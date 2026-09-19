import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:autodoc/core/constants/firestore_collections.dart';
import 'package:autodoc/core/models/service_record_model.dart';
import 'package:autodoc/features/chat/data/models/cotizacion_model.dart';

/// Tope de las dos listas de "Mis Servicios". Es un tope de LECTURAS, no solo
/// de documentos: las dos consultas ordenan por `fecha` antes del `limit`, así
/// que lo que se queda fuera es siempre lo más antiguo, nunca algo arbitrario.
const int maxTrabajosTaller = 200;

/// Servicios de un vehículo que se enseñan en su perfil (lo más reciente).
const int maxServiciosPorVehiculo = 30;

/// El trabajo de un taller visto desde las cotizaciones y los servicios que
/// registró: las listas de "Mis Servicios" y lo que el perfil de un vehículo
/// le enseña al taller (observaciones del 2026-09-19).
///
/// **Todas las consultas de cotizaciones filtran por `id_taller`**, y no es
/// un detalle: `firestore.rules` solo deja leer una cotización a su
/// propietario, a quien la redactó o a quien actúa por su taller, y las
/// reglas no filtran — rechazan la consulta entera si no pueden demostrar que
/// TODOS los documentos que devolvería cumplen. Pedir las cotizaciones
/// aceptadas de un vehículo solo por `id_vehiculo` + `estado` (lo que hacía
/// `InitiateServiceScreen`) moría siempre en `permission-denied`, y la
/// pantalla decía «No se pudo comprobar si el cliente aprobó una
/// cotización» (captura 7).
class TrabajosTallerRepository {
  TrabajosTallerRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _cotizaciones =>
      _firestore.collection(FirestoreCollections.cotizaciones);

  CollectionReference<Map<String, dynamic>> get _servicios =>
      _firestore.collection(FirestoreCollections.servicios);

  /// Las cotizaciones de ESTE taller para ESTE vehículo, de la más nueva a la
  /// más vieja. Los borradores (`draft`) no cuentan: son el paso intermedio
  /// de publicar una cotización, nunca algo que el cliente haya visto.
  ///
  /// Solo igualdades y sin `orderBy`, a propósito: Firestore la sirve con los
  /// índices automáticos de un campo, sin índice compuesto que desplegar, y
  /// las cotizaciones de un solo coche en un solo taller son pocas. Se ordena
  /// en memoria.
  Future<List<CotizacionModel>> cotizacionesDelVehiculo({
    required String idVehiculo,
    required String idTaller,
  }) async {
    final snap = await _cotizaciones
        .where('id_vehiculo', isEqualTo: idVehiculo)
        .where('id_taller', isEqualTo: idTaller)
        .get();
    return _ordenadas(snap).where((c) => c.estado != 'draft').toList();
  }

  /// Las cotizaciones ACEPTADAS y todavía sin cobrar (al cerrar el servicio
  /// pasan a `finalizada`) de este vehículo en este taller: lo que el
  /// servicio en curso tiene que cobrar.
  ///
  /// Pueden ser varias: desde el 2026-09-19 el taller puede mandar una
  /// cotización extra sobre un coche que ya tiene una aceptada, y el
  /// servidor no abre un segundo ticket si ya hay uno abierto
  /// (`existeTicketAbiertoParaVehiculo`), así que las dos van a la misma
  /// visita. Se devuelven de la más antigua a la más nueva, que es el orden
  /// en que el cliente las fue aprobando.
  Future<List<CotizacionModel>> cotizacionesAceptadas({
    required String idVehiculo,
    required String idTaller,
  }) async {
    final snap = await _cotizaciones
        .where('id_vehiculo', isEqualTo: idVehiculo)
        .where('id_taller', isEqualTo: idTaller)
        .where('estado', isEqualTo: 'aceptada')
        .get();
    return _ordenadas(snap).reversed.toList();
  }

  /// Los servicios que este taller registró sobre este vehículo, del más
  /// reciente al más antiguo.
  ///
  /// Índice `servicios (id_vehiculo, id_taller, fecha DESC)`: ya existía,
  /// lo usa la búsqueda del servicio a reseñar.
  Future<List<ServiceRecordModel>> serviciosDelVehiculo({
    required String idVehiculo,
    required String idTaller,
  }) async {
    final snap = await _servicios
        .where('id_vehiculo', isEqualTo: idVehiculo)
        .where('id_taller', isEqualTo: idTaller)
        .orderBy('fecha', descending: true)
        .limit(maxServiciosPorVehiculo)
        .get();
    return snap.docs
        .map((d) => ServiceRecordModel.fromMap(d.data(), d.id))
        .toList();
  }

  /// Las cotizaciones del taller, de la más nueva a la más vieja: de aquí
  /// salen las pestañas "Pendientes", "En proceso" y "Rechazados" de "Mis
  /// Servicios".
  ///
  /// Son DOS consultas juntas: las [maxTrabajosTaller] más recientes, más
  /// todas las que siguen vivas (pendientes o aceptadas) por viejas que sean.
  /// Con la primera sola, en un taller con más de 200 cotizaciones un coche
  /// que llevaba semanas en el taller desaparecía de "En proceso" (revisión
  /// del 2026-09-19). La segunda son dos igualdades (`whereIn` cuenta como
  /// igualdad): índices automáticos, y el `limit` se aplica a cada estado.
  ///
  /// Índice `cotizaciones (id_taller, fecha DESC)` para la primera: nuevo el
  /// 2026-09-19. Sin desplegarlo, la consulta muere en producción con
  /// `failed-precondition` (los emuladores no lo detectan).
  Stream<List<CotizacionModel>> watchCotizacionesDelTaller(String idTaller) {
    final recientes = _cotizaciones
        .where('id_taller', isEqualTo: idTaller)
        .orderBy('fecha', descending: true)
        .limit(maxTrabajosTaller)
        .snapshots();
    final vivas = _cotizaciones
        .where('id_taller', isEqualTo: idTaller)
        .where('estado', whereIn: const ['pendiente', 'aceptada'])
        .limit(maxTrabajosTaller)
        .snapshots();
    return _unidas(recientes, vivas).map((docs) {
      final porId = <String, CotizacionModel>{
        for (final d in docs) d.id: CotizacionModel.fromMap(d.data(), d.id),
      };
      return porId.values.where((c) => c.estado != 'draft').toList()
        ..sort((a, b) => b.fecha.compareTo(a.fecha));
    });
  }

  /// Emite los documentos de [a] y [b] juntos cada vez que cambia cualquiera,
  /// pero solo cuando los dos han emitido al menos una vez: si no, la lista
  /// saldría primero a medias y "En proceso" parpadearía.
  static Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _unidas(
    Stream<QuerySnapshot<Map<String, dynamic>>> a,
    Stream<QuerySnapshot<Map<String, dynamic>>> b,
  ) {
    late StreamController<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
    controlador;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? subA;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? subB;
    QuerySnapshot<Map<String, dynamic>>? ultimoA;
    QuerySnapshot<Map<String, dynamic>>? ultimoB;

    void emitir() {
      final da = ultimoA;
      final db = ultimoB;
      if (da == null || db == null) return;
      controlador.add([...da.docs, ...db.docs]);
    }

    controlador = StreamController(
      onListen: () {
        subA = a.listen((s) {
          ultimoA = s;
          emitir();
        }, onError: controlador.addError);
        subB = b.listen((s) {
          ultimoB = s;
          emitir();
        }, onError: controlador.addError);
      },
      onCancel: () async {
        await subA?.cancel();
        await subB?.cancel();
      },
    );
    return controlador.stream;
  }

  /// Los servicios que el taller ya registró (la pestaña "Finalizados").
  ///
  /// Por `id_taller` del DUEÑO: es lo que escribe `InitiateServiceScreen` al
  /// cerrar el servicio, también cuando lo cierra un empleado. Índice
  /// `servicios (id_taller, fecha DESC)`, que ya existía.
  Stream<List<ServiceRecordModel>> watchServiciosDelTaller(String idTaller) {
    return _servicios
        .where('id_taller', isEqualTo: idTaller)
        .orderBy('fecha', descending: true)
        .limit(maxTrabajosTaller)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => ServiceRecordModel.fromMap(d.data(), d.id))
              .toList(),
        );
  }

  /// Marca como cobradas las cotizaciones que acaba de cerrar un servicio.
  ///
  /// En un lote: todas o ninguna. Una a una, si fallaba la segunda se quedaba
  /// en `aceptada` y se volvía a cobrar en el siguiente servicio del coche
  /// (revisión del 2026-09-19).
  Future<void> marcarFinalizadas(Iterable<String> idsCotizacion) async {
    final ids = idsCotizacion.toSet();
    if (ids.isEmpty) return;
    final lote = _firestore.batch();
    for (final id in ids) {
      lote.update(_cotizaciones.doc(id), {'estado': 'finalizada'});
    }
    await lote.commit();
  }

  static List<CotizacionModel> _ordenadas(
    QuerySnapshot<Map<String, dynamic>> snap,
  ) {
    return snap.docs
        .map((d) => CotizacionModel.fromMap(d.data(), d.id))
        .toList()
      ..sort((a, b) => b.fecha.compareTo(a.fecha));
  }
}
