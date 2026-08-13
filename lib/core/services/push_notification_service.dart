import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:autodoc/firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    if (!e.toString().contains('duplicate-app')) {
      rethrow;
    }
  }
  debugPrint("Handling a background message: ${message.messageId}");
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
        // `update` (no `set(merge: true)`) a propósito: si el doc de
        // usuarios/{userId} todavía no existe (cuenta recién creada, antes
        // de completar profile_setup), `set(merge: true)` lo CREARÍA con
        // solo `fcmToken`, y ese doc a medio llenar hacía que
        // UserService.getUserData() lo tratara como perfil ya existente
        // (UserModel.fromMap rellena rol='Propietario', estado='pendiente',
        // nombre/correo vacíos) — saltándose profile_setup y mandando al
        // usuario nuevo directo al dashboard con datos bugueados. `update`
        // falla en silencio (not-found) si el doc no existe todavía; el
        // token se guarda en el siguiente updateUserToken tras el login,
        // una vez profile_setup ya creó el doc real.
        await _firestore.collection('usuarios').doc(userId).update({
          'fcmToken': token,
        });
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
