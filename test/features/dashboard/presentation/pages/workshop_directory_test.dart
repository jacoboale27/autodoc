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

  test('la vista de mapa se rinde antes de montar GoogleMap sin API key', () {
    // Regresion: durante semanas se desplego web sin GOOGLE_MAPS_API_KEY y el
    // directorio pintaba un rectangulo gris mudo. El guardia tiene que estar
    // antes del GoogleMap, no despues.
    final guard = source.indexOf('isMapUnavailable(');
    expect(
      guard,
      greaterThan(-1),
      reason: 'la vista de mapa no comprueba si falta la API key',
    );
    expect(
      guard,
      lessThan(source.indexOf('GoogleMap(')),
      reason: 'el guardia va antes de construir el GoogleMap',
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

  test('la tarjeta del mapa centra el tap en la propia AppCard, sin '
      'GestureDetector externo redundante', () {
    // Regresion de accesibilidad (hallazgo QA #13): un GestureDetector
    // externo con onTap envolviendo una AppCard sin onTap/semanticLabel es
    // peor que "boton sin nombre" — el lector de pantalla ni siquiera
    // anuncia que la tarjeta es interactiva. El onTap (que centra el mapa
    // vía workshopCameraUpdate) y el semanticLabel tienen que vivir en la
    // propia AppCard, no en un wrapper.
    final start = source.indexOf('Widget _buildMapCard(');
    expect(start, greaterThan(-1), reason: 'no se encontró _buildMapCard');
    final end = source.indexOf('Widget _buildWorkshopCard(', start);
    expect(end, greaterThan(start));
    final body = source.substring(start, end);

    expect(
      body.contains('GestureDetector'),
      isFalse,
      reason:
          'la AppCard del mapa ya no debe envolverse en un GestureDetector '
          'externo; el tap vive en AppCard.onTap',
    );
    expect(
      body.contains('workshopCameraUpdate(data)'),
      isTrue,
      reason: 'el tap dejó de calcular el centrado del mapa',
    );
    expect(
      body.contains('onTap:'),
      isTrue,
      reason: 'la AppCard del mapa necesita su propio onTap',
    );
    expect(
      body.contains('semanticLabel:'),
      isTrue,
      reason: 'la AppCard del mapa necesita semanticLabel',
    );
  });
}
