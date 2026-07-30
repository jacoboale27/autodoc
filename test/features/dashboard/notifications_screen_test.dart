import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/models/app_notification_model.dart';
import 'package:autodoc/features/dashboard/presentation/pages/notifications_screen.dart';

// Importante 2 de la revision de la Tarea 12: los documentos de
// notificacion escritos ANTES de que /reserva_detail empezara a exigir un
// id en la ruta siguen teniendo `deepLink: '/reserva_detail'` a secas en
// Firestore. Sin normalizar ese valor legado, tocar la notificacion cae en
// el 404 del router en vez de abrir la reserva.
void main() {
  group('normalizeDeepLink', () {
    test(
      'reescribe el deepLink legado /reserva_detail usando metadata.reservaId',
      () {
        final notif = AppNotification(
          id: 'n1',
          tipo: 'reserva',
          titulo: 'Reserva Confirmada',
          body: 'body',
          deepLink: '/reserva_detail',
          timestamp: DateTime.now(),
          metadata: const {'reservaId': 'r-123'},
        );

        expect(normalizeDeepLink(notif), '/reserva_detail/r-123');
      },
    );

    test('redirige a una ruta segura si el deepLink legado no trae '
        'reservaId en metadata', () {
      final notif = AppNotification(
        id: 'n2',
        tipo: 'reserva',
        titulo: 'Reserva Confirmada',
        body: 'body',
        deepLink: '/reserva_detail',
        timestamp: DateTime.now(),
        metadata: null,
      );

      expect(normalizeDeepLink(notif), '/chat_list');
    });

    test('no toca deepLinks que ya no dependen de un id (p. ej. /alerts)', () {
      final notif = AppNotification(
        id: 'n3',
        tipo: 'alerta',
        titulo: 'Alerta',
        body: 'body',
        deepLink: '/alerts',
        timestamp: DateTime.now(),
      );

      expect(normalizeDeepLink(notif), '/alerts');
    });

    test(
      'no toca un deepLink /reserva_detail/:id ya nuevo (con id incluido)',
      () {
        final notif = AppNotification(
          id: 'n4',
          tipo: 'reserva',
          titulo: 'Reserva Confirmada',
          body: 'body',
          deepLink: '/reserva_detail/r-456',
          timestamp: DateTime.now(),
        );

        expect(normalizeDeepLink(notif), '/reserva_detail/r-456');
      },
    );
  });
}
