import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/features/chat/presentation/widgets/chat_bubble.dart';
import 'package:autodoc/features/chat/presentation/widgets/cards/reserva_chat_card.dart';
import '../../../../../support/chat_harness.dart';

/// `id_reserva` puede llegar como CADENA VACIA, no solo como `null`.
///
/// `ReservaProvider.solicitarReserva` devuelve `''` cuando la escritura de la
/// reserva falla (reserva_provider.dart:48), y `chat_screen.dart:353` no
/// comprueba ese valor: manda el mensaje `reserva_card` igual, con
/// `id_reserva: ''` en la metadata. El mensaje queda PERSISTIDO, asi que lo
/// que se rompa aqui se rompe para los dos participantes cada vez que abran
/// el hilo, para siempre.
///
/// Las tres guardas de la tarjeta miran `== null`, y `''` no es null.
void main() {
  testWidgets('una reserva con id vacio no revienta la tarjeta', (
    tester,
  ) async {
    await pumpChatWidget(
      tester,
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ChatBubble(
          isMe: true,
          child: ReservaChatCard(
            metadata: const {
              'id_reserva': '',
              'estado': 'pendiente',
              'fecha': '2026-09-10T10:00:00.000',
              'hora': '10:00',
            },
            isMe: true,
            mensajeId: 'm1',
            conversacionId: 'c1',
            firestore: FakeFirebaseFirestore(),
          ),
        ),
      ),
      width: 375,
    );
    await tester.pumpAndSettle();

    expect(
      tester.takeException(),
      isNull,
      reason:
          'Un id vacio llega a collection("reservas").doc(""), que no es una '
          'ruta valida. El hilo de chat entero deja de pintarse.',
    );
  });

  testWidgets('con id vacio, "Ver detalle" queda deshabilitado', (
    tester,
  ) async {
    await pumpChatWidget(
      tester,
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ChatBubble(
          isMe: true,
          child: ReservaChatCard(
            metadata: const {
              'id_reserva': '',
              'estado': 'pendiente',
              'fecha': '2026-09-10T10:00:00.000',
              'hora': '10:00',
            },
            isMe: true,
            mensajeId: 'm1',
            conversacionId: 'c1',
            firestore: FakeFirebaseFirestore(),
          ),
        ),
      ),
      width: 375,
    );
    await tester.pumpAndSettle();
    tester.takeException();

    final boton = tester
        .widgetList<AppButton>(find.byType(AppButton))
        .where((b) => b.type == AppButtonType.text);
    expect(boton, isNotEmpty, reason: 'No se encontro el boton Ver detalle.');
    expect(
      boton.first.onPressed,
      isNull,
      reason:
          'Con id vacio el boton navega a /reserva_detail/ sin id: una ruta '
          'malformada. Debe quedar inerte, igual que con id nulo.',
    );
  });
}
