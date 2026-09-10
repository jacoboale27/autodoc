import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/features/reviews/data/services/review_service.dart';
import 'package:autodoc/core/constants/firestore_collections.dart';

/// Doble de Storage: registra cada subida y cada borrado y devuelve una URL
/// determinista, para poder afirmar *que* se subio y *que* se borro sin tocar
/// Firebase.
class _StorageFalso {
  final List<String> subidas = [];
  final List<String> borrados = [];
  bool fallaAlBorrar = false;

  Future<String> subir({
    required String ruta,
    required Uint8List bytes,
    required String contentType,
  }) async {
    subidas.add(ruta);
    return 'https://storage.test/${Uri.encodeComponent(ruta)}';
  }

  Future<void> borrar(String url) async {
    if (fallaAlBorrar) throw StateError('objeto ausente');
    borrados.add(url);
  }
}

XFile _foto(String nombre) => XFile.fromData(
  Uint8List.fromList(const [1, 2, 3]),
  name: nombre,
  path: nombre,
  mimeType: 'image/jpeg',
);

Future<FakeFirebaseFirestore> _conResenia({
  List<String> fotos = const [],
}) async {
  final firestore = FakeFirebaseFirestore();
  await firestore.collection(FirestoreCollections.servicios).doc('s1').set({
    'id_taller': 't1',
    'id_vehiculo': 'v1',
  });
  await firestore.collection(FirestoreCollections.vehiculos).doc('v1').set({
    'id_propietario': 'u1',
  });
  await firestore.collection(FirestoreCollections.resenias).doc('s1_u1').set({
    'id_resenia': 's1_u1',
    'id_usuario': 'u1',
    'id_taller': 't1',
    'id_servicio': 's1',
    'estrellas': 4,
    'comentario': 'original',
    'fotos': fotos,
  });
  return firestore;
}

Future<List<String>> _fotosDe(FakeFirebaseFirestore db) async {
  final doc = await db
      .collection(FirestoreCollections.resenias)
      .doc('s1_u1')
      .get();
  return (doc.data()!['fotos'] as List).cast<String>();
}

void main() {
  test('submitReview persiste la lista de fotos si se provee', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection(FirestoreCollections.servicios).doc('s1').set({
      'id_taller': 't1',
      'id_vehiculo': 'v1',
    });
    await firestore.collection(FirestoreCollections.vehiculos).doc('v1').set({
      'id_propietario': 'u1',
    });

    final service = ReviewService(firestore: firestore);
    await service.submitReview(
      userId: 'u1',
      tallerId: 't1',
      idServicio: 's1',
      estrellas: 5,
      fotos: const [
        'https://example.com/foto1.jpg',
        'https://example.com/foto2.jpg',
      ],
    );

    final doc = await firestore
        .collection(FirestoreCollections.resenias)
        .doc('s1_u1')
        .get();
    expect(doc.data()!['fotos'], [
      'https://example.com/foto1.jpg',
      'https://example.com/foto2.jpg',
    ]);
  });

  group('updateReview y las fotos', () {
    test('sin argumentos de foto no toca la lista ni borra nada', () async {
      final db = await _conResenia(fotos: const ['https://a/1.jpg']);
      final storage = _StorageFalso();
      final service = ReviewService(
        firestore: db,
        subidor: storage.subir,
        borrador: storage.borrar,
      );

      final finales = await service.updateReview(
        reviewId: 's1_u1',
        tallerId: 't1',
        estrellas: 5,
        comentario: 'editado',
      );

      // null y no [] a proposito: una lista vacia significaria "se borraron
      // todas", que es justo lo contrario de lo que hace esta llamada.
      expect(finales, isNull);
      expect(await _fotosDe(db), ['https://a/1.jpg']);
      expect(storage.borrados, isEmpty);
      expect(storage.subidas, isEmpty);
    });

    test('conservar todas las fotos las deja intactas', () async {
      final db = await _conResenia(
        fotos: const ['https://a/1.jpg', 'https://a/2.jpg'],
      );
      final storage = _StorageFalso();
      final service = ReviewService(
        firestore: db,
        subidor: storage.subir,
        borrador: storage.borrar,
      );

      final finales = await service.updateReview(
        reviewId: 's1_u1',
        tallerId: 't1',
        estrellas: 5,
        fotosConservadas: const ['https://a/1.jpg', 'https://a/2.jpg'],
      );

      expect(finales, ['https://a/1.jpg', 'https://a/2.jpg']);
      expect(await _fotosDe(db), ['https://a/1.jpg', 'https://a/2.jpg']);
      expect(storage.borrados, isEmpty);
    });

    test('anadir una foto la sube y la anexa sin borrar las previas', () async {
      final db = await _conResenia(fotos: const ['https://a/1.jpg']);
      final storage = _StorageFalso();
      final service = ReviewService(
        firestore: db,
        subidor: storage.subir,
        borrador: storage.borrar,
      );

      final finales = await service.updateReview(
        reviewId: 's1_u1',
        tallerId: 't1',
        estrellas: 5,
        fotosConservadas: const ['https://a/1.jpg'],
        fotosNuevas: [_foto('nueva.jpg')],
      );

      expect(finales!.length, 2);
      expect(finales.first, 'https://a/1.jpg');
      expect(storage.subidas.single, startsWith('resenia_fotos/s1/'));
      expect(await _fotosDe(db), finales);
      expect(storage.borrados, isEmpty);
    });

    test(
      'quitar una foto la borra de Storage tras escribir Firestore',
      () async {
        final db = await _conResenia(
          fotos: const ['https://a/1.jpg', 'https://a/2.jpg'],
        );
        final storage = _StorageFalso();
        final service = ReviewService(
          firestore: db,
          subidor: storage.subir,
          borrador: storage.borrar,
        );

        final finales = await service.updateReview(
          reviewId: 's1_u1',
          tallerId: 't1',
          estrellas: 3,
          fotosConservadas: const ['https://a/1.jpg'],
        );

        expect(finales, ['https://a/1.jpg']);
        expect(await _fotosDe(db), ['https://a/1.jpg']);
        expect(storage.borrados, ['https://a/2.jpg']);
      },
    );

    test('reemplazar una foto borra la vieja y sube la nueva', () async {
      final db = await _conResenia(fotos: const ['https://a/1.jpg']);
      final storage = _StorageFalso();
      final service = ReviewService(
        firestore: db,
        subidor: storage.subir,
        borrador: storage.borrar,
      );

      final finales = await service.updateReview(
        reviewId: 's1_u1',
        tallerId: 't1',
        estrellas: 5,
        fotosConservadas: const [],
        fotosNuevas: [_foto('reemplazo.jpg')],
      );

      expect(finales!.length, 1);
      expect(finales.single, startsWith('https://storage.test/'));
      expect(storage.borrados, ['https://a/1.jpg']);
      expect(await _fotosDe(db), finales);
    });

    test('vaciar la lista borra todas las fotos', () async {
      final db = await _conResenia(
        fotos: const ['https://a/1.jpg', 'https://a/2.jpg'],
      );
      final storage = _StorageFalso();
      final service = ReviewService(
        firestore: db,
        subidor: storage.subir,
        borrador: storage.borrar,
      );

      final finales = await service.updateReview(
        reviewId: 's1_u1',
        tallerId: 't1',
        estrellas: 1,
        fotosConservadas: const [],
      );

      expect(finales, isEmpty);
      expect(await _fotosDe(db), isEmpty);
      expect(storage.borrados, ['https://a/1.jpg', 'https://a/2.jpg']);
    });

    test('no se puede conservar una URL que no estaba en la resenia', () async {
      final db = await _conResenia(fotos: const ['https://a/1.jpg']);
      final storage = _StorageFalso();
      final service = ReviewService(
        firestore: db,
        subidor: storage.subir,
        borrador: storage.borrar,
      );

      await expectLater(
        service.updateReview(
          reviewId: 's1_u1',
          tallerId: 't1',
          estrellas: 5,
          fotosConservadas: const ['https://otra/ajena.jpg'],
        ),
        throwsA(isA<StateError>()),
      );
      expect(await _fotosDe(db), ['https://a/1.jpg']);
      expect(storage.borrados, isEmpty);
    });

    test('no se pueden dejar mas fotos que el maximo permitido', () async {
      final db = await _conResenia(fotos: const ['https://a/1.jpg']);
      final storage = _StorageFalso();
      final service = ReviewService(
        firestore: db,
        subidor: storage.subir,
        borrador: storage.borrar,
      );

      await expectLater(
        service.updateReview(
          reviewId: 's1_u1',
          tallerId: 't1',
          estrellas: 5,
          fotosConservadas: const ['https://a/1.jpg'],
          fotosNuevas: [_foto('a.jpg'), _foto('b.jpg'), _foto('c.jpg')],
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(storage.subidas, isEmpty);
      expect(await _fotosDe(db), ['https://a/1.jpg']);
    });

    test('un borrado que falla no revierte la lista ya escrita', () async {
      final db = await _conResenia(
        fotos: const ['https://a/1.jpg', 'https://a/2.jpg'],
      );
      final storage = _StorageFalso()..fallaAlBorrar = true;
      final service = ReviewService(
        firestore: db,
        subidor: storage.subir,
        borrador: storage.borrar,
      );

      final finales = await service.updateReview(
        reviewId: 's1_u1',
        tallerId: 't1',
        estrellas: 4,
        fotosConservadas: const ['https://a/1.jpg'],
      );

      expect(finales, ['https://a/1.jpg']);
      expect(await _fotosDe(db), ['https://a/1.jpg']);
    });
  });
}
