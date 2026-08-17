import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:autodoc/features/dashboard/presentation/providers/alert_provider.dart';
import 'package:autodoc/core/models/maintenance_task_model.dart';
import 'package:intl/intl.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_radius.dart';
import 'package:autodoc/core/theme/app_severity.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/utils/responsive.dart';
import 'package:autodoc/core/utils/ui_utils.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/widgets/app_card.dart';
import 'package:autodoc/core/widgets/app_page_body.dart';
import 'package:autodoc/core/widgets/app_scaffold.dart';
import 'package:autodoc/core/widgets/app_section_header.dart';
import 'package:autodoc/core/widgets/app_text_field.dart';

class TaskCompleteScreen extends StatefulWidget {
  final MaintenanceTask task;
  final int currentKm;
  const TaskCompleteScreen({
    super.key,
    required this.task,
    required this.currentKm,
  });

  @override
  State<TaskCompleteScreen> createState() => _TaskCompleteScreenState();
}

class _TaskCompleteScreenState extends State<TaskCompleteScreen> {
  final _costController = TextEditingController();
  final _notesController = TextEditingController();
  XFile? _receiptImage;
  bool _isLoading = false;

  Future<void> _pickImageCamera() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
      );
      if (pickedFile != null) {
        setState(() => _receiptImage = pickedFile);
      }
    } catch (e) {
      if (mounted) {
        UiUtils.showErrorSnackbar(
          context,
          'No se pudo acceder a la cámara en este dispositivo.',
        );
      }
    }
  }

  Future<void> _pickImageGallery() async {
    try {
      final result = await FilePicker.pickFiles(type: FileType.image);
      if (result == null) return;
      final file = result.files.single;
      final webBytes = kIsWeb ? await file.readAsBytes() : null;
      XFile? picked;
      if (webBytes != null) {
        picked = XFile.fromData(webBytes, name: file.name);
      } else if (file.path != null) {
        picked = XFile(file.path!, name: file.name);
      }
      if (picked != null) {
        setState(() => _receiptImage = picked);
      }
    } catch (e) {
      if (mounted) {
        UiUtils.showErrorSnackbar(
          context,
          'No se pudo abrir la galería en este dispositivo.',
        );
      }
    }
  }

  @override
  void dispose() {
    _costController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final status = widget.task.getStatus(widget.currentKm);
    final severity = AppSeverity.forStatus(
      status,
      colors,
      optimalLabel: widget.task.getStatusLabel(widget.currentKm),
      preventiveLabel: widget.task.getStatusLabel(widget.currentKm),
      criticalLabel: widget.task.getStatusLabel(widget.currentKm),
    );

    return AppScaffold(
      appBar: AppBar(
        backgroundColor: colors.surfaceContainer,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          tooltip: 'Volver',
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Completar Servicio',
          style: AppTextStyles.titleLarge.copyWith(
            fontWeight: FontWeight.bold,
            color: colors.primary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: AppPageBody(
          maxWidth: AppBreakpoints.maxFormWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Task summary card
              AppCard(
                margin: EdgeInsets.zero,
                padding: EdgeInsets.all(Responsive.padding(context, 20)),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: severity.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                          ),
                          child: Icon(
                            severity.icon,
                            color: severity.color,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.base),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.task.nombre,
                                style: AppTextStyles.titleMedium.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: colors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                severity.label,
                                style: AppTextStyles.labelMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: severity.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.base),
                    Container(
                      padding: EdgeInsets.all(Responsive.padding(context, 12)),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: _infoItem(
                              'Km Actual',
                              NumberFormat('#,###').format(widget.currentKm),
                              colors,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 30,
                            color: colors.outline.withValues(alpha: 0.4),
                          ),
                          Expanded(
                            child: _infoItem(
                              'Último',
                              '${NumberFormat('#,###').format(widget.task.ultimoKm)} km',
                              colors,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 30,
                            color: colors.outline.withValues(alpha: 0.4),
                          ),
                          Expanded(
                            child: _infoItem(
                              'Fecha',
                              DateFormat(
                                'dd/MM/yy',
                              ).format(widget.task.fechaUltimoServicio),
                              colors,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),
              const AppSectionHeader(
                title: 'DETALLES DEL SERVICIO',
                subtitle:
                    'Registra la información del mantenimiento realizado.',
                uppercase: true,
              ),
              const SizedBox(height: AppSpacing.base),

              // Cost field
              AppTextField(
                label: 'Costo total',
                controller: _costController,
                keyboardType: TextInputType.number,
                prefixIcon: const Icon(Icons.attach_money),
                hintText: '0.00',
                helperText: 'Opcional.',
              ),
              const SizedBox(height: AppSpacing.base),
              AppTextField(
                label: 'Notas, taller o refacciones',
                controller: _notesController,
                maxLines: 3,
                prefixIcon: const Icon(Icons.note_alt_outlined),
                hintText: 'Ej: Se usó aceite sintético 5W-30...',
              ),

              const SizedBox(height: AppSpacing.xl),
              const AppSectionHeader(
                title: 'EVIDENCIA (RECIBO O FOTO)',
                subtitle:
                    'Para validar el servicio, adjunta una foto del recibo o '
                    'de la pieza cambiada.',
                uppercase: true,
              ),
              const SizedBox(height: AppSpacing.base),

              if (_receiptImage != null)
                Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      height: 180,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(
                          color: colors.success.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: FutureBuilder<List<int>>(
                          future: _receiptImage!.readAsBytes().then(
                            (b) => b.toList(),
                          ),
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              return Image.memory(
                                Uint8List.fromList(snapshot.data!),
                                fit: BoxFit.cover,
                              );
                            }
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          },
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () => setState(() => _receiptImage = null),
                        child: Container(
                          padding: EdgeInsets.all(
                            Responsive.padding(context, 6),
                          ),
                          decoration: BoxDecoration(
                            color: colors.textPrimary.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close,
                            color: colors.surface,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: Responsive.padding(context, 10),
                          vertical: Responsive.padding(context, 4),
                        ),
                        decoration: BoxDecoration(
                          color: colors.success,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check, color: colors.surface, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              'Imagen adjunta',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: colors.surface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: _photoButton(
                        icon: Icons.camera_alt,
                        label: 'Cámara',
                        onTap: _pickImageCamera,
                        semanticLabel: 'Adjuntar foto con la cámara',
                        colors: colors,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.base),
                    Expanded(
                      child: _photoButton(
                        icon: Icons.photo_library,
                        label: 'Galería',
                        onTap: _pickImageGallery,
                        semanticLabel: 'Adjuntar foto desde la galería',
                        colors: colors,
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: AppSpacing.xxl),
              AppButton(
                text: _isLoading ? 'Guardando...' : 'Confirmar y validar',
                icon: const Icon(Icons.check_circle),
                isLoading: _isLoading,
                onPressed: _receiptImage == null ? null : _submitCompletion,
                semanticLabel:
                    'Confirmar y validar el servicio con la evidencia adjunta',
              ),
              if (_receiptImage == null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 14, color: colors.error),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Se requiere evidencia fotográfica para validar',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: colors.error,
                          ),
                        ),
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

  Widget _infoItem(String label, String value, AppColors colors) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.labelSmall.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: AppTextStyles.labelLarge.copyWith(
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _photoButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required String semanticLabel,
    required AppColors colors,
  }) {
    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(vertical: 28),
      onTap: onTap,
      semanticLabel: semanticLabel,
      child: Column(
        children: [
          Icon(icon, color: colors.primary, size: 28),
          const SizedBox(height: AppSpacing.sm),
          Text(
            label,
            style: AppTextStyles.labelLarge.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitCompletion() async {
    setState(() => _isLoading = true);
    try {
      final cost = double.tryParse(_costController.text) ?? 0.0;
      await context.read<AlertProvider>().userCompleteTask(
        taskId: widget.task.id,
        currentKm: widget.currentKm,
        cost: cost,
        notes: _notesController.text.trim(),
        receiptImage: _receiptImage,
      );
      if (mounted) {
        UiUtils.showSuccessSnackbar(
          context,
          'Servicio validado y registrado en historial ✓',
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        UiUtils.showErrorSnackbar(context, 'Error: $e');
        setState(() => _isLoading = false);
      }
    }
  }
}
