import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:autodoc/features/dashboard/presentation/providers/alert_provider.dart';
import 'package:autodoc/core/models/vehicle_model.dart';
import '../../helpers/test_helpers.mocks.dart';

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
        when(mockQuery.get()).thenThrow('Firestore error');

        await alertProvider.fetchAlerts('1', vehicle);

        expect(alertProvider.isLoading, false);
        expect(alertProvider.error, contains('Firestore error'));
      },
    );
  });
}
