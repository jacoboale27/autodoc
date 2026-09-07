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
  _cantidad();
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

  test('acepta un punto decimal inicial sin digitos enteros', () {
    expect(_aplicar('', '.5').text, '.5');
  });

  test('rechaza mas de dos decimales', () {
    expect(_aplicar('12.5', '12.567').text, '12.5');
  });
}

/// Revisión adversarial (Ronda 3): el campo "Cantidad" de un renglón de
/// cotización tenía `keyboardType` y ningún formatter — el antipatrón que
/// B3 declaró insuficiente — así que aceptaba «abc» y el total se seguía
/// calculando con ese renglón dentro.
void _cantidad() {
  group('cantidadInputFormatters', () {
    TextEditingValue aplicar(String anterior, String nuevo) {
      var valor = TextEditingValue(text: anterior);
      for (final f in cantidadInputFormatters) {
        valor = f.formatEditUpdate(valor, TextEditingValue(text: nuevo));
      }
      return valor;
    }

    test('rechaza letras y conserva lo que ya había', () {
      expect(aplicar('', 'abc').text, '');
      expect(aplicar('2', '2a').text, '2');
    });

    test('acepta cantidades decimales reales (medio litro, hora y media)', () {
      expect(aplicar('', '0.5').text, '0.5');
      expect(aplicar('1', '1.5').text, '1.5');
    });

    test('no admite dos puntos ni mas de dos decimales', () {
      expect(aplicar('1.5', '1.5.2').text, '1.5');
      expect(aplicar('1.55', '1.555').text, '1.55');
    });

    test('no admite signo negativo', () {
      expect(aplicar('', '-1').text, '');
    });
  });
}
