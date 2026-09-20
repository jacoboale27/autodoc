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

  test('el mapa no depende de ninguna clave de API', () {
    // Este test comprobaba que, sin `GOOGLE_MAPS_API_KEY`, el directorio se
    // rindiera con un aviso antes de montar el `GoogleMap` —durante semanas
    // se desplegó web sin clave y aquí había un rectángulo gris mudo—. El
    // 2026-09-20 la clave del entorno además CADUCÓ, con el agravante de que
    // una clave rota no se puede detectar desde la app: el error lo pinta la
    // propia API dentro de una vista de plataforma.
    //
    // Así que ya no hay clave que comprobar: el mapa son tiles de
    // OpenStreetMap dibujados por Flutter. Lo que este test fija ahora es que
    // no se vuelva a introducir esa dependencia.
    expect(source.contains('GoogleMap('), isFalse);
    expect(source.contains('google_maps_flutter'), isFalse);
    expect(source.contains('googleMapsApiKey'), isFalse);
    expect(
      source.contains('MapaOsm('),
      isTrue,
      reason: 'el directorio pinta el mapa de la app',
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

  test('la valoracion de la tarjeta del mapa vive en el semanticLabel de la '
      'AppCard, no en un Semantics hijo (que quedaba mudo)', () {
    // `AppCard` pulsable excluye la semantica de sus hijos, asi que el
    // `Semantics(label: "... de 5 estrellas")` que envolvia la insignia de
    // valoracion era codigo muerto: no se anunciaba en ninguna parte y la
    // valoracion tampoco estaba en el label de la tarjeta.
    final start = source.indexOf('Widget _buildMapCard(');
    expect(start, greaterThan(-1), reason: 'no se encontró _buildMapCard');
    final end = source.indexOf('Widget _buildWorkshopCard(', start);
    expect(end, greaterThan(start));
    final body = source.substring(start, end);

    expect(
      body.contains('Semantics('),
      isFalse,
      reason:
          'un Semantics hijo dentro de una AppCard pulsable es codigo '
          'muerto: la informacion va en el semanticLabel de la tarjeta',
    );
    expect(
      body.contains(r"semanticLabel: '$name, $spec, $ratingLabel'"),
      isTrue,
      reason: 'la valoracion tiene que estar en el nombre de la tarjeta',
    );
    expect(
      body.contains('de 5 estrellas'),
      isTrue,
      reason: 'y el texto de la valoracion no puede haberse perdido',
    );
  });

  test(
    'la tarjeta del taller tiene un boton "Ver perfil" que navega a /perfil_publico/{uid} (Tarea 13, D1)',
    () {
      // El perfil publico completo (galeria, ubicacion, catalogo, empleados)
      // vive en la ruta ya existente `/perfil_publico/:userId`
      // (PublicProfileScreen, Tarea 10) -- RULING A de la Tarea 13 prohibe
      // crear una segunda pantalla/ruta para el mismo taller.
      final start = source.indexOf('Widget _buildWorkshopCard(');
      expect(
        start,
        greaterThan(-1),
        reason: 'no se encontró _buildWorkshopCard',
      );

      final body = source.substring(start);
      expect(
        body.contains("Key('wd_ver_perfil')"),
        isTrue,
        reason: 'falta el boton "Ver perfil" en la tarjeta del directorio',
      );
      expect(
        body.contains(r"context.push('/perfil_publico/$tallerId')"),
        isTrue,
        reason:
            'el boton "Ver perfil" debe navegar a la ruta ya existente de '
            'PublicProfileScreen, no a una nueva',
      );
    },
  );
}
