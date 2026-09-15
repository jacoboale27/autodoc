import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:provider/provider.dart';
import 'package:autodoc/features/auth/presentation/pages/auth_screen.dart';
import 'package:autodoc/features/auth/presentation/providers/auth_provider.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/l10n/app_localizations.dart';
import 'helpers/test_helpers.mocks.dart';

class _Auth extends AuthProvider {
  _Auth()
    : super(
        authService: MockAuthService(),
        adminAuthService: MockAdminAuthService(),
      );
  final pending = Completer<bool>();
  int calls = 0;
  @override
  Future<bool> signInWithGoogle() {
    calls++;
    return pending.future;
  }

  @override
  Future<bool> sendPasswordReset(String email) {
    calls++;
    return pending.future;
  }
}

void main() {
  for (final google in [true, false]) {
    testWidgets(
      'grupo 1: ${google ? 'Google' : 'recuperar'} bloquea dos taps',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final auth = _Auth();
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ChangeNotifierProvider<AuthProvider>.value(
              value: auth,
              child: const AuthScreen(isLogin: true),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (!google) {
          await tester.tap(find.text('Forgot your password?'));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byType(TextField).last,
            'owner@example.test',
          );
        }
        final button = find.text(google ? 'Log in with Google' : 'Send link');
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.tap(button);
        expect(auth.calls, 1);
        auth.pending.complete(false);
        await tester.pumpAndSettle();
      },
    );
  }
}
