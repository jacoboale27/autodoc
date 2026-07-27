import 'dart:io';
import '../constants/firestore_collections.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Inicializar configuraciones de flutter_local_notifications
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Crear canal de notificaciones para Android (importante para Android 8+)
    if (!kIsWeb && Platform.isAndroid) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'high_importance_channel', // id
        'Notificaciones Importantes', // title
        description: 'Este canal se usa para notificaciones importantes.',
        importance: Importance.max,
      );

      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(channel);
      }
    }

    // Escuchar notificaciones en primer plano
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // Escuchar toques en notificaciones en segundo plano
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

    _isInitialized = true;
  }

  void _onForegroundMessage(RemoteMessage message) {
    debugPrint(
      "Mensaje recibido en primer plano: ${message.notification?.title}",
    );

    final notification = message.notification;
    final android = message.notification?.android;

    if (notification != null && android != null && !kIsWeb) {
      _localNotifications.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'Notificaciones Importantes',
            channelDescription:
                'Este canal se usa para notificaciones importantes.',
            icon: '@mipmap/ic_launcher',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
      );
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint("Notificación local tocada: ${response.payload}");
    // Aquí puedes manejar la navegación si pasaste un payload
  }

  void _onMessageOpenedApp(RemoteMessage message) {
    debugPrint(
      "Notificación de FCM tocada desde segundo plano: ${message.data}",
    );
    // Manejar navegación basada en message.data
  }

  /// Registra el token de FCM en Firestore para el usuario actual
  Future<void> saveUserToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Obtener el token FCM
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        await FirebaseFirestore.instance
            .collection(FirestoreCollections.usuarios)
            .doc(user.uid)
            .update({'fcmToken': token});
        debugPrint("Token FCM guardado en Firestore: $token");
      }

      // Escuchar cambios en el token
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        FirebaseFirestore.instance
            .collection(FirestoreCollections.usuarios)
            .doc(user.uid)
            .update({'fcmToken': newToken});
      });
    } catch (e) {
      debugPrint("Error guardando token FCM: $e");
    }
  }
}
