import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/features/reviews/data/services/review_service.dart';
import 'package:autodoc/core/constants/firestore_collections.dart';

void main() {
  test('responderResenia guarda texto y fecha en respuesta_taller', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection(FirestoreCollections.resenias).doc('s1_u1').set({
      'id_usuario': 'u1',
      'id_taller': 't1',
      'id_servicio': 's1',
      'estrellas': 5,
      'fecha_resenia': DateTime.now(),
    });

    final service = ReviewService(firestore: firestore);
    await service.responderResenia(
      reviewId: 's1_u1',
      tallerId: 't1',
      texto: 'Gracias por tu confianza',
    );

    final doc = await firestore
        .collection(FirestoreCollections.resenias)
        .doc('s1_u1')
        .get();
    expect(
      doc.data()!['respuesta_taller']['texto'],
      'Gracias por tu confianza',
    );
  });

  test('responderResenia rechaza texto vacío', () async {
    final firestore = FakeFirebaseFirestore();
    final service = ReviewService(firestore: firestore);

    expect(
      () => service.responderResenia(
        reviewId: 's1_u1',
        tallerId: 't1',
        texto: '  ',
      ),
      throwsArgumentError,
    );
  });
}
