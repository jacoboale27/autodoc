import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/providers/auth_session_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mockito/mockito.dart';
import 'package:autodoc/core/services/push_notification_service.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {
  final StreamController<User?> _controller = StreamController<User?>.broadcast();
  
  @override
  Stream<User?> idTokenChanges() => _controller.stream;

  void emitUser(User? user) {
    _controller.add(user);
  }
}

class MockUser extends Mock implements User {
  @override
  String get uid => 'user123';
}

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

      final provider = AuthSessionProvider(firebaseAuth: mockAuth);
      
      final mockUser = MockUser();
      mockAuth.emitUser(mockUser);
      
      await Future.delayed(Duration.zero);

      expect(provider.isLoggedIn, true);
      expect(fakePushService.updateUserTokenCalled, true);
      expect(fakePushService.updatedUserId, 'user123');
    });

    test('does not update FCM token on user logout', () async {
      final mockAuth = MockFirebaseAuth();
      final fakePushService = FakePushNotificationService();
      
      PushNotificationService.setInstanceForTesting(fakePushService);

      final provider = AuthSessionProvider(firebaseAuth: mockAuth);
      
      mockAuth.emitUser(null);
      
      await Future.delayed(Duration.zero);

      expect(provider.isLoggedIn, false);
      expect(fakePushService.updateUserTokenCalled, false);
    });
  });
}
