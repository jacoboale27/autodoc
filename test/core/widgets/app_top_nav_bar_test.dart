import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/widgets/navigation/app_nav_destination.dart';

import '../../support/shell_harness.dart';
import '../../support/responsive_harness.dart';

void main() {
  testWidgets('no desborda a 1200px, el ancho mínimo donde se muestra', (
    tester,
  ) async {
    await pumpTopNav(
      tester,
      width: 1200,
      userName: 'Un Nombre Largo De Verdad',
    );
    expectNoOverflow(tester);
  });

  testWidgets('no desborda a 1200px con el nombre más largo plausible', (
    tester,
  ) async {
    await pumpTopNav(
      tester,
      width: 1200,
      userName: 'María de los Ángeles Hernández Villalobos',
    );
    expectNoOverflow(tester);
  });

  testWidgets('muestra los mismos destinos que AppNavDestinations', (
    tester,
  ) async {
    await pumpTopNav(tester, width: 1440);

    for (final destination in AppNavDestinations.owner) {
      expect(
        find.text(destination.label),
        findsWidgets,
        reason: 'falta ${destination.route} en la barra superior',
      );
    }
  });

  testWidgets('los controles de icono tienen tooltip', (tester) async {
    await pumpTopNav(tester, width: 1440);

    for (final button in tester.widgetList<IconButton>(
      find.byType(IconButton),
    )) {
      expect(
        button.tooltip,
        isNotNull,
        reason: 'IconButton sin tooltip: ${button.icon}',
      );
      expect(button.tooltip, isNotEmpty);
    }
  });

  testWidgets('renderiza en dark mode sin excepciones', (tester) async {
    await pumpTopNav(tester, width: 1440, brightness: Brightness.dark);
    expectNoOverflow(tester);
  });
}
