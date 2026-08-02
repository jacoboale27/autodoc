import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/features/mechanic/data/repositories/reparacion_repository.dart';
import 'package:autodoc/core/constants/firestore_collections.dart';

void main() {
  test('iniciarReparacion crea documento con estado recibido', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = ReparacionRepository(firestore: firestore);

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
      final repo = ReparacionRepository(firestore: firestore);
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
    final repo = ReparacionRepository(firestore: firestore);
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
    final repo = ReparacionRepository(firestore: firestore);
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
      final repo = ReparacionRepository(firestore: firestore);
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
      final repo = ReparacionRepository(firestore: firestore);

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
      final repo = ReparacionRepository(firestore: firestore);

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
      final repo = ReparacionRepository(firestore: firestore);
      final idCreado = await repo.iniciarReparacion(
        idVehiculo: 'v1',
        idTaller: 't1',
        idPropietario: 'p1',
        placa: 'P123-456',
      );
      await repo.cambiarEstado(
        idReparacion: idCreado,
        nuevoEstado: 'listo_para_entrega',
      );

      final idEncontrado = await repo.buscarReparacionActiva(
        idVehiculo: 'v1',
        idTaller: 't1',
      );

      expect(idEncontrado, idCreado);
    },
  );

  test(
    'buscarReparacionActiva no mezcla tickets de otro vehículo o taller',
    () async {
      final firestore = FakeFirebaseFirestore();
      final repo = ReparacionRepository(firestore: firestore);
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

  test('watchReparacionesActivas emite reparaciones del taller', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = ReparacionRepository(firestore: firestore);
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
}
