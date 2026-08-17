import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/widgets/navigation/app_bottom_nav.dart';
import 'package:autodoc/core/widgets/navigation/app_nav_destination.dart';

import '../../../support/responsive_harness.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    int currentIndex = 0,
    ValueChanged<int>? onSelected,
    Brightness brightness = Brightness.light,
  }) async {
    await pumpAtWidth(
      tester,
      Align(
        alignment: Alignment.bottomCenter,
        child: AppBottomNav(
          currentIndex: currentIndex,
          onDestinationSelected: onSelected ?? (_) {},
        ),
      ),
      width: 375,
      brightness: brightness,
    );
  }

  testWidgets('renderiza un destino por entrada de AppNavDestinations', (
    tester,
  ) async {
    await pump(tester);

    for (final destination in AppNavDestinations.owner) {
      expect(
        find.text(destination.label),
        findsOneWidget,
        reason: 'falta la etiqueta visible de ${destination.route}',
      );
    }
  });

  testWidgets('cada destino tiene un área tappable de al menos 48dp', (
    tester,
  ) async {
    await pump(tester);

    final destinations = find.byType(NavigationDestination);
    expect(destinations, findsNWidgets(AppNavDestinations.owner.length));

    for (var i = 0; i < AppNavDestinations.owner.length; i++) {
      final size = tester.getSize(destinations.at(i));
      expect(
        size.height,
        greaterThanOrEqualTo(48.0),
        reason: 'destino $i mide ${size.height}dp de alto',
      );
    }
  });

  testWidgets('notifica el índice tocado', (tester) async {
    int? selected;
    await pump(tester, onSelected: (index) => selected = index);

    await tester.tap(find.text('Garaje'));
    await tester.pumpAndSettle();

    expect(selected, 1);
  });

  testWidgets('el destino activo usa el icono filled, no solo color', (
    tester,
  ) async {
    await pump(tester, currentIndex: 1);

    expect(
      find.byIcon(AppNavDestinations.owner[1].selectedIcon),
      findsOneWidget,
    );
    expect(find.byIcon(AppNavDestinations.owner[1].icon), findsNothing);
  });

  testWidgets('no desborda a 320px', (tester) async {
    await pumpAtWidth(
      tester,
      Align(
        alignment: Alignment.bottomCenter,
        child: AppBottomNav(currentIndex: 0, onDestinationSelected: (_) {}),
      ),
      width: 320,
    );
    expectNoOverflow(tester);
  });

  testWidgets('renderiza en dark mode sin excepciones', (tester) async {
    await pump(tester, brightness: Brightness.dark);
    expectNoOverflow(tester);
  });
}
