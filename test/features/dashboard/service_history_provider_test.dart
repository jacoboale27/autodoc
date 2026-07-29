import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:autodoc/features/dashboard/presentation/providers/service_history_provider.dart';
import '../../helpers/test_helpers.mocks.dart';

void main() {
  test('Check that fetchServices uses limit() or startAfter()', () async {
    final mockFirestore = MockFirebaseFirestore();
    final mockCollection = MockCollectionReference<Map<String, dynamic>>();
    final mockQuery = MockQuery<Map<String, dynamic>>();
    final mockSnapshot = MockQuerySnapshot<Map<String, dynamic>>();

    when(mockFirestore.collection(any)).thenReturn(mockCollection);
    when(
      mockCollection.where(any, isEqualTo: anyNamed('isEqualTo')),
    ).thenReturn(mockQuery);
    when(
      mockQuery.orderBy(any, descending: anyNamed('descending')),
    ).thenReturn(mockQuery);
    when(mockQuery.limit(any)).thenReturn(mockQuery);
    when(mockQuery.get()).thenAnswer((_) async => mockSnapshot);
    when(mockSnapshot.docs).thenReturn([]);

    final provider = ServiceHistoryProvider(firestore: mockFirestore);
    await provider.fetchServices('veh-123');

    verify(mockQuery.limit(10)).called(1);
  });
}
