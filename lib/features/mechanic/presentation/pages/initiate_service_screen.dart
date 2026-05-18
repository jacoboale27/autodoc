import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/core/models/vehicle_model.dart';
import 'package:autodoc/features/dashboard/presentation/providers/alert_provider.dart';
import 'package:autodoc/features/auth/presentation/providers/auth_provider.dart';
import 'package:autodoc/core/models/maintenance_task_model.dart';
import 'package:autodoc/core/models/alert_model.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/widgets/app_button.dart';

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
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, ingresa el kilometraje actual')),
      );
      return;
    }

    final nuevoKm = int.tryParse(_kmController.text);
    if (nuevoKm == null || nuevoKm < widget.vehicle.kilometrajeActual) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El kilometraje debe ser mayor o igual al actual')),
      );
      return;
    }

    if (_completedTaskIds.isEmpty) {
      HapticFeedback.heavyImpact();
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

      for (var taskId in _completedTaskIds) {
        await alertProvider.tallerUpdateService(
          taskId: taskId,
          nuevoKilometraje: nuevoKm,
          tallerId: tallerId,
          descripcion: _notesController.text,
        );
      }

      await alertProvider.fetchAlerts(widget.vehicle.idVehiculo, widget.vehicle);

      if (mounted) {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Servicio registrado exitosamente'),
            backgroundColor: context.appColors.secondary,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al registrar servicio: $e'),
            backgroundColor: context.appColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final alertProvider = context.watch<AlertProvider>();
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text('Iniciar Servicio', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        backgroundColor: colors.surfaceContainer,
        foregroundColor: colors.primary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildVehicleHeader(colors),
            const SizedBox(height: 24),

            _buildSectionTitle('KILOMETRAJE DE INGRESO', colors),
            const SizedBox(height: 12),
            _buildKmInput(colors),
            const SizedBox(height: 24),

            _buildSectionTitle('ALERTAS DETECTADAS', colors),
            const SizedBox(height: 12),
            _buildAlertsList(alertProvider, colors),
            const SizedBox(height: 24),

            _buildSectionTitle('TAREAS A REALIZAR', colors),
            const SizedBox(height: 12),
            _buildMaintenanceTasks(alertProvider, colors),
            const SizedBox(height: 24),

            _buildSectionTitle('OBSERVACIONES TÉCNICAS', colors),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 3,
              style: GoogleFonts.inter(color: colors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Detalles del trabajo realizado...',
                hintStyle: GoogleFonts.inter(color: colors.textSecondary),
                filled: true,
                fillColor: colors.surfaceContainer,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colors.textSecondary.withValues(alpha: 0.2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colors.textSecondary.withValues(alpha: 0.2)),
                ),
              ),
            ),
            const SizedBox(height: 40),

            AppButton(
              text: 'FINALIZAR SERVICIO',
              onPressed: _isSaving ? null : _handleFinalizeService,
              isLoading: _isSaving,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, AppColors colors) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: colors.textSecondary,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildVehicleHeader(AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [colors.primary, colors.primary.withValues(alpha: 0.8)]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
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
                      style: GoogleFonts.montserrat(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.visible,
                    ),
                    Text(
                      'Placa: ${widget.vehicle.placa}',
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                      ),
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
              color: colors.secondary.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Kilometraje Actual:',
                  style: GoogleFonts.inter(
                    color: colors.primary,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '${widget.vehicle.kilometrajeActual} KM',
                  style: GoogleFonts.inter(
                    color: colors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKmInput(AppColors colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.textSecondary.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.speed, color: colors.primary),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: _kmController,
              keyboardType: TextInputType.number,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Kilometraje actual',
                hintStyle: GoogleFonts.inter(color: colors.textSecondary),
              ),
            ),
          ),
          Text(
            'KM',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsList(AlertProvider provider, AppColors colors) {
    if (provider.isLoading) {
      return Center(child: CircularProgressIndicator(color: colors.primary));
    }
    if (provider.activeAlerts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.secondary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: colors.secondary),
            const SizedBox(width: 12),
            Text(
              'No hay alertas pendientes',
              style: GoogleFonts.inter(color: colors.secondary),
            ),
          ],
        ),
      );
    }

    return Column(
      children: provider.activeAlerts.take(3).map((alert) {
        final color = alert.prioridad == AlertPriority.high ? colors.error : colors.warning;
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
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMaintenanceTasks(AlertProvider provider, AppColors colors) {
    if (provider.isLoading) {
      return Center(child: CircularProgressIndicator(color: colors.primary));
    }
    if (provider.maintenanceTasks.isEmpty) {
      return Text(
        'No hay tareas configuradas para este vehículo',
        style: GoogleFonts.inter(color: colors.textSecondary),
      );
    }

    return Column(
      children: provider.maintenanceTasks.map((task) {
        final isSelected = _completedTaskIds.contains(task.id);
        final status = task.getStatus(widget.vehicle.kilometrajeActual);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: colors.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? colors.secondary : colors.textSecondary.withValues(alpha: 0.2),
              width: isSelected ? 2 : 1,
            ),
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
            activeColor: colors.secondary,
            title: Text(
              task.nombre,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
            subtitle: Text(
              'Frecuencia: ${task.frecuenciaKm} km / ${task.frecuenciaMeses} meses',
              style: GoogleFonts.inter(fontSize: 12, color: colors.textSecondary),
            ),
            secondary: _getStatusIcon(status, colors),
          ),
        );
      }).toList(),
    );
  }

  Widget _getStatusIcon(MaintenanceStatus status, AppColors colors) {
    switch (status) {
      case MaintenanceStatus.critical:
        return Icon(Icons.error, color: colors.error);
      case MaintenanceStatus.preventive:
        return Icon(Icons.warning, color: colors.warning);
      case MaintenanceStatus.optimal:
        return Icon(Icons.check_circle, color: colors.secondary);
    }
  }
}
