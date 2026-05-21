import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:autodoc/core/widgets/vehicle_image_widget.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/core/models/vehicle_model.dart';
import '../providers/vehicle_provider.dart';
import '../widgets/license_plate_widget.dart';
import 'package:go_router/go_router.dart';
import 'package:autodoc/features/auth/presentation/providers/auth_provider.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/widgets/app_scaffold.dart';
import 'package:autodoc/core/widgets/app_card.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import '../widgets/share_vehicle_sheet.dart';

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
                  _buildTechnicalDetails(vehicle, colors),
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

  Widget _buildHeader(BuildContext context, AppColors colors, VehicleModel vehicle) {
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
              icon: Icon(Icons.arrow_back_ios_new, color: colors.primary, size: 20),
            ),
            Text(
              'Perfil del Vehículo',
              style: GoogleFonts.inter(
                fontSize: 18,
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
                      Icon(Icons.people_outline, color: colors.textSecondary, size: 20),
                      const SizedBox(width: 8),
                      const Text('Compartir Vehículo'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text('Eliminar Vehículo', style: TextStyle(color: Colors.red)),
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
                        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: colors.secondary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'ACTIVO',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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
                  'Propietario: Personal',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          ElSalvadorLicensePlate(
            placa: vehicle.placa,
            width: 140,
            height: 80,
          ),
        ],
      ),
    );
  }

  Widget _buildTechnicalDetails(VehicleModel vehicle, AppColors colors) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.25,
        children: [
          _buildDetailItem(Icons.calendar_today, 'Año', vehicle.anio?.toString() ?? 'N/A', colors),
          _buildDetailItem(Icons.palette, 'Color', vehicle.color ?? 'N/A', colors),
          _buildDetailItem(
            Icons.speed, 
            'Kilometraje', 
            '${vehicle.kilometrajeActual} km', 
            colors,
            onTap: () => _showEditMileageDialog(context, vehicle, colors),
          ),
          _buildDetailItem(Icons.directions_car, 'Marca', vehicle.marca ?? 'N/A', colors),
        ],
      ),
    );
  }
 
  Widget _buildDetailItem(IconData icon, String label, String value, AppColors colors, {VoidCallback? onTap}) {
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: colors.primary, size: 20),
                if (onTap != null) Icon(Icons.edit, color: colors.primary.withValues(alpha: 0.5), size: 14),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: colors.textSecondary, fontWeight: FontWeight.w500, height: 1.2),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.textPrimary, height: 1.2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentationStatus(VehicleModel vehicle, AppColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Documentación y Alertas',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: colors.textPrimary),
          ),
          const SizedBox(height: 12),
          _buildDocumentationStatusItem(
            'Tarjeta de Circulación',
            vehicle.vencimientoTarjeta,
            colors,
            () => _showUpdateDateDialog(context, vehicle, true),
          ),
          const SizedBox(height: 12),
          _buildDocumentationStatusItem(
            'Seguro SOAT',
            vehicle.vencimientoSoat,
            colors,
            () => _showUpdateDateDialog(context, vehicle, false),
          ),
        ],
      ),
    );
  }
 
  Widget _buildDocumentationStatusItem(String title, DateTime? expiryDate, AppColors colors, VoidCallback onUpdate) {
    if (expiryDate == null) {
      return _buildStatusAlert(
        icon: Icons.help_outline,
        title: title,
        subtitle: 'Fecha no registrada',
        color: Colors.grey,
        colors: colors,
        actionLabel: 'Actualizar',
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
      statusText = 'Vencido el $formattedDate';
    } else if (difference < 30) {
      statusColor = colors.warning;
      icon = Icons.warning_amber_rounded;
      statusText = 'Vence en $difference días ($formattedDate)';
    } else {
      statusColor = colors.secondary;
      icon = Icons.verified_user_outlined;
      statusText = 'Vence en $difference días ($formattedDate)';
    }
 
    return _buildStatusAlert(
      icon: icon,
      title: title,
      subtitle: statusText,
      color: statusColor,
      colors: colors,
      isVerified: difference >= 30,
      actionLabel: difference < 30 ? 'Renovar' : null,
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
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: colors.textPrimary)),
                Text(subtitle, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
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
  Future<void> _showUpdateDateDialog(BuildContext context, VehicleModel vehicle, bool isTarjeta) async {
    final vehicleProvider = context.read<VehicleProvider>();
    final messenger = ScaffoldMessenger.of(context);

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
            const SnackBar(content: Text('Fecha actualizada correctamente')),
          );
        } else {
          messenger.showSnackBar(
            SnackBar(content: Text(vehicleProvider.error ?? 'Error al actualizar fecha')),
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
            'Acciones Rápidas',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: colors.textPrimary),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildActionButton(Icons.history, 'Historial', colors.primary, colors, onTap: () {
                context.push('/service_history', extra: vehicle.idVehiculo);
              }),
              const SizedBox(width: 12),
              _buildActionButton(Icons.build, 'Servicios', colors.secondary, colors, onTap: () {
                context.push('/workshop_directory');
              }),
              const SizedBox(width: 12),
              _buildActionButton(Icons.description, 'Papeles', colors.warning, colors, onTap: () {
                context.push('/alerts');
              }),
            ],
          ),
        ],
      ),
    );
  }
 
  Widget _buildActionButton(IconData icon, String label, Color color, AppColors colors, {VoidCallback? onTap}) {
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
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textPrimary)),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditMileageDialog(BuildContext context, VehicleModel vehicle, AppColors colors) {
    final controller = TextEditingController(text: vehicle.kilometrajeActual.toString());
    final formKey = GlobalKey<FormState>();
 
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text('Actualizar Kilometraje', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: colors.textPrimary)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Ingresa el kilometraje actual. Debe ser mayor a ${vehicle.kilometrajeActual} km.',
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Nuevo Kilometraje',
                  labelStyle: TextStyle(color: colors.textSecondary),
                  suffixText: 'km',
                  suffixStyle: TextStyle(color: colors.textSecondary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: Icon(Icons.speed, color: colors.primary),
                ),
                style: TextStyle(color: colors.textPrimary),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Ingresa un valor';
                  final newMileage = int.tryParse(value);
                  if (newMileage == null) return 'Ingresa un número válido';
                  if (newMileage <= vehicle.kilometrajeActual) {
                    return 'Debe ser mayor a ${vehicle.kilometrajeActual}';
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
            child: const Text('Cancelar'),
          ),
          AppButton(
            text: 'Guardar',
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final newMileage = int.parse(controller.text);
                final updatedVehicle = vehicle.copyWith(kilometrajeActual: newMileage);
                
                final vehicleProvider = context.read<VehicleProvider>();
                final messenger = ScaffoldMessenger.of(context);
                final success = await vehicleProvider.updateVehicle(updatedVehicle);
                
                if (context.mounted) {
                  if (success) {
                    context.pop();
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Kilometraje actualizado correctamente')),
                    );
                  } else {
                    messenger.showSnackBar(
                      SnackBar(content: Text(vehicleProvider.error ?? 'Error al actualizar')),
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

  void _showDeleteConfirmationDialog(BuildContext context, VehicleModel vehicle, AppColors colors) {
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isVerifying = false;
 
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: colors.surface,
          title: Text('Eliminar Vehículo', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: colors.error)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '¿Estás seguro que deseas eliminar el ${vehicle.marca} ${vehicle.modelo}? Esta acción no se puede deshacer.',
                  style: TextStyle(fontSize: 14, color: colors.textPrimary),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Ingresa tu contraseña',
                    labelStyle: TextStyle(color: colors.textSecondary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: Icon(Icons.lock, color: colors.primary),
                  ),
                  style: TextStyle(color: colors.textPrimary),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Ingresa tu contraseña';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isVerifying ? null : () => context.pop(),
              child: const Text('Cancelar'),
            ),
            AppButton(
              text: 'Eliminar',
              isLoading: isVerifying,
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  setState(() => isVerifying = true);
                  
                  final authProvider = context.read<AuthProvider>();
                  final vehicleProvider = context.read<VehicleProvider>();
                  
                  final isValid = await authProvider.verifyPassword(passwordController.text);
                  
                  if (context.mounted) {
                    if (!isValid) {
                      setState(() => isVerifying = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Contraseña incorrecta')),
                      );
                      return;
                    }
                    
                    final success = await vehicleProvider.deleteVehicle(vehicle.idVehiculo, vehicle.idPropietario);
                    
                    if (context.mounted) {
                      setState(() => isVerifying = false);
                      if (success) {
                        final messenger = ScaffoldMessenger.of(context);
                        context.pop(); // Close dialog
                        context.pop(); // Go back to previous screen
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Vehículo eliminado correctamente')),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(vehicleProvider.error ?? 'Error al eliminar')),
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
