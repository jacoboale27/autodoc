import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/features/mechanic/data/repositories/reparacion_repository.dart';
import 'package:autodoc/core/constants/firestore_collections.dart';
import 'package:autodoc/core/models/reparacion_model.dart';

import '../../../../helpers/test_helpers.mocks.dart';

void main() {
  test('iniciarReparacion crea documento con estado recibido', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = ReparacionRepository(
      firestore: firestore,
      functions: MockFirebaseFunctions(),
    );

    final id = await repo.iniciarReparacion(
      idVehiculo: 'v1',
      idTaller: 't1',
      idPropietario: 'p1',
      placa: 'P123-456',
    );

    final doc = await firestore
        .collection(FirestoreCollections.reparaciones)
        .doc(id)
        .get();
    expect(doc.data()!['estado'], 'recibido');
  });

  test(
    'cambiarEstado actualiza estado y agrega entrada al historial',
    () async {
      final firestore = FakeFirebaseFirestore();
      final repo = ReparacionRepository(
        firestore: firestore,
        functions: MockFirebaseFunctions(),
      );
      final id = await repo.iniciarReparacion(
        idVehiculo: 'v1',
        idTaller: 't1',
        idPropietario: 'p1',
        placa: 'P123-456',
      );

      await repo.cambiarEstado(idReparacion: id, nuevoEstado: 'en_revision');

      final doc = await firestore
          .collection(FirestoreCollections.reparaciones)
          .doc(id)
          .get();
      expect(doc.data()!['estado'], 'en_revision');
      expect((doc.data()!['historial_estados'] as List).length, 2);
    },
  );

  test('cambiarEstado rechaza un estado fuera de la lista permitida', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = ReparacionRepository(
      firestore: firestore,
      functions: MockFirebaseFunctions(),
    );
    final id = await repo.iniciarReparacion(
      idVehiculo: 'v1',
      idTaller: 't1',
      idPropietario: 'p1',
      placa: 'P123-456',
    );

    expect(
      () => repo.cambiarEstado(idReparacion: id, nuevoEstado: 'inventado'),
      throwsArgumentError,
    );
  });

  test('cambiarEstado rechaza retroceder a un estado anterior', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = ReparacionRepository(
      firestore: firestore,
      functions: MockFirebaseFunctions(),
    );
    final id = await repo.iniciarReparacion(
      idVehiculo: 'v1',
      idTaller: 't1',
      idPropietario: 'p1',
      placa: 'P123-456',
    );

    // recibido -> esperando_repuestos (avance permitido, salta en_revision)
    await repo.cambiarEstado(
      idReparacion: id,
      nuevoEstado: 'esperando_repuestos',
    );

    // esperando_repuestos -> en_revision (retroceso, debe fallar)
    expect(
      () => repo.cambiarEstado(idReparacion: id, nuevoEstado: 'en_revision'),
      throwsArgumentError,
    );
  });

  test(
    'cambiarEstado permite avanzar directo saltando pasos intermedios',
    () async {
      final firestore = FakeFirebaseFirestore();
      final repo = ReparacionRepository(
        firestore: firestore,
        functions: MockFirebaseFunctions(),
      );
      final id = await repo.iniciarReparacion(
        idVehiculo: 'v1',
        idTaller: 't1',
        idPropietario: 'p1',
        placa: 'P123-456',
      );

      // recibido -> listo_para_entrega (salta en_revision y esperando_repuestos)
      await repo.cambiarEstado(
        idReparacion: id,
        nuevoEstado: 'listo_para_entrega',
      );

      final doc = await firestore
          .collection(FirestoreCollections.reparaciones)
          .doc(id)
          .get();
      expect(doc.data()!['estado'], 'listo_para_entrega');
    },
  );

  test(
    'cambiarEstado rechaza un idReparacion inexistente con error de dominio',
    () async {
      final firestore = FakeFirebaseFirestore();
      final repo = ReparacionRepository(
        firestore: firestore,
        functions: MockFirebaseFunctions(),
      );

      expect(
        () => repo.cambiarEstado(
          idReparacion: 'no-existe',
          nuevoEstado: 'en_revision',
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'buscarReparacionActiva devuelve null si no hay ninguna para ese vehículo+taller',
    () async {
      final firestore = FakeFirebaseFirestore();
      final repo = ReparacionRepository(
        firestore: firestore,
        functions: MockFirebaseFunctions(),
      );

      final id = await repo.buscarReparacionActiva(
        idVehiculo: 'v1',
        idTaller: 't1',
      );

      expect(id, isNull);
    },
  );

  test(
    'buscarReparacionActiva encuentra el ticket existente sin importar su estado',
    () async {
      final firestore = FakeFirebaseFirestore();
      final repo = ReparacionRepository(
        firestore: firestore,
        functions: MockFirebaseFunctions(),
      );
      final idCreado = await repo.iniciarReparacion(
        idVehiculo: 'v1',
        idTaller: 't1',
        idPropietario: 'p1',
        placa: 'P123-456',
      );
      // 'entregado' y no 'listo_para_entrega': desde la ronda 6 este ultimo
      // es un estado ABIERTO (el coche sigue en el taller), asi que ya no
      // probaria nada sobre "sin importar su estado".
      await repo.cambiarEstado(
        idReparacion: idCreado,
        nuevoEstado: estadoReparacionEntregado,
      );

      final idEncontrado = await repo.buscarReparacionActiva(
        idVehiculo: 'v1',
        idTaller: 't1',
      );

      expect(idEncontrado, idCreado);
    },
  );

  test('con un ticket cerrado y otro abierto para el mismo vehiculo+taller, '
      'buscarReparacionActiva devuelve el ABIERTO', () async {
    // El cliente que vuelve: el servidor considera cerrado el
    // `entregado` de la visita pasada
    // (`ESTADOS_TICKET_CERRADO`) y abre un ticket nuevo al aceptar la
    // cotizacion nueva. Con el `limit(1)` sin orden que habia antes,
    // Firestore podia devolver el viejo: "Recibir vehiculo" no hacia nada
    // (ya habia pasado de `recibido`) y el ticket nuevo se quedaba en "Por
    // recibir" para siempre.
    final firestore = FakeFirebaseFirestore();
    final repo = ReparacionRepository(
      firestore: firestore,
      functions: MockFirebaseFunctions(),
    );

    final viejo = await repo.iniciarReparacion(
      idVehiculo: 'v1',
      idTaller: 't1',
      idPropietario: 'p1',
      placa: 'P123-456',
    );
    await repo.cambiarEstado(
      idReparacion: viejo,
      nuevoEstado: estadoReparacionEntregado,
    );

    await firestore.collection('reparaciones').doc('cot_nuevo').set({
      'id_vehiculo': 'v1',
      'id_taller': 't1',
      'id_propietario': 'p1',
      'placa': 'P123-456',
      'estado': 'pendiente_recepcion',
      'historial_estados': const [],
      'fecha_creacion': Timestamp.fromDate(DateTime(2030)),
      'fecha_actualizacion': Timestamp.fromDate(DateTime(2030)),
    });

    expect(
      await repo.buscarReparacionActiva(idVehiculo: 'v1', idTaller: 't1'),
      'cot_nuevo',
    );
  });

  test(
    'entre dos tickets abiertos, buscarReparacionActiva devuelve el mas reciente',
    () async {
      final firestore = FakeFirebaseFirestore();
      final repo = ReparacionRepository(
        firestore: firestore,
        functions: MockFirebaseFunctions(),
      );

      for (final caso in [
        ('viejo', DateTime(2020)),
        ('reciente', DateTime(2031)),
      ]) {
        await firestore.collection('reparaciones').doc(caso.$1).set({
          'id_vehiculo': 'v1',
          'id_taller': 't1',
          'id_propietario': 'p1',
          'placa': 'P123-456',
          'estado': 'recibido',
          'historial_estados': const [],
          'fecha_creacion': Timestamp.fromDate(caso.$2),
          'fecha_actualizacion': Timestamp.fromDate(caso.$2),
        });
      }

      expect(
        await repo.buscarReparacionActiva(idVehiculo: 'v1', idTaller: 't1'),
        'reciente',
      );
    },
  );

  test(
    'buscarReparacionActiva no mezcla tickets de otro vehículo o taller',
    () async {
      final firestore = FakeFirebaseFirestore();
      final repo = ReparacionRepository(
        firestore: firestore,
        functions: MockFirebaseFunctions(),
      );
      await repo.iniciarReparacion(
        idVehiculo: 'v1',
        idTaller: 't1',
        idPropietario: 'p1',
        placa: 'P123-456',
      );

      expect(
        await repo.buscarReparacionActiva(idVehiculo: 'v2', idTaller: 't1'),
        isNull,
      );
      expect(
        await repo.buscarReparacionActiva(idVehiculo: 'v1', idTaller: 't2'),
        isNull,
      );
    },
  );

  test(
    'cambiarEstado a cancelado se acepta desde cualquier estado del pipeline',
    () async {
      final firestore = FakeFirebaseFirestore();
      final repo = ReparacionRepository(
        firestore: firestore,
        functions: MockFirebaseFunctions(),
      );
      final id = await repo.iniciarReparacion(
        idVehiculo: 'v1',
        idTaller: 't1',
        idPropietario: 'p1',
        placa: 'P123-456',
      );

      // recibido -> cancelado no es un "avance" del pipeline, pero debe
      // aceptarse igual: 'cancelado' es un estado terminal fuera de
      // estadosReparacion, no un retroceso.
      await repo.cambiarEstado(idReparacion: id, nuevoEstado: 'cancelado');

      final doc = await firestore
          .collection(FirestoreCollections.reparaciones)
          .doc(id)
          .get();
      expect(doc.data()!['estado'], 'cancelado');
    },
  );

  test(
    'cambiarEstado a cancelado tambien se acepta mas avanzado en el pipeline',
    () async {
      final firestore = FakeFirebaseFirestore();
      final repo = ReparacionRepository(
        firestore: firestore,
        functions: MockFirebaseFunctions(),
      );
      final id = await repo.iniciarReparacion(
        idVehiculo: 'v1',
        idTaller: 't1',
        idPropietario: 'p1',
        placa: 'P123-456',
      );
      await repo.cambiarEstado(
        idReparacion: id,
        nuevoEstado: 'listo_para_entrega',
      );

      // Sin el carve-out de 'cancelado', esto lanzaría "no se puede
      // retroceder" porque estadosReparacion.indexOf('cancelado') == -1.
      await repo.cambiarEstado(idReparacion: id, nuevoEstado: 'cancelado');

      final doc = await firestore
          .collection(FirestoreCollections.reparaciones)
          .doc(id)
          .get();
      expect(doc.data()!['estado'], 'cancelado');
    },
  );

  test('watchReparacionesActivas emite reparaciones del taller', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = ReparacionRepository(
      firestore: firestore,
      functions: MockFirebaseFunctions(),
    );
    await repo.iniciarReparacion(
      idVehiculo: 'v1',
      idTaller: 't1',
      idPropietario: 'p1',
      placa: 'P123-456',
    );
    await repo.iniciarReparacion(
      idVehiculo: 'v2',
      idTaller: 't2',
      idPropietario: 'p2',
      placa: 'P789-000',
    );

    final lista = await repo.watchReparacionesActivas('t1').first;

    expect(lista.length, 1);
    expect(lista.first.idTaller, 't1');
  });

  // --- Ronda 6: 'entregado', el estado terminal que saca el ticket del
  // tablero. Antes el pipeline terminaba en `listo_para_entrega` y ningun
  // ticket salia nunca: el tablero y "Mis Servicios" acumulaban la historia
  // completa del taller, y el vinculo al vehiculo se revocaba con el coche
  // todavia aparcado dentro.

  test(
    'watchReparacionesActivas NO emite los tickets que salieron del tablero',
    () async {
      final firestore = FakeFirebaseFirestore();
      final repo = ReparacionRepository(
        firestore: firestore,
        functions: MockFirebaseFunctions(),
      );

      final entregado = await repo.iniciarReparacion(
        idVehiculo: 'v1',
        idTaller: 't1',
        idPropietario: 'p1',
        placa: 'ENTREGADO',
      );
      await repo.cambiarEstado(
        idReparacion: entregado,
        nuevoEstado: estadoReparacionEntregado,
      );
      final cancelado = await repo.iniciarReparacion(
        idVehiculo: 'v2',
        idTaller: 't1',
        idPropietario: 'p1',
        placa: 'CANCELADO',
      );
      await repo.cambiarEstado(
        idReparacion: cancelado,
        nuevoEstado: 'cancelado',
      );
      await repo.iniciarReparacion(
        idVehiculo: 'v3',
        idTaller: 't1',
        idPropietario: 'p1',
        placa: 'EN CURSO',
      );

      final lista = await repo.watchReparacionesActivas('t1').first;

      expect(lista.map((r) => r.placa), ['EN CURSO']);
    },
  );

  test(
    'watchReparacionesActivas SI emite un listo_para_entrega: el coche sigue '
    'en el taller',
    () async {
      final firestore = FakeFirebaseFirestore();
      final repo = ReparacionRepository(
        firestore: firestore,
        functions: MockFirebaseFunctions(),
      );
      final id = await repo.iniciarReparacion(
        idVehiculo: 'v1',
        idTaller: 't1',
        idPropietario: 'p1',
        placa: 'P123-456',
      );
      await repo.cambiarEstado(
        idReparacion: id,
        nuevoEstado: 'listo_para_entrega',
      );

      final lista = await repo.watchReparacionesActivas('t1').first;

      expect(lista.length, 1);
      expect(lista.first.estado, 'listo_para_entrega');
    },
  );

  test(
    'cambiarEstado a entregado cierra el ticket desde el ultimo estado',
    () async {
      final firestore = FakeFirebaseFirestore();
      final repo = ReparacionRepository(
        firestore: firestore,
        functions: MockFirebaseFunctions(),
      );
      final id = await repo.iniciarReparacion(
        idVehiculo: 'v1',
        idTaller: 't1',
        idPropietario: 'p1',
        placa: 'P123-456',
      );
      await repo.cambiarEstado(
        idReparacion: id,
        nuevoEstado: 'listo_para_entrega',
      );

      await repo.cambiarEstado(
        idReparacion: id,
        nuevoEstado: estadoReparacionEntregado,
      );

      final doc = await firestore
          .collection(FirestoreCollections.reparaciones)
          .doc(id)
          .get();
      expect(doc.data()!['estado'], estadoReparacionEntregado);
      // El historial deja rastro de la entrega: es el unico registro de cuando
      // el coche salio del taller.
      expect(
        (doc.data()!['historial_estados'] as List).last['estado'],
        estadoReparacionEntregado,
      );
    },
  );

  test(
    'cambiarEstado a entregado se rechaza si el coche nunca llego al taller',
    () async {
      // 'pendiente_recepcion' es un coche que todavia no ha aparecido: no se
      // puede entregar lo que no se tiene. Ese ticket se cancela, no se
      // entrega — y como entregar revoca el vinculo y saca el ticket del
      // tablero sin vuelta atras, dejarlo pasar seria irreversible.
      final firestore = FakeFirebaseFirestore();
      final repo = ReparacionRepository(
        firestore: firestore,
        functions: MockFirebaseFunctions(),
      );
      await firestore
          .collection(FirestoreCollections.reparaciones)
          .doc('cot_c1')
          .set({
            'id_vehiculo': 'v1',
            'id_taller': 't1',
            'id_propietario': 'p1',
            'placa': 'P123-456',
            'estado': 'pendiente_recepcion',
            'historial_estados': const [],
            'fecha_creacion': Timestamp.fromDate(DateTime(2026)),
            'fecha_actualizacion': Timestamp.fromDate(DateTime(2026)),
          });

      await expectLater(
        repo.cambiarEstado(
          idReparacion: 'cot_c1',
          nuevoEstado: estadoReparacionEntregado,
        ),
        throwsA(isA<ArgumentError>()),
      );
    },
  );

  test(
    'entregar dos veces se rechaza en vez de reescribir el ticket',
    () async {
      final firestore = FakeFirebaseFirestore();
      final repo = ReparacionRepository(
        firestore: firestore,
        functions: MockFirebaseFunctions(),
      );
      final id = await repo.iniciarReparacion(
        idVehiculo: 'v1',
        idTaller: 't1',
        idPropietario: 'p1',
        placa: 'P123-456',
      );
      await repo.cambiarEstado(
        idReparacion: id,
        nuevoEstado: estadoReparacionEntregado,
      );

      // Sin esta guarda, el segundo toque anadiria otra entrada al historial y
      // volveria a disparar `revocarVinculoAlCerrarTicket` — que ya no revoca
      // dos veces, pero solo porque ESE lado tambien lo comprueba.
      await expectLater(
        repo.cambiarEstado(
          idReparacion: id,
          nuevoEstado: estadoReparacionEntregado,
        ),
        throwsA(isA<ArgumentError>()),
      );
    },
  );

  // --- A4b: "Recibir vehiculo" ya no crea el ticket, lo transiciona ---
  //
  // Los tickets los abre ahora la Cloud Function `onCotizacionAceptada` en
  // 'pendiente_recepcion'; aqui se siembran directamente en Firestore porque
  // esa via no existe en el cliente (y `firestore.rules` la prohibe).

  /// Siembra un ticket tal como lo escribe `onCotizacionAceptada`.
  Future<String> sembrarTicket(
    FakeFirebaseFirestore firestore, {
    String id = 'cot_c1',
    Map<String, dynamic> extra = const {},
  }) async {
    await firestore.collection(FirestoreCollections.reparaciones).doc(id).set({
      'id_cotizacion': 'c1',
      'id_vehiculo': 'v1',
      'id_taller': 't1',
      'id_propietario': 'p1',
      'placa': 'P123-456',
      'estado': 'pendiente_recepcion',
      'historial_estados': [
        {'estado': 'pendiente_recepcion', 'timestamp': DateTime.now()},
      ],
      ...extra,
    });
    return id;
  }

  // Ronda 5: recibir el vehiculo dejo de ser una escritura del cliente sobre
  // `reparaciones` y paso a ser el callable `recibirVehiculoDelTicket`, que
  // mueve el ticket Y otorga el vinculo con el vehiculo en una sola escritura
  // atomica (ver `functions/src/vinculoTaller.js`). La maquina de estados
  // —recibir dos veces, no arrastrar hacia atras, rechazar un ticket
  // cancelado— se prueba ahora del lado servidor, en
  // `functions/test/vinculo_taller.test.js`, que es donde vive. Lo que queda
  // por probar aqui es el contrato del repositorio: que llama al callable
  // correcto con el id correcto, y que traduce sus fallos a algo que la
  // pantalla sepa mostrar.

  test('recibirVehiculo llama al callable con el id del ticket', () async {
    final functions = _FakeFunctions(
      alLlamar: (nombre, params) {
        expect(nombre, 'recibirVehiculoDelTicket');
        expect(params, {'id_reparacion': 'r1'});
        return {'recibido_ahora': true};
      },
    );
    final repo = ReparacionRepository(
      firestore: FakeFirebaseFirestore(),
      functions: functions,
    );

    expect(await repo.recibirVehiculo(idReparacion: 'r1'), true);
  });

  test('recibirVehiculo propaga el no-op del servidor', () async {
    // `recibido_ahora: false` es "ya estaba recibido". El provider necesita
    // distinguirlo para no anunciar una recepcion que no ocurrio (hallazgo 2).
    final repo = ReparacionRepository(
      firestore: FakeFirebaseFirestore(),
      functions: _FakeFunctions(alLlamar: (_, _) => {'recibido_ahora': false}),
    );

    expect(await repo.recibirVehiculo(idReparacion: 'r1'), false);
  });

  test('un rechazo del servidor llega a la pantalla con SU mensaje, no con un '
      'error crudo de Firebase', () async {
    // Sin esta traduccion, el mecanico veia el `toString()` de una
    // FirebaseFunctionsException. El mensaje del servidor ("el ticket esta
    // cancelado: hace falta una cotizacion nueva") es el que dice que hacer.
    final repo = ReparacionRepository(
      firestore: FakeFirebaseFirestore(),
      functions: _FakeFunctions(
        alLlamar: (_, _) => throw FirebaseFunctionsException(
          code: 'failed-precondition',
          message: 'El ticket de este vehículo está cancelado.',
        ),
      ),
    );

    expect(
      () => repo.recibirVehiculo(idReparacion: 'r1'),
      throwsA(
        isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          'El ticket de este vehículo está cancelado.',
        ),
      ),
    );
  });

  test(
    'un ticket anterior a A4b (sin id_cotizacion y ya recibido) no se toca',
    () async {
      // Compatibilidad con produccion: los tickets abiertos por la via antigua
      // nacieron en 'recibido' y no tienen 'id_cotizacion'. El pipeline no
      // puede romperse con ellos. (Que recibirlos sea un no-op se prueba del
      // lado servidor desde la Ronda 5, ver vinculo_taller.test.js.)
      final firestore = FakeFirebaseFirestore();
      final repo = ReparacionRepository(
        firestore: firestore,
        functions: MockFirebaseFunctions(),
      );
      final id = await repo.iniciarReparacion(
        idVehiculo: 'v1',
        idTaller: 't1',
        idPropietario: 'p1',
        placa: 'P123-456',
      );

      await repo.cambiarEstado(idReparacion: id, nuevoEstado: 'en_revision');

      final doc = await firestore
          .collection(FirestoreCollections.reparaciones)
          .doc(id)
          .get();
      expect(doc.data()!['estado'], 'en_revision');
      expect(doc.data()!.containsKey('id_cotizacion'), isFalse);
    },
  );

  test(
    'cambiarEstado sigue prohibiendo el retroceso con el indice desplazado',
    () async {
      // Insertar 'pendiente_recepcion' al principio de estadosReparacion
      // desplazo todos los indices; la comprobacion es relativa, asi que
      // volver a 'pendiente_recepcion' desde 'recibido' debe seguir siendo un
      // retroceso.
      final firestore = FakeFirebaseFirestore();
      final repo = ReparacionRepository(
        firestore: firestore,
        functions: MockFirebaseFunctions(),
      );
      final id = await sembrarTicket(firestore);
      await repo.cambiarEstado(idReparacion: id, nuevoEstado: 'recibido');

      expect(
        () => repo.cambiarEstado(
          idReparacion: id,
          nuevoEstado: 'pendiente_recepcion',
        ),
        throwsArgumentError,
      );
    },
  );
}

/// Doble de `FirebaseFunctions` con lo justo para probar el repositorio: no
/// hay `MockHttpsCallable` generado y regenerar los mocks por esto seria
/// desproporcionado.
class _FakeFunctions extends Fake implements FirebaseFunctions {
  final Object? Function(String nombre, dynamic parametros) alLlamar;

  _FakeFunctions({required this.alLlamar});

  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) =>
      _FakeCallable(nombre: name, alLlamar: alLlamar);
}

class _FakeCallable extends Fake implements HttpsCallable {
  final String nombre;
  final Object? Function(String nombre, dynamic parametros) alLlamar;

  _FakeCallable({required this.nombre, required this.alLlamar});

  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async =>
      _FakeResult<T>(alLlamar(nombre, parameters) as T);
}

class _FakeResult<T> extends Fake implements HttpsCallableResult<T> {
  @override
  final T data;

  _FakeResult(this.data);
}
