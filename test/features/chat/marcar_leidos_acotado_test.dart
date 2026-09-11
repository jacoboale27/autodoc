import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/features/chat/data/models/mensaje_model.dart';
import 'package:autodoc/features/chat/data/repositories/chat_repository.dart';

/// Gap 7.1 de `GAPS-02-drenaje.md`: `marcarComoLeidos` leía el hilo entero y
/// metía todas las escrituras en un ÚNICO `WriteBatch`.
///
/// Dos defectos en la misma función, y el segundo es el que rompe de verdad:
///
///   1. `.where('id_remitente', isNotEqualTo: uid).get()` **sin `limit`**, en
///      cada apertura de la conversación, filtrando `estado != 'visto'` en
///      memoria. El gap 9.3 acotó el stream de al lado y dejó esta lectura
///      intacta.
///   2. Un `WriteBatch` de Firestore admite **500 operaciones**. Con más de
///      499 mensajes del otro participante el `commit()` falla entero, así que
///      el contador de no leídos **no se resetea nunca más**: la conversación
///      se queda con su globo rojo para siempre, y cada apertura vuelve a
///      intentar el mismo batch imposible.
///
/// `FakeFirebaseFirestore` **sí** aplica el límite de 500 (lanza «Firestore
/// supports at most 500 tasks in a batch»), así que el defecto se reproduce
/// con el doble tal cual — se comprobó antes de arreglar nada. El envoltorio
/// de aquí no existe para detectar eso, sino para poder afirmar lo que un
/// `expect` sobre el resultado final no ve: **cuántos** lotes se commitearon y
/// **de qué tamaño**. Sin eso, «se marcaron todos» daría igual de verde
/// leyendo el hilo entero de una vez que leyéndolo por tandas.
class FirestoreQueCuentaLotes extends FakeFirebaseFirestore {
  /// Operaciones de cada `batch()` que llegó a `commit()`, en orden.
  final List<int> lotes = <int>[];

  @override
  WriteBatch batch() => _LoteContado(super.batch(), lotes);
}

class _LoteContado implements WriteBatch {
  _LoteContado(this._real, this._lotes);

  final WriteBatch _real;
  final List<int> _lotes;
  int _operaciones = 0;

  @override
  void set<T>(DocumentReference<T> document, T data, [SetOptions? options]) {
    _operaciones += 1;
    _real.set(document, data, options);
  }

  @override
  void update<T>(DocumentReference<T> document, T data) {
    _operaciones += 1;
    _real.update(document, data);
  }

  @override
  void delete(DocumentReference document) {
    _operaciones += 1;
    _real.delete(document);
  }

  @override
  Future<void> commit() {
    _lotes.add(_operaciones);
    return _real.commit();
  }
}

/// Tope duro de Firestore. No es configurable ni negociable.
const int _maxOperacionesPorBatch = 500;

Future<FirestoreQueCuentaLotes> conHilo({
  required int delOtro,
  int mios = 0,
  String estadoInicial = 'entregado',
}) async {
  final db = FirestoreQueCuentaLotes();
  await db.collection('conversaciones').doc('c1').set({
    'id_propietario': 'yo',
    'id_mecanico': 'otro',
    'nombre_propietario': 'Ana',
    'nombre_mecanico': 'Taller',
    'ultimo_mensaje': 'hola',
    'ultimo_mensaje_ts': Timestamp.fromDate(DateTime(2026, 1, 1)),
    'no_leidos_propietario': delOtro,
    'no_leidos_mecanico': 0,
    'estado': 'activo',
  });
  final mensajes = db
      .collection('conversaciones')
      .doc('c1')
      .collection('mensajes');
  for (var i = 0; i < delOtro; i += 1) {
    await mensajes.doc('otro$i').set({
      'id_remitente': 'otro',
      'contenido': 'mensaje $i',
      'tipo': 'texto',
      'timestamp': Timestamp.fromDate(
        DateTime(2026, 1, 1).add(Duration(minutes: i)),
      ),
      'estado': estadoInicial,
    });
  }
  for (var i = 0; i < mios; i += 1) {
    await mensajes.doc('mio$i').set({
      'id_remitente': 'yo',
      'contenido': 'respuesta $i',
      'tipo': 'texto',
      'timestamp': Timestamp.fromDate(
        DateTime(2026, 1, 1).add(Duration(minutes: 500 + i)),
      ),
      'estado': 'entregado',
    });
  }
  return db;
}

Future<List<String>> estadosDe(FakeFirebaseFirestore db, String prefijo) async {
  final snap = await db
      .collection('conversaciones')
      .doc('c1')
      .collection('mensajes')
      .get();
  return snap.docs
      .where((d) => d.id.startsWith(prefijo))
      .map((d) => (d.data()['estado'] ?? '').toString())
      .toList();
}

void main() {
  test('un hilo largo no revienta el batch', () async {
    final db = await conHilo(delOtro: maxMensajesPorLoteDeLectura + 101);
    final repo = ChatRepository(firestore: db);

    await repo.marcarComoLeidos('c1', false, 'yo');

    expect(db.lotes, isNotEmpty);
    expect(
      db.lotes.reduce((a, b) => a > b ? a : b),
      lessThanOrEqualTo(_maxOperacionesPorBatch),
      reason:
          'un WriteBatch admite 500 operaciones; pasarse hace fallar el commit '
          'ENTERO, y con el se queda sin resetear el contador de no leidos',
    );
  });

  test(
    'y marca como vistos TODOS los mensajes, no solo el primer lote',
    () async {
      final cuantos = maxMensajesPorLoteDeLectura + 101;
      final db = await conHilo(delOtro: cuantos);
      final repo = ChatRepository(firestore: db);

      await repo.marcarComoLeidos('c1', false, 'yo');

      final estados = await estadosDe(db, 'otro');
      expect(estados, hasLength(cuantos));
      expect(estados.every((e) => e == 'visto'), isTrue);
    },
  );

  test('la lectura va por lotes: mas de un commit para un hilo largo', () async {
    final db = await conHilo(delOtro: maxMensajesPorLoteDeLectura + 101);
    final repo = ChatRepository(firestore: db);

    await repo.marcarComoLeidos('c1', false, 'yo');

    expect(
      db.lotes.length,
      greaterThan(1),
      reason:
          'si cabe todo en un commit es que la consulta no lleva `limit` y se '
          'trajo el hilo entero',
    );
  });

  test('el contador propio se resetea', () async {
    final db = await conHilo(delOtro: 3);
    final repo = ChatRepository(firestore: db);

    await repo.marcarComoLeidos('c1', false, 'yo');

    final conv = await db.collection('conversaciones').doc('c1').get();
    expect(conv.data()!['no_leidos_propietario'], 0);
  });

  test('NO toca los mensajes propios', () async {
    final db = await conHilo(delOtro: 2, mios: 3);
    final repo = ChatRepository(firestore: db);

    await repo.marcarComoLeidos('c1', false, 'yo');

    expect(await estadosDe(db, 'mio'), everyElement('entregado'));
    expect(await estadosDe(db, 'otro'), everyElement('visto'));
  });

  test('un uid que no participa en la conversacion no escribe nada', () async {
    final db = await conHilo(delOtro: 3);
    final repo = ChatRepository(firestore: db);

    await repo.marcarComoLeidos('c1', false, 'un-tercero');

    expect(db.lotes, isEmpty);
    expect(await estadosDe(db, 'otro'), everyElement('entregado'));
  });

  test('un uid vacio tampoco', () async {
    // `chat_screen` se protege de llamar con el perfil aun sin cargar, pero la
    // guarda vive tambien aqui: con uid vacio, antes se marcaba como visto
    // TODO mensaje cuyo remitente no fuera la cadena vacia — o sea el hilo
    // entero, incluidos los propios.
    final db = await conHilo(delOtro: 3, mios: 2);
    final repo = ChatRepository(firestore: db);

    await repo.marcarComoLeidos('c1', false, '');

    expect(db.lotes, isEmpty);
  });

  test('una conversacion que ya no existe no revienta', () async {
    final db = await conHilo(delOtro: 1);
    final repo = ChatRepository(firestore: db);

    await repo.marcarComoLeidos('fantasma', false, 'yo');

    expect(db.lotes, isEmpty);
  });

  test('un hilo ya visto entero no escribe ningun mensaje', () async {
    final db = await conHilo(delOtro: 5, estadoInicial: 'visto');
    final repo = ChatRepository(firestore: db);

    await repo.marcarComoLeidos('c1', false, 'yo');

    // Un solo lote, y con una sola operacion: el reseteo del contador. Abrir
    // una conversacion ya leida no puede costar una escritura por mensaje.
    expect(db.lotes, [1]);
  });
}
