import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:autodoc/features/admin/data/services/admin_service.dart';
import 'package:autodoc/features/admin/data/repositories/admin_repository.dart';
import 'package:autodoc/features/admin/presentation/providers/admin_provider.dart';

import '../../../../helpers/test_helpers.mocks.dart';

/// Repositorio dummy: crearUsuario/eliminarUsuarioPermanente nunca llegan a
/// tocarlo en el camino de error probado aquí (fallan antes, en el
/// callable), así que basta con no forzar Firebase.initializeApp() vía un
/// AdminRepository real (mismo enfoque que admin_service_test.dart).
class _DummyAdminRepository implements AdminRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'crearUsuario transiciona isLoading y expone error cuando el callable falla',
    () async {
      final mockFunctions = MockFirebaseFunctions();
      when(
        mockFunctions.httpsCallable('superUserCreateAccount'),
      ).thenThrow(Exception('network error'));

      final service = AdminService(
        functions: mockFunctions,
        repository: _DummyAdminRepository(),
      );
      final provider = AdminProvider(adminService: service);

      final loadingStates = <bool>[];
      provider.addListener(() => loadingStates.add(provider.isLoading));

      final result = await provider.crearUsuario(
        nombreCompleto: 'A',
        correo: 'a@x.com',
        rol: 'Propietario',
      );

      expect(result, false);
      expect(provider.isLoading, false);
      expect(provider.error, isNotNull);
      expect(loadingStates.first, true);
      expect(loadingStates.last, false);
    },
  );

  test(
    'eliminarUsuarioPermanente expone error cuando el callable falla',
    () async {
      final mockFunctions = MockFirebaseFunctions();
      when(
        mockFunctions.httpsCallable('superUserDeleteAccount'),
      ).thenThrow(Exception('network error'));

      final service = AdminService(
        functions: mockFunctions,
        repository: _DummyAdminRepository(),
      );
      final provider = AdminProvider(adminService: service);

      await provider.eliminarUsuarioPermanente('uid1');

      expect(provider.isLoading, false);
      expect(provider.error, isNotNull);
    },
  );
}
