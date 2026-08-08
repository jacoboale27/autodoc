import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
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
}
