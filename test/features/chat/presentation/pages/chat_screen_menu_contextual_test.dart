import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/features/chat/presentation/pages/chat_screen.dart';

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
}
