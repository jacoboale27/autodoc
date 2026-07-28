import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:autodoc/core/providers/auth_session_provider.dart';
import 'package:autodoc/core/services/push_notification_service.dart';
import '../../helpers/test_helpers.mocks.dart';

class FakePushNotificationService extends Fake implements PushNotificationService {
  bool updateUserTokenCalled = false;
  String? updatedUserId;

  @override
  Future<void> updateUserToken(String userId) async {
    updateUserTokenCalled = true;
    updatedUserId = userId;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthSessionProvider Tests', () {
    test('updates FCM token on user login', () async {
      final mockAuth = MockFirebaseAuth();
      final fakePushService = FakePushNotificationService();
      
      PushNotificationService.setInstanceForTesting(fakePushService);

      final streamController = StreamController<User?>.broadcast();
      when(mockAuth.idTokenChanges()).thenAnswer((_) => streamController.stream);

      final provider = AuthSessionProvider(firebaseAuth: mockAuth);
      
      final mockUser = MockUser();
      when(mockUser.uid).thenReturn('user123');
      
      streamController.add(mockUser);
      
      await Future.delayed(Duration.zero);

      expect(provider.isLoggedIn, true);
      expect(fakePushService.updateUserTokenCalled, true);
      expect(fakePushService.updatedUserId, 'user123');
      
      streamController.close();
    });

    test('does not update FCM token on user logout', () async {
      final mockAuth = MockFirebaseAuth();
      final fakePushService = FakePushNotificationService();
      
      PushNotificationService.setInstanceForTesting(fakePushService);

      final streamController = StreamController<User?>.broadcast();
      when(mockAuth.idTokenChanges()).thenAnswer((_) => streamController.stream);

      final provider = AuthSessionProvider(firebaseAuth: mockAuth);
      
      streamController.add(null);
      
      await Future.delayed(Duration.zero);

      expect(provider.isLoggedIn, false);
      expect(fakePushService.updateUserTokenCalled, false);
      
      streamController.close();
    });
  });
}
