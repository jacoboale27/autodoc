import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/features/chat/presentation/widgets/chat_bubble.dart';
import 'package:autodoc/features/chat/presentation/widgets/cards/reserva_chat_card.dart';
import '../../../../../support/chat_harness.dart';

/// Mismo patrón que `cotizacion_chat_card_test.dart`: `ReservaChatCard` ahora
/// lee `reservas/{id}` vía `StreamBuilder`, que en un widget test sin
/// `Firebase.initializeApp()` lanzaría `FirebaseException('[core/no-app]')`
/// si no se inyecta un `FakeFirebaseFirestore` explícito.
Widget _card({
  required Map<String, dynamic> metadata,
  required bool isMe,
  FirebaseFirestore? firestore,
}) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16),
  child: ChatBubble(
    isMe: isMe,
    child: ReservaChatCard(
      metadata: metadata,
      isMe: isMe,
      mensajeId: 'm1',
      conversacionId: 'c1',
      firestore: firestore,
    ),
  ),
);

void main() {
  testWidgets(
    'la tarjeta refleja el estado del documento de reserva, no el del mensaje',
    (tester) async {
      // El mensaje quedó congelado en 'pendiente' cuando se envió. La
      // reserva ya es 'confirmada'. Esta discrepancia ES el bug A2 — no
      // falta un listener, sobra una copia desnormalizada.
      final fake = FakeFirebaseFirestore();
      await fake.collection('reservas').doc('r1').set({
        'estado': 'confirmada',
        'id_proponente': 'cli1',
      });

      await pumpChatWidget(
        tester,
        _card(
          metadata: const {
            'id_reserva': 'r1',
            'estado': 'pendiente',
            'fecha': '2026-09-10T10:00:00.000',
            'hora': '10:00',
          },
          isMe: false,
          firestore: fake,
        ),
        width: 375,
      );
      await tester.pumpAndSettle();

      // AppStatusBadge pinta su `text` en mayúsculas (`text.toUpperCase()`
      // en app_status_badge.dart), así que el texto real en pantalla es
      // 'CONFIRMADA'/'PENDIENTE', no 'Confirmada'/'Pendiente' como decía
      // el snippet del brief.
      expect(find.text('CONFIRMADA'), findsOneWidget);
      expect(find.text('PENDIENTE'), findsNothing);
    },
  );

  testWidgets('sin id_reserva cae al estado del mensaje sin romperse', (
    tester,
  ) async {
    // Los mensajes de reserva ya existentes en producción pueden no traer
    // id_reserva.
    await pumpChatWidget(
      tester,
      _card(
        metadata: const {
          'estado': 'pendiente',
          'fecha': '2026-09-10T10:00:00.000',
        },
        isMe: false,
      ),
      width: 375,
    );
    await tester.pumpAndSettle();
    expect(find.text('PENDIENTE'), findsOneWidget);
  });

  testWidgets(
    'usa el id_proponente real del documento, no isMe, para la etiqueta '
    'de quién propuso la fecha',
    (tester) async {
      // R4: el mensaje lo envió el mecánico (isMe: true desde su
      // perspectiva), pero tras una reprogramación quien propuso la fecha
      // vigente es la contraparte (cli1, distinta del mecánico m1). Si el
      // widget usara `isMe` en vez del `id_proponente` real del documento,
      // mostraría "Propusiste esta fecha" — exactamente la mentira que R4
      // identificó.
      final fake = FakeFirebaseFirestore();
      await fake.collection('reservas').doc('r1').set({
        'estado': 'pendiente',
        'id_proponente': 'cli1',
      });

      await pumpChatWidget(
        tester,
        _card(
          metadata: const {
            'id_reserva': 'r1',
            'estado': 'pendiente',
            'fecha': '2026-09-10T10:00:00.000',
            'hora': '10:00',
          },
          isMe: true,
          firestore: fake,
        ),
        width: 375,
        user: fakeChatUser(id: 'm1', rol: 'Mecanico'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Te propusieron esta fecha'), findsOneWidget);
      expect(
        find.text('Propusiste esta fecha — espera respuesta'),
        findsNothing,
      );
    },
  );
}
