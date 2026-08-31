// test/support/router_harness.dart
//
// Monta la app con su **enrutador real** (`createAppRouter`) en una ubicacion
// concreta, y devuelve el `GoRouter` para poder observarle la URL.
//
// Existe porque hay defectos que solo viven en la relacion entre la
// navegacion y la barra de direcciones (hallazgo §2.14 del QA del
// 2026-08-28): una pantalla montada con `home:` no tiene URL que observar, y
// un `GoRouter` sintetico de test no reproduce los guards ni las
// transiciones reales. Los demas harness de `test/support/` montan pantallas
// sueltas; este monta la app.

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:autodoc/core/models/user_model.dart';
import 'package:autodoc/core/providers/auth_session_provider.dart';
import 'package:autodoc/core/providers/language_provider.dart';
import 'package:autodoc/core/providers/notification_center_provider.dart';
import 'package:autodoc/core/providers/theme_provider.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/router/app_router.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/features/auth/presentation/providers/auth_provider.dart';
import 'package:autodoc/features/chat/presentation/providers/chat_provider.dart';
import 'package:autodoc/features/mechanic/data/services/verificacion_service.dart';
import 'package:autodoc/features/mechanic/presentation/providers/verificacion_provider.dart';
import 'package:autodoc/l10n/app_localizations.dart';

import '../helpers/test_helpers.mocks.dart';
// Los dos harness definen `FakeUserProfileProvider`; aqui se usa el de
// `entry_harness`, que es el que acepta un `UserModel` arbitrario.
import 'chat_harness.dart' hide FakeUserProfileProvider;
import 'entry_harness.dart';

class FakeRouterAuthSession extends ChangeNotifier
    implements AuthSessionProvider {
  FakeRouterAuthSession({required this.isLoggedIn, required this.uid});

  final String uid;

  @override
  final bool isLoggedIn;

  @override
  String get currentUid => isLoggedIn ? uid : '';

  @override
  User? get user => null;

  @override
  String? get error => null;

  @override
  void clearError() {}

  @override
  Future<void> refreshUser() async {}
}

/// El viewport por defecto de un widget test son 800 px de alto, y elementos
/// como el enlace de cambio de modo de `AuthScreen` caen por debajo: sin
/// agrandarlo, `tap()` deriva un offset que no impacta en el widget y el test
/// falla por un motivo que no es el defecto que se persigue.
const Size kRouterViewport = Size(1000, 1600);

/// URL que el enrutador reporta ahora mismo — el mismo valor que go_router
/// entrega al navegador para pintar la barra de direcciones.
String urlDe(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

/// Monta la app real en [initialLocation] y devuelve su `GoRouter`.
///
/// Los providers son los que las pantallas alcanzables desde aqui exigen al
/// montarse. Se usan los providers **reales** con un Firestore falso donde se
/// puede, en vez de dobles del provider entero: un doble podria esconder que
/// la pantalla destino ni siquiera construye, que es justo lo que estos tests
/// tienen que detectar.
/// Deja el arbol estable sin usar `pumpAndSettle`.
///
/// `pumpAndSettle` no termina en algunas rutas de esta app (se agota el
/// timeout), asi que no sirve como forma general de asentar. Estos pumps
/// acotados bastan para que una navegacion y su transicion terminen, y no
/// dependen de que no quede ninguna animacion viva en la pantalla.
Future<void> asentarRuta(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

Future<GoRouter> pumpAppAt(
  WidgetTester tester,
  String initialLocation, {
  UserModel? usuario,
  bool sesionIniciada = false,
  FakeChatProvider? chat,
  bool asentarConSettle = true,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  tester.view.physicalSize = kRouterViewport;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final mockAuthService = MockAuthService();
  when(mockAuthService.isEmailPasswordUser).thenReturn(true);

  final perfilUsuario = usuario ?? testUser();
  final perfil = FakeUserProfileProvider(userData: perfilUsuario);
  // El uid de la sesion tiene que ser el del propio perfil: `resolveRedirect`
  // comprueba `hasAttemptedFetchFor(currentUid)`, y si no casan cree que el
  // perfil aun no se ha cargado y desvia al splash con `?redirect=`.
  final sesion = FakeRouterAuthSession(
    isLoggedIn: sesionIniciada,
    uid: perfilUsuario.idUsuario,
  );
  final router = createAppRouter(
    sesion,
    perfil,
    initialLocation: initialLocation,
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(
            authService: mockAuthService,
            adminAuthService: MockAdminAuthService(),
          ),
        ),
        ChangeNotifierProvider<UserProfileProvider>.value(value: perfil),
        ChangeNotifierProvider<AuthSessionProvider>.value(value: sesion),
        ChangeNotifierProvider<VerificacionProvider>(
          create: (_) => VerificacionProvider(
            service: VerificacionService(firestore: FakeFirebaseFirestore()),
          ),
        ),
        ChangeNotifierProvider<ChatProvider>.value(
          value: chat ?? FakeChatProvider(),
        ),
        ChangeNotifierProvider<NotificationCenterProvider>(
          create: (_) =>
              NotificationCenterProvider(firestore: FakeFirebaseFirestore()),
        ),
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
        ChangeNotifierProvider<LanguageProvider>(
          create: (_) => LanguageProvider(),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.light,
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  if (asentarConSettle) {
    await tester.pumpAndSettle();
  } else {
    await asentarRuta(tester);
  }
  return router;
}
