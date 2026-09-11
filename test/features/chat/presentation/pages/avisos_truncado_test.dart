import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/widgets/aviso_lista_truncada.dart';
import 'package:autodoc/features/chat/data/models/conversacion_model.dart';
import 'package:autodoc/features/chat/data/models/mensaje_model.dart';
import 'package:autodoc/features/chat/presentation/pages/chat_screen.dart';
import 'package:autodoc/features/chat/presentation/pages/conversaciones_list_screen.dart';

import '../../../../support/chat_harness.dart';

/// El recorte de la bandeja y del hilo (gaps 9.2 y 9.3) tiene que **verse**.
///
/// Acotar los streams sin decirlo convierte un hilo que falta en un hilo que
/// no existe — la misma razón por la que el tablero Kanban lleva su
/// `AvisoTableroTruncado`. Estos tests afirman sobre lo que la pantalla pinta,
/// no sobre el getter del provider: el provider ya lo cubre
/// `streams_acotados_test.dart`, y afirmar dos veces sobre la misma capa fue
/// justo el falso verde de la tanda anterior.
ConversacionModel _conv(int i) => ConversacionModel(
  id: 'c$i',
  idPropietario: 'u1',
  idMecanico: 'm1',
  nombrePropietario: 'Ana Pérez',
  nombreMecanico: 'Taller Escobar',
  ultimoMensaje: 'Le confirmo la cita.',
  ultimoMensajeTs: DateTime(2026, 8, 11).subtract(Duration(hours: i)),
);

MensajeModel _msg(int i) => MensajeModel(
  id: 'm$i',
  idRemitente: 'u1',
  contenido: 'mensaje $i',
  tipo: 'texto',
  timestamp: DateTime(2026, 8, 11).subtract(Duration(minutes: i)),
  estado: 'enviado',
);

void main() {
  testWidgets('la bandeja avisa cuando llegó al tope', (tester) async {
    await pumpChatWidget(
      tester,
      const ConversacionesListScreen(),
      width: 375,
      chatProvider: FakeChatProvider(
        conversaciones: List.generate(maxConversacionesBandeja, _conv),
      ),
      user: fakeChatUser(),
    );

    expect(find.byType(AvisoListaTruncada), findsOneWidget);
  });

  testWidgets('sin llegar al tope no hay aviso', (tester) async {
    await pumpChatWidget(
      tester,
      const ConversacionesListScreen(),
      width: 375,
      chatProvider: FakeChatProvider(conversaciones: [_conv(0)]),
      user: fakeChatUser(),
    );

    expect(find.byType(AvisoListaTruncada), findsNothing);
  });

  testWidgets('el hilo avisa cuando llegó al tope', (tester) async {
    await pumpChatWidget(
      tester,
      const ChatScreen(conversacionId: 'c0'),
      width: 375,
      chatProvider: FakeChatProvider(
        conversaciones: [_conv(0)],
        mensajes: List.generate(maxMensajesHilo, _msg),
      ),
      user: fakeChatUser(),
    );
    await tester.pump();

    // El aviso vive al final de una `ListView` invertida, o sea arriba del
    // todo: hay que desplazarse hasta él para que se construya.
    final lista = find.byType(ListView);
    for (var i = 0; i < 60; i += 1) {
      if (find.byType(AvisoListaTruncada).evaluate().isNotEmpty) break;
      await tester.drag(lista, const Offset(0, 600));
      await tester.pump();
    }
    expect(
      find.byType(AvisoListaTruncada),
      findsOneWidget,
      reason:
          'el aviso tiene que quedar del lado de los mensajes viejos, que es '
          'lo que falta; si no aparece al subir, el hilo recorta en silencio',
    );
  });
}
