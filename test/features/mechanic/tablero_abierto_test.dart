import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/models/reparacion_model.dart';
import 'package:autodoc/features/mechanic/data/repositories/reparacion_repository.dart';

import '../../support/fake_functions.dart';
import '../../support/sembrar_reparacion.dart';

/// Gap 9.1: el tope del tablero acotaba **documentos, no lecturas**.
///
/// `watchReparacionesActivas` era `whereIn` de 5 estados + `orderBy` +
/// `limit(200)`. Firestore ejecuta un `in` como N subconsultas y aplica el
/// límite **a cada una** antes de fusionar: hasta 1000 documentos leídos para
/// devolver 200, en cada `attach` del listener. El tope existía, pero no era
/// el que parecía — y el riesgo real era creérselo.
///
/// El cierre es denormalizar `abierto` en el ticket y preguntar por una
/// igualdad, que lee exactamente el tope. Eso mueve el problema a mantener el
/// campo coherente con `estado`, que es lo que fijan estos tests por el lado
/// del cliente; la regla que lo ata en el servidor está en
/// `test_rules/reparaciones_abierto.test.js`, y los tres escritores
/// server-side en `functions/test/`.
void main() {
  const idTaller = 't1';

  ReparacionRepository repo(FirebaseFirestore db) => ReparacionRepository(
    firestore: db,
    functions: FakeFunctions(alLlamar: (_, _) => null),
  );

  test('el ticket nace con `abierto` en true', () async {
    final db = FakeFirebaseFirestore();
    final id = await sembrarReparacion(
      db,
      idVehiculo: 'v1',
      idTaller: idTaller,
      idPropietario: 'p1',
      placa: 'ABC123',
    );

    final doc = await db.collection('reparaciones').doc(id).get();
    expect(doc.data()!['abierto'], isTrue);
  });

  test('cerrar el ticket pone `abierto` en false', () async {
    final db = FakeFirebaseFirestore();
    final id = await sembrarReparacion(
      db,
      idVehiculo: 'v1',
      idTaller: idTaller,
      idPropietario: 'p1',
      placa: 'ABC123',
      estado: 'listo_para_entrega',
    );

    await repo(db).cambiarEstado(idReparacion: id, nuevoEstado: 'entregado');

    final doc = await db.collection('reparaciones').doc(id).get();
    expect(doc.data()!['estado'], 'entregado');
    expect(
      doc.data()!['abierto'],
      isFalse,
      reason:
          'si `abierto` no sigue al estado, el ticket entregado se queda en '
          'el tablero para siempre',
    );
  });

  test('avanzar de columna lo deja en true', () async {
    final db = FakeFirebaseFirestore();
    final id = await sembrarReparacion(
      db,
      idVehiculo: 'v1',
      idTaller: idTaller,
      idPropietario: 'p1',
      placa: 'ABC123',
    );

    await repo(db).cambiarEstado(idReparacion: id, nuevoEstado: 'en_revision');

    final doc = await db.collection('reparaciones').doc(id).get();
    expect(doc.data()!['abierto'], isTrue);
  });

  test('cancelar también cierra el ticket', () async {
    final db = FakeFirebaseFirestore();
    final id = await sembrarReparacion(
      db,
      idVehiculo: 'v1',
      idTaller: idTaller,
      idPropietario: 'p1',
      placa: 'ABC123',
    );

    await repo(db).cambiarEstado(idReparacion: id, nuevoEstado: 'cancelado');

    final doc = await db.collection('reparaciones').doc(id).get();
    expect(doc.data()!['abierto'], isFalse);
  });

  test('el tablero pregunta por `abierto`, no por la lista de estados', () async {
    final db = FakeFirebaseFirestore();
    await sembrarReparacion(
      db,
      idVehiculo: 'v1',
      idTaller: idTaller,
      idPropietario: 'p1',
      placa: 'ABC123',
    );
    // Ticket incoherente a propósito: estado de columna viva, `abierto` en
    // false. La regla de Firestore impide escribirlo (ver
    // `test_rules/reparaciones_abierto.test.js`), y aquí se fabrica a mano
    // precisamente porque es lo único que distingue las dos consultas: con el
    // `whereIn` sobre `estado` este documento SALDRÍA.
    await db.collection('reparaciones').doc('incoherente').set({
      'id_reparacion': 'incoherente',
      'id_vehiculo': 'v2',
      'id_taller': idTaller,
      'id_propietario': 'p1',
      'placa': 'XYZ999',
      'estado': 'en_revision',
      'abierto': false,
      'historial_estados': <Map<String, dynamic>>[],
      'fecha_creacion': Timestamp.fromDate(DateTime(2026, 1, 1)),
      'fecha_actualizacion': Timestamp.fromDate(DateTime(2026, 1, 2)),
    });

    final activas = await repo(db).watchReparacionesActivas(idTaller).first;

    expect(activas.map((r) => r.idVehiculo), contains('v1'));
    expect(
      activas.map((r) => r.idVehiculo),
      isNot(contains('v2')),
      reason:
          'el filtro tiene que ser la igualdad sobre `abierto`: es lo que hace '
          'que el limit acote LECTURAS y no solo documentos',
    );
  });

  test('el tablero sigue acotado al tope', () async {
    final db = FakeFirebaseFirestore();
    for (var i = 0; i < maxTicketsTablero + 5; i += 1) {
      await sembrarReparacion(
        db,
        idVehiculo: 'v$i',
        idTaller: idTaller,
        idPropietario: 'p1',
        placa: 'ABC$i',
        ahora: DateTime(2026, 1, 1).add(Duration(days: maxTicketsTablero - i)),
      );
    }

    final activas = await repo(db).watchReparacionesActivas(idTaller).first;

    expect(activas, hasLength(maxTicketsTablero));
    expect(activas.first.idVehiculo, 'v0');
  });
}
