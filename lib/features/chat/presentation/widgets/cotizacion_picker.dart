import 'package:flutter/material.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/utils/l10n_extension.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';

class CotizacionPicker extends StatefulWidget {
  final Function(
    String descripcion,
    double total,
    double? manoDeObra,
    List<Map<String, dynamic>>? materiales,
  )
  onConfirm;

  const CotizacionPicker({super.key, required this.onConfirm});

  @override
  State<CotizacionPicker> createState() => _CotizacionPickerState();
}

class _CotizacionPickerState extends State<CotizacionPicker> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  final _totalController = TextEditingController();
  final _manoDeObraController = TextEditingController();

  final _matNameController = TextEditingController();
  final _matQtyController = TextEditingController();
  final _matPriceController = TextEditingController();

  final List<Map<String, dynamic>> _materiales = [];

  @override
  void initState() {
    super.initState();
    _manoDeObraController.addListener(_calculateTotal);
  }

  @override
  void dispose() {
    _descController.dispose();
    _totalController.dispose();
    _manoDeObraController.dispose();
    _matNameController.dispose();
    _matQtyController.dispose();
    _matPriceController.dispose();
    super.dispose();
  }

  void _calculateTotal() {
    double total = 0.0;
    double mano = double.tryParse(_manoDeObraController.text.trim()) ?? 0.0;
    total += mano;
    for (var m in _materiales) {
      double qty = (m['cantidad'] as num).toDouble();
      double price = (m['precio'] as num).toDouble();
      total += (qty * price);
    }
    _totalController.text = total.toStringAsFixed(2);
  }

  void _addMaterial() {
    final name = _matNameController.text.trim();
    final qty = double.tryParse(_matQtyController.text.trim()) ?? 0.0;
    final price = double.tryParse(_matPriceController.text.trim()) ?? 0.0;
    if (name.isNotEmpty && qty > 0 && price > 0) {
      setState(() {
        _materiales.add({'nombre': name, 'cantidad': qty, 'precio': price});
        _matNameController.clear();
        _matQtyController.clear();
        _matPriceController.clear();
        _calculateTotal();
      });
    }
  }

  void _removeMaterial(int index) {
    setState(() {
      _materiales.removeAt(index);
      _calculateTotal();
    });
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      final desc = _descController.text.trim();
      final total = double.tryParse(_totalController.text.trim()) ?? 0.0;
      final mano = double.tryParse(_manoDeObraController.text.trim());

      widget.onConfirm(
        desc,
        total,
        mano,
        _materiales.isEmpty ? null : _materiales,
      );
      Navigator.pop(context);
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
                  style: AppTextStyles.titleLarge.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _descController,
                      decoration: const InputDecoration(
                        labelText: 'Descripción del Servicio',
                        hintText: 'Ej. Cambio de Aceite + Filtros',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Requerido'
                          : null,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _manoDeObraController,
                      decoration: const InputDecoration(
                        labelText: 'Mano de Obra (\$)',
                        hintText: 'Ej. 50.00',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.build),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Materiales / Repuestos',
                      style: AppTextStyles.titleSmall.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _matNameController,
                            decoration: const InputDecoration(
                              labelText: 'Nombre',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _matQtyController,
                            decoration: const InputDecoration(
                              labelText: 'Cant.',
                              isDense: true,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _matPriceController,
                            decoration: const InputDecoration(
                              labelText: 'Precio',
                              isDense: true,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.add_circle,
                            color: Colors.green,
                          ),
                          onPressed: _addMaterial,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_materiales.isNotEmpty)
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _materiales.length,
                        itemBuilder: (context, index) {
                          final mat = _materiales[index];
                          final qty = (mat['cantidad'] as num).toDouble();
                          final price = (mat['precio'] as num).toDouble();
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(mat['nombre']),
                            subtitle: Text(
                              '$qty x \$${price.toStringAsFixed(2)} = \$${(qty * price).toStringAsFixed(2)}',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _removeMaterial(index),
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _totalController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Costo Total (\$)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      validator: (value) {
                        if (value == null ||
                            value.trim().isEmpty ||
                            value == '0.00') {
                          return 'Requerido';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
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
                child: Text(
                  context.l10n.chatGenerateAndSend,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
