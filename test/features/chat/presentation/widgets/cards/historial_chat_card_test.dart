import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/features/chat/data/models/mensaje_model.dart';
import 'package:autodoc/features/chat/presentation/widgets/chat_bubble.dart';
import 'package:autodoc/features/chat/presentation/widgets/chat_card_shell.dart';
import 'package:autodoc/features/chat/presentation/widgets/cards/historial_chat_card.dart';
import '../../../../../support/chat_harness.dart';
import '../../../../../support/responsive_harness.dart';

MensajeModel _mensaje() => MensajeModel(
  id: 'm1',
  idRemitente: 'u1',
  contenido: 'veh-123',
  tipo: 'historial',
  timestamp: DateTime(2026, 8, 1),
  estado: 'enviado',
);

Widget _enBurbuja({required bool isMe}) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16),
  child: Align(
    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
    child: ChatBubble(
      isMe: isMe,
      child: HistorialChatCard(mensaje: _mensaje()),
    ),
  ),
);

void main() {
  testWidgets('no dibuja una segunda burbuja dentro de la burbuja', (
    tester,
  ) async {
    await pumpChatWidget(tester, _enBurbuja(isMe: true), width: 375);
    // El defecto original: la tarjeta devolvía su propio Align + Container
    // con `color: isMe ? colors.primary : ...`, dentro de la burbuja que ya
    // tiene ese mismo color. Ahora la superficie la pone ChatCardShell.
    expect(find.byType(ChatBubble), findsOneWidget);
    expect(find.byType(ChatCardShell), findsOneWidget);
    // Buscamos específicamente un Align entre HistorialChatCard y
    // ChatCardShell (el defecto original), no cualquier Align en el
    // subárbol completo: AppButton usa internamente un Align propio (vía
    // Container(alignment: ...)) para centrar su contenido, que es una
    // decisión de implementación legítima y no la burbuja estirada que este
    // test protege. `find.ancestor` sin acotar recorrería también los
    // ancestros por encima de HistorialChatCard (incluido el Align del
    // propio harness de test), así que se camina manualmente el árbol de
    // elementos entre ambos límites.
    final shellElement = tester.element(find.byType(ChatCardShell));
    final historialElement = tester.element(find.byType(HistorialChatCard));
    var foundAlign = false;
    shellElement.visitAncestorElements((element) {
      if (element == historialElement) return false;
      if (element.widget is Align) foundAlign = true;
      return true;
    });
    expect(
      foundAlign,
      isFalse,
      reason:
          'Un Align sin widthFactor envolviendo la tarjeta la estiraba a '
          'todo el ancho de la lista, independientemente del contenido.',
    );
  });

  testWidgets('la burbuja se ajusta al contenido, no al ancho de la lista', (
    tester,
  ) async {
    await pumpChatWidget(tester, _enBurbuja(isMe: true), width: 1024);
    final anchoBurbuja = tester.getSize(find.byType(ChatBubble)).width;
    // 1024 − 32 de padding = 992 disponibles. Antes, el Align lo ocupaba todo.
    expect(
      anchoBurbuja,
      lessThan(992 * 0.9),
      reason: 'La burbuja de historial ocupaba todo el ancho disponible.',
    );
  });

  testWidgets('no desborda en ningún ancho auditado', (tester) async {
    for (final width in kAuditWidths) {
      await pumpChatWidget(tester, _enBurbuja(isMe: false), width: width);
      expectNoOverflow(tester);
    }
  });

  testWidgets('el botón de ver historial navega a la ruta del vehículo', (
    tester,
  ) async {
    // Protege el único comportamiento de negocio de esta tarjeta: el id del
    // vehículo viaja en `mensaje.contenido`, no en metadata.
    await pumpChatWidget(tester, _enBurbuja(isMe: false), width: 375);
    expect(find.text('Ver Historial Completo'), findsOneWidget);
  });
}
