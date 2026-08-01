import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/features/admin/data/repositories/admin_repository.dart';
import 'package:autodoc/core/constants/firestore_collections.dart';

void main() {
  test('suspenderCuenta marca estado=suspendido', () async {
    final firestore = FakeFirebaseFirestore();
    final docRef = await firestore
        .collection(FirestoreCollections.usuarios)
        .add({'nombre_completo': 'Juan', 'estado': 'activo'});

    final repo = AdminRepository(firestore: firestore);
    await repo.suspenderCuenta(
      coleccion: FirestoreCollections.usuarios,
      docId: docRef.id,
      motivo: 'Incumplimiento de normas',
    );

    final doc = await firestore
        .collection(FirestoreCollections.usuarios)
        .doc(docRef.id)
        .get();
    expect(doc.data()!['estado'], 'suspendido');
  });

  test('reactivarCuenta marca estado=activo por defecto', () async {
    final firestore = FakeFirebaseFirestore();
    final docRef = await firestore
        .collection(FirestoreCollections.usuarios)
        .add({'nombre_completo': 'Juan', 'estado': 'suspendido'});

    final repo = AdminRepository(firestore: firestore);
    await repo.reactivarCuenta(
      coleccion: FirestoreCollections.usuarios,
      docId: docRef.id,
    );

    final doc = await firestore
        .collection(FirestoreCollections.usuarios)
        .doc(docRef.id)
        .get();
    expect(doc.data()!['estado'], 'activo');
  });

  test(
    'reactivarCuenta acepta un estadoActivo distinto (p.ej. talleres usan aprobado)',
    () async {
      final firestore = FakeFirebaseFirestore();
      final docRef = await firestore
          .collection(FirestoreCollections.talleres)
          .add({'nombre': 'Taller Y', 'estado': 'suspendido'});

      final repo = AdminRepository(firestore: firestore);
      await repo.reactivarCuenta(
        coleccion: FirestoreCollections.talleres,
        docId: docRef.id,
        estadoActivo: 'aprobado',
      );

      final doc = await firestore
          .collection(FirestoreCollections.talleres)
          .doc(docRef.id)
          .get();
      expect(doc.data()!['estado'], 'aprobado');
    },
  );
}
