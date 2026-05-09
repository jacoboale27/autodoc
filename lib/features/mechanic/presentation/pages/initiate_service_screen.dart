import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/core/models/vehicle_model.dart';
import 'package:autodoc/features/dashboard/presentation/providers/alert_provider.dart';
import 'package:autodoc/features/auth/presentation/providers/auth_provider.dart';
import 'package:autodoc/core/models/maintenance_task_model.dart';
import 'package:autodoc/core/models/alert_model.dart';

class InitiateServiceScreen extends StatefulWidget {
  final VehicleModel vehicle;

  const InitiateServiceScreen({super.key, required this.vehicle});

  @override
  State<InitiateServiceScreen> createState() => _InitiateServiceScreenState();
}

class _InitiateServiceScreenState extends State<InitiateServiceScreen> {
  final TextEditingController _kmController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final Set<String> _completedTaskIds = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _kmController.text = widget.vehicle.kilometrajeActual.toString();
    // Cargar alertas y tareas al iniciar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AlertProvider>().fetchAlerts(widget.vehicle.idVehiculo, widget.vehicle);
    });
  }

  @override
  void dispose() {
    _kmController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleFinalizeService() async {
    if (_kmController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, ingresa el kilometraje actual')),
      );
      return;
    }

    final nuevoKm = int.tryParse(_kmController.text);
    if (nuevoKm == null || nuevoKm < widget.vehicle.kilometrajeActual) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El kilometraje debe ser mayor o igual al actual')),
      );
      return;
    }

    if (_completedTaskIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos una tarea realizada')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final alertProvider = context.read<AlertProvider>();
      final authProvider = context.read<AuthProvider>();
      final tallerId = authProvider.userData?.idUsuario ?? 'taller_anonimo';

      // Actualizar cada tarea seleccionada
      for (var taskId in _completedTaskIds) {
        await alertProvider.tallerUpdateService(
          taskId: taskId,
          nuevoKilometraje: nuevoKm,
          tallerId: tallerId,
          descripcion: _notesController.text,
        );
      }

      // Recargar alertas para recalcular estados
      await alertProvider.fetchAlerts(widget.vehicle.idVehiculo, widget.vehicle);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Servicio registrado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // Volver a la búsqueda
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al registrar servicio: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final alertProvider = context.watch<AlertProvider>();
    final primaryBlue = const Color(0xFF0E3B69);
    final secondaryTeal = const Color(0xFF006A62);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Iniciar Servicio', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: primaryBlue,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Resumen Vehículo
            _buildVehicleHeader(primaryBlue, secondaryTeal),
            const SizedBox(height: 24),

            // Kilometraje Actual
            _buildSectionTitle('Kilometraje de Ingreso'),
            const SizedBox(height: 12),
            _buildKmInput(primaryBlue),
            const SizedBox(height: 24),

            // Alertas Activas
            _buildSectionTitle('Alertas Detectadas'),
            const SizedBox(height: 12),
            _buildAlertsList(alertProvider),
            const SizedBox(height: 24),

            // Tareas de Mantenimiento
            _buildSectionTitle('Tareas a Realizar'),
            const SizedBox(height: 12),
            _buildMaintenanceTasks(alertProvider, secondaryTeal),
            const SizedBox(height: 24),

            // Notas
            _buildSectionTitle('Observaciones Técnicas'),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Detalles del trabajo realizado...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
              ),
            ),
            const SizedBox(height: 40),

            // Botón Finalizar
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _handleFinalizeService,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'FINALIZAR SERVICIO',
                          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Colors.grey[600],
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildVehicleHeader(Color primary, Color secondary) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [primary, primary.withValues(alpha: 0.8)]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: primary.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.directions_car, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.vehicle.marca} ${widget.vehicle.modelo}',
                      style: GoogleFonts.montserrat(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.visible,
                    ),
                    Text(
                      'Placa: ${widget.vehicle.placa}',
                      style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF8CF1E4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Kilometraje Actual:',
                  style: GoogleFonts.inter(color: primary, fontWeight: FontWeight.w500, fontSize: 12),
                ),
                Text(
                  '${widget.vehicle.kilometrajeActual} KM',
                  style: GoogleFonts.inter(color: primary, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKmInput(Color primary) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.speed, color: primary),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: _kmController,
              keyboardType: TextInputType.number,
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Kilometraje actual',
              ),
            ),
          ),
          Text('KM', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildAlertsList(AlertProvider provider) {
    if (provider.isLoading) return const Center(child: CircularProgressIndicator());
    if (provider.activeAlerts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 12),
            Text('No hay alertas pendientes', style: GoogleFonts.inter(color: Colors.green[800])),
          ],
        ),
      );
    }

    return Column(
      children: provider.activeAlerts.take(3).map((alert) {
        final color = alert.prioridad == AlertPriority.high ? Colors.red : Colors.orange;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: color, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  alert.titulo,
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: color),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMaintenanceTasks(AlertProvider provider, Color secondary) {
    if (provider.isLoading) return const Center(child: CircularProgressIndicator());
    if (provider.maintenanceTasks.isEmpty) {
      return Text('No hay tareas configuradas para este vehículo', style: GoogleFonts.inter(color: Colors.grey));
    }

    return Column(
      children: provider.maintenanceTasks.map((task) {
        final isSelected = _completedTaskIds.contains(task.id);
        final status = task.getStatus(widget.vehicle.kilometrajeActual);
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSelected ? secondary : Colors.grey[200]!, width: isSelected ? 2 : 1),
          ),
          child: CheckboxListTile(
            value: isSelected,
            onChanged: (val) {
              setState(() {
                if (val == true) {
                  _completedTaskIds.add(task.id);
                } else {
                  _completedTaskIds.remove(task.id);
                }
              });
            },
            activeColor: secondary,
            title: Text(task.nombre, style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            subtitle: Text(
              'Frecuencia: ${task.frecuenciaKm} km / ${task.frecuenciaMeses} meses',
              style: GoogleFonts.inter(fontSize: 12),
            ),
            secondary: _getStatusIcon(status),
          ),
        );
      }).toList(),
    );
  }

  Widget _getStatusIcon(MaintenanceStatus status) {
    switch (status) {
      case MaintenanceStatus.critical:
        return const Icon(Icons.error, color: Colors.red);
      case MaintenanceStatus.preventive:
        return const Icon(Icons.warning, color: Colors.orange);
      case MaintenanceStatus.optimal:
        return const Icon(Icons.check_circle, color: Colors.green);
    }
  }
}
