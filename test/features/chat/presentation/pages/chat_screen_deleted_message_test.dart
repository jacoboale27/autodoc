import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/features/chat/presentation/pages/chat_screen.dart';
import 'package:autodoc/features/chat/presentation/widgets/chat_bubble.dart';
import 'package:autodoc/features/chat/presentation/widgets/cards/audio_chat_card.dart';
import 'package:autodoc/features/chat/presentation/widgets/cards/imagen_chat_card.dart';

import '../../../../support/chat_harness.dart';

/// Regresion de "le doy a borrar mensaje y solo se pone en gris; no se si lo
/// borra".
///
/// Si lo borraba: `ChatRepository.deleteMensaje` es un borrado suave que marca
/// `is_deleted` y sustituye `contenido`. Lo que no hacia era tocar `tipo` ni
/// `url_archivo`, y `_buildMessageContent` decidia solo por `tipo` — asi que
/// una imagen borrada seguia pintando la foto y un audio borrado seguia
/// ofreciendo el reproductor. Lo unico que cambiaba era el fondo de la
/// burbuja. El contenido "borrado" seguia entero delante del usuario.
const _textoBorrado = 'Este mensaje ha sido eliminado';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  Future<void> montar(
    WidgetTester tester, {
    required String tipo,
    String remitente = 'u1',
    String? urlArchivo,
  }) async {
    await Firebase.initializeApp();
    await pumpChatWidget(
      tester,
      const ChatScreen(conversacionId: 'c1'),
      width: 375,
      user: fakeChatUser(),
      chatProvider: FakeChatProvider(
        conversaciones: [fakeConversacion()],
        mensajes: [
          fakeMensaje(
            id: 'm1',
            idRemitente: remitente,
            // Lo que deja el borrado suave en Firestore.
            contenido: _textoBorrado,
            tipo: tipo,
            urlArchivo: urlArchivo,
            isDeleted: true,
            duracionSegundos: tipo == 'audio' ? 5 : null,
          ),
        ],
      ),
    );
  }

  testWidgets('una imagen borrada deja de mostrar la imagen', (tester) async {
    await montar(
      tester,
      tipo: 'imagen',
      urlArchivo: 'https://example.com/foto.jpg',
    );

    expect(
      find.byType(ImagenChatCard),
      findsNothing,
      reason: 'la foto sigue a la vista despues de borrar el mensaje',
    );
    expect(find.text(_textoBorrado), findsOneWidget);
  });

  testWidgets('un audio borrado deja de mostrar el reproductor', (
    tester,
  ) async {
    await montar(
      tester,
      tipo: 'audio',
      urlArchivo: 'https://example.com/nota.m4a',
    );

    expect(
      find.byType(AudioChatCard),
      findsNothing,
      reason: 'el audio se sigue pudiendo reproducir despues de borrarlo',
    );
    expect(find.text(_textoBorrado), findsOneWidget);
  });

  testWidgets('un texto borrado muestra el aviso', (tester) async {
    await montar(tester, tipo: 'texto');
    expect(find.text(_textoBorrado), findsOneWidget);
  });

  testWidgets('el mensaje borrado del OTRO tambien se ve apagado', (
    tester,
  ) async {
    // Antes la atenuacion solo se aplicaba a `isMe`: al receptor le llegaba un
    // "Este mensaje ha sido eliminado" con el mismo aspecto que cualquier otro
    // mensaje suyo.
    await montar(tester, tipo: 'texto', remitente: 'm1');

    final burbuja = tester.widget<ChatBubble>(find.byType(ChatBubble));
    expect(burbuja.isMe, isFalse);
    expect(burbuja.isDeleted, isTrue);
  });
}
