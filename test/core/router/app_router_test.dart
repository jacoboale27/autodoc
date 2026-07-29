import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:autodoc/core/router/app_router.dart';
import 'package:autodoc/core/providers/auth_session_provider.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FakeAuthSessionProvider extends ChangeNotifier
    implements AuthSessionProvider {
  final bool _isLoggedIn;
  final String _currentUid;

  FakeAuthSessionProvider({bool isLoggedIn = false, String currentUid = ''})
    : _isLoggedIn = isLoggedIn,
      _currentUid = currentUid;

  @override
  bool get isLoggedIn => _isLoggedIn;

  @override
  String get currentUid => _currentUid;

  @override
  User? get user => null;

  @override
  String? get error => null;

  @override
  void clearError() {}

  @override
  Future<void> refreshUser() async {}
}

class FakeUserProfileProvider extends ChangeNotifier
    implements UserProfileProvider {
  final UserModel? _userData;
  final bool _isLoading;
  final bool _hasAttemptedFetch;

  FakeUserProfileProvider({
    UserModel? userData,
    bool isLoading = false,
    bool hasAttemptedFetch = true,
  }) : _userData = userData,
       _isLoading = isLoading,
       _hasAttemptedFetch = hasAttemptedFetch;

  @override
  UserModel? get userData => _userData;

  @override
  bool get isLoading => _isLoading;

  @override
  bool get hasAttemptedFetch => _hasAttemptedFetch;

  @override
  String? get fetchedUserId => _userData?.idUsuario;

  @override
  bool hasAttemptedFetchFor(String userId) => _hasAttemptedFetch;

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

void main() {
  testWidgets('AppRouter Redirect Logic Direct Unit Tests', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final BuildContext context = tester.element(find.byType(SizedBox));

    String? evaluateRedirect({
      required bool isLoggedIn,
      required UserModel? userData,
      required String path,
    }) {
      final authProvider = FakeAuthSessionProvider(
        isLoggedIn: isLoggedIn,
        currentUid: isLoggedIn ? 'uid_1' : '',
      );
      final profileProvider = FakeUserProfileProvider(
        userData: userData,
        hasAttemptedFetch: true,
      );
      final router = createAppRouter(authProvider, profileProvider);

      final uri = Uri.parse(path);
      final state = GoRouterState(
        router.configuration,
        uri: uri,
        matchedLocation: uri.path,
        name: null,
        path: uri.path,
        fullPath: uri.path,
        pathParameters: const {},
        extra: null,
        pageKey: ValueKey(uri.path),
      );

      return appRouterRedirect(authProvider, profileProvider, context, state);
    }

    // 1. Unauthenticated user on /login -> null (stays on /login)
    expect(
      evaluateRedirect(isLoggedIn: false, userData: null, path: '/login'),
      null,
    );

    // 2. Unauthenticated user on protected /dashboard -> /login
    expect(
      evaluateRedirect(isLoggedIn: false, userData: null, path: '/dashboard'),
      '/login',
    );

    // 3. Authenticated user without Firestore profile on /login -> /profile_setup
    expect(
      evaluateRedirect(isLoggedIn: true, userData: null, path: '/login'),
      '/profile_setup',
    );

    // 4. Authenticated user without Firestore profile trying to access protected /dashboard -> /profile_setup
    expect(
      evaluateRedirect(isLoggedIn: true, userData: null, path: '/dashboard'),
      '/profile_setup',
    );

    // 5. Authenticated user with Propietario profile on /login -> /dashboard
    final ownerUser = UserModel(
      idUsuario: 'uid_1',
      nombreCompleto: 'Juan Owner',
      correo: 'owner@test.com',
      rol: 'Propietario',
      fechaRegistro: DateTime.now(),
    );
    expect(
      evaluateRedirect(isLoggedIn: true, userData: ownerUser, path: '/login'),
      '/dashboard',
    );

    // 6. Authenticated user with Mecanico profile on /login -> /mechanic_dashboard
    final mechanicUser = UserModel(
      idUsuario: 'uid_1',
      nombreCompleto: 'Carlos Mecanico',
      correo: 'mecanico@test.com',
      rol: 'Mecanico',
      fechaRegistro: DateTime.now(),
    );
    expect(
      evaluateRedirect(
        isLoggedIn: true,
        userData: mechanicUser,
        path: '/login',
      ),
      '/mechanic_dashboard',
    );

    // 7. Authenticated user with existing profile on /profile_setup -> /dashboard
    expect(
      evaluateRedirect(
        isLoggedIn: true,
        userData: ownerUser,
        path: '/profile_setup',
      ),
      '/dashboard',
    );
    expect(
      evaluateRedirect(
        isLoggedIn: true,
        userData: mechanicUser,
        path: '/profile_setup',
      ),
      '/mechanic_dashboard',
    );
  });

  testWidgets('Renders 404 page on unknown route', (WidgetTester tester) async {
    final authProvider = FakeAuthSessionProvider(isLoggedIn: true, currentUid: 'uid_1');
    final ownerUser = UserModel(
      idUsuario: 'uid_1',
      nombreCompleto: 'Juan Owner',
      correo: 'owner@test.com',
      rol: 'Propietario',
      fechaRegistro: DateTime.now(),
    );
    final profileProvider = FakeUserProfileProvider(userData: ownerUser, hasAttemptedFetch: true);
    final router = createAppRouter(
      authProvider,
      profileProvider,
      initialLocation: '/non_existent_route',
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    expect(find.text('Página no encontrada (404)'), findsOneWidget);
  });
}
