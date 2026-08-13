import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/features/dashboard/presentation/providers/alert_provider.dart';
import 'package:autodoc/core/models/maintenance_task_model.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_radius.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/widgets/app_text_field.dart';
import 'package:autodoc/core/widgets/app_scaffold.dart';
import 'package:autodoc/core/widgets/app_card.dart';
import 'package:autodoc/core/widgets/app_page_body.dart';
import 'package:autodoc/core/widgets/app_section_header.dart';
import 'package:go_router/go_router.dart';
import 'package:autodoc/core/utils/responsive.dart';
import 'package:autodoc/core/utils/ui_utils.dart';

class TaskConfigScreen extends StatefulWidget {
  final MaintenanceTask task;
  const TaskConfigScreen({super.key, required this.task});

  @override
  State<TaskConfigScreen> createState() => _TaskConfigScreenState();
}

class _TaskConfigScreenState extends State<TaskConfigScreen> {
  late TextEditingController _kmController;
  late TextEditingController _monthsController;
  bool _isLoading = false;

  /// Preajuste aplicado, si el usuario tocó alguno. Se limpia en cuanto edita
  /// un campo a mano: dejar el chip marcado con otro valor en el campo mentiría.
  ({int km, int months})? _activePreset;

  void _clearPreset() {
    if (_activePreset != null) setState(() => _activePreset = null);
  }

  @override
  void initState() {
    super.initState();
    _kmController = TextEditingController(
      text: widget.task.frecuenciaKm.toString(),
    );
    _monthsController = TextEditingController(
      text: widget.task.frecuenciaMeses.toString(),
    );
  }

  @override
  void dispose() {
    _kmController.dispose();
    _monthsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final primary = colors.primary;
    final textColor = colors.textPrimary;
    final subTextColor = colors.textSecondary;

    return AppScaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Configurar Tarea',
          style: AppTextStyles.titleLarge.copyWith(
            fontWeight: FontWeight.bold,
            color: primary,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: AppPageBody(
          maxWidth: AppBreakpoints.maxFormWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppCard(
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: Icon(
                        Icons.build_circle_outlined,
                        color: primary,
                        size: Responsive.iconSize(context, 28),
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
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Último servicio: ${widget.task.ultimoKm} km',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: subTextColor,
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
                title: 'Frecuencia de mantenimiento',
                subtitle:
                    'Ajusta cada cuántos kilómetros y meses se debe realizar '
                    'este servicio.',
                uppercase: true,
              ),
              const SizedBox(height: AppSpacing.lg),

              AppTextField(
                label: 'Frecuencia en Kilómetros',
                controller: _kmController,
                keyboardType: TextInputType.number,
                prefixIcon: const Icon(Icons.speed),
                hintText: 'Ej. 5000',
                helperText: 'Debe ser mayor que 0.',
                isRequired: true,
                onChanged: (_) => _clearPreset(),
              ),
              const SizedBox(height: AppSpacing.base),
              AppTextField(
                label: 'Frecuencia en Meses',
                controller: _monthsController,
                keyboardType: TextInputType.number,
                prefixIcon: const Icon(Icons.calendar_month),
                hintText: 'Ej. 6',
                helperText: 'Debe ser mayor que 0.',
                isRequired: true,
                onChanged: (_) => _clearPreset(),
              ),

              const SizedBox(height: AppSpacing.xxl),
              const AppSectionHeader(
                title: 'Preajustes rápidos',
                uppercase: true,
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  _presetChip('3,000 km / 3 m', 3000, 3, primary),
                  _presetChip('5,000 km / 6 m', 5000, 6, primary),
                  _presetChip('10,000 km / 12 m', 10000, 12, primary),
                  _presetChip('20,000 km / 24 m', 20000, 24, primary),
                ],
              ),

              const SizedBox(height: AppSpacing.xxxl),
              AppButton(
                text: 'Guardar Configuración',
                semanticLabel:
                    'Guardar la configuración de frecuencia de esta tarea',
                onPressed: _isLoading ? null : _saveConfig,
                isLoading: _isLoading,
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _presetChip(String label, int km, int months, Color primary) {
    final selected = _activePreset?.km == km && _activePreset?.months == months;

    return FilterChip(
      label: Text(label, style: AppTextStyles.labelMedium),
      selected: selected,
      showCheckmark: true,
      backgroundColor: primary.withValues(alpha: 0.08),
      selectedColor: primary.withValues(alpha: 0.2),
      labelStyle: AppTextStyles.labelMedium.copyWith(color: primary),
      side: BorderSide(color: primary.withValues(alpha: selected ? 0.6 : 0.2)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      onSelected: (_) {
        setState(() {
          _activePreset = (km: km, months: months);
          _kmController.text = km.toString();
          _monthsController.text = months.toString();
        });
      },
    );
  }

  Future<void> _saveConfig() async {
    final km = int.tryParse(_kmController.text);
    final months = int.tryParse(_monthsController.text);
    if (km == null || km <= 0 || months == null || months <= 0) {
      UiUtils.showErrorSnackbar(context, 'Ingresa valores válidos mayores a 0');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await context.read<AlertProvider>().userUpdateTaskFull(
        widget.task.id,
        km,
        months,
      );
      if (mounted) {
        UiUtils.showSuccessSnackbar(
          context,
          'Configuración guardada correctamente',
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        UiUtils.showErrorSnackbar(context, 'Error: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
