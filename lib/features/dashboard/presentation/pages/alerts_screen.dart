import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:autodoc/features/dashboard/presentation/providers/alert_provider.dart';
import 'package:autodoc/features/dashboard/presentation/providers/vehicle_provider.dart';
import 'package:autodoc/core/models/alert_model.dart';
import 'package:autodoc/core/models/maintenance_task_model.dart';
import 'package:intl/intl.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/widgets/app_card.dart';
import 'package:autodoc/core/widgets/app_scaffold.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/widgets/app_text_field.dart';
import 'package:autodoc/core/widgets/app_skeleton_layouts.dart';

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
          _buildHeader(context, isDark, colors.primary, colors.surfaceContainer),
          // Tabs
          _buildTabs(isDark, colors.primary, colors.textSecondary, colors.surfaceContainer),
          // Content
          Expanded(
            child: vehicle == null
                ? Center(
                    child: Text(
                      'Selecciona un vehículo primero',
                      style: TextStyle(color: colors.textSecondary),
                    ),
                  )
                : alertProvider.isLoading
                ? AppSkeletonLayouts.listCards(itemCount: 4, cardHeight: 100)
                : _buildContent(
                    alertProvider,
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
    return Container(
      padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            right: 8,
            bottom: 12,
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
                icon: Icon(
                  Icons.arrow_back_ios_new,
                  color: isDark ? Colors.white70 : Colors.grey[700],
                ),
                onPressed: () => context.pop(),
              ),
              Text(
                'Alertas',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: primary,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.update, color: primary),
                tooltip: 'Actualizar Kilometraje',
                onPressed: () => _showUpdateMileageDialog(context),
              ),
            ],
          ),
    );
  }

  Widget _buildTabs(
    bool isDark,
    Color primary,
    Color subTextColor,
    Color cardColor,
  ) {
    final tabs = ['Todas', 'Urgentes', 'Próximas'];
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        border: Border(
          bottom: BorderSide(color: primary.withValues(alpha: 0.1)),
        ),
      ),
      padding: const EdgeInsets.only(left: 16, right: 16, top: 12),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final isActive = _selectedTab == i;
          return Padding(
            padding: const EdgeInsets.only(right: 24),
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = i),
              child: Container(
                padding: const EdgeInsets.only(bottom: 12),
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
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    color: isActive ? primary : subTextColor,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildContent(
    AlertProvider provider,
    int currentKm,
    bool isDark,
    Color primary,
    Color textColor,
    Color subTextColor,
    Color cardColor,
  ) {
    // Separate tasks by status
    final criticalTasks = <MaintenanceTask>[];
    final preventiveTasks = <MaintenanceTask>[];
    final optimalTasks = <MaintenanceTask>[];

    for (var task in provider.maintenanceTasks) {
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
    final highAlerts = provider.activeAlerts
        .where((a) => a.prioridad == AlertPriority.high)
        .toList();
    final medAlerts = provider.activeAlerts
        .where((a) => a.prioridad == AlertPriority.medium)
        .toList();
    final lowAlerts = provider.activeAlerts
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
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.verified_outlined,
              size: 56,
              color: Colors.green.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              '¡Todo al día!',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'No hay alertas en esta categoría.',
              style: TextStyle(color: subTextColor, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Mileage indicator
        _buildMileageChip(currentKm, primary, isDark),
        const SizedBox(height: 20),

        // Critical Section
        if (showCritical &&
            (criticalTasks.isNotEmpty || highAlerts.isNotEmpty)) ...[
          _buildSectionHeader(
            'Prioridad Alta',
            Colors.red,
            '${criticalTasks.length + highAlerts.length} pendientes',
          ),
          const SizedBox(height: 12),
          ...criticalTasks.map(
            (t) => _buildTaskCard(
              t,
              currentKm,
              Colors.red,
              isDark,
              primary,
              textColor,
              subTextColor,
              cardColor,
            ),
          ),
          ...highAlerts.map(
            (a) => _buildAlertCard(
              a,
              Colors.red,
              isDark,
              textColor,
              subTextColor,
              cardColor,
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Preventive Section
        if (showPreventive &&
            (preventiveTasks.isNotEmpty || medAlerts.isNotEmpty)) ...[
          _buildSectionHeader(
            'Próximos Vencimientos',
            Colors.amber[700]!,
            '${preventiveTasks.length + medAlerts.length} eventos',
          ),
          const SizedBox(height: 12),
          ...preventiveTasks.map(
            (t) => _buildTaskCard(
              t,
              currentKm,
              Colors.amber[700]!,
              isDark,
              primary,
              textColor,
              subTextColor,
              cardColor,
            ),
          ),
          ...medAlerts.map(
            (a) => _buildAlertCard(
              a,
              Colors.amber[700]!,
              isDark,
              textColor,
              subTextColor,
              cardColor,
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Optimal / Suggestions
        if (showOptimal &&
            (optimalTasks.isNotEmpty || lowAlerts.isNotEmpty)) ...[
          _buildSectionHeader('Sugerencias', primary, null),
          const SizedBox(height: 12),
          ...optimalTasks.map(
            (t) => _buildTaskCard(
              t,
              currentKm,
              primary,
              isDark,
              primary,
              textColor,
              subTextColor,
              cardColor,
            ),
          ),
          ...lowAlerts.map(
            (a) => _buildAlertCard(
              a,
              primary,
              isDark,
              textColor,
              subTextColor,
              cardColor,
            ),
          ),
        ],
        const SizedBox(height: 80),
      ],
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
          Icon(Icons.speed, color: primary, size: 20),
          const SizedBox(width: 10),
          Text(
            'Kilometraje actual: ',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: primary.withValues(alpha: 0.7),
            ),
          ),
          Text(
            '${NumberFormat('#,###').format(km)} km',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: primary,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => _showUpdateMileageDialog(context),
            child: Icon(Icons.edit, size: 16, color: primary),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color, String? subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: color,
            ),
          ),
          const Spacer(),
          if (subtitle != null)
            Text(
              subtitle,
              style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
            ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(
    MaintenanceTask task,
    int currentKm,
    Color accentColor,
    bool isDark,
    Color primary,
    Color textColor,
    Color subTextColor,
    Color cardColor,
  ) {
    final status = task.getStatus(currentKm);
    final kmDiff = currentKm - task.ultimoKm;
    final kmLeft = task.frecuenciaKm - kmDiff;
    final progress = (kmDiff / task.frecuenciaKm).clamp(0.0, 1.0);
    final statusLabel = task.getStatusLabel(currentKm);

    String subtitle;
    if (status == MaintenanceStatus.critical) {
      subtitle = 'Superado por ${(-kmLeft).abs()} km. ¡Atención inmediata!';
    } else if (status == MaintenanceStatus.preventive) {
      subtitle = 'Faltan $kmLeft km para la revisión programada.';
    } else {
      subtitle = 'Próximo servicio en $kmLeft km aprox.';
    }

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
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
              child: Container(width: 4, color: accentColor),
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
                          color: accentColor.withValues(
                            alpha: isDark ? 0.2 : 0.1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.build_circle_outlined,
                          color: accentColor,
                          size: 24,
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
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: textColor,
                              ),
                            ),
                            Text(
                              subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: subTextColor,
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
                          color: accentColor.withValues(
                            alpha: isDark ? 0.25 : 0.1,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          statusLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: accentColor,
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
                      backgroundColor: Colors.grey.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation(accentColor),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Último: ${NumberFormat('#,###').format(task.ultimoKm)} km',
                        style: TextStyle(fontSize: 10, color: subTextColor),
                      ),
                      Text(
                        'Cada ${NumberFormat('#,###').format(task.frecuenciaKm)} km',
                        style: TextStyle(fontSize: 10, color: subTextColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: _buildCompactActionButton(
                          label: 'Configurar',
                          icon: Icons.settings,
                          accentColor: primary,
                          onPressed: () => context.push('/task_config', extra: task),
                          outlined: true,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildCompactActionButton(
                          label: 'Completar',
                          icon: Icons.check,
                          accentColor: accentColor,
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
    );
  }

  Widget _buildAlertCard(
    AlertModel alert,
    Color accentColor,
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color cardColor,
  ) {
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
      default:
        icon = Icons.info_outline;
    }

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(width: 4, color: accentColor),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: accentColor, size: 22),
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
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          alert.descripcion,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: subTextColor,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.check_circle_outline,
                      color: accentColor.withValues(alpha: 0.5),
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
    );
  }

  Widget _buildCompactActionButton({
    required String label,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onPressed,
    bool outlined = false,
  }) {
    final style = outlined
        ? OutlinedButton.styleFrom(
            foregroundColor: accentColor,
            side: BorderSide(color: accentColor.withValues(alpha: 0.4)),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
            visualDensity: VisualDensity.compact,
            minimumSize: const Size(0, 40),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          )
        : ElevatedButton.styleFrom(
            backgroundColor: accentColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
            visualDensity: VisualDensity.compact,
            minimumSize: const Size(0, 40),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            elevation: 0,
          );

    final button = outlined
        ? OutlinedButton.icon(onPressed: onPressed, style: style, icon: Icon(icon, size: 16), label: _compactLabel(label))
        : ElevatedButton.icon(onPressed: onPressed, style: style, icon: Icon(icon, size: 16), label: _compactLabel(label));

    return SizedBox(height: 40, child: button);
  }

  Widget _compactLabel(String label) {
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
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
          'Actualizar Kilometraje',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: AppTextField(
          controller: controller,
          keyboardType: TextInputType.number,
          label: 'Nuevo Kilometraje',
          suffixText: 'km',
        ),
        actions: [
          AppButton(
            onPressed: () => Navigator.pop(ctx),
            text: 'Cancelar',
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
                  context.read<AlertProvider>().fetchAlerts(
                    vehicle.idVehiculo,
                    vehicleProvider.selectedVehicle!,
                  );
                  Navigator.pop(ctx);
                }
              }
            },
            text: 'Guardar',
          ),
        ],
      ),
    );
  }
}
