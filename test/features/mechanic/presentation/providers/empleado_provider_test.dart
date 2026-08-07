import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:autodoc/features/mechanic/data/repositories/empleado_repository.dart';
import 'package:autodoc/features/mechanic/presentation/providers/empleado_provider.dart';

import '../../../../helpers/test_helpers.mocks.dart';

void main() {
  test('watchTaller puebla empleados desde el repositorio', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = EmpleadoRepository(firestore: firestore);
    await firestore
        .collection('talleres')
        .doc('t1')
        .collection('empleados')
        .doc('e1')
        .set({
          'id_taller_propietario': 't1',
          'nombre_completo': 'A',
          'correo': 'a@x.com',
          'activo': true,
        });

    final provider = EmpleadoProvider(repository: repo);
    provider.watchTaller('t1');
    await Future.delayed(Duration.zero);

    expect(provider.empleados.length, 1);
  });

  test(
    'crearEmpleado transiciona isLoading y expone error cuando el callable falla',
    () async {
      // No hay MockHttpsCallable generado en test_helpers.mocks.dart (solo
      // FirebaseFunctions), asi que se limita la cobertura al camino de error:
      // basta con que httpsCallable() lance para ejercitar el try/catch del
      // provider sin necesitar simular una HttpsCallableResult real.
      final firestore = FakeFirebaseFirestore();
      final repo = EmpleadoRepository(firestore: firestore);
      final mockFunctions = MockFirebaseFunctions();
      when(
        mockFunctions.httpsCallable('crearEmpleadoTaller'),
      ).thenThrow(Exception('network error'));

      final provider = EmpleadoProvider(
        repository: repo,
        functions: mockFunctions,
      );

      final loadingStates = <bool>[];
      provider.addListener(() => loadingStates.add(provider.isLoading));

      final result = await provider.crearEmpleado(
        correo: 'a@x.com',
        password: '123456',
        nombreCompleto: 'A',
        rol: 'Mecanico',
      );

      expect(result, false);
      expect(provider.isLoading, false);
      expect(provider.error, isNotNull);
      expect(loadingStates.first, true);
      expect(loadingStates.last, false);
    },
  );
}
