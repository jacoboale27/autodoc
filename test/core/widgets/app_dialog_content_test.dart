import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/widgets/app_dialog_content.dart';

import '../../support/responsive_harness.dart';

void main() {
  Future<void> pumpDialog(WidgetTester tester, double width) async {
    await pumpAtWidth(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => const AlertDialog(
              title: Text('Nuevo ítem'),
              content: AppDialogContent(child: TextField(key: Key('campo'))),
            ),
          ),
          child: const Text('abrir'),
        ),
      ),
      width: width,
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('no desborda ni siquiera a 320 px', (tester) async {
    await pumpDialog(tester, 320);
    expectNoOverflow(tester);
    expect(tester.getSize(find.byKey(const Key('campo'))).width, lessThan(320));
  });

  testWidgets('no se estira más allá de la medida de formulario', (
    tester,
  ) async {
    await pumpDialog(tester, 1440);
    expect(
      tester.getSize(find.byKey(const Key('campo'))).width,
      lessThanOrEqualTo(560),
    );
  });
}
