import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/features/dashboard/presentation/providers/vehicle_provider.dart';
import 'package:autodoc/core/models/vehicle_model.dart';
import 'package:autodoc/features/auth/presentation/providers/auth_provider.dart';
import 'package:autodoc/features/dashboard/presentation/providers/alert_provider.dart';
import 'package:autodoc/core/widgets/vehicle_image_widget.dart';
import '../widgets/add_vehicle_form.dart';
import 'package:uuid/uuid.dart';

class GarageScreen extends StatelessWidget {
  const GarageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final primaryPurple = theme.colorScheme.primary;
    final bgColorStart = isDark ? const Color(0xFF1E293B) : const Color(0xFFF7F6F8);
    final cardColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextColor = isDark ? Colors.white70 : const Color(0xFF64748B);
    
    final vehicleProvider = context.watch<VehicleProvider>();
    final vehicles = vehicleProvider.vehicles;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark 
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [bgColorStart, Colors.white, const Color(0xFFF3F1F5)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context, primaryPurple, isDark, textColor),
              Expanded(
                child: vehicles.isEmpty
                    ? _buildEmptyState(context, primaryPurple, subTextColor)
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: vehicles.length,
                        itemBuilder: (context, index) {
                          final vehicle = vehicles[index];
                          return _buildVehicleCard(context, vehicle, primaryPurple, vehicleProvider, isDark, cardColor, textColor, subTextColor);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color primary, bool isDark, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.8),
        border: Border(bottom: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.1) : primary.withValues(alpha: 0.1))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            color: primary,
            onPressed: () => context.pop(),
          ),
          Text(
            'Mis Vehículos',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: primary.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.add),
              color: Colors.white,
              iconSize: 20,
              onPressed: () => _showAddVehicleDialog(context, primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, Color primary, Color subTextColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.directions_car_outlined, size: 64, color: primary.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            'No tienes vehículos en tu garaje',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: subTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleCard(BuildContext context, VehicleModel vehicle, Color primary, VehicleProvider provider, bool isDark, Color cardColor, Color textColor, Color subTextColor) {
    // Determine status (mocked logic based on html)
    // For now, let's just make it "Óptimo" if kilometraje < 10000
    final isOptimo = vehicle.kilometrajeActual < 10000;
    final statusColor = isOptimo ? Colors.green : Colors.yellow[700]!;
    final statusText = isOptimo ? 'Óptimo' : 'Revisión Sugerida';

    return GestureDetector(
      onTap: () => context.push('/vehicle_profile', extra: vehicle),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image Section
              SizedBox(
                height: 192,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    VehicleImageWidget(
                      imageUrl: vehicle.fotoUrl,
                      fit: BoxFit.cover,
                    ),
                    // Status Badge
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4),
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
                              statusText.toUpperCase(),
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF334155),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
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
                              BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4),
                            ],
                          ),
                          child: const Icon(Icons.star, color: Colors.white, size: 16),
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
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: primary,
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
                              color: subTextColor,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        if (!vehicle.isPrimary)
                          TextButton(
                            onPressed: () => provider.setAsPrimary(vehicle),
                            child: Text(
                              'Hacer Principal',
                              style: TextStyle(color: primary, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.chevron_right, color: primary),
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
            idVehiculo: const Uuid().v4(),
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
                SnackBar(content: Text(vehicleProvider.error ?? 'Error al agregar vehiculo')),
              );
            }
          }
        },
      ),
    );
  }
}
