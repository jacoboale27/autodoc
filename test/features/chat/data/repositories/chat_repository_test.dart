import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:autodoc/features/chat/data/repositories/chat_repository.dart';
import 'package:autodoc/features/chat/data/models/cotizacion_model.dart';

void main() {
  group('ChatRepository.crearCotizacion', () {
    // El motor de `fake_firebase_security_rules` solo conoce read/write/
    // update/delete/list: no existe `create`, y `write` YA INCLUYE `delete`.
    // Por eso aqui solo se puede expresar el caso en que la limpieza esta
    // permitida. El caso contrario -- que un draft huerfano no sea
    // consumible -- depende de las reglas reales y se prueba contra el
    // emulador en test_rules/cotizaciones.test.js, no contra este falso.
    test('fallo privado no deja cotizacion utilizable', () async {
      final firestore = FakeFirebaseFirestore(
        securityRules: '''
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /cotizaciones/{id} {
      allow read, write: if true;
      match /privado/{document} {
        allow read, write: if false;
      }
    }
  }
}
''',
      );
      final repo = ChatRepository(firestore: firestore);
      final cotizacion = CotizacionModel(
        id: '',
        idPropietario: 'owner1',
        idMecanico: 'taller1',
        items: [CotizacionItem(material: 'Filtro', cantidad: 1, costo: 20)],
        fecha: DateTime(2026, 1, 1),
      );

      // El falso lanza un `Exception` plano al denegar, no el
      // `FirebaseException` con code 'permission-denied' que devuelve
      // Firestore real. Lo que este test fija es que el error se propaga
      // y que la limpieza corre; el codigo concreto del error pertenece a
      // la suite de reglas contra el emulador.
      await expectLater(
        repo.crearCotizacion(cotizacion),
        throwsA(isA<Exception>()),
      );

      final publicDocs = await firestore.collection('cotizaciones').get();
      expect(
        publicDocs.docs.where((doc) => doc.data()['estado'] != 'draft'),
        isEmpty,
      );
      expect(publicDocs.docs, isEmpty);
    });

    test('el documento publico nunca incluye beneficio en los items', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = ChatRepository(firestore: firestore);
      final cotizacion = CotizacionModel(
        id: '',
        idPropietario: 'owner1',
        idMecanico: 'taller1',
        items: [
          CotizacionItem(
            material: 'Filtro',
            cantidad: 1,
            costo: 20,
            beneficio: 8,
          ),
        ],
        fecha: DateTime(2026, 1, 1),
      );

      final id = await repo.crearCotizacion(cotizacion);

      final publicDoc = await firestore
          .collection('cotizaciones')
          .doc(id)
          .get();
      final items = publicDoc.data()!['items'] as List;
      expect(publicDoc.data()!['estado'], 'pendiente');
      expect((items.first as Map).containsKey('beneficio'), isFalse);
    });

    test('escribe el beneficio en la subcoleccion privada', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = ChatRepository(firestore: firestore);
      final cotizacion = CotizacionModel(
        id: '',
        idPropietario: 'owner1',
        idMecanico: 'taller1',
        items: [
          CotizacionItem(
            material: 'Filtro',
            cantidad: 1,
            costo: 20,
            beneficio: 8,
          ),
        ],
        fecha: DateTime(2026, 1, 1),
      );

      final id = await repo.crearCotizacion(cotizacion);
      final beneficios = await repo.obtenerBeneficiosCotizacion(id);

      expect(beneficios, [8.0]);
    });

    test(
      'obtenerBeneficiosCotizacion devuelve lista vacia si no existe',
      () async {
        final firestore = FakeFirebaseFirestore();
        final repo = ChatRepository(firestore: firestore);

        final beneficios = await repo.obtenerBeneficiosCotizacion('no-existe');

        expect(beneficios, isEmpty);
      },
    );
  });
}
