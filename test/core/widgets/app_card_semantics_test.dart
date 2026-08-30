import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/widgets/app_card.dart';

import '../../support/responsive_harness.dart';

void main() {
  test('una AppCard pulsable sin semanticLabel dispara el assert de '
      'construcción (en el garaje se anunciaban cinco "boton" sin nombre)', () {
    expect(
      () => AppCard(onTap: () {}, child: const Text('Contenido')),
      throwsAssertionError,
    );
  });

  testWidgets('una AppCard pulsable expone el rol de boton', (tester) async {
    final handle = tester.ensureSemantics();

    await pumpAtWidth(
      tester,
      Center(
        child: AppCard(
          onTap: () {},
          semanticLabel: 'Volkswagen Jetta, placa P376-571',
          child: const Text('Contenido'),
        ),
      ),
      width: 375,
    );

    expect(
      tester.getSemantics(find.byType(AppCard)),
      matchesSemantics(
        label: 'Volkswagen Jetta, placa P376-571',
        isButton: true,
        isFocusable: true,
        hasTapAction: true,
      ),
    );

    handle.dispose();
  });
}
