import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/features/auth/presentation/providers/auth_provider.dart';
import 'package:autodoc/features/dashboard/presentation/providers/vehicle_provider.dart';
import 'package:autodoc/features/dashboard/presentation/providers/alert_provider.dart';
import 'package:autodoc/core/models/vehicle_model.dart';
import 'package:autodoc/core/models/maintenance_task_model.dart';
import 'package:autodoc/core/widgets/vehicle_image_widget.dart';
import 'package:autodoc/core/widgets/app_card.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/widgets/app_skeleton_layouts.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:uuid/uuid.dart';
import '../widgets/add_vehicle_form.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      final authProvider = context.read<AuthProvider>();
      if (authProvider.user != null) {
        final vehicleProvider = context.read<VehicleProvider>();
        vehicleProvider.fetchVehicles(authProvider.user!.uid).then((_) {
          if (mounted && vehicleProvider.selectedVehicle != null) {
            context.read<AlertProvider>().fetchAlerts(
              vehicleProvider.selectedVehicle!.idVehiculo,
              vehicleProvider.selectedVehicle!,
            );
          }
        });
      }
      _isInitialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors = context.appColors;

    final primaryPurple = colors.primary;
    final bgColorStart = isDark ? colors.surfaceContainer : colors.surface;
    final bgColorEnd = isDark ? colors.surface : colors.surfaceContainer;
    final textColor = colors.textPrimary;
    final subTextColor = colors.textSecondary;

    final vehicleProvider = context.watch<VehicleProvider>();
    final alertProvider = context.watch<AlertProvider>();
    final vehicle = vehicleProvider.selectedVehicle;
    final isLoading = vehicleProvider.isLoading;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [bgColorStart, bgColorEnd],
          ),
        ),
        child: Stack(
          children: [
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(
                  bottom: 120,
                ), // For bottom nav and FAB
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context, isDark, textColor, subTextColor),
                    const SizedBox(height: 8),
                    if (isLoading)
                      AppSkeletonLayouts.dashboard()
                    else if (vehicle == null)
                      _buildEmptyVehicleState(
                        context,
                        primaryPurple,
                        isDark,
                        textColor,
                        subTextColor,
                      )
                    else
                       _buildVehicleCard(
                        primaryPurple,
                        vehicle,
                        isDark,
                        textColor,
                        subTextColor,
                      ),
                    const SizedBox(height: 16),
                    if (vehicle != null) ...[
                      _buildMaintenanceSemaphore(
                        context.watch<AlertProvider>(),
                        vehicle,
                        colors,
                      ),
                      const SizedBox(height: 16),
                    ],
                    const SizedBox(height: 16),
                    _buildActiveAlerts(
                      primaryPurple,
                      alertProvider,
                      isDark,
                      subTextColor,
                      colors,
                    ),
                    const SizedBox(height: 32),
                    _buildNearbyServices(primaryPurple, isDark, subTextColor),
                  ],
                ),
              ),
            ),

            // FAB
            Positioned(
              bottom: 100,
              right: 24,
              child: FloatingActionButton(
                onPressed: () => _showAddVehicleDialog(context, primaryPurple),
                backgroundColor: colors.primary,
                foregroundColor: isDark ? colors.secondary : Colors.white,
                elevation: 8,
                shape: const CircleBorder(),
                child: const Icon(Icons.add, size: 32),
              ),
            ),

            // Bottom Navbar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomNav(primaryPurple, isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    bool isDark,
    Color textColor,
    Color subTextColor,
  ) {
    final authProvider = context.watch<AuthProvider>();
    final userName =
        authProvider.user?.displayName?.split(' ').first ?? 'Usuario';

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hola, $userName 👋',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '¿Listo para la carretera hoy?',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: subTextColor,
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () => context.push('/user_profile'),
            child: Stack(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    image: DecorationImage(
                      image: CachedNetworkImageProvider(
                        authProvider.userData?.fotoPerfilUrl ??
                            'https://www.w3schools.com/howto/img_avatar.png',
                      ),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: context.appColors.secondary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceSemaphore(
    AlertProvider provider,
    VehicleModel vehicle,
    AppColors colors,
  ) {
    final tasks = provider.maintenanceTasks;
    if (tasks.isEmpty) return const SizedBox.shrink();

    // Aggregate worst status across all tasks
    MaintenanceStatus worstStatus = MaintenanceStatus.optimal;
    for (final task in tasks) {
      final s = task.getStatus(vehicle.kilometrajeActual);
      if (s == MaintenanceStatus.critical) {
        worstStatus = MaintenanceStatus.critical;
        break;
      } else if (s == MaintenanceStatus.preventive) {
        worstStatus = MaintenanceStatus.preventive;
      }
    }

    final Color semColor;
    final IconData semIcon;
    final String semLabel;
    switch (worstStatus) {
      case MaintenanceStatus.critical:
        semColor = colors.error;
        semIcon = Icons.error_rounded;
        semLabel = 'Mantenimiento vencido — atención inmediata';
        break;
      case MaintenanceStatus.preventive:
        semColor = colors.warning;
        semIcon = Icons.warning_rounded;
        semLabel = 'Mantenimiento próximo — revisa las alertas';
        break;
      case MaintenanceStatus.optimal:
        semColor = colors.secondary;
        semIcon = Icons.check_circle_rounded;
        semLabel = 'Vehículo en buen estado';
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        margin: EdgeInsets.zero,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: semColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(semIcon, color: semColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Estado de Mantenimiento',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: colors.textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    semLabel,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: semColor,
                    ),
                  ),
                ],
              ),
            ),
            // Three-dot semaphore dots
            Row(
              children: [
                _semDot(MaintenanceStatus.optimal, worstStatus, colors),
                const SizedBox(width: 4),
                _semDot(MaintenanceStatus.preventive, worstStatus, colors),
                const SizedBox(width: 4),
                _semDot(MaintenanceStatus.critical, worstStatus, colors),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _semDot(MaintenanceStatus dot, MaintenanceStatus current, AppColors colors) {
    final bool active = dot.index >= current.index;
    final Color c = dot == MaintenanceStatus.critical
        ? colors.error
        : dot == MaintenanceStatus.preventive
            ? colors.warning
            : colors.secondary;
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? c : c.withValues(alpha: 0.2),
      ),
    );
  }

  Widget _buildEmptyVehicleState(
    BuildContext context,
    Color primary,
    bool isDark,
    Color textColor,
    Color subTextColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: AppCard(
        padding: const EdgeInsets.all(32),
        margin: EdgeInsets.zero,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.directions_car_filled_outlined,
                size: 48,
                color: primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No hay vehiculos registrados',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Añade tu primer vehículo para empezar a controlar su mantenimiento y estado.',
              textAlign: TextAlign.center,
              style: TextStyle(color: subTextColor, fontSize: 14),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                text: 'Registrar Vehículo',
                onPressed: () => _showAddVehicleDialog(context, primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleCard(
    Color primary,
    VehicleModel vehicle,
    bool isDark,
    Color textColor,
    Color subTextColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: AppCard(
        padding: const EdgeInsets.all(24),
        margin: EdgeInsets.zero,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'VEHICULO PRINCIPAL',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: primary,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${vehicle.marca ?? ''} ${vehicle.modelo ?? ''} ${vehicle.anio ?? ''}',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Placa: ${vehicle.placa}',
                        style: TextStyle(color: subTextColor, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.directions_car, color: primary),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: VehicleImageWidget(
                imageUrl: vehicle.fotoUrl,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                _buildStatItem(
                  'KILOMETRAJE',
                  vehicle.kilometrajeActual.toString(),
                  'km',
                  primary,
                  isDark,
                  subTextColor,
                ),
                const SizedBox(width: 16),
                _buildStatItem(
                  'NIVEL DE COMBUSTIBLE',
                  '78',
                  '%',
                  primary,
                  isDark,
                  subTextColor,
                ), // Hardcoded for now as it's not in model
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                text: 'Ver Estado del Vehículo',
                onPressed: () => context.push('/vehicle_profile', extra: vehicle),
                icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddVehicleDialog(BuildContext context, Color primary) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddVehicleForm(
        primaryColor: primary,
        onFinish: (vehicle) async {
          final authProvider = context.read<AuthProvider>();
          final vehicleProvider = context.read<VehicleProvider>();

          final newVehicle = vehicle.copyWith(
            idVehiculo: Uuid().v4(),
            idPropietario: authProvider.user!.uid,
          );

          final success = await vehicleProvider.addVehicle(newVehicle);
          if (success) {
            // Crear tareas de mantenimiento predeterminadas
            if (context.mounted) {
              await context.read<AlertProvider>().createDefaultTasks(
                newVehicle.idVehiculo,
                newVehicle.kilometrajeActual,
              );
            }
            if (context.mounted) Navigator.pop(context);
          } else {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    vehicleProvider.error ?? 'Error al agregar vehiculo',
                  ),
                ),
              );
            }
          }
        },
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    String unit,
    Color color,
    bool isDark,
    Color subTextColor,
  ) {
    return Expanded(
      child: AppCard(
        padding: const EdgeInsets.all(12),
        margin: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: subTextColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const TextSpan(text: ' '),
                  TextSpan(
                    text: unit,
                    style: TextStyle(fontSize: 12, color: subTextColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveAlerts(
    Color primary,
    AlertProvider provider,
    bool isDark,
    Color subTextColor,
    AppColors colors,
  ) {
    final activeAlerts = provider.activeAlerts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Alertas Activas',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: () => context.push('/alerts'),
                child: Text(
                  'Ver Todas',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (activeAlerts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              '¡Excelente! No tienes alertas pendientes.',
              style: TextStyle(
                color: colors.secondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: activeAlerts.map((alert) {
                Color color;
                IconData icon;
                switch (alert.tipoAlerta) {
                  case 'Aceite':
                    icon = Icons.oil_barrel;
                    color = colors.warning;
                    break;
                  case 'SOAT':
                    icon = Icons.verified_user;
                    color = colors.error;
                    break;
                  case 'Llantas':
                    icon = Icons.tire_repair;
                    color = colors.primary;
                    break;
                  default:
                    icon = Icons.notifications;
                    color = primary;
                }
                return Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: _buildAlertCard(
                    icon,
                    alert.titulo,
                    alert.descripcion,
                    color,
                    isDark,
                    subTextColor,
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildAlertCard(
    IconData icon,
    String title,
    String status,
    Color statusColor,
    bool isDark,
    Color subTextColor,
  ) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      margin: EdgeInsets.zero,
      child: SizedBox(
        width: 150,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: statusColor, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: subTextColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              status,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNearbyServices(Color primary, bool isDark, Color subTextColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Talleres Cercanos',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () => context.push('/workshop_directory'),
                child: Text(
                  'Ver todos',
                  style: TextStyle(color: primary, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () => context.push('/workshop_directory'),
            child: _buildServiceTile(
              Icons.build,
              'AutoFix Workshop',
              'Especialidad: Motor • 4.8★',
              primary,
              isDark,
              subTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceTile(
    IconData icon,
    String title,
    String subtitle,
    Color primary,
    bool isDark,
    Color subTextColor,
  ) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      margin: EdgeInsets.zero,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: subTextColor, fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: context.appColors.textSecondary),
        ],
      ),
    );
  }

  Widget _buildBottomNav(Color primary, bool isDark) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 80,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: isDark
                ? context.appColors.surfaceContainer.withValues(alpha: 0.9)
                : context.appColors.surfaceContainer.withValues(alpha: 0.85),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                Icons.home,
                'Home',
                true,
                primary,
                () => context.go('/dashboard'),
              ),
              _buildNavItem(
                Icons.garage,
                'Garage',
                false,
                primary,
                () => context.push('/garage'),
              ),
              _buildNavItem(Icons.analytics, 'Logs', false, primary, () {
                final vehicle = context.read<VehicleProvider>().selectedVehicle;
                if (vehicle != null) {
                  context.push('/service_history', extra: vehicle.idVehiculo);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Seleccione un vehículo primero'),
                    ),
                  );
                }
              }),
              _buildNavItem(
                Icons.person,
                'Profile',
                false,
                primary,
                () => context.push('/user_profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    IconData icon,
    String label,
    bool isActive,
    Color primary,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isActive ? primary : context.appColors.textSecondary,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isActive ? primary : context.appColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
