import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/features/dashboard/presentation/providers/vehicle_provider.dart';
import 'package:autodoc/features/dashboard/presentation/providers/alert_provider.dart';
import 'package:autodoc/core/models/vehicle_model.dart';
import 'package:autodoc/core/models/maintenance_task_model.dart';
import 'package:autodoc/features/dashboard/data/services/workshop_service.dart';
import 'package:autodoc/core/models/user_model.dart';
import 'package:autodoc/core/widgets/vehicle_image_widget.dart';
import 'package:autodoc/core/widgets/app_card.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/widgets/app_skeleton_layouts.dart';
import 'package:autodoc/core/widgets/notification_bell_button.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:uuid/uuid.dart';

import 'package:autodoc/core/utils/responsive.dart';
import 'package:autodoc/core/utils/l10n_extension.dart';
import 'package:autodoc/core/utils/ui_utils.dart';
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
      final userSession = context.read<UserProfileProvider>();
      if (userSession.userData != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final vehicleProvider = context.read<VehicleProvider>();
          vehicleProvider.fetchVehicles(userSession.userData!.idUsuario).then((
            _,
          ) {
            if (mounted && vehicleProvider.selectedVehicle != null) {
              context.read<AlertProvider>().fetchAlerts(
                vehicleProvider.selectedVehicle!.idVehiculo,
                vehicleProvider.selectedVehicle!,
              );
            }
          });
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
                padding: EdgeInsets.only(
                  bottom: Responsive.isDesktop(context)
                      ? Responsive.padding(context, 24)
                      : Responsive.padding(context, 120),
                  top: Responsive.isDesktop(context)
                      ? Responsive.size(context, 100)
                      : 0,
                ), // Adjust padding based on navbars
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context, isDark, textColor, subTextColor),
                    const SizedBox(height: 8),
                    if (vehicle?.tallerPendienteConfirmacion != null) ...[
                      _buildTallerPendienteBanner(
                        context,
                        vehicleProvider,
                        vehicle!,
                        primaryPurple,
                        isDark,
                        textColor,
                        subTextColor,
                      ),
                      const SizedBox(height: 16),
                    ],
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
                child: Icon(Icons.add, size: Responsive.iconSize(context, 32)),
              ),
            ),

            // Bottom Navbar (Only on mobile)
            // Removed local navbar as it's now handled by ShellRoute globally

            // Top Navbar (Only on desktop)
            // Removed local navbar as it's now handled by ShellRoute globally
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
    final userSession = context.watch<UserProfileProvider>();
    final userName =
        userSession.userData?.nombreCompleto.split(' ').first ?? 'Usuario';

    return Padding(
      padding: EdgeInsets.all(Responsive.padding(context, 24.0)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.dashHello(userName),
                style: GoogleFonts.inter(
                  fontSize: Responsive.fontSize(context, 28),
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.dashReadyForRoad,
                style: GoogleFonts.inter(
                  fontSize: Responsive.fontSize(context, 14),
                  fontWeight: FontWeight.w500,
                  color: subTextColor,
                ),
              ),
            ],
          ),
          Row(
            children: [
              NotificationBellButton(readColor: subTextColor),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => context.push('/user_profile'),
                child: Stack(
                  children: [
                    Container(
                      width: Responsive.size(context, 48),
                      height: Responsive.size(context, 48),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        image: DecorationImage(
                          image: CachedNetworkImageProvider(
                            userSession.userData?.fotoPerfilUrl ??
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
                        width: Responsive.size(context, 12),
                        height: Responsive.size(context, 12),
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
        ],
      ),
    );
  }

  /// Banner de confirmación del hallazgo C1: cuando un taller atendió un
  /// vehículo que nunca tuvo taller vinculado, el trigger
  /// requestReviewOnServiceComplete marca `taller_pendiente_confirmacion`
  /// en vez de vincularlo automáticamente. El propietario debe confirmar o
  /// rechazar explícitamente antes de otorgar acceso permanente al
  /// historial (ver VehicleProvider.confirmarVinculoTaller /
  /// rechazarVinculoTaller).
  ///
  /// Cierre C-1 de la revisión adversarial: el banner debe mostrar QUIÉN
  /// pide acceso (nombre del taller denormalizado por el trigger en
  /// `taller_pendiente_nombre`) y a qué vehículo (placa), no un texto
  /// genérico — de lo contrario el propietario no puede distinguir una
  /// visita real de un intento de secuestro con el mismo texto.
  Widget _buildTallerPendienteBanner(
    BuildContext context,
    VehicleProvider vehicleProvider,
    VehicleModel vehicle,
    Color primary,
    bool isDark,
    Color textColor,
    Color subTextColor,
  ) {
    final tallerId = vehicle.tallerPendienteConfirmacion;
    if (tallerId == null) return const SizedBox.shrink();

    final colors = context.appColors;
    final tallerNombre =
        vehicle.tallerPendienteNombre ??
        context.l10n.dashTallerPendienteNombreDesconocido;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.padding(context, 24),
      ),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        margin: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.build_circle_outlined, color: colors.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.l10n.dashTallerPendienteTitulo,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.storefront_outlined, size: 16, color: primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    context.l10n.dashTallerPendienteSolicitante(tallerNombre),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              context.l10n.dashLicensePlate(vehicle.placa),
              style: TextStyle(color: subTextColor, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.dashTallerPendienteDesc,
              style: TextStyle(color: subTextColor, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final success = await vehicleProvider
                          .confirmarVinculoTaller(vehicle.idVehiculo, tallerId);
                      if (!success && context.mounted) {
                        UiUtils.showErrorSnackbar(
                          context,
                          vehicleProvider.error ??
                              context.l10n.dashTallerPendienteConfirmError,
                        );
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primary,
                      side: BorderSide(color: primary),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      minimumSize: Size.zero,
                    ),
                    child: Text(context.l10n.chatAccept),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final success = await vehicleProvider
                          .rechazarVinculoTaller(vehicle.idVehiculo, tallerId);
                      if (!success && context.mounted) {
                        UiUtils.showErrorSnackbar(
                          context,
                          vehicleProvider.error ??
                              context.l10n.dashTallerPendienteRechazarError,
                        );
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      minimumSize: Size.zero,
                    ),
                    child: Text(context.l10n.chatReject),
                  ),
                ),
              ],
            ),
          ],
        ),
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
        semLabel = context.l10n.dashMaintCritical;
        break;
      case MaintenanceStatus.preventive:
        semColor = colors.warning;
        semIcon = Icons.warning_rounded;
        semLabel = context.l10n.dashMaintWarning;
        break;
      case MaintenanceStatus.optimal:
        semColor = colors.secondary;
        semIcon = Icons.check_circle_rounded;
        semLabel = context.l10n.dashMaintOptimal;
        break;
    }

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.padding(context, 24),
      ),
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
              child: Icon(
                semIcon,
                color: semColor,
                size: Responsive.iconSize(context, 22),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.dashMaintStatusLabel,
                    style: GoogleFonts.inter(
                      fontSize: Responsive.fontSize(context, 11),
                      fontWeight: FontWeight.bold,
                      color: colors.textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    semLabel,
                    style: GoogleFonts.inter(
                      fontSize: Responsive.fontSize(context, 13),
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

  Widget _semDot(
    MaintenanceStatus dot,
    MaintenanceStatus current,
    AppColors colors,
  ) {
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
                size: Responsive.iconSize(context, 48),
                color: primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              context.l10n.dashNoVehicles,
              style: GoogleFonts.inter(
                fontSize: Responsive.fontSize(context, 20),
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.dashNoVehiclesDesc,
              textAlign: TextAlign.center,
              style: TextStyle(color: subTextColor, fontSize: 14),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                text: context.l10n.dashRegisterVehicle,
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
                          context.l10n.dashMainVehicle,
                          style: GoogleFonts.inter(
                            fontSize: Responsive.fontSize(context, 10),
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
                          fontSize: Responsive.fontSize(context, 20),
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        context.l10n.dashLicensePlate(vehicle.placa),
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
                height: Responsive.heroHeight(context, 140),
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                _buildStatItem(
                  context.l10n.dashMileage,
                  vehicle.kilometrajeActual.toString(),
                  context.l10n.dashKm,
                  primary,
                  isDark,
                  subTextColor,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                text: context.l10n.dashViewVehicleState,
                onPressed: () => context.push(
                  '/vehicle_profile/${vehicle.idVehiculo}',
                  extra: vehicle,
                ),
                icon: const Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: Colors.white,
                ),
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
          final userSession = context.read<UserProfileProvider>();
          final vehicleProvider = context.read<VehicleProvider>();

          final newVehicle = vehicle.copyWith(
            idVehiculo: const Uuid().v4(),
            idPropietario: userSession.userData!.idUsuario,
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
              UiUtils.showErrorSnackbar(
                context,
                vehicleProvider.error ?? context.l10n.dashAddVehicleError,
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
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.padding(context, 24),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.dashActiveAlerts,
                style: GoogleFonts.inter(
                  fontSize: Responsive.fontSize(context, 18),
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: () => context.push('/alerts'),
                child: Text(
                  context.l10n.dashViewAll,
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
              context.l10n.dashNoAlertsPending,
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
              child: Icon(
                icon,
                color: statusColor,
                size: Responsive.iconSize(context, 24),
              ),
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
                context.l10n.dashNearbyWorkshops,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () => context.push('/workshop_directory'),
                child: Text(
                  context.l10n.dashViewAllWorkshops,
                  style: TextStyle(color: primary, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<UserModel>>(
            stream: WorkshopService().getWorkshopsStream(limit: 5),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError ||
                  !snapshot.hasData ||
                  snapshot.data!.isEmpty) {
                return Center(
                  child: Text(
                    'No hay talleres disponibles',
                    style: TextStyle(color: subTextColor),
                  ),
                );
              }

              var workshops = snapshot.data!;
              // Sort by rating descending
              workshops.sort((a, b) {
                final ratingA =
                    a.toMap()['calificacion_promedio'] as num? ?? 0.0;
                final ratingB =
                    b.toMap()['calificacion_promedio'] as num? ?? 0.0;
                return ratingB.compareTo(ratingA);
              });

              // Take top 5
              final topWorkshops = workshops.take(5).toList();

              return Column(
                children: topWorkshops.map((workshop) {
                  final data = workshop.toMap();
                  final calificacion =
                      data['calificacion_promedio'] as num? ?? 0.0;
                  final especialidad =
                      data['especialidad'] as String? ?? 'General';
                  return InkWell(
                    onTap: () => context.push('/workshop_directory'),
                    child: _buildServiceTile(
                      Icons.build,
                      data['nombre_completo'] as String? ?? 'Taller',
                      'Especialidad: $especialidad • ${calificacion.toStringAsFixed(1)}★',
                      primary,
                      isDark,
                      subTextColor,
                    ),
                  );
                }).toList(),
              );
            },
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
            width: Responsive.size(context, 48),
            height: Responsive.size(context, 48),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(Responsive.size(context, 12)),
            ),
            child: Icon(
              icon,
              color: primary,
              size: Responsive.iconSize(context, 24),
            ),
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
}
