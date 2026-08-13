import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/theme/app_motion.dart';
import 'package:autodoc/core/widgets/app_button.dart';

import '../../support/responsive_harness.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget button, {
    double width = 375,
    Brightness brightness = Brightness.light,
    bool disableAnimations = false,
  }) async {
    await pumpAtWidth(
      tester,
      Center(child: button),
      width: width,
      brightness: brightness,
      disableAnimations: disableAnimations,
    );
  }

  group('feedback de press', () {
    testWidgets('se encoge al presionar y vuelve al soltar', (tester) async {
      await pump(tester, AppButton(text: 'Guardar', onPressed: () {}));

      double currentScale() =>
          tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;

      expect(currentScale(), 1.0);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(AppButton)),
      );
      await tester.pump();
      expect(currentScale(), AppMotion.pressedScale);

      await gesture.up();
      await tester.pump();
      expect(currentScale(), 1.0);
    });

    testWidgets('vuelve a 1.0 si el gesto se cancela', (tester) async {
      await pump(tester, AppButton(text: 'Guardar', onPressed: () {}));

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(AppButton)),
      );
      await tester.pump();
      await gesture.cancel();
      await tester.pump();

      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
        1.0,
      );
    });

    testWidgets('un botón deshabilitado no se encoge', (tester) async {
      await pump(tester, const AppButton(text: 'Guardar', onPressed: null));

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(AppButton)),
      );
      await tester.pump();

      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
        1.0,
        reason: 'un control no interactivo no debe parecer que responde',
      );
      await gesture.up();
    });

    testWidgets('un botón en carga no se encoge ni dispara onPressed', (
      tester,
    ) async {
      var taps = 0;
      await pump(
        tester,
        AppButton(text: 'Guardar', isLoading: true, onPressed: () => taps++),
      );

      await tester.tap(find.byType(AppButton), warnIfMissed: false);
      // Duration.zero explícita: dispara el Future.delayed(Duration.zero)
      // que flutter_animate agenda al montar el shimmer del botón en carga.
      await tester.pump(Duration.zero);

      expect(taps, 0);
    });

    testWidgets('con reduced motion no hay encogimiento', (tester) async {
      await pump(
        tester,
        AppButton(text: 'Guardar', onPressed: () {}),
        disableAnimations: true,
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(AppButton)),
      );
      await tester.pump();

      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
        1.0,
      );
      await gesture.up();
    });
  });

  group('feedback de hover', () {
    testWidgets('se eleva al entrar el puntero y el press gana al hover', (
      tester,
    ) async {
      await pump(tester, AppButton(text: 'Guardar', onPressed: () {}));

      double currentScale() =>
          tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;

      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(
        pointer.hover(tester.getCenter(find.byType(AppButton))),
      );
      await tester.pump();
      expect(currentScale(), AppMotion.hoverScale);

      // Presionar mientras se está en hover debe mostrar el press, no el lift.
      await tester.sendEventToBinding(pointer.down(pointer.location!));
      await tester.pump();
      expect(currentScale(), AppMotion.pressedScale);

      await tester.sendEventToBinding(pointer.up());
      await tester.pump();
      expect(currentScale(), AppMotion.hoverScale);
    });
  });

  group('comportamiento preservado', () {
    testWidgets('tocar sigue disparando onPressed', (tester) async {
      var tapped = false;
      await pump(
        tester,
        AppButton(text: 'Guardar', onPressed: () => tapped = true),
      );

      await tester.tap(find.byType(AppButton));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('muestra el indicador de carga en vez del texto', (
      tester,
    ) async {
      await pump(
        tester,
        AppButton(text: 'Guardar', isLoading: true, onPressed: () {}),
      );
      // flutter_animate agenda un Future.delayed(Duration.zero) en initState
      // para arrancar el shimmer repetido. tester.pump() sin argumento no
      // avanza el reloj falso (solo vacía microtasks), así que ese timer
      // sigue pendiente al desmontar; hace falta un pump con Duration
      // explícita para dispararlo.
      await tester.pump(Duration.zero);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Guardar'), findsNothing);
    });
  });

  group('accesibilidad', () {
    testWidgets('todos los tamaños llegan a 48dp de alto', (tester) async {
      for (final size in AppButtonSize.values) {
        await pump(tester, AppButton(text: 'Ok', size: size, onPressed: () {}));

        final height = tester.getSize(find.byType(AppButton)).height;
        expect(
          height,
          greaterThanOrEqualTo(48.0),
          reason: '$size mide ${height}dp de alto',
        );
      }
    });

    testWidgets('expone semántica de botón con su etiqueta', (tester) async {
      await pump(tester, AppButton(text: 'Guardar', onPressed: () {}));

      expect(
        tester.getSemantics(find.byType(AppButton).first),
        matchesSemantics(
          label: 'Guardar',
          isButton: true,
          isEnabled: true,
          hasEnabledState: true,
          hasTapAction: true,
          isFocusable: true,
        ),
      );
    });

    testWidgets('semanticLabel sustituye a la etiqueta visible', (
      tester,
    ) async {
      await pump(
        tester,
        AppButton(
          text: 'Guardar',
          semanticLabel: 'Guardar los cambios del vehículo',
          onPressed: () {},
        ),
      );

      expect(
        find.bySemanticsLabel('Guardar los cambios del vehículo'),
        findsOneWidget,
      );
    });
  });

  group('render', () {
    testWidgets('los tres tipos renderizan en ambos temas sin excepciones', (
      tester,
    ) async {
      for (final brightness in Brightness.values) {
        for (final type in AppButtonType.values) {
          await pump(
            tester,
            AppButton(text: 'Ok', type: type, onPressed: () {}),
            brightness: brightness,
          );
          expectNoOverflow(tester);
        }
      }
    });
  });
}
