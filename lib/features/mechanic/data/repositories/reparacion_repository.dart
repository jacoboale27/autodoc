import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:autodoc/core/constants/firestore_collections.dart';
import 'package:autodoc/core/models/reparacion_model.dart';

class ReparacionRepository {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  ReparacionRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? FirebaseFunctions.instance;

  /// Igual que [iniciarReparacion]/[buscarReparacionActiva] combinados, pero
  /// vía el callable `iniciarReparacionPorVehiculo` en vez de escribir
  /// directo a Firestore. Se usa cuando el vehículo viene de "Buscar
  /// Vehículo" (búsqueda por placa): `buscarVehiculoPorPlaca` no devuelve
  /// `id_propietario` a propósito (para no exponer al dueño a cualquier
  /// mecánico que busque una placa, ver ese callable), así que el cliente no
  /// tiene ese dato para satisfacer la regla de creación de `reparaciones` —
  /// el callable lo resuelve del lado servidor.
  @Deprecated('El ticket lo crea onCotizacionAceptada')
  Future<String> iniciarOReutilizarPorVehiculo({
    required String idVehiculo,
    required String idTaller,
  }) async {
    final result = await _functions
        .httpsCallable('iniciarReparacionPorVehiculo')
        .call({'id_vehiculo': idVehiculo, 'id_taller': idTaller});
    final data = result.data as Map;
    return data['id_reparacion'] as String;
  }

  /// Busca un ticket de reparación ya existente para este vehículo en este
  /// taller, sin importar su estado: el brief no define un estado
  /// "entregado"/cerrado (ver `estadosReparacion`, cuyo último valor es
  /// `listo_para_entrega`, todavía "activo" para
  /// `watchReparacionesActivas`), así que cualquier reparación encontrada
  /// para este par vehículo+taller es la misma visita en curso. Devuelve
  /// `null` si no hay ninguna. Se usa antes de crear un ticket nuevo para
  /// no duplicarlo cada vez que se reentra a la pantalla de servicio
  /// (`InitiateServiceScreen` recreaba un ticket en cada `initState`).
  Future<String?> buscarReparacionActiva({
    required String idVehiculo,
    required String idTaller,
  }) async {
    final snap = await _firestore
        .collection(FirestoreCollections.reparaciones)
        .where('id_vehiculo', isEqualTo: idVehiculo)
        .where('id_taller', isEqualTo: idTaller)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first.id;
  }

  /// Lee un ticket por id. Devuelve `null` si no existe.
  ///
  /// Lo usa `ReparacionProvider.buscarReparacionActiva` (la gating de
  /// A3/B2) para distinguir un ticket vigente de uno `cancelado`:
  /// [buscarReparacionActiva] deliberadamente no filtra por estado (ver su
  /// propio comentario), así que esa distinción se resuelve con una
  /// segunda lectura en vez de complicar esa consulta para todos sus
  /// llamadores (incluidos los deprecados, que sí quieren "cualquier
  /// estado").
  Future<ReparacionModel?> obtenerReparacion(String idReparacion) async {
    final snap = await _firestore
        .collection(FirestoreCollections.reparaciones)
        .doc(idReparacion)
        .get();
    if (!snap.exists || snap.data() == null) return null;
    return ReparacionModel.fromMap(snap.data()!, snap.id);
  }

  /// Crea un ticket desde el cliente. **Ya no es alcanzable en producción**:
  /// desde A4b `firestore.rules` cierra `allow create` en `reparaciones` y el
  /// único creador es la Cloud Function `onCotizacionAceptada`. Se conserva
  /// porque hay tickets en producción abiertos por esta vía y porque los
  /// tests la siguen usando para sembrar datos.
  @Deprecated('El ticket lo crea onCotizacionAceptada')
  Future<String> iniciarReparacion({
    required String idVehiculo,
    required String idTaller,
    required String idPropietario,
    required String placa,
  }) async {
    final ahora = DateTime.now();
    final docRef = _firestore
        .collection(FirestoreCollections.reparaciones)
        .doc();
    final model = ReparacionModel(
      idReparacion: docRef.id,
      idVehiculo: idVehiculo,
      idTaller: idTaller,
      idPropietario: idPropietario,
      placa: placa,
      estado: 'recibido',
      historialEstados: [
        {'estado': 'recibido', 'timestamp': ahora},
      ],
      fechaCreacion: ahora,
      fechaActualizacion: ahora,
    );
    await docRef.set(model.toMap());
    return docRef.id;
  }

  /// Marca que el vehículo llegó físicamente al taller: transición
  /// `pendiente_recepcion` -> `recibido`.
  ///
  /// El ticket ya existe cuando el cliente acepta la cotización (trigger
  /// `onCotizacionAceptada`), así que "Recibir vehículo" ya no crea nada.
  /// Sin esto el mecánico podía abrir un ticket sin que nadie hubiera
  /// aceptado ninguna cotización (A3/B2).
  ///
  /// Recibir dos veces no es un error: si el ticket ya está en `recibido` o
  /// más adelante en el pipeline no hace nada, en vez de reventar con el
  /// "no se puede retroceder" de [cambiarEstado]. Un ticket `cancelado` sí
  /// se rechaza: hace falta una cotización nueva.
  ///
  /// Devuelve `true` si esta llamada movió el ticket a `recibido`, o `false`
  /// si ya estaba ahí o más adelante (no-op). Hallazgo 2 de la revisión de
  /// la Tarea 4: sin distinguir estos dos casos, `ReparacionProvider` no
  /// podía distinguir "acabo de recibir el vehículo" de "este ticket ya
  /// estaba recibido de antes" (p. ej. porque [ReparacionRepository.
  /// buscarReparacionActiva] resolvió un ticket legado en vez del nuevo), y
  /// la pantalla terminaba anunciando una recepción que no ocurrió.
  Future<bool> recibirVehiculo({required String idReparacion}) async {
    final snap = await _firestore
        .collection(FirestoreCollections.reparaciones)
        .doc(idReparacion)
        .get();
    if (!snap.exists || snap.data() == null) {
      throw ArgumentError('Reparación no encontrada: $idReparacion');
    }
    // Los tickets anteriores a A4b no traen `estado` explícito en algunos
    // documentos antiguos; se leen como 'recibido', que es donde nacían.
    final estadoActual = (snap.data()!['estado'] ?? 'recibido').toString();
    if (estadoActual == 'cancelado') {
      throw ArgumentError(
        'El ticket de este vehículo está cancelado: hace falta una '
        'cotización aceptada nueva.',
      );
    }
    final indiceActual = estadosReparacion.indexOf(estadoActual);
    if (indiceActual >= estadosReparacion.indexOf('recibido')) return false;
    await cambiarEstado(idReparacion: idReparacion, nuevoEstado: 'recibido');
    return true;
  }

  Future<void> cambiarEstado({
    required String idReparacion,
    required String nuevoEstado,
  }) async {
    // 'cancelado' es un estado terminal fuera del pipeline secuencial de
    // `estadosReparacion` (a propósito: si viviera en esa lista aparecería
    // como una columna más del kanban y desordenaría el índice que decide
    // "avanzar"/"retroceder" — ver ReparacionesKanbanScreen, que itera
    // `estadosReparacion` para las columnas). Se acepta aparte, sin
    // importar el estado actual del ticket.
    if (nuevoEstado != 'cancelado' &&
        !estadosReparacion.contains(nuevoEstado)) {
      throw ArgumentError('Estado inválido: $nuevoEstado');
    }
    final docRef = _firestore
        .collection(FirestoreCollections.reparaciones)
        .doc(idReparacion);
    final ahora = DateTime.now();

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists || snap.data() == null) {
        throw ArgumentError('Reparación no encontrada: $idReparacion');
      }
      final data = snap.data() as Map<String, dynamic>;

      final estadoActual = (data['estado'] ?? 'recibido').toString();
      final indiceActual = estadosReparacion.indexOf(estadoActual);
      final indiceNuevo = estadosReparacion.indexOf(nuevoEstado);
      if (nuevoEstado != 'cancelado' &&
          indiceActual != -1 &&
          indiceNuevo < indiceActual) {
        throw ArgumentError(
          'No se puede retroceder de "$estadoActual" a "$nuevoEstado"',
        );
      }

      final historial = List<Map<String, dynamic>>.from(
        (data['historial_estados'] as List).map(
          (h) => Map<String, dynamic>.from(h as Map),
        ),
      )..add({'estado': nuevoEstado, 'timestamp': Timestamp.fromDate(ahora)});

      tx.update(docRef, {
        'estado': nuevoEstado,
        'historial_estados': historial,
        'fecha_actualizacion': Timestamp.fromDate(ahora),
      });
    });
  }

  Stream<List<ReparacionModel>> watchReparacionesActivas(String idTaller) {
    return _firestore
        .collection(FirestoreCollections.reparaciones)
        .where('id_taller', isEqualTo: idTaller)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => ReparacionModel.fromMap(d.data(), d.id))
              .toList(),
        );
  }
}
