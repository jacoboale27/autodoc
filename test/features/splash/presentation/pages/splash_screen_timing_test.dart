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
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/features/splash/presentation/pages/splash_screen.dart';

import '../../../../helpers/test_helpers.mocks.dart';
import '../../../../support/contrast.dart';
import '../../../../support/entry_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  Future<void> pumpRouter(
    WidgetTester tester, {
    required double width,
    required double height,
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
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('un visitante sin sesion sale del splash en menos de 1 segundo', (
    tester,
  ) async {
    await pumpRouter(tester, width: 375, height: 812);
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();
    expect(
      find.text('ONBOARDING'),
      findsOneWidget,
      reason: 'el splash sigue reteniendo al usuario mas de 900 ms',
    );
  });

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
