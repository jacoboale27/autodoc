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

  /// Cuántos tickets se traen para elegir el vigente. Un vehículo+taller
  /// legítimo acumula uno por visita, así que 20 cubre de sobra el historial
  /// de un cliente recurrente sin dejar la consulta sin tope.
  static const int _maxTicketsPorVehiculoTaller = 20;

  /// Busca el ticket de reparación **de la visita actual** de este vehículo en
  /// este taller, o `null` si no hay ninguno.
  ///
  /// No basta con `limit(1)`: un vehículo+taller puede tener VARIOS tickets.
  /// El servidor abre uno nuevo cuando el anterior ya está cerrado
  /// (`ESTADOS_TICKET_CERRADO` en `functions/src/aceptarCotizacion.js`, espejo
  /// de [estadosReparacionCerrados]), que es justo lo que pasa con un cliente
  /// que vuelve: queda el `entregado` de la visita pasada y nace el
  /// `pendiente_recepcion` de la nueva. Con `limit(1)` sin orden, Firestore
  /// devolvía cualquiera de los dos — y si devolvía el viejo, "Recibir
  /// vehículo" era un no-op silencioso ([recibirVehiculo] devuelve `false`
  /// porque ese ticket ya pasó de `recibido`) y el ticket nuevo se quedaba
  /// para siempre en "Por recibir" mientras el mecánico creía haber recibido
  /// el coche.
  ///
  /// Se prefiere el ticket ABIERTO más reciente; si todos están cerrados se
  /// devuelve el más reciente, para no cambiar el comportamiento del llamador
  /// que sí quiere "cualquier ticket existente": la lista de Mis Servicios,
  /// donde un ticket ya entregado sigue siendo tocable. El filtro de
  /// `cancelado` vive en `ReparacionProvider.buscarReparacionActiva`, que es
  /// el único que decide si se puede abrir la pantalla de servicio.
  ///
  /// Se ordena en memoria y no con `orderBy`: añadirlo a una consulta que ya
  /// tiene dos igualdades exige un índice compuesto nuevo, y el tope de
  /// [_maxTicketsPorVehiculoTaller] hace que ordenar aquí no cueste nada.
  Future<String?> buscarReparacionActiva({
    required String idVehiculo,
    required String idTaller,
  }) async {
    final snap = await _firestore
        .collection(FirestoreCollections.reparaciones)
        .where('id_vehiculo', isEqualTo: idVehiculo)
        .where('id_taller', isEqualTo: idTaller)
        .limit(_maxTicketsPorVehiculoTaller)
        .get();
    if (snap.docs.isEmpty) return null;

    final docs = snap.docs.toList()
      ..sort((a, b) => _fechaCreacion(b).compareTo(_fechaCreacion(a)));
    for (final doc in docs) {
      // Los tickets anteriores a A4b no traen `estado`; nacían en 'recibido',
      // que está abierto — mismo default que `recibirVehiculo`.
      final estado = (doc.data()['estado'] ?? 'recibido').toString();
      if (!estadosReparacionCerrados.contains(estado)) return doc.id;
    }
    return docs.first.id;
  }

  /// `fecha_creacion` tolerante: los documentos que escribe la Cloud Function
  /// la traen como `Timestamp`, pero un ticket recién escrito con
  /// `serverTimestamp()` la expone como `null` en el snapshot local. Un ticket
  /// sin fecha se ordena como el más antiguo.
  static DateTime _fechaCreacion(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final valor = doc.data()['fecha_creacion'];
    if (valor is Timestamp) return valor.toDate();
    if (valor is DateTime) return valor;
    return DateTime.fromMillisecondsSinceEpoch(0);
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
  /// Ronda 5: pasa por el callable `recibirVehiculoDelTicket` en vez de
  /// escribir directo sobre `reparaciones`.
  ///
  /// Recibir el vehículo dejó de ser solo un cambio de estado: es también el
  /// momento en que el taller obtiene acceso a la ficha del coche
  /// (`vehiculos.talleres_vinculados`, que antes se otorgaba al aceptarse la
  /// cotización y no se revocaba nunca). Las dos mitades tienen que pasar
  /// juntas —o el ticket queda recibido sin que el taller pueda abrir la
  /// ficha, o al revés— y el cliente no puede escribir la segunda:
  /// `firestore.rules` solo le permite tocar `kilometraje_actual` del
  /// vehículo. La transición vive por tanto en el servidor, en una escritura
  /// atómica.
  ///
  /// El contrato hacia arriba no cambia: `true` si esta llamada movió el
  /// ticket a `recibido`, `false` si ya estaba ahí o más adelante (no-op).
  /// Los rechazos del servidor se traducen a [ArgumentError] con el mensaje
  /// del servidor, que es lo que [ReparacionProvider] y la pantalla ya
  /// esperaban de la versión anterior.
  Future<bool> recibirVehiculo({required String idReparacion}) async {
    try {
      final result = await _functions
          .httpsCallable('recibirVehiculoDelTicket')
          .call({'id_reparacion': idReparacion});
      final data = result.data as Map;
      return data['recibido_ahora'] == true;
    } on FirebaseFunctionsException catch (e) {
      throw ArgumentError(
        e.message ?? 'No se pudo recibir el vehículo de este ticket.',
      );
    }
  }

  Future<void> cambiarEstado({
    required String idReparacion,
    required String nuevoEstado,
  }) async {
    // 'cancelado' y 'entregado' son estados terminales fuera del pipeline
    // secuencial de `estadosReparacion` (a propósito: si vivieran en esa lista
    // aparecerían como una columna más del kanban y desordenarían el índice
    // que decide "avanzar"/"retroceder" — ver ReparacionesKanbanScreen, que
    // itera `estadosReparacion` para las columnas). Se aceptan aparte.
    if (!estadosReparacionCerrados.contains(nuevoEstado) &&
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

      // Entregar no es "avanzar una columna": es afirmar que el coche salió
      // del taller. Solo tiene sentido si el coche estaba dentro. Sin esta
      // guarda se podría entregar un `pendiente_recepcion` (un coche que
      // nunca llegó — eso es `cancelado`) o entregar dos veces, y como
      // entregar es lo que revoca el vínculo al vehículo y saca el ticket
      // del tablero, ninguna de las dos cosas se puede deshacer desde la
      // interfaz.
      if (nuevoEstado == estadoReparacionEntregado &&
          !estadosVehiculoEnTaller.contains(estadoActual)) {
        throw ArgumentError(
          estadoActual == estadoReparacionEntregado
              ? 'Este vehículo ya se entregó.'
              : 'No se puede entregar un vehículo que no está en el taller '
                    '(estado actual: "$estadoActual").',
        );
      }

      final indiceActual = estadosReparacion.indexOf(estadoActual);
      final indiceNuevo = estadosReparacion.indexOf(nuevoEstado);
      if (!estadosReparacionCerrados.contains(nuevoEstado) &&
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
        // Denormalizado para que el tablero pregunte por una igualdad (gap
        // 9.1). Va SIEMPRE junto al estado y derivado de él: `firestore.rules`
        // exige que el documento resultante sea coherente, así que un update
        // que mueva `estado` sin mover esto se deniega.
        'abierto': ticketAbierto(nuevoEstado),
        'historial_estados': historial,
        'fecha_actualizacion': Timestamp.fromDate(ahora),
      });
    });
  }

  /// Los tickets **vivos** del taller: los que están en alguna columna del
  /// tablero.
  ///
  /// El filtro por estado va en la consulta y no en memoria porque este stream
  /// es la fuente del Kanban y de "Mis Servicios", y sin él transmitía la
  /// historia ENTERA del taller en cada apertura del tablero — todos los
  /// tickets cancelados y todos los ya entregados, crecimiento sin techo, y
  /// pagando lecturas por documentos que ninguna de las dos pantallas pinta.
  ///
  /// El filtro es la **igualdad** `abierto == true`, y no el `whereIn` sobre
  /// [estadosReparacion] que tuvo hasta el gap 9.1. La diferencia no es de
  /// estilo: Firestore ejecuta un `in` como N subconsultas y aplica el
  /// `limit` **a cada una** antes de fusionar, así que el `whereIn` de cinco
  /// estados con `limit(200)` leía hasta 1000 documentos para devolver 200 —
  /// el tope acotaba documentos, no lecturas. Una igualdad lee exactamente el
  /// tope.
  ///
  /// El precio es un campo denormalizado que hay que mantener coherente; quién
  /// lo escribe y quién lo ata está en [ticketAbierto]. Y trae la misma
  /// precondición que el `whereIn` y que el `orderBy`: **una igualdad sobre un
  /// campo ausente no devuelve nada**, así que los tickets anteriores a este
  /// cambio no aparecerían hasta que `backfill_entregado.js` les escriba
  /// `abierto`. Correrlo ANTES de desplegar no es opcional.
  ///
  /// **Va acotado** (residual 7.6 de FUNC-02). Sin `limit` este stream traía
  /// el conjunto entero en cada `attach` del listener, y su tamaño no depende
  /// del uso normal sino de que el taller cierre sus tickets: un ticket que
  /// nunca pasa a `entregado` se queda aquí para siempre (residual 7.2). El
  /// tope acota el coste sin depender de esa disciplina.
  ///
  /// El `orderBy` es parte del tope, no un adorno: recortar sin ordenar deja
  /// fuera tickets **arbitrarios**, porque sin `orderBy` el orden es por
  /// `__name__`, o sea por un id aleatorio. Ordenando por actividad, lo que
  /// cae fuera es lo más rancio, que es lo que un tablero puede permitirse
  /// perder de vista. Y que se haya llegado al tope se anuncia: ver
  /// `ReparacionProvider.tableroTruncado`.
  ///
  /// Ese `orderBy` añade una segunda precondición al mismo backfill: excluye
  /// los documentos sin `fecha_actualizacion`, y los tickets anteriores a A4b
  /// pueden no tenerla. `backfill_entregado.js` se la escribe (pasada 1), con
  /// el valor tolerante que ya usaba para decidir la antigüedad — así el
  /// ticket conserva el momento real de su última actividad, no el de la
  /// migración. **Correr el backfill antes de desplegar esta versión no es
  /// opcional**, exactamente igual que para el `whereIn` de arriba.
  Stream<List<ReparacionModel>> watchReparacionesActivas(String idTaller) {
    return _firestore
        .collection(FirestoreCollections.reparaciones)
        .where('id_taller', isEqualTo: idTaller)
        .where('abierto', isEqualTo: true)
        .orderBy('fecha_actualizacion', descending: true)
        .limit(maxTicketsTablero)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => ReparacionModel.fromMap(d.data(), d.id))
              .toList(),
        );
  }
}
