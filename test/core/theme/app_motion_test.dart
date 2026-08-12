import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/theme/app_motion.dart';

void main() {
  group('curvas', () {
    test('easeOut arranca rápido: se siente inmediato al input', () {
      // A un 10% del tiempo ya recorrió más de un 30% del camino.
      expect(AppMotion.easeOut.transform(0.1), greaterThan(0.3));
      expect(AppMotion.easeOut.transform(1.0), closeTo(1.0, 0.001));
    });

    test(
      'easeInOut arranca lento: es para movimiento ya visible en pantalla',
      () {
        expect(AppMotion.easeInOut.transform(0.1), lessThan(0.1));
        expect(AppMotion.easeInOut.transform(1.0), closeTo(1.0, 0.001));
      },
    );

    test('drawer arranca rápido y desacelera largo', () {
      expect(AppMotion.drawer.transform(0.1), greaterThan(0.1));
      expect(AppMotion.drawer.transform(1.0), closeTo(1.0, 0.001));
    });
  });

  group('duraciones', () {
    test('toda micro-interacción se mantiene bajo 300ms', () {
      for (final duration in [
        AppMotion.press,
        AppMotion.hover,
        AppMotion.tooltip,
        AppMotion.dropdown,
      ]) {
        expect(duration.inMilliseconds, lessThan(300));
      }
    });

    test('la salida es más rápida que la entrada', () {
      expect(
        AppMotion.sheetExit.inMilliseconds,
        lessThan(AppMotion.sheetEnter.inMilliseconds),
      );
    });

    test('el paso de stagger está en el rango 30-80ms', () {
      expect(AppMotion.staggerStep.inMilliseconds, inInclusiveRange(30, 80));
    });
  });

  group('escalas de interacción', () {
    test('pressedScale es un encogimiento sutil (0.95-0.98)', () {
      expect(AppMotion.pressedScale, inInclusiveRange(0.95, 0.98));
    });

    test('hoverScale es un lift sutil', () {
      expect(AppMotion.hoverScale, greaterThan(1.0));
      expect(AppMotion.hoverScale, lessThan(1.05));
    });
  });

  group('reduced motion', () {
    Future<void> pumpWith(
      WidgetTester tester,
      bool disableAnimations,
      void Function(BuildContext) probe,
    ) async {
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: Builder(
            builder: (context) {
              probe(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    }

    testWidgets('sin reduced motion los valores pasan intactos', (
      tester,
    ) async {
      late bool reduced;
      late Duration duration;
      late double scale;

      await pumpWith(tester, false, (context) {
        reduced = AppMotion.reduced(context);
        duration = AppMotion.transformDuration(context, AppMotion.press);
        scale = AppMotion.pressScaleFor(context);
      });

      expect(reduced, isFalse);
      expect(duration, AppMotion.press);
      expect(scale, AppMotion.pressedScale);
    });

    testWidgets('con reduced motion se anula el movimiento', (tester) async {
      late bool reduced;
      late Duration duration;
      late double pressScale;
      late double hoverScale;

      await pumpWith(tester, true, (context) {
        reduced = AppMotion.reduced(context);
        duration = AppMotion.transformDuration(context, AppMotion.press);
        pressScale = AppMotion.pressScaleFor(context);
        hoverScale = AppMotion.hoverScaleFor(context);
      });

      expect(reduced, isTrue);
      expect(duration, Duration.zero);
      expect(pressScale, 1.0);
      expect(hoverScale, 1.0);
    });
  });
}
