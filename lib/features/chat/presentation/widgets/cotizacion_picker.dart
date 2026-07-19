import 'package:flutter/material.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/utils/l10n_extension.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';

class CotizacionPicker extends StatefulWidget {
  final Function(String descripcion, double total) onConfirm;

  const CotizacionPicker({super.key, required this.onConfirm});

  @override
  State<CotizacionPicker> createState() => _CotizacionPickerState();
}

class _CotizacionPickerState extends State<CotizacionPicker> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  final _totalController = TextEditingController();

  @override
  void dispose() {
    _descController.dispose();
    _totalController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      final desc = _descController.text.trim();
      final total = double.tryParse(_totalController.text.trim()) ?? 0.0;
      widget.onConfirm(desc, total);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceContainer : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Nueva Cotización',
                  style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Descripción del Servicio',
                hintText: 'Ej. Cambio de Aceite + Filtros',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty ? 'Requerido' : null,
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _totalController,
              decoration: const InputDecoration(
                labelText: 'Costo Total (\$)',
                hintText: 'Ej. 85.00',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return 'Requerido';
                if (double.tryParse(value.trim()) == null) return 'Valor inválido';
                return null;
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(context.l10n.chatGenerateAndSend, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
