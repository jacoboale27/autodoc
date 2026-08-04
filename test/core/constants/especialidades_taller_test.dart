import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/constants/especialidades_taller.dart';

void main() {
  test('especialidadesTaller is non-empty and has no duplicates', () {
    expect(especialidadesTaller, isNotEmpty);
    expect(especialidadesTaller.toSet().length, especialidadesTaller.length);
  });

  test('especialidadesTaller contains the expected core categories', () {
    expect(especialidadesTaller, contains('Mecánica General'));
    expect(especialidadesTaller, contains('Frenos'));
    expect(especialidadesTaller, contains('Transmisión'));
    expect(especialidadesTaller, contains('Eléctrico'));
  });
}
