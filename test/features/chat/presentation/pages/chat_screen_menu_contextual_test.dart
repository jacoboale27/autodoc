import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/features/chat/presentation/pages/chat_screen.dart';
import 'package:autodoc/features/chat/presentation/widgets/cards/audio_chat_card.dart';

import '../../../../support/chat_harness.dart';

/// Tarea 11a (C4): menú contextual de mensaje — mantener presionado ofrece
/// Copiar siempre; Borrar solo en el mensaje propio y no borrado. Editar se
/// cubre en `chat_screen_editar_mensaje_test.dart` (Tarea 11b).
///
/// 11c (responder/reenviar) queda fuera de esta ronda a propósito — no se
/// prueba ni se implementa.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  Future<FakeChatProvider> montar(
    WidgetTester tester, {
    required bool esMio,
    bool isDeleted = false,
  }) async {
    await Firebase.initializeApp();
    final chatProvider = FakeChatProvider(
      conversaciones: [fakeConversacion()],
      mensajes: [
        fakeMensaje(
          id: 'm1',
          idRemitente: esMio ? 'u1' : 'm1',
          contenido: 'hola',
          isDeleted: isDeleted,
        ),
      ],
    );
    await pumpChatWidget(
      tester,
      const ChatScreen(conversacionId: 'c1'),
      width: 375,
      user: fakeChatUser(),
      chatProvider: chatProvider,
    );
    return chatProvider;
  }

  testWidgets('mantener presionado un mensaje propio ofrece Copiar y Borrar', (
    tester,
  ) async {
    await montar(tester, esMio: true);
    await tester.longPress(find.text('hola'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('menu_mensaje_copiar')), findsOneWidget);
    expect(find.byKey(const Key('menu_mensaje_borrar')), findsOneWidget);
  });

  testWidgets('sobre un mensaje ajeno solo se ofrece Copiar', (tester) async {
    await montar(tester, esMio: false);
    await tester.longPress(find.text('hola'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('menu_mensaje_copiar')), findsOneWidget);
    expect(find.byKey(const Key('menu_mensaje_borrar')), findsNothing);
  });

  testWidgets('un mensaje propio ya borrado no ofrece Borrar de nuevo', (
    tester,
  ) async {
    final chatProvider = FakeChatProvider(
      conversaciones: [fakeConversacion()],
      mensajes: [
        fakeMensaje(
          id: 'm1',
          idRemitente: 'u1',
          // Lo que deja el borrado suave en Firestore.
          contenido: 'Este mensaje ha sido eliminado',
          isDeleted: true,
        ),
      ],
    );
    await pumpChatWidget(
      tester,
      const ChatScreen(conversacionId: 'c1'),
      width: 375,
      user: fakeChatUser(),
      chatProvider: chatProvider,
    );
    await tester.longPress(find.text('Este mensaje ha sido eliminado'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('menu_mensaje_copiar')), findsOneWidget);
    expect(find.byKey(const Key('menu_mensaje_borrar')), findsNothing);
  });

  testWidgets(
    'tocar Copiar copia el contenido al portapapeles y cierra el menu',
    (tester) async {
      final copiado = <ClipboardData?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            final args = call.arguments as Map<dynamic, dynamic>;
            copiado.add(ClipboardData(text: args['text'] as String));
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await montar(tester, esMio: true);
      await tester.longPress(find.text('hola'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('menu_mensaje_copiar')));
      await tester.pumpAndSettle();

      expect(copiado, hasLength(1));
      expect(copiado.single?.text, 'hola');
      expect(find.byKey(const Key('menu_mensaje_copiar')), findsNothing);
    },
  );

  testWidgets('tocar Borrar abre la confirmacion y borra al aceptar', (
    tester,
  ) async {
    final chatProvider = await montar(tester, esMio: true);
    await tester.longPress(find.text('hola'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('menu_mensaje_borrar')));
    await tester.pumpAndSettle();

    // El dialogo de confirmacion ya existia antes de esta tarea.
    expect(
      find.text(
        '¿Estás seguro de que quieres eliminar este mensaje para todos?',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();

    expect(chatProvider.llamadas, contains('deleteMensaje:c1:m1'));
  });

  // R10 (revision C4b): `msg.contenido` en un mensaje de audio o imagen es
  // un placeholder interno ('🎤 Nota de voz', '📷 Imagen adjunta') que la
  // burbuja ni siquiera muestra (AudioChatCard/ImagenChatCard ignoran
  // `contenido`) — ofrecer "Copiar" ahi copiaba ese placeholder, no nada
  // que el usuario hubiera visto como texto.
  testWidgets(
    'sobre un mensaje de audio no se ofrece Copiar (no hay texto visible que copiar)',
    (tester) async {
      await Firebase.initializeApp();
      final chatProvider = FakeChatProvider(
        conversaciones: [fakeConversacion()],
        mensajes: [
          fakeMensaje(
            id: 'm1',
            idRemitente: 'u1',
            contenido: '🎤 Nota de voz',
            tipo: 'audio',
            urlArchivo: 'https://example.com/audio.m4a',
          ),
        ],
      );
      await pumpChatWidget(
        tester,
        const ChatScreen(conversacionId: 'c1'),
        width: 375,
        user: fakeChatUser(),
        chatProvider: chatProvider,
      );

      await tester.longPress(find.byType(AudioChatCard));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('menu_mensaje_copiar')), findsNothing);
    },
  );

  testWidgets(
    'sobre una tarjeta de reserva no se ofrece Copiar (no es texto libre)',
    (tester) async {
      await Firebase.initializeApp();
      final chatProvider = FakeChatProvider(
        conversaciones: [fakeConversacion()],
        mensajes: [
          fakeMensaje(
            id: 'm1',
            idRemitente: 'u1',
            contenido: 'Reserva propuesta',
            tipo: 'reserva_card',
            // Sin `id_reserva`: evita la rama con `StreamBuilder` sobre
            // Firestore real de `ReservaChatCard` (no hay emulador en este
            // test), igual que el resto de la suite ejercita esta tarjeta.
          ),
        ],
      );
      await pumpChatWidget(
        tester,
        const ChatScreen(conversacionId: 'c1'),
        width: 375,
        user: fakeChatUser(),
        chatProvider: chatProvider,
      );

      await tester.longPress(find.text('Reserva de Cita'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('menu_mensaje_copiar')), findsNothing);
    },
  );

  // Consecuencia de R10: si Copiar deja de ofrecerse en un audio ajeno, ese
  // mensaje no tiene NINGUNA accion (no es propio, asi que tampoco Editar ni
  // Borrar). Abrir el sheet igualmente mostraba una franja vacia que el
  // usuario solo podia cerrar. No debe abrirse nada.
  testWidgets(
    'sobre un audio de la contraparte no se abre ningun menu (no hay acciones)',
    (tester) async {
      await Firebase.initializeApp();
      final chatProvider = FakeChatProvider(
        conversaciones: [fakeConversacion()],
        mensajes: [
          fakeMensaje(
            id: 'm1',
            idRemitente: 'm1',
            contenido: 'Nota de voz',
            tipo: 'audio',
          ),
        ],
      );
      await pumpChatWidget(
        tester,
        const ChatScreen(conversacionId: 'c1'),
        width: 375,
        user: fakeChatUser(),
        chatProvider: chatProvider,
      );

      await tester.longPress(find.byType(AudioChatCard));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byKey(const Key('menu_mensaje_copiar')), findsNothing);
      expect(find.byKey(const Key('menu_mensaje_editar')), findsNothing);
      expect(find.byKey(const Key('menu_mensaje_borrar')), findsNothing);
    },
  );
}
