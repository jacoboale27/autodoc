import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/features/reviews/data/services/review_service.dart';
import 'package:autodoc/core/constants/firestore_collections.dart';

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
}
