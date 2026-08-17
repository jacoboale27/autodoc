import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'lib/features/dashboard/presentation/pages/workshop_directory_screen.dart',
  ).readAsStringSync();

  test('no usa el azul de Material: la marca es morado/teal', () {
    expect(
      source.contains('Colors.blue'),
      isFalse,
      reason: 'los chips de filtro usan Colors.blue en una app morado/teal',
    );
  });

  test('no re-deriva la paleta oscura a mano', () {
    for (final literal in ['0xFF0F172A', '0xFF1E293B']) {
      expect(
        source.contains(literal),
        isFalse,
        reason: '$literal duplica AppPalette; usa context.appColors',
      );
    }
  });

  test('no usa GoogleFonts ni colores literales', () {
    expect(source.contains('GoogleFonts.'), isFalse);
    for (final banned in [
      'Colors.white',
      'Colors.grey',
      'Colors.amber',
      'Colors.black',
    ]) {
      expect(source.contains(banned), isFalse, reason: banned);
    }
  });

  test('no quedan anchos fijos grandes', () {
    expect(
      RegExp(r'width:\s*240\b').hasMatch(source),
      isFalse,
      reason: 'la tarjeta del mapa fija 240px de ancho',
    );
  });

  test('no importa responsive_framework', () {
    expect(source.contains('responsive_framework'), isFalse);
  });

  test('el split lista/mapa se decide por WindowClass', () {
    expect(
      source.contains('AppBreakpoints'),
      isTrue,
      reason: 'la decisión de split debe salir de la escala única',
    );
    expect(source.contains('isAtLeastExpanded'), isTrue);
  });
}
