import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:autodoc/firebase_options.dart';
import 'package:autodoc/features/splash/presentation/pages/splash_screen.dart';
import 'package:autodoc/features/onboarding/presentation/pages/onboarding_screen.dart';
import 'package:autodoc/features/auth/presentation/pages/auth_screen.dart';
import 'package:autodoc/features/dashboard/presentation/pages/dashboard_screen.dart';
import 'package:autodoc/features/profile/presentation/pages/profile_setup_screen.dart';
import 'package:autodoc/features/auth/presentation/providers/auth_provider.dart';
import 'package:autodoc/features/profile/presentation/pages/user_profile_screen.dart';
import 'package:autodoc/features/dashboard/presentation/pages/garage_screen.dart';
import 'package:autodoc/features/dashboard/presentation/pages/alerts_screen.dart';
import 'package:autodoc/features/dashboard/presentation/providers/alert_provider.dart';
import 'package:autodoc/features/dashboard/presentation/providers/vehicle_provider.dart';
import 'package:autodoc/features/dashboard/presentation/pages/vehicle_profile_screen.dart';
import 'package:autodoc/features/mechanic/presentation/pages/vehicle_search_screen.dart';
import 'package:autodoc/core/models/vehicle_model.dart';
import 'package:autodoc/core/providers/theme_provider.dart';
import 'package:autodoc/features/mechanic/presentation/pages/initiate_service_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => VehicleProvider()),
        ChangeNotifierProvider(create: (_) => AlertProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

final GoRouter _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const AuthScreen(isLogin: true),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const AuthScreen(isLogin: false),
    ),
    GoRoute(
      path: '/profile_setup',
      builder: (context, state) => const ProfileSetupScreen(),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/vehicle_profile',
      builder: (context, state) {
        final vehicle = state.extra as VehicleModel;
        return VehicleProfileScreen(vehicle: vehicle);
      },
    ),
    GoRoute(
      path: '/user_profile',
      builder: (context, state) => const UserProfileScreen(),
    ),
    GoRoute(
      path: '/garage',
      builder: (context, state) => const GarageScreen(),
    ),
    GoRoute(
      path: '/alerts',
      builder: (context, state) => const AlertsScreen(),
    ),
    GoRoute(
      path: '/mechanic_search',
      builder: (context, state) => const VehicleSearchScreen(),
    ),
    GoRoute(
      path: '/initiate_service',
      builder: (context, state) {
        final vehicle = state.extra as VehicleModel;
        return InitiateServiceScreen(vehicle: vehicle);
      },
    ),
  ],
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    
    return MaterialApp.router(
      title: 'AutoDoc',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      themeMode: themeProvider.themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF522C81),
          primary: const Color(0xFF522C81),
          surface: const Color(0xFFF7F6F8),
        ),
        textTheme: GoogleFonts.interTextTheme(),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF522C81),
          primary: const Color(0xFF98FFD9),
          brightness: Brightness.dark,
          surface: const Color(0xFF0F172A),
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      ),
    );
  }
}
