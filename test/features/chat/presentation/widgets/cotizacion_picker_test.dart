import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/features/chat/presentation/widgets/cotizacion_picker.dart';
import '../../../../support/chat_harness.dart';
import '../../../../support/responsive_harness.dart';

void main() {
  testWidgets('el formulario se acota a maxFormWidth en pantallas grandes', (
    tester,
  ) async {
    await pumpChatWidget(
      tester,
      CotizacionPicker(onConfirm: (_, _) async {}),
      width: 1440,
    );
    final ancho = tester.getSize(find.byType(Form)).width;
    expect(
      ancho,
      lessThanOrEqualTo(AppBreakpoints.maxFormWidth),
      reason: 'A 1440 px los campos del formulario medían 1400 px.',
    );
  });

  testWidgets('el error de fecha se anuncia al lector de pantalla', (
    tester,
  ) async {
    await pumpChatWidget(
      tester,
      CotizacionPicker(onConfirm: (_, _) async {}),
      width: 375,
    );
    await tester.tap(find.text('Generar y Enviar'));
    await tester.pump();
    expect(
      find.bySemanticsLabel(
        RegExp('Debes proponer el día y hora del servicio'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('no desborda en ningún ancho auditado', (tester) async {
    for (final width in kAuditWidths) {
      await pumpChatWidget(
        tester,
        CotizacionPicker(onConfirm: (_, _) async {}),
        width: width,
      );
      expectNoOverflow(tester);
    }
  });
}
