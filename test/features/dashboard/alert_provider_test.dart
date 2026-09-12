import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:autodoc/features/dashboard/presentation/providers/alert_provider.dart';
import 'package:autodoc/core/models/vehicle_model.dart';
import '../../helpers/test_helpers.mocks.dart';
import 'package:firebase_core/firebase_core.dart';

void main() {
  late MockFirebaseFirestore mockFirestore;
  late MockFirebaseStorage mockStorage;
  late MockCollectionReference<Map<String, dynamic>> mockAlertsCollection;
  late MockQuery<Map<String, dynamic>> mockQuery;

  late AlertProvider alertProvider;

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    mockStorage = MockFirebaseStorage();
    mockAlertsCollection = MockCollectionReference<Map<String, dynamic>>();
    mockQuery = MockQuery<Map<String, dynamic>>();

    alertProvider = AlertProvider(
      firestore: mockFirestore,
      storage: mockStorage,
    );
  });

  group('AlertProvider Tests', () {
    test('initial state is correct', () {
      expect(alertProvider.isLoading, false);
      expect(alertProvider.error, null);
      expect(alertProvider.alerts, isEmpty);
      expect(alertProvider.maintenanceTasks, isEmpty);
    });

    test(
      'fetchAlerts sets loading state and handles error correctly',
      () async {
        final vehicle = VehicleModel(
          idVehiculo: '1',
          idPropietario: 'owner',
          placa: 'ABC',
          marca: 'Toyota',
          modelo: 'Corolla',
          anio: 2020,
        );

        when(
          mockFirestore.collection('alertas'),
        ).thenReturn(mockAlertsCollection);
        when(
          mockAlertsCollection.where('id_vehiculo', isEqualTo: '1'),
        ).thenReturn(mockQuery);
        when(mockQuery.get()).thenThrow(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'unavailable',
            message: 'The service is currently unavailable.',
          ),
        );

        await alertProvider.fetchAlerts('1', vehicle);

        expect(alertProvider.isLoading, false);
        // UX-04: antes se lanzaba la cadena 'Firestore error' y se afirmaba que
        // el provider la contenia, lo que con `_error = e.toString()` pasaba
        // siempre sin probar nada. Lo que llega de verdad es un
        // `FirebaseException`, y de el se estaba pintando el `[cloud_firestore/
        // ...]` entero en pantalla.
        expect(alertProvider.error, isNot(contains('cloud_firestore')));
        expect(alertProvider.error, isNot(contains('unavailable')));
        expect(alertProvider.error, contains('conexion'));
      },
    );
  });
}
