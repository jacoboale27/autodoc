import 'dart:async';
import 'dart:typed_data';

import 'package:autodoc/features/chat/data/models/mensaje_model.dart';
import 'package:autodoc/features/chat/presentation/pages/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../support/chat_harness.dart';

final class _ChatPendiente extends FakeChatProvider {
  _ChatPendiente({List<MensajeModel>? mensajes})
    : super(conversaciones: [fakeConversacion()], mensajes: mensajes);

  final envioPendiente = Completer<bool>();
  final edicionPendiente = Completer<bool>();
  var envios = 0;
  var ediciones = 0;

  @override
  Future<bool> enviarMensaje({
    required String conversacionId,
    required String contenido,
    required String remitenteId,
    required String receptorId,
    required bool isMecanicoRemitente,
    String tipo = 'texto',
    Map<String, dynamic>? metadata,
    String? urlArchivo,
    int? duracionSegundos,
  }) {
    envios++;
    return envioPendiente.future;
  }

  @override
  Future<bool> editarMensaje(
    String conversacionId,
    String mensajeId,
    String nuevoContenido,
  ) {
    ediciones++;
    return edicionPendiente.future;
  }
}

XFile _imagen() => XFile.fromData(
  Uint8List.fromList(const [0x89, 0x50, 0x4e, 0x47]),
  name: 'foto.png',
  path: 'foto.png',
  mimeType: 'image/png',
);

void main() {
  Future<void> montar(
    WidgetTester tester,
    FakeChatProvider chat, {
    SelectorDeImagen? selector,
  }) => pumpChatWidget(
    tester,
    ChatScreen(conversacionId: 'c1', selectorDeImagen: selector),
    width: 400,
    user: fakeChatUser(),
    chatProvider: chat,
  );

  testWidgets(
    'doble_envio_a_chat deshabilita enviar mientras el primer mensaje sigue pendiente',
    (tester) async {
      final chat = _ChatPendiente();
      await montar(tester, chat);
      await tester.enterText(
        find.byKey(const Key('chat_input_field')),
        'mensaje unico',
      );

      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      // El compositor se limpia de forma optimista. Volver a escribir antes
      // de que termine el primer Future reproduce el doble envio real.
      await tester.enterText(
        find.byKey(const Key('chat_input_field')),
        'mensaje repetido',
      );

      final boton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.send),
      );
      expect(boton.onPressed, isNull);
      await tester.tap(find.byIcon(Icons.send));
      expect(chat.envios, 1);

      chat.envioPendiente.complete(true);
      await tester.pump();
    },
  );

  testWidgets(
    'doble_envio_a_chat ignora dos aperturas de adjunto mientras el selector sigue pendiente',
    (tester) async {
      final chat = FakeChatProvider(conversaciones: [fakeConversacion()]);
      final selectorPendiente = Completer<XFile?>();
      var selecciones = 0;
      await montar(
        tester,
        chat,
        selector: (_) {
          selecciones++;
          return selectorPendiente.future;
        },
      );

      await tester.tap(find.byIcon(Icons.camera_alt));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.camera_alt));

      expect(selecciones, 1);
      final boton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.camera_alt),
      );
      expect(boton.onPressed, isNull);

      selectorPendiente.complete(null);
      await tester.pump();
    },
  );

  testWidgets(
    'doble_envio_a_chat deshabilita Guardar mientras la primera edicion sigue pendiente',
    (tester) async {
      final chat = _ChatPendiente(
        mensajes: [fakeMensaje(id: 'm1', contenido: 'hola')],
      );
      await montar(tester, chat);
      await tester.longPress(find.text('hola'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('menu_mensaje_editar')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('campo_editar_mensaje')),
        'hola corregido',
      );

      await tester.tap(find.text('Guardar'));
      await tester.tap(find.text('Guardar'));
      await tester.pump();

      final guardar = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Guardar'),
      );
      expect(guardar.onPressed, isNull);
      expect(chat.ediciones, 1);

      chat.edicionPendiente.complete(true);
      await tester.pumpAndSettle();
    },
  );
}
