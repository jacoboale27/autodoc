import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/features/dashboard/presentation/providers/alert_provider.dart';
import 'package:autodoc/features/dashboard/presentation/providers/vehicle_provider.dart';
import 'package:autodoc/core/models/alert_model.dart';
import 'package:autodoc/core/models/maintenance_task_model.dart';
import 'package:intl/intl.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final primaryPurple = theme.colorScheme.primary;
    final accentColor = const Color(0xFF98FFD9);
    final surfaceColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF7F6F8);
    final cardColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextColor = isDark ? Colors.white70 : const Color(0xFF64748B);
    
    final vehicleProvider = context.watch<VehicleProvider>();
    final alertProvider = context.watch<AlertProvider>();
    final vehicle = vehicleProvider.selectedVehicle;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Alertas y Recordatorios',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [primaryPurple, const Color(0xFF2D1B4E)],
          ),
        ),
        child: SafeArea(
          child: vehicle == null
              ? const Center(child: Text('Selecciona un vehículo primero', style: TextStyle(color: Colors.white)))
              : Column(
                  children: [
                    _buildSummaryHeader(alertProvider, accentColor),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                          ),
                          child: alertProvider.isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : ListView(
                                  padding: const EdgeInsets.symmetric(vertical: 24),
                                  children: [
                                    _buildSectionTitle('Estado General del Vehículo', textColor),
                                    _buildMileageCard(vehicle.kilometrajeActual, primaryPurple, isDark, cardColor),
                                    const SizedBox(height: 24),
                                    
                                    _buildSectionTitle('Tareas de Mantenimiento', textColor),
                                    if (alertProvider.maintenanceTasks.isEmpty)
                                      _buildEmptyState('No hay tareas configuradas')
                                    else
                                      ...alertProvider.maintenanceTasks.map((task) => 
                                        _buildMaintenanceCard(task, vehicle.kilometrajeActual, primaryPurple, cardColor, textColor, subTextColor)),
                                    
                                    const SizedBox(height: 32),
                                    _buildSectionTitle('Otras Alertas', textColor),
                                    if (alertProvider.activeAlerts.isEmpty)
                                      _buildEmptyState('Todo al día')
                                    else
                                      ...alertProvider.activeAlerts.map((alert) => _buildAlertItem(alert, primaryPurple, cardColor, textColor, subTextColor)),
                                    
                                    const SizedBox(height: 40),
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

  Widget _buildSummaryHeader(AlertProvider provider, Color accent) {
    final pendingCount = provider.activeAlerts.length;
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.notifications_active, color: accent, size: 32),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$pendingCount alertas activas',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                'Tu vehículo necesita atención',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildAlertItem(AlertModel alert, Color primary, Color cardColor, Color textColor, Color subTextColor) {
    Color color;
    IconData icon;
    
    switch (alert.prioridad) {
      case AlertPriority.high:
        color = Colors.redAccent;
        icon = Icons.warning_rounded;
        break;
      case AlertPriority.medium:
        color = Colors.orangeAccent;
        icon = Icons.info_outline;
        break;
      case AlertPriority.low:
        color = Colors.blueAccent;
        icon = Icons.check_circle_outline;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.titulo,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  alert.descripcion,
                  style: TextStyle(fontSize: 13, color: subTextColor),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.check_circle, color: primary.withValues(alpha: 0.2)),
            onPressed: () => context.read<AlertProvider>().completeAlert(alert.idAlerta),
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceCard(MaintenanceTask task, int currentKm, Color primary, Color cardColor, Color textColor, Color subTextColor) {
    final status = task.getStatus(currentKm);
    Color statusColor;
    String statusText = task.getStatusLabel(currentKm);
    
    switch (status) {
      case MaintenanceStatus.critical:
        statusColor = Colors.redAccent;
        break;
      case MaintenanceStatus.preventive:
        statusColor = Colors.orangeAccent;
        break;
      case MaintenanceStatus.optimal:
        statusColor = Colors.greenAccent;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.build_circle_outlined, color: statusColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.nombre,
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
                    ),
                    Text(
                      'Último: ${task.ultimoKm} km | ${DateFormat('dd MMM yy').format(task.fechaUltimoServicio)}',
                      style: TextStyle(fontSize: 12, color: subTextColor),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusText,
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: (currentKm - task.ultimoKm) / task.frecuenciaKm,
              backgroundColor: Colors.grey.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMileageCard(int currentKm, Color primary, bool isDark, Color cardColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? primary.withValues(alpha: 0.1) : primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Kilometraje Actual', style: TextStyle(color: Colors.grey, fontSize: 12)),
              Text(
                '${NumberFormat('#,###').format(currentKm)} km',
                style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: primary),
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: () => _showUpdateMileageDialog(context),
            icon: const Icon(Icons.edit, size: 16),
            label: const Text('Actualizar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Icon(Icons.verified_user_outlined, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  void _showUpdateMileageDialog(BuildContext context) {
    final vehicleProvider = context.read<VehicleProvider>();
    final vehicle = vehicleProvider.selectedVehicle;
    if (vehicle == null) return;

    final controller = TextEditingController(text: vehicle.kilometrajeActual.toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Actualizar Kilometraje'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Nuevo Kilometraje',
            suffixText: 'km',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final newKm = int.tryParse(controller.text);
              if (newKm != null && newKm >= vehicle.kilometrajeActual) {
                await vehicleProvider.updateVehicleMileage(vehicle.idVehiculo, newKm);
                if (context.mounted) {
                  context.read<AlertProvider>().fetchAlerts(vehicle.idVehiculo, vehicleProvider.selectedVehicle!);
                  Navigator.pop(context);
                }
              }
            }, 
            child: const Text('Guardar')
          ),
        ],
      ),
    );
  }
}
