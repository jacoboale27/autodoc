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

  group('AuthProvider Tests', () {
    test('initial state is correct', () {
      expect(authProvider.isLoading, false);
      expect(authProvider.error, null);
    });

    test('signIn sets loading state correctly', () async {
      when(mockAuthService.signInWithEmail('test@test.com', 'password'))
          .thenAnswer((_) async => null);

      final future = authProvider.signIn('test@test.com', 'password');
      
      expect(authProvider.isLoading, true);
      
      await future;
      
      expect(authProvider.isLoading, false);
      expect(authProvider.error, null);
      verify(mockAuthService.signInWithEmail('test@test.com', 'password')).called(1);
    });

    test('signIn handles error correctly', () async {
      when(mockAuthService.signInWithEmail('test@test.com', 'password'))
          .thenThrow('Auth Error');

      await authProvider.signIn('test@test.com', 'password');
      
      expect(authProvider.isLoading, false);
      expect(authProvider.error, 'Auth Error');
    });

    test('signOut clears state', () async {
      when(mockAuthService.signOut()).thenAnswer((_) async {});

      await authProvider.signOut();

      expect(authProvider.isLoading, false);
      expect(authProvider.error, null);
      verify(mockAuthService.signOut()).called(1);
    });
  });
}
