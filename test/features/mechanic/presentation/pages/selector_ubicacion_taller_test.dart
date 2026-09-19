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
                  construirMapa: (punto, alElegir) => GestureDetector(
                    key: const Key('mapa_falso'),
                    onTap: () => alElegir(elegido),
                    child: Text('punto ${punto.latitude}'),
                  ),
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
                  construirMapa: (_, _) => const SizedBox.expand(),
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
