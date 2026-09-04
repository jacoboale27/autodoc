import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/utils/input_formatters.dart';
import 'package:autodoc/core/utils/l10n_extension.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/widgets/app_dialog_content.dart';
import 'package:autodoc/features/chat/data/models/cotizacion_model.dart';

class _ItemFormRow {
  final materialController = TextEditingController();
  final cantidadController = TextEditingController(text: '1');
  final costoController = TextEditingController();
  final beneficioController = TextEditingController(text: '0');

  void dispose() {
    materialController.dispose();
    cantidadController.dispose();
    costoController.dispose();
    beneficioController.dispose();
  }

  CotizacionItem toItem() {
    return CotizacionItem(
      material: materialController.text.trim(),
      cantidad: double.tryParse(cantidadController.text.trim()) ?? 1,
      costo: double.tryParse(costoController.text.trim()) ?? 0,
      beneficio: double.tryParse(beneficioController.text.trim()) ?? 0,
    );
  }
}

class CotizacionPicker extends StatefulWidget {
  final Future<void> Function(
    List<CotizacionItem> items,
    DateTime fechaPropuesta,
  )
  onConfirm;
  final DateTime? initialFecha;
  final String? subtitle;

  const CotizacionPicker({
    super.key,
    required this.onConfirm,
    this.initialFecha,
    this.subtitle,
  });

  @override
  State<CotizacionPicker> createState() => _CotizacionPickerState();
}

class _CotizacionPickerState extends State<CotizacionPicker> {
  final _formKey = GlobalKey<FormState>();
  final List<_ItemFormRow> _rows = [_ItemFormRow()];
  DateTime? _fechaPropuesta;
  bool _isSubmitting = false;
  bool _fechaError = false;

  @override
  void initState() {
    super.initState();
    _fechaPropuesta = widget.initialFecha;
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  void _addRow() {
    setState(() => _rows.add(_ItemFormRow()));
  }

  void _removeRow(int index) {
    setState(() {
      _rows[index].dispose();
      _rows.removeAt(index);
    });
  }

  double get _total => _rows.fold(0.0, (acc, r) => acc + r.toItem().subtotal);

  Future<void> _pickFecha() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _fechaPropuesta ?? widget.initialFecha ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 180)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: _fechaPropuesta != null
          ? TimeOfDay.fromDateTime(_fechaPropuesta!)
          : TimeOfDay.now(),
    );
    if (time == null) return;

    setState(() {
      _fechaPropuesta = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final formValid = _formKey.currentState?.validate() ?? false;
    final fechaValid = _fechaPropuesta != null;
    if (!formValid || !fechaValid) {
      setState(() => _fechaError = !fechaValid);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _fechaError = false;
    });
    try {
      final items = _rows.map((r) => r.toItem()).toList();
      await widget.onConfirm(items, _fechaPropuesta!);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _isSubmitting = false);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: AppDialogContent(
          maxWidth: AppBreakpoints.maxFormWidth,
          child: Form(
            key: _formKey,
            child: ListView(
              controller: scrollController,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: colors.outline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Nueva Cotización',
                        style: AppTextStyles.titleLarge.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.pop(context),
                    ),
                  ],
                ),
                if (widget.subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.subtitle!,
                    style: TextStyle(color: colors.textSecondary, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _isSubmitting
                      ? null
                      : () async {
                          await _pickFecha();
                          if (_fechaPropuesta != null) {
                            setState(() => _fechaError = false);
                          }
                        },
                  icon: const Icon(Icons.event),
                  label: Text(
                    _fechaPropuesta != null
                        ? DateFormat(
                            'dd/MM/yyyy hh:mm a',
                          ).format(_fechaPropuesta!)
                        : 'Día y hora del servicio *',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _fechaError
                        ? colors.error
                        : colors.primary,
                    side: BorderSide(
                      color: _fechaError ? colors.error : colors.primary,
                      width: _fechaError ? 1.5 : 1,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                if (_fechaError) ...[
                  const SizedBox(height: 4),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      'Debes proponer el día y hora del servicio.',
                      style: TextStyle(color: colors.error, fontSize: 12),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Text(
                  'Materiales / Repuestos',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < _rows.length; i++)
                  _buildItemRow(context, i, colors),
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  onPressed: _isSubmitting ? null : _addRow,
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar renglón'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.primary,
                    side: BorderSide(
                      color: colors.primary.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Total a cobrar:',
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '\$${_total.toStringAsFixed(2)}',
                      style: AppTextStyles.titleLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colors.secondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    text: context.l10n.chatGenerateAndSend,
                    onPressed: _isSubmitting ? null : _submit,
                    isLoading: _isSubmitting,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemRow(BuildContext context, int index, AppColors colors) {
    final row = _rows[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: row.materialController,
                  decoration: const InputDecoration(
                    labelText: 'Material / Repuesto',
                    isDense: true,
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Requerido' : null,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              if (_rows.length > 1)
                IconButton(
                  icon: Icon(Icons.close, color: colors.error, size: 20),
                  onPressed: () => _removeRow(index),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: row.cantidadController,
                  decoration: const InputDecoration(
                    labelText: 'Cantidad',
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) => double.tryParse(v?.trim() ?? '') == null
                      ? 'Inválido'
                      : null,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: row.costoController,
                  decoration: const InputDecoration(
                    labelText: 'Costo (\$)',
                    isDense: true,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: montoInputFormatters,
                  validator: (v) => double.tryParse(v?.trim() ?? '') == null
                      ? 'Inválido'
                      : null,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: row.beneficioController,
            decoration: InputDecoration(
              labelText: 'Beneficio (\$) — solo tú lo ves',
              isDense: true,
              prefixIcon: Icon(
                Icons.visibility_off_outlined,
                size: 18,
                color: colors.textSecondary,
              ),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: montoInputFormatters,
            validator: (v) =>
                double.tryParse(v?.trim() ?? '0') == null ? 'Inválido' : null,
          ),
        ],
      ),
    );
  }
}
