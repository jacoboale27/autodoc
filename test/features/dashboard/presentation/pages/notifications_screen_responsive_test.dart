import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/core/models/app_notification_model.dart';
import 'package:autodoc/core/providers/notification_center_provider.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/core/widgets/app_empty_state.dart';
import 'package:autodoc/features/dashboard/presentation/pages/notifications_screen.dart';

import '../../../../support/responsive_harness.dart';
import '../../../../support/shell_harness.dart';

/// Doble mínimo: extiende el provider real y solo fija la lista.
///
/// El constructor por defecto de NotificationCenterProvider cae en
/// FirebaseFirestore.instance, que lanza sin Firebase.initializeApp(); se le
/// pasa un FakeFirebaseFirestore para evitarlo.
class _FakeNotifProvider extends NotificationCenterProvider {
  _FakeNotifProvider(this._items) : super(firestore: FakeFirebaseFirestore());
  final List<AppNotification> _items;

  @override
  List<AppNotification> get notifications => _items;
  @override
  bool get isLoading => false;
  @override
  bool get hasUnread => _items.any((n) => !n.leida);
  @override
  int get unreadCount => _items.where((n) => !n.leida).length;
}

AppNotification _notif(String id, {bool leida = false}) => AppNotification(
  id: id,
  titulo: 'Servicio completado en tu Toyota Corolla',
  body: 'El taller Mecánica Central registró un cambio de aceite.',
  tipo: 'review',
  timestamp: DateTime(2026, 8, 1),
  leida: leida,
);

Future<void> pumpScreen(
  WidgetTester tester,
  double width, {
  List<AppNotification>? items,
  Brightness brightness = Brightness.light,
}) async {
  await pumpAtWidth(
    tester,
    MultiProvider(
      providers: [
        ChangeNotifierProvider<NotificationCenterProvider>.value(
          value: _FakeNotifProvider(items ?? [_notif('n1')]),
        ),
        ChangeNotifierProvider<UserProfileProvider>.value(
          value: FakeProfileProvider('Propietario'),
        ),
      ],
      child: const NotificationsScreen(),
    ),
    width: width,
    brightness: brightness,
  );
  await tester.pump();
}

void main() {
  test('no tiene colores literales', () {
    final source = File(
      'lib/features/dashboard/presentation/pages/notifications_screen.dart',
    ).readAsStringSync();
    final offenders = <String>[];
    final lines = source.split('\n');
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].trimLeft().startsWith('//')) continue;
      if (lines[i].contains('Colors.transparent')) continue;
      if (RegExp(
        r'Color\(0x[0-9a-fA-F]{8}\)|Colors\.(white|black|grey)',
      ).hasMatch(lines[i])) {
        offenders.add('${i + 1}: ${lines[i].trim()}');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  testWidgets('la lista se acota a la medida de lectura en desktop', (
    tester,
  ) async {
    await pumpScreen(tester, 1440);

    final tileWidth = tester.getSize(find.byType(Dismissible).first).width;
    expect(
      tileWidth,
      lessThanOrEqualTo(AppBreakpoints.maxReadingWidth),
      reason: 'el tile mide ${tileWidth}px de ancho: ilegible',
    );
  });

  testWidgets('usa AppEmptyState cuando no hay notificaciones', (tester) async {
    await pumpScreen(tester, 375, items: []);
    expect(find.byType(AppEmptyState), findsOneWidget);
  });

  testWidgets('cada notificación se anuncia como una unidad', (tester) async {
    await pumpScreen(tester, 375);

    expect(
      find.bySemanticsLabel(RegExp('Servicio completado en tu Toyota Corolla')),
      findsWidgets,
    );
  });

  testWidgets('una notificación sin leer lo dice, no solo lo pinta', (
    tester,
  ) async {
    await pumpScreen(tester, 375, items: [_notif('n1')]);

    expect(
      find.bySemanticsLabel(RegExp('[Ss]in leer')),
      findsWidgets,
      reason: 'el estado "sin leer" solo se comunica con un punto de color',
    );
  });

  testWidgets('no desborda en ningún ancho de auditoría, en ambos temas', (
    tester,
  ) async {
    for (final brightness in Brightness.values) {
      await forEachAuditWidth(tester, (width) async {
        await pumpScreen(tester, width, brightness: brightness);
        expectNoOverflow(tester);
      });
    }
  });
}
