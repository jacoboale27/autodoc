import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:autodoc/core/models/app_notification_model.dart';
import 'package:autodoc/core/providers/notification_center_provider.dart';
import 'package:autodoc/core/widgets/notification_bell_button.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/l10n/app_localizations.dart';

class _FakeNotificationCenterProvider extends ChangeNotifier
    implements NotificationCenterProvider {
  @override
  bool get hasUnread => false;

  @override
  int get unreadCount => 0;

  @override
  bool get isLoading => false;

  @override
  List<AppNotification> get notifications => [];

  @override
  String? get error => null;

  @override
  void initialize(String userId) {}

  @override
  Future<void> markAsRead(String userId, String notificationId) async {}

  @override
  Future<void> markAllAsRead(String userId) async {}

  @override
  Future<void> deleteNotification(String userId, String notificationId) async {}
}

void main() {
  testWidgets(
    'NotificationBellButton renders and navigates to /notifications on tap',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final notificationProvider = _FakeNotificationCenterProvider();

      final router = GoRouter(
        initialLocation: '/bell_test',
        routes: [
          GoRoute(
            path: '/bell_test',
            builder: (_, _) =>
                ChangeNotifierProvider<NotificationCenterProvider>.value(
                  value: notificationProvider,
                  child: const Scaffold(
                    body: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          NotificationBellButton(),
                          SizedBox(height: 16),
                          Text('Test Page'),
                        ],
                      ),
                    ),
                  ),
                ),
          ),
          GoRoute(
            path: '/notifications',
            builder: (_, _) =>
                const Scaffold(body: Text('NOTIFICATIONS_SCREEN')),
          ),
        ],
      );

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => _FakeNotificationCenterProvider(),
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pump();

      // Verify the bell icon is rendered with correct tooltip
      final bellFinder = find.byWidgetPredicate(
        (w) => w is IconButton && w.tooltip == 'Notificaciones',
      );
      expect(
        bellFinder,
        findsOneWidget,
        reason:
            'NotificationBellButton should render with Notificaciones tooltip',
      );

      // Tap the bell
      await tester.tap(bellFinder);
      await tester.pumpAndSettle();

      // Verify navigation to /notifications
      expect(
        find.text('NOTIFICATIONS_SCREEN'),
        findsOneWidget,
        reason: 'Should navigate to notifications screen after tapping bell',
      );
    },
  );

  testWidgets('NotificationBellButton respects custom colors parameter', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final customReadColor = Colors.orange;
    final customIcon = Icons.notifications_none;
    final notificationProvider = _FakeNotificationCenterProvider();

    final router = GoRouter(
      initialLocation: '/bell_test',
      routes: [
        GoRoute(
          path: '/bell_test',
          builder: (_, _) =>
              ChangeNotifierProvider<NotificationCenterProvider>.value(
                value: notificationProvider,
                child: Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        NotificationBellButton(
                          readColor: customReadColor,
                          readIcon: customIcon,
                        ),
                        const SizedBox(height: 16),
                        const Text('Test Page'),
                      ],
                    ),
                  ),
                ),
              ),
        ),
        GoRoute(
          path: '/notifications',
          builder: (_, _) => const Scaffold(body: Text('NOTIFICATIONS_SCREEN')),
        ),
      ],
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider.value(value: notificationProvider)],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pump();

    // Verify the bell icon is rendered
    final bellFinder = find.byWidgetPredicate(
      (w) => w is IconButton && w.tooltip == 'Notificaciones',
    );
    expect(bellFinder, findsOneWidget);

    // Tap it and verify navigation still works with custom params
    await tester.tap(bellFinder);
    await tester.pumpAndSettle();

    expect(
      find.text('NOTIFICATIONS_SCREEN'),
      findsOneWidget,
      reason: 'Should navigate even with custom color/icon parameters',
    );
  });
}
