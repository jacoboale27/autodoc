import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/features/chat/presentation/widgets/cards/cotizacion_chat_card.dart';
import 'package:autodoc/features/chat/presentation/widgets/cards/reserva_chat_card.dart';
import 'support/chat_harness.dart';

class _Chat extends FakeChatProvider {
  final pending = Completer<void>();
  int calls = 0;
  @override
  Future<void> actualizarEstadoCotizacion(String id, String estado) {
    calls++;
    return pending.future;
  }

  @override
  Future<void> actualizarMetadatosMensaje(
    String conversacionId,
    String mensajeId,
    Map<String, dynamic> metadata,
  ) {
    calls++;
    return pending.future;
  }
}

class _Reservas extends FakeReservaProvider {
  @override
  Future<void> cambiarEstadoReserva(
    String id,
    String estado, {
    DateTime? fechaConfirmada,
  }) async {}
}

void main() {
  for (final cotizacion in [true, false]) {
    for (final action in ['Aceptar', 'Rechazar']) {
      testWidgets('grupo ${cotizacion ? 5 : 6}: $action escribe una vez', (
        tester,
      ) async {
        final firestore = FakeFirebaseFirestore();
        final chat = _Chat();
        await firestore
            .collection(cotizacion ? 'cotizaciones' : 'reservas')
            .doc('r1')
            .set({
              'id_propietario': 'u1',
              'id_mecanico': 'm1',
              'id_proponente': 'm1',
              'id_conversacion': 'c1',
              'id_vehiculo': 'v1',
              'id_taller': 'm1',
              'estado': 'pendiente',
              'items': <Map<String, dynamic>>[],
              'fecha': Timestamp.now(),
              'fecha_creacion': Timestamp.now(),
              'fecha_hora_propuesta': Timestamp.fromDate(
                DateTime.now().add(const Duration(days: 7)),
              ),
              'tipo_servicio': 'Frenos',
            });
        final metadata = <String, dynamic>{
          'id_reserva': 'r1',
          'id_cotizacion': 'r1',
          'estado': 'pendiente',
          'fecha': DateTime.now()
              .add(const Duration(days: 7))
              .toIso8601String(),
          'hora': '10:00',
          'tipo_servicio': 'Frenos',
        };
        final Widget card = cotizacion
            ? CotizacionChatCard(
                metadata: metadata,
                isMe: false,
                mensajeId: 'm1',
                conversacionId: 'c1',
                firestore: firestore,
              )
            : ReservaChatCard(
                metadata: metadata,
                isMe: false,
                mensajeId: 'm1',
                conversacionId: 'c1',
                firestore: firestore,
              );
        await pumpChatWidget(
          tester,
          card,
          width: 800,
          user: fakeChatUser(),
          chatProvider: chat,
          reservaProvider: _Reservas(),
        );
        await tester.pumpAndSettle();
        final button = find.text(action);
        await tester.tap(button);
        await tester.tap(button);
        expect(chat.calls, 1);
        chat.pending.complete();
        await tester.pumpAndSettle();
        await tester.tap(button);
        expect(chat.calls, 2);
        await tester.pumpAndSettle();
      });
    }
  }
}
