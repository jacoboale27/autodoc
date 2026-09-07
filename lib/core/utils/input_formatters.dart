import 'package:flutter/services.dart';

/// Formateador numérico que, a diferencia de
/// `FilteringTextInputFormatter.allow` con un patrón anclado, no borra todo
/// el campo cuando el candidato completo no matchea (p.ej. al escribir una
/// letra en medio de un número ya válido): simplemente rechaza el cambio y
/// conserva el valor anterior.
class _NumeroInputFormatter extends TextInputFormatter {
  const _NumeroInputFormatter(this._valido);

  final RegExp _valido;

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
  _NumeroInputFormatter(RegExp(r'^\d*\.?\d{0,2}$')),
];

/// Formatters para el campo "Cantidad" de un renglón de cotización.
///
/// Mismo mecanismo y mismo motivo que [montoInputFormatters]: ese campo tenía
/// `keyboardType` y ningún formatter, que es exactamente el antipatrón que la
/// tarea B3 declaró insuficiente — la revisión adversarial escribió «abc» en
/// él sin problema. El `validator` bloquea el envío, pero mientras tanto el
/// total se sigue calculando con el renglón inválido, así que el error se ve
/// como un precio mal sumado y no como un campo mal escrito.
///
/// El patrón admite decimales (medio litro de aceite, 1.5 horas de trabajo)
/// pero no un signo ni notación científica.
final List<TextInputFormatter> cantidadInputFormatters = <TextInputFormatter>[
  _NumeroInputFormatter(RegExp(r'^\d*\.?\d{0,2}$')),
];
