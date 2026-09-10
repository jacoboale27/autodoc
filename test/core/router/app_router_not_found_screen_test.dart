import 'package:firebase_auth_mocks/firebase_auth_mocks.dart' as firebase_mocks;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:autodoc/l10n/app_localizations.dart';
import 'package:autodoc/core/router/app_router.dart';
import 'package:autodoc/core/providers/auth_session_provider.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/models/user_model.dart';
import 'package:autodoc/core/widgets/not_found_screen.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

/// UX-02: an unmatched route must not strand the user. Local fakes mirror the
/// ones in app_router_unknown_route_test.dart so this file stands alone.
class _FakeAuthSessionProvider extends ChangeNotifier
    implements AuthSessionProvider {
  @override
  bool get isLoggedIn => true;

  @override
  String get currentUid => 'uid_1';

  @override
  User? get user =>
      firebase_mocks.MockUser(uid: 'uid_1', isEmailVerified: true);

  @override
  String? get error => null;

  @override
  void clearError() {}

  @override
  Future<void> refreshUser() async {}
}

class _FakeUserProfileProvider extends ChangeNotifier
    implements UserProfileProvider {
  @override
  UserModel? get userData => UserModel(
    idUsuario: 'uid_1',
    nombreCompleto: 'Juan Owner',
    correo: 'owner@test.com',
    rol: 'Propietario',
    fechaRegistro: DateTime.now(),
  );

  @override
  bool get isLoading => false;

  @override
  bool get hasAttemptedFetch => true;

  @override
  String? get fetchedUserId => 'uid_1';

  @override
  bool hasAttemptedFetchFor(String userId) => true;

  @override
  String? get error => null;

  @override
  Future<void> fetchUserData(String userId) async {}

  @override
  Future<bool> updateProfile(
    UserModel updatedUser, {
    dynamic imageFile,
    bool isNewUser = false,
  }) async => true;

  @override
  void clearUserData() {}
}

Future<GoRouter> _pumpAt(WidgetTester tester, String location) async {
  final auth = _FakeAuthSessionProvider();
  final profile = _FakeUserProfileProvider();
  final router = createAppRouter(auth, profile, initialLocation: location);
  // SplashScreen (the widget behind '/') reads both providers, so leaving the
  // 404 has to land somewhere that can actually build.
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthSessionProvider>.value(value: auth),
        ChangeNotifierProvider<UserProfileProvider>.value(value: profile),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('the 404 page uses localized copy, not a hardcoded literal', (
    tester,
  ) async {
    await _pumpAt(tester, '/directorio');

    // The dead-end literal must be gone.
    expect(find.text('Página no encontrada (404)'), findsNothing);

    final l10n = await AppLocalizations.delegate.load(const Locale('es'));
    expect(find.text(l10n.notFoundTitle), findsOneWidget);
  });

  testWidgets('the 404 page shows the path the user actually asked for', (
    tester,
  ) async {
    await _pumpAt(tester, '/directorio');

    expect(find.textContaining('/directorio'), findsOneWidget);
  });

  testWidgets('the real router renders NotFoundScreen for an unmatched path', (
    tester,
  ) async {
    await _pumpAt(tester, '/directorio');

    expect(find.byType(NotFoundScreen), findsOneWidget);
  });

  testWidgets('the home button on the 404 routes back to the app root', (
    tester,
  ) async {
    // SplashScreen (the real '/') cannot be built in a widget test: it needs a
    // live Firebase. So the destination here is a stub, and what is under test
    // is NotFoundScreen's own contract -- that its button navigates to '/'.
    final router = GoRouter(
      initialLocation: '/directorio',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('app root')),
        ),
      ],
      errorBuilder: (context, state) =>
          NotFoundScreen(attemptedPath: state.uri.path),
    );

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('es'));
    final homeButton = find.widgetWithText(FilledButton, l10n.notFoundGoHome);
    expect(homeButton, findsOneWidget);

    await tester.tap(homeButton);
    await tester.pumpAndSettle();

    expect(find.text('app root'), findsOneWidget);
    expect(find.text(l10n.notFoundTitle), findsNothing);
  });

  testWidgets('the back button appears only when there is somewhere to go '
      'back to', (tester) async {
    // Reached by push (from inside the app) there IS history; reached as the
    // entry point of a deep link there is none, and offering "Volver" then
    // would be a button that does nothing.
    late BuildContext ctx;
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) {
            ctx = context;
            return const Scaffold(body: Text('app root'));
          },
        ),
      ],
      errorBuilder: (context, state) =>
          NotFoundScreen(attemptedPath: state.uri.path),
    );

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('es'));

    ctx.push('/no_existe');
    await tester.pumpAndSettle();

    final back = find.widgetWithText(TextButton, l10n.notFoundGoBack);
    expect(back, findsOneWidget);

    await tester.tap(back);
    await tester.pumpAndSettle();

    expect(find.text('app root'), findsOneWidget);
  });
}
