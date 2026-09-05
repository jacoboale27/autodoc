// Tarea 12, C6 — previsualizar el adjunto antes de subirlo y enviarlo.
//
// El orden real hoy (antes de esta tarea) es: elegir imagen -> SUBIR a
// Storage -> enviar mensaje. Este archivo cubre que la previsualización se
// interponga ANTES de la subida: cancelar debe dejar `subirImagenChat` sin
// llamar, no solo `enviarMensaje` (ver chat_screen.dart, `_pickAndSendImage`).
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'package:autodoc/features/chat/data/models/mensaje_model.dart';
import 'package:autodoc/features/chat/presentation/pages/chat_screen.dart';
import 'package:autodoc/features/chat/presentation/widgets/adjunto_preview_sheet.dart';

import '../../../../support/chat_harness.dart';

/// PNG válido de 1x1 transparente. `Image.memory` decodifica bytes de
/// verdad (no solo los guarda), así que un `Uint8List` cualquiera hace que
/// `dart:ui` lance al resolver el codec y tumbe el test con una excepción no
/// capturada. Mismo bytes que usa `workshop_verification_screen_test.dart`
/// para el mismo problema.
final Uint8List _pngDePrueba = Uint8List.fromList(const <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, //
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, //
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, //
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, //
  0x42, 0x60, 0x82, //
]);

/// `XFile` fake: bytes en memoria, sin tocar disco/red — como el resto del
/// harness de este módulo.
XFile _xfileFake({String nombre = 'foto.jpg'}) =>
    XFile.fromData(_pngDePrueba, name: nombre, mimeType: 'image/png');

void main() {
  Future<void> pumpChat(
    WidgetTester tester,
    FakeChatProvider chat, {
    required XFile? Function(ImageSource) selectorDeImagen,
  }) async {
    await pumpChatWidget(
      tester,
      ChatScreen(
        conversacionId: 'c1',
        selectorDeImagen: (source) async => selectorDeImagen(source),
      ),
      width: 400,
      user: fakeChatUser(rol: 'Propietario'),
      chatProvider: chat,
    );
  }

  testWidgets(
    'elegir una imagen abre la previsualizacion y no sube ni envia todavia',
    (tester) async {
      final chat = FakeChatProvider(
        conversaciones: [fakeConversacion()],
        mensajes: const <MensajeModel>[],
      );
      await pumpChat(tester, chat, selectorDeImagen: (_) => _xfileFake());

      await tester.tap(find.byIcon(Icons.camera_alt));
      await tester.pumpAndSettle();

      expect(find.byType(AdjuntoPreviewSheet), findsOneWidget);
      expect(
        chat.llamadas.any((l) => l.startsWith('subirImagenChat')),
        isFalse,
        reason: 'no se sube nada hasta confirmar',
      );
      expect(
        chat.llamadas.any((l) => l.startsWith('enviarMensaje')),
        isFalse,
        reason: 'no se envia nada hasta confirmar',
      );
    },
  );

  testWidgets('cancelar la previsualizacion no sube ni envia nada', (
    tester,
  ) async {
    final chat = FakeChatProvider(
      conversaciones: [fakeConversacion()],
      mensajes: const <MensajeModel>[],
    );
    await pumpChat(tester, chat, selectorDeImagen: (_) => _xfileFake());

    await tester.tap(find.byIcon(Icons.camera_alt));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.byType(AdjuntoPreviewSheet), findsNothing);
    expect(
      chat.llamadas.any((l) => l.startsWith('subirImagenChat')),
      isFalse,
      reason: 'cancelar no debe subir el archivo a Storage',
    );
    expect(chat.llamadas.any((l) => l.startsWith('enviarMensaje')), isFalse);
  });

  testWidgets(
    'confirmar en la previsualizacion sube y envia exactamente un mensaje',
    (tester) async {
      final chat = FakeChatProvider(
        conversaciones: [fakeConversacion()],
        mensajes: const <MensajeModel>[],
      );
      await pumpChat(tester, chat, selectorDeImagen: (_) => _xfileFake());

      await tester.tap(find.byIcon(Icons.camera_alt));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Enviar'));
      await tester.pumpAndSettle();

      expect(
        chat.llamadas.where((l) => l.startsWith('subirImagenChat')),
        hasLength(1),
      );
      expect(
        chat.llamadas.where((l) => l.startsWith('enviarMensaje')),
        hasLength(1),
      );
    },
  );

  testWidgets('Cambiar vuelve a abrir el selector sin enviar', (tester) async {
    final chat = FakeChatProvider(
      conversaciones: [fakeConversacion()],
      mensajes: const <MensajeModel>[],
    );
    var llamadasAlSelector = 0;
    await pumpChat(
      tester,
      chat,
      selectorDeImagen: (_) {
        llamadasAlSelector++;
        return _xfileFake(nombre: 'foto$llamadasAlSelector.jpg');
      },
    );

    await tester.tap(find.byIcon(Icons.camera_alt));
    await tester.pumpAndSettle();
    expect(llamadasAlSelector, 1);

    await tester.tap(find.text('Cambiar'));
    await tester.pumpAndSettle();

    // Se reabrió el selector (segunda llamada) y la previsualización sigue
    // en pantalla con el nuevo archivo, pero nada se envió todavía.
    expect(llamadasAlSelector, 2);
    expect(find.byType(AdjuntoPreviewSheet), findsOneWidget);
    expect(chat.llamadas.any((l) => l.startsWith('enviarMensaje')), isFalse);
    expect(chat.llamadas.any((l) => l.startsWith('subirImagenChat')), isFalse);
  });
}
