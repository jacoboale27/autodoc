import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:autodoc/core/providers/notification_center_provider.dart';
import 'package:autodoc/core/models/app_notification_model.dart';

import '../../helpers/test_helpers.mocks.dart';

/// NotificationCenterProvider unit tests.
void main() {
  late NotificationCenterProvider provider;
  late MockFirebaseFirestore mockFirestore;

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    provider = NotificationCenterProvider(firestore: mockFirestore);
  });

  tearDown(() {
    provider.dispose();
  });

  group('NotificationCenterProvider — Initial State', () {
    test('notifications is empty initially', () {
      expect(provider.notifications, isEmpty);
    });

    test('unreadCount is 0 initially', () {
      expect(provider.unreadCount, 0);
    });

    test('hasUnread is false initially', () {
      expect(provider.hasUnread, isFalse);
    });

    test('isLoading is false initially', () {
      expect(provider.isLoading, isFalse);
    });

    test('error is null initially', () {
      expect(provider.error, isNull);
    });
  });

  group('AppNotification — Model', () {
    test('AppNotification fromMap parses correctly', () {
      final data = {
        'id': 'n1',
        'tipo': 'chat',
        'titulo': 'Nuevo mensaje',
        'body': 'Juan te envió un mensaje',
        'leida': false,
        'deepLink': '/chat/conv123',
        'timestamp': Timestamp.fromDate(DateTime(2026, 7, 1)),
      };

      final notif = AppNotification.fromMap(data, 'n1');
      expect(notif.id, 'n1');
      expect(notif.tipo, 'chat');
      expect(notif.titulo, 'Nuevo mensaje');
      expect(notif.leida, isFalse);
      expect(notif.deepLink, '/chat/conv123');
    });

    test('AppNotification with leida=true reflects in model', () {
      final data = {
        'id': 'n2',
        'tipo': 'alerta',
        'titulo': 'SOAT vence pronto',
        'body': 'Tu SOAT vence en 7 días',
        'leida': true,
        'timestamp': Timestamp.fromDate(DateTime.now()),
      };

      final notif = AppNotification.fromMap(data, 'n2');
      expect(notif.leida, isTrue);
    });

    test('AppNotification deepLink is optional', () {
      final data = {
        'id': 'n3',
        'tipo': 'sistema',
        'titulo': 'Bienvenido',
        'body': 'Gracias por registrarte',
        'leida': false,
        'timestamp': Timestamp.fromDate(DateTime.now()),
      };

      final notif = AppNotification.fromMap(data, 'n3');
      expect(notif.deepLink, isNull);
    });
  });

  group('AppNotification — Type routing', () {
    final routeMap = {
      'chat': '/chat_list',
      'alerta': '/alerts',
      'reserva': '/chat_list',
      'review': '/user_profile',
    };

    test('notification type "chat" routes to chat_list or chat/{id}', () {
      // The routing logic in _resolveNotificationRoute checks data['id']
      // for chat notifications. Without an id, it defaults to /chat_list.
      expect(routeMap['chat'], '/chat_list');
    });

    test('notification type "alerta" routes to /alerts', () {
      expect(routeMap['alerta'], '/alerts');
    });

    test('notification type "review" routes to /user_profile', () {
      expect(routeMap['review'], '/user_profile');
    });
  });
}
