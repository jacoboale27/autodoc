import 'package:go_router/go_router.dart';
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
import 'package:autodoc/features/dashboard/presentation/pages/task_config_screen.dart';
import 'package:autodoc/features/dashboard/presentation/pages/task_complete_screen.dart';
import 'package:autodoc/features/admin/presentation/pages/admin_dashboard_screen.dart';
import 'package:autodoc/features/admin/presentation/pages/admin_usuarios_screen.dart';
import 'package:autodoc/features/admin/presentation/pages/admin_talleres_screen.dart';
import 'package:autodoc/features/admin/presentation/pages/admin_resenias_screen.dart';
import 'package:autodoc/features/admin/presentation/pages/admin_logs_screen.dart';
import 'package:autodoc/features/admin/presentation/pages/admin_seed_screen.dart';

/// App Router Definition
///
/// Route expectations (extra parameters):
/// - /vehicle_profile: expects `VehicleModel`
/// - /service_history: expects `String` (vehicleId)
/// - /initiate_service: expects `VehicleModel`
/// - /task_config: expects `MaintenanceTask`
/// - /task_complete: expects `Map<String, dynamic>` with keys 'task' (MaintenanceTask) and 'currentKm' (int)
final GoRouter appRouter = GoRouter(
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
      path: '/service_history',
      builder: (context, state) {
        final vehicleId = state.extra as String;
        return ServiceHistoryScreen(vehicleId: vehicleId);
      },
    ),
    GoRoute(
      path: '/mechanic_search',
      builder: (context, state) => const VehicleSearchScreen(),
    ),
    GoRoute(
      path: '/mechanic_dashboard',
      builder: (context, state) => const MechanicDashboardScreen(),
    ),
    GoRoute(
      path: '/workshop_settings',
      builder: (context, state) => const WorkshopSettingsScreen(),
    ),
    GoRoute(
      path: '/mechanic_reviews',
      builder: (context, state) => const MechanicReviewsScreen(),
    ),
    GoRoute(
      path: '/workshop_directory',
      builder: (context, state) => const WorkshopDirectoryScreen(),
    ),
    GoRoute(
      path: '/initiate_service',
      builder: (context, state) {
        final vehicle = state.extra as VehicleModel;
        return InitiateServiceScreen(vehicle: vehicle);
      },
    ),
    GoRoute(
      path: '/task_config',
      builder: (context, state) {
        final task = state.extra as MaintenanceTask;
        return TaskConfigScreen(task: task);
      },
    ),
    GoRoute(
      path: '/task_complete',
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>;
        return TaskCompleteScreen(
          task: data['task'] as MaintenanceTask,
          currentKm: data['currentKm'] as int,
        );
      },
    ),
    GoRoute(
      path: '/admin/dashboard',
      builder: (context, state) => const AdminDashboardScreen(),
    ),
    GoRoute(
      path: '/admin/usuarios',
      builder: (context, state) => const AdminUsuariosScreen(),
    ),
    GoRoute(
      path: '/admin/talleres',
      builder: (context, state) => const AdminTalleresScreen(),
    ),
    GoRoute(
      path: '/admin/resenias',
      builder: (context, state) => const AdminReseniasScreen(),
    ),
    GoRoute(
      path: '/admin/logs',
      builder: (context, state) => const AdminLogsScreen(),
    ),
    GoRoute(
      path: '/admin/seed',
      builder: (context, state) => const AdminSeedScreen(),
    ),
  ],
);
