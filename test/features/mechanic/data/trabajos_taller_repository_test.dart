// Revisión del 2026-09-19 de "Mis Servicios" y del cierre de servicio.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/features/mechanic/data/repositories/trabajos_taller_repository.dart';

Future<void> _cotizacion(
  FakeFirebaseFirestore db,
  String id, {
  required String estado,
  required DateTime fecha,
  String idTaller = 't1',
}) => db.collection('cotizaciones').doc(id).set({
  'id_taller': idTaller,
  'id_mecanico': idTaller,
  'id_propietario': 'p1',
  'id_vehiculo': 'v1',
  'estado': estado,
  'fecha': Timestamp.fromDate(fecha),
  'items': const [],
});

void main() {
  test(
    'un trabajo en proceso antiguo no se cae de la lista por el tope',
    () async {
      final db = FakeFirebaseFirestore();
      // La aceptada es la MÁS VIEJA; encima, más cotizaciones que el tope.
      await _cotizacion(
        db,
        'vieja',
        estado: 'aceptada',
        fecha: DateTime(2025, 1, 1),
      );
      for (var i = 0; i < maxTrabajosTaller + 5; i++) {
        await _cotizacion(
          db,
          'c$i',
          estado: 'finalizada',
          fecha: DateTime(2026, 1, 1).add(Duration(hours: i)),
        );
      }
      await _cotizacion(
        db,
        'ajena',
        estado: 'aceptada',
        fecha: DateTime(2025, 1, 2),
        idTaller: 't2',
      );

      final lista = await TrabajosTallerRepository(
        firestore: db,
      ).watchCotizacionesDelTaller('t1').first;

      expect(lista.map((c) => c.id), contains('vieja'));
      expect(lista.map((c) => c.id), isNot(contains('ajena')));
      expect(
        lista.map((c) => c.id).toSet(),
        hasLength(lista.length),
        reason: 'sin duplicados',
      );
      expect(
        lista.first.fecha.isAfter(lista.last.fecha),
        isTrue,
        reason: 'más nueva primero',
      );
    },
  );

  test('los borradores no salen', () async {
    final db = FakeFirebaseFirestore();
    await _cotizacion(db, 'b', estado: 'draft', fecha: DateTime(2026, 9, 1));
    await _cotizacion(
      db,
      'p',
      estado: 'pendiente',
      fecha: DateTime(2026, 9, 2),
    );
    final lista = await TrabajosTallerRepository(
      firestore: db,
    ).watchCotizacionesDelTaller('t1').first;
    expect(lista.map((c) => c.id), ['p']);
  });

  test('marcar finalizadas va en UN lote (todo o nada)', () async {
    // `FakeFirebaseFirestore` aplica un lote paso a paso, así que no puede
    // demostrar la atomicidad: eso lo garantiza Firestore. Lo que sí se
    // afirma es que todo pasa por un solo lote y no por updates sueltos.
    final db = _Espia();
    await _cotizacion(
      db,
      'a1',
      estado: 'aceptada',
      fecha: DateTime(2026, 9, 1),
    );
    await _cotizacion(
      db,
      'a2',
      estado: 'aceptada',
      fecha: DateTime(2026, 9, 2),
    );

    await TrabajosTallerRepository(
      firestore: db,
    ).marcarFinalizadas(['a1', 'a2']);

    expect(db.lotes, 1);
    for (final id in ['a1', 'a2']) {
      final doc = await db.collection('cotizaciones').doc(id).get();
      expect(doc.data()!['estado'], 'finalizada');
    }
  });
}

class _Espia extends FakeFirebaseFirestore {
  int lotes = 0;

  @override
  WriteBatch batch() {
    lotes++;
    return super.batch();
  }
}
