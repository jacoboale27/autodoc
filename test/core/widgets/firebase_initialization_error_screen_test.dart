import 'package:autodoc/core/widgets/firebase_initialization_error_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'explains Firebase startup failure instead of rendering a blank screen',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: FirebaseInitializationErrorScreen()),
      );

      expect(find.text('No pudimos iniciar AutoDoc'), findsOneWidget);
      expect(find.textContaining('Firebase'), findsOneWidget);
    },
  );
}
