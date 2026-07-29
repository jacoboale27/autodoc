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
  void update(DocumentReference document, Map<Object, Object?> data) {}

  @override
  Future<void> commit() async {
    isCommitted = true;
  }
}

void main() {
  late MockFirebaseFirestore mockFirestore;
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

    vehicleService = VehicleService(firestore: mockFirestore);
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
  });
}
