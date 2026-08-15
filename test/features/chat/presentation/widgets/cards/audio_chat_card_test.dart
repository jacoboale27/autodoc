import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/features/chat/presentation/widgets/chat_bubble.dart';
import 'package:autodoc/features/chat/presentation/widgets/cards/audio_chat_card.dart';
import '../../../../../support/chat_harness.dart';
import '../../../../../support/contrast.dart';

void main() {
  testWidgets(
    'AudioChatCard muestra botón de reproducir y duración formateada',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: AudioChatCard(
              urlArchivo: 'https://example.com/a.m4a',
              duracionSegundos: 65,
              isMe: true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.text('1:05'), findsOneWidget);
    },
  );

  testWidgets('el botón de reproducción tiene etiqueta accesible', (
    tester,
  ) async {
    await pumpChatWidget(
      tester,
      const ChatBubble(
        isMe: true,
        child: AudioChatCard(
          urlArchivo: 'https://example.com/a.m4a',
          duracionSegundos: 65,
          isMe: true,
        ),
      ),
      width: 375,
    );
    expect(
      find.bySemanticsLabel('Reproducir nota de voz, 1:05'),
      findsOneWidget,
    );
  });

  testWidgets('el contenido es legible sobre la burbuja en tema oscuro', (
    tester,
  ) async {
    // Regresión de §0.1(a): `contentColor = isMe ? Colors.white : ...`
    // sobre colors.primary, que en oscuro es #81E6D9 → 1,47:1.
    await pumpChatWidget(
      tester,
      const ChatBubble(
        isMe: true,
        child: AudioChatCard(
          urlArchivo: 'https://example.com/a.m4a',
          duracionSegundos: 65,
          isMe: true,
        ),
      ),
      width: 375,
      brightness: Brightness.dark,
    );
    final context = tester.element(find.byType(AudioChatCard));
    final colors = context.appColors;
    final duracion = tester.widget<Text>(find.text('1:05'));
    expect(
      contrastRatio(duracion.style!.color!, colors.primary),
      greaterThanOrEqualTo(4.5),
    );
  });

  testWidgets('el botón cumple el mínimo de 48 dp', (tester) async {
    await pumpChatWidget(
      tester,
      const ChatBubble(
        isMe: true,
        child: AudioChatCard(
          urlArchivo: 'https://example.com/a.m4a',
          duracionSegundos: 5,
          isMe: true,
        ),
      ),
      width: 375,
    );
    final size = tester.getSize(find.byType(IconButton));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });
}
