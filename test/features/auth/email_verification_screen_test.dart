import 'dart:async';

import 'package:autodoc/core/providers/auth_session_provider.dart';
import 'package:autodoc/core/providers/language_provider.dart';
import 'package:autodoc/core/providers/theme_provider.dart';
import 'package:autodoc/core/router/app_router.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/core/services/push_notification_service.dart';
import 'package:autodoc/features/auth/presentation/pages/auth_screen.dart';
import 'package:autodoc/features/auth/presentation/pages/email_verification_screen.dart';
import 'package:autodoc/features/auth/presentation/providers/auth_provider.dart';
import 'package:autodoc/l10n/app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_helpers.mocks.dart';
import '../../core/providers/auth_session_provider_test.dart'
    show FakePushNotificationService;
import '../../core/router/app_router_test.dart' show FakeUserProfileProvider;
import '../../support/entry_harness.dart' show testUser;

// `UserInfo` de firebase_auth no expone un constructor generativo publico,
// asi que el proveedor se simula con un doble.
class _ProviderInfo extends Mock implements UserInfo {
  _ProviderInfo(this.providerId);
  @override
  final String providerId;
}

class _Credential extends Mock implements UserCredential {
  _Credential(this.user);
  @override
  final User user;
}

void main() {
  late MockFirebaseAuth firebase;
  late MockUser unverified;
  late MockUser verified;
  late MockAuthService service;
  late AuthSessionProvider session;
  late StreamController<User?> events;
  late GoRouter router;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    firebase = MockFirebaseAuth();
    unverified = MockUser();
    verified = MockUser();
    for (final user in [unverified, verified]) {
      when(user.uid).thenReturn('uid');
      when(user.email).thenReturn('fixture@example.test');
    }
    when(unverified.emailVerified).thenReturn(false);
    when(verified.emailVerified).thenReturn(true);
    when(unverified.reload()).thenAnswer((_) async {});
    when(firebase.currentUser).thenReturn(unverified);
    events = StreamController<User?>.broadcast();
    when(firebase.idTokenChanges()).thenAnswer((_) => events.stream);
    PushNotificationService.setInstanceForTesting(
      FakePushNotificationService(),
    );
    session = AuthSessionProvider(firebaseAuth: firebase);
    service = MockAuthService();
    when(service.sendEmailVerification()).thenAnswer((_) async {});
    when(service.signOut()).thenAnswer((_) async {
      when(firebase.currentUser).thenReturn(null);
      events.add(null);
    });
  });

  tearDown(() async {
    router.dispose();
    await events.close();
    session.dispose();
  });

  Future<void> pumpGate(
    WidgetTester tester, {
    bool hasProfile = false,
    String initialLocation = '/chat/fixture',
    bool signedIn = true,
    Locale locale = const Locale('es'),
  }) async {
    if (signedIn) await session.refreshUser();
    final profile = FakeUserProfileProvider(
      userData: hasProfile ? testUser().copyWith(idUsuario: 'uid') : null,
    );
    // Keep the production redirect and gate, replacing data-heavy destination
    // pages with markers so this test never initializes live Firebase services.
    router = GoRouter(
      initialLocation: initialLocation,
      refreshListenable: session,
      redirect: (context, state) =>
          appRouterRedirect(session, profile, context, state),
      routes: [
        GoRoute(
          path: '/login',
          builder: (_, _) => const AuthScreen(isLogin: true),
        ),
        GoRoute(
          path: '/register',
          builder: (_, _) => const AuthScreen(isLogin: false),
        ),
        GoRoute(
          path: '/verify_email',
          builder: (_, _) => const EmailVerificationScreen(),
        ),
        for (final path in ['/dashboard', '/profile_setup', '/chat/:id'])
          GoRoute(path: path, builder: (_, _) => Text(path)),
      ],
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthSessionProvider>.value(value: session),
          ChangeNotifierProvider<AuthProvider>(
            create: (_) => AuthProvider(
              authService: service,
              adminAuthService: MockAdminAuthService(),
            ),
          ),
          ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
          ChangeNotifierProvider<LanguageProvider>(
            create: (_) => LanguageProvider(),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          // AuthScreen lee la extension AppColors del tema: sin AppTheme.light
          // el build revienta con un null check antes de llegar al gate.
          theme: AppTheme.light,
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String location() => router.routeInformationProvider.value.uri.path;

  testWidgets('deep links and back cannot dismiss the gate', (tester) async {
    await pumpGate(tester);
    expect(location(), '/verify_email');
    expect(find.byType(EmailVerificationScreen), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.byType(TextButton), findsNWidgets(2));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(location(), '/verify_email');
    router.go('/dashboard?redirect=/profile_setup');
    await tester.pumpAndSettle();
    expect(location(), '/verify_email');
  });

  testWidgets('resend does not unlock access, sign out returns to login', (
    tester,
  ) async {
    await pumpGate(tester);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(EmailVerificationScreen)),
    )!;
    await tester.tap(find.text(l10n.authResendEmail));
    await tester.pumpAndSettle();
    verify(service.sendEmailVerification()).called(1);
    expect(location(), '/verify_email');
    expect(find.text(l10n.authEmailResent), findsOneWidget);
    await tester.tap(find.text(l10n.upSignOut));
    await tester.pumpAndSettle();
    expect(location(), '/login');
  });

  testWidgets('un cierre de sesion que falla NO dice que fallo el correo', (
    tester,
  ) async {
    // GAPS-05, gap 3-bis de H-01: las tres acciones del gate comparten
    // `_run`, y su `catch (_)` pintaba SIEMPRE «no se pudo enviar el correo».
    // Un cierre de sesion fallido dejaba a la persona buscando en su bandeja
    // de entrada un correo que nadie habia intentado mandar.
    when(
      service.signOut(),
    ).thenThrow(FirebaseAuthException(code: 'network-request-failed'));
    await pumpGate(tester);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(EmailVerificationScreen)),
    )!;

    await tester.tap(find.text(l10n.upSignOut));
    await tester.pumpAndSettle();

    expect(find.text(l10n.authSignOutError), findsOneWidget);
    expect(
      find.text(l10n.authSendEmailError),
      findsNothing,
      reason: 'el mensaje del correo no puede aparecer al cerrar sesion',
    );
    expect(location(), '/verify_email');
  });
  for (final hasProfile in [false, true]) {
    testWidgets('awaits reload then routes with hasProfile=$hasProfile', (
      tester,
    ) async {
      await pumpGate(tester, hasProfile: hasProfile);
      final reloaded = Completer<void>();
      when(unverified.reload()).thenAnswer((_) async {
        await reloaded.future;
        when(firebase.currentUser).thenReturn(verified);
      });
      final l10n = AppLocalizations.of(
        tester.element(find.byType(EmailVerificationScreen)),
      )!;
      await tester.tap(find.text(l10n.authAlreadyVerified));
      await tester.pump();
      expect(location(), '/verify_email');
      expect(session.user?.emailVerified, false);
      reloaded.complete();
      await tester.pumpAndSettle();
      expect(session.user?.emailVerified, true);
      expect(location(), hasProfile ? '/dashboard' : '/profile_setup');
    });
  }

  for (final fails in [false, true]) {
    testWidgets('unconfirmed or failed reload keeps gate: failure=$fails', (
      tester,
    ) async {
      await pumpGate(tester, locale: const Locale('en'));
      if (fails) when(unverified.reload()).thenThrow(Exception('offline'));
      final l10n = AppLocalizations.of(
        tester.element(find.byType(EmailVerificationScreen)),
      )!;
      await tester.tap(find.text(l10n.authAlreadyVerified));
      await tester.pumpAndSettle();
      expect(location(), '/verify_email');
      expect(find.text(l10n.authVerificationNotDetected), findsOneWidget);
    });
  }

  for (final registration in [false, true]) {
    testWidgets(
      'email authentication enters gate: registration=$registration',
      (tester) async {
        Future<UserCredential> authenticate() async {
          events.add(unverified);
          return _Credential(unverified);
        }

        when(
          service.signInWithEmail(any, any),
        ).thenAnswer((_) => authenticate());
        when(
          service.registerWithEmail(any, any),
        ).thenAnswer((_) => authenticate());
        await pumpGate(
          tester,
          signedIn: false,
          initialLocation: registration ? '/register' : '/login',
        );
        await tester.enterText(
          find.byKey(const ValueKey('auth-email-field')),
          'fixture@example.test',
        );
        await tester.enterText(
          find.byKey(const ValueKey('auth-password-field')),
          'fixture123',
        );
        await tester.ensureVisible(find.byKey(const ValueKey('auth-submit')));
        await tester.tap(find.byKey(const ValueKey('auth-submit')));
        await tester.pumpAndSettle();
        expect(location(), '/verify_email');
        expect(find.byType(AlertDialog), findsNothing);
      },
    );
  }

  for (final hasProfile in [false, true]) {
    testWidgets('verified Google login bypasses gate: hasProfile=$hasProfile', (
      tester,
    ) async {
      when(verified.providerData).thenReturn([_ProviderInfo('google.com')]);
      when(service.signInWithGoogle()).thenAnswer((_) async {
        when(firebase.currentUser).thenReturn(verified);
        events.add(verified);
        return _Credential(verified);
      });
      await pumpGate(
        tester,
        signedIn: false,
        hasProfile: hasProfile,
        initialLocation: '/login',
      );
      final l10n = AppLocalizations.of(
        tester.element(find.byType(AuthScreen)),
      )!;
      await tester.ensureVisible(find.text(l10n.authGoogleLogin));
      await tester.tap(find.text(l10n.authGoogleLogin));
      await tester.pumpAndSettle();
      expect(find.byType(EmailVerificationScreen), findsNothing);
      expect(location(), hasProfile ? '/dashboard' : '/profile_setup');
    });
  }
}
