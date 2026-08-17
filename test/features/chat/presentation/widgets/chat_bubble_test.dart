import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/features/chat/presentation/widgets/chat_bubble.dart';
import '../../../../support/responsive_harness.dart';

void main() {
  group('ChatBubble.maxWidthFor', () {
    test('en compact la burbuja usa el 80 % del ancho disponible', () {
      // 320 − 32 (padding del ListView) = 288 disponibles → 230.4
      expect(
        ChatBubble.maxWidthFor(288, WindowClass.compact),
        closeTo(230.4, 0.01),
      );
    });

    test('en medium sigue siendo proporcional, no fija', () {
      expect(
        ChatBubble.maxWidthFor(736, WindowClass.medium),
        closeTo(588.8, 0.01),
      );
    });

    test('a partir de expanded se acota al ancho de lectura', () {
      // 0.8 × 1408 = 1126.4, pero el tope de lectura manda.
      expect(
        ChatBubble.maxWidthFor(1408, WindowClass.expanded),
        AppBreakpoints.maxReadingWidth,
      );
      expect(
        ChatBubble.maxWidthFor(2000, WindowClass.large),
        AppBreakpoints.maxReadingWidth,
      );
    });

    test('nunca devuelve más que el ancho disponible', () {
      // Una ventana estrecha en clase large (ventana redimensionada a mano)
      // no puede producir una burbuja más ancha que su contenedor.
      expect(ChatBubble.maxWidthFor(200, WindowClass.large), 200);
    });
  });

  group('ChatBubble en el árbol', () {
    testWidgets('no desborda en ningún ancho auditado', (tester) async {
      for (final width in kAuditWidths) {
        await pumpAtWidth(
          tester,
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerRight,
              child: ChatBubble(
                isMe: true,
                child: Text(
                  'Buenas tardes, necesito una revisión completa de frenos '
                  'para el jueves por la mañana si es posible, y también '
                  'cambio de aceite.',
                ),
              ),
            ),
          ),
          width: width,
        );
        expectNoOverflow(tester);
      }
    });

    testWidgets('a 1440 px la burbuja no supera el ancho de lectura', (
      tester,
    ) async {
      await pumpAtWidth(
        tester,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerRight,
            child: ChatBubble(isMe: true, child: Text('x' * 600)),
          ),
        ),
        width: 1440,
      );
      final size = tester.getSize(find.byType(ChatBubble));
      expect(size.width, lessThanOrEqualTo(AppBreakpoints.maxReadingWidth));
    });

    testWidgets('la cola apunta al lado correcto según isMe', (tester) async {
      await pumpAtWidth(
        tester,
        const ChatBubble(isMe: true, child: Text('a')),
        width: 375,
      );
      final propio = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(ChatBubble),
              matching: find.byType(Container),
            )
            .first,
      );
      final radiusPropio =
          (propio.decoration as BoxDecoration).borderRadius as BorderRadius;
      expect(radiusPropio.bottomRight, Radius.zero);
      expect(radiusPropio.bottomLeft, isNot(Radius.zero));
    });

    testWidgets('expone un semanticLabel cuando se le pasa', (tester) async {
      await pumpAtWidth(
        tester,
        const ChatBubble(
          isMe: false,
          semanticLabel: 'Mensaje de Taller Escobar',
          child: Text('Hola'),
        ),
        width: 375,
      );
      expect(
        find.bySemanticsLabel('Mensaje de Taller Escobar'),
        findsOneWidget,
      );
    });
  });
}
