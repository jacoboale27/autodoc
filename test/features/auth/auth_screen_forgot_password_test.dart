import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/features/auth/presentation/pages/auth_screen.dart';
import 'package:autodoc/features/auth/presentation/providers/auth_provider.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/l10n/app_localizations.dart';
import '../../helpers/test_helpers.mocks.dart';

void main() {
  late MockAuthService mockAuthService;
  late MockAdminAuthService mockAdminAuthService;
  late AuthProvider authProvider;

  setUp(() {
    mockAuthService = MockAuthService();
    mockAdminAuthService = MockAdminAuthService();
    authProvider = AuthProvider(
      authService: mockAuthService,
      adminAuthService: mockAdminAuthService,
    );
  });

  Widget buildTestableWidget(Widget widget) {
    return MaterialApp(
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ChangeNotifierProvider<AuthProvider>.value(
        value: authProvider,
        child: widget,
      ),
    );
  }

  testWidgets(
    'shows error feedback when password reset fails (dialog does not get stuck)',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Mock the sendPasswordReset to throw an exception
      when(
        mockAuthService.sendPasswordReset(any),
      ).thenThrow('Could not send the email.');

      await tester.pumpWidget(
        buildTestableWidget(const AuthScreen(isLogin: true)),
      );
      await tester.pumpAndSettle();

      // Open the forgot password dialog
      await tester.tap(find.text('Forgot your password?'));
      await tester.pumpAndSettle();

      // Verify dialog is open
      expect(find.byType(AlertDialog), findsOneWidget);

      // Enter an email and tap send
      await tester.enterText(find.byType(TextField).last, 'nadie@gmail.com');
      await tester.tap(find.text('Send link'));

      // Wait for the dialog to close and snackbar to appear
      await tester.pumpAndSettle();

      // The dialog should be closed (not stuck open)
      // After the fix, it should pop immediately on failure
      expect(find.byType(AlertDialog), findsNothing);

      // SnackBar should appear with error message
      // (searching for snackbar content text)
      expect(find.text('Could not send the email.'), findsOneWidget);
    },
  );
}
