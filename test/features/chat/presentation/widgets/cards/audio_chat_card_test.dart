import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/features/chat/presentation/widgets/cards/audio_chat_card.dart';

void main() {
  testWidgets(
    'AudioChatCard muestra botón de reproducir y duración formateada',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
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
}
