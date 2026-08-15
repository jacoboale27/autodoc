import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/features/chat/presentation/widgets/chat_bubble.dart';
import 'package:autodoc/features/chat/presentation/widgets/cards/imagen_chat_card.dart';
import '../../../../../support/chat_harness.dart';
import '../../../../../support/responsive_harness.dart';

void main() {
  testWidgets('dos mensajes con la misma URL no colisionan en el Hero', (
    tester,
  ) async {
    // Reenviar una foto es normal en un chat. Con `tag: urlArchivo` esto
    // lanza "There are multiple heroes that share the same tag".
    await pumpChatWidget(
      tester,
      const Column(
        children: [
          ImagenChatCard(
            urlArchivo: 'https://example.com/averia.jpg',
            isMe: true,
            mensajeId: 'm1',
          ),
          ImagenChatCard(
            urlArchivo: 'https://example.com/averia.jpg',
            isMe: false,
            mensajeId: 'm2',
          ),
        ],
      ),
      width: 375,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('el alto de la imagen está acotado', (tester) async {
    await pumpChatWidget(
      tester,
      const ChatBubble(
        isMe: true,
        child: ImagenChatCard(
          urlArchivo: 'https://example.com/larga.jpg',
          isMe: true,
          mensajeId: 'm1',
        ),
      ),
      width: 375,
      height: 800,
    );
    final alto = tester.getSize(find.byType(ImagenChatCard)).height;
    expect(
      alto,
      lessThanOrEqualTo(360),
      reason:
          'Una captura alargada producía una burbuja de más de una '
          'pantalla de alto y expulsaba el resto de la conversación.',
    );
  });

  testWidgets('la imagen tiene etiqueta accesible', (tester) async {
    await pumpChatWidget(
      tester,
      const ImagenChatCard(
        urlArchivo: 'https://example.com/a.jpg',
        isMe: false,
        mensajeId: 'm1',
      ),
      width: 375,
    );
    expect(
      find.bySemanticsLabel('Imagen adjunta. Toca para ampliar.'),
      findsOneWidget,
    );
  });

  testWidgets('no desborda en ningún ancho auditado', (tester) async {
    for (final width in kAuditWidths) {
      await pumpChatWidget(
        tester,
        const ChatBubble(
          isMe: true,
          child: ImagenChatCard(
            urlArchivo: 'https://example.com/a.jpg',
            isMe: true,
            mensajeId: 'm1',
          ),
        ),
        width: width,
      );
      expectNoOverflow(tester);
    }
  });
}
