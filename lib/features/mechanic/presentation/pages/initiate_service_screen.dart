import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:autodoc/features/chat/data/models/cotizacion_model.dart';
import 'package:autodoc/core/models/vehicle_model.dart';
import 'package:autodoc/features/dashboard/presentation/providers/alert_provider.dart';
import 'package:autodoc/features/mechanic/presentation/providers/reparacion_provider.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/models/maintenance_task_model.dart';
import 'package:autodoc/core/models/alert_model.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/widgets/missing_argument_screen.dart';
import 'package:autodoc/core/utils/responsive.dart';
import 'package:autodoc/core/utils/ui_utils.dart';
import 'package:autodoc/core/constants/firestore_collections.dart';

class InitiateServiceScreen extends StatefulWidget {
  final String vehiculoId;
  final VehicleModel? vehiculoPrecargado;

  const InitiateServiceScreen({
    super.key,
    required this.vehiculoId,
    this.vehiculoPrecargado,
  });

  @override
  State<InitiateServiceScreen> createState() => _InitiateServiceScreenState();
}

class _InitiateServiceScreenState extends State<InitiateServiceScreen> {
  VehicleModel? _vehiculo;
  bool _cargando = false;
  String? _errorCarga;

  final TextEditingController _kmController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _costoController = TextEditingController();
  final TextEditingController _manoDeObraController = TextEditingController();
  final List<Map<String, dynamic>> _materiales = [];
  final Set<String> _completedTaskIds = {};
  bool _isSaving = false;
  XFile? _invoiceImage;

  bool _hasApprovedQuote = false;
  CotizacionModel? _approvedQuote;

  /// Id del ticket Kanban de reparación creado al recibir el vehículo
  /// (Task 4). Puede quedar en null si `ReparacionProvider.iniciar` falla:
  /// eso no debe bloquear el flujo de servicio existente.
  String? _idReparacion;

  bool get _isInvoicePdf =>
      _invoiceImage?.name.toLowerCase().endsWith('.pdf') ?? false;

  Future<void> _pickInvoiceDocument() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );
      if (result != null) {
        final file = result.files.single;
        final webBytes = kIsWeb ? await file.readAsBytes() : null;
        if (!mounted) return;
        setState(() {
          if (webBytes != null) {
            _invoiceImage = XFile.fromData(webBytes, name: file.name);
          } else if (file.path != null) {
            _invoiceImage = XFile(file.path!);
          }
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
    _manoDeObraController.addListener(_updateTotalCost);
    _vehiculo = widget.vehiculoPrecargado;
    if (_vehiculo != null) {
      _onVehiculoListo();
    } else {
      _cargarVehiculo();
    }
  }

  Future<void> _cargarVehiculo() async {
    setState(() {
      _cargando = true;
      _errorCarga = null;
    });
    try {
      final doc = await FirebaseFirestore.instance
          .collection(FirestoreCollections.vehiculos)
          .doc(widget.vehiculoId)
          .get();
      if (!mounted) return;
      if (!doc.exists) {
        setState(() {
          _cargando = false;
          _errorCarga = 'notFound';
        });
        return;
      }
      setState(() {
        _vehiculo = VehicleModel.fromMap(doc.data()!, doc.id);
        _cargando = false;
      });
      _onVehiculoListo();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _errorCarga = 'error';
      });
    }
  }

  void _onVehiculoListo() {
    final vehiculo = _vehiculo!;
    _kmController.text = vehiculo.kilometrajeActual.toString();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AlertProvider>().fetchAlerts(vehiculo.idVehiculo, vehiculo);
      _iniciarTicketReparacion(vehiculo);
    });

    FirebaseFirestore.instance
        .collection('cotizaciones')
        .where('id_vehiculo', isEqualTo: vehiculo.idVehiculo)
        .where('estado', isEqualTo: 'aceptada')
        .orderBy('fecha', descending: true)
        .limit(1)
        .get()
        .then((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            if (mounted) {
              setState(() {
                _hasApprovedQuote = true;
                _approvedQuote = CotizacionModel.fromMap(
                  snapshot.docs.first.data(),
                  snapshot.docs.first.id,
                );
                _costoController.text = _approvedQuote!.total.toStringAsFixed(
                  2,
                );
              });
            }
          }
        });
  }

  /// Crea el ticket Kanban de reparación en cuanto el mecánico recibe el
  /// vehículo (Task 4, brief step 8). Si falla, se registra en debug y se
  /// continúa: el flujo de servicio existente no debe depender de esto.
  Future<void> _iniciarTicketReparacion(VehicleModel vehiculo) async {
    final userSession = context.read<UserProfileProvider>();
    final tallerId = userSession.userData?.idUsuario ?? '';
    if (tallerId.isEmpty) return;

    try {
      final idReparacion = await context.read<ReparacionProvider>().iniciar(
        idVehiculo: vehiculo.idVehiculo,
        idTaller: tallerId,
        idPropietario: vehiculo.idPropietario,
        placa: vehiculo.placa,
      );
      if (!mounted) return;
      if (idReparacion == null) {
        debugPrint(
          'No se pudo crear el ticket de reparación para ${vehiculo.placa}',
        );
        return;
      }
      setState(() {
        _idReparacion = idReparacion;
      });
    } catch (e) {
      debugPrint('Error al crear el ticket de reparación: $e');
    }
  }

  void _updateTotalCost() {
    double totalMateriales = 0;
    for (var m in _materiales) {
      double subtotal =
          (m['cantidad'] as num).toDouble() *
          (m['precioUnitario'] as num).toDouble();
      totalMateriales += subtotal;
    }
    double manoDeObra = double.tryParse(_manoDeObraController.text) ?? 0;
    double total = totalMateriales + manoDeObra;
    if (total > 0) {
      _costoController.text = total.toStringAsFixed(2);
    } else {
      _costoController.text = '';
    }
  }

  @override
  void dispose() {
    _kmController.dispose();
    _notesController.dispose();
    _costoController.dispose();
    _manoDeObraController.dispose();
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
    if (nuevoKm == null || nuevoKm < _vehiculo!.kilometrajeActual) {
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
      final manoDeObraDouble = _hasApprovedQuote
          ? _approvedQuote?.manoDeObra
          : double.tryParse(_manoDeObraController.text);
      final materialesList = _hasApprovedQuote
          ? _approvedQuote?.materiales
          : _materiales;

      for (var taskId in _completedTaskIds) {
        await alertProvider.tallerUpdateService(
          taskId: taskId,
          nuevoKilometraje: nuevoKm,
          tallerId: tallerId,
          descripcion: _notesController.text,
          costo: costoDouble,
          manoDeObra: manoDeObraDouble,
          materiales: materialesList,
          receiptImage: _invoiceImage,
        );
      }

      await alertProvider.fetchAlerts(_vehiculo!.idVehiculo, _vehiculo!);

      if (_idReparacion != null && mounted) {
        try {
          await context.read<ReparacionProvider>().cambiarEstado(
            _idReparacion!,
            'listo_para_entrega',
          );
        } catch (e) {
          // No bloquear el cierre del servicio si el ticket Kanban no pudo
          // actualizarse (p.ej. ya estaba en ese estado o fue eliminado).
          debugPrint('Error al actualizar el ticket de reparación: $e');
        }
      }

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
    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_errorCarga != null || _vehiculo == null) {
      return const MissingArgumentScreen(
        mensaje: 'No se pudo cargar el vehículo del servicio.',
        rutaVuelta: '/mechanic_dashboard',
      );
    }

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

            if (_hasApprovedQuote) ...[
              Container(
                padding: EdgeInsets.all(Responsive.padding(context, 16)),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: colors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'El cliente aprobó una cotización previa por \$${_approvedQuote!.total.toStringAsFixed(2)}. El desglose ya está registrado.',
                        style: GoogleFonts.inter(
                          color: colors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: Responsive.fontSize(context, 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            if (!_hasApprovedQuote) ...[
              _buildSectionTitle('MATERIALES / REPUESTOS', colors),
              const SizedBox(height: 12),
              _buildMaterialesList(colors),
              const SizedBox(height: 24),

              _buildSectionTitle('MANO DE OBRA', colors),
              const SizedBox(height: 12),
              _buildManoDeObraInput(colors),
              const SizedBox(height: 24),
            ],

            _buildSectionTitle('COSTO DEL SERVICIO (TOTAL)', colors),
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
              child: _isInvoicePdf
                  ? Container(
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
                    )
                  : FutureBuilder<List<int>>(
                      future: _invoiceImage!.readAsBytes().then(
                        (b) => b.toList(),
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
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
                      '${_vehiculo!.marca} ${_vehiculo!.modelo}',
                      style: GoogleFonts.montserrat(
                        color: Colors.white,
                        fontSize: Responsive.fontSize(context, 18),
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.visible,
                    ),
                    Text(
                      'Placa: ${_vehiculo!.placa}',
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
                  '${_vehiculo!.kilometrajeActual} KM',
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
              readOnly: true,
              style: GoogleFonts.inter(
                fontSize: Responsive.fontSize(context, 18),
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Calculado automáticamente',
                hintStyle: GoogleFonts.inter(color: colors.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManoDeObraInput(AppColors colors) {
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
          Icon(Icons.build_circle_outlined, color: colors.secondary),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: _manoDeObraController,
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
                hintText: 'Costo mano de obra',
                hintStyle: GoogleFonts.inter(color: colors.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialesList(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_materiales.isEmpty)
          Text(
            'No hay materiales agregados.',
            style: GoogleFonts.inter(color: colors.textSecondary),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _materiales.length,
            itemBuilder: (context, index) {
              final item = _materiales[index];
              final subtotal =
                  (item['cantidad'] as num).toDouble() *
                  (item['precioUnitario'] as num).toDouble();
              return Card(
                color: colors.surfaceContainer,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: colors.textSecondary.withValues(alpha: 0.2),
                  ),
                ),
                elevation: 0,
                child: ListTile(
                  title: Text(
                    item['nombre'],
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Cant: ${item['cantidad']} | P.U: \$${(item['precioUnitario'] as num).toStringAsFixed(2)}',
                    style: GoogleFonts.inter(color: colors.textSecondary),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '\$${subtotal.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          color: colors.primary,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, color: colors.error),
                        onPressed: () {
                          setState(() {
                            _materiales.removeAt(index);
                            _updateTotalCost();
                          });
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _showAddMaterialDialog(colors),
          icon: const Icon(Icons.add),
          label: const Text('Agregar Material/Repuesto'),
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.primary,
            side: BorderSide(color: colors.primary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showAddMaterialDialog(AppColors colors) async {
    final nombreController = TextEditingController();
    final cantidadController = TextEditingController();
    final precioController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colors.surface,
          title: Text(
            'Agregar Material',
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreController,
                style: GoogleFonts.inter(color: colors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Nombre o descripción',
                  labelStyle: TextStyle(color: colors.textSecondary),
                ),
              ),
              TextField(
                controller: cantidadController,
                keyboardType: TextInputType.number,
                style: GoogleFonts.inter(color: colors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Cantidad',
                  labelStyle: TextStyle(color: colors.textSecondary),
                ),
              ),
              TextField(
                controller: precioController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: GoogleFonts.inter(color: colors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Precio Unitario',
                  labelStyle: TextStyle(color: colors.textSecondary),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancelar',
                style: TextStyle(color: colors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final nombre = nombreController.text.trim();
                final cantidad = double.tryParse(cantidadController.text);
                final precio = double.tryParse(precioController.text);

                if (nombre.isNotEmpty && cantidad != null && precio != null) {
                  setState(() {
                    _materiales.add({
                      'nombre': nombre,
                      'cantidad': cantidad,
                      'precioUnitario': precio,
                    });
                    _updateTotalCost();
                  });
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Agregar'),
            ),
          ],
        );
      },
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
        final status = task.getStatus(_vehiculo!.kilometrajeActual);

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
