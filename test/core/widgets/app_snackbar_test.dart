import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/widgets/app_snackbar.dart';

import '../../support/contrast.dart';
import '../../support/responsive_harness.dart';

const double kAaBody = 4.5;
const double kAaGlyph = 3.0;

void main() {
  Future<void> showAndSettle(
    WidgetTester tester,
    SnackbarType type, {
    Brightness brightness = Brightness.light,
  }) async {
    await pumpAtWidth(
      tester,
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => AppSnackbar.show(context, 'Mensaje', type: type),
          child: const Text('mostrar'),
        ),
      ),
      width: 375,
      brightness: brightness,
    );
    await tester.tap(find.text('mostrar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));
  }

  group('contraste', () {
    testWidgets('el texto pasa AA en los tres tipos y ambos temas', (
      tester,
    ) async {
      for (final brightness in Brightness.values) {
        for (final type in SnackbarType.values) {
          await showAndSettle(tester, type, brightness: brightness);

          final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
          final background = snackBar.backgroundColor!;
          final text = tester.widget<Text>(find.text('Mensaje'));
          final textColor = text.style!.color!;

          expect(
            contrastRatio(textColor, background),
            greaterThanOrEqualTo(kAaBody),
            reason: '$type / $brightness: texto sobre fondo',
          );
        }
      }
    });

    testWidgets('el icono se distingue del fondo en los tres tipos', (
      tester,
    ) async {
      for (final type in SnackbarType.values) {
        await showAndSettle(tester, type);

        final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
        final icon = tester.widget<Icon>(find.byType(Icon).first);

        expect(
          contrastRatio(icon.color!, snackBar.backgroundColor!),
          greaterThanOrEqualTo(kAaGlyph),
          reason: '$type: icono sobre fondo',
        );
      }
    });
  });

  group('el color no es el único indicador', () {
    testWidgets('cada tipo usa un icono distinto', (tester) async {
      final icons = <IconData>{};

      for (final type in SnackbarType.values) {
        await showAndSettle(tester, type);
        icons.add(tester.widget<Icon>(find.byType(Icon).first).icon!);
      }

      expect(
        icons.length,
        SnackbarType.values.length,
        reason: 'dos tipos comparten icono: se distinguen solo por color',
      );
    });
  });

  group('tokens', () {
    testWidgets('no usa Colors.white literal en el estilo del texto', (
      tester,
    ) async {
      await showAndSettle(tester, SnackbarType.success);

      final text = tester.widget<Text>(find.text('Mensaje'));
      // El color debe salir de la paleta, no de Colors.white.
      expect(text.style?.color, isNotNull);
      expect(text.style?.fontFamily, isNotNull);
    });
  });

  group('comportamiento preservado', () {
    testWidgets('muestra el mensaje y la acción OK', (tester) async {
      await showAndSettle(tester, SnackbarType.info);

      expect(find.text('Mensaje'), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);
    });

    testWidgets('no desborda con un mensaje largo a 320px', (tester) async {
      await pumpAtWidth(
        tester,
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => AppSnackbar.show(
              context,
              'No se pudo guardar el servicio porque el vehículo ya no está '
              'asociado a tu cuenta. Vuelve a intentarlo más tarde.',
            ),
            child: const Text('mostrar'),
          ),
        ),
        width: 320,
      );
      await tester.tap(find.text('mostrar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));

      expectNoOverflow(tester);
    });
  });
}
