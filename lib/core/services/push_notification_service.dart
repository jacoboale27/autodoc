import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:autodoc/firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Manejando mensaje en background: ${message.messageId}");
}

class PushNotificationService {
  static PushNotificationService? _instance;
  
  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;

  factory PushNotificationService({
    FirebaseMessaging? messaging,
    FirebaseFirestore? firestore,
  }) {
    _instance ??= PushNotificationService._internal(
      messaging ?? FirebaseMessaging.instance,
      firestore ?? FirebaseFirestore.instance,
    );
    return _instance!;
  }

  PushNotificationService._internal(this._messaging, this._firestore);

  @visibleForTesting
  static void setInstanceForTesting(PushNotificationService mock) {
    _instance = mock;
  }

  Future<void> initialize() async {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    try {
      await _messaging
          .requestPermission(alert: true, badge: true, sound: true)
          .timeout(const Duration(seconds: 5));
      debugPrint(
        "=== [PushNotificationService] Permisos de notificación configurados ===",
      );
    } catch (e, stack) {
      debugPrint(
        "=== [PushNotificationService] ERROR en requestPermission: $e ===",
      );
      debugPrint(stack.toString());
    }
  }

  Future<void> updateUserToken(String userId) async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _firestore.collection('Usuarios').doc(userId).set({
          'fcmToken': token,
        }, SetOptions(merge: true));
        debugPrint(
          "=== [PushNotificationService] Token actualizado para el usuario $userId ===",
        );
      }
    } catch (e) {
      debugPrint(
        "=== [PushNotificationService] Error al actualizar token: $e ===",
      );
    }
  }
}
