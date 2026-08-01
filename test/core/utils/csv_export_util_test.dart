import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/utils/csv_export_util.dart';

void main() {
  test('buildCsv arma encabezado y filas separadas por coma con comillas', () {
    final csv = buildCsv(
      ['Nombre', 'Correo'],
      [
        ['Ana "La Jefa"', 'ana@example.com'],
        ['Luis, Pérez', 'luis@example.com'],
      ],
    );

    final lines = csv.split('\r\n').where((l) => l.isNotEmpty).toList();
    expect(lines[0], 'Nombre,Correo');
    expect(lines[1], contains('Ana ""La Jefa""'));
    expect(lines[2], contains('"Luis, Pérez"'));
  });
}
