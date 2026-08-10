import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:mockito/mockito.dart';
import 'package:autodoc/core/providers/auth_session_provider.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/features/splash/presentation/pages/splash_screen.dart';

import '../../../../helpers/test_helpers.mocks.dart';

void main() {
  // UserProfileProvider builds a UserService() eagerly, which touches
  // FirebaseFirestore.instance on construction. Register a fake Firebase
  // "[DEFAULT]" app via the method-channel mocks so that doesn't throw
  // (matching the pattern used in dashboard_screen_vehicle_fetch_test.dart).
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUp(() {
    // A brand-new, first-time visitor: no remembered session and
    // onboarding not yet marked complete.
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'shows onboarding for a first-time, logged-out visitor even at a desktop viewport width',
    (tester) async {
      await Firebase.initializeApp();

      // Desktop-class width (Responsive.isDesktop is true for >= 1200).
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockAuth = MockFirebaseAuth();
      final streamController = StreamController<User?>.broadcast();
      addTearDown(streamController.close);
      when(
        mockAuth.idTokenChanges(),
      ).thenAnswer((_) => streamController.stream);
      when(mockAuth.currentUser).thenReturn(null);

      final authSessionProvider = AuthSessionProvider(firebaseAuth: mockAuth);
      final userProfileProvider = UserProfileProvider();

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(path: '/', builder: (_, _) => const SplashScreen()),
          GoRoute(
            path: '/onboarding',
            builder: (_, _) => const Scaffold(body: Text('ONBOARDING_SCREEN')),
          ),
          GoRoute(
            path: '/login',
            builder: (_, _) => const Scaffold(body: Text('LOGIN_SCREEN')),
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthSessionProvider>.value(
              value: authSessionProvider,
            ),
            ChangeNotifierProvider<UserProfileProvider>.value(
              value: userProfileProvider,
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
          ),
        ),
      );

      // The splash screen waits 3 seconds before navigating.
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      expect(find.text('ONBOARDING_SCREEN'), findsOneWidget);
      expect(find.text('LOGIN_SCREEN'), findsNothing);
    },
  );
}
