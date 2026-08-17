import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/widgets/navigation/app_nav_destination.dart';
import 'package:autodoc/core/widgets/navigation/app_nav_rail.dart';

import '../../../support/responsive_harness.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required double width,
    required bool extended,
    int currentIndex = 0,
    ValueChanged<int>? onSelected,
    Brightness brightness = Brightness.light,
  }) async {
    await pumpAtWidth(
      tester,
      Row(
        children: [
          AppNavRail(
            currentIndex: currentIndex,
            extended: extended,
            onDestinationSelected: onSelected ?? (_) {},
          ),
          const Expanded(child: SizedBox()),
        ],
      ),
      width: width,
      brightness: brightness,
    );
    // pumpAtWidth solo hace pumpWidget: entre dos pumps con distinto
    // `extended` en el mismo tester, NavigationRail reutiliza su elemento y
    // anima el ancho en vez de saltar al valor final. pumpAndSettle asegura
    // que cada pump refleje el estado en reposo.
    await tester.pumpAndSettle();
  }

  testWidgets('colapsado muestra iconos sin etiquetas visibles', (
    tester,
  ) async {
    await pump(tester, width: 768, extended: false);

    expect(find.byType(NavigationRail), findsOneWidget);
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isFalse);
    expect(rail.destinations.length, AppNavDestinations.owner.length);
  });

  testWidgets('extendido muestra las etiquetas', (tester) async {
    await pump(tester, width: 1024, extended: true);

    for (final destination in AppNavDestinations.owner) {
      expect(find.text(destination.label), findsOneWidget);
    }
  });

  testWidgets('colapsado ocupa menos ancho que extendido', (tester) async {
    await pump(tester, width: 1024, extended: false);
    final collapsed = tester.getSize(find.byType(NavigationRail)).width;

    await pump(tester, width: 1024, extended: true);
    final expanded = tester.getSize(find.byType(NavigationRail)).width;

    expect(collapsed, lessThan(expanded));
    expect(collapsed, greaterThanOrEqualTo(72.0)); // mínimo tappable + holgura
  });

  testWidgets('notifica el índice seleccionado', (tester) async {
    int? selected;
    await pump(
      tester,
      width: 1024,
      extended: true,
      onSelected: (index) => selected = index,
    );

    await tester.tap(find.text('Talleres'));
    await tester.pumpAndSettle();

    expect(selected, 3);
  });

  testWidgets('cada destino tiene semántica aunque esté colapsado', (
    tester,
  ) async {
    await pump(tester, width: 768, extended: false);

    for (final destination in AppNavDestinations.owner) {
      expect(
        find.bySemanticsLabel(RegExp(RegExp.escape(destination.label))),
        findsWidgets,
        reason: 'sin semántica: ${destination.route}',
      );
    }
  });

  testWidgets('el destino activo usa el icono filled', (tester) async {
    await pump(tester, width: 1024, extended: true, currentIndex: 2);
    expect(
      find.byIcon(AppNavDestinations.owner[2].selectedIcon),
      findsOneWidget,
    );
  });

  testWidgets('renderiza en dark mode sin excepciones', (tester) async {
    await pump(
      tester,
      width: 1024,
      extended: true,
      brightness: Brightness.dark,
    );
    expectNoOverflow(tester);
  });
}
