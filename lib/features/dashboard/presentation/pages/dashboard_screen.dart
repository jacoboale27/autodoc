import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/features/auth/presentation/providers/auth_provider.dart';
import 'package:autodoc/features/dashboard/presentation/providers/vehicle_provider.dart';
import 'package:autodoc/features/dashboard/presentation/providers/alert_provider.dart';
import 'package:autodoc/core/models/vehicle_model.dart';
import 'package:autodoc/core/widgets/vehicle_image_widget.dart';
import 'package:uuid/uuid.dart';
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
      final authProvider = context.read<AuthProvider>();
      if (authProvider.user != null) {
        final vehicleProvider = context.read<VehicleProvider>();
        vehicleProvider.fetchVehicles(authProvider.user!.uid).then((_) {
          if (mounted && vehicleProvider.selectedVehicle != null) {
            context.read<AlertProvider>().fetchAlerts(
              vehicleProvider.selectedVehicle!.idVehiculo,
              vehicleProvider.selectedVehicle!,
            );
          }
        });
      }
      _isInitialized = true;
    }
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
                padding: const EdgeInsets.only(bottom: 120), // For bottom nav and FAB
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context, isDark, textColor, subTextColor),
                    const SizedBox(height: 8),
                    if (isLoading)
                      const Center(child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(),
                      ))
                    else if (vehicle == null)
                      _buildEmptyVehicleState(context, primaryPurple, isDark, textColor, subTextColor)
                    else
                      _buildVehicleCard(primaryPurple, vehicle, isDark, textColor, subTextColor),
                    const SizedBox(height: 32),
                    _buildActiveAlerts(primaryPurple, alertProvider, isDark, subTextColor),
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
                backgroundColor: isDark ? const Color(0xFF98FFD9) : primaryPurple,
                foregroundColor: isDark ? primaryPurple : Colors.white,
                elevation: 8,
                shape: const CircleBorder(),
                child: const Icon(Icons.add, size: 32),
              ),
            ),
            
            // Bottom Navbar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomNav(primaryPurple, isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark, Color textColor, Color subTextColor) {
    final authProvider = context.watch<AuthProvider>();
    final userName = authProvider.user?.displayName?.split(' ').first ?? 'Usuario';

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hola, $userName 👋',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '¿Listo para la carretera hoy?',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: subTextColor,
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () => context.push('/user_profile'),
            child: Stack(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    image: DecorationImage(
                      image: CachedNetworkImageProvider(
                        authProvider.userData?.fotoPerfilUrl ?? 'https://www.w3schools.com/howto/img_avatar.png',
                      ),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.green,
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
    );
  }

  Widget _buildEmptyVehicleState(BuildContext context, Color primary, bool isDark, Color textColor, Color subTextColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.directions_car_filled_outlined, size: 48, color: primary),
            ),
            const SizedBox(height: 24),
            Text(
              'No hay vehiculos registrados',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Añade tu primer vehículo para empezar a controlar su mantenimiento y estado.',
              textAlign: TextAlign.center,
              style: TextStyle(color: subTextColor, fontSize: 14),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => _showAddVehicleDialog(context, primary),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text('Registrar Vehiculo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleCard(Color primary, VehicleModel vehicle, bool isDark, Color textColor, Color subTextColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: primary.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
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
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'VEHICULO PRINCIPAL',
                              style: GoogleFonts.inter(
                                fontSize: 10,
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
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Placa: ${vehicle.placa}',
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
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    _buildStatItem('KILOMETRAJE', vehicle.kilometrajeActual.toString(), 'km', primary, isDark, subTextColor),
                    const SizedBox(width: 16),
                    _buildStatItem('NIVEL DE COMBUSTIBLE', '78', '%', primary, isDark, subTextColor), // Hardcoded for now as it's not in model
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => context.push('/vehicle_profile', extra: vehicle),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 4,
                      shadowColor: primary.withValues(alpha: 0.3),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Ver Estado del Vehiculo', style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 16),
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
            idVehiculo: Uuid().v4(),
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



  Widget _buildStatItem(String label, String value, String unit, Color color, bool isDark, Color subTextColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: subTextColor, fontWeight: FontWeight.bold)),
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

  Widget _buildActiveAlerts(Color primary, AlertProvider provider, bool isDark, Color subTextColor) {
    final activeAlerts = provider.activeAlerts;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Alertas Activas',
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              GestureDetector(
                onTap: () => context.push('/alerts'),
                child: Text(
                  'Ver Todas',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: primary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (activeAlerts.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text('¡Excelente! No tienes alertas pendientes.', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500)),
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
                  case 'Aceite': icon = Icons.oil_barrel; color = Colors.orange; break;
                  case 'SOAT': icon = Icons.verified_user; color = Colors.red; break;
                  case 'Llantas': icon = Icons.tire_repair; color = Colors.blue; break;
                  default: icon = Icons.notifications; color = primary;
                }
                return Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: _buildAlertCard(icon, alert.titulo, alert.descripcion, color, isDark, subTextColor),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildAlertCard(IconData icon, String title, String status, Color statusColor, bool isDark, Color subTextColor) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: statusColor, size: 24),
          ),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(fontSize: 12, color: subTextColor, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(
            status,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: statusColor),
          ),
        ],
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
                'Talleres Cercanos',
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () => context.push('/workshop_directory'),
                child: Text('Ver todos', style: TextStyle(color: primary, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () => context.push('/workshop_directory'),
            child: _buildServiceTile(Icons.build, 'AutoFix Workshop', 'Especialidad: Motor • 4.8★', primary, isDark, subTextColor),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceTile(IconData icon, String title, String subtitle, Color primary, bool isDark, Color subTextColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: subTextColor, fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Color(0xFFCBD5E1)),
        ],
      ),
    );
  }

  Widget _buildBottomNav(Color primary, bool isDark) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 80,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.7),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home, 'Home', true, primary, () => context.go('/dashboard')),
              _buildNavItem(Icons.garage, 'Garage', false, primary, () => context.push('/garage')),
              _buildNavItem(Icons.analytics, 'Logs', false, primary, () {
                final vehicle = context.read<VehicleProvider>().selectedVehicle;
                if (vehicle != null) {
                  context.push('/service_history', extra: vehicle.idVehiculo);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seleccione un vehículo primero')));
                }
              }),
              _buildNavItem(Icons.person, 'Profile', false, primary, () => context.push('/user_profile')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive, Color primary, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isActive ? primary : const Color(0xFFCBD5E1),
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isActive ? primary : const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }
}
