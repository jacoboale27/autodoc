import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/constants/divipola_sv.dart';

void main() {
  group('divipolaSv (El Salvador - Reforma 2023)', () {
    test('tiene exactamente 14 departamentos', () {
      expect(divipolaSv.keys.length, 14);
    });

    test('la suma total de municipios es exactamente 44', () {
      final totalMunicipios = divipolaSv.values.fold<int>(
        0,
        (acc, municipios) => acc + municipios.length,
      );
      expect(totalMunicipios, 44);
    });

    test('ningún municipio aparece en dos departamentos distintos', () {
      final vistos = <String>{};
      for (final entry in divipolaSv.entries) {
        for (final municipio in entry.value) {
          expect(
            vistos.contains(municipio),
            isFalse,
            reason:
                'El municipio "$municipio" está repetido en el departamento "${entry.key}"',
          );
          vistos.add(municipio);
        }
      }
      expect(vistos.length, 44);
    });

    test('ningún departamento ni municipio está vacío o en blanco', () {
      for (final entry in divipolaSv.entries) {
        expect(entry.key.trim().isNotEmpty, isTrue);
        expect(entry.value.isNotEmpty, isTrue);
        for (final municipio in entry.value) {
          expect(municipio.trim().isNotEmpty, isTrue);
        }
      }
    });
  });
}
