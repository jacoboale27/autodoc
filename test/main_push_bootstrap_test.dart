import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/services/push_notification_service.dart';
import 'package:autodoc/main.dart';

/// Simula el permiso de notificaciones en web: `requestPermission()` no
/// resuelve hasta que el usuario decide, asi que este fake nunca completa
/// su Future, igual que pasaria en un navegador real esperando al usuario.
class _PushQueNuncaResuelve extends Fake implements PushNotificationService {
  @override
  Future<void> initialize() => Completer<void>().future;
}

void main() {
  test('el arranque no espera al permiso de notificaciones', () async {
    final reloj = Stopwatch()..start();
    await startPushNotifications(push: _PushQueNuncaResuelve());
    reloj.stop();

    expect(
      reloj.elapsed,
      lessThan(const Duration(seconds: 1)),
      reason:
          'requestPermission tarda 5 s en expirar en web y estaba en el '
          'camino critico: Firebase quedaba listo a los 2,0 s y runApp no se '
          'lanzaba hasta los 7,0 s',
    );
  });
}
