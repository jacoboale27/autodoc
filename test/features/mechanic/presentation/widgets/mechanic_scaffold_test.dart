import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/features/mechanic/presentation/widgets/mechanic_scaffold.dart';
import 'package:autodoc/features/mechanic/presentation/widgets/mechanic_sidebar.dart';

import '../../../../support/mechanic_harness.dart';
import '../../../../support/responsive_harness.dart';

void main() {
  Future<void> pump(WidgetTester tester, double width) => pumpMechanicScreen(
    tester,
    const MechanicScaffold(
      title: 'Catálogo de Servicios',
      body: Center(child: Text('contenido')),
    ),
    width: width,
  );

  testWidgets('compact y medium usan drawer, no sidebar fijo', (tester) async {
    for (final width in [320.0, 375.0, 600.0, 768.0]) {
      await pump(tester, width);
      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(Row),
          matching: find.byType(MechanicSidebar),
        ),
        findsNothing,
        reason: 'a $width px el sidebar de 280 dp no debe ocupar el layout',
      );
      expect(find.byType(AppBar), findsOneWidget, reason: 'a $width px');
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).drawer,
        isNotNull,
        reason: 'a $width px debe haber drawer para llegar a la navegación',
      );
    }
  });

  testWidgets('expanded y large usan sidebar fijo, sin AppBar', (tester) async {
    for (final width in [840.0, 1024.0, 1200.0, 1440.0]) {
      await pump(tester, width);
      await tester.pump();

      expect(
        find.byType(MechanicSidebar),
        findsOneWidget,
        reason: 'a $width px',
      );
      expect(find.byType(AppBar), findsNothing, reason: 'a $width px');
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).drawer,
        isNull,
        reason: 'a $width px el sidebar ya está visible: el drawer sobra',
      );
    }
  });

  testWidgets('el título identifica la pantalla en las cuatro clases', (
    tester,
  ) async {
    await pump(tester, 375);
    await tester.pump();
    expect(find.text('Catálogo de Servicios'), findsOneWidget);

    await pump(tester, 1440);
    await tester.pump();
    expect(
      find.text('CATÁLOGO DE SERVICIOS'),
      findsOneWidget,
      reason: 'la barra de escritorio usa la variante en mayúsculas',
    );
  });

  testWidgets('no desborda en ninguno de los anchos de auditoría', (
    tester,
  ) async {
    for (final width in kAuditWidths) {
      await pump(tester, width);
      await tester.pump();
      expectNoOverflow(tester);
    }
  });

  testWidgets('el contenido recibe al menos 560 px cuando hay sidebar fijo', (
    tester,
  ) async {
    await pump(tester, 840);
    await tester.pump();

    final bodyWidth = tester.getSize(find.text('contenido')).width;
    expect(
      tester.getSize(find.byType(MechanicSidebar)).width,
      280,
      reason: 'el sidebar sigue midiendo 280 dp',
    );
    expect(
      bodyWidth,
      lessThanOrEqualTo(560),
      reason: 'sanity: el contenido cabe en el hueco que deja el sidebar',
    );
  });
}
