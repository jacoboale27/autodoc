import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:autodoc/features/chat/data/repositories/chat_repository.dart';
import 'package:autodoc/features/chat/data/models/cotizacion_model.dart';

void main() {
  group('ChatRepository.crearCotizacion', () {
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
