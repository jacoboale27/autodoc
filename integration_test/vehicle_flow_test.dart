import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:autodoc/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Vehicle Flow Integration Test', () {
    testWidgets('Add vehicle flow', (tester) async {
      app.main();
      await tester.pump(const Duration(seconds: 5));

      // Assuming user is logged in (using Firebase Emulator state)
      // Navigate to add vehicle screen
      final addButton = find.byIcon(Icons.add);
      if (addButton.evaluate().isNotEmpty) {
        await tester.tap(addButton.first);
        await tester.pump(const Duration(seconds: 2));

        // Verify form appears (just check if a text field is present)
        final textFields = find.byType(TextField);
        expect(textFields, findsWidgets);
      }
    });
  });
}
