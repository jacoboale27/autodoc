import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/widgets/app_text_field.dart';

import '../../support/responsive_harness.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget field, {double width = 375}) {
    return pumpAtWidth(tester, Center(child: field), width: width);
  }

  testWidgets('la etiqueta está asociada al campo para el lector de pantalla', (
    tester,
  ) async {
    await pump(tester, const AppTextField(label: 'Placa del vehículo'));

    final semantics = tester.getSemantics(find.byType(EditableText));
    expect(
      semantics.label,
      contains('Placa del vehículo'),
      reason:
          'el campo no anuncia su etiqueta: '
          'un Text hermano en un Column no está asociado al input',
    );
  });

  testWidgets('un campo obligatorio lo anuncia', (tester) async {
    await pump(
      tester,
      const AppTextField(label: 'Placa del vehículo', isRequired: true),
    );

    final semantics = tester.getSemantics(find.byType(EditableText));
    expect(semantics.label.toLowerCase(), contains('obligatorio'));
  });

  testWidgets('muestra el helperText bajo el campo', (tester) async {
    await pump(
      tester,
      const AppTextField(label: 'Placa', helperText: 'Formato: P123-456'),
    );

    expect(find.text('Formato: P123-456'), findsOneWidget);
  });

  testWidgets('el error se muestra junto al campo, no solo como borde', (
    tester,
  ) async {
    final formKey = GlobalKey<FormState>();

    await pump(
      tester,
      Form(
        key: formKey,
        child: const AppTextField(label: 'Placa', validator: _alwaysInvalid),
      ),
    );

    formKey.currentState!.validate();
    await tester.pump();

    expect(find.text('Placa inválida'), findsOneWidget);
  });

  testWidgets('acepta entrada de texto', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await pump(tester, AppTextField(label: 'Placa', controller: controller));

    await tester.enterText(find.byType(TextFormField), 'P123-456');
    expect(controller.text, 'P123-456');
  });

  testWidgets('no desborda en ningún ancho de auditoría', (tester) async {
    await forEachAuditWidth(tester, (width) async {
      await pump(
        tester,
        const AppTextField(
          label: 'Una etiqueta razonablemente larga para un campo',
          hintText: 'Escribe aquí el valor que corresponda',
        ),
        width: width,
      );
      expectNoOverflow(tester);
    });
  });
}

String? _alwaysInvalid(String? value) => 'Placa inválida';
