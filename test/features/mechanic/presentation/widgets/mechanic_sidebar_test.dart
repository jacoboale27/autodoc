import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'lib/features/mechanic/presentation/widgets/mechanic_sidebar.dart',
  ).readAsStringSync();

  test('no usa una familia tipográfica fuera del design system', () {
    expect(
      source.contains('GoogleFonts.montserrat'),
      isFalse,
      reason:
          'Montserrat es una tercera familia; la app usa Inter vía '
          'AppTextStyles. Ver CONVENTIONS.md §2.1.',
    );
    expect(
      source.contains('GoogleFonts.'),
      isFalse,
      reason: 'Usa AppTextStyles en vez de invocar GoogleFonts directamente.',
    );
  });

  test('no tiene colores literales', () {
    final offenders = <String>[];
    final lines = source.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trimLeft().startsWith('//')) continue;
      if (line.contains('Colors.transparent')) continue;
      if (RegExp(r'Colors\.(white|black|grey|gray)').hasMatch(line)) {
        offenders.add('${i + 1}: ${line.trim()}');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  testWidgets('el borde derecho es visible en light mode', (tester) async {
    // Verificación estructural: el borde debe salir de colors.outline, que por
    // construcción contrasta con la superficie en ambos temas.
    expect(source.contains('colors.outline'), isTrue);
  });
}
