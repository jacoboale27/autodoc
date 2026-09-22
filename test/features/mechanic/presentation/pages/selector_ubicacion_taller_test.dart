// Observaciones del 2026-09-19: «no deja seleccionar bien la ubicación del
// taller ... el mapa no funciona y se queda estático». Eran dos causas: el
// mapa vivía en un AlertDialog (en la web la capa de accesibilidad del
// diálogo se quedaba los clics) y la clave de Google Maps estaba vencida.
//
// Observación del 2026-09-20 («arregla lo del mapa»): ya no hay clave. El
// mapa son tiles de OpenStreetMap dibujados por Flutter, así que ni siquiera
// hace falta sustituirlo para probarlo — antes había que inyectar un mapa
// falso porque el plugin de Google no tiene plataforma en un widget test.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:autodoc/features/mechanic/presentation/pages/selector_ubicacion_taller_screen.dart';

import '../../../../support/responsive_harness.dart';

Future<LatLng?> abrirSelector(
  WidgetTester tester, {
  double width = 1024,
}) async {
  LatLng? devuelto;
  await pumpAtWidth(
    tester,
    Builder(
      builder: (context) => TextButton(
        onPressed: () async {
          devuelto = await Navigator.of(context).push<LatLng>(
            MaterialPageRoute(
              builder: (_) => const SelectorUbicacionTallerScreen(
                inicial: ubicacionPorDefectoTaller,
              ),
            ),
          );
        },
        child: const Text('abrir'),
      ),
    ),
    width: width,
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return devuelto;
}

void main() {
  test('el mapa del taller no vuelve a un diálogo ni a Google Maps', () {
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
    expect(
      selector.contains('google_maps_flutter'),
      isFalse,
      reason: 'una clave que caduca deja la app sin mapa y sin avisar',
    );
    expect(selector.contains('MapaOsm('), isTrue);
  });

  testWidgets('ya no hace falta clave: el mapa se dibuja en el árbol', (
    tester,
  ) async {
    await abrirSelector(tester);

    expect(find.byKey(const Key('selector_ubicacion_mapa')), findsOneWidget);
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byKey(const Key('selector_ubicacion_ayuda')), findsOneWidget);
  });

  testWidgets('tocar el mapa mueve el punto y confirmar lo devuelve', (
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
                builder: (_) => const SelectorUbicacionTallerScreen(
                  inicial: ubicacionPorDefectoTaller,
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

    // Arriba y a la izquierda del centro: más al norte y más al oeste.
    //
    // Gesto a mano y medio segundo de espera, no `tester.tapAt` + `pump()`:
    // `FlutterMap` distingue el toque del doble toque (que hace zoom), así
    // que retiene el `onTap` hasta que vence esa ventana. Con un solo pump el
    // toque no llega nunca y el test ve el punto inicial — que es como parecía
    // que «el mapa no responde».
    final centro = tester.getCenter(find.byType(FlutterMap));
    final gesto = await tester.startGesture(centro + const Offset(-120, -80));
    await gesto.up();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    await tester.tap(find.byKey(const Key('selector_ubicacion_confirmar')));
    await tester.pumpAndSettle();

    expect(devuelto, isNotNull);
    expect(
      devuelto!.latitude,
      greaterThan(ubicacionPorDefectoTaller.latitude),
      reason: 'tocar más arriba en la pantalla es más al norte',
    );
    expect(
      devuelto!.longitude,
      lessThan(ubicacionPorDefectoTaller.longitude),
      reason: 'tocar más a la izquierda es más al oeste',
    );
  });

  testWidgets('confirmar sin tocar devuelve el punto inicial', (tester) async {
    LatLng? devuelto;
    await pumpAtWidth(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            devuelto = await Navigator.of(context).push<LatLng>(
              MaterialPageRoute(
                builder: (_) => const SelectorUbicacionTallerScreen(
                  inicial: LatLng(13.5, -89.1),
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

    await tester.tap(find.byKey(const Key('selector_ubicacion_confirmar')));
    await tester.pumpAndSettle();

    expect(devuelto, const LatLng(13.5, -89.1));
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
                builder: (_) => const SelectorUbicacionTallerScreen(
                  inicial: ubicacionPorDefectoTaller,
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

  testWidgets('el marcador se dibuja donde está el punto', (tester) async {
    await abrirSelector(tester);
    expect(find.byIcon(Icons.location_on), findsOneWidget);
  });
}
