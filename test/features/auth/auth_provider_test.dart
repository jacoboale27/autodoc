import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:autodoc/features/auth/presentation/providers/auth_provider.dart';
import '../../helpers/test_helpers.mocks.dart';

// UX-04: estos cinco casos lanzaban una **cadena suelta** (`thenThrow('email-
// already-in-use')`) y luego afirmaban que `provider.error` la contenia. Con
// `_error = e.toString()` eso pasaba siempre, pero no probaba nada del manejo
// real de errores de Auth: en produccion lo que llega es un
// `FirebaseAuthException`, y de el se estaba pintando el `[firebase_auth/...]`
// entero, en ingles, en un SnackBar.
//
// Ahora lanzan lo que lanza Firebase y afirman las dos mitades que importan:
// que el codigo NO sale a la pantalla, y que el mensaje sigue siendo
// ACCIONABLE. Lo segundo no es adorno — los errores de Auth son los unicos de
// toda la app que la persona puede resolver por si misma, y taparlos con "algo
// fallo" habria sido cambiar un defecto por otro.
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

  group('AuthProvider — Initial State', () {
    test('initial state is correct', () {
      expect(authProvider.isLoading, false);
      expect(authProvider.error, null);
    });
  });

  group('AuthProvider — signIn (email)', () {
    test('signIn sets loading state correctly', () async {
      when(
        mockAuthService.signInWithEmail('test@test.com', 'password'),
      ).thenAnswer((_) async => null);

      final future = authProvider.signIn('test@test.com', 'password');

      expect(authProvider.isLoading, true);

      await future;

      expect(authProvider.isLoading, false);
      expect(authProvider.error, null);
      verify(
        mockAuthService.signInWithEmail('test@test.com', 'password'),
      ).called(1);
    });

    test('signIn handles generic error correctly', () async {
      when(
        mockAuthService.signInWithEmail('test@test.com', 'password'),
      ).thenThrow(FirebaseAuthException(code: 'invalid-credential'));

      await authProvider.signIn('test@test.com', 'password');

      expect(authProvider.isLoading, false);
      expect(authProvider.error, isNot(contains('invalid-credential')));
      expect(authProvider.error, isNot(contains('firebase_auth')));
      expect(authProvider.error, contains('contrasena'));
    });

    test('signIn with non-email uses admin login path', () async {
      when(
        mockAdminAuthService.loginAsAdmin('adminuser', 'password'),
      ).thenAnswer((_) async => null);

      await authProvider.signIn('adminuser', 'password');

      verifyNever(mockAuthService.signInWithEmail(any, any));
      verify(
        mockAdminAuthService.loginAsAdmin('adminuser', 'password'),
      ).called(1);
    });

    test('signIn error clears on next signIn attempt', () async {
      // First, fail
      when(
        mockAuthService.signInWithEmail('test@test.com', 'wrong'),
      ).thenThrow('wrong-password');
      await authProvider.signIn('test@test.com', 'wrong');
      expect(authProvider.error, isNotNull);

      // Then succeed — error should clear
      when(
        mockAuthService.signInWithEmail('test@test.com', 'correct'),
      ).thenAnswer((_) async => null);
      await authProvider.signIn('test@test.com', 'correct');
      expect(authProvider.error, null);
    });
  });

  group('AuthProvider — signOut', () {
    test('signOut calls service', () async {
      when(mockAuthService.signOut()).thenAnswer((_) async {});

      await authProvider.signOut();

      expect(authProvider.isLoading, false);
      expect(authProvider.error, null);
      verify(mockAuthService.signOut()).called(1);
    });
  });

  group('AuthProvider — registration', () {
    test('register success calls sendEmailVerification', () async {
      final mockCredential = _MockUserCredential();
      final mockUser = _MockUser();
      when(mockCredential.user).thenReturn(mockUser);
      when(
        mockAuthService.registerWithEmail('new@test.com', 'pass123'),
      ).thenAnswer((_) async => mockCredential);
      when(mockAuthService.sendEmailVerification()).thenAnswer((_) async {});

      final result = await authProvider.register('new@test.com', 'pass123');

      expect(result, true);
      expect(authProvider.isLoading, false);
      verify(mockAuthService.sendEmailVerification()).called(1);
    });

    test('register failure returns false', () async {
      when(
        mockAuthService.registerWithEmail('fail@test.com', 'pass'),
      ).thenThrow(FirebaseAuthException(code: 'email-already-in-use'));

      final result = await authProvider.register('fail@test.com', 'pass');

      expect(result, false);
      expect(authProvider.error, isNot(contains('email-already-in-use')));
      // Sigue diciendo QUE hacer: ese correo ya tiene cuenta.
      expect(authProvider.error, contains('ya tiene una cuenta'));
    });

    test('register returns false when user is null', () async {
      final mockCredential = _MockUserCredential();
      when(mockCredential.user).thenReturn(null);
      when(
        mockAuthService.registerWithEmail('test@test.com', 'pass123'),
      ).thenAnswer((_) async => mockCredential);

      final result = await authProvider.register('test@test.com', 'pass123');

      expect(result, false);
    });
  });

  group('AuthProvider — password reset', () {
    test('sendPasswordReset succeeds', () async {
      when(
        mockAuthService.sendPasswordReset('test@test.com'),
      ).thenAnswer((_) async {});

      final result = await authProvider.sendPasswordReset('test@test.com');

      expect(result, true);
      expect(authProvider.isLoading, false);
      verify(mockAuthService.sendPasswordReset('test@test.com')).called(1);
    });

    test('sendPasswordReset on network error returns false', () async {
      when(
        mockAuthService.sendPasswordReset('test@test.com'),
      ).thenThrow(FirebaseAuthException(code: 'network-request-failed'));

      final result = await authProvider.sendPasswordReset('test@test.com');

      expect(result, false);
      expect(authProvider.error, isNot(contains('network-request-failed')));
      expect(authProvider.error, contains('conexion'));
    });
  });

  group('AuthProvider — email verification', () {
    test('sendEmailVerification succeeds', () async {
      when(mockAuthService.sendEmailVerification()).thenAnswer((_) async {});

      final result = await authProvider.sendEmailVerification();

      expect(result, true);
      verify(mockAuthService.sendEmailVerification()).called(1);
    });

    test('sendEmailVerification failure returns false with error', () async {
      when(
        mockAuthService.sendEmailVerification(),
      ).thenThrow(FirebaseAuthException(code: 'too-many-requests'));

      final result = await authProvider.sendEmailVerification();

      expect(result, false);
      expect(authProvider.error, isNot(contains('too-many-requests')));
      expect(authProvider.error, contains('Demasiados intentos'));
    });

    test('refreshEmailVerificationStatus calls reloadCurrentUser', () async {
      when(mockAuthService.reloadCurrentUser()).thenAnswer((_) async {});
      when(mockAuthService.isCurrentUserEmailVerified).thenReturn(true);

      final verified = await authProvider.refreshEmailVerificationStatus();

      expect(verified, true);
      verify(mockAuthService.reloadCurrentUser()).called(1);
    });

    test(
      'refreshEmailVerificationStatus returns false when not verified',
      () async {
        when(mockAuthService.reloadCurrentUser()).thenAnswer((_) async {});
        when(mockAuthService.isCurrentUserEmailVerified).thenReturn(false);

        final verified = await authProvider.refreshEmailVerificationStatus();

        expect(verified, false);
      },
    );
  });

  group('AuthProvider — signInWithGoogle', () {
    test(
      'AuthProvider — signInWithGoogle success bypasses extra steps',
      () async {
        final mockCredential = _MockUserCredential();
        final mockUser = _MockUser();
        when(mockCredential.user).thenReturn(mockUser);
        when(
          mockAuthService.signInWithGoogle(),
        ).thenAnswer((_) async => mockCredential);

        final result = await authProvider.signInWithGoogle();

        expect(result, true);
        expect(authProvider.isLoading, false);
        expect(authProvider.error, null);
        verify(mockAuthService.signInWithGoogle()).called(1);
      },
    );

    test('signInWithGoogle failure returns false with error', () async {
      when(
        mockAuthService.signInWithGoogle(),
      ).thenThrow(FirebaseAuthException(code: 'popup-closed-by-user'));

      final result = await authProvider.signInWithGoogle();

      expect(result, false);
      expect(authProvider.isLoading, false);
      expect(authProvider.error, isNotNull);
      expect(authProvider.error, isNot(contains('popup-closed-by-user')));
      verify(mockAuthService.signInWithGoogle()).called(1);
    });
  });

  group('AuthProvider — clearError', () {
    test('clearError sets error to null', () async {
      when(
        mockAuthService.signInWithEmail('x@x.com', 'pass'),
      ).thenThrow('some error');
      await authProvider.signIn('x@x.com', 'pass');
      expect(authProvider.error, isNotNull);

      await authProvider.clearError();
      expect(authProvider.error, null);
    });
  });
}

// ── Minimal mock helpers ──────────────────────────────────────────────────────

class _MockUserCredential extends Mock implements UserCredential {}

class _MockUser extends Mock implements User {}
