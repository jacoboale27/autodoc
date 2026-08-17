// test/support/responsive_harness_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';

import 'responsive_harness.dart';

void main() {
  test('kAuditWidths cubre las 4 window classes y los cortes exactos', () {
    expect(kAuditWidths, [320, 375, 600, 768, 840, 1024, 1200, 1440]);

    final covered = kAuditWidths.map(AppBreakpoints.fromWidth).toSet();
    expect(covered, WindowClass.values.toSet());

    // Los tres cortes exactos están presentes: son donde rompe.
    expect(kAuditWidths, containsAll([600.0, 840.0, 1200.0]));
  });

  testWidgets('pumpAtWidth fija el ancho lógico del viewport', (tester) async {
    for (final width in kAuditWidths) {
      late double observed;
      await pumpAtWidth(
        tester,
        Builder(
          builder: (context) {
            observed = MediaQuery.sizeOf(context).width;
            return const SizedBox.shrink();
          },
        ),
        width: width,
      );
      expect(observed, width, reason: 'ancho observado != solicitado @$width');
    }
  });

  testWidgets('pumpAtWidth aplica el brightness pedido', (tester) async {
    late Brightness observed;
    await pumpAtWidth(
      tester,
      Builder(
        builder: (context) {
          observed = Theme.of(context).brightness;
          return const SizedBox.shrink();
        },
      ),
      width: 375,
      brightness: Brightness.dark,
    );
    expect(observed, Brightness.dark);
  });

  testWidgets('pumpAtWidth propaga disableAnimations al MediaQuery', (
    tester,
  ) async {
    late bool observed;
    await pumpAtWidth(
      tester,
      Builder(
        builder: (context) {
          observed = MediaQuery.disableAnimationsOf(context);
          return const SizedBox.shrink();
        },
      ),
      width: 375,
      disableAnimations: true,
    );
    expect(observed, isTrue);
  });

  testWidgets('expectNoOverflow detecta un RenderFlex overflow real', (
    tester,
  ) async {
    await pumpAtWidth(
      tester,
      // Ambos hijos necesitan `height` explícito: si el cross axis del Row
      // colapsa a 0, `RenderFlex.paint` retorna antes de reportar el
      // overflow (`size.isEmpty`), y `takeException()` vería `null` pese a
      // que el layout sí desbordó.
      const Row(
        children: [
          SizedBox(width: 900, height: 50),
          SizedBox(width: 900, height: 50),
        ],
      ),
      width: 375,
    );

    // Hay overflow: la excepción existe. La consumimos para no ensuciar el test.
    expect(tester.takeException(), isNotNull);
  });

  testWidgets('expectNoOverflow pasa cuando no hay overflow', (tester) async {
    await pumpAtWidth(tester, const SizedBox(width: 100), width: 375);
    expectNoOverflow(tester);
  });
}
