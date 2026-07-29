import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:autodoc/l10n/app_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:provider/provider.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'package:autodoc/core/utils/map_injector.dart';
import 'package:autodoc/core/bootstrap/firebase_bootstrap.dart';
import 'package:autodoc/core/providers/language_provider.dart';
import 'package:autodoc/core/services/translation_service.dart';
import 'package:autodoc/firebase_options.dart';
import 'package:autodoc/core/router/app_router.dart';
import 'package:autodoc/features/auth/presentation/providers/auth_provider.dart';
import 'package:autodoc/core/providers/auth_session_provider.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/features/dashboard/presentation/providers/alert_provider.dart';
import 'package:autodoc/features/dashboard/presentation/providers/vehicle_provider.dart';
import 'package:autodoc/core/providers/theme_provider.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/features/admin/presentation/providers/admin_provider.dart';
import 'package:autodoc/features/admin/presentation/providers/admin_dashboard_provider.dart';
import 'package:autodoc/core/services/notification_service.dart';
import 'package:autodoc/features/chat/presentation/providers/chat_provider.dart';
import 'package:autodoc/features/chat/presentation/providers/reserva_provider.dart';
import 'package:autodoc/core/providers/notification_center_provider.dart';
import 'package:autodoc/features/chat/data/models/mensaje_model.dart';

import 'package:autodoc/core/services/push_notification_service.dart';
import 'package:autodoc/core/widgets/firebase_initialization_error_screen.dart';

/// Resolves the deep link destination route from a push notification payload.
/// Returns null if no routing action should be taken.
String? _resolveNotificationRoute(Map<String, dynamic> data) {
  final type = data['type'] as String?;
  final id = data['id'] as String?;

  switch (type) {
    case 'chat':
      if (id != null && id.isNotEmpty) return '/chat/$id';
      return '/chat_list';
    case 'reserva':
      return '/chat_list'; // ReservaModel needs to be fetched; open list as fallback
    case 'alerta':
      return '/alerts';
    case 'review':
      return '/user_profile';
    default:
      return null;
  }
}

// Global navigator key for deep linking from background (removed because unused)

void main() async {
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();

  // 0. Cargar variables de entorno
  try {
    await dotenv.load(fileName: "app.env");
    debugPrint(
      "=== [AutoDoc Init] Variables de entorno cargadas con éxito ===",
    );
    if (kIsWeb) {
      final mapsKey = dotenv.env['GOOGLE_MAPS_API_KEY'];
      if (mapsKey != null && mapsKey.isNotEmpty) {
        injectGoogleMapsScript(mapsKey);
      }
    }
  } catch (e) {
    debugPrint(
      "=== [AutoDoc Init] Advertencia: No se pudo cargar .env: $e ===",
    );
  }

  // 1. Inicializar Firebase
  debugPrint("=== [AutoDoc Init] Inicializando Firebase ===");
  final firebaseResult = await FirebaseBootstrap.initialize(
    () async {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
    },
  );
  if (!firebaseResult.isReady) {
    debugPrint(
      "=== [AutoDoc Init] ERROR al inicializar Firebase: ${firebaseResult.error} ===",
    );
    runApp(const FirebaseInitializationErrorApp());
    return;
  }
  debugPrint("=== [AutoDoc Init] Firebase inicializado con éxito ===");

  // 2. Configurar Firebase Crashlytics
  try {
    if (!kIsWeb) {
      // Pass all uncaught Flutter framework errors to Crashlytics
      FlutterError.onError = (errorDetails) {
        FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
      };
      // Pass all uncaught asynchronous errors to Crashlytics
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
      debugPrint("=== [AutoDoc Init] Crashlytics configurado ===");
    }
  } catch (e) {
    debugPrint("=== [AutoDoc Init] ERROR al configurar Crashlytics: $e ===");
  }

  // 3. Habilitar persistencia offline de Firestore
  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    debugPrint(
      "=== [AutoDoc Init] Firestore offline persistence habilitado ===",
    );
  } catch (e) {
    debugPrint(
      "=== [AutoDoc Init] ERROR al habilitar Firestore persistence: $e ===",
    );
  }

  // 4. Configurar Firebase Messaging y permisos de notificaciones
  try {
    debugPrint("=== [AutoDoc Init] Inicializando PushNotificationService ===");
    await PushNotificationService().initialize();
    debugPrint("=== [AutoDoc Init] PushNotificationService inicializado ===");
  } catch (e, stack) {
    debugPrint("=== [AutoDoc Init] ERROR en PushNotificationService: $e ===");
    debugPrint(stack.toString());
  }

  // 5. Inicializar Local Notifications y FCM en foreground
  try {
    debugPrint("=== [AutoDoc Init] Inicializando NotificationService ===");
    await NotificationService().initialize().timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        debugPrint(
          "=== [AutoDoc Init] TIMEOUT en NotificationService.initialize(). Continuando... ===",
        );
      },
    );
    debugPrint("=== [AutoDoc Init] NotificationService inicializado ===");
  } catch (e, stack) {
    debugPrint(
      "=== [AutoDoc Init] ERROR al inicializar NotificationService: $e ===",
    );
    debugPrint(stack.toString());
  }

  // 6. Inicializar Hive y cache de traducción
  try {
    debugPrint(
      "=== [AutoDoc Init] Inicializando Hive, offline_cache y TranslationService ===",
    );
    await Hive.initFlutter();
    Hive.registerAdapter(MensajeModelAdapter());
    await Hive.openBox('offline_cache');
    await Hive.openBox<MensajeModel>('mensajes');
    await TranslationService().initialize().timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        debugPrint(
          "=== [AutoDoc Init] TIMEOUT al inicializar TranslationService. Continuando... ===",
        );
      },
    );
    debugPrint(
      "=== [AutoDoc Init] Hive, offline_cache y TranslationService inicializados con éxito ===",
    );
  } catch (e, stack) {
    debugPrint(
      "=== [AutoDoc Init] ERROR al inicializar Hive/TranslationService: $e ===",
    );
    debugPrint(stack.toString());
  }

  debugPrint("=== [AutoDoc Init] Inicialización completa. Lanzando runApp ===");

  // Crear providers base
  final authSessionProvider = AuthSessionProvider();
  final userProfileProvider = UserProfileProvider();
  final vehicleProvider = VehicleProvider();

  void checkAndFetchProfile() {
    if (authSessionProvider.isLoggedIn) {
      final currentUid = authSessionProvider.currentUid;
      if (currentUid.isNotEmpty &&
          userProfileProvider.userData?.idUsuario != currentUid) {
        userProfileProvider.fetchUserData(currentUid);
      }
    } else {
      userProfileProvider.clearUserData();
      vehicleProvider.clearVehicles();
    }
  }

  // Escuchar cambios de auth para obtener datos de perfil
  authSessionProvider.addListener(checkAndFetchProfile);
  // Ejecutar verificación inicial por si la sesión ya estaba activa
  checkAndFetchProfile();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider.value(value: authSessionProvider),
        ChangeNotifierProvider.value(value: userProfileProvider),
        ChangeNotifierProvider.value(value: vehicleProvider),
        ChangeNotifierProvider(create: (_) => AlertProvider()),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
        ChangeNotifierProvider(create: (_) => AdminDashboardProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => ReservaProvider()),
        ChangeNotifierProvider(create: (_) => NotificationCenterProvider()),
      ],
      child: MyApp(
        authProvider: authSessionProvider,
        profileProvider: userProfileProvider,
      ),
    ),
  );
}

class MyApp extends StatefulWidget {
  final AuthSessionProvider authProvider;
  final UserProfileProvider profileProvider;

  const MyApp({
    super.key,
    required this.authProvider,
    required this.profileProvider,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = createAppRouter(widget.authProvider, widget.profileProvider);
    _setupDeepLinking();
  }

  /// Configures FCM deep linking so that tapping a push notification
  /// navigates the user to the correct screen.
  void _setupDeepLinking() {
    // App opened from a terminated state via push notification
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        final route = _resolveNotificationRoute(message.data);
        if (route != null) {
          // Delay until after the first frame so the router is ready
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _router.go(route);
          });
        }
      }
    });

    // App resumed from background via push notification tap
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final route = _resolveNotificationRoute(message.data);
      if (route != null) {
        _router.go(route);
      }
    });

    // Web: handle query params for notification deep linking
    // e.g. ?notif=chat&id=conversacionId
    // The router handles this via GoRouter's initial location from URL
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final languageProvider = context.watch<LanguageProvider>();

    return MaterialApp.router(
      title: 'AutoDoc',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
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
