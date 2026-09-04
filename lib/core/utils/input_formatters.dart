import 'package:flutter/services.dart';

/// Formateador de precio que, a diferencia de
/// `FilteringTextInputFormatter.allow` con un patrón anclado, no borra todo
/// el campo cuando el candidato completo no matchea (p.ej. al escribir una
/// letra en medio de un número ya válido): simplemente rechaza el cambio y
/// conserva el valor anterior.
class _MontoInputFormatter extends TextInputFormatter {
  static final RegExp _valido = RegExp(r'^\d*\.?\d{0,2}$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (_valido.hasMatch(newValue.text)) {
      return newValue;
    }
    return oldValue;
  }
}

/// Formatters para campos de dinero editables por el usuario (mano de obra,
/// precio unitario de materiales/repuestos, costo y beneficio de una
/// cotización). No se usa en campos de solo lectura (p.ej. un total
/// calculado): Flutter nunca invoca `formatEditUpdate` en un campo
/// `readOnly`, así que ponerlo ahí sería código inalcanzable.
///
/// `keyboardType` NO basta: en Flutter Web es decorativo (no hay teclado
/// virtual que restringir) y en movil no impide pegar del portapapeles.
final List<TextInputFormatter> montoInputFormatters = <TextInputFormatter>[
  _MontoInputFormatter(),
];
