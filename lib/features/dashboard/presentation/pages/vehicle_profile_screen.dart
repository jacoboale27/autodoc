import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:autodoc/core/widgets/vehicle_image_widget.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/models/vehicle_model.dart';
import '../providers/vehicle_provider.dart';
import '../widgets/license_plate_widget.dart';
import 'package:go_router/go_router.dart';
import 'package:autodoc/features/auth/presentation/providers/auth_provider.dart';

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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryPurple = theme.colorScheme.primary;
    final bgColorStart = isDark ? const Color(0xFF1E293B) : const Color(0xFFF7F6F8);
    final bgColorEnd = isDark ? const Color(0xFF0F172A) : const Color(0xFFECE9F1);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextColor = isDark ? Colors.grey[400]! : const Color(0xFF64748B);
    final cardColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;

    final vehicleProvider = context.watch<VehicleProvider>();
    // Update local vehicle if provider has new data
    final updatedVehicle = vehicleProvider.vehicles.firstWhere(
      (v) => v.idVehiculo == _currentVehicle.idVehiculo,
      orElse: () => _currentVehicle,
    );
    _currentVehicle = updatedVehicle;

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
        child: Column(
          children: [
            _buildHeader(context, primaryPurple, isDark, textColor, subTextColor),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeroImage(_currentVehicle, isDark),
                    _buildVehicleIdentity(_currentVehicle, primaryPurple, textColor, subTextColor),
                    _buildTechnicalDetails(_currentVehicle, primaryPurple, isDark, cardColor, textColor, subTextColor),
                    _buildDocumentationStatus(_currentVehicle, primaryPurple, isDark, cardColor, textColor, subTextColor),
                    _buildQuickActions(_currentVehicle, primaryPurple, isDark, cardColor, textColor),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color primary, bool isDark, Color textColor, Color subTextColor) {
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.transparent : Colors.white,
          border: Border(bottom: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[200]!, width: 1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.arrow_back_ios_new, color: isDark ? Colors.white : primary, size: 20),
            ),
            Text(
              'Perfil del Vehículo',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_horiz, color: primary, size: 24),
              onSelected: (value) {
                if (value == 'delete') {
                  _showDeleteConfirmationDialog(context, _currentVehicle, primary, isDark, textColor, subTextColor);
                }
              },
              itemBuilder: (context) => [
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

  Widget _buildHeroImage(VehicleModel vehicle, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        height: 220,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
          boxShadow: isDark ? null : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              VehicleImageWidget(
                imageUrl: vehicle.fotoUrl,
                fit: BoxFit.cover,
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
                          color: const Color(0xFF22C55E),
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
    );
  }

  Widget _buildVehicleIdentity(VehicleModel vehicle, Color primary, Color textColor, Color subTextColor) {
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
                    color: textColor,
                  ),
                ),
                Text(
                  'Propietario: Personal',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: subTextColor,
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

  Widget _buildTechnicalDetails(VehicleModel vehicle, Color primary, bool isDark, Color cardColor, Color textColor, Color subTextColor) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.5,
        children: [
          _buildDetailItem(Icons.calendar_today, 'Año', vehicle.anio?.toString() ?? 'N/A', primary, cardColor, textColor, subTextColor),
          _buildDetailItem(Icons.palette, 'Color', vehicle.color ?? 'N/A', primary, cardColor, textColor, subTextColor),
          _buildDetailItem(
            Icons.speed, 
            'Kilometraje', 
            '${vehicle.kilometrajeActual} km', 
            primary,
            cardColor,
            textColor,
            subTextColor,
            onTap: () => _showEditMileageDialog(context, _currentVehicle, primary, isDark, textColor, subTextColor),
          ),
          _buildDetailItem(Icons.directions_car, 'Marca', vehicle.marca ?? 'N/A', primary, cardColor, textColor, subTextColor),
        ],
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value, Color primary, Color cardColor, Color textColor, Color subTextColor, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          boxShadow: onTap != null ? [
            BoxShadow(color: primary.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
          ] : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: primary, size: 20),
                if (onTap != null) Icon(Icons.edit, color: primary.withValues(alpha: 0.5), size: 14),
              ],
            ),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontSize: 11, color: subTextColor, fontWeight: FontWeight.w500)),
            Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentationStatus(VehicleModel vehicle, Color primary, bool isDark, Color cardColor, Color textColor, Color subTextColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Documentación y Alertas',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 12),
          _buildDocumentationStatusItem(
            'Tarjeta de Circulación',
            vehicle.vencimientoTarjeta,
            primary,
            cardColor,
            textColor,
            () => _showUpdateDateDialog(context, vehicle, true),
          ),
          const SizedBox(height: 12),
          _buildDocumentationStatusItem(
            'Seguro SOAT',
            vehicle.vencimientoSoat,
            primary,
            cardColor,
            textColor,
            () => _showUpdateDateDialog(context, vehicle, false),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentationStatusItem(String title, DateTime? expiryDate, Color primary, Color cardColor, Color textColor, VoidCallback onUpdate) {
    if (expiryDate == null) {
      return _buildStatusAlert(
        icon: Icons.help_outline,
        title: title,
        subtitle: 'Fecha no registrada',
        color: Colors.grey,
        cardColor: cardColor,
        textColor: textColor,
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
      statusColor = Colors.red;
      icon = Icons.error_outline;
      statusText = 'Vencido el $formattedDate';
    } else if (difference < 30) {
      statusColor = Colors.orange;
      icon = Icons.warning_amber_rounded;
      statusText = 'Vence en $difference días ($formattedDate)';
    } else {
      statusColor = Colors.green;
      icon = Icons.verified_user_outlined;
      statusText = 'Vence en $difference días ($formattedDate)';
    }

    return _buildStatusAlert(
      icon: icon,
      title: title,
      subtitle: statusText,
      color: statusColor,
      cardColor: cardColor,
      textColor: textColor,
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
    required Color cardColor,
    required Color textColor,
    bool isVerified = false,
    String? actionLabel,
    VoidCallback? onActionPressed,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isVerified ? color.withValues(alpha: 0.1) : color.withValues(alpha: 0.2)),
      ),
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
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
                Text(subtitle, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          if (actionLabel != null)
            ElevatedButton(
              onPressed: onActionPressed ?? () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(actionLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            )
          else if (isVerified)
            Icon(Icons.check_circle, color: color, size: 20),
        ],
      ),
    );
  }

  Future<void> _showUpdateDateDialog(BuildContext context, VehicleModel vehicle, bool isTarjeta) async {
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
        
      final vehicleProvider = context.read<VehicleProvider>();
      final messenger = ScaffoldMessenger.of(context);
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

  Widget _buildQuickActions(VehicleModel vehicle, Color primary, bool isDark, Color cardColor, Color textColor) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Acciones Rápidas',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildActionButton(Icons.history, 'Historial', Colors.blue, primary, cardColor, textColor, isDark, onTap: () {
                context.push('/service_history', extra: vehicle.idVehiculo);
              }),
              const SizedBox(width: 12),
              _buildActionButton(Icons.build, 'Servicios', Colors.orange, primary, cardColor, textColor, isDark, onTap: () {
                context.push('/workshop_directory');
              }),
              const SizedBox(width: 12),
              _buildActionButton(Icons.description, 'Papeles', Colors.green, primary, cardColor, textColor, isDark, onTap: () {
                context.push('/alerts');
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color, Color primary, Color cardColor, Color textColor, bool isDark, {VoidCallback? onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap ?? () {},
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[200]!),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 8),
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor)),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditMileageDialog(BuildContext context, VehicleModel vehicle, Color primary, bool isDark, Color textColor, Color subTextColor) {
    final controller = TextEditingController(text: vehicle.kilometrajeActual.toString());
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Text('Actualizar Kilometraje', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: textColor)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Ingresa el kilometraje actual. Debe ser mayor a ${vehicle.kilometrajeActual} km.',
                style: TextStyle(fontSize: 13, color: subTextColor),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Nuevo Kilometraje',
                  labelStyle: TextStyle(color: subTextColor),
                  suffixText: 'km',
                  suffixStyle: TextStyle(color: subTextColor),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: Icon(Icons.speed, color: primary),
                ),
                style: TextStyle(color: textColor),
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
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final newMileage = int.parse(controller.text);
                final updatedVehicle = vehicle.copyWith(kilometrajeActual: newMileage);
                
                final vehicleProvider = context.read<VehicleProvider>();
                final success = await vehicleProvider.updateVehicle(updatedVehicle);
                
                if (context.mounted) {
                  if (success) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Kilometraje actualizado correctamente')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(vehicleProvider.error ?? 'Error al actualizar')),
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context, VehicleModel vehicle, Color primary, bool isDark, Color textColor, Color subTextColor) {
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isVerifying = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          title: Text('Eliminar Vehículo', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.red)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '¿Estás seguro que deseas eliminar el ${vehicle.marca} ${vehicle.modelo}? Esta acción no se puede deshacer.',
                  style: TextStyle(fontSize: 14, color: textColor),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Ingresa tu contraseña',
                    labelStyle: TextStyle(color: subTextColor),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: Icon(Icons.lock, color: primary),
                  ),
                  style: TextStyle(color: textColor),
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
              onPressed: isVerifying ? null : () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: isVerifying ? null : () async {
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
                        Navigator.pop(context); // Close dialog
                        context.pop(); // Go back to previous screen
                        ScaffoldMessenger.of(context).showSnackBar(
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
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: isVerifying 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Eliminar'),
            ),
          ],
        ),
      ),
    );
  }
}
