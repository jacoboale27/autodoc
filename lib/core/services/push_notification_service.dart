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
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
