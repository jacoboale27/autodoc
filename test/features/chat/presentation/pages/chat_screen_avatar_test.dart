import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:autodoc/core/widgets/app_user_avatar.dart';
import 'package:autodoc/features/chat/data/models/conversacion_model.dart';
import 'package:autodoc/features/chat/data/models/mensaje_model.dart';
import 'package:autodoc/features/chat/presentation/pages/chat_screen.dart';
import '../../../../support/chat_harness.dart';

/// C1: el encabezado del chat pinta la foto del receptor obtenida en la
/// misma lectura que ya resolvía el nombre real (`_futurePerfilReceptor`,
/// antes `_futureNombreReceptor`) — ninguna lectura adicional.
///
/// Actualizado en la Tarea 10 (R18): estos tests montan un receptor
/// mecánico ('m1', visto por un usuario `Propietario`), así que la lectura
/// real ya no es `usuarios/{receptorId}` — esa siempre daba
/// permission-denied en producción para cualquiera que no fuera el propio
/// dueño (ver el hallazgo documentado en `_futurePerfilReceptor`) — sino
/// `talleres/{receptorId}`, la proyección pública y de lectura anónima que
/// alimenta `publishTallerProfile.js`. De ahí que aquí se siembre
/// `talleres/m1` con la clave `nombre` (no `nombre_completo`, que es la
/// clave de `usuarios`).
ConversacionModel _conv() => ConversacionModel(
  id: 'c1',
  idPropietario: 'u1',
  idMecanico: 'm1',
  nombrePropietario: 'Ana Pérez',
  nombreMecanico: 'Taller Escobar',
  ultimoMensaje: 'ok',
  ultimoMensajeTs: DateTime(2026, 8, 11),
);

void main() {
  testWidgets(
    'pinta la foto del receptor que trae la misma lectura del nombre',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('talleres').doc('m1').set({
        'nombre': 'Taller Escobar Real',
        'foto_perfil_url': 'https://x/taller.jpg',
      });

      await pumpChatWidget(
        tester,
        ChatScreen(conversacionId: 'c1', firestore: firestore),
        width: 375,
        chatProvider: FakeChatProvider(conversaciones: [_conv()]),
        user: fakeChatUser(rol: 'Propietario'),
      );
      await tester.pump();
      await tester.pump();

      final avatar = tester.widget<AppUserAvatar>(find.byType(AppUserAvatar));
      expect(avatar.urlFoto, 'https://x/taller.jpg');
      expect(find.byType(CachedNetworkImage), findsOneWidget);
    },
  );

  testWidgets(
    'sin foto en el documento de usuario, el encabezado cae a la inicial',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('talleres').doc('m1').set({
        'nombre': 'Taller Escobar Real',
      });

      await pumpChatWidget(
        tester,
        ChatScreen(conversacionId: 'c1', firestore: firestore),
        width: 375,
        chatProvider: FakeChatProvider(
          conversaciones: [_conv()],
          mensajes: [
            MensajeModel(
              id: 'm1',
              idRemitente: 'u1',
              contenido: 'hola',
              tipo: 'texto',
              timestamp: DateTime(2026, 8, 11),
              estado: 'visto',
            ),
          ],
        ),
        user: fakeChatUser(rol: 'Propietario'),
      );
      await tester.pump();
      await tester.pump();

      final avatar = tester.widget<AppUserAvatar>(find.byType(AppUserAvatar));
      expect(avatar.urlFoto, isNull);
      expect(find.byType(CachedNetworkImage), findsNothing);
    },
  );
}
