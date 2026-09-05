import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'dart:io';
import 'package:autodoc/features/chat/data/models/mensaje_model.dart';
import 'package:autodoc/features/chat/data/repositories/chat_repository.dart';
import 'package:autodoc/features/chat/presentation/providers/chat_provider.dart';

/// C1: `iniciarOCrearConversacion` acepta la foto de cada participante y la
/// deja escrita en el documento — es el punto donde el cliente crea la
/// conversación (no hay Cloud Function que lo haga, ver
/// functions/index.js: el único trigger sobre `conversaciones` es
/// `notifyOnNewChatMessage`, que reacciona a mensajes ya existentes).
void main() {
  setUpAll(() async {
    final tempDir = Directory.systemTemp.createTempSync();
    Hive.init(tempDir.path);
    Hive.registerAdapter(MensajeModelAdapter());
    await Hive.openBox<MensajeModel>('mensajes');
  });

  tearDownAll(() async {
    await Hive.close();
  });

  test(
    'escribe foto_propietario y foto_mecanico en el documento nuevo',
    () async {
      final firestore = FakeFirebaseFirestore();
      final provider = ChatProvider(
        repository: ChatRepository(firestore: firestore),
      );

      final id = await provider.iniciarOCrearConversacion(
        idPropietario: 'p1',
        idMecanico: 'm1',
        nombrePropietario: 'Ana',
        nombreMecanico: 'Taller Escobar',
        fotoPropietario: 'https://x/p.jpg',
        fotoMecanico: 'https://x/m.jpg',
      );

      final doc = await firestore.collection('conversaciones').doc(id).get();
      expect(doc.data()?['foto_propietario'], 'https://x/p.jpg');
      expect(doc.data()?['foto_mecanico'], 'https://x/m.jpg');
    },
  );

  test('sin fotos (llamador que no las tiene) no escribe esos campos, y no '
      'rompe la creacion de la conversacion', () async {
    final firestore = FakeFirebaseFirestore();
    final provider = ChatProvider(
      repository: ChatRepository(firestore: firestore),
    );

    final id = await provider.iniciarOCrearConversacion(
      idPropietario: 'p1',
      idMecanico: 'm1',
      nombrePropietario: 'Ana',
      nombreMecanico: 'Taller Escobar',
    );

    final doc = await firestore.collection('conversaciones').doc(id).get();
    expect(doc.exists, isTrue);
    expect(doc.data()?.containsKey('foto_propietario'), isFalse);
    expect(doc.data()?.containsKey('foto_mecanico'), isFalse);
  });
}
