import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:autodoc/core/services/push_notification_service.dart';
import '../../helpers/test_helpers.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PushNotificationService Tests', () {
    test('updateUserToken updates token in Firestore', () async {
      final mockMessaging = MockFirebaseMessaging();
      final mockFirestore = MockFirebaseFirestore();

      final mockCollection = MockCollectionReference<Map<String, dynamic>>();
      final mockDoc = MockDocumentReference<Map<String, dynamic>>();

      when(mockMessaging.getToken()).thenAnswer((_) async => 'test_token');
      when(mockFirestore.collection('Usuarios')).thenReturn(mockCollection);
      when(mockCollection.doc('user123')).thenReturn(mockDoc);
      when(mockDoc.set(any, any)).thenAnswer((_) async {});

      final service = PushNotificationService(
        messaging: mockMessaging,
        firestore: mockFirestore,
      );

      await service.updateUserToken('user123');

      verify(mockFirestore.collection('Usuarios')).called(1);
      verify(mockCollection.doc('user123')).called(1);
      verify(mockDoc.set({'fcmToken': 'test_token'}, any)).called(1);
    });
  });
}
