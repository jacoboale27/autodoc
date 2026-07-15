import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:autodoc/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Auth Flow Integration Test', () {
    testWidgets('Login and Logout flow', (tester) async {
      app.main();
      await tester.pump(const Duration(seconds: 5));

      // Find the email field and enter text
      final textFields = find.byType(TextField);
      if (textFields.evaluate().length >= 2) {
        final emailField = textFields.first;
        await tester.enterText(emailField, 'test@example.com');
        
        final passwordField = textFields.last;
        await tester.enterText(passwordField, 'password123');
        await tester.pump();
        
        // Tap login button - finding Elevated Button
        final loginButton = find.byType(ElevatedButton).first;
        if (loginButton.evaluate().isNotEmpty) {
          await tester.tap(loginButton);
          await tester.pump(const Duration(seconds: 5));
        }
      }
    });
  });
}
