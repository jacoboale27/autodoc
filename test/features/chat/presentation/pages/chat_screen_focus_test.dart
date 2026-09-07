import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/features/chat/presentation/pages/chat_screen.dart';

import '../../../../support/chat_harness.dart';

/// Regresion de C5: tras enviar un mensaje, `_controller.clear()` limpiaba el
/// texto pero no habia ningun `FocusNode` en el compositor, asi que el
/// TextField perdia el foco (y en movil se cerraba el teclado). Habia que
/// tocar la barra de nuevo entre mensaje y mensaje.
///
/// Y regresion de la propia correccion: pedir el foco de forma sincrona dejaba
/// el campo *con aspecto* de enfocado pero con la conexion de edicion cerrada,
/// asi que a partir del segundo mensaje no se enviaba nada. `hasFocus` no
/// distingue los dos estados — `testTextInput.hasAnyClients` si, porque es
/// exactamente la conexion que `TextInputAction.send` derriba. Por eso los
/// tests de abajo afirman las dos cosas, y ademas envian tres mensajes
/// seguidos (Paso 5 de la Tarea 1), que es donde el fallo se veia.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  Future<FakeChatProvider> montarChat(WidgetTester tester) async {
    final chatProvider = FakeChatProvider(conversaciones: [fakeConversacion()]);
    await pumpChatWidget(
      tester,
      const ChatScreen(conversacionId: 'c1'),
      width: 375,
      chatProvider: chatProvider,
      user: fakeChatUser(),
    );
    return chatProvider;
  }

  testWidgets('el campo de texto conserva el foco despues de enviar', (
    tester,
  ) async {
    await Firebase.initializeApp();
    await montarChat(tester);

    final campo = find.byKey(const Key('chat_input_field'));

    await tester.tap(campo);
    await tester.pumpAndSettle();
    await tester.enterText(campo, 'hola');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    final widget = tester.widget<TextField>(campo);
    expect(widget.controller!.text, isEmpty, reason: 'el texto se limpia');
    expect(
      widget.focusNode!.hasFocus,
      isTrue,
      reason: 'pero el foco se conserva',
    );
  });

  testWidgets(
    'enviar reengancha el compositor con una transicion real de foco',
    (tester) async {
      await Firebase.initializeApp();
      await montarChat(tester);

      final campo = find.byKey(const Key('chat_input_field'));
      await tester.tap(campo);
      await tester.pumpAndSettle();

      final node = tester.widget<TextField>(campo).focusNode!;
      final transiciones = <bool>[];
      node.addListener(() => transiciones.add(node.hasFocus));

      await tester.enterText(campo, 'hola');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();

      expect(
        transiciones,
        containsAllInOrder([false, true]),
        reason:
            'el nodo tiene que soltar el foco y volver a pedirlo: es esa '
            'transicion, y no un requestFocus() sincrono sobre un nodo que '
            'nunca dejo de ser el foco primario, la que hace que EditableText '
            'reabra la conexion de edicion cerrada por TextInputAction.send',
      );
    },
  );

  testWidgets('tres mensajes seguidos con la accion de enviar salen los tres', (
    tester,
  ) async {
    await Firebase.initializeApp();
    final chatProvider = await montarChat(tester);

    final campo = find.byKey(const Key('chat_input_field'));
    await tester.tap(campo);
    await tester.pumpAndSettle();

    for (final texto in ['uno', 'dos', 'tres']) {
      await tester.enterText(campo, texto);
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();
    }

    expect(
      chatProvider.llamadas.where((l) => l.startsWith('enviarMensaje:')),
      containsAllInOrder([
        'enviarMensaje:c1:uno',
        'enviarMensaje:c1:dos',
        'enviarMensaje:c1:tres',
      ]),
    );
  });
}
