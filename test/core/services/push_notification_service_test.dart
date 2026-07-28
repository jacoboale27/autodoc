import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/services/push_notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mockito/mockito.dart';

class MockFirebaseMessaging extends Fake implements FirebaseMessaging {
  @override
  Future<String?> getToken({String? vapidKey}) async {
    return 'test_token';
  }
}

class FakeFirebaseFirestore extends Fake implements FirebaseFirestore {
  final Map<String, Map<String, dynamic>> data = {};

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return FakeCollectionReference(this, collectionPath);
  }
}

class FakeCollectionReference extends Fake implements CollectionReference<Map<String, dynamic>> {
  final FakeFirebaseFirestore firestore;
  final String path;

  FakeCollectionReference(this.firestore, this.path);

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    return FakeDocumentReference(firestore, path!);
  }
}

class FakeDocumentReference extends Fake implements DocumentReference<Map<String, dynamic>> {
  final FakeFirebaseFirestore firestore;
  final String docId;

  FakeDocumentReference(this.firestore, this.docId);

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    firestore.data[docId] = data;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PushNotificationService Tests', () {
    test('updateUserToken updates token in Firestore', () async {
      final mockMessaging = MockFirebaseMessaging();
      final fakeFirestore = FakeFirebaseFirestore();

      final service = PushNotificationService(
        messaging: mockMessaging,
        firestore: fakeFirestore,
      );

      await service.updateUserToken('user123');

      expect(fakeFirestore.data['user123'], isNotNull);
      expect(fakeFirestore.data['user123']!['fcmToken'], 'test_token');
    });
  });
}
