import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/features/chat/presentation/widgets/chat_bubble.dart';
import 'package:autodoc/features/chat/presentation/widgets/cards/vehiculo_chat_card.dart';
import '../../../../../support/chat_harness.dart';
import '../../../../../support/responsive_harness.dart';

const _meta = {
  'marca': 'Toyota',
  'modelo': 'Hilux 4x4 Doble Cabina',
  'anio': 2019,
  'placa': 'ABC-1234',
};

Widget _enBurbuja({bool isMe = true}) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16),
  child: Align(
    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
    child: ChatBubble(
      isMe: isMe,
      child: VehiculoChatCard(metadata: _meta, isMe: isMe),
    ),
  ),
);

void main() {
  testWidgets('no desborda en ningún ancho auditado, en ambos temas', (
    tester,
  ) async {
    for (final width in kAuditWidths) {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        await pumpChatWidget(
          tester,
          _enBurbuja(),
          width: width,
          brightness: brightness,
        );
        expectNoOverflow(tester);
      }
    }
  });

  testWidgets('la placa no se trunca cuando el modelo es largo', (
    tester,
  ) async {
    // El Row de año + placa es `spaceBetween` sin hijos flexibles: con un
    // modelo largo a 320 px, uno de los dos desaparecía.
    await pumpChatWidget(tester, _enBurbuja(), width: 320);
    expect(find.text('ABC-1234'), findsOneWidget);
    expectNoOverflow(tester);
  });

  testWidgets('anuncia el vehículo al lector de pantalla', (tester) async {
    await pumpChatWidget(tester, _enBurbuja(), width: 375);
    expect(
      find.bySemanticsLabel(
        'Vehículo compartido: Toyota Hilux 4x4 Doble '
        'Cabina, año 2019, placa ABC-1234',
      ),
      findsOneWidget,
    );
  });

  testWidgets('metadata incompleta no rompe la tarjeta', (tester) async {
    // `metadata` es un Map<String, dynamic> que viene de Firestore: puede
    // llegar sin claves si el mensaje se creó con una versión anterior.
    await pumpChatWidget(
      tester,
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: ChatBubble(
          isMe: true,
          child: VehiculoChatCard(metadata: {}, isMe: true),
        ),
      ),
      width: 375,
    );
    expect(tester.takeException(), isNull);
  });
}
