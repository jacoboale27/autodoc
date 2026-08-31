import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:mockito/mockito.dart';
import 'package:autodoc/core/models/vehicle_model.dart';
import 'package:autodoc/features/dashboard/presentation/providers/alert_provider.dart';
import '../../../../helpers/test_helpers.mocks.dart';

void main() {
  test(
    'fetchAlertsForVehicles merges alerts from every vehicle instead of replacing them',
    () async {
      final firestore = FakeFirebaseFirestore();

      await firestore.collection('alertas').add({
        'id_vehiculo': 'v1',
        'estado': 'Pendiente',
        'titulo': 'SOAT vence pronto',
      });
      await firestore.collection('alertas').add({
        'id_vehiculo': 'v2',
        'estado': 'Pendiente',
        'titulo': 'Cambio de aceite',
      });

      final provider = AlertProvider(
        firestore: firestore,
        storage: MockFirebaseStorage(),
      );
      final v1 = VehicleModel(
        idVehiculo: 'v1',
        idPropietario: 'owner-1',
        placa: 'P111-111',
        marca: 'Toyota',
        modelo: 'Corolla',
        kilometrajeActual: 10000,
      );
      final v2 = VehicleModel(
        idVehiculo: 'v2',
        idPropietario: 'owner-1',
        placa: 'P222-222',
        marca: 'Honda',
        modelo: 'Civic',
        kilometrajeActual: 20000,
      );

      await provider.fetchAlertsForVehicles([v1, v2]);

      // Both vehicles' manually-created Firestore alerts must survive the
      // merge — if fetchAlertsForVehicles regressed to replace semantics
      // (e.g. only kept the last vehicle's alerts), v1's alert would be
      // gone here.
      final titles = provider.activeAlerts.map((a) => a.titulo).toSet();
      expect(titles, containsAll({'SOAT vence pronto', 'Cambio de aceite'}));

      // Alerts for every requested vehicle are present, proving accumulation
      // across the loop rather than a single-vehicle replace.
      expect(provider.activeAlerts.map((a) => a.idVehiculo).toSet(), {
        'v1',
        'v2',
      });

      // Each vehicle's own manual alert must be attributed to that vehicle,
      // not merged/cross-assigned.
      final v1Alert = provider.activeAlerts.firstWhere(
        (a) => a.titulo == 'SOAT vence pronto',
      );
      expect(v1Alert.idVehiculo, 'v1');
      final v2Alert = provider.activeAlerts.firstWhere(
        (a) => a.titulo == 'Cambio de aceite',
      );
      expect(v2Alert.idVehiculo, 'v2');
    },
  );

  test('fetchAlertsForVehicles does not duplicate a previous vehicle\'s alerts '
      'when a later vehicle\'s fetch fails', () async {
    final mockFirestore = MockFirebaseFirestore();
    final mockAlertsCollection =
        MockCollectionReference<Map<String, dynamic>>();
    final mockMantCollection = MockCollectionReference<Map<String, dynamic>>();

    final mockAlertsQueryV1 = MockQuery<Map<String, dynamic>>();
    final mockAlertsQueryV2 = MockQuery<Map<String, dynamic>>();
    final mockMantQueryV1 = MockQuery<Map<String, dynamic>>();

    final mockAlertsSnapshotV1 = MockQuerySnapshot<Map<String, dynamic>>();
    final mockAlertsDocV1 = MockQueryDocumentSnapshot<Map<String, dynamic>>();
    final mockMantSnapshotV1 = MockQuerySnapshot<Map<String, dynamic>>();
    final mockMantDocV1 = MockQueryDocumentSnapshot<Map<String, dynamic>>();

    when(mockFirestore.collection('alertas')).thenReturn(mockAlertsCollection);
    when(
      mockFirestore.collection('mantenimientos'),
    ).thenReturn(mockMantCollection);

    // v1: succeeds — one manual alert, one existing maintenance task (so
    // fetchAlerts doesn't need to hit createDefaultTasks/batch()).
    when(
      mockAlertsCollection.where('id_vehiculo', isEqualTo: 'v1'),
    ).thenReturn(mockAlertsQueryV1);
    when(mockAlertsQueryV1.get()).thenAnswer((_) async => mockAlertsSnapshotV1);
    when(mockAlertsSnapshotV1.docs).thenReturn([mockAlertsDocV1]);
    when(mockAlertsDocV1.id).thenReturn('alert-v1');
    when(mockAlertsDocV1.data()).thenReturn({
      'id_vehiculo': 'v1',
      'estado': 'Pendiente',
      'titulo': 'SOAT vence pronto',
    });

    when(
      mockMantCollection.where('id_vehiculo', isEqualTo: 'v1'),
    ).thenReturn(mockMantQueryV1);
    when(mockMantQueryV1.get()).thenAnswer((_) async => mockMantSnapshotV1);
    when(mockMantSnapshotV1.docs).thenReturn([mockMantDocV1]);
    when(mockMantDocV1.id).thenReturn('task-v1');
    when(mockMantDocV1.data()).thenReturn({
      'id_vehiculo': 'v1',
      'nombre': 'Cambio de Aceite',
      'ultimo_km': 1000,
      'fecha_ultimo_servicio': Timestamp.fromDate(DateTime(2020, 1, 1)),
      'frecuencia_km': 5000,
      'frecuencia_meses': 6,
    });

    // v2: fails at the very first Firestore call inside fetchAlerts —
    // before `_alerts`/`_maintenanceTasks` get reassigned for v2.
    when(
      mockAlertsCollection.where('id_vehiculo', isEqualTo: 'v2'),
    ).thenReturn(mockAlertsQueryV2);
    when(mockAlertsQueryV2.get()).thenThrow(Exception('Firestore boom'));

    final provider = AlertProvider(
      firestore: mockFirestore,
      storage: MockFirebaseStorage(),
    );
    final v1 = VehicleModel(
      idVehiculo: 'v1',
      idPropietario: 'owner-1',
      placa: 'P111-111',
      marca: 'Toyota',
      modelo: 'Corolla',
      kilometrajeActual: 10000,
    );
    final v2 = VehicleModel(
      idVehiculo: 'v2',
      idPropietario: 'owner-1',
      placa: 'P222-222',
      marca: 'Honda',
      modelo: 'Civic',
      kilometrajeActual: 20000,
    );

    await provider.fetchAlertsForVehicles([v1, v2]);

    // v1's manual alert must appear exactly once — not duplicated by the
    // failed v2 iteration re-adding v1's leftover `_alerts`.
    final soatAlerts = provider.alerts.where(
      (a) => a.titulo == 'SOAT vence pronto',
    );
    expect(soatAlerts.length, 1);

    // The failure must still be surfaced.
    expect(provider.error, isNotNull);
  });

  test('fetchAlertsForVehicles conserva las tareas de mantenimiento de TODOS '
      'los vehiculos, no solo las del ultimo procesado', () async {
    final firestore = FakeFirebaseFirestore();

    // Una tarea propia por vehiculo, ya existente, para que fetchAlerts
    // no entre en createDefaultTasks.
    await firestore.collection('mantenimientos').add({
      'id_vehiculo': 'v1',
      'nombre': 'Cambio de Aceite',
      'ultimo_km': 9000,
      'fecha_ultimo_servicio': Timestamp.fromDate(DateTime.now()),
      'frecuencia_km': 5000,
      'frecuencia_meses': 6,
    });
    await firestore.collection('mantenimientos').add({
      'id_vehiculo': 'v2',
      'nombre': 'Rotacion de Llantas',
      'ultimo_km': 19000,
      'fecha_ultimo_servicio': Timestamp.fromDate(DateTime.now()),
      'frecuencia_km': 10000,
      'frecuencia_meses': 12,
    });

    final provider = AlertProvider(
      firestore: firestore,
      storage: MockFirebaseStorage(),
    );
    // 'v1' es el PRIMARIO (el que VehicleProvider selecciona) y 'v2' el
    // ultimo procesado por el bucle. Los consumidores filtran
    // `maintenanceTasks` por el vehiculo seleccionado: si la lista se
    // queda solo con las del ultimo procesado, ese filtro da vacio y la
    // pantalla se apaga.
    final v1 = VehicleModel(
      idVehiculo: 'v1',
      idPropietario: 'owner-1',
      placa: 'P111-111',
      marca: 'Toyota',
      modelo: 'Corolla',
      kilometrajeActual: 10000,
      isPrimary: true,
    );
    final v2 = VehicleModel(
      idVehiculo: 'v2',
      idPropietario: 'owner-1',
      placa: 'P222-222',
      marca: 'Honda',
      modelo: 'Civic',
      kilometrajeActual: 20000,
    );

    await provider.fetchAlertsForVehicles([v1, v2]);

    expect(
      provider.maintenanceTasks.map((t) => t.vehicleId).toSet(),
      {'v1', 'v2'},
      reason:
          'las tareas del vehiculo primario no pueden desaparecer solo '
          'porque no fue el ultimo del bucle',
    );

    // Y el filtro que aplican dashboard_screen/alerts_screen sobre el
    // vehiculo seleccionado debe encontrar algo.
    expect(
      provider.maintenanceTasks
          .where((t) => t.vehicleId == v1.idVehiculo)
          .map((t) => t.nombre),
      contains('Cambio de Aceite'),
    );
  });
}
