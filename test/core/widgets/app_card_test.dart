import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/theme/app_motion.dart';
import 'package:autodoc/core/widgets/app_card.dart';

import '../../support/responsive_harness.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget card, {
    bool disableAnimations = false,
    Brightness brightness = Brightness.light,
  }) async {
    await pumpAtWidth(
      tester,
      Center(child: card),
      width: 375,
      brightness: brightness,
      disableAnimations: disableAnimations,
    );
  }

  testWidgets('sin onTap no anima: es una superficie estática', (tester) async {
    await pump(tester, const AppCard(child: Text('Contenido')));

    expect(
      find.byType(AnimatedScale),
      findsNothing,
      reason: 'una tarjeta no pulsable no debe prometer interacción',
    );
  });

  testWidgets('con onTap se encoge al presionar y vuelve al soltar', (
    tester,
  ) async {
    await pump(
      tester,
      AppCard(
        onTap: () {},
        semanticLabel: 'Contenido',
        child: const Text('Contenido'),
      ),
    );

    double currentScale() =>
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;

    expect(currentScale(), 1.0);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(AppCard)),
    );
    await tester.pump();
    expect(currentScale(), AppMotion.pressedScale);

    await gesture.up();
    await tester.pump();
    expect(currentScale(), 1.0);
  });

  testWidgets('con onTap se eleva al pasar el puntero', (tester) async {
    await pump(
      tester,
      AppCard(
        onTap: () {},
        semanticLabel: 'Contenido',
        child: const Text('Contenido'),
      ),
    );

    List<BoxShadow>? shadowOf() {
      final container = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      return (container.decoration as BoxDecoration?)?.boxShadow;
    }

    final resting = shadowOf()!.first.blurRadius;

    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(
      pointer.hover(tester.getCenter(find.byType(AppCard))),
    );
    await tester.pump();

    expect(
      shadowOf()!.first.blurRadius,
      greaterThan(resting),
      reason: 'la tarjeta no se elevó al hover',
    );
  });

  testWidgets('tocar dispara onTap', (tester) async {
    var tapped = false;
    await pump(
      tester,
      AppCard(
        onTap: () => tapped = true,
        semanticLabel: 'Contenido',
        child: const Text('Contenido'),
      ),
    );

    await tester.tap(find.byType(AppCard));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('con reduced motion no se encoge', (tester) async {
    await pump(
      tester,
      AppCard(
        onTap: () {},
        semanticLabel: 'Contenido',
        child: const Text('Contenido'),
      ),
      disableAnimations: true,
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(AppCard)),
    );
    await tester.pump();

    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1.0);
    await gesture.up();
  });

  testWidgets('una tarjeta pulsable expone semántica de botón', (tester) async {
    await pump(
      tester,
      AppCard(
        onTap: () {},
        semanticLabel: 'Toyota Corolla 2019',
        child: const Text('Contenido'),
      ),
    );

    expect(find.bySemanticsLabel('Toyota Corolla 2019'), findsOneWidget);
  });

  testWidgets('renderiza en ambos temas sin excepciones', (tester) async {
    for (final brightness in Brightness.values) {
      await pump(
        tester,
        AppCard(
          onTap: () {},
          semanticLabel: 'Contenido',
          child: const Text('Contenido'),
        ),
        brightness: brightness,
      );
      expectNoOverflow(tester);
    }
  });
}
