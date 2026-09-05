import 'package:flutter_test/flutter_test.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:autodoc/core/widgets/app_user_avatar.dart';
import 'package:autodoc/features/chat/data/models/conversacion_model.dart';
import 'package:autodoc/features/chat/presentation/pages/conversaciones_list_screen.dart';
import '../../../../support/chat_harness.dart';

/// C1: la lista de conversaciones pinta la foto de perfil del otro
/// participante sin pagar una lectura extra de Firestore por fila — la URL
/// llega ya denormalizada en el propio documento de conversación.
void main() {
  ConversacionModel convConFoto() => ConversacionModel(
    id: 'c1',
    idPropietario: 'u1',
    idMecanico: 'm1',
    nombrePropietario: 'Ana Pérez',
    nombreMecanico: 'Taller Escobar',
    ultimoMensaje: 'ok',
    ultimoMensajeTs: DateTime(2026, 8, 11),
    fotoMecanico: 'https://x/taller.jpg',
  );

  ConversacionModel convSinFoto() => ConversacionModel(
    // Documento tal cual quedó grabado antes de esta funcionalidad: sin
    // fotoPropietario/fotoMecanico. Es exactamente lo que produce
    // ConversacionModel.fromMap sobre un documento real de producción sin
    // esos campos.
    id: 'c2',
    idPropietario: 'u1',
    idMecanico: 'm1',
    nombrePropietario: 'Ana Pérez',
    nombreMecanico: 'Taller Viejo',
    ultimoMensaje: 'hola',
    ultimoMensajeTs: DateTime(2026, 8, 11),
  );

  testWidgets(
    'usa AppUserAvatar con la foto denormalizada del mecánico (rol propietario)',
    (tester) async {
      await pumpChatWidget(
        tester,
        const ConversacionesListScreen(),
        width: 375,
        chatProvider: FakeChatProvider(conversaciones: [convConFoto()]),
        user: fakeChatUser(rol: 'Propietario'),
      );

      final avatar = tester.widget<AppUserAvatar>(find.byType(AppUserAvatar));
      expect(avatar.urlFoto, 'https://x/taller.jpg');
      expect(find.byType(CachedNetworkImage), findsOneWidget);
    },
  );

  testWidgets(
    'una conversacion creada antes de esta funcionalidad (sin foto) cae a '
    'la inicial del nombre, no a un espacio roto',
    (tester) async {
      await pumpChatWidget(
        tester,
        const ConversacionesListScreen(),
        width: 375,
        chatProvider: FakeChatProvider(conversaciones: [convSinFoto()]),
        user: fakeChatUser(rol: 'Propietario'),
      );

      final avatar = tester.widget<AppUserAvatar>(find.byType(AppUserAvatar));
      expect(avatar.urlFoto, isNull);
      expect(find.byType(CachedNetworkImage), findsNothing);
      expect(find.text('T'), findsOneWidget); // inicial de "Taller Viejo"
    },
  );
}
