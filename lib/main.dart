import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:autodoc/l10n/app_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:autodoc/core/providers/language_provider.dart';
import 'package:autodoc/core/services/translation_service.dart';
import 'package:autodoc/firebase_options.dart';
import 'package:autodoc/core/router/app_router.dart';
import 'package:autodoc/features/auth/presentation/providers/auth_provider.dart';
import 'package:autodoc/features/dashboard/presentation/providers/alert_provider.dart';
import 'package:autodoc/features/dashboard/presentation/providers/vehicle_provider.dart';
import 'package:autodoc/core/providers/theme_provider.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/features/admin/presentation/providers/admin_provider.dart';
import 'package:autodoc/features/admin/presentation/providers/admin_dashboard_provider.dart';
import 'package:autodoc/core/services/notification_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Manejando mensaje en background: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Inicializar Firebase
  try {
    debugPrint("=== [AutoDoc Init] Inicializando Firebase ===");
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint("=== [AutoDoc Init] Firebase inicializado con éxito ===");
  } catch (e, stack) {
    debugPrint("=== [AutoDoc Init] ERROR al inicializar Firebase: $e ===");
    debugPrint(stack.toString());
  }

  // 2. Configurar Firebase Messaging y permisos de notificaciones
  try {
    debugPrint("=== [AutoDoc Init] Configurando Firebase Messaging ===");
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    ).timeout(
      const Duration(seconds: 5),
    );
    debugPrint("=== [AutoDoc Init] Permisos de notificación configurados ===");
  } catch (e, stack) {
    debugPrint("=== [AutoDoc Init] ERROR en Firebase Messaging: $e ===");
    debugPrint(stack.toString());
  }

  // 3. Inicializar Local Notifications y FCM en foreground
  try {
    debugPrint("=== [AutoDoc Init] Inicializando NotificationService ===");
    await NotificationService().initialize().timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        debugPrint("=== [AutoDoc Init] TIMEOUT en NotificationService.initialize(). Continuando... ===");
      },
    );
    debugPrint("=== [AutoDoc Init] NotificationService inicializado ===");
  } catch (e, stack) {
    debugPrint("=== [AutoDoc Init] ERROR al inicializar NotificationService: $e ===");
    debugPrint(stack.toString());
  }

  // 4. Inicializar Hive y cache de traducción
  try {
    debugPrint("=== [AutoDoc Init] Inicializando Hive y TranslationService ===");
    await Hive.initFlutter(); // ¡IMPORTANTE! Inicializa Hive para Flutter antes de abrir boxes.
    await TranslationService().initialize().timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        debugPrint("=== [AutoDoc Init] TIMEOUT al inicializar TranslationService. Continuando... ===");
      },
    );
    debugPrint("=== [AutoDoc Init] TranslationService inicializado con éxito ===");
  } catch (e, stack) {
    debugPrint("=== [AutoDoc Init] ERROR al inicializar Hive/TranslationService: $e ===");
    debugPrint(stack.toString());
  }
  
  debugPrint("=== [AutoDoc Init] Inicialización completa. Lanzando runApp ===");
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => VehicleProvider()),
        ChangeNotifierProvider(create: (_) => AlertProvider()),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
        ChangeNotifierProvider(create: (_) => AdminDashboardProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final languageProvider = context.watch<LanguageProvider>();
    
    return MaterialApp.router(
      title: 'AutoDoc',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      locale: languageProvider.currentLocale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      themeMode: themeProvider.themeMode,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      builder: (context, child) => ResponsiveBreakpoints.builder(
        child: child!,
        breakpoints: [
          const Breakpoint(start: 0, end: 450, name: MOBILE),
          const Breakpoint(start: 451, end: 800, name: TABLET),
          const Breakpoint(start: 801, end: 1920, name: DESKTOP),
          const Breakpoint(start: 1921, end: double.infinity, name: '4K'),
        ],
      ),
    );
  }
}

