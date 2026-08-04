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

  test('formatearDuracionGrabacion pads seconds under 10', () {
    expect(formatearDuracionGrabacion(const Duration(seconds: 5)), '0:05');
  });

  test('formatearDuracionGrabacion rolls over minutes', () {
    expect(formatearDuracionGrabacion(const Duration(seconds: 65)), '1:05');
  });

  test('formatearDuracionGrabacion at zero', () {
    expect(formatearDuracionGrabacion(Duration.zero), '0:00');
  });
}
