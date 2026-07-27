import 'package:flutter/material.dart';
import '../widgets/vehicle_gallery_widget.dart';

import '../widgets/expense_summary_card.dart';
import '../../data/services/vehicle_service.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:autodoc/core/widgets/vehicle_image_widget.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/core/models/vehicle_model.dart';
import '../providers/vehicle_provider.dart';
import '../widgets/license_plate_widget.dart';
import 'package:autodoc/features/auth/presentation/providers/auth_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/widgets/app_scaffold.dart';
import 'package:autodoc/core/widgets/app_card.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import '../widgets/share_vehicle_sheet.dart';
import 'package:autodoc/core/utils/responsive.dart';
import 'package:autodoc/core/utils/l10n_extension.dart';
import 'package:autodoc/core/providers/auth_session_provider.dart';

class VehicleProfileScreen extends StatefulWidget {
  final VehicleModel vehicle;

  const VehicleProfileScreen({super.key, required this.vehicle});

  @override
  State<VehicleProfileScreen> createState() => _VehicleProfileScreenState();
}

class _VehicleProfileScreenState extends State<VehicleProfileScreen> {
  late VehicleModel _currentVehicle;

  @override
  void initState() {
    super.initState();
    _currentVehicle = widget.vehicle;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final vehicleProvider = context.watch<VehicleProvider>();
    final vehicle = vehicleProvider.vehicles.firstWhere(
      (v) => v.idVehiculo == _currentVehicle.idVehiculo,
      orElse: () => _currentVehicle,
    );

    return AppScaffold(
      useGradient: true,
      body: Column(
        children: [
          _buildHeader(context, colors, vehicle),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeroImage(vehicle, colors),
                  _buildVehicleIdentity(vehicle, colors),
                  _buildExpenseSummary(vehicle, colors),
                  _buildTechnicalDetails(vehicle, colors),
                  _buildNotesSection(vehicle, colors),
                  VehicleGalleryWidget(
                    vehicleId: vehicle.idVehiculo,
                    colors: colors,
                  ),
                  _buildDocumentationStatus(vehicle, colors),
                  _buildQuickActions(vehicle, colors),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    AppColors colors,
    VehicleModel vehicle,
  ) {
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
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
              onPressed: () => context.pop(),
              icon: Icon(
                Icons.arrow_back_ios_new,
                color: colors.primary,
                size: 20,
              ),
            ),
            Text(
              context.l10n.vpProfileTitle,
              style: GoogleFonts.inter(
                fontSize: Responsive.fontSize(context, 18),
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_horiz, color: colors.primary, size: 24),
              onSelected: (value) {
                if (value == 'delete') {
                  _showDeleteConfirmationDialog(context, vehicle, colors);
                } else if (value == 'share') {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => ShareVehicleSheet(
                      vehicle: vehicle,
                      onUpdated: (updated) {
                        setState(() => _currentVehicle = updated);
                      },
                    ),
                  );
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'share',
                  child: Row(
                    children: [
                      Icon(
                        Icons.people_outline,
                        color: colors.textSecondary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(context.l10n.vpShareVehicle),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      const Icon(Icons.delete, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        context.l10n.vpDeleteVehicle,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroImage(VehicleModel vehicle, AppColors colors) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 220,
            width: double.infinity,
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
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colors.secondary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            context.l10n.vpActiveStatus,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleIdentity(VehicleModel vehicle, AppColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${vehicle.marca} ${vehicle.modelo}',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
                Text(
                  context.l10n.vpOwnerPersonal,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          ElSalvadorLicensePlate(placa: vehicle.placa, width: 140, height: 80),
        ],
      ),
    );
  }

  Widget _buildExpenseSummary(VehicleModel vehicle, AppColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: FutureBuilder<Map<String, dynamic>>(
        future: VehicleService().getExpenseSummary(vehicle.idVehiculo),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError ||
              !snapshot.hasData ||
              snapshot.data!.isEmpty) {
            return const SizedBox.shrink();
          }
          return ExpenseSummaryCard(summary: snapshot.data!);
        },
      ),
    );
  }

  Widget _buildTechnicalDetails(VehicleModel vehicle, AppColors colors) {
    return Padding(
      padding: EdgeInsets.all(Responsive.padding(context, 20)),
      child: GridView.count(
        crossAxisCount: Responsive.isDesktop(context) ? 4 : 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: Responsive.padding(context, 16),
        crossAxisSpacing: Responsive.padding(context, 16),
        childAspectRatio: Responsive.isDesktop(context) ? 2.0 : 1.25,
        children: [
          _buildDetailItem(
            Icons.calendar_today,
            context.l10n.vpYear,
            vehicle.anio?.toString() ?? 'N/A',
            colors,
          ),
          _buildDetailItem(
            Icons.palette,
            context.l10n.vpColor,
            vehicle.color ?? 'N/A',
            colors,
          ),
          _buildDetailItem(
            Icons.speed,
            context.l10n.vpMileage,
            '${vehicle.kilometrajeActual} ${context.l10n.vpKm}',
            colors,
            onTap: () => _showEditMileageDialog(context, vehicle, colors),
          ),
          _buildDetailItem(
            Icons.directions_car,
            context.l10n.vpBrand,
            vehicle.marca ?? 'N/A',
            colors,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(
    IconData icon,
    String label,
    String value,
    AppColors colors, {
    VoidCallback? onTap,
  }) {
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.all(Responsive.padding(context, 12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  icon,
                  color: colors.primary,
                  size: Responsive.iconSize(context, 20),
                ),
                if (onTap != null)
                  Icon(
                    Icons.edit,
                    color: colors.primary.withValues(alpha: 0.5),
                    size: Responsive.iconSize(context, 14),
                  ),
              ],
            ),
            SizedBox(height: Responsive.padding(context, 6)),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: Responsive.fontSize(context, 11),
                color: colors.textSecondary,
                fontWeight: FontWeight.w500,
                height: 1.2,
              ),
            ),
            SizedBox(height: Responsive.padding(context, 2)),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: Responsive.fontSize(context, 14),
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection(VehicleModel vehicle, AppColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.vpQuickNotes,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              IconButton(
                icon: Icon(Icons.add, color: colors.primary),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) {
                      final controller = TextEditingController();
                      return AlertDialog(
                        title: const Text('Nueva Nota'),
                        content: TextField(
                          controller: controller,
                          decoration: const InputDecoration(
                            hintText: 'Escribe tu nota aquí...',
                          ),
                          maxLines: 3,
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancelar'),
                          ),
                          TextButton(
                            onPressed: () async {
                              final text = controller.text.trim();
                              if (text.isNotEmpty) {
                                final uid = context
                                    .read<AuthSessionProvider>()
                                    .user
                                    ?.uid;
                                final provider = context
                                    .read<VehicleProvider>();
                                await VehicleService().addNote(
                                  vehicle.idVehiculo,
                                  text,
                                );
                                if (uid != null) {
                                  provider.fetchVehicles(uid);
                                }
                              }
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                              }
                            },
                            child: const Text('Guardar'),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          ),
          if (vehicle.notas.isEmpty)
            Text(
              'No hay notas registradas.',
              style: TextStyle(color: colors.textSecondary),
            )
          else
            ...vehicle.notas.map(
              (nota) => Dismissible(
                key: Key(nota),
                direction: DismissDirection.endToStart,
                onDismissed: (direction) async {
                  final uid = context.read<AuthSessionProvider>().user?.uid;
                  final provider = context.read<VehicleProvider>();
                  await VehicleService().removeNote(vehicle.idVehiculo, nota);
                  if (uid != null) {
                    provider.fetchVehicles(uid);
                  }
                },
                background: Container(
                  color: colors.error,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16.0),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                child: Card(
                  margin: const EdgeInsets.only(bottom: 8.0),
                  color: isDark(context)
                      ? colors.surfaceContainer
                      : Colors.grey.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.sticky_note_2,
                          color: colors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            nota,
                            style: TextStyle(color: colors.textPrimary),
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
    );
  }

  bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  Widget _buildDocumentationStatus(VehicleModel vehicle, AppColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.vpDocAndAlerts,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _buildDocumentationStatusItem(
            context.l10n.vpCirculationCard,
            vehicle.vencimientoTarjeta,
            colors,
            () => _showUpdateDateDialog(context, vehicle, true),
          ),
          const SizedBox(height: 12),
          _buildDocumentationStatusItem(
            context.l10n.vpSoatInsurance,
            vehicle.vencimientoSoat,
            colors,
            () => _showUpdateDateDialog(context, vehicle, false),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentationStatusItem(
    String title,
    DateTime? expiryDate,
    AppColors colors,
    VoidCallback onUpdate,
  ) {
    if (expiryDate == null) {
      return _buildStatusAlert(
        icon: Icons.help_outline,
        title: title,
        subtitle: context.l10n.vpDateNotRegistered,
        color: Colors.grey,
        colors: colors,
        actionLabel: context.l10n.vpUpdate,
        onActionPressed: onUpdate,
      );
    }

    final now = DateTime.now();
    final difference = expiryDate.difference(now).inDays;
    final formattedDate = DateFormat('dd MMM yyyy').format(expiryDate);

    Color statusColor;
    IconData icon;
    String statusText;

    if (difference < 0) {
      statusColor = colors.error;
      icon = Icons.error_outline;
      statusText = context.l10n.vpExpiredOn(formattedDate);
    } else if (difference < 30) {
      statusColor = colors.warning;
      icon = Icons.warning_amber_rounded;
      statusText = context.l10n.vpExpiresInDays(
        difference.toString(),
        formattedDate,
      );
    } else {
      statusColor = colors.secondary;
      icon = Icons.verified_user_outlined;
      statusText = context.l10n.vpExpiresInDays(
        difference.toString(),
        formattedDate,
      );
    }

    return _buildStatusAlert(
      icon: icon,
      title: title,
      subtitle: statusText,
      color: statusColor,
      colors: colors,
      isVerified: difference >= 30,
      actionLabel: difference < 30 ? context.l10n.vpRenew : null,
      onActionPressed: onUpdate,
    );
  }

  Widget _buildStatusAlert({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required AppColors colors,
    bool isVerified = false,
    String? actionLabel,
    VoidCallback? onActionPressed,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: colors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (actionLabel != null)
            AppButton(
              text: actionLabel,
              onPressed: onActionPressed,
              type: AppButtonType.primary,
              // Overriding theme primary color if necessary, but AppButton uses colors.primary
            )
          else if (isVerified)
            Icon(Icons.check_circle, color: color, size: 20),
        ],
      ),
    );
  }

  Future<void> _showUpdateDateDialog(
    BuildContext context,
    VehicleModel vehicle,
    bool isTarjeta,
  ) async {
    final vehicleProvider = context.read<VehicleProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null && mounted) {
      final updatedVehicle = isTarjeta
          ? vehicle.copyWith(vencimientoTarjeta: pickedDate)
          : vehicle.copyWith(vencimientoSoat: pickedDate);

      final success = await vehicleProvider.updateVehicle(updatedVehicle);

      if (mounted) {
        if (success) {
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.vpDateUpdatedSuccess)),
          );
        } else {
          messenger.showSnackBar(
            SnackBar(
              content: Text(vehicleProvider.error ?? l10n.vpDateUpdateError),
            ),
          );
        }
      }
    }
  }

  Widget _buildQuickActions(VehicleModel vehicle, AppColors colors) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.vpQuickActions,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildActionButton(
                Icons.history,
                context.l10n.vpHistory,
                colors.primary,
                colors,
                onTap: () {
                  context.push('/service_history', extra: vehicle.idVehiculo);
                },
              ),
              const SizedBox(width: 12),
              _buildActionButton(
                Icons.build,
                context.l10n.vpServices,
                colors.secondary,
                colors,
                onTap: () {
                  context.push('/workshop_directory');
                },
              ),
              const SizedBox(width: 12),
              _buildActionButton(
                Icons.description,
                context.l10n.vpPapers,
                colors.warning,
                colors,
                onTap: () {
                  context.push('/alerts');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String label,
    Color color,
    AppColors colors, {
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: AppCard(
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditMileageDialog(
    BuildContext context,
    VehicleModel vehicle,
    AppColors colors,
  ) {
    final controller = TextEditingController(
      text: vehicle.kilometrajeActual.toString(),
    );
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text(
          context.l10n.vpUpdateMileage,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.l10n.vpEnterNewMileage(
                  vehicle.kilometrajeActual.toString(),
                ),
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: context.l10n.vpNewMileageLabel,
                  labelStyle: TextStyle(color: colors.textSecondary),
                  suffixText: context.l10n.vpKm,
                  suffixStyle: TextStyle(color: colors.textSecondary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.speed, color: colors.primary),
                ),
                style: TextStyle(color: colors.textPrimary),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return context.l10n.vpEnterValue;
                  }
                  final newMileage = int.tryParse(value);
                  if (newMileage == null) {
                    return context.l10n.vpEnterValidNumber;
                  }
                  if (newMileage <= vehicle.kilometrajeActual) {
                    return context.l10n.vpMustBeGreaterThan(
                      vehicle.kilometrajeActual.toString(),
                    );
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: Text(context.l10n.alertsCancel),
          ),
          AppButton(
            text: context.l10n.vpSave,
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final newMileage = int.parse(controller.text);
                final updatedVehicle = vehicle.copyWith(
                  kilometrajeActual: newMileage,
                );

                final vehicleProvider = context.read<VehicleProvider>();
                final messenger = ScaffoldMessenger.of(context);
                final success = await vehicleProvider.updateVehicle(
                  updatedVehicle,
                );

                if (context.mounted) {
                  if (success) {
                    context.pop();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(context.l10n.vpMileageUpdatedSuccess),
                      ),
                    );
                  } else {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          vehicleProvider.error ?? context.l10n.vpUpdateError,
                        ),
                      ),
                    );
                  }
                }
              }
            },
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmationDialog(
    BuildContext context,
    VehicleModel vehicle,
    AppColors colors,
  ) {
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isVerifying = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: colors.surface,
          title: Text(
            context.l10n.vpDeleteVehicle,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              color: colors.error,
            ),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.l10n.vpConfirmDelete(
                    vehicle.marca ?? '',
                    vehicle.modelo ?? '',
                  ),
                  style: TextStyle(fontSize: 14, color: colors.textPrimary),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: context.l10n.vpEnterPassword,
                    labelStyle: TextStyle(color: colors.textSecondary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: Icon(Icons.lock, color: colors.primary),
                  ),
                  style: TextStyle(color: colors.textPrimary),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return context.l10n.vpEnterPassword;
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isVerifying ? null : () => context.pop(),
              child: Text(context.l10n.alertsCancel),
            ),
            AppButton(
              text: context.l10n.vpDeleteVehicle,
              isLoading: isVerifying,
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  setState(() => isVerifying = true);

                  final vehicleProvider = context.read<VehicleProvider>();

                  final isValid = await context
                      .read<AuthProvider>()
                      .verifyPassword(passwordController.text);

                  if (context.mounted) {
                    if (!isValid) {
                      setState(() => isVerifying = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.l10n.vpIncorrectPassword),
                        ),
                      );
                      return;
                    }

                    final success = await vehicleProvider.deleteVehicle(
                      vehicle.idVehiculo,
                      vehicle.idPropietario,
                    );

                    if (context.mounted) {
                      setState(() => isVerifying = false);
                      if (success) {
                        final messenger = ScaffoldMessenger.of(context);
                        context.pop(); // Close dialog
                        context.pop(); // Go back to previous screen
                        messenger.showSnackBar(
                          SnackBar(content: Text(context.l10n.vpDeleteSuccess)),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              vehicleProvider.error ??
                                  context.l10n.vpDeleteError,
                            ),
                          ),
                        );
                      }
                    }
                  }
                }
              },
              // type: AppButtonType.primary, // Default is primary
            ),
          ],
        ),
      ),
    );
  }
}
