import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/widgets/app_horizontal_scroller.dart';

import '../../support/responsive_harness.dart';

/// Regresion de "en desktop no deja desplazar las alertas activas".
///
/// La fila era una `SingleChildScrollView` horizontal a secas, y en desktop eso
/// no se puede mover: la rueda del raton emite delta vertical (`scrollDelta.dx`
/// es 0) y `Scrollable` solo consume el eje que coincide con su direccion; el
/// arrastre con raton viene desactivado en `ScrollBehavior.dragDevices`; y
/// `MaterialScrollBehavior.buildScrollbar` no pone barra en el eje horizontal.
/// Las tarjetas a partir de la tercera eran sencillamente inalcanzables.
const _flechaDerecha = ValueKey('horizontal-scroller-flecha-derecha');
const _flechaIzquierda = ValueKey('horizontal-scroller-flecha-izquierda');

Widget _scroller({int tarjetas = 8}) => AppHorizontalScroller(
  semanticLabel: 'alertas',
  children: [
    for (var i = 0; i < tarjetas; i++)
      SizedBox(width: 240, height: 120, child: Card(child: Text('tarjeta $i'))),
  ],
);

void main() {
  testWidgets('en desktop aparece la flecha derecha si sobra contenido', (
    tester,
  ) async {
    await pumpAtWidth(tester, _scroller(), width: 1440);
    await tester.pumpAndSettle();

    expect(find.byKey(_flechaDerecha), findsOneWidget);
    // Al principio del recorrido no hay nada hacia atras.
    expect(find.byKey(_flechaIzquierda), findsNothing);
  });

  testWidgets('la flecha derecha desplaza y entonces aparece la izquierda', (
    tester,
  ) async {
    await pumpAtWidth(tester, _scroller(), width: 1440);
    await tester.pumpAndSettle();

    final antes = tester
        .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
        .controller!
        .offset;

    await tester.tap(find.byKey(_flechaDerecha));
    await tester.pumpAndSettle();

    final despues = tester
        .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
        .controller!
        .offset;

    expect(despues, greaterThan(antes), reason: 'la flecha no desplazo nada');
    expect(find.byKey(_flechaIzquierda), findsOneWidget);
  });

  testWidgets('al llegar al final se apaga la flecha derecha', (tester) async {
    await pumpAtWidth(tester, _scroller(tarjetas: 3), width: 1440);
    await tester.pumpAndSettle();

    final controller = tester
        .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
        .controller!;
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();

    expect(find.byKey(_flechaDerecha), findsNothing);
  });

  testWidgets('sin desbordamiento no hay flechas', (tester) async {
    await pumpAtWidth(tester, _scroller(tarjetas: 1), width: 1440);
    await tester.pumpAndSettle();

    expect(find.byKey(_flechaDerecha), findsNothing);
    expect(find.byKey(_flechaIzquierda), findsNothing);
  });

  testWidgets('en compact y medium no se dibujan flechas', (tester) async {
    // Ahi hay dedo, y las flechas taparian contenido justo donde menos ancho
    // sobra.
    for (final width in [375.0, 768.0]) {
      await pumpAtWidth(tester, _scroller(), width: width);
      await tester.pumpAndSettle();
      expect(find.byKey(_flechaDerecha), findsNothing, reason: '$width px');
      expect(find.byKey(_flechaIzquierda), findsNothing, reason: '$width px');
    }
  });

  testWidgets('acepta arrastre con raton, no solo con dedo', (tester) async {
    await pumpAtWidth(tester, _scroller(), width: 1440);
    await tester.pumpAndSettle();

    final scrollable = tester.widget<SingleChildScrollView>(
      find.byType(SingleChildScrollView),
    );
    final antes = scrollable.controller!.offset;

    // kind: mouse es la clave — con el dragDevices por defecto este gesto se
    // ignora por completo.
    final gesto = await tester.startGesture(
      tester.getCenter(find.byType(SingleChildScrollView)),
      kind: PointerDeviceKind.mouse,
    );
    await gesto.moveBy(const Offset(-200, 0));
    await gesto.up();
    await tester.pumpAndSettle();

    expect(
      scrollable.controller!.offset,
      greaterThan(antes),
      reason: 'el arrastre con raton no movio la fila',
    );
  });

  testWidgets('no desborda en ningun ancho de auditoria', (tester) async {
    await forEachAuditWidth(tester, (width) async {
      await pumpAtWidth(tester, _scroller(), width: width);
      await tester.pumpAndSettle();
      expectNoOverflow(tester);
    });
  });
}
