import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:autodoc/features/dashboard/presentation/providers/alert_provider.dart';
import 'package:autodoc/features/dashboard/presentation/providers/vehicle_provider.dart';
import 'package:autodoc/core/models/alert_model.dart';
import 'package:autodoc/core/models/maintenance_task_model.dart';
import 'package:intl/intl.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_severity.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/widgets/app_card.dart';
import 'package:autodoc/core/widgets/app_empty_state.dart';
import 'package:autodoc/core/widgets/app_grid.dart';
import 'package:autodoc/core/widgets/app_page_body.dart';
import 'package:autodoc/core/widgets/app_scaffold.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/widgets/app_section_header.dart';
import 'package:autodoc/core/widgets/app_text_field.dart';
import 'package:autodoc/core/widgets/app_skeleton_layouts.dart';
import 'package:autodoc/core/utils/responsive.dart';
import 'package:autodoc/core/utils/l10n_extension.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  int _selectedTab = 0; // 0=Todas, 1=Urgentes, 2=Próximas

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final vehicleProvider = context.watch<VehicleProvider>();
    final alertProvider = context.watch<AlertProvider>();
    final vehicle = vehicleProvider.selectedVehicle;

    return AppScaffold(
      useGradient: true,
      body: Column(
        children: [
          // Header
          _buildHeader(
            context,
            isDark,
            colors.primary,
            colors.surfaceContainer,
          ),
          // Tabs
          _buildTabs(
            isDark,
            colors.primary,
            colors.textSecondary,
            colors.surfaceContainer,
          ),
          // Content
          Expanded(
            child: vehicle == null
                ? Center(
                    child: Text(
                      context.l10n.alertsSelectVehicle,
                      style: TextStyle(color: colors.textSecondary),
                    ),
                  )
                : alertProvider.isLoading
                ? AppSkeletonLayouts.listCards(itemCount: 4, cardHeight: 100)
                : _buildContent(
                    alertProvider,
                    vehicle.idVehiculo,
                    vehicle.kilometrajeActual,
                    isDark,
                    colors.primary,
                    colors.textPrimary,
                    colors.textSecondary,
                    colors.surfaceContainer,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    bool isDark,
    Color primary,
    Color cardColor,
  ) {
    final colors = context.appColors;
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.only(
          left: AppSpacing.sm,
          right: AppSpacing.sm,
          top: AppSpacing.sm,
          bottom: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: cardColor,
          border: Border(
            bottom: BorderSide(color: primary.withValues(alpha: 0.1)),
          ),
        ),
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back_ios_new, color: colors.textSecondary),
              onPressed: () => context.pop(),
            ),
            Text(
              context.l10n.alertsTitle,
              style: AppTextStyles.titleLarge.copyWith(color: primary),
            ),
            const Spacer(),
            IconButton(
              icon: Icon(Icons.update, color: primary),
              tooltip: context.l10n.alertsUpdateMileage,
              onPressed: () => _showUpdateMileageDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs(
    bool isDark,
    Color primary,
    Color subTextColor,
    Color cardColor,
  ) {
    final tabs = [
      context.l10n.alertsTabAll,
      context.l10n.alertsTabUrgent,
      context.l10n.alertsTabUpcoming,
    ];
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        border: Border(
          bottom: BorderSide(color: primary.withValues(alpha: 0.1)),
        ),
      ),
      padding: const EdgeInsets.only(top: AppSpacing.md),
      // Scroll horizontal: a 320px, 3 pestañas con su etiqueta más larga
      // ("Próximas") no caben sin él (desbordaba 24px). El resto de la
      // pantalla usa AppPageBody para el gutter; aquí se pone directamente
      // en el contenido desplazable para que el scroll llegue hasta el
      // borde.
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
        child: Row(
          key: const Key('alerts-tabs'),
          children: List.generate(tabs.length, (i) {
            final isActive = _selectedTab == i;
            return Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xl),
              child: InkWell(
                onTap: () => setState(() => _selectedTab = i),
                child: Semantics(
                  selected: isActive,
                  button: true,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isActive ? primary : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Text(
                      tabs[i],
                      style: AppTextStyles.labelLarge.copyWith(
                        fontWeight: isActive
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: isActive ? primary : subTextColor,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildContent(
    AlertProvider provider,
    String vehicleId,
    int currentKm,
    bool isDark,
    Color primary,
    Color textColor,
    Color subTextColor,
    Color cardColor,
  ) {
    // `provider.maintenanceTasks`/`provider.alerts` pueden traer datos de
    // OTRO vehiculo mezclados (fetchAlertsForVehicles acumula alertas de
    // todos los vehiculos del dueño para el dashboard, y deja
    // maintenanceTasks con las del ultimo vehiculo procesado; ver su
    // docstring en alert_provider.dart). Sin este filtro, una tarea de
    // otro vehiculo se graduaba contra el odometro del seleccionado y
    // aparecia a la vez como alerta critica (la real, de otro vehiculo) y
    // como sugerencia ÓPTIMA (mal graduada aqui) -- el hallazgo QA §16.
    final tasksForVehicle = provider.maintenanceTasks
        .where((t) => t.vehicleId == vehicleId)
        .toList();
    final alertsForVehicle = provider.activeAlerts
        .where((a) => a.idVehiculo == vehicleId)
        .toList();

    // Separate tasks by status
    final criticalTasks = <MaintenanceTask>[];
    final preventiveTasks = <MaintenanceTask>[];
    final optimalTasks = <MaintenanceTask>[];

    for (var task in tasksForVehicle) {
      switch (task.getStatus(currentKm)) {
        case MaintenanceStatus.critical:
          criticalTasks.add(task);
          break;
        case MaintenanceStatus.preventive:
          preventiveTasks.add(task);
          break;
        case MaintenanceStatus.optimal:
          optimalTasks.add(task);
          break;
      }
    }

    // Also separate alerts by priority
    final highAlerts = alertsForVehicle
        .where((a) => a.prioridad == AlertPriority.high)
        .toList();
    final medAlerts = alertsForVehicle
        .where((a) => a.prioridad == AlertPriority.medium)
        .toList();
    final lowAlerts = alertsForVehicle
        .where((a) => a.prioridad == AlertPriority.low)
        .toList();

    // Filter by tab
    final showCritical = _selectedTab == 0 || _selectedTab == 1;
    final showPreventive = _selectedTab == 0 || _selectedTab == 2;
    final showOptimal = _selectedTab == 0;

    final hasContent =
        (showCritical && (criticalTasks.isNotEmpty || highAlerts.isNotEmpty)) ||
        (showPreventive &&
            (preventiveTasks.isNotEmpty || medAlerts.isNotEmpty)) ||
        (showOptimal && (optimalTasks.isNotEmpty || lowAlerts.isNotEmpty));

    if (!hasContent) {
      return AppEmptyState(
        icon: Icons.verified_outlined,
        title: context.l10n.alertsAllGood,
        description: context.l10n.alertsNoAlertsInCategory,
      );
    }

    final colors = context.appColors;
    final criticalStyle = AppSeverity.forStatus(
      MaintenanceStatus.critical,
      colors,
      optimalLabel: context.l10n.alertsSuggestions,
      preventiveLabel: context.l10n.alertsUpcomingExpirations,
      criticalLabel: context.l10n.alertsHighPriority,
    );
    final preventiveStyle = AppSeverity.forStatus(
      MaintenanceStatus.preventive,
      colors,
      optimalLabel: context.l10n.alertsSuggestions,
      preventiveLabel: context.l10n.alertsUpcomingExpirations,
      criticalLabel: context.l10n.alertsHighPriority,
    );
    final optimalStyle = AppSeverity.forStatus(
      MaintenanceStatus.optimal,
      colors,
      optimalLabel: context.l10n.alertsSuggestions,
      preventiveLabel: context.l10n.alertsUpcomingExpirations,
      criticalLabel: context.l10n.alertsHighPriority,
    );

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        vertical: Responsive.padding(context, AppSpacing.base),
      ),
      child: AppPageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mileage indicator
            _buildMileageChip(currentKm, primary, isDark),
            const SizedBox(height: AppSpacing.xl),

            // Critical Section
            if (showCritical &&
                (criticalTasks.isNotEmpty || highAlerts.isNotEmpty)) ...[
              _buildSectionHeader(
                criticalStyle,
                context.l10n.alertsPendingCount(
                  (criticalTasks.length + highAlerts.length).toString(),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppGrid(
                compactColumns: 1,
                mediumColumns: 1,
                expandedColumns: 2,
                largeColumns: 2,
                childAspectRatio: 1.5,
                children: [
                  ...criticalTasks.map(
                    (t) => _buildTaskCard(t, currentKm, criticalStyle),
                  ),
                  ...highAlerts.map((a) => _buildAlertCard(a, criticalStyle)),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],

            // Preventive Section
            if (showPreventive &&
                (preventiveTasks.isNotEmpty || medAlerts.isNotEmpty)) ...[
              _buildSectionHeader(
                preventiveStyle,
                context.l10n.alertsEventsCount(
                  (preventiveTasks.length + medAlerts.length).toString(),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppGrid(
                compactColumns: 1,
                mediumColumns: 1,
                expandedColumns: 2,
                largeColumns: 2,
                childAspectRatio: 1.5,
                children: [
                  ...preventiveTasks.map(
                    (t) => _buildTaskCard(t, currentKm, preventiveStyle),
                  ),
                  ...medAlerts.map((a) => _buildAlertCard(a, preventiveStyle)),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],

            // Optimal / Suggestions
            if (showOptimal &&
                (optimalTasks.isNotEmpty || lowAlerts.isNotEmpty)) ...[
              _buildSectionHeader(optimalStyle, null),
              const SizedBox(height: AppSpacing.md),
              AppGrid(
                compactColumns: 1,
                mediumColumns: 1,
                expandedColumns: 2,
                largeColumns: 2,
                childAspectRatio: 1.5,
                children: [
                  ...optimalTasks.map(
                    (t) => _buildTaskCard(t, currentKm, optimalStyle),
                  ),
                  ...lowAlerts.map((a) => _buildAlertCard(a, optimalStyle)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMileageChip(int km, Color primary, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.speed,
            color: primary,
            size: Responsive.iconSize(context, 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${context.l10n.alertsCurrentMileage} ',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: primary.withValues(alpha: 0.7),
                    ),
                  ),
                  TextSpan(
                    text:
                        '${NumberFormat('#,###').format(km)} ${context.l10n.vpKm}',
                    style: AppTextStyles.labelLarge.copyWith(
                      fontWeight: FontWeight.bold,
                      color: primary,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 16),
            color: primary,
            tooltip: context.l10n.alertsUpdateMileage,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: () => _showUpdateMileageDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(AppSeverityStyle style, String? subtitle) {
    final colors = context.appColors;
    return Row(
      children: [
        Icon(style.icon, color: style.color, size: 18),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: AppSectionHeader(title: style.label, uppercase: true)),
        if (subtitle != null)
          Text(
            subtitle,
            style: AppTextStyles.labelSmall.copyWith(
              color: colors.textSecondary,
            ),
          ),
      ],
    );
  }

  Widget _buildTaskCard(
    MaintenanceTask task,
    int currentKm,
    AppSeverityStyle style,
  ) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = task.getStatus(currentKm);
    final kmDiff = currentKm - task.ultimoKm;
    final kmLeft = task.frecuenciaKm - kmDiff;
    final progress = (kmDiff / task.frecuenciaKm).clamp(0.0, 1.0);
    final statusLabel = task.getStatusLabel(currentKm);

    String subtitle;
    if (status == MaintenanceStatus.critical) {
      subtitle = context.l10n.alertsOverdue((-kmLeft).abs().toString());
    } else if (status == MaintenanceStatus.preventive) {
      subtitle = context.l10n.alertsMissingKm(kmLeft.toString());
    } else {
      subtitle = context.l10n.alertsNextServiceApprox(kmLeft.toString());
    }

    return Semantics(
      label: '${style.label}: ${task.nombre}',
      child: AppCard(
        margin: EdgeInsets.zero,
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Left accent bar
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(width: 4, color: style.color),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: style.color.withValues(
                              alpha: isDark ? 0.2 : 0.1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            style.icon,
                            color: style.color,
                            size: Responsive.iconSize(context, 24),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                task.nombre,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.titleSmall.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: colors.textPrimary,
                                ),
                              ),
                              Text(
                                subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: colors.textSecondary,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: style.color.withValues(
                              alpha: isDark ? 0.25 : 0.1,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            statusLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.labelSmall.copyWith(
                              fontWeight: FontWeight.w700,
                              color: style.color,
                              height: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 5,
                        backgroundColor: colors.surfaceVariant,
                        valueColor: AlwaysStoppedAnimation(style.color),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            context.l10n.alertsLastKm(
                              NumberFormat('#,###').format(task.ultimoKm),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: Text(
                            context.l10n.alertsEveryKm(
                              NumberFormat('#,###').format(task.frecuenciaKm),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: _buildCompactActionButton(
                            label: context.l10n.alertsConfig,
                            icon: Icons.settings,
                            onPressed: () =>
                                context.push('/task_config', extra: task),
                            outlined: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildCompactActionButton(
                            label: context.l10n.alertsComplete,
                            icon: Icons.check,
                            onPressed: () => context.push(
                              '/task_complete',
                              extra: {'task': task, 'currentKm': currentKm},
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlertCard(AlertModel alert, AppSeverityStyle style) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    IconData icon;
    switch (alert.tipoAlerta) {
      case 'SOAT':
        icon = Icons.gavel;
        break;
      case 'Aceite':
        icon = Icons.oil_barrel;
        break;
      case 'Llantas':
        icon = Icons.tire_repair;
        break;
      case 'Fluidos':
        icon = Icons.water_drop;
        break;
      case 'Luces':
        icon = Icons.lightbulb;
        break;
      case 'MantenimientoInconsistente':
        icon = Icons.speed;
        break;
      default:
        icon = Icons.info_outline;
    }

    // El provider no puede localizar este texto (no tiene BuildContext),
    // así que la pantalla lo arma aquí a partir del dato guardado en
    // metadata.
    final descripcion = alert.tipoAlerta == 'MantenimientoInconsistente'
        ? context.l10n.alertsInconsistentMileage(
            NumberFormat('#,###').format(alert.metadata?['ultimo_km'] ?? 0),
          )
        : alert.descripcion;

    return Semantics(
      label: '${style.label}: ${alert.titulo}',
      child: AppCard(
        margin: EdgeInsets.zero,
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(width: 4, color: style.color),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: style.color.withValues(
                          alpha: isDark ? 0.2 : 0.1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: style.color, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            alert.titulo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.titleSmall.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            descripcion,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: colors.textSecondary,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.check_circle_outline,
                        color: style.color.withValues(alpha: 0.5),
                      ),
                      onPressed: () => context
                          .read<AlertProvider>()
                          .completeAlert(alert.idAlerta),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    bool outlined = false,
  }) {
    return AppButton(
      text: label,
      icon: Icon(icon),
      size: AppButtonSize.small,
      type: outlined ? AppButtonType.text : AppButtonType.primary,
      onPressed: onPressed,
    );
  }

  void _showUpdateMileageDialog(BuildContext context) {
    final vehicleProvider = context.read<VehicleProvider>();
    final vehicle = vehicleProvider.selectedVehicle;
    if (vehicle == null) return;

    final controller = TextEditingController(
      text: vehicle.kilometrajeActual.toString(),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          context.l10n.alertsUpdateMileage,
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: AppTextField(
          controller: controller,
          keyboardType: TextInputType.number,
          label: context.l10n.alertsNewMileage,
          suffixText: context.l10n.vpKm,
        ),
        actions: [
          AppButton(
            onPressed: () => Navigator.pop(ctx),
            text: context.l10n.alertsCancel,
            type: AppButtonType.text,
          ),
          AppButton(
            onPressed: () async {
              final newKm = int.tryParse(controller.text);
              if (newKm != null && newKm >= vehicle.kilometrajeActual) {
                await vehicleProvider.updateVehicleMileage(
                  vehicle.idVehiculo,
                  newKm,
                );
                if (ctx.mounted) {
                  // Use fetchAlertsForVehicles (not the single-vehicle
                  // fetchAlerts) so we don't collapse the app-wide merged
                  // alert list back down to just this vehicle.
                  context.read<AlertProvider>().fetchAlertsForVehicles(
                    vehicleProvider.vehicles,
                  );
                  Navigator.pop(ctx);
                }
              }
            },
            text: context.l10n.alertsSave,
          ),
        ],
      ),
    );
  }
}
