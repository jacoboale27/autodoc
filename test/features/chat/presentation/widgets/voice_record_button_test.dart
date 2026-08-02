import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:io';
import 'package:autodoc/features/chat/presentation/widgets/voice_record_button.dart';

void main() {
  testWidgets('VoiceRecordButton renderiza el ícono de micrófono inactivo', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VoiceRecordButton(onGrabacionCompleta: (File f, int d) {}),
        ),
      ),
    );

    expect(find.byIcon(Icons.mic), findsOneWidget);
  });
}
