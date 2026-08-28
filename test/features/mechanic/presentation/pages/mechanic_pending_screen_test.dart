import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/features/mechanic/presentation/pages/mechanic_pending_screen.dart';

import '../../../../support/mechanic_harness.dart';
import '../../../../support/responsive_harness.dart';

void main() {
  testWidgets('no desborda en ningún ancho de auditoría, ni en 568 de alto', (
    tester,
  ) async {
    for (final width in kAuditWidths) {
      await pumpMechanicScreen(
        tester,
        const MechanicPendingScreen(),
        width: width,
        height: 568,
        location: '/mechanic_pending',
        disableAnimations: true,
      );
      await tester.pump();
      expectNoOverflow(tester);
    }
  });

  testWidgets('la pantalla se estabiliza: no hay animación en bucle', (
    tester,
  ) async {
    await pumpMechanicScreen(
      tester,
      const MechanicPendingScreen(),
      width: 375,
      location: '/mechanic_pending',
    );

    // Con el `repeat()` actual esto lanza
    // "pumpAndSettle timed out": la animación nunca termina.
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('Cuenta Pendiente de Aprobación'), findsOneWidget);
  });

  testWidgets('usa AppButton, no un ElevatedButton crudo', (tester) async {
    await pumpMechanicScreen(
      tester,
      const MechanicPendingScreen(),
      width: 375,
      location: '/mechanic_pending',
      disableAnimations: true,
    );
    await tester.pump();

    // findsWidgets y no findsOneWidget: la pantalla tiene dos acciones
    // (verificar estado y completar la verificacion). Lo que este test
    // protege es que ninguna sea un ElevatedButton crudo.
    expect(find.byType(AppButton), findsWidgets);
    expect(find.byType(ElevatedButton), findsNothing);
  });

  testWidgets('el contenido no se estira más allá de la medida de formulario', (
    tester,
  ) async {
    await pumpMechanicScreen(
      tester,
      const MechanicPendingScreen(),
      width: 1440,
      location: '/mechanic_pending',
      disableAnimations: true,
    );
    await tester.pump();

    final width = tester
        .getSize(find.text('Cuenta Pendiente de Aprobación'))
        .width;
    expect(
      width,
      lessThanOrEqualTo(560),
      reason: 'un párrafo de 1440 px de ancho es ilegible',
    );
  });
}
