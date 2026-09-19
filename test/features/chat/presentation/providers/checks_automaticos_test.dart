// Observaciones del 2026-09-18 (chat): «los cheques de los mensajes no
// aparecen hasta que se refresca el chat, tiene que ser automático».
//
// `marcarComoLeidos` solo corría AL ABRIR la conversación, así que con las dos
// personas dentro del chat, lo que una escribía nunca pasaba a "visto" para la
// otra hasta que alguien salía y volvía a entrar.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/features/chat/data/models/mensaje_model.dart';
import 'package:autodoc/features/chat/data/repositories/chat_repository.dart';
import 'package:autodoc/features/chat/presentation/providers/chat_provider.dart';

Future<void> _escribe(
  FakeFirebaseFirestore db,
  String id,
  String remitente,
) async {
  await db
      .collection('conversaciones')
      .doc('c1')
      .collection('mensajes')
      .doc(id)
      .set({
        'id_remitente': remitente,
        'contenido': 'hola $id',
        'tipo': 'texto',
        'timestamp': Timestamp.fromDate(DateTime(2026, 9, 18, 10, id.length)),
        'estado': 'enviado',
      });
}

Future<String> _estado(FakeFirebaseFirestore db, String id) async {
  final doc = await db
      .collection('conversaciones')
      .doc('c1')
      .collection('mensajes')
      .doc(id)
      .get();
  return doc.data()!['estado'] as String;
}

/// Deja correr los listeners y las escrituras encadenadas del doble.
Future<void> _asentar() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late FakeFirebaseFirestore db;
  late ChatProvider provider;

  setUp(() async {
    db = FakeFirebaseFirestore();
    await db.collection('conversaciones').doc('c1').set({
      'id_propietario': 'yo',
      'id_mecanico': 'taller',
      'no_leidos_propietario': 0,
      'no_leidos_mecanico': 0,
    });
    provider = ChatProvider(repository: ChatRepository(firestore: db));
  });

  tearDown(() => provider.dispose());

  test(
    'con el chat abierto, lo que llega del otro se marca visto solo',
    () async {
      provider.inicializarMensajes('c1');
      provider.abrirConversacion('c1', lectorId: 'yo', lectorEsMecanico: false);
      await _asentar();

      await _escribe(db, 'm1', 'taller');
      await _asentar();

      expect(await _estado(db, 'm1'), kEstadoMensajeVisto);
    },
  );

  test('los mensajes propios no se marcan como vistos por uno mismo', () async {
    provider.inicializarMensajes('c1');
    provider.abrirConversacion('c1', lectorId: 'yo', lectorEsMecanico: false);
    await _escribe(db, 'm1', 'yo');
    await _asentar();

    expect(await _estado(db, 'm1'), 'enviado');
  });

  test('en segundo plano no se da nada por visto; al volver, sí', () async {
    provider.inicializarMensajes('c1');
    provider.abrirConversacion('c1', lectorId: 'yo', lectorEsMecanico: false);
    provider.pausarLectura(true);
    await _escribe(db, 'm1', 'taller');
    await _asentar();
    expect(await _estado(db, 'm1'), 'enviado');
    expect(provider.conversacionAbierta, isNull);

    provider.pausarLectura(false);
    await _asentar();
    expect(await _estado(db, 'm1'), kEstadoMensajeVisto);
    expect(provider.conversacionAbierta, 'c1');
  });

  test('cerrado el chat, lo que llega ya no se marca', () async {
    provider.inicializarMensajes('c1');
    provider.abrirConversacion('c1', lectorId: 'yo', lectorEsMecanico: false);
    await _asentar();
    provider.cerrarConversacion('c1');

    await _escribe(db, 'm1', 'taller');
    await _asentar();

    expect(await _estado(db, 'm1'), 'enviado');
  });
}
