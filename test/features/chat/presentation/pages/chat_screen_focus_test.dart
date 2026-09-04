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
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  testWidgets('el campo de texto conserva el foco despues de enviar', (
    tester,
  ) async {
    await Firebase.initializeApp();
    await pumpChatWidget(
      tester,
      const ChatScreen(conversacionId: 'c1'),
      width: 375,
      chatProvider: FakeChatProvider(conversaciones: [fakeConversacion()]),
      user: fakeChatUser(),
    );

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
}
