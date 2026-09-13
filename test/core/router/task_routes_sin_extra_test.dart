import 'package:firebase_auth_mocks/firebase_auth_mocks.dart' as firebase_mocks;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:autodoc/core/router/app_router.dart';
import 'package:autodoc/core/providers/auth_session_provider.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/models/user_model.dart';
import 'package:autodoc/l10n/app_localizations.dart';

/// Las rutas `/task_config` y `/task_complete` leen `state.extra` con un cast
/// INCONDICIONAL (`state.extra as MaintenanceTask`). `extra` no sobrevive a una
/// recarga del navegador ni existe al entrar por URL, asi que el constructor de
/// la pagina recibia null y reventaba con un TypeError.
///
/// No hace falta teclear la URL para dispararlo: basta con estar en la pantalla
/// y pulsar F5. Es el mismo tipo de callejon sin salida que cerro UX-02 para el
/// error de inicializacion y para el 404.
///
/// Las dos rutas se empujan desde `/alerts` (alerts_screen.dart:618,628), que
/// es donde viven las tareas: devolver ahi es recuperacion util, no un 404 de
/// consolacion.
///
/// Fakes locales copiados de app_router_unknown_route_test.dart, para que este
/// test no dependa de otro archivo.
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
  User? get user => isLoggedIn
      ? firebase_mocks.MockUser(uid: currentUid, isEmailVerified: true)
      : null;

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

  for (final ruta in ['/task_config', '/task_complete']) {
    testWidgets('$ruta sin `extra` no revienta: devuelve a /alerts', (
      tester,
    ) async {
      final router = createAppRouter(
        buildAuthProvider(),
        buildProfileProvider(),
        initialLocation: ruta,
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );
      await tester.pumpAndSettle();

      // Lo que se afirma es que el CAST ya no es lo que falla. `/alerts` no se
      // puede pintar en este harness minimo —no tiene providers ni Firebase, y
      // muere con un null check al construirse—, asi que exigir cero
      // excepciones probaria la pobreza del harness y no la del router. Se
      // afirma en cambio que la excepcion, si la hay, no menciona el cast, que
      // es el defecto que este test existe para vigilar.
      final excepcion = tester.takeException();
      expect(
        excepcion?.toString() ?? '',
        isNot(contains('MaintenanceTask')),
        reason:
            'Recargar la pagina estando en $ruta pierde `extra`, y el cast '
            'incondicional lo convertia en un TypeError. La persona veia una '
            'pantalla rota de la que no podia salir.',
      );
      expect(
        excepcion?.toString() ?? '',
        isNot(contains("Map<String, dynamic>")),
        reason: 'Mismo cast, en /task_complete.',
      );
      expect(
        router.routeInformationProvider.value.uri.path,
        '/alerts',
        reason:
            'Sin la tarea no hay nada que configurar, pero si donde elegir '
            'otra: /alerts es la pantalla que empuja estas dos rutas.',
      );
    });
  }
}
