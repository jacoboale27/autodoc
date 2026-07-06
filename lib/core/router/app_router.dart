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
import 'package:autodoc/features/dashboard/presentation/pages/task_config_screen.dart';
import 'package:autodoc/features/dashboard/presentation/pages/task_complete_screen.dart';
import 'package:autodoc/features/admin/presentation/pages/admin_dashboard_screen.dart';
import 'package:autodoc/features/admin/presentation/pages/admin_usuarios_screen.dart';
import 'package:autodoc/features/admin/presentation/pages/admin_talleres_screen.dart';
import 'package:autodoc/features/admin/presentation/pages/admin_resenias_screen.dart';
import 'package:autodoc/features/admin/presentation/pages/admin_logs_screen.dart';
import 'package:autodoc/features/admin/presentation/pages/admin_seed_screen.dart';

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

/// App Router Definition
///
/// Route expectations (extra parameters):
/// - /vehicle_profile: expects `VehicleModel`
/// - /service_history: expects `String` (vehicleId)
/// - /initiate_service: expects `VehicleModel`
/// - /task_config: expects `MaintenanceTask`
/// - /task_complete: expects `Map<String, dynamic>` with keys 'task' (MaintenanceTask) and 'currentKm' (int)
final GoRouter appRouter = GoRouter(
  initialLocation: '/login',
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
    GoRoute(
      path: '/dashboard',
      pageBuilder: (context, state) => buildPageWithFadeThrough(context: context, state: state, child: const DashboardScreen()),
    ),
    GoRoute(
      path: '/vehicle_profile',
      pageBuilder: (context, state) {
        final vehicle = state.extra as VehicleModel;
        return buildPageWithFadeThrough(context: context, state: state, child: VehicleProfileScreen(vehicle: vehicle));
      },
    ),
    GoRoute(
      path: '/user_profile',
      pageBuilder: (context, state) => buildPageWithFadeThrough(context: context, state: state, child: const UserProfileScreen()),
    ),
    GoRoute(
      path: '/garage',
      pageBuilder: (context, state) => buildPageWithFadeThrough(context: context, state: state, child: const GarageScreen()),
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
      path: '/mechanic_dashboard',
      pageBuilder: (context, state) => buildPageWithFadeThrough(context: context, state: state, child: const MechanicDashboardScreen()),
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
      path: '/workshop_directory',
      pageBuilder: (context, state) => buildPageWithFadeThrough(context: context, state: state, child: const WorkshopDirectoryScreen()),
    ),
    GoRoute(
      path: '/initiate_service',
      pageBuilder: (context, state) {
        final vehicle = state.extra as VehicleModel;
        return buildPageWithFadeThrough(context: context, state: state, child: InitiateServiceScreen(vehicle: vehicle));
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
  ],
);
