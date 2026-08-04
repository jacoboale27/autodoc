import 'package:flutter/services.dart';

/// Formatea una placa de vehículo particular de El Salvador: prefijo `P`
/// obligatorio, seguido de 3 caracteres hexadecimales (0-9, A-F), un guion
/// obligatorio, y 3 caracteres hexadecimales más (p.ej. `P1A2-3B4`).
class PlateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text.toUpperCase().replaceAll('-', '');

    // Solo caracteres hexadecimales (0-9, A-F) y, temporalmente mientras se
    // escribe, la P inicial.
    text = text.replaceAll(RegExp(r'[^0-9A-F]'), '');

    // Prefijo P obligatorio: si el usuario empezó a escribir sin ella,
    // se antepone automáticamente.
    if (!text.startsWith('P')) {
      text = 'P$text';
    }
    // Evita una segunda P si el usuario la volvió a escribir después del
    // prefijo automático.
    if (text.length > 1) {
      text = 'P${text.substring(1).replaceAll('P', '')}';
    }

    // Tope: P + 3 + 3 = 7 caracteres útiles (el guion se agrega aparte).
    if (text.length > 7) {
      text = text.substring(0, 7);
    }

    var formatted = text;
    if (text.length > 4) {
      formatted = '${text.substring(0, 4)}-${text.substring(4)}';
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Normaliza cualquier variante de una placa (con o sin guion, minúsculas,
/// espacios, etc.) a la misma forma canónica que produce [PlateFormatter]
/// mientras el usuario escribe (`P###-###`). Se usa para comparar/consultar
/// placas (búsqueda del mecánico, escaneo QR) contra lo que ya quedó
/// guardado al registrar el vehículo, evitando que ambos flujos diverjan.
String normalizarPlaca(String input) {
  return PlateFormatter()
      .formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(
          text: input,
          selection: TextSelection.collapsed(offset: input.length),
        ),
      )
      .text;
}

/// Patrón completo de una placa válida de vehículo particular: `P` + 3
/// caracteres hexadecimales + guion + 3 caracteres hexadecimales.
final RegExp placaElSalvadorPattern = RegExp(r'^P[0-9A-F]{3}-[0-9A-F]{3}$');

/// Validador de formulario para el campo de placa. Devuelve `null` si es
/// válida, o un mensaje de error para mostrar en el `TextFormField`.
String? validarPlacaElSalvador(String? value) {
  final placa = value?.trim().toUpperCase() ?? '';
  if (placa.isEmpty) {
    return 'La placa es obligatoria';
  }
  if (!placaElSalvadorPattern.hasMatch(placa)) {
    return 'Formato inválido. Usa P123-456 (particular, El Salvador)';
  }
  return null;
}
