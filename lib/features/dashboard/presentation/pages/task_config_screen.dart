import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/features/dashboard/presentation/providers/alert_provider.dart';
import 'package:autodoc/core/models/maintenance_task_model.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/widgets/app_text_field.dart';
import 'package:autodoc/core/widgets/app_scaffold.dart';
import 'package:autodoc/core/widgets/app_card.dart';
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
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: primary),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(Responsive.padding(context, 20)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Task info card
                  AppCard(
                    padding: EdgeInsets.all(Responsive.padding(context, 20)),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.build_circle_outlined,
                            color: primary,
                            size: Responsive.iconSize(context, 28),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.task.nombre,
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  fontSize: Responsive.fontSize(context, 17),
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Último servicio: ${widget.task.ultimoKm} km',
                                style: TextStyle(
                                  fontSize: Responsive.fontSize(context, 13),
                                  color: subTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),
                  Text(
                    'FRECUENCIA DE MANTENIMIENTO',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.fontSize(context, 11),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: subTextColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ajusta cada cuántos kilómetros y meses se debe realizar este servicio.',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.fontSize(context, 13),
                      color: subTextColor,
                    ),
                  ),
                  const SizedBox(height: 20),

                  AppTextField(
                    label: 'Frecuencia en Kilómetros',
                    controller: _kmController,
                    keyboardType: TextInputType.number,
                    prefixIcon: const Icon(Icons.speed),
                    hintText: 'Ej. 5000',
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Frecuencia en Meses',
                    controller: _monthsController,
                    keyboardType: TextInputType.number,
                    prefixIcon: const Icon(Icons.calendar_month),
                    hintText: 'Ej. 6',
                  ),

                  const SizedBox(height: 28),
                  // Quick presets
                  Text(
                    'PREAJUSTES RÁPIDOS',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.fontSize(context, 11),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: subTextColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _presetChip('3,000 km / 3 m', 3000, 3, primary),
                      _presetChip('5,000 km / 6 m', 5000, 6, primary),
                      _presetChip('10,000 km / 12 m', 10000, 12, primary),
                      _presetChip('20,000 km / 24 m', 20000, 24, primary),
                    ],
                  ),

                  const SizedBox(height: 40),
                  // Save button
                  AppButton(
                    text: 'Guardar Configuración',
                    onPressed: _isLoading ? null : _saveConfig,
                    isLoading: _isLoading,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _presetChip(String label, int km, int months, Color primary) {
    return ActionChip(
      label: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: Responsive.fontSize(context, 12),
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: primary.withValues(alpha: 0.1),
      labelStyle: TextStyle(color: primary),
      side: BorderSide(color: primary.withValues(alpha: 0.2)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onPressed: () {
        setState(() {
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
