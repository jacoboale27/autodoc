import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/utils/plate_formatter.dart';

TextEditingValue _apply(PlateFormatter f, String input) {
  return f.formatEditUpdate(
    TextEditingValue.empty,
    TextEditingValue(
      text: input,
      selection: TextSelection.collapsed(offset: input.length),
    ),
  );
}

String _tecleado(TipoPlaca tipo, String input) =>
    _apply(PlateFormatter(tipo: tipo), input).text;

void main() {
  group('PlateFormatter', () {
    late PlateFormatter formatter;
    setUp(() => formatter = const PlateFormatter());

    test('auto-prefixes P when the user types digits first', () {
      final result = _apply(formatter, '1a2');
      expect(result.text, 'P1A2');
    });

    test('does not double-prefix when the user already typed P', () {
      final result = _apply(formatter, 'p1a2');
      expect(result.text, 'P1A2');
    });

    test('el guion separa siempre los tres últimos caracteres', () {
      expect(_apply(formatter, 'P123456').text, 'P123-456');
      expect(_apply(formatter, 'P12345').text, 'P12-345');
      expect(_apply(formatter, 'P1234').text, 'P1-234');
    });

    test('con 3 caracteres o menos todavía no se pinta el guion', () {
      expect(_apply(formatter, 'P123').text, 'P123');
      expect(_apply(formatter, 'P1').text, 'P1');
      expect(_apply(formatter, 'P').text, 'P');
    });

    test('el guion se recoloca al ir escribiendo, de derecha a izquierda', () {
      // Lo que ve el usuario tecleando 1,2,3,4,5,6 uno a uno.
      expect(_apply(formatter, 'P1').text, 'P1');
      expect(_apply(formatter, 'P12').text, 'P12');
      expect(_apply(formatter, 'P123').text, 'P123');
      expect(_apply(formatter, 'P1234').text, 'P1-234');
      expect(_apply(formatter, 'P12345').text, 'P12-345');
      expect(_apply(formatter, 'P123456').text, 'P123-456');
    });

    test('borrar un carácter de una placa de 6 devuelve la de 5', () {
      expect(_apply(formatter, 'P123-45').text, 'P12-345');
    });

    test('rejects non-hex letters (keeps only 0-9A-F)', () {
      final result = _apply(formatter, 'PZZZ111');
      expect(result.text, 'P111');
    });

    test('caps total length at P + 3 + hyphen + 3', () {
      final result = _apply(formatter, 'P1234567890');
      expect(result.text, 'P123-456');
    });

    test('conserva los ceros a la izquierda del esquema alfanumérico', () {
      // Primera placa alfanumérica entregada por el VMT: P 001 00A.
      expect(_apply(formatter, 'P00100A').text, 'P001-00A');
    });
  });

  group('normalizarPlaca', () {
    test('matches what PlateFormatter produces for the same raw input', () {
      const formatter = PlateFormatter();
      const raw = 'p12300a';
      final typed = _apply(formatter, raw).text;
      expect(normalizarPlaca(raw), typed);
      expect(normalizarPlaca(raw), 'P123-00A');
    });

    test('normalizes a lowercase plate without hyphen, as used by the '
        'mechanic search screen / QR scan path', () {
      expect(normalizarPlaca('p12300a'), 'P123-00A');
    });

    test('normalizes a plate that already has the hyphen and mixed case', () {
      expect(normalizarPlaca('p123-00a'), 'P123-00A');
    });

    test(
      'una placa de cinco caracteres sobrevive el viaje de ida y vuelta',
      () {
        expect(normalizarPlaca('p12345'), 'P12-345');
        expect(normalizarPlaca('P12-345'), 'P12-345');
        expect(normalizarPlaca(' p12 345 '), 'P12-345');
      },
    );

    test('no rellena ni recorta ceros: P012-345 y P12-345 son distintas', () {
      // En el esquema alfanumérico el correlativo se imprime rellenado a
      // tres posiciones, así que el cero es significativo y la app debe
      // guardar exactamente lo que está estampado en la placa.
      expect(normalizarPlaca('P012345'), 'P012-345');
      expect(normalizarPlaca('P12345'), 'P12-345');
    });
  });

  group('validarPlacaElSalvador', () {
    test('acepta una placa de seis caracteres', () {
      expect(validarPlacaElSalvador('P123-456'), isNull);
    });

    test('acepta una placa de cinco caracteres (P12-345)', () {
      expect(validarPlacaElSalvador('P12-345'), isNull);
    });

    test('acepta una placa de cuatro caracteres (P1-234)', () {
      expect(validarPlacaElSalvador('P1-234'), isNull);
    });

    test('acepta letras A-F en los tres últimos caracteres', () {
      expect(validarPlacaElSalvador('P001-00A'), isNull);
      expect(validarPlacaElSalvador('P999-FFF'), isNull);
      expect(validarPlacaElSalvador('P12-3AB'), isNull);
    });

    test('acepta letras hexadecimales también en el correlativo', () {
      expect(validarPlacaElSalvador('P1A2-3B4'), isNull);
      expect(validarPlacaElSalvador('PABC-123'), isNull);
      expect(validarPlacaElSalvador('P1F-234'), isNull);
    });

    test('rejects a plate missing the hyphen', () {
      expect(validarPlacaElSalvador('P12345'), isNotNull);
    });

    test('rejects a plate without the P prefix', () {
      expect(validarPlacaElSalvador('123-456'), isNotNull);
    });

    test('rechaza una placa demasiado corta o demasiado larga', () {
      expect(validarPlacaElSalvador('P-123'), isNotNull);
      expect(validarPlacaElSalvador('P1234-567'), isNotNull);
    });

    test('rejects empty input', () {
      expect(validarPlacaElSalvador(''), isNotNull);
      expect(validarPlacaElSalvador(null), isNotNull);
    });
  });

  group('tipos de placa', () {
    test('el prefijo lo decide el tipo elegido, no una P fija', () {
      expect(_tecleado(TipoPlaca.particular, '12345'), 'P12-345');
      expect(_tecleado(TipoPlaca.moto, '12345'), 'M12-345');
      expect(_tecleado(TipoPlaca.carga, '12345'), 'C12-345');
      expect(_tecleado(TipoPlaca.alquiler, '12345'), 'A12-345');
    });

    test('no duplica el prefijo cuando el usuario ya lo escribió', () {
      expect(_tecleado(TipoPlaca.moto, 'M12345'), 'M12-345');
      expect(_tecleado(TipoPlaca.carga, 'C12345'), 'C12-345');
    });

    test('A y C son también dígitos hexadecimales: el prefijo se quita una '
        'sola vez y el correlativo puede empezar por esa misma letra', () {
      // Placa de alquiler cuyo correlativo empieza por A: "A A12 345".
      expect(_tecleado(TipoPlaca.alquiler, 'AA12345'), 'AA12-345');
      expect(_tecleado(TipoPlaca.alquiler, 'A12345'), 'A12-345');
      expect(_tecleado(TipoPlaca.carga, 'CC12345'), 'CC12-345');
    });

    test('el guion sigue flotando por la derecha en cualquier tipo', () {
      expect(_tecleado(TipoPlaca.moto, '1'), 'M1');
      expect(_tecleado(TipoPlaca.moto, '123'), 'M123');
      expect(_tecleado(TipoPlaca.moto, '1234'), 'M1-234');
      expect(_tecleado(TipoPlaca.moto, '123456'), 'M123-456');
    });

    test('el validador acepta los cuatro tipos', () {
      expect(validarPlacaElSalvador('P123-456'), isNull);
      expect(validarPlacaElSalvador('M12-345'), isNull);
      expect(validarPlacaElSalvador('C1-234'), isNull);
      expect(validarPlacaElSalvador('A123-00F'), isNull);
    });

    test('el validador rechaza lo que no encaja en ningún tipo cubierto', () {
      expect(validarPlacaElSalvador('X12-345'), isNotNull);
      // A + "B123": cuatro caracteres en el primer grupo, uno de más.
      expect(validarPlacaElSalvador('AB123-456'), isNotNull);
    });

    test('los prefijos de dos letras quedan ambiguos y se aceptan como del '
        'tipo de su primera letra', () {
      // "AB12-345" (autobús) es indistinguible de una placa de alquiler
      // cuyo correlativo sea "B12345", porque B es un dígito hexadecimal
      // válido. Con la regla permisiva que acordamos, se acepta: preferimos
      // colar una placa rara antes que rechazar una legítima.
      expect(validarPlacaElSalvador('AB12-345'), isNull);
      expect(validarPlacaElSalvador('CD12-345'), isNull);
    });
  });

  group('componerPlaca', () {
    test('arma la placa a partir del tipo y un correlativo ya limpio', () {
      expect(componerPlaca(TipoPlaca.particular, '12345'), 'P12-345');
      expect(componerPlaca(TipoPlaca.moto, '123456'), 'M123-456');
      expect(componerPlaca(TipoPlaca.carga, '123'), 'C123');
    });

    test('no se come una letra inicial del correlativo: aquí el prefijo no '
        'se adivina, viene dado', () {
      // Lo necesita el selector de tipo del formulario: al pasar de una
      // placa a otra hay que recomponerla sin perder un correlativo que
      // empiece por A o por C.
      expect(componerPlaca(TipoPlaca.alquiler, 'A12345'), 'AA12-345');
      expect(componerPlaca(TipoPlaca.carga, 'C12345'), 'CC12-345');
    });
  });

  group('normalizarPlaca con varios tipos', () {
    test('respeta el prefijo que trae el texto: la búsqueda del mecánico y '
        'el escaneo QR no eligen tipo', () {
      expect(normalizarPlaca('m12345'), 'M12-345');
      expect(normalizarPlaca('M12-345'), 'M12-345');
      expect(normalizarPlaca('c123456'), 'C123-456');
      expect(normalizarPlaca('a12345'), 'A12-345');
    });

    test('sin prefijo sigue asumiendo particular', () {
      expect(normalizarPlaca('12345'), 'P12-345');
      expect(normalizarPlaca('123456'), 'P123-456');
    });

    test('una placa de alquiler cuyo correlativo empieza por A sobrevive', () {
      expect(normalizarPlaca('AA12345'), 'AA12-345');
    });
  });
}
