import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:autodoc/features/dashboard/data/services/vehicle_service.dart';
import 'package:autodoc/core/constants/firestore_collections.dart';
import '../../../../helpers/test_helpers.mocks.dart';

class FakeWriteBatch implements WriteBatch {
  final List<DocumentReference> deleted = [];
  bool isCommitted = false;

  @override
  void delete(DocumentReference document) {
    deleted.add(document);
  }

  @override
  void set<T>(DocumentReference<T> document, T data, [SetOptions? options]) {}

  @override
  void update<T>(DocumentReference<T> document, T data) {}

  @override
  Future<void> commit() async {
    isCommitted = true;
  }
}

void main() {
  late MockFirebaseFirestore mockFirestore;
  late MockFirebaseFunctions mockFunctions;
  late FakeWriteBatch fakeBatch;
  late MockCollectionReference<Map<String, dynamic>> mockVehiclesCollection;
  late MockCollectionReference<Map<String, dynamic>> mockServiciosCollection;
  late MockCollectionReference<Map<String, dynamic>> mockAlertasCollection;
  late MockDocumentReference<Map<String, dynamic>> mockVehicleDoc;
  late MockQuery<Map<String, dynamic>> mockServiciosQuery;
  late MockQuery<Map<String, dynamic>> mockAlertasQuery;
  late MockQuerySnapshot<Map<String, dynamic>> mockServiciosSnapshot;
  late MockQuerySnapshot<Map<String, dynamic>> mockAlertasSnapshot;

  late VehicleService vehicleService;

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    mockFunctions = MockFirebaseFunctions();
    fakeBatch = FakeWriteBatch();
    mockVehiclesCollection = MockCollectionReference();
    mockServiciosCollection = MockCollectionReference();
    mockAlertasCollection = MockCollectionReference();
    mockVehicleDoc = MockDocumentReference();
    mockServiciosQuery = MockQuery();
    mockAlertasQuery = MockQuery();
    mockServiciosSnapshot = MockQuerySnapshot();
    mockAlertasSnapshot = MockQuerySnapshot();

    when(mockFirestore.batch()).thenReturn(fakeBatch);

    when(
      mockFirestore.collection(FirestoreCollections.vehiculos),
    ).thenReturn(mockVehiclesCollection);
    when(mockVehiclesCollection.doc('v1')).thenReturn(mockVehicleDoc);

    when(
      mockFirestore.collection(FirestoreCollections.servicios),
    ).thenReturn(mockServiciosCollection);
    when(
      mockServiciosCollection.where('id_vehiculo', isEqualTo: 'v1'),
    ).thenReturn(mockServiciosQuery);
    when(
      mockServiciosQuery.get(),
    ).thenAnswer((_) async => mockServiciosSnapshot);
    when(mockServiciosSnapshot.docs).thenReturn([]);

    when(
      mockFirestore.collection(FirestoreCollections.alertas),
    ).thenReturn(mockAlertasCollection);
    when(
      mockAlertasCollection.where('id_vehiculo', isEqualTo: 'v1'),
    ).thenReturn(mockAlertasQuery);
    when(mockAlertasQuery.get()).thenAnswer((_) async => mockAlertasSnapshot);
    when(mockAlertasSnapshot.docs).thenReturn([]);

    vehicleService = VehicleService(
      firestore: mockFirestore,
      functions: mockFunctions,
    );
  });

  group('VehicleService Tests', () {
    test(
      'Check that deleting a vehicle wraps Firestore calls in a WriteBatch',
      () async {
        await vehicleService.deleteVehicle('v1');

        verify(mockFirestore.batch()).called(1);
        expect(
          fakeBatch.deleted.length,
          1,
        ); // Only the vehicle ref, since related are empty
        expect(fakeBatch.deleted.first, mockVehicleDoc);
        expect(fakeBatch.isCommitted, true);
      },
    );

    // Cierre C1 (confirmacion del propietario para talleres_vinculados):
    // confirmarVinculoTaller/rechazarVinculoTaller deben hacer un update
    // parcial del documento, no un toMap() completo.
    test(
      'confirmarVinculoTaller hace un update parcial con arrayUnion y borra el pendiente',
      () async {
        when(mockVehicleDoc.update(any)).thenAnswer((_) async {});

        await vehicleService.confirmarVinculoTaller('v1', 'taller1');

        final captured = verify(mockVehicleDoc.update(captureAny)).captured;
        expect(captured.length, 1);
        final Map<Object, Object?> data = captured.first;
        expect(data.containsKey('talleres_vinculados'), true);
        expect(data['talleres_vinculados'], isA<FieldValue>());
        expect(data['taller_pendiente_confirmacion'], isA<FieldValue>());
      },
    );

    test(
      'rechazarVinculoTaller solo borra taller_pendiente_confirmacion',
      () async {
        when(mockVehicleDoc.update(any)).thenAnswer((_) async {});

        await vehicleService.rechazarVinculoTaller('v1');

        final captured = verify(mockVehicleDoc.update(captureAny)).captured;
        expect(captured.length, 1);
        final Map<Object, Object?> data = captured.first;
        expect(data.length, 1);
        expect(data['taller_pendiente_confirmacion'], isA<FieldValue>());
      },
    );
  });
}
