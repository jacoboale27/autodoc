import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/features/chat/presentation/widgets/chat_bubble.dart';
import '../../../../support/responsive_harness.dart';

void main() {
  group('ChatBubble contrast', () {
    testWidgets('en oscuro la burbuja ajena contrasta con el fondo del chat', (
      tester,
    ) async {
      await pumpAtWidth(
        tester,
        const ChatBubble(isMe: false, child: Text('hola')),
        width: 1440,
        brightness: Brightness.dark,
      );
      final contenedor = tester.widget<Container>(
        find.byKey(const ValueKey('chat-bubble-surface')),
      );
      final fondoBurbuja = (contenedor.decoration as BoxDecoration).color;
      final fondoChat = AppTheme.dark.extension<AppColors>()!.surfaceContainer;

      expect(
        fondoBurbuja,
        isNot(fondoChat),
        reason:
            'chat_screen.dart:377 pinta el Scaffold con surfaceContainer; '
            'si la burbuja usa el mismo token es invisible',
      );
    });
  });
}
