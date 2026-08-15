import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/widgets/app_status_badge.dart';
import 'package:autodoc/features/chat/presentation/widgets/chat_bubble.dart';
import 'package:autodoc/features/chat/presentation/widgets/chat_card_shell.dart';
import '../../../../support/responsive_harness.dart';
import '../../../../support/contrast.dart';

Widget _shellEnBurbuja({required bool isMe, String? titulo}) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16),
  child: Align(
    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
    child: ChatBubble(
      isMe: isMe,
      child: ChatCardShell(
        icon: Icons.event,
        title: titulo ?? 'Reserva de Cita',
        trailing: const AppStatusBadge(
          text: 'Cotización Enviada',
          type: AppStatusType.info,
        ),
        child: const Text('contenido'),
      ),
    ),
  ),
);

void main() {
  testWidgets('la cabecera no desborda con título y badge largos en 320 px', (
    tester,
  ) async {
    await pumpAtWidth(
      tester,
      _shellEnBurbuja(
        isMe: false,
        titulo: 'Cotización de Servicio de Mantenimiento Preventivo',
      ),
      width: 320,
    );
    expectNoOverflow(tester);
  });

  testWidgets('no desborda en ningún ancho auditado, propia y ajena', (
    tester,
  ) async {
    for (final width in kAuditWidths) {
      for (final isMe in [true, false]) {
        await pumpAtWidth(tester, _shellEnBurbuja(isMe: isMe), width: width);
        expectNoOverflow(tester);
      }
    }
  });

  testWidgets(
    'el título es legible sobre la cabecera en claro, sea propia o no',
    (tester) async {
      // Ésta es la regresión de §0.1(b): la cabecera pintaba `Colors.white`
      // sobre `Colors.black12` compuesto sobre blanco (#E0E0E0) → 1,32:1.
      for (final isMe in [true, false]) {
        await pumpAtWidth(
          tester,
          _shellEnBurbuja(isMe: isMe),
          width: 375,
          brightness: Brightness.light,
        );
        final texto = tester.widget<Text>(find.text('Reserva de Cita'));
        final colorTexto = texto.style!.color!;
        final context = tester.element(find.byType(ChatCardShell));
        final colors = context.appColors;
        expect(
          contrastRatio(colorTexto, colors.surface),
          greaterThanOrEqualTo(4.5),
          reason:
              'El título de la tarjeta debe cumplir AA sobre su propia '
              'superficie, independientemente de isMe (isMe=$isMe).',
        );
      }
    },
  );

  testWidgets('el color del contenido no cambia con isMe', (tester) async {
    Color colorDelTitulo(WidgetTester t) =>
        t.widget<Text>(find.text('Reserva de Cita')).style!.color!;

    await pumpAtWidth(tester, _shellEnBurbuja(isMe: false), width: 375);
    final ajeno = colorDelTitulo(tester);
    await pumpAtWidth(tester, _shellEnBurbuja(isMe: true), width: 375);
    final propio = colorDelTitulo(tester);

    expect(
      propio,
      ajeno,
      reason: 'Regla de la fase: isMe decide burbuja, nunca contenido.',
    );
  });

  testWidgets('crece con el espacio disponible en vez de quedarse fija', (
    tester,
  ) async {
    await pumpAtWidth(tester, _shellEnBurbuja(isMe: false), width: 375);
    final estrecha = tester.getSize(find.byType(ChatCardShell)).width;
    await pumpAtWidth(tester, _shellEnBurbuja(isMe: false), width: 768);
    final ancha = tester.getSize(find.byType(ChatCardShell)).width;
    expect(
      ancha,
      greaterThan(estrecha),
      reason: 'Las tarjetas tenían ancho fijo (260/280/300) y no crecían.',
    );
  });
}
