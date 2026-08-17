import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:animations/animations.dart';
import 'package:provider/provider.dart';

import 'package:autodoc/features/splash/presentation/pages/splash_screen.dart';
import 'package:autodoc/features/onboarding/presentation/pages/onboarding_screen.dart';
import 'package:autodoc/features/auth/presentation/pages/auth_screen.dart';
import 'package:autodoc/features/dashboard/presentation/pages/dashboard_screen.dart';
import 'package:autodoc/features/profile/presentation/pages/profile_setup_screen.dart';
import 'package:autodoc/features/profile/presentation/pages/user_profile_screen.dart';
import 'package:autodoc/features/dashboard/presentation/pages/garage_screen.dart';
import 'package:autodoc/features/dashboard/presentation/pages/service_history_screen.dart';
import 'package:autodoc/features/dashboard/presentation/pages/alerts_screen.dart';
import 'package:autodoc/features/dashboard/presentation/pages/workshop_directory_screen.dart';
import 'package:autodoc/features/dashboard/presentation/pages/vehicle_profile_screen.dart';
import 'package:autodoc/features/mechanic/presentation/pages/mechanic_dashboard_screen.dart';
import 'package:autodoc/features/mechanic/presentation/pages/vehicle_search_screen.dart';
import 'package:autodoc/features/mechanic/presentation/pages/workshop_settings_screen.dart';
import 'package:autodoc/core/models/vehicle_model.dart';
import 'package:autodoc/core/models/maintenance_task_model.dart';
import 'package:autodoc/features/mechanic/presentation/pages/initiate_service_screen.dart';
import 'package:autodoc/features/mechanic/presentation/pages/mechanic_reviews_screen.dart';
import 'package:autodoc/features/mechanic/presentation/pages/mechanic_pending_screen.dart';
import 'package:autodoc/features/dashboard/presentation/pages/task_config_screen.dart';
import 'package:autodoc/features/dashboard/presentation/pages/task_complete_screen.dart';
import 'package:autodoc/features/mechanic/presentation/pages/mechanic_service_history_screen.dart';
import 'package:autodoc/features/mechanic/presentation/pages/reparaciones_kanban_screen.dart';
import 'package:autodoc/features/mechanic/presentation/pages/empleados_screen.dart';
import 'package:autodoc/features/mechanic/presentation/pages/catalogo_servicios_screen.dart';
import 'package:autodoc/features/admin/presentation/pages/admin_dashboard_screen.dart';
import 'package:autodoc/features/admin/presentation/pages/admin_usuarios_screen.dart';
import 'package:autodoc/features/admin/presentation/pages/admin_talleres_screen.dart';
import 'package:autodoc/features/admin/presentation/pages/admin_resenias_screen.dart';
import 'package:autodoc/features/admin/presentation/pages/admin_logs_screen.dart';
import 'package:autodoc/features/admin/presentation/pages/admin_seed_screen.dart';
import 'package:autodoc/core/widgets/main_scaffold.dart';
import 'package:autodoc/features/chat/presentation/pages/conversaciones_list_screen.dart';
import 'package:autodoc/features/chat/presentation/pages/chat_screen.dart';
import 'package:autodoc/features/chat/presentation/pages/reserva_detail_screen.dart';
import 'package:autodoc/features/chat/data/models/reserva_model.dart';
import 'package:autodoc/core/providers/auth_session_provider.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/features/dashboard/presentation/pages/notifications_screen.dart';
import 'package:autodoc/core/models/user_model.dart';
import 'package:autodoc/core/widgets/missing_argument_screen.dart';

CustomTransitionPage<T> buildPageWithFadeThrough<T>({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeThroughTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        child: child,
      );
    },
  );
}

/// Routes that don't require authentication
const _publicRoutes = <String>{'/', '/login', '/register', '/onboarding'};

/// Routes exclusively for Propietario role
const _ownerRoutes = <String>{
  '/dashboard',
  '/garage',
  '/workshop_directory',
  '/user_profile',
  '/vehicle_profile',
  '/alerts',
  '/service_history',
};

/// Routes exclusively for Mecánico/Taller role
const _mechanicRoutes = <String>{
  '/mechanic_dashboard',
  '/mechanic_search',
  '/mechanic_service_history',
  '/workshop_settings',
  '/mechanic_reviews',
  '/initiate_service',
  '/mechanic_pending',
  '/mechanic_reparaciones',
  '/mechanic/empleados',
  '/mechanic/catalogo',
};

/// Valores de `usuarios/{uid}.estado` que permiten a un mecanico/taller
/// acceder a la app. Espejo exacto de `isMecanico()` en `firestore.rules`
/// (`getUserData().get('estado', 'pendiente') in ['aprobado', 'activo']`):
/// cualquier otro valor (incluido ausente, 'pendiente' o 'suspendido') se
/// retiene en `/mechanic_pending`. `mechanic_pending_screen.dart` referencia
/// esta misma constante — si cambia aqui, cambia alli tambien.
const estadosMecanicoAprobado = <String>{'aprobado', 'activo'};

/// Routes exclusively for Admin role
const _adminRoutes = <String>{
  '/admin/dashboard',
  '/admin/usuarios',
  '/admin/talleres',
  '/admin/resenias',
  '/admin/logs',
  '/admin/seed',
};

/// Determines the normalized role string
String _normalizeRole(String? rol) {
  if (rol == null) return '';
  final r = rol.trim().toLowerCase();
  if (r == 'admin' || r == 'administrador' || r == 'superusuario') {
    return 'admin';
  }
  if (r == 'mecanico' || r == 'taller') return 'mechanic';
  return 'owner'; // Propietario or default
}

/// Returns the home route for a given role
String _homeForRole(String normalizedRole) {
  switch (normalizedRole) {
    case 'admin':
      return '/admin/dashboard';
    case 'mechanic':
      return '/mechanic_dashboard';
    default:
      return '/dashboard';
  }
}

/// Resuelve el widget hijo de una ruta que depende de un id de path
/// parameter (`:vehiculoId`, `:reservaId`, ...): si el id no llega (null o
/// vacío) devuelve [MissingArgumentScreen] con `mensajeFaltante`; si llega,
/// delega en `buildScreen`.
///
/// Se extrae como función pura y pública (igual que `resolveRedirect`) para
/// poder probarla sin depender del parseo de URLs de go_router — una
/// navegación real nunca entrega un pathParameter vacío para un segmento
/// `:id` (go_router exige al menos un carácter por segmento), pero esta
/// guarda es la última línea de defensa contra una pantalla en blanco si
/// esa garantía cambiara o si el router se invoca programáticamente con un
/// `GoRouterState` construido a mano.
Widget resolveRouteChild({
  required String? id,
  required String mensajeFaltante,
  String rutaVuelta = '/dashboard',
  required Widget Function(String id) buildScreen,
}) {
  if (id == null || id.isEmpty) {
    return MissingArgumentScreen(
      mensaje: mensajeFaltante,
      rutaVuelta: rutaVuelta,
    );
  }
  return buildScreen(id);
}

/// Checks if a path matches or starts with any route in the set
bool _matchesRouteSet(String path, Set<String> routes) {
  for (final route in routes) {
    if (path == route ||
        path.startsWith('$route/') ||
        path.startsWith('$route?')) {
      return true;
    }
  }
  return false;
}

/// App Router Definition with auth guards
///
/// Route expectations:
/// - /vehicle_profile/:vehiculoId   — extra opcional: VehicleModel (precarga)
/// - /service_history/:vehiculoId   — extra opcional: VehicleModel (precarga)
/// - /initiate_service/:vehiculoId  — extra opcional: VehicleModel (precarga)
/// - /reserva_detail/:reservaId     — extra opcional: ReservaModel (precarga)
/// Ninguna pantalla depende de `extra`: todas resuelven el argumento desde su id.
/// - /task_config: expects `MaintenanceTask`
/// - /task_complete: expects `Map<String, dynamic>` with keys 'task' (MaintenanceTask) and 'currentKm' (int)
/// Núcleo de decisión del enrutado, sin dependencias de Flutter ni de go_router.
/// `appRouterRedirect` es un adaptador sobre esta función; los tests la invocan
/// directamente.
String? resolveRedirect({
  required bool isLoggedIn,
  required UserModel? userData,
  required bool isLoading,
  required bool hasAttemptedFetch,
  required String? profileError,
  required String currentPath,
  String? redirectParam,
}) {
  final isPublicRoute = _publicRoutes.contains(currentPath);
  final isProfileLoading = isLoading || (isLoggedIn && !hasAttemptedFetch);

  if (!isLoggedIn && !isPublicRoute) return '/login';

  // Mientras el perfil se carga no se puede decidir el rol, asi que no se
  // permite montar ninguna ruta protegida: se retiene en el splash. Devolver
  // null aqui permitia renderizar la pantalla de otro rol en una carga en frio,
  // que es como un token de taller llegaba a ver /dashboard.
  if (isLoggedIn && (isProfileLoading || !hasAttemptedFetch)) {
    if (currentPath == '/' ||
        currentPath == '/login' ||
        currentPath == '/register') {
      return null;
    }
    // Preserva el destino solicitado (recarga de una ruta con id, deep link
    // de notificacion push en frio) como query param, mismo formato que ya
    // usa la rama de login/register de esta funcion mas abajo
    // (`redirectParam` / `Uri.decodeComponent`). El splash lo lee y navega
    // ahi una vez el perfil termina de cargar.
    return '/?redirect=${Uri.encodeComponent(currentPath)}';
  }

  if (isLoggedIn && (currentPath == '/login' || currentPath == '/register')) {
    if (userData == null) {
      if (profileError != null) return null;
      return '/profile_setup';
    }
    if (redirectParam != null && redirectParam.isNotEmpty) {
      return Uri.decodeComponent(redirectParam);
    }
    return _homeForRole(_normalizeRole(userData.rol));
  }

  if (isLoggedIn &&
      userData == null &&
      profileError == null &&
      currentPath != '/profile_setup' &&
      !isPublicRoute) {
    return '/profile_setup';
  }

  if (isLoggedIn && userData != null) {
    final role = _normalizeRole(userData.rol);
    final home = _homeForRole(role);

    final estado = userData.estado.trim().toLowerCase();
    if (role == 'mechanic' && !estadosMecanicoAprobado.contains(estado)) {
      return currentPath == '/mechanic_pending' ? null : '/mechanic_pending';
    }

    if (currentPath.startsWith('/chat/') ||
        currentPath == '/chat_list' ||
        currentPath.startsWith('/reserva_detail')) {
      return null;
    }

    if (currentPath == '/task_config' || currentPath == '/task_complete') {
      return (role != 'owner' && role != 'admin') ? home : null;
    }

    if (currentPath == '/profile_setup') return home;

    if (role == 'owner' &&
        (_matchesRouteSet(currentPath, _mechanicRoutes) ||
            _matchesRouteSet(currentPath, _adminRoutes))) {
      return '/dashboard';
    }
    if (role == 'mechanic' &&
        (_matchesRouteSet(currentPath, _ownerRoutes) ||
            _matchesRouteSet(currentPath, _adminRoutes))) {
      return '/mechanic_dashboard';
    }
    if (role != 'admin' && _matchesRouteSet(currentPath, _adminRoutes)) {
      return home;
    }
  }

  return null;
}

/// Core redirect logic extracted for unit testing
String? appRouterRedirect(
  AuthSessionProvider authProvider,
  UserProfileProvider profileProvider,
  BuildContext context,
  GoRouterState state,
) {
  final currentUid = authProvider.currentUid;
  final rawUserData = profileProvider.userData;
  final userData =
      (rawUserData != null &&
          (rawUserData.idUsuario == currentUid ||
              rawUserData.idUsuario.isEmpty))
      ? rawUserData
      : null;

  return resolveRedirect(
    isLoggedIn: authProvider.isLoggedIn,
    userData: userData,
    isLoading: profileProvider.isLoading,
    hasAttemptedFetch: profileProvider.hasAttemptedFetchFor(currentUid),
    profileError: profileProvider.error,
    currentPath: state.uri.path,
    redirectParam: state.uri.queryParameters['redirect'],
  );
}

/// App Router Definition with auth guards
GoRouter createAppRouter(
  AuthSessionProvider authProvider,
  UserProfileProvider profileProvider, {
  String initialLocation = '/',
}) {
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: Listenable.merge([authProvider, profileProvider]),
    redirect: (BuildContext context, GoRouterState state) =>
        appRouterRedirect(authProvider, profileProvider, context, state),
    errorBuilder: (context, state) =>
        const Scaffold(body: Center(child: Text('Página no encontrada (404)'))),
    routes: [
      GoRoute(
        path: '/',
        pageBuilder: (context, state) => buildPageWithFadeThrough(
          context: context,
          state: state,
          child: const SplashScreen(),
        ),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) => buildPageWithFadeThrough(
          context: context,
          state: state,
          child: const OnboardingScreen(),
        ),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => buildPageWithFadeThrough(
          context: context,
          state: state,
          child: const AuthScreen(isLogin: true),
        ),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (context, state) => buildPageWithFadeThrough(
          context: context,
          state: state,
          child: const AuthScreen(isLogin: false),
        ),
      ),
      GoRoute(
        path: '/profile_setup',
        pageBuilder: (context, state) => buildPageWithFadeThrough(
          context: context,
          state: state,
          child: const ProfileSetupScreen(),
        ),
      ),

      // Main App Shell
      ShellRoute(
        builder: (context, state, child) {
          return MainScaffold(child: child);
        },
        routes: [
          GoRoute(
            path: '/dashboard',
            pageBuilder: (context, state) => buildPageWithFadeThrough(
              context: context,
              state: state,
              child: const DashboardScreen(),
            ),
          ),
          GoRoute(
            path: '/garage',
            pageBuilder: (context, state) => buildPageWithFadeThrough(
              context: context,
              state: state,
              child: const GarageScreen(),
            ),
          ),
          GoRoute(
            path: '/workshop_directory',
            pageBuilder: (context, state) => buildPageWithFadeThrough(
              context: context,
              state: state,
              child: const WorkshopDirectoryScreen(),
            ),
          ),
          GoRoute(
            path: '/user_profile',
            pageBuilder: (context, state) => buildPageWithFadeThrough(
              context: context,
              state: state,
              child: const UserProfileScreen(),
            ),
          ),
          GoRoute(
            path: '/chat_list',
            pageBuilder: (context, state) => buildPageWithFadeThrough(
              context: context,
              state: state,
              child: const ConversacionesListScreen(),
            ),
          ),
        ],
      ),

      GoRoute(
        path: '/vehicle_profile/:vehiculoId',
        pageBuilder: (context, state) => buildPageWithFadeThrough(
          context: context,
          state: state,
          child: resolveRouteChild(
            id: state.pathParameters['vehiculoId'],
            mensajeFaltante: 'No se indicó ningún vehículo.',
            buildScreen: (id) => VehicleProfileScreen(
              vehiculoId: id,
              vehiculoPrecargado: state.extra is VehicleModel
                  ? state.extra as VehicleModel
                  : null,
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/alerts',
        pageBuilder: (context, state) => buildPageWithFadeThrough(
          context: context,
          state: state,
          child: const AlertsScreen(),
        ),
      ),
      GoRoute(
        path: '/service_history/:vehiculoId',
        pageBuilder: (context, state) => buildPageWithFadeThrough(
          context: context,
          state: state,
          child: resolveRouteChild(
            id: state.pathParameters['vehiculoId'],
            mensajeFaltante: 'No se indicó ningún vehículo.',
            buildScreen: (id) => ServiceHistoryScreen(vehiculoId: id),
          ),
        ),
      ),
      GoRoute(
        path: '/mechanic_search',
        pageBuilder: (context, state) => buildPageWithFadeThrough(
          context: context,
          state: state,
          child: const VehicleSearchScreen(),
        ),
      ),
      GoRoute(
        path: '/mechanic_service_history',
        pageBuilder: (context, state) => buildPageWithFadeThrough(
          context: context,
          state: state,
          child: const MechanicServiceHistoryScreen(),
        ),
      ),
      GoRoute(
        path: '/mechanic_dashboard',
        pageBuilder: (context, state) => buildPageWithFadeThrough(
          context: context,
          state: state,
          child: const MechanicDashboardScreen(),
        ),
      ),
      GoRoute(
        path: '/mechanic_reparaciones',
        pageBuilder: (context, state) => buildPageWithFadeThrough(
          context: context,
          state: state,
          child: Consumer<UserProfileProvider>(
            builder: (context, userSession, _) => ReparacionesKanbanScreen(
              idTaller: userSession.userData?.idTallerEfectivo ?? '',
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/mechanic/empleados',
        pageBuilder: (context, state) => buildPageWithFadeThrough(
          context: context,
          state: state,
          child: Consumer<UserProfileProvider>(
            builder: (context, userSession, _) => EmpleadosScreen(
              // Un empleado nunca gestiona empleados (bloqueado en 3 capas,
              // ver comentario en EmpleadosScreen), pero se resuelve el id
              // efectivo igualmente por consistencia con el resto de rutas
              // del panel mecánico: para el dueño real (el único que de
              // hecho usa este id) es un no-op, `idTallerEfectivo ==
              // idUsuario`.
              idTaller: userSession.userData?.idTallerEfectivo ?? '',
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/mechanic/catalogo',
        pageBuilder: (context, state) => buildPageWithFadeThrough(
          context: context,
          state: state,
          child: Consumer<UserProfileProvider>(
            builder: (context, userSession, _) => CatalogoServiciosScreen(
              idTaller: userSession.userData?.idTallerEfectivo ?? '',
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/mechanic_pending',
        pageBuilder: (context, state) => buildPageWithFadeThrough(
          context: context,
          state: state,
          child: const MechanicPendingScreen(),
        ),
      ),
      GoRoute(
        path: '/workshop_settings',
        pageBuilder: (context, state) => buildPageWithFadeThrough(
          context: context,
          state: state,
          child: const WorkshopSettingsScreen(),
        ),
      ),
      GoRoute(
        path: '/mechanic_reviews',
        pageBuilder: (context, state) => buildPageWithFadeThrough(
          context: context,
          state: state,
          child: const MechanicReviewsScreen(),
        ),
      ),
      GoRoute(
        path: '/initiate_service/:vehiculoId',
        pageBuilder: (context, state) => buildPageWithFadeThrough(
          context: context,
          state: state,
          child: resolveRouteChild(
            id: state.pathParameters['vehiculoId'],
            mensajeFaltante: 'No se indicó ningún vehículo.',
            rutaVuelta: '/mechanic_dashboard',
            buildScreen: (id) => InitiateServiceScreen(
              vehiculoId: id,
              vehiculoPrecargado: state.extra is VehicleModel
                  ? state.extra as VehicleModel
                  : null,
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/chat/:id',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return buildPageWithFadeThrough(
            context: context,
            state: state,
            child: ChatScreen(conversacionId: id),
          );
        },
      ),
      GoRoute(
        path: '/reserva_detail/:reservaId',
        pageBuilder: (context, state) => buildPageWithFadeThrough(
          context: context,
          state: state,
          child: resolveRouteChild(
            id: state.pathParameters['reservaId'],
            mensajeFaltante: 'No se indicó ninguna reserva.',
            rutaVuelta: '/chat_list',
            buildScreen: (id) => ReservaDetailScreen(
              reservaId: id,
              reservaPrecargada: state.extra is ReservaModel
                  ? state.extra as ReservaModel
                  : null,
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/task_config',
        pageBuilder: (context, state) {
          final task = state.extra as MaintenanceTask;
          return buildPageWithFadeThrough(
            context: context,
            state: state,
            child: TaskConfigScreen(task: task),
          );
        },
      ),
      GoRoute(
        path: '/task_complete',
        pageBuilder: (context, state) {
          final data = state.extra as Map<String, dynamic>;
          return buildPageWithFadeThrough(
            context: context,
            state: state,
            child: TaskCompleteScreen(
              task: data['task'] as MaintenanceTask,
              currentKm: data['currentKm'] as int,
            ),
          );
        },
      ),
      GoRoute(
        path: '/admin/dashboard',
        pageBuilder: (context, state) => buildPageWithFadeThrough(
          context: context,
          state: state,
          child: const AdminDashboardScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/usuarios',
        pageBuilder: (context, state) => buildPageWithFadeThrough(
          context: context,
          state: state,
          child: const AdminUsuariosScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/talleres',
        pageBuilder: (context, state) => buildPageWithFadeThrough(
          context: context,
          state: state,
          child: const AdminTalleresScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/resenias',
        pageBuilder: (context, state) => buildPageWithFadeThrough(
          context: context,
          state: state,
          child: const AdminReseniasScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/logs',
        pageBuilder: (context, state) => buildPageWithFadeThrough(
          context: context,
          state: state,
          child: const AdminLogsScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/seed',
        pageBuilder: (context, state) => buildPageWithFadeThrough(
          context: context,
          state: state,
          child: const AdminSeedScreen(),
        ),
      ),
      GoRoute(
        path: '/notifications',
        pageBuilder: (context, state) => buildPageWithFadeThrough(
          context: context,
          state: state,
          child: const NotificationsScreen(),
        ),
      ),
    ],
  );
}
