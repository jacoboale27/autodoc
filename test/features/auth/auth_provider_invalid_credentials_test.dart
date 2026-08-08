import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:autodoc/features/auth/presentation/providers/auth_provider.dart';
import '../../helpers/test_helpers.mocks.dart';

void main() {
  late MockAuthService mockAuthService;
  late MockAdminAuthService mockAdminAuthService;
  late AuthProvider authProvider;

  setUp(() {
    mockAuthService = MockAuthService();
    mockAdminAuthService = MockAdminAuthService();
    authProvider = AuthProvider(
      authService: mockAuthService,
      adminAuthService: mockAdminAuthService,
    );
  });

  test(
    'signIn returns false and sets an error for credentials Firebase rejects',
    () async {
      // Mock the auth service to throw when given invalid credentials
      when(
        mockAuthService.signInWithEmail(
          'definitely-not-a-real-account@example.invalid',
          'wrong-password-123',
        ),
      ).thenThrow('user-not-found');

      final result = await authProvider.signIn(
        'definitely-not-a-real-account@example.invalid',
        'wrong-password-123',
      );

      expect(result, isFalse);
      expect(authProvider.error, isNotNull);
    },
  );
}
