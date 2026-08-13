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
import 'package:autodoc/core/widgets/navigation/app_bottom_nav.dart';
import 'package:autodoc/core/widgets/navigation/app_nav_rail.dart';
import 'package:autodoc/core/widgets/app_top_nav_bar.dart';
import 'package:autodoc/core/theme/app_theme.dart';

/// Doble del provider de perfil que solo fija el rol.
///
/// **Implementa** `UserProfileProvider` en vez de extenderlo, y no es una
/// preferencia de estilo: la clase real inicializa
/// `final UserService _userService = UserService()` en la declaración del
/// campo, y `UserService` hace `FirebaseFirestore.instance` en la suya.
/// Extenderla ejecuta ambos inicializadores y **lanza** en un widget test sin
/// `Firebase.initializeApp()`.
class _FakeProfileProvider extends ChangeNotifier
    implements UserProfileProvider {
  _FakeProfileProvider(this.rol);
  final String rol;

  @override
  UserModel? get userData => UserModel(
    idUsuario: 'test-uid',
    nombreCompleto: 'Ana Pérez',
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

Future<void> pumpShell(
  WidgetTester tester, {
  required double width,
  required String rol,
  String location = '/dashboard',
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

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
            GoRoute(
              path: path,
              builder: (context, state) => Center(child: Text('body $path')),
            ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<UserProfileProvider>.value(
          value: _FakeProfileProvider(rol),
        ),
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
        ChangeNotifierProvider<LanguageProvider>(
          create: (_) => LanguageProvider(),
        ),
        ChangeNotifierProvider<NotificationCenterProvider>(
          create: (_) =>
              NotificationCenterProvider(firestore: FakeFirebaseFirestore()),
        ),
      ],
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('rol Propietario', () {
    testWidgets('compact (375) usa la barra inferior', (tester) async {
      await pumpShell(tester, width: 375, rol: 'Propietario');

      expect(find.byType(AppBottomNav), findsOneWidget);
      expect(find.byType(AppNavRail), findsNothing);
      expect(find.byType(AppTopNavBar), findsNothing);
    });

    testWidgets('medium (768) usa el rail colapsado', (tester) async {
      await pumpShell(tester, width: 768, rol: 'Propietario');

      expect(find.byType(AppNavRail), findsOneWidget);
      expect(
        tester.widget<AppNavRail>(find.byType(AppNavRail)).extended,
        isFalse,
      );
      expect(find.byType(AppBottomNav), findsNothing);
    });

    testWidgets('expanded (1024) usa el rail extendido', (tester) async {
      await pumpShell(tester, width: 1024, rol: 'Propietario');

      expect(find.byType(AppNavRail), findsOneWidget);
      expect(
        tester.widget<AppNavRail>(find.byType(AppNavRail)).extended,
        isTrue,
      );
      expect(find.byType(AppBottomNav), findsNothing);
    });

    testWidgets('large (1440) usa la barra superior', (tester) async {
      await pumpShell(tester, width: 1440, rol: 'Propietario');

      expect(find.byType(AppTopNavBar), findsOneWidget);
      expect(find.byType(AppBottomNav), findsNothing);
      expect(find.byType(AppNavRail), findsNothing);
    });

    testWidgets('exactamente una presentación de nav por ancho', (
      tester,
    ) async {
      for (final width in [
        320.0,
        375.0,
        600.0,
        768.0,
        840.0,
        1024.0,
        // 1200 se añade en la Task 6: AppTopNavBar desborda ahí hasta que esa
        // tarea la envuelva en un SingleChildScrollView (ver plan Fase 2).
        1440.0,
      ]) {
        await pumpShell(tester, width: width, rol: 'Propietario');

        final present = [
          tester.widgetList(find.byType(AppBottomNav)).length,
          tester.widgetList(find.byType(AppNavRail)).length,
          tester.widgetList(find.byType(AppTopNavBar)).length,
        ];

        expect(
          present.where((count) => count > 0).length,
          1,
          reason: 'a $width px hay ${present.where((c) => c > 0).length} navs',
        );
        expect(tester.takeException(), isNull, reason: 'overflow @$width');
      }
    });

    testWidgets('la ruta actual marca el destino correcto', (tester) async {
      await pumpShell(
        tester,
        width: 375,
        rol: 'Propietario',
        location: '/workshop_directory',
      );

      expect(
        tester.widget<AppBottomNav>(find.byType(AppBottomNav)).currentIndex,
        3,
      );
    });
  });

  group('rol Mecanico', () {
    testWidgets('compact y medium usan drawer, no sidebar fijo', (
      tester,
    ) async {
      for (final width in [375.0, 768.0]) {
        await pumpShell(tester, width: width, rol: 'Mecanico');

        // DrawerController no construye su child (el Drawer) mientras está
        // cerrado, así que find.byType(Drawer) no lo encuentra en reposo.
        // La presencia real de la navegación por drawer se verifica en la
        // propiedad drawer del Scaffold.
        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
        expect(scaffold.drawer, isNotNull, reason: 'sin drawer @$width');
        expect(find.byType(AppBottomNav), findsNothing);
      }
    });

    testWidgets('expanded y large usan sidebar fijo, sin drawer', (
      tester,
    ) async {
      for (final width in [1024.0, 1440.0]) {
        await pumpShell(tester, width: width, rol: 'Mecanico');

        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
        expect(scaffold.drawer, isNull, reason: 'drawer @$width');
        expect(tester.takeException(), isNull, reason: 'overflow @$width');
      }
    });
  });
}
