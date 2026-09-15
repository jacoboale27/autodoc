import 'dart:async';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/core/providers/notification_center_provider.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/features/dashboard/presentation/pages/notifications_screen.dart';
import 'support/responsive_harness.dart';
import 'support/shell_harness.dart';

class _Notifications extends NotificationCenterProvider {
  _Notifications() : super(firestore: FakeFirebaseFirestore());
  final pending = Completer<void>();
  int calls = 0;
  @override
  bool get hasUnread => true;
  @override
  Future<void> markAllAsRead(String userId) {
    calls++;
    return pending.future;
  }
}

void main() {
  testWidgets('grupo 8: marcar todo leido escribe una vez con dos taps', (
    tester,
  ) async {
    final notifications = _Notifications();
    await pumpAtWidth(
      tester,
      MultiProvider(
        providers: [
          ChangeNotifierProvider<NotificationCenterProvider>.value(
            value: notifications,
          ),
          ChangeNotifierProvider<UserProfileProvider>.value(
            value: FakeProfileProvider('Propietario'),
          ),
        ],
        child: const NotificationsScreen(),
      ),
      width: 800,
    );
    await tester.pumpAndSettle();
    final button = find.byIcon(Icons.done_all_rounded);
    await tester.tap(button);
    await tester.tap(button);
    expect(notifications.calls, 1);
    notifications.pending.complete();
    await tester.pumpAndSettle();
    await tester.tap(button);
    expect(notifications.calls, 2);
    await tester.pumpAndSettle();
  });
}
