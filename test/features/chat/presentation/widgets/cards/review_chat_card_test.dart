// test/features/chat/presentation/widgets/cards/review_chat_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/features/chat/presentation/widgets/chat_bubble.dart';
import 'package:autodoc/features/chat/presentation/widgets/chat_card_shell.dart';
import 'package:autodoc/features/chat/presentation/widgets/cards/review_chat_card.dart';
import '../../../../../support/chat_harness.dart';
import '../../../../../support/contrast.dart';
import '../../../../../support/responsive_harness.dart';

Widget _card({required bool isMe, String estado = 'pendiente'}) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16),
  child: Align(
    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
    child: ChatBubble(
      isMe: isMe,
      child: ReviewChatCard(
        metadata: {'estado': estado, 'tallerNombre': 'Taller Escobar'},
        isMe: isMe,
        tallerId: 't1',
        mensajeId: 'm1',
        conversacionId: 'c1',
      ),
    ),
  ),
);

void main() {
  testWidgets(
    'el texto es legible cuando el mensaje es propio y el tema claro',
    (tester) async {
      // Regresión de §0.1(b): con isMe=true el cuerpo se pintaba Colors.white
      // sobre una tarjeta Colors.white → 1,00:1, invisible.
      await pumpChatWidget(tester, _card(isMe: true), width: 375);
      final context = tester.element(find.byType(ChatCardShell));
      final colors = context.appColors;
      final cuerpo = tester.widget<Text>(
        find.textContaining('Por favor califica'),
      );
      final color =
          cuerpo.style?.color ??
          DefaultTextStyle.of(
            tester.element(find.textContaining('Por favor califica')),
          ).style.color!;
      expect(contrastRatio(color, colors.surface), greaterThanOrEqualTo(4.5));
    },
  );

  testWidgets(
    'el aviso de reseña enviada usa el token de éxito, no Colors.green',
    (tester) async {
      await pumpChatWidget(
        tester,
        _card(isMe: false, estado: 'completada'),
        width: 375,
      );
      final context = tester.element(find.byType(ChatCardShell));
      final colors = context.appColors;
      final icono = tester.widget<Icon>(find.byIcon(Icons.check_circle));
      expect(icono.color, colors.success);
      final texto = tester.widget<Text>(find.text('¡Gracias por tu reseña!'));
      expect(
        contrastRatio(texto.style!.color!, colors.surface),
        greaterThanOrEqualTo(4.5),
        reason:
            'lightSuccess (#48BB78) sobre lightSurface da 2,25:1: el color '
            'no puede ser quien porte el mensaje en tema claro.',
      );
    },
  );

  testWidgets('usa AppButton y ChatCardShell', (tester) async {
    await pumpChatWidget(tester, _card(isMe: false), width: 375);
    expect(find.byType(ChatCardShell), findsOneWidget);
    expect(find.byType(AppButton), findsOneWidget);
    expect(find.byType(ElevatedButton), findsNothing);
  });

  testWidgets('no desborda en ningún ancho auditado, en ambos temas', (
    tester,
  ) async {
    for (final width in kAuditWidths) {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        await pumpChatWidget(
          tester,
          _card(isMe: false),
          width: width,
          brightness: brightness,
        );
        expectNoOverflow(tester);
      }
    }
  });

  testWidgets('crece con el ancho disponible', (tester) async {
    await pumpChatWidget(tester, _card(isMe: false), width: 375);
    final estrecha = tester.getSize(find.byType(ChatCardShell)).width;
    await pumpChatWidget(tester, _card(isMe: false), width: 768);
    expect(
      tester.getSize(find.byType(ChatCardShell)).width,
      greaterThan(estrecha),
      reason: 'La tarjeta tenía width: 280 fijo.',
    );
  });
}
