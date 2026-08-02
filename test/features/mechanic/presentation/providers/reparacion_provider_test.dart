// test/features/mechanic/presentation/providers/reparacion_provider_test.dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/features/mechanic/data/repositories/reparacion_repository.dart';
import 'package:autodoc/features/mechanic/presentation/providers/reparacion_provider.dart';

void main() {
  test('watchTaller puebla reparaciones desde el repositorio', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = ReparacionRepository(firestore: firestore);
    await repo.iniciarReparacion(
      idVehiculo: 'v1',
      idTaller: 't1',
      idPropietario: 'p1',
      placa: 'P1',
    );

    final provider = ReparacionProvider(repository: repo);
    provider.watchTaller('t1');
    await Future.delayed(Duration.zero);

    expect(provider.reparaciones.length, 1);
  });

  test(
    'cambiarEstado delega en el repositorio y no lanza si es válido',
    () async {
      final firestore = FakeFirebaseFirestore();
      final repo = ReparacionRepository(firestore: firestore);
      final id = await repo.iniciarReparacion(
        idVehiculo: 'v1',
        idTaller: 't1',
        idPropietario: 'p1',
        placa: 'P1',
      );

      final provider = ReparacionProvider(repository: repo);
      await provider.cambiarEstado(id, 'en_revision');

      expect(provider.error, isNull);
    },
  );
}
