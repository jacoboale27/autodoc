import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:autodoc/core/models/vehicle_model.dart';
import 'package:autodoc/features/dashboard/presentation/providers/alert_provider.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/models/maintenance_task_model.dart';
import 'package:autodoc/core/models/alert_model.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/utils/responsive.dart';
import 'package:autodoc/core/utils/ui_utils.dart';

class InitiateServiceScreen extends StatefulWidget {
  final VehicleModel vehicle;

  const InitiateServiceScreen({super.key, required this.vehicle});

  @override
  State<InitiateServiceScreen> createState() => _InitiateServiceScreenState();
}

class _InitiateServiceScreenState extends State<InitiateServiceScreen> {
  final TextEditingController _kmController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _costoController = TextEditingController();
  final Set<String> _completedTaskIds = {};
  bool _isSaving = false;
  XFile? _invoiceImage;

  bool get _isInvoicePdf =>
      _invoiceImage?.name.toLowerCase().endsWith('.pdf') ?? false;

  Future<void> _pickInvoiceDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );
      if (result != null && result.files.single.path != null) {
        setState(() {
          _invoiceImage = XFile(result.files.single.path!);
        });
      }
    } catch (e) {
      debugPrint("Error al seleccionar documento: $e");
    }
  }

  Future<void> _pickInvoiceCamera() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.camera);
      if (pickedFile != null) {
        setState(() {
          _invoiceImage = pickedFile;
        });
      }
    } catch (e) {
      debugPrint("Error al tomar/seleccionar imagen: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    _kmController.text = widget.vehicle.kilometrajeActual.toString();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AlertProvider>().fetchAlerts(
        widget.vehicle.idVehiculo,
        widget.vehicle,
      );
    });
  }

  @override
  void dispose() {
    _kmController.dispose();
    _notesController.dispose();
    _costoController.dispose();
    super.dispose();
  }

  Future<void> _handleFinalizeService() async {
    if (_kmController.text.isEmpty) {
      HapticFeedback.heavyImpact();
      UiUtils.showErrorSnackbar(
        context,
        'Por favor, ingresa el kilometraje actual',
      );
      return;
    }

    final nuevoKm = int.tryParse(_kmController.text);
    if (nuevoKm == null || nuevoKm < widget.vehicle.kilometrajeActual) {
      HapticFeedback.heavyImpact();
      UiUtils.showErrorSnackbar(
        context,
        'El kilometraje debe ser mayor o igual al actual',
      );
      return;
    }

    if (_completedTaskIds.isEmpty) {
      HapticFeedback.heavyImpact();
      UiUtils.showErrorSnackbar(
        context,
        'Selecciona al menos una tarea realizada',
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final alertProvider = context.read<AlertProvider>();
      final userSession = context.read<UserProfileProvider>();
      final tallerId = userSession.userData?.idUsuario ?? 'taller_anonimo';

      final costoDouble = double.tryParse(_costoController.text);

      for (var taskId in _completedTaskIds) {
        await alertProvider.tallerUpdateService(
          taskId: taskId,
          nuevoKilometraje: nuevoKm,
          tallerId: tallerId,
          descripcion: _notesController.text,
          costo: costoDouble,
          receiptImage: _invoiceImage,
        );
      }

      await alertProvider.fetchAlerts(
        widget.vehicle.idVehiculo,
        widget.vehicle,
      );

      if (mounted) {
        HapticFeedback.lightImpact();
        UiUtils.showSuccessSnackbar(
          context,
          'Servicio registrado exitosamente',
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        UiUtils.showErrorSnackbar(context, 'Error al registrar servicio: $e');
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
        title: Text(
          'Iniciar Servicio',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
        ),
        backgroundColor: colors.surfaceContainer,
        foregroundColor: colors.primary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(Responsive.padding(context, 20.0)),
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

            _buildSectionTitle('COSTO DEL SERVICIO (OPCIONAL)', colors),
            const SizedBox(height: 12),
            _buildCostoInput(colors),
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
                  borderSide: BorderSide(
                    color: colors.textSecondary.withValues(alpha: 0.2),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: colors.textSecondary.withValues(alpha: 0.2),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            _buildSectionTitle('FOTO DE FACTURA / COMPROBANTE', colors),
            const SizedBox(height: 12),
            _buildInvoicePicker(colors),
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

  Widget _buildInvoicePicker(AppColors colors) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(Responsive.padding(context, 16)),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.textSecondary.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          if (_invoiceImage != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: FutureBuilder<List<int>>(
                future: _invoiceImage!.readAsBytes().then((b) => b.toList()),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    if (_isInvoicePdf) {
                      return Container(
                        height: 200,
                        width: double.infinity,
                        color: colors.primary.withValues(alpha: 0.1),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.picture_as_pdf,
                              size: Responsive.iconSize(context, 64),
                              color: colors.error,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _invoiceImage!.name,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                color: colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return Image.memory(
                      Uint8List.fromList(snapshot.data!),
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    );
                  }
                  return const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  onPressed: () => _pickInvoiceCamera(),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Tomar otra'),
                ),
                TextButton.icon(
                  onPressed: () => _pickInvoiceDocument(),
                  icon: const Icon(Icons.folder),
                  label: const Text('Archivo'),
                ),
                TextButton.icon(
                  onPressed: () => setState(() => _invoiceImage = null),
                  icon: Icon(Icons.delete, color: colors.error),
                  label: Text(
                    'Eliminar',
                    style: TextStyle(color: colors.error),
                  ),
                ),
              ],
            ),
          ] else ...[
            Icon(
              Icons.receipt_long_outlined,
              size: Responsive.iconSize(context, 48),
              color: colors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              '¿Deseas adjuntar una foto de la factura?',
              style: GoogleFonts.inter(
                fontSize: Responsive.fontSize(context, 14),
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            Text(
              'Esto le servirá al propietario como comprobante legal.',
              style: GoogleFonts.inter(
                fontSize: Responsive.fontSize(context, 12),
                color: colors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _pickInvoiceCamera(),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Cámara'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => _pickInvoiceDocument(),
                  icon: const Icon(Icons.folder),
                  label: const Text('Archivo / PDF'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.primary,
                    side: BorderSide(color: colors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, AppColors colors) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: Responsive.fontSize(context, 12),
        fontWeight: FontWeight.bold,
        color: colors.textSecondary,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildVehicleHeader(AppColors colors) {
    return Container(
      padding: EdgeInsets.all(Responsive.padding(context, 20)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primary, colors.primary.withValues(alpha: 0.8)],
        ),
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
                padding: EdgeInsets.all(Responsive.padding(context, 12)),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.directions_car,
                  color: Colors.white,
                  size: Responsive.iconSize(context, 32),
                ),
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
                        fontSize: Responsive.fontSize(context, 18),
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.visible,
                    ),
                    Text(
                      'Placa: ${widget.vehicle.placa}',
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: Responsive.fontSize(context, 14),
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
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.padding(context, 16),
              vertical: Responsive.padding(context, 10),
            ),
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
                    fontSize: Responsive.fontSize(context, 12),
                  ),
                ),
                Text(
                  '${widget.vehicle.kilometrajeActual} KM',
                  style: GoogleFonts.inter(
                    color: colors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: Responsive.fontSize(context, 14),
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
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.padding(context, 20),
        vertical: Responsive.padding(context, 8),
      ),
      child: Row(
        children: [
          Icon(Icons.speed, color: colors.primary),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: _kmController,
              keyboardType: TextInputType.number,
              style: GoogleFonts.inter(
                fontSize: Responsive.fontSize(context, 18),
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
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostoInput(AppColors colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.textSecondary.withValues(alpha: 0.2)),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.padding(context, 20),
        vertical: Responsive.padding(context, 8),
      ),
      child: Row(
        children: [
          Icon(Icons.attach_money, color: colors.secondary),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: _costoController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: GoogleFonts.inter(
                fontSize: Responsive.fontSize(context, 18),
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Ej. 150.00',
                hintStyle: GoogleFonts.inter(color: colors.textSecondary),
              ),
            ),
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
        padding: EdgeInsets.all(Responsive.padding(context, 16)),
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
        final color = alert.prioridad == AlertPriority.high
            ? colors.error
            : colors.warning;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: EdgeInsets.all(Responsive.padding(context, 12)),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: color,
                size: Responsive.iconSize(context, 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  alert.titulo,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: Responsive.fontSize(context, 13),
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
              color: isSelected
                  ? colors.secondary
                  : colors.textSecondary.withValues(alpha: 0.2),
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
              style: GoogleFonts.inter(
                fontSize: Responsive.fontSize(context, 12),
                color: colors.textSecondary,
              ),
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
