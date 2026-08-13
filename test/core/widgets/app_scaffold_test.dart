import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/widgets/app_scaffold.dart';

import '../../support/responsive_harness.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required double width,
    Widget? bottomNavigationBar,
    bool applyGutter = false,
  }) async {
    await pumpAtWidth(
      tester,
      AppScaffold(
        applyGutter: applyGutter,
        bottomNavigationBar: bottomNavigationBar,
        body: Container(key: const Key('body')),
      ),
      width: width,
    );
  }

  testWidgets('la barra inferior solo se muestra en compact', (tester) async {
    const bar = SizedBox(key: Key('bottom'), height: 60);

    await pump(tester, width: 375, bottomNavigationBar: bar);
    expect(find.byKey(const Key('bottom')), findsOneWidget);

    for (final width in [768.0, 1024.0, 1440.0]) {
      await pump(tester, width: width, bottomNavigationBar: bar);
      expect(
        find.byKey(const Key('bottom')),
        findsNothing,
        reason: 'barra inferior visible @$width, donde ya hay rail o top nav',
      );
    }
  });

  testWidgets('sin applyGutter el body ocupa todo el ancho', (tester) async {
    await pump(tester, width: 1440);
    expect(tester.getSize(find.byKey(const Key('body'))).width, 1440);
  });

  testWidgets('con applyGutter el body respeta el gutter y el ancho máximo', (
    tester,
  ) async {
    await pump(tester, width: 375, applyGutter: true);
    expect(tester.getSize(find.byKey(const Key('body'))).width, 375 - 16 * 2);

    await pump(tester, width: 1440, applyGutter: true);
    expect(tester.getSize(find.byKey(const Key('body'))).width, 1200 - 40 * 2);
  });

  testWidgets('no desborda en ningún ancho de auditoría', (tester) async {
    await forEachAuditWidth(tester, (width) async {
      await pump(tester, width: width, applyGutter: true);
      expectNoOverflow(tester);
    });
  });
}
