import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/features/dashboard/presentation/providers/vehicle_provider.dart';
import 'package:autodoc/core/models/vehicle_model.dart';
import 'package:autodoc/core/models/maintenance_task_model.dart';
import 'package:autodoc/core/providers/user_session_provider.dart';
import 'package:autodoc/features/dashboard/presentation/providers/alert_provider.dart';
import 'package:autodoc/core/widgets/vehicle_image_widget.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/widgets/app_card.dart';
import 'package:autodoc/core/widgets/app_scaffold.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/widgets/app_skeleton_layouts.dart';
import '../widgets/add_vehicle_form.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:autodoc/core/utils/responsive.dart';
import 'package:autodoc/core/utils/l10n_extension.dart';
import 'package:autodoc/core/providers/auth_session_provider.dart';

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
                  ? AppSkeletonLayouts.listCards(
                      itemCount: 3,
                      cardHeight: 140,
                    )
                  : vehicles.isEmpty
                  ? _buildEmptyState(context, colors)
                  : AnimationLimiter(
                      child: ListView.builder(
                        padding: EdgeInsets.all(Responsive.padding(context, 16)),
                        itemCount: vehicles.length,
                        itemBuilder: (context, index) {
                          final vehicle = vehicles[index];
                          return AnimationConfiguration.staggeredList(
                            position: index,
                            duration: const Duration(milliseconds: 375),
                            child: SlideAnimation(
                              verticalOffset: 50.0,
                              child: FadeInAnimation(
                                child: _buildVehicleCard(
                                  context,
                                  vehicle,
                                  colors,
                                  vehicleProvider,
                                  currentUserId,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppColors colors) {
    return Container(
      padding: EdgeInsets.all(Responsive.padding(context, 16)),
      decoration: BoxDecoration(
        color: colors.surfaceContainer.withValues(alpha: 0.8),
        border: Border(
          bottom: BorderSide(color: colors.primary.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            color: colors.primary,
            onPressed: () => context.pop(),
          ),
          Text(
            context.l10n.garageMyVehicles,
            style: GoogleFonts.inter(
              fontSize: Responsive.fontSize(context, 18),
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: colors.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.add),
              color: Colors.white,
              iconSize: 20,
              onPressed: () => _showAddVehicleDialog(context, colors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppColors colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.directions_car_outlined,
            size: Responsive.iconSize(context, 64),
            color: colors.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.garageNoVehicles,
            style: GoogleFonts.inter(
              fontSize: Responsive.fontSize(context, 16),
              fontWeight: FontWeight.w500,
              color: colors.textSecondary,
            ),
          ),
        ],
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

    return AppCard(
      onTap: () => context.push('/vehicle_profile', extra: vehicle),
      margin: const EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image Section
            SizedBox(
              height: Responsive.heroHeight(context, 192),
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
                    top: 12,
                    left: 12,
                    child: FutureBuilder<MaintenanceStatus>(
                      future: context.read<AlertProvider>().getVehicleOverallStatus(vehicle),
                      builder: (context, snapshot) {
                        final worstStatus = snapshot.data ?? MaintenanceStatus.optimal;
                        
                        Color statusColor = colors.secondary;
                        String statusText = 'ÓPTIMO';
                        switch (worstStatus) {
                          case MaintenanceStatus.critical:
                            statusColor = colors.error;
                            statusText = 'ATENCIÓN REQUERIDA';
                            break;
                          case MaintenanceStatus.preventive:
                            statusColor = colors.warning;
                            statusText = 'REVISIÓN PRONTA';
                            break;
                          case MaintenanceStatus.optimal:
                            statusColor = colors.secondary;
                            statusText = 'ÓPTIMO';
                            break;
                        }

                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                statusText,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF334155),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                    ),
                  ),
                  // Primary Star Badge
                  if (vehicle.isPrimary)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.star,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Details Section
            Padding(
              padding: const EdgeInsets.all(16),
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
                          style: GoogleFonts.inter(
                            fontSize: Responsive.fontSize(context, 20),
                            fontWeight: FontWeight.bold,
                            color: colors.primary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          vehicle.placa.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 14,
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
                      if (!vehicle.isPrimary && vehicle.idPropietario == currentUserId)
                        AppButton(
                          onPressed: provider.isLoading
                              ? null
                              : () => _setVehicleAsPrimary(context, vehicle, provider),
                          text: context.l10n.garageMakePrimary,
                          type: AppButtonType.text,
                          icon: const Icon(Icons.star_border),
                        ),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
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
    final messenger = ScaffoldMessenger.of(context);
    final success = await provider.setAsPrimary(vehicle);

    if (!context.mounted) return;

    if (success) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.garageNowPrimary('${vehicle.marca ?? ''} ${vehicle.modelo ?? ''}'.trim()),
          ),
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            provider.error ?? context.l10n.garageMakePrimaryError,
          ),
        ),
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
          final userSession = context.read<UserSessionProvider>();
          final vehicleProvider = context.read<VehicleProvider>();

          final newVehicle = vehicle.copyWith(
            idVehiculo: const Uuid().v4(),
            idPropietario: userSession.user!.uid,
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
                    vehicleProvider.error ?? context.l10n.garageAddVehicleError,
                  ),
                ),
              );
            }
          }
        },
      ),
    );
  }
}
