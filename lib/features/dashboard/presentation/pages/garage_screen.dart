import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/features/dashboard/presentation/providers/vehicle_provider.dart';
import 'package:autodoc/core/models/vehicle_model.dart';
import 'package:autodoc/core/models/maintenance_task_model.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/providers/auth_session_provider.dart';
import 'package:autodoc/features/dashboard/presentation/providers/alert_provider.dart';
import 'package:autodoc/core/widgets/vehicle_image_widget.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_motion.dart';
import 'package:autodoc/core/theme/app_radius.dart';
import 'package:autodoc/core/theme/app_severity.dart';
import 'package:autodoc/core/theme/app_shadows.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/widgets/app_card.dart';
import 'package:autodoc/core/widgets/app_empty_state.dart';
import 'package:autodoc/core/widgets/app_grid.dart';
import 'package:autodoc/core/widgets/app_page_body.dart';
import 'package:autodoc/core/widgets/app_scaffold.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/widgets/app_skeleton_layouts.dart';
import '../widgets/add_vehicle_form.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:autodoc/core/utils/l10n_extension.dart';
import 'package:autodoc/core/utils/ui_utils.dart';

class GarageScreen extends StatelessWidget {
  const GarageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final vehicleProvider = context.watch<VehicleProvider>();
    final vehicles = vehicleProvider.vehicles;
    final currentUserId = context.watch<AuthSessionProvider>().user?.uid;

    return AppScaffold(
      useGradient: true,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, colors),
            Expanded(
              child: vehicleProvider.isLoading
                  ? AppSkeletonLayouts.listCards(itemCount: 3, cardHeight: 140)
                  : vehicles.isEmpty
                  ? AppEmptyState(
                      icon: Icons.directions_car_outlined,
                      title: context.l10n.garageNoVehicles,
                      description: context.l10n.garageNoVehicles,
                      action: AppButton(
                        text: 'Añadir vehículo',
                        icon: const Icon(Icons.add),
                        onPressed: () =>
                            _showAddVehicleDialog(context, colors.primary),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.base,
                      ),
                      child: AppPageBody(
                        child: AnimationLimiter(
                          child: AppGrid(
                            compactColumns: 1,
                            mediumColumns: 2,
                            expandedColumns: 3,
                            largeColumns: 4,
                            childAspectRatio: 0.95,
                            children: [
                              for (
                                var index = 0;
                                index < vehicles.length;
                                index++
                              )
                                AnimationConfiguration.staggeredGrid(
                                  position: index,
                                  columnCount: 1,
                                  duration: AppMotion.transformDuration(
                                    context,
                                    AppMotion.sheetEnter,
                                  ),
                                  child: SlideAnimation(
                                    verticalOffset: AppMotion.reduced(context)
                                        ? 0
                                        : 24,
                                    child: FadeInAnimation(
                                      child: _buildVehicleCard(
                                        context,
                                        vehicles[index],
                                        colors,
                                        vehicleProvider,
                                        currentUserId,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppColors colors) {
    // Garage es una pestaña del ShellRoute (Fase 2): no hay a dónde volver,
    // así que ya no lleva un botón "atrás" propio.
    return AppPageBody(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.base),
        child: Row(
          children: [
            Expanded(
              child: Text(
                context.l10n.garageMyVehicles,
                style: AppTextStyles.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
            ),
            IconButton.filled(
              icon: const Icon(Icons.add),
              tooltip: 'Añadir vehículo',
              style: IconButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                minimumSize: const Size(48, 48),
              ),
              onPressed: () => _showAddVehicleDialog(context, colors.primary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleCard(
    BuildContext context,
    VehicleModel vehicle,
    AppColors colors,
    VehicleProvider provider,
    String? currentUserId,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppCard(
      onTap: () => context.push(
        '/vehicle_profile/${vehicle.idVehiculo}',
        extra: vehicle,
      ),
      semanticLabel:
          '${vehicle.marca ?? ''} ${vehicle.modelo ?? ''}, placa '
          '${vehicle.placa}',
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image Section
            AspectRatio(
              aspectRatio: 16 / 10,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: 'vehicle_image_${vehicle.idVehiculo}',
                    child: VehicleImageWidget(
                      imageUrl: vehicle.fotoUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
                  // Status Badge
                  Positioned(
                    top: AppSpacing.md,
                    left: AppSpacing.md,
                    child: FutureBuilder<MaintenanceStatus>(
                      future: context
                          .read<AlertProvider>()
                          .getVehicleOverallStatus(vehicle),
                      builder: (context, snapshot) {
                        final severity = AppSeverity.forStatus(
                          snapshot.data ?? MaintenanceStatus.optimal,
                          colors,
                          optimalLabel: context.l10n.garageOptimal,
                          preventiveLabel: context.l10n.garageSuggestedReview,
                          // No existe una clave l10n para el estado crítico
                          // en lib/l10n/; añadirla queda fuera del alcance
                          // de esta fase.
                          criticalLabel: 'Atención requerida',
                        );

                        return Semantics(
                          label: severity.label,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.xs + 2,
                            ),
                            decoration: BoxDecoration(
                              color: colors.surfaceContainer.withValues(
                                alpha: 0.92,
                              ),
                              borderRadius: BorderRadius.circular(
                                AppRadius.full,
                              ),
                              boxShadow: isDark
                                  ? AppShadows.darkSm
                                  : AppShadows.lightSm,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  severity.icon,
                                  color: severity.color,
                                  size: 14,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  severity.label.toUpperCase(),
                                  style: AppTextStyles.labelSmall.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colors.textPrimary,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Primary Star Badge
                  if (vehicle.isPrimary)
                    Positioned(
                      top: AppSpacing.md,
                      right: AppSpacing.md,
                      child: Semantics(
                        label: 'Vehículo principal',
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: colors.warning,
                            shape: BoxShape.circle,
                            boxShadow: isDark
                                ? AppShadows.darkSm
                                : AppShadows.lightSm,
                          ),
                          child: Icon(
                            Icons.star,
                            color: colors.onPrimary,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Details Section
            Padding(
              padding: const EdgeInsets.all(AppSpacing.base),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${vehicle.marca ?? ''} ${vehicle.modelo ?? ''}',
                          style: AppTextStyles.titleLarge.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colors.primary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          vehicle.placa.toUpperCase(),
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colors.textSecondary,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      if (!vehicle.isPrimary &&
                          vehicle.idPropietario == currentUserId)
                        // Icono y no boton con texto: "Hacer Principal" mide
                        // ~150 px y, junto al chevron de 40, no dejaba sitio
                        // al Expanded del nombre. A 768 px el titulo caia a
                        // dos letras.
                        IconButton(
                          tooltip: context.l10n.garageMakePrimary,
                          icon: const Icon(Icons.star_border),
                          color: colors.primary,
                          onPressed: provider.isLoading
                              ? null
                              : () => _setVehicleAsPrimary(
                                  context,
                                  vehicle,
                                  provider,
                                ),
                        ),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Icon(Icons.chevron_right, color: colors.primary),
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

  Future<void> _setVehicleAsPrimary(
    BuildContext context,
    VehicleModel vehicle,
    VehicleProvider provider,
  ) async {
    final success = await provider.setAsPrimary(vehicle);

    if (!context.mounted) return;

    if (success) {
      UiUtils.showSuccessSnackbar(
        context,
        context.l10n.garageNowPrimary(
          '${vehicle.marca ?? ''} ${vehicle.modelo ?? ''}'.trim(),
        ),
      );
    } else {
      UiUtils.showErrorSnackbar(
        context,
        provider.error ?? context.l10n.garageMakePrimaryError,
      );
    }
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
                vehicleProvider.error ?? context.l10n.garageAddVehicleError,
              );
            }
          }
        },
      ),
    );
  }
}
