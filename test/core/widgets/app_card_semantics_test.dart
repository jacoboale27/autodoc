import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
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

  test('interactiveChildren NO relaja el assert: una AppCard pulsable sigue '
      'necesitando semanticLabel', () {
    expect(
      () => AppCard(
        onTap: () {},
        interactiveChildren: true,
        child: const Text('Contenido'),
      ),
      throwsAssertionError,
    );
  });

  testWidgets(
    'por defecto la tarjeta se traga la semantica de sus hijos: un control '
    'de dentro se queda sin nodo propio',
    (tester) async {
      final handle = tester.ensureSemantics();

      await pumpAtWidth(
        tester,
        Center(
          child: AppCard(
            onTap: () {},
            semanticLabel: 'Tarjeta',
            child: IconButton(
              tooltip: 'Accion propia',
              icon: const Icon(Icons.star_border),
              onPressed: () {},
            ),
          ),
        ),
        width: 375,
      );

      // `getSemantics` sube al primer nodo ancestro: si el boton tuviera el
      // suyo, seria el del boton y traeria su tooltip.
      expect(tester.getSemantics(find.byType(IconButton)).tooltip, '');

      handle.dispose();
    },
  );

  testWidgets(
    'con interactiveChildren el control de dentro conserva su nodo, su '
    'nombre y su accion, y la tarjeta conserva su label',
    (tester) async {
      final handle = tester.ensureSemantics();

      await pumpAtWidth(
        tester,
        Center(
          child: AppCard(
            onTap: () {},
            semanticLabel: 'Tarjeta',
            interactiveChildren: true,
            child: IconButton(
              tooltip: 'Accion propia',
              icon: const Icon(Icons.star_border),
              onPressed: () {},
            ),
          ),
        ),
        width: 375,
      );

      final boton = tester.getSemantics(find.byType(IconButton));
      expect(boton.tooltip, 'Accion propia');
      expect(boton.getSemanticsData().flagsCollection.isButton, isTrue);
      expect(boton.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

      // Y la tarjeta no pierde el suyo por exponer a los hijos.
      expect(find.bySemanticsLabel('Tarjeta'), findsOneWidget);

      handle.dispose();
    },
  );
}
