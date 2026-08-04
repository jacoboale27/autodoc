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

void main() {
  group('PlateFormatter', () {
    late PlateFormatter formatter;
    setUp(() => formatter = PlateFormatter());

    test('auto-prefixes P when the user types digits first', () {
      final result = _apply(formatter, '1a2');
      expect(result.text, 'P1A2');
    });

    test('does not double-prefix when the user already typed P', () {
      final result = _apply(formatter, 'p1a2');
      expect(result.text, 'P1A2');
    });

    test('inserts a hyphen after the 3rd character following P', () {
      final result = _apply(formatter, 'P1A23B4');
      expect(result.text, 'P1A2-3B4');
    });

    test('rejects non-hex letters (keeps only 0-9A-F)', () {
      final result = _apply(formatter, 'PZZZ111');
      expect(result.text, 'P111');
    });

    test('caps total length at P + 3 + hyphen + 3', () {
      final result = _apply(formatter, 'P1234567890');
      expect(result.text, 'P123-456');
    });
  });

  group('normalizarPlaca', () {
    test('matches what PlateFormatter produces for the same raw input', () {
      final formatter = PlateFormatter();
      const raw = 'p1a23b4';
      final typed = _apply(formatter, raw).text;
      expect(normalizarPlaca(raw), typed);
      expect(normalizarPlaca(raw), 'P1A2-3B4');
    });

    test('normalizes a lowercase plate without hyphen, as used by the '
        'mechanic search screen / QR scan path', () {
      expect(normalizarPlaca('p1a23b4'), 'P1A2-3B4');
    });

    test('normalizes a plate that already has the hyphen and mixed case', () {
      expect(normalizarPlaca('p1A2-3b4'), 'P1A2-3B4');
    });
  });

  group('validarPlacaElSalvador', () {
    test('accepts a complete valid plate', () {
      expect(validarPlacaElSalvador('P1A2-3B4'), isNull);
    });

    test('rejects a plate missing the hyphen', () {
      expect(validarPlacaElSalvador('P1A23B4'), isNotNull);
    });

    test('rejects a plate without the P prefix', () {
      expect(validarPlacaElSalvador('1A2-3B4'), isNotNull);
    });

    test('rejects empty input', () {
      expect(validarPlacaElSalvador(''), isNotNull);
      expect(validarPlacaElSalvador(null), isNotNull);
    });
  });
}
