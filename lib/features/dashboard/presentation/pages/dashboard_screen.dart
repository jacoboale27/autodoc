import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
import 'package:autodoc/core/widgets/app_horizontal_scroller.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/widgets/app_skeleton_layouts.dart';
import 'package:autodoc/core/widgets/notification_bell_button.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_radius.dart';
import 'package:autodoc/core/theme/app_severity.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/widgets/app_page_body.dart';
import 'package:autodoc/core/widgets/app_section_header.dart';
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
        _isInitialized = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final vehicleProvider = context.read<VehicleProvider>();
          vehicleProvider.fetchVehicles(userSession.userData!.idUsuario).then((
            _,
          ) {
            if (!mounted) return;
            // Se llama SIEMPRE, tambien con la lista vacia: el provider ya
            // trata ese caso vaciando `_alerts` (alert_provider.dart:97).
            // Con el `isNotEmpty` que habia aqui, un usuario recien creado
            // veia las alertas del usuario de la sesion anterior — incluido
            // "Tu SOAT vencio hace 29 dias" de un coche que no es suyo.
            context.read<AlertProvider>().fetchAlertsForVehicles(
              vehicleProvider.vehicles,
            );
          });
        });
      }
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddVehicleDialog(context, primaryPurple),
        backgroundColor: colors.primary,
        foregroundColor: isDark ? colors.secondary : colors.onPrimary,
        elevation: 8,
        shape: const CircleBorder(),
        tooltip: context.l10n.dashRegisterVehicle,
        child: Icon(Icons.add, size: Responsive.iconSize(context, 32)),
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [bgColorStart, bgColorEnd],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            // No renombrar el parámetro de contexto del builder a "context":
            // eclipsaría el context de _DashboardScreenState y los
            // context.watch<UserProfileProvider>() de _buildHeader
            // registrarían su dependencia en el Element interno del
            // LayoutBuilder en vez del State, y didChangeDependencies() ya
            // no volvería a dispararse cuando llegan los datos del usuario
            // (ver dashboard_screen_vehicle_fetch_test.dart).
            builder: (_, constraints) {
              final windowClass = AppBreakpoints.fromWidth(
                constraints.maxWidth,
              );
              final twoColumn = windowClass.isAtLeastExpanded;

              final primaryBlocks = <Widget>[
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
                if (vehicle != null) ...[
                  const SizedBox(height: AppSpacing.base),
                  _buildMaintenanceSemaphore(
                    context.watch<AlertProvider>(),
                    vehicle,
                    colors,
                  ),
                ],
              ];

              final secondaryBlocks = <Widget>[
                _buildActiveAlerts(
                  primaryPurple,
                  alertProvider,
                  isDark,
                  subTextColor,
                  colors,
                ),
                const SizedBox(height: AppSpacing.xxl),
                _buildNearbyServices(primaryPurple, isDark, subTextColor),
              ];

              return SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: AppSpacing.xxxl * 2),
                child: AppPageBody(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(
                        context,
                        isDark,
                        textColor,
                        subTextColor,
                        windowClass,
                      ),
                      const SizedBox(height: AppSpacing.sm),
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
                        const SizedBox(height: AppSpacing.base),
                      ],
                      if (twoColumn)
                        Row(
                          key: const Key('dashboard-two-column'),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 5,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: primaryBlocks,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xxl),
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: secondaryBlocks,
                              ),
                            ),
                          ],
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ...primaryBlocks,
                            const SizedBox(height: AppSpacing.xxl),
                            ...secondaryBlocks,
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Saludo del dashboard, con campana de notificaciones y avatar de perfil.
  ///
  /// Esos dos controles se ocultan en [WindowClass.large] porque ahi el shell
  /// ya monta [AppTopNavBar], que lleva los mismos dos destinos
  /// (`/notifications` y `/user_profile`) a unos centimetros de distancia.
  ///
  /// La condicion es la clase de ventana y no `kIsWeb` a proposito: lo que
  /// decide si sobran no es la plataforma sino si el shell los esta pintando
  /// ya, y eso pasa exactamente en `large` (ver `MainScaffold._OwnerShell`).
  /// En compact el shell usa `AppBottomNav` y en medium/expanded `AppNavRail`,
  /// y ninguno de los dos incluye notificaciones ni perfil: ahi son la unica
  /// via de acceso y quitarlos los dejaria inalcanzables.
  Widget _buildHeader(
    BuildContext context,
    bool isDark,
    Color textColor,
    Color subTextColor,
    WindowClass windowClass,
  ) {
    final userSession = context.watch<UserProfileProvider>();
    final userName =
        userSession.userData?.nombreCompleto.split(' ').first ?? 'Usuario';

    final colors = context.appColors;
    final userPhoto = userSession.userData?.fotoPerfilUrl;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.base),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.dashHello(userName),
                  style: AppTextStyles.headlineSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  context.l10n.dashReadyForRoad,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                    color: subTextColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (!windowClass.isLarge) ...[
            const SizedBox(width: AppSpacing.sm),
            Row(
              key: const Key('dashboard-header-acciones'),
              children: [
                NotificationBellButton(readColor: subTextColor),
                const SizedBox(width: AppSpacing.xs),
                GestureDetector(
                  onTap: () => context.push('/user_profile'),
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: Responsive.size(context, 24),
                        backgroundColor: colors.primary,
                        backgroundImage: userPhoto != null
                            ? NetworkImage(userPhoto)
                            : null,
                        child: userPhoto == null
                            ? Text(
                                userName.isNotEmpty
                                    ? userName[0].toUpperCase()
                                    : 'U',
                                style: AppTextStyles.titleMedium.copyWith(
                                  color: colors.onPrimary,
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: Responsive.size(context, 12),
                          height: Responsive.size(context, 12),
                          decoration: BoxDecoration(
                            color: colors.secondary,
                            shape: BoxShape.circle,
                            border: Border.all(color: colors.surface, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
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

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.base),
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.build_circle_outlined, color: colors.warning),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  context.l10n.dashTallerPendienteTitulo,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          Row(
            children: [
              Icon(Icons.storefront_outlined, size: 16, color: primary),
              const SizedBox(width: AppSpacing.xs + 2),
              Expanded(
                child: Text(
                  context.l10n.dashTallerPendienteSolicitante(tallerNombre),
                  style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs / 2),
          Text(
            context.l10n.dashLicensePlate(vehicle.placa),
            style: AppTextStyles.labelSmall.copyWith(color: subTextColor),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            context.l10n.dashTallerPendienteDesc,
            style: AppTextStyles.bodySmall.copyWith(color: subTextColor),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  text: context.l10n.chatAccept,
                  type: AppButtonType.outlined,
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
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  text: context.l10n.chatReject,
                  type: AppButtonType.danger,
                  onPressed: () async {
                    final success = await vehicleProvider.rechazarVinculoTaller(
                      vehicle.idVehiculo,
                      tallerId,
                    );
                    if (!success && context.mounted) {
                      UiUtils.showErrorSnackbar(
                        context,
                        vehicleProvider.error ??
                            context.l10n.dashTallerPendienteRechazarError,
                      );
                    }
                  },
                ),
              ),
            ],
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

    final severity = AppSeverity.forStatus(
      worstStatus,
      colors,
      optimalLabel: context.l10n.dashMaintOptimal,
      preventiveLabel: context.l10n.dashMaintWarning,
      criticalLabel: context.l10n.dashMaintCritical,
    );

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.md + 2,
      ),
      margin: EdgeInsets.zero,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm + 2),
            decoration: BoxDecoration(
              color: severity.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              severity.icon,
              color: severity.color,
              size: Responsive.iconSize(context, 22),
            ),
          ),
          const SizedBox(width: AppSpacing.md + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.dashMaintStatusLabel,
                  style: AppTextStyles.labelSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs / 2),
                Text(
                  severity.label,
                  style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: severity.color,
                  ),
                ),
              ],
            ),
          ),
          // Three-dot semaphore dots
          Row(
            children: [
              _semDot(MaintenanceStatus.optimal, worstStatus, colors),
              const SizedBox(width: AppSpacing.xs),
              _semDot(MaintenanceStatus.preventive, worstStatus, colors),
              const SizedBox(width: AppSpacing.xs),
              _semDot(MaintenanceStatus.critical, worstStatus, colors),
            ],
          ),
        ],
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
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
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
          const SizedBox(height: AppSpacing.xl),
          Text(
            context.l10n.dashNoVehicles,
            style: AppTextStyles.titleLarge.copyWith(
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            context.l10n.dashNoVehiclesDesc,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(color: subTextColor),
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              text: context.l10n.dashRegisterVehicle,
              onPressed: () => _showAddVehicleDialog(context, primary),
            ),
          ),
        ],
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
    final colors = context.appColors;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
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
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        context.l10n.dashMainVehicle,
                        style: AppTextStyles.labelSmall.copyWith(
                          fontWeight: FontWeight.bold,
                          color: primary,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '${vehicle.marca ?? ''} ${vehicle.modelo ?? ''} ${vehicle.anio ?? ''}',
                      style: AppTextStyles.titleLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      context.l10n.dashLicensePlate(vehicle.placa),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: subTextColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(Icons.directions_car, color: primary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: VehicleImageWidget(
              imageUrl: vehicle.fotoUrl,
              height: Responsive.heroHeight(context, 140),
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
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
          const SizedBox(height: AppSpacing.base),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              text: context.l10n.dashViewVehicleState,
              onPressed: () => context.push(
                '/vehicle_profile/${vehicle.idVehiculo}',
                extra: vehicle,
              ),
              // Sin color: AppButton ya aplica su foreground al icono vía
              // IconTheme.
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
            ),
          ),
        ],
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
              style: AppTextStyles.labelSmall.copyWith(
                color: subTextColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const TextSpan(text: ' '),
                  TextSpan(
                    text: unit,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: subTextColor,
                    ),
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
        AppSectionHeader(
          title: context.l10n.dashActiveAlerts,
          trailing: AppButton(
            text: context.l10n.dashViewAll,
            type: AppButtonType.text,
            size: AppButtonSize.small,
            onPressed: () => context.push('/alerts'),
          ),
        ),
        const SizedBox(height: AppSpacing.base),
        if (activeAlerts.isEmpty)
          Text(
            context.l10n.dashNoAlertsPending,
            style: AppTextStyles.bodyMedium.copyWith(
              color: colors.secondary,
              fontWeight: FontWeight.w500,
            ),
          )
        else
          // Con flechas: en desktop la rueda del raton no mueve un scroll
          // horizontal y las alertas a partir de la tercera eran inalcanzables.
          AppHorizontalScroller(
            semanticLabel: 'alertas',
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
              return _buildAlertCard(
                icon,
                alert.titulo,
                alert.descripcion,
                color,
                isDark,
                subTextColor,
              );
            }).toList(),
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
      padding: const EdgeInsets.all(AppSpacing.base),
      margin: EdgeInsets.zero,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 150, maxWidth: 220),
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
              style: AppTextStyles.labelMedium.copyWith(
                color: subTextColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: AppSpacing.xs / 2),
            Text(
              status,
              style: AppTextStyles.bodySmall.copyWith(
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: context.l10n.dashNearbyWorkshops,
          trailing: AppButton(
            text: context.l10n.dashViewAllWorkshops,
            type: AppButtonType.text,
            size: AppButtonSize.small,
            onPressed: () => context.push('/workshop_directory'),
          ),
        ),
        const SizedBox(height: AppSpacing.base),
        StreamBuilder<List<UserModel>>(
          stream: WorkshopService().getWorkshopsStream(limit: 5),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError ||
                !snapshot.hasData ||
                snapshot.data!.isEmpty) {
              // No existe clave l10n para este texto (ya era literal antes
              // de esta fase); fuera de alcance añadir l10n nuevo aquí.
              return Center(
                child: Text(
                  'No hay talleres disponibles',
                  style: AppTextStyles.bodyMedium.copyWith(color: subTextColor),
                ),
              );
            }

            var workshops = snapshot.data!;
            // Sort by rating descending
            workshops.sort((a, b) {
              final ratingA = a.toMap()['calificacion_promedio'] as num? ?? 0.0;
              final ratingB = b.toMap()['calificacion_promedio'] as num? ?? 0.0;
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
      padding: const EdgeInsets.all(AppSpacing.base),
      margin: EdgeInsets.zero,
      child: Row(
        children: [
          Container(
            width: Responsive.size(context, 48),
            height: Responsive.size(context, 48),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              icon,
              color: primary,
              size: Responsive.iconSize(context, 24),
            ),
          ),
          const SizedBox(width: AppSpacing.base),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs / 2),
                Text(
                  subtitle,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: subTextColor,
                  ),
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
