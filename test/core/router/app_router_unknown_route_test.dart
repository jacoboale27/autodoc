import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:autodoc/core/router/app_router.dart';
import 'package:autodoc/core/providers/auth_session_provider.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/models/user_model.dart';

/// Minimal fakes mirroring the ones in app_router_test.dart, kept local so
/// this regression test has no cross-file dependency.
class _FakeAuthSessionProvider extends ChangeNotifier
    implements AuthSessionProvider {
  final bool _isLoggedIn;
  final String _currentUid;

  _FakeAuthSessionProvider({bool isLoggedIn = false, String currentUid = ''})
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

class _FakeUserProfileProvider extends ChangeNotifier
    implements UserProfileProvider {
  final UserModel? _userData;
  final bool _isLoading;
  final bool _hasAttemptedFetch;

  _FakeUserProfileProvider({
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
  // Both providers report a fully authenticated, profiled Propietario so
  // `appRouterRedirect` never diverts navigation away from the paths under
  // test.
  _FakeAuthSessionProvider buildAuthProvider() =>
      _FakeAuthSessionProvider(isLoggedIn: true, currentUid: 'uid_1');

  _FakeUserProfileProvider buildProfileProvider() => _FakeUserProfileProvider(
    userData: UserModel(
      idUsuario: 'uid_1',
      nombreCompleto: 'Juan Owner',
      correo: 'owner@test.com',
      rol: 'Propietario',
      fechaRegistro: DateTime.now(),
    ),
    hasAttemptedFetch: true,
  );

  testWidgets('an unmatched path renders the real app router 404 page, not a '
      'blank/broken screen', (tester) async {
    // Exercise the actual createAppRouter (not a hand-copied stand-in), so
    // this test breaks if the real errorBuilder or its text ever changes.
    final router = createAppRouter(
      buildAuthProvider(),
      buildProfileProvider(),
      initialLocation: '/directorio', // the wrong path TestSprite used
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('Página no encontrada (404)'), findsOneWidget);
  });

  test('the real app router has /workshop_directory registered but not '
      '/directorio', () {
    // WorkshopDirectoryScreen lives inside the app's ShellRoute/MainScaffold
    // and depends on providers (VehicleProvider, etc.) that aren't wired up
    // in this lightweight test, so actually building that screen would
    // require a much heavier widget-tree setup. Instead we introspect the
    // real router's route configuration directly, which still ties the
    // assertion to the actual registered paths rather than a copy.
    final router = createAppRouter(buildAuthProvider(), buildProfileProvider());

    final registeredMatch = router.configuration.findMatch(
      Uri.parse('/workshop_directory'),
    );
    expect(
      registeredMatch.isError,
      isFalse,
      reason: '/workshop_directory should be a registered route',
    );

    final bogusMatch = router.configuration.findMatch(Uri.parse('/directorio'));
    expect(
      bogusMatch.isError,
      isTrue,
      reason: '/directorio should NOT be a registered route',
    );
  });
}
