import 'dart:async';

import 'package:autodoc/core/widgets/firebase_initialization_error_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/l10n/app_localizations.dart';

Future<AppLocalizations> _es() =>
    AppLocalizations.delegate.load(const Locale('es'));

Future<void> _pump(
  WidgetTester tester, {
  Future<bool> Function()? onRetry,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: FirebaseInitializationErrorScreen(onRetry: onRetry),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'explains Firebase startup failure instead of rendering a blank screen',
    (tester) async {
      await _pump(tester);
      final l10n = await _es();

      expect(find.text(l10n.startupErrorTitle), findsOneWidget);
      expect(find.text(l10n.startupErrorBody), findsOneWidget);
    },
  );

  testWidgets('the copy is localized, not a hardcoded Spanish literal', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: FirebaseInitializationErrorScreen(),
      ),
    );
    await tester.pumpAndSettle();

    final en = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(en.startupErrorTitle), findsOneWidget);
    expect(find.text('No pudimos iniciar AutoDoc'), findsNothing);
  });

  testWidgets('offers a retry control that actually invokes the retry', (
    tester,
  ) async {
    var attempts = 0;
    await _pump(
      tester,
      onRetry: () async {
        attempts++;
        return true;
      },
    );
    final l10n = await _es();

    final retry = find.widgetWithText(FilledButton, l10n.startupErrorRetry);
    expect(retry, findsOneWidget);

    await tester.tap(retry);
    await tester.pumpAndSettle();

    expect(attempts, 1);
  });

  testWidgets('shows progress while retrying and does not double-fire', (
    tester,
  ) async {
    var attempts = 0;
    final gate = Completer<void>();
    await _pump(
      tester,
      onRetry: () async {
        attempts++;
        await gate.future;
        return false;
      },
    );
    final l10n = await _es();

    final retry = find.widgetWithText(FilledButton, l10n.startupErrorRetry);
    await tester.tap(retry);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // A second tap while in flight must not start another attempt.
    await tester.tap(find.byType(FilledButton), warnIfMissed: false);
    await tester.pump();
    expect(attempts, 1);

    gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('a failed retry tells the user the attempt failed', (
    tester,
  ) async {
    await _pump(tester, onRetry: () async => false);
    final l10n = await _es();

    expect(find.text(l10n.startupErrorRetryFailed), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, l10n.startupErrorRetry));
    await tester.pumpAndSettle();

    expect(find.text(l10n.startupErrorRetryFailed), findsOneWidget);
  });

  testWidgets('never leaks the raw exception to the user', (tester) async {
    await _pump(tester);

    expect(find.textContaining('Exception'), findsNothing);
    expect(find.textContaining('FirebaseException'), findsNothing);
  });
}
