import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/widgets/animated_counter.dart';

import '../../support/responsive_harness.dart';

void main() {
  testWidgets('cuenta desde 0 hasta el valor y se detiene ahí', (tester) async {
    await pumpAtWidth(tester, const AnimatedCounter(value: 42), width: 375);

    expect(find.text('0'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('42'), findsOneWidget);
  });

  testWidgets('la duración por defecto no supera 600ms', (tester) async {
    await pumpAtWidth(tester, const AnimatedCounter(value: 42), width: 375);

    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    expect(
      find.text('42'),
      findsOneWidget,
      reason: 'el contador sigue animando tras 600ms',
    );
  });

  testWidgets('con reduced motion muestra el valor final de inmediato', (
    tester,
  ) async {
    await pumpAtWidth(
      tester,
      const AnimatedCounter(value: 42),
      width: 375,
      disableAnimations: true,
    );

    expect(
      find.text('42'),
      findsOneWidget,
      reason: 'con reduced motion no debe haber conteo',
    );
  });

  testWidgets('anima también al cambiar de valor', (tester) async {
    await pumpAtWidth(tester, const AnimatedCounter(value: 10), width: 375);
    await tester.pumpAndSettle();
    expect(find.text('10'), findsOneWidget);

    await pumpAtWidth(tester, const AnimatedCounter(value: 20), width: 375);
    await tester.pumpAndSettle();
    expect(find.text('20'), findsOneWidget);
  });

  testWidgets('respeta prefix y suffix', (tester) async {
    await pumpAtWidth(
      tester,
      const AnimatedCounter(value: 7, prefix: r'$', suffix: ' USD'),
      width: 375,
    );
    await tester.pumpAndSettle();

    expect(find.text(r'$7 USD'), findsOneWidget);
  });

  testWidgets('el lector de pantalla anuncia el valor final, no el tween', (
    tester,
  ) async {
    await pumpAtWidth(
      tester,
      const AnimatedCounter(value: 42, semanticLabel: '42 servicios'),
      width: 375,
    );

    // Sin esperar a que termine: la semántica ya debe ser la final.
    expect(find.bySemanticsLabel('42 servicios'), findsOneWidget);
  });
}
