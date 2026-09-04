import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/utils/input_formatters.dart';

TextEditingValue _aplicar(String viejo, String nuevo) {
  var valor = TextEditingValue(
    text: nuevo,
    selection: TextSelection.collapsed(offset: nuevo.length),
  );
  for (final f in montoInputFormatters) {
    valor = f.formatEditUpdate(
      TextEditingValue(
        text: viejo,
        selection: TextSelection.collapsed(offset: viejo.length),
      ),
      valor,
    );
  }
  return valor;
}

void main() {
  test('acepta enteros y decimales', () {
    expect(_aplicar('12', '12.5').text, '12.5');
    expect(_aplicar('', '80').text, '80');
  });

  test('rechaza letras sin borrar lo ya escrito', () {
    // El patron anclado importa: con uno no anclado, escribir una letra
    // vaciaba el campo entero (ver catalogo_servicios_screen.dart:22).
    expect(_aplicar('12.5', '12.5a').text, '12.5');
  });

  test('rechaza texto pegado desde el portapapeles', () {
    expect(_aplicar('', 'cincuenta dolares').text, '');
  });

  test('rechaza un segundo punto decimal', () {
    expect(_aplicar('12.5', '12.5.3').text, '12.5');
  });
}
