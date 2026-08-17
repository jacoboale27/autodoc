import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:autodoc/core/providers/auth_session_provider.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/services/push_notification_service.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/features/splash/presentation/pages/splash_screen.dart';

import '../../../../helpers/test_helpers.mocks.dart';
import '../../../../support/contrast.dart';
import '../../../../support/entry_harness.dart';

class _FakePushNotificationService extends Fake
    implements PushNotificationService {
  @override
  Future<void> updateUserToken(String userId) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  Future<StreamController<User?>> pumpRouter(
    WidgetTester tester, {
    required double width,
    required double height,
    List<GoRoute> extraRoutes = const [],
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Firebase.initializeApp();
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final mockAuth = MockFirebaseAuth();
    final controller = StreamController<User?>.broadcast();
    addTearDown(controller.close);
    when(mockAuth.idTokenChanges()).thenAnswer((_) => controller.stream);
    when(mockAuth.currentUser).thenReturn(null);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthSessionProvider>.value(
            value: AuthSessionProvider(firebaseAuth: mockAuth),
          ),
          ChangeNotifierProvider<UserProfileProvider>.value(
            value: UserProfileProvider(),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: GoRouter(
            initialLocation: '/',
            routes: [
              GoRoute(path: '/', builder: (_, _) => const SplashScreen()),
              GoRoute(
                path: '/onboarding',
                builder: (_, _) => const Scaffold(body: Text('ONBOARDING')),
              ),
              GoRoute(
                path: '/login',
                builder: (_, _) => const Scaffold(body: Text('LOGIN')),
              ),
              GoRoute(
                path: '/dashboard',
                builder: (_, _) => const Scaffold(body: Text('DASHBOARD')),
              ),
              GoRoute(
                path: '/profile_setup',
                builder: (_, _) => const Scaffold(body: Text('PROFILE_SETUP')),
              ),
              ...extraRoutes,
            ],
          ),
        ),
      ),
    );
    return controller;
  }

  testWidgets('un visitante sin sesion sale del splash en menos de 1 segundo', (
    tester,
  ) async {
    final controller = await pumpRouter(tester, width: 375, height: 812);
    // Simula el comportamiento real de Firebase: `idTokenChanges()` siempre
    // emite su primer valor pronto (aqui, "sin sesion") en vez de quedarse
    // callado para siempre como haria un stream nunca-emitido.
    controller.add(null);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();
    expect(
      find.text('ONBOARDING'),
      findsOneWidget,
      reason: 'el splash sigue reteniendo al usuario mas de 900 ms',
    );
  });

  testWidgets(
    'un usuario logueado en frio no cae en /login mientras la sesion resuelve async '
    '(regresion: la sesion tardaba en emitir y el splash la leia en null)',
    (tester) async {
      PushNotificationService.setInstanceForTesting(
        _FakePushNotificationService(),
      );
      final controller = await pumpRouter(tester, width: 375, height: 812);
      // No emite nada todavia: simula que `idTokenChanges()` tarda en
      // resolver, igual que en un arranque en frio real donde el provider
      // se construye justo antes de runApp y el splash ya esta en su
      // primer frame antes de que el stream reporte nada.
      await tester.pump(const Duration(milliseconds: 300));

      // Ahora, dentro del presupuesto acotado de 2 s que el splash le da a
      // la sesion, llega la primera emision real: un usuario logueado.
      final mockUser = MockUser();
      when(mockUser.uid).thenReturn('user123');
      controller.add(mockUser);
      await tester.pump();

      // Deja correr el resto del presupuesto y el resto del flujo (sondeo
      // de perfil, retardo minimo anti-parpadeo) hasta asentarse.
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      expect(
        find.text('LOGIN'),
        findsNothing,
        reason:
            'un usuario con sesion real NUNCA debe terminar en /login: '
            'el splash decidio "no hay sesion" antes de que el stream '
            'de auth tuviera oportunidad de resolver.',
      );
      expect(
        find.text('ONBOARDING'),
        findsNothing,
        reason:
            'un usuario con sesion real NUNCA debe terminar varado en '
            '/onboarding por leer session.user antes de que resuelva.',
      );
      // El perfil nunca resuelve en este harness (no hay fetch real), asi
      // que tras agotar tambien su presupuesto de 2 s el splash cae en
      // /profile_setup: confirma que efectivamente tomo la rama de
      // "usuario autenticado", no que se quedo colgado en el splash.
      expect(find.text('PROFILE_SETUP'), findsOneWidget);
    },
  );

  testWidgets('no hay barra de progreso falsa', (tester) async {
    final source = File(
      'lib/features/splash/presentation/pages/splash_screen.dart',
    ).readAsStringSync();
    expect(
      source.contains('TweenAnimationBuilder'),
      isFalse,
      reason: 'la barra de 3 s no medía ninguna carga real',
    );
    expect(
      RegExp(r'Duration\(seconds:\s*3\)').hasMatch(source),
      isFalse,
      reason: 'sigue la espera fija de 3 segundos',
    );
  });

  testWidgets('el nombre de la app se lee en los dos temas', (tester) async {
    for (final brightness in Brightness.values) {
      await pumpEntryNoSettle(
        tester,
        const SplashBranding(),
        width: 375,
        brightness: brightness,
      );
      final context = tester.element(find.byType(SplashBranding));
      final colors = context.appColors;
      for (final key in const <String>['splash-auto', 'splash-doc']) {
        final text = tester.widget<Text>(find.byKey(ValueKey(key)));
        expect(
          contrastRatio(text.style!.color!, colors.primary),
          greaterThanOrEqualTo(3.0),
          reason: '$key ilegible en $brightness',
        );
      }
    }
  });

  testWidgets('no desborda en horizontal de telefono', (tester) async {
    final errors = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = errors.add;
    await pumpRouter(tester, width: 800, height: 400);
    await tester.pump(const Duration(milliseconds: 100));
    FlutterError.onError = previous;
    expect(
      errors,
      isEmpty,
      reason: '${errors.map((e) => e.exception).toList()}',
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });
}
