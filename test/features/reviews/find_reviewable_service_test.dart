import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/features/reviews/data/services/review_service.dart';

/// Gap 7.4 de `GAPS-02-drenaje.md`, segunda mitad: `findReviewableServiceId`
/// leia `servicios` con un `whereIn` de hasta 30 vehiculos **sin `limit`**,
/// ordenaba en memoria y se quedaba con el primero que fuera de ese taller.
/// O sea que traia TODO el historial de servicios del propietario —de
/// cualquier taller— para devolver como mucho un id.
///
/// La funcion no tenia ni un test, asi que lo primero es fijar lo que hace,
/// y luego acotarla sin cambiarlo. Lo que la acota es filtrar por `id_taller`
/// en el SERVIDOR en vez de en memoria: el conjunto pasa de "todo el historial
/// del propietario" a "sus servicios con este taller", que es justo lo que la
/// funcion mira.
///
/// El ahorro en si no lo puede ver este test: `FakeFirebaseFirestore` no
/// cuenta lecturas. Lo que si lo vigila es `test/firestore_indices_test.dart`,
/// que exige indice compuesto para la consulta nueva.
void main() {
  const uid = 'owner-1';
  const taller = 'taller-1';

  Future<FakeFirebaseFirestore> conHistorial({
    required int serviciosDeOtrosTalleres,
    required List<({String id, int dia, String taller})> propios,
    List<String> yaResenados = const [],
  }) async {
    final db = FakeFirebaseFirestore();
    await db.collection('vehiculos').doc('v1').set({
      'id_propietario': uid,
      'placa': 'ABC123',
    });

    for (var i = 0; i < serviciosDeOtrosTalleres; i += 1) {
      await db.collection('servicios').doc('ajeno-$i').set({
        'id_vehiculo': 'v1',
        'id_taller': 'taller-ajeno-$i',
        'fecha': Timestamp.fromDate(DateTime(2026, 1, 1)),
      });
    }

    for (final s in propios) {
      await db.collection('servicios').doc(s.id).set({
        'id_vehiculo': 'v1',
        'id_taller': s.taller,
        'fecha': Timestamp.fromDate(DateTime(2026, 1, s.dia)),
      });
    }

    for (final idServicio in yaResenados) {
      await db.collection('resenias').doc('r-$idServicio').set({
        'id_usuario': uid,
        'id_taller': taller,
        'id_servicio': idServicio,
        'estrellas': 5,
      });
    }
    return db;
  }

  test('devuelve el servicio MAS RECIENTE de ese taller', () async {
    final db = await conHistorial(
      serviciosDeOtrosTalleres: 0,
      propios: [
        (id: 'viejo', dia: 1, taller: taller),
        (id: 'nuevo', dia: 20, taller: taller),
      ],
    );

    final id = await ReviewService(
      firestore: db,
    ).findReviewableServiceId(uid, taller);

    expect(id, 'nuevo');
  });

  test('salta los servicios que ya tienen resenia', () async {
    final db = await conHistorial(
      serviciosDeOtrosTalleres: 0,
      propios: [
        (id: 'viejo', dia: 1, taller: taller),
        (id: 'nuevo', dia: 20, taller: taller),
      ],
      yaResenados: ['nuevo'],
    );

    final id = await ReviewService(
      firestore: db,
    ).findReviewableServiceId(uid, taller);

    expect(id, 'viejo');
  });

  test(
    'devuelve null si ya resenio todos los servicios de ese taller',
    () async {
      final db = await conHistorial(
        serviciosDeOtrosTalleres: 0,
        propios: [(id: 'unico', dia: 1, taller: taller)],
        yaResenados: ['unico'],
      );

      final id = await ReviewService(
        firestore: db,
      ).findReviewableServiceId(uid, taller);

      expect(id, isNull);
    },
  );

  // El caso que motiva el acotado: el historial del propietario puede ser
  // enorme y casi todo de OTROS talleres. La respuesta no cambia; lo que
  // cambia es cuanto hay que leer para darla.
  test('no se confunde con un historial largo de otros talleres', () async {
    final db = await conHistorial(
      serviciosDeOtrosTalleres: 120,
      propios: [(id: 'elBueno', dia: 5, taller: taller)],
    );

    final id = await ReviewService(
      firestore: db,
    ).findReviewableServiceId(uid, taller);

    expect(id, 'elBueno');
  });

  test('devuelve null si el propietario no tiene vehiculos', () async {
    final db = FakeFirebaseFirestore();

    final id = await ReviewService(
      firestore: db,
    ).findReviewableServiceId(uid, taller);

    expect(id, isNull);
  });

  /// Gap 6 del §5 de `GAPS-05-drenaje.md`: con mas de 30 vehiculos, el
  /// `whereIn` se parte en tandas y el bucle devolvia el primer no resenado de
  /// la PRIMERA tanda que tuviera alguno — no el mas reciente de todos. Cada
  /// tanda viene ordenada por fecha, pero entre tandas no hay orden ninguno,
  /// asi que la funcion ofrecia resenar un servicio viejo teniendo uno nuevo
  /// sin resenar. Nadie lo veia porque hasta 30 vehiculos solo hay una tanda.
  test('con mas de 30 vehiculos devuelve el mas reciente GLOBAL', () async {
    final db = FakeFirebaseFirestore();
    // 31 vehiculos: ids con cero a la izquierda para que el orden por
    // `__name__` sea el que se espera y `veh-30` caiga en la segunda tanda.
    for (var i = 0; i <= 30; i += 1) {
      await db
          .collection('vehiculos')
          .doc('veh-${i.toString().padLeft(2, '0')}')
          .set({'id_propietario': uid, 'placa': 'ABC$i'});
    }
    // El VIEJO va en la primera tanda; el RECIENTE, en la segunda.
    await db.collection('servicios').doc('elViejo').set({
      'id_vehiculo': 'veh-00',
      'id_taller': taller,
      'fecha': Timestamp.fromDate(DateTime(2026, 1, 2)),
    });
    await db.collection('servicios').doc('elReciente').set({
      'id_vehiculo': 'veh-30',
      'id_taller': taller,
      'fecha': Timestamp.fromDate(DateTime(2026, 6, 20)),
    });

    final id = await ReviewService(
      firestore: db,
    ).findReviewableServiceId(uid, taller);

    expect(
      id,
      'elReciente',
      reason:
          'Devolver el de la primera tanda ofrece resenar lo viejo '
          'teniendo lo nuevo sin resenar.',
    );
  });
}
