// test/features/dashboard/presentation/providers/alert_provider_default_tasks_test.dart
//
// `createDefaultTasks` escribia cada tarea con `collection().doc()` — id
// aleatorio — asi que CADA llamada creaba un juego completo de ocho. Y se
// llama mas de una vez por diseno: al anadir el vehiculo y otra vez desde
// `fetchAlerts` siempre que la lista salga vacia, que es exactamente lo que
// pasa mientras la escritura anterior todavia no es visible. De ahi los
// vehiculos con el plan repetido x2, x3, x6 en produccion.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/constants/firestore_collections.dart';
import 'package:autodoc/core/constants/maintenance_defaults.dart';
import 'package:autodoc/features/dashboard/presentation/providers/alert_provider.dart';

import '../../../../helpers/test_helpers.mocks.dart';

void main() {
  late FakeFirebaseFirestore db;
  late AlertProvider provider;

  setUp(() {
    db = FakeFirebaseFirestore();
    provider = AlertProvider(firestore: db, storage: MockFirebaseStorage());
  });

  Future<List<Map<String, dynamic>>> tareasDe(String vehicleId) async {
    final snap = await db
        .collection(FirestoreCollections.mantenimientos)
        .where('id_vehiculo', isEqualTo: vehicleId)
        .get();
    return snap.docs.map((d) => d.data()).toList();
  }

  test('siembra el plan completo la primera vez', () async {
    await provider.createDefaultTasks('v1', 1000);

    final tareas = await tareasDe('v1');
    expect(tareas, hasLength(kTareasMantenimientoPorDefecto.length));
    expect(
      tareas.map((t) => t['nombre']).toSet(),
      kTareasMantenimientoPorDefecto.map((t) => t['nombre']).toSet(),
    );
  });

  test('llamarla dos veces NO duplica el plan', () async {
    await provider.createDefaultTasks('v1', 1000);
    await provider.createDefaultTasks('v1', 1000);

    expect(
      await tareasDe('v1'),
      hasLength(kTareasMantenimientoPorDefecto.length),
      reason:
          'cada llamada de mas anadia otras ocho tareas; asi es como los '
          'vehiculos acabaron con el plan repetido x6',
    );
  });

  test('seis llamadas seguidas siguen dejando ocho tareas', () async {
    for (var i = 0; i < 6; i++) {
      await provider.createDefaultTasks('v1', 1000);
    }

    expect(
      await tareasDe('v1'),
      hasLength(kTareasMantenimientoPorDefecto.length),
    );
  });

  test('no pisa el progreso de una tarea que ya existe', () async {
    // El propietario ya hizo el cambio de aceite a los 90 000 km.
    await db
        .collection(FirestoreCollections.mantenimientos)
        .doc(idTareaMantenimiento('v1', 'Cambio de Aceite'))
        .set({
          'id_vehiculo': 'v1',
          'nombre': 'Cambio de Aceite',
          'ultimo_km': 90000,
          'fecha_ultimo_servicio': Timestamp.fromDate(DateTime(2026, 1, 1)),
          'frecuencia_km': 5000,
          'frecuencia_meses': 6,
        });

    await provider.createDefaultTasks('v1', 1000);

    final tareas = await tareasDe('v1');
    expect(tareas, hasLength(kTareasMantenimientoPorDefecto.length));
    final aceite = tareas.firstWhere((t) => t['nombre'] == 'Cambio de Aceite');
    expect(
      aceite['ultimo_km'],
      90000,
      reason:
          'con id determinista, un `set` a ciegas habria devuelto la tarea a '
          '1000 km y borrado un servicio real del historial del propietario',
    );
  });

  test('vehiculos distintos no comparten documentos', () async {
    await provider.createDefaultTasks('v1', 1000);
    await provider.createDefaultTasks('v2', 2000);

    expect(await tareasDe('v1'), hasLength(8));
    expect(await tareasDe('v2'), hasLength(8));
  });

  group('idTareaMantenimiento', () {
    test('es estable y depende del vehiculo y del nombre', () {
      expect(
        idTareaMantenimiento('v1', 'Cambio de Aceite'),
        idTareaMantenimiento('v1', 'Cambio de Aceite'),
      );
      expect(
        idTareaMantenimiento('v1', 'Cambio de Aceite'),
        isNot(idTareaMantenimiento('v2', 'Cambio de Aceite')),
      );
      expect(
        idTareaMantenimiento('v1', 'Cambio de Aceite'),
        isNot(idTareaMantenimiento('v1', 'Filtro de Aire')),
      );
    });

    test('quita acentos y no deja caracteres raros en el id', () {
      expect(idTareaMantenimiento('v1', 'Bujías'), 'v1__bujias');
      expect(
        idTareaMantenimiento('v1', 'Rotación de Llantas'),
        'v1__rotacion_de_llantas',
      );
      // Firestore rechaza '/' en un id de documento.
      for (final tarea in kTareasMantenimientoPorDefecto) {
        final id = idTareaMantenimiento('v1', tarea['nombre'] as String);
        expect(id, isNot(contains('/')));
        expect(id, matches(RegExp(r'^[A-Za-z0-9_-]+$')));
      }
    });
  });
}
