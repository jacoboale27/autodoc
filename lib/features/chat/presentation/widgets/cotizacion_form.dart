import 'package:flutter/material.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/utils/input_formatters.dart';

/// Controladores de una fila de material/repuesto: nombre, cantidad y costo
/// unitario. Es la única pieza genuinamente idéntica entre las dos pantallas
/// que hoy piden una lista de materiales — `CotizacionPicker` (chat, antes de
/// que el cliente acepte nada) e `InitiateServiceScreen` (al cerrar un
/// servicio sin cotización aprobada) — el resto (fecha propuesta, beneficio
/// por renglón, mano de obra) sigue siendo propio de cada lado porque no
/// tienen equivalente en el otro. Ver
/// `.superpowers/sdd/2026-09-04-observaciones-colaboradores/task-7-report.md`.
class CotizacionItemRowControllers {
  final nombreController = TextEditingController();
  final cantidadController = TextEditingController(text: '1');
  final costoController = TextEditingController();

  double get cantidad => double.tryParse(cantidadController.text.trim()) ?? 1;
  double get costo => double.tryParse(costoController.text.trim()) ?? 0;
  double get subtotal => cantidad * costo;

  void dispose() {
    nombreController.dispose();
    cantidadController.dispose();
    costoController.dispose();
  }
}

/// Lista editable de renglones de material/repuesto (nombre + cantidad +
/// costo, con `montoInputFormatters` en el campo de dinero) y, opcionalmente,
/// el total calculado. No emite un modelo de dominio ni asume a qué destino
/// va a parar la cotización: cada llamador (`CotizacionPicker`,
/// `InitiateServiceScreen`) sigue armando su propio payload a partir de
/// [rows] — este widget solo evita que ambos reimplementen el mismo renglón.
class CotizacionItemsForm extends StatelessWidget {
  /// Filas a renderizar. El dueño del estado es el llamador: este widget no
  /// es un `StatefulWidget` porque no posee la lista, solo la dibuja.
  final List<CotizacionItemRowControllers> rows;

  /// Se invoca para agregar una fila vacía. `null` deshabilita el botón.
  final VoidCallback? onAddRow;

  /// Se invoca con el índice a eliminar. El botón de eliminar de una fila
  /// solo se muestra si `rows.length > minRows`.
  final void Function(int index) onRemoveRow;

  /// Se invoca en cada edición de cualquier campo, para que el llamador
  /// pueda recalcular totales que dependan de estas filas (p. ej. el costo
  /// combinado con mano de obra en `InitiateServiceScreen`).
  final VoidCallback onChanged;

  /// Mínimo de filas que deben quedar sin botón de eliminar. `CotizacionPicker`
  /// exige al menos un renglón (usa 1, su valor por defecto); `InitiateServiceScreen`
  /// permite quedarse sin materiales (usa 0).
  final int minRows;

  /// Si es `true` (por defecto), dibuja el total de estas filas debajo de la
  /// lista. `InitiateServiceScreen` lo desactiva porque ya muestra su propio
  /// total combinado (materiales + mano de obra) en un campo aparte.
  final bool showTotal;

  final String nombreLabel;
  final String costoLabel;
  final String addRowLabel;
  final String totalLabel;

  /// Contenido a mostrar cuando `rows` está vacía, en vez de la lista.
  final Widget? emptyPlaceholder;

  /// Widget adicional a dibujar al final de la fila `index` (p. ej. el campo
  /// "beneficio" que solo existe en `CotizacionPicker`).
  final Widget Function(BuildContext context, int index)? trailingBuilder;

  const CotizacionItemsForm({
    super.key,
    required this.rows,
    required this.onAddRow,
    required this.onRemoveRow,
    required this.onChanged,
    this.minRows = 1,
    this.showTotal = true,
    this.nombreLabel = 'Material / Repuesto',
    this.costoLabel = 'Costo (\$)',
    this.addRowLabel = 'Agregar renglón',
    this.totalLabel = 'Total a cobrar:',
    this.emptyPlaceholder,
    this.trailingBuilder,
  });

  double get _total => rows.fold(0.0, (acc, r) => acc + r.subtotal);

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (rows.isEmpty && emptyPlaceholder != null) ...[
          emptyPlaceholder!,
          const SizedBox(height: 8),
        ] else
          for (var i = 0; i < rows.length; i++) _buildRow(context, i, colors),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: onAddRow,
          icon: const Icon(Icons.add),
          label: Text(addRowLabel),
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.primary,
            side: BorderSide(color: colors.primary.withValues(alpha: 0.4)),
          ),
        ),
        if (showTotal) ...[
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  totalLabel,
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '\$${_total.toStringAsFixed(2)}',
                key: const Key('cotizacion_items_total'),
                style: AppTextStyles.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.secondary,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildRow(BuildContext context, int index, AppColors colors) {
    final row = rows[index];
    return Container(
      key: ValueKey('cotizacion_item_row_$index'),
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
                  key: Key('cotizacion_item_nombre_$index'),
                  controller: row.nombreController,
                  decoration: InputDecoration(
                    labelText: nombreLabel,
                    isDense: true,
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Requerido' : null,
                  onChanged: (_) => onChanged(),
                ),
              ),
              if (rows.length > minRows)
                IconButton(
                  icon: Icon(Icons.close, color: colors.error, size: 20),
                  onPressed: () => onRemoveRow(index),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: Key('cotizacion_item_cantidad_$index'),
                  controller: row.cantidadController,
                  decoration: const InputDecoration(
                    labelText: 'Cantidad',
                    isDense: true,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: cantidadInputFormatters,
                  validator: (v) => double.tryParse(v?.trim() ?? '') == null
                      ? 'Inválido'
                      : null,
                  onChanged: (_) => onChanged(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  key: Key('cotizacion_item_costo_$index'),
                  controller: row.costoController,
                  decoration: InputDecoration(
                    labelText: costoLabel,
                    isDense: true,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: montoInputFormatters,
                  validator: (v) => double.tryParse(v?.trim() ?? '') == null
                      ? 'Inválido'
                      : null,
                  onChanged: (_) => onChanged(),
                ),
              ),
            ],
          ),
          if (trailingBuilder != null) ...[
            const SizedBox(height: 8),
            trailingBuilder!(context, index),
          ],
        ],
      ),
    );
  }
}
