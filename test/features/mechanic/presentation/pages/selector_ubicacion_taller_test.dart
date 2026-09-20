// Observaciones del 2026-09-19: «no deja seleccionar bien la ubicación del
// taller ... el mapa no funciona y se queda estático». El mapa vivía en un
// AlertDialog y en la web la capa de accesibilidad del diálogo se quedaba los
// clics (ver SelectorUbicacionTallerScreen). Reproducido en el navegador:
// en un diálogo no se mueve; en una página, sí.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:autodoc/features/mechanic/presentation/pages/selector_ubicacion_taller_screen.dart';

import '../../../../support/responsive_harness.dart';

void main() {
  test('el mapa del taller no vuelve a un diálogo ni bajo un Semantics', () {
    final ajustes = File(
      'lib/features/mechanic/presentation/pages/workshop_settings_screen.dart',
    ).readAsStringSync();
    expect(
      ajustes.contains('GoogleMap('),
      isFalse,
      reason:
          'el mapa vive en SelectorUbicacionTallerScreen, a pantalla '
          'completa: dentro de un diálogo no recibe los clics en la web',
    );

    // Solo el código: los comentarios cuentan precisamente de dónde venía.
    final selector = File(
      'lib/features/mechanic/presentation/pages/'
      'selector_ubicacion_taller_screen.dart',
    ).readAsLinesSync().where((l) => !l.trimLeft().startsWith('//')).join(' ');
    expect(selector.contains('showDialog'), isFalse);
    expect(selector.contains('AlertDialog'), isFalse);
    expect(
      RegExp(r'Semantics\(\s*label').hasMatch(selector),
      isFalse,
      reason: 'un Semantics con rótulo sobre el mapa vuelve a taparlo',
    );
    expect(selector.contains('WebGestureHandling.greedy'), isTrue);
  });

  testWidgets('tocar el mapa y confirmar devuelve el punto elegido', (
    tester,
  ) async {
    const elegido = LatLng(13.7, -89.2);
    LatLng? devuelto;
    await pumpAtWidth(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            devuelto = await Navigator.of(context).push<LatLng>(
              MaterialPageRoute(
                builder: (_) => SelectorUbicacionTallerScreen(
                  inicial: ubicacionPorDefectoTaller,
                  construirMapa: (punto, alElegir, alCargar) {
                    // Un mapa sano avisa de que cargó, igual que
                    // `onMapCreated`. Sin eso, a los ocho segundos la
                    // pantalla daría el mapa por muerto.
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => alCargar(),
                    );
                    return GestureDetector(
                      key: const Key('mapa_falso'),
                      onTap: () => alElegir(elegido),
                      child: Text('punto ${punto.latitude}'),
                    );
                  },
                ),
              ),
            );
          },
          child: const Text('abrir'),
        ),
      ),
      width: 1024,
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('selector_ubicacion_ayuda')), findsOneWidget);
    expect(find.text('punto ${ubicacionPorDefectoTaller.latitude}'), findsOne);

    await tester.tap(find.byKey(const Key('mapa_falso')));
    await tester.pump();
    expect(find.text('punto 13.7'), findsOneWidget);

    await tester.tap(find.byKey(const Key('selector_ubicacion_confirmar')));
    await tester.pumpAndSettle();
    expect(devuelto, elegido);
  });

  testWidgets('si el mapa no carga, se puede escribir la ubicación', (
    tester,
  ) async {
    // Observaciones del 2026-09-19: «no sirve el mapa en ninguna parte». La
    // clave del entorno está VENCIDA, y entonces Google pinta su propio
    // cartel gris dentro de la vista de plataforma: `onMapCreated` no llega
    // nunca, la app no se entera y el taller se queda sin poder fijar su
    // ubicación. Aquí el mapa falso hace justo eso: no avisar.
    LatLng? devuelto;
    await pumpAtWidth(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            devuelto = await Navigator.of(context).push<LatLng>(
              MaterialPageRoute(
                builder: (_) => SelectorUbicacionTallerScreen(
                  inicial: ubicacionPorDefectoTaller,
                  esperaDelMapa: const Duration(seconds: 2),
                  construirMapa: (_, _, _) =>
                      const SizedBox.expand(key: Key('mapa_falso')),
                ),
              ),
            );
          },
          child: const Text('abrir'),
        ),
      ),
      width: 1024,
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    // Mientras se espera, el mapa sigue en pantalla: un mapa lento no es un
    // mapa roto. (La transición de ruta se come ~300 ms de reloj, de ahí que
    // la espera sean segundos y no milisegundos.)
    expect(find.byKey(const Key('mapa_falso')), findsOneWidget);
    expect(find.byKey(const Key('selector_ubicacion_sin_mapa')), findsNothing);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('selector_ubicacion_sin_mapa')),
      findsOneWidget,
    );
    // Y el mapa muerto se RETIRA: si no, el cartel de error de Google se
    // queda debajo del aviso.
    expect(find.byKey(const Key('mapa_falso')), findsNothing);
    expect(find.byKey(const Key('selector_ubicacion_ayuda')), findsNothing);

    await tester.enterText(
      find.byKey(const Key('selector_ubicacion_latitud')),
      '13.98',
    );
    await tester.enterText(
      find.byKey(const Key('selector_ubicacion_longitud')),
      '-89.55',
    );
    await tester.tap(find.byKey(const Key('selector_ubicacion_confirmar')));
    await tester.pumpAndSettle();

    expect(devuelto, const LatLng(13.98, -89.55));
  });

  testWidgets('unas coordenadas imposibles no mueven el taller', (
    tester,
  ) async {
    LatLng? devuelto;
    await pumpAtWidth(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            devuelto = await Navigator.of(context).push<LatLng>(
              MaterialPageRoute(
                builder: (_) => SelectorUbicacionTallerScreen(
                  inicial: ubicacionPorDefectoTaller,
                  esperaDelMapa: const Duration(seconds: 2),
                  construirMapa: (_, _, _) => const SizedBox.expand(),
                ),
              ),
            );
          },
          child: const Text('abrir'),
        ),
      ),
      width: 1024,
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('selector_ubicacion_latitud')),
      '999',
    );
    await tester.tap(find.byKey(const Key('selector_ubicacion_confirmar')));
    await tester.pumpAndSettle();

    expect(devuelto, ubicacionPorDefectoTaller);
  });

  testWidgets('salir sin confirmar no cambia nada', (tester) async {
    Object? devuelto = 'sin llamar';
    await pumpAtWidth(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            devuelto = await Navigator.of(context).push<LatLng>(
              MaterialPageRoute(
                builder: (_) => SelectorUbicacionTallerScreen(
                  inicial: ubicacionPorDefectoTaller,
                  construirMapa: (_, _, alCargar) {
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => alCargar(),
                    );
                    return const SizedBox.expand();
                  },
                ),
              ),
            );
          },
          child: const Text('abrir'),
        ),
      ),
      width: 375,
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    Navigator.of(
      tester.element(find.byType(SelectorUbicacionTallerScreen)),
    ).pop();
    await tester.pumpAndSettle();
    expect(devuelto, isNull);
  });
}
