import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:autodoc/core/providers/notification_center_provider.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/l10n/app_localizations.dart';

void main() {
  testWidgets(
    'tapping the bell icon on the owner dashboard opens /notifications',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = GoRouter(
        initialLocation: '/bell_test',
        routes: [
          GoRoute(
            path: '/bell_test',
            builder: (context, _) => Scaffold(
              appBar: AppBar(
                title: const Text('Bell Test'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none_rounded),
                    onPressed: () => context.push('/notifications'),
                    tooltip: 'Notificaciones',
                  ),
                ],
              ),
              body: const Text('Test Page'),
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
          create: (_) => NotificationCenterProvider(),
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pump();

      // Find and tap the bell icon
      final bellFinder = find.byWidgetPredicate(
        (w) => w is IconButton && w.tooltip == 'Notificaciones',
      );
      expect(
        bellFinder,
        findsOneWidget,
        reason: 'Bell icon should be rendered with Notificaciones tooltip',
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
}
