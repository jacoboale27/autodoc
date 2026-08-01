import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:autodoc/features/reviews/data/services/review_service.dart';
import 'package:autodoc/core/constants/firestore_collections.dart';
import '../../../../helpers/test_helpers.mocks.dart'
    show MockFirebaseFirestore, MockCollectionReference, MockDocumentReference;

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
    final respuesta = doc.data()!['respuesta_taller'] as Map<String, dynamic>;
    expect(respuesta['texto'], 'Gracias por tu confianza');
    expect(
      respuesta['fecha'],
      isA<Timestamp>(),
      reason:
          'fake_cloud_firestore resuelve FieldValue.serverTimestamp() a un '
          'Timestamp concreto al escribir el documento.',
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

  test(
    'responderResenia mapea permission-denied a un StateError legible',
    () async {
      // fake_cloud_firestore no aplica reglas de seguridad, así que no puede
      // lanzar un FirebaseException(code: 'permission-denied') por sí solo.
      // Se usan los mocks de mockito (ya generados en test_helpers.mocks.dart
      // y usados con este mismo patrón en admin_auth_service_test.dart) para
      // forzar esa excepción específica en la llamada a update().
      final firestore = MockFirebaseFirestore();
      final collection = MockCollectionReference<Map<String, dynamic>>();
      final docRef = MockDocumentReference<Map<String, dynamic>>();
      when(
        firestore.collection(FirestoreCollections.resenias),
      ).thenReturn(collection);
      when(collection.doc('s1_u1')).thenReturn(docRef);
      when(docRef.update(any)).thenThrow(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      );

      final service = ReviewService(firestore: firestore);

      expect(
        () => service.responderResenia(
          reviewId: 's1_u1',
          tallerId: 't1',
          texto: 'Gracias por tu confianza',
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('No se pudo publicar la respuesta'),
          ),
        ),
      );
    },
  );
}
