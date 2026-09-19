// Observaciones del 2026-09-18 (chat): «en el mensaje aparezcan los 3
// puntitos y que despliegue opciones de borrar, editar, copiar, responder,
// reenviar». Copiar/editar/borrar existían desde C4 (solo con mantener
// presionado); faltaban los tres puntos, responder y reenviar.
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/features/chat/data/models/mensaje_model.dart';
import 'package:autodoc/features/chat/presentation/pages/chat_screen.dart';

import '../../../../support/chat_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  Future<FakeChatProvider> montar(
    WidgetTester tester, {
    List<MensajeModel>? mensajes,
    bool conOtraConversacion = true,
  }) async {
    await Firebase.initializeApp();
    final chat = FakeChatProvider(
      conversaciones: [
        fakeConversacion(),
        if (conOtraConversacion)
          fakeConversacion(
            id: 'c2',
            idMecanico: 'm2',
            nombreMecanico: 'Taller Dos',
          ),
      ],
      mensajes:
          mensajes ??
          [fakeMensaje(id: 'm1', idRemitente: 'm1', contenido: 'hola')],
    );
    await pumpChatWidget(
      tester,
      const ChatScreen(conversacionId: 'c1'),
      width: 375,
      user: fakeChatUser(),
      chatProvider: chat,
    );
    return chat;
  }

  testWidgets(
    'cada mensaje tiene sus tres puntos, que abren el menú completo',
    (tester) async {
      await montar(
        tester,
        mensajes: [fakeMensaje(id: 'm1', idRemitente: 'u1', contenido: 'mío')],
      );

      await tester.tap(find.byKey(const Key('mensaje_opciones')));
      await tester.pumpAndSettle();

      for (final accion in [
        'menu_mensaje_responder',
        'menu_mensaje_reenviar',
        'menu_mensaje_copiar',
        'menu_mensaje_editar',
        'menu_mensaje_borrar',
      ]) {
        expect(find.byKey(Key(accion)), findsOneWidget, reason: accion);
      }
    },
  );

  testWidgets('responder: la barra aparece y el envío lleva la cita', (
    tester,
  ) async {
    final chat = await montar(tester);

    await tester.tap(find.byKey(const Key('mensaje_opciones')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('menu_mensaje_responder')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('barra_respondiendo')), findsOneWidget);
    expect(find.textContaining('Respondiendo a'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('chat_input_field')), 'sí');
    await tester.tap(find.byTooltip('Enviar'));
    await tester.pumpAndSettle();

    expect(chat.ultimaRespuestaA, isNotNull);
    expect(chat.ultimaRespuestaA!['id'], 'm1');
    expect(chat.ultimaRespuestaA!['contenido'], 'hola');
    expect(
      find.byKey(const Key('barra_respondiendo')),
      findsNothing,
      reason: 'enviada la respuesta, la barra se va',
    );
  });

  testWidgets('cancelar la respuesta envía un mensaje normal', (tester) async {
    final chat = await montar(tester);

    await tester.tap(find.byKey(const Key('mensaje_opciones')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('menu_mensaje_responder')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cancelar_respuesta')));
    await tester.pump();

    await tester.enterText(find.byKey(const Key('chat_input_field')), 'otro');
    await tester.tap(find.byTooltip('Enviar'));
    await tester.pumpAndSettle();

    expect(chat.ultimaRespuestaA, isNull);
  });

  testWidgets('una respuesta muestra la cita del mensaje original', (
    tester,
  ) async {
    await montar(
      tester,
      mensajes: [
        MensajeModel(
          id: 'm2',
          idRemitente: 'u1',
          contenido: 'claro que sí',
          timestamp: DateTime(2026, 9, 18, 10),
          respuestaA: const {
            'id': 'm1',
            'id_remitente': 'm1',
            'tipo': 'texto',
            'contenido': '¿Mañana a las 9?',
          },
        ),
      ],
    );

    expect(find.text('¿Mañana a las 9?'), findsOneWidget);
    expect(find.text('claro que sí'), findsOneWidget);
  });

  testWidgets('reenviar: se elige otra conversación y se envía marcado', (
    tester,
  ) async {
    final chat = await montar(tester);

    await tester.tap(find.byKey(const Key('mensaje_opciones')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('menu_mensaje_reenviar')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('reenviar_a_c1')),
      findsNothing,
      reason: 'no se reenvía a la misma conversación',
    );
    await tester.tap(find.byKey(const Key('reenviar_a_c2')));
    await tester.pumpAndSettle();

    expect(chat.llamadas, contains('enviarMensaje:c2:hola'));
    expect(chat.ultimoReenviado, isTrue);
    expect(chat.ultimoTipo, 'texto');
  });

  testWidgets('una cotización no se puede reenviar', (tester) async {
    await montar(
      tester,
      mensajes: [
        fakeMensaje(
          id: 'm1',
          idRemitente: 'm1',
          contenido: 'Cotización',
          tipo: 'cotizacion_card',
          metadata: const {},
        ),
      ],
    );

    await tester.tap(find.byKey(const Key('mensaje_opciones')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('menu_mensaje_responder')), findsOneWidget);
    expect(find.byKey(const Key('menu_mensaje_reenviar')), findsNothing);
  });

  test(
    'el resumen de una respuesta recorta textos largos y nombra lo demás',
    () {
      final largo = 'a' * 300;
      final r1 = resumenParaResponder(
        MensajeModel(
          id: 'x',
          idRemitente: 'u1',
          contenido: largo,
          timestamp: DateTime(2026),
        ),
      );
      expect((r1['contenido'] as String).length, lessThan(130));

      final r2 = resumenParaResponder(
        MensajeModel(
          id: 'y',
          idRemitente: 'u1',
          contenido: '📷 Imagen adjunta',
          tipo: 'imagen',
          timestamp: DateTime(2026),
        ),
      );
      expect(r2['contenido'], '📷 Foto');
    },
  );
}
