import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:autodoc/core/models/user_model.dart';
import 'package:autodoc/core/providers/language_provider.dart';
import 'package:autodoc/core/providers/notification_center_provider.dart';
import 'package:autodoc/core/providers/theme_provider.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/widgets/main_scaffold.dart';
import 'package:autodoc/core/widgets/app_top_nav_bar.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/l10n/app_localizations.dart';

/// Doble del provider de perfil que solo fija el rol y el nombre.
///
/// **Implementa** `UserProfileProvider` en vez de extenderlo, y no es una
/// preferencia de estilo: la clase real inicializa
/// `final UserService _userService = UserService()` en la declaración del
/// campo, y `UserService` hace `FirebaseFirestore.instance` en la suya.
/// Extenderla ejecuta ambos inicializadores y **lanza** en un widget test sin
/// `Firebase.initializeApp()`.
class FakeProfileProvider extends ChangeNotifier
    implements UserProfileProvider {
  FakeProfileProvider(this.rol, {String nombreCompleto = 'Ana Pérez'})
    : _nombreCompleto = nombreCompleto;
  final String rol;
  final String _nombreCompleto;

  @override
  UserModel? get userData => UserModel(
    idUsuario: 'test-uid',
    nombreCompleto: _nombreCompleto,
    correo: 'ana@example.com',
    rol: rol,
    fechaRegistro: DateTime(2026, 1, 1),
  );

  @override
  bool get isLoading => false;
  @override
  bool get hasAttemptedFetch => true;
  @override
  String? get fetchedUserId => 'test-uid';
  @override
  String? get error => null;
  @override
  bool hasAttemptedFetchFor(String userId) => true;
  @override
  Future<void> fetchUserData(String userId) async {}
  @override
  Future<bool> updateProfile(
    UserModel updatedUser, {
    XFile? imageFile,
    bool isNewUser = false,
  }) async => true;
  @override
  void clearUserData() {}
}

List<ChangeNotifierProvider> _shellProviders(
  String rol, {
  String nombreCompleto = 'Ana Pérez',
}) {
  return [
    ChangeNotifierProvider<UserProfileProvider>.value(
      value: FakeProfileProvider(rol, nombreCompleto: nombreCompleto),
    ),
    ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
    ChangeNotifierProvider<LanguageProvider>(create: (_) => LanguageProvider()),
    ChangeNotifierProvider<NotificationCenterProvider>(
      create: (_) =>
          NotificationCenterProvider(firestore: FakeFirebaseFirestore()),
    ),
  ];
}

/// Monta `MainScaffold` con un `ShellRoute` real de go_router, con los
/// providers que necesita cualquiera de sus presentaciones de navegación.
Future<void> pumpShell(
  WidgetTester tester, {
  required double width,
  required String rol,
  String location = '/dashboard',
  // Permite a un test inyectar contenido real (con su propia semantica) en
  // el `child` de la `ShellRoute`, en vez del `Text` de relleno por
  // defecto. Lo usa `main_scaffold_large_content_semantics_test.dart` para
  // comprobar que el limite semantico explicito que envuelve `child` en la
  // rama `WindowClass.large` no aplana ni traga el contenido real.
  Widget Function(String path)? bodyBuilder,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final buildBody = bodyBuilder ?? (path) => Center(child: Text('body $path'));

  final router = GoRouter(
    initialLocation: location,
    routes: [
      ShellRoute(
        builder: (context, state, child) => MainScaffold(child: child),
        routes: [
          for (final path in [
            '/dashboard',
            '/garage',
            '/chat_list',
            '/workshop_directory',
            '/user_profile',
          ])
            GoRoute(path: path, builder: (context, state) => buildBody(path)),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    MultiProvider(
      providers: _shellProviders(rol),
      child: MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Monta `AppTopNavBar` sola, con los cinco providers que necesita:
/// `GoRouterState`, `ThemeProvider`, `LanguageProvider`,
/// `NotificationCenterProvider` y `UserProfileProvider`.
Future<void> pumpTopNav(
  WidgetTester tester, {
  required double width,
  String userName = 'Ana Pérez',
  Brightness brightness = Brightness.light,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final router = GoRouter(
    initialLocation: '/dashboard',
    routes: [
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const Scaffold(
          body: Column(
            children: [
              AppTopNavBar(),
              Expanded(child: SizedBox()),
            ],
          ),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    MultiProvider(
      providers: _shellProviders('Propietario', nombreCompleto: userName),
      child: MaterialApp.router(
        theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
}
