import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/features/chat/presentation/widgets/voice_record_button.dart';
import '../../../../support/chat_harness.dart';

void main() {
  test('formatearDuracionGrabacion sigue formateando m:ss', () {
    // El helper ya es público y correcto; se fija como contrato porque el
    // Semantics del botón lo va a consumir.
    expect(formatearDuracionGrabacion(const Duration(seconds: 65)), '1:05');
    expect(formatearDuracionGrabacion(Duration.zero), '0:00');
  });

  testWidgets('el botón de grabar cumple el mínimo de 48 dp', (tester) async {
    await pumpChatWidget(
      tester,
      VoiceRecordButton(onGrabacionCompleta: (_, _) {}),
      width: 375,
    );
    final size = tester.getSize(find.byType(VoiceRecordButton));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('anuncia qué hace al lector de pantalla', (tester) async {
    await pumpChatWidget(
      tester,
      VoiceRecordButton(onGrabacionCompleta: (_, _) {}),
      width: 375,
    );
    expect(
      find.bySemanticsLabel('Grabar nota de voz. Mantén presionado.'),
      findsOneWidget,
    );
  });
}
