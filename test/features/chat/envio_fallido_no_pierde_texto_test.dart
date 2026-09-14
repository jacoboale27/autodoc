import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mockito/mockito.dart';

import 'package:autodoc/features/chat/data/models/mensaje_model.dart';
import 'package:autodoc/features/chat/data/repositories/chat_repository.dart';
import 'package:autodoc/features/chat/presentation/providers/chat_provider.dart';

/// GAPS-05 — H-01 lo destapo refutando un cargo: el chat NO duplica mensajes,
/// pero **si el envio falla, el texto ya se borro y la persona no recibe
/// error**.
///
/// La pantalla (`chat_screen.dart:234`) llama a `enviarMensaje` **sin
/// `await`** y limpia el campo en la linea siguiente. El provider se traga la
/// excepcion en su `catch`, la guarda en `_error` y notifica — pero la
/// pantalla de chat no pinta ese campo en ninguna parte. Resultado: el mensaje
/// desaparece del compositor, no llega al servidor y no hay ni un aviso. El
/// caso real es el mas comun de todos: el tunel del metro.
///
/// Lo que se arregla es el contrato del provider. Sin un valor de retorno, la
/// pantalla **no tiene forma** de saber si restaurar el texto: `await` sobre un
/// `Future<void>` que se traga el error completa igual de bien que un envio
/// correcto.
class RepositorioQueFalla extends Mock implements ChatRepository {
  RepositorioQueFalla({this.fallo});

  Object? fallo;
  int envios = 0;

  @override
  Stream<List<MensajeModel>> streamMensajes(String conversacionId) =>
      Stream.value([]);

  @override
  Future<void> enviarMensaje({
    String? conversacionId,
    MensajeModel? mensaje,
    String? receptorId,
    bool? isMecanicoRemitente,
  }) async {
    envios += 1;
    if (fallo != null) throw fallo!;
  }
}

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

  Future<bool> enviar(ChatProvider provider) => provider.enviarMensaje(
    conversacionId: 'c1',
    contenido: 'hola',
    remitenteId: 'u1',
    receptorId: 'u2',
    isMecanicoRemitente: false,
  );

  test('un envio correcto responde true', () async {
    final repo = RepositorioQueFalla();
    final provider = ChatProvider(repository: repo);
    addTearDown(provider.dispose);

    expect(await enviar(provider), isTrue);
    expect(repo.envios, 1);
    expect(provider.error, isNull);
  });

  test(
    'un envio que falla responde false, para que la pantalla lo sepa',
    () async {
      final repo = RepositorioQueFalla(
        fallo: FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unavailable',
        ),
      );
      final provider = ChatProvider(repository: repo);
      addTearDown(provider.dispose);

      expect(
        await enviar(provider),
        isFalse,
        reason:
            'sin valor de retorno la pantalla no puede distinguir un envio '
            'correcto de uno tragado por el catch, y el texto se pierde en '
            'silencio',
      );
    },
  );

  test('y deja el motivo en `error`, sin detalle tecnico', () async {
    final repo = RepositorioQueFalla(
      fallo: FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'INTERNAL: no debe verse',
      ),
    );
    final provider = ChatProvider(repository: repo);
    addTearDown(provider.dispose);

    await enviar(provider);

    expect(provider.error, isNotNull);
    expect(provider.error, isNot(contains('INTERNAL')));
  });
}
