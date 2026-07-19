import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:animations/animations.dart';

import 'package:autodoc/features/splash/presentation/pages/splash_screen.dart';
import 'package:autodoc/features/onboarding/presentation/pages/onboarding_screen.dart';
import 'package:autodoc/features/auth/presentation/pages/auth_screen.dart';
import 'package:autodoc/features/landing/presentation/pages/landing_screen.dart';
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
const _publicRoutes = <String>{
  '/',
  '/login',
  '/register',
  '/onboarding',
  '/landing',
};

/// Routes exclusively for Propietario role
const _ownerRoutes = <String>{
  '/dashboard',
  '/garage',
  '/workshop_directory',
  '/user_profile',
  '/chat_list',
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
};

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
  if (r == 'admin' || r == 'administrador') return 'admin';
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

/// Checks if a path matches or starts with any route in the set
bool _matchesRouteSet(String path, Set<String> routes) {
  for (final route in routes) {
    if (path == route || path.startsWith('$route/') || path.startsWith('$route?')) {
      return true;
    }
  }
  return false;
}

/// App Router Definition with auth guards
///
/// Route expectations (extra parameters):
/// - /vehicle_profile: expects `VehicleModel`
/// - /service_history: expects `String` (vehicleId)
/// - /initiate_service: expects `VehicleModel`
/// - /task_config: expects `MaintenanceTask`
/// - /task_complete: expects `Map<String, dynamic>` with keys 'task' (MaintenanceTask) and 'currentKm' (int)
GoRouter createAppRouter(AuthSessionProvider authProvider, UserProfileProvider profileProvider) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: Listenable.merge([authProvider, profileProvider]),
    redirect: (BuildContext context, GoRouterState state) {
      final currentPath = state.uri.path;
      final isPublicRoute = _publicRoutes.contains(currentPath);
      final isLoggedIn = authProvider.isLoggedIn;
      final userData = profileProvider.userData;

      // --- 1. Unauthenticated user trying to access protected route ---
      if (!isLoggedIn && !isPublicRoute) {
        // Persist intended destination as query param for post-login redirect
        final encodedRedirect = Uri.encodeComponent(currentPath);
        return '/login?redirect=$encodedRedirect';
      }

      // --- 2. Authenticated user on login/register → redirect to appropriate home ---
      if (isLoggedIn && (currentPath == '/login' || currentPath == '/register')) {
        if (userData == null) {
          return '/profile_setup';
        }
        // Check if there's a pending redirect
        final redirectParam = state.uri.queryParameters['redirect'];
        if (redirectParam != null && redirectParam.isNotEmpty) {
          return Uri.decodeComponent(redirectParam);
        }
        return _homeForRole(_normalizeRole(userData.rol));
      }

      // --- 3. Authenticated user without profile → force profile setup ---
      if (isLoggedIn && userData == null && currentPath != '/profile_setup' && !isPublicRoute) {
        return '/profile_setup';
      }

      // --- 4. Role-based access control ---
      if (isLoggedIn && userData != null) {
        final role = _normalizeRole(userData.rol);
        final home = _homeForRole(role);

        // Mechanic pending approval: block dashboard access until approved
        final estado = userData.estado.trim().toLowerCase();
        if (role == 'mechanic' && (estado == 'pendiente' || estado == 'pending')) {
          if (currentPath != '/mechanic_pending') {
            return '/mechanic_pending';
          }
          return null; // Already on pending screen
        }

        // Chat routes are shared between owner and mechanic
        if (currentPath.startsWith('/chat/') || currentPath == '/reserva_detail') {
          return null; // Allow — both roles use chat
        }

        // Task config/complete routes are for owners
        if (currentPath == '/task_config' || currentPath == '/task_complete') {
          if (role != 'owner' && role != 'admin') {
            return home;
          }
          return null;
        }

        // Profile setup is for anyone
        if (currentPath == '/profile_setup') {
          return null;
        }

        // Owner trying to access mechanic routes → redirect to owner home
        if (role == 'owner' && _matchesRouteSet(currentPath, _mechanicRoutes)) {
          return '/dashboard';
        }
        if (role == 'owner' && _matchesRouteSet(currentPath, _adminRoutes)) {
          return '/dashboard';
        }

        // Mechanic trying to access owner routes → redirect to mechanic home
        if (role == 'mechanic' && _matchesRouteSet(currentPath, _ownerRoutes)) {
          return '/mechanic_dashboard';
        }
        if (role == 'mechanic' && _matchesRouteSet(currentPath, _adminRoutes)) {
          return '/mechanic_dashboard';
        }

        // Non-admin trying to access admin routes → redirect to their home
        if (role != 'admin' && _matchesRouteSet(currentPath, _adminRoutes)) {
          return home;
        }
      }

      // --- 5. No redirect needed ---
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        pageBuilder: (context, state) => buildPageWithFadeThrough(context: context, state: state, child: const SplashScreen()),
      ),
      GoRoute(
        path: '/landing',
        pageBuilder: (context, state) => buildPageWithFadeThrough(context: context, state: state, child: const LandingScreen()),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) => buildPageWithFadeThrough(context: context, state: state, child: const OnboardingScreen()),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => buildPageWithFadeThrough(context: context, state: state, child: const AuthScreen(isLogin: true)),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (context, state) => buildPageWithFadeThrough(context: context, state: state, child: const AuthScreen(isLogin: false)),
      ),
      GoRoute(
        path: '/profile_setup',
        pageBuilder: (context, state) => buildPageWithFadeThrough(context: context, state: state, child: const ProfileSetupScreen()),
      ),
      
      // Main App Shell
      ShellRoute(
        builder: (context, state, child) {
          return MainScaffold(child: child);
        },
        routes: [
          GoRoute(
            path: '/dashboard',
            pageBuilder: (context, state) => buildPageWithFadeThrough(context: context, state: state, child: const DashboardScreen()),
          ),
          GoRoute(
            path: '/garage',
            pageBuilder: (context, state) => buildPageWithFadeThrough(context: context, state: state, child: const GarageScreen()),
          ),
          GoRoute(
            path: '/workshop_directory',
            pageBuilder: (context, state) => buildPageWithFadeThrough(context: context, state: state, child: const WorkshopDirectoryScreen()),
          ),
          GoRoute(
            path: '/user_profile',
            pageBuilder: (context, state) => buildPageWithFadeThrough(context: context, state: state, child: const UserProfileScreen()),
          ),
          GoRoute(
            path: '/chat_list',
            pageBuilder: (context, state) => buildPageWithFadeThrough(context: context, state: state, child: const ConversacionesListScreen()),
          ),
        ],
      ),
      
      GoRoute(
        path: '/vehicle_profile',
        pageBuilder: (context, state) {
          final vehicle = state.extra as VehicleModel;
          return buildPageWithFadeThrough(context: context, state: state, child: VehicleProfileScreen(vehicle: vehicle));
        },
      ),
      GoRoute(
        path: '/alerts',
        pageBuilder: (context, state) => buildPageWithFadeThrough(context: context, state: state, child: const AlertsScreen()),
      ),
      GoRoute(
        path: '/service_history',
        pageBuilder: (context, state) {
          final vehicleId = state.extra as String;
          return buildPageWithFadeThrough(context: context, state: state, child: ServiceHistoryScreen(vehicleId: vehicleId));
        },
      ),
      GoRoute(
        path: '/mechanic_search',
        pageBuilder: (context, state) => buildPageWithFadeThrough(context: context, state: state, child: const VehicleSearchScreen()),
      ),
      GoRoute(
        path: '/mechanic_service_history',
        pageBuilder: (context, state) => buildPageWithFadeThrough(context: context, state: state, child: const MechanicServiceHistoryScreen()),
      ),
      GoRoute(
        path: '/mechanic_dashboard',
        pageBuilder: (context, state) => buildPageWithFadeThrough(context: context, state: state, child: const MechanicDashboardScreen()),
      ),
      GoRoute(
        path: '/mechanic_pending',
        pageBuilder: (context, state) => buildPageWithFadeThrough(context: context, state: state, child: const MechanicPendingScreen()),
      ),
      GoRoute(
        path: '/workshop_settings',
        pageBuilder: (context, state) => buildPageWithFadeThrough(context: context, state: state, child: const WorkshopSettingsScreen()),
      ),
      GoRoute(
        path: '/mechanic_reviews',
        pageBuilder: (context, state) => buildPageWithFadeThrough(context: context, state: state, child: const MechanicReviewsScreen()),
      ),
      GoRoute(
        path: '/initiate_service',
        pageBuilder: (context, state) {
          final vehicle = state.extra as VehicleModel;
          return buildPageWithFadeThrough(context: context, state: state, child: InitiateServiceScreen(vehicle: vehicle));
        },
      ),
      GoRoute(
        path: '/chat/:id',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return buildPageWithFadeThrough(context: context, state: state, child: ChatScreen(conversacionId: id));
        },
      ),
      GoRoute(
        path: '/reserva_detail',
        pageBuilder: (context, state) {
          final reserva = state.extra as ReservaModel;
          return buildPageWithFadeThrough(context: context, state: state, child: ReservaDetailScreen(reserva: reserva));
        },
      ),
      GoRoute(
        path: '/task_config',
        pageBuilder: (context, state) {
          final task = state.extra as MaintenanceTask;
          return buildPageWithFadeThrough(context: context, state: state, child: TaskConfigScreen(task: task));
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
        pageBuilder: (context, state) => buildPageWithFadeThrough(context: context, state: state, child: const AdminDashboardScreen()),
      ),
      GoRoute(
        path: '/admin/usuarios',
        pageBuilder: (context, state) => buildPageWithFadeThrough(context: context, state: state, child: const AdminUsuariosScreen()),
      ),
      GoRoute(
        path: '/admin/talleres',
        pageBuilder: (context, state) => buildPageWithFadeThrough(context: context, state: state, child: const AdminTalleresScreen()),
      ),
      GoRoute(
        path: '/admin/resenias',
        pageBuilder: (context, state) => buildPageWithFadeThrough(context: context, state: state, child: const AdminReseniasScreen()),
      ),
      GoRoute(
        path: '/admin/logs',
        pageBuilder: (context, state) => buildPageWithFadeThrough(context: context, state: state, child: const AdminLogsScreen()),
      ),
      GoRoute(
        path: '/admin/seed',
        pageBuilder: (context, state) => buildPageWithFadeThrough(context: context, state: state, child: const AdminSeedScreen()),
      ),
      GoRoute(
        path: '/notifications',
        pageBuilder: (context, state) => buildPageWithFadeThrough(context: context, state: state, child: const NotificationsScreen()),
      ),
      GoRoute(
        path: '/mechanic_pending',
        pageBuilder: (context, state) => buildPageWithFadeThrough(context: context, state: state, child: const MechanicPendingScreen()),
      ),
    ],
  );
}
