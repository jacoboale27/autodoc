import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/widgets/app_text_field.dart';

import '../../support/entry_harness.dart';

void main() {
  testWidgets('enabled: false deshabilita el campo', (tester) async {
    await pumpEntry(
      tester,
      const Scaffold(body: AppTextField(label: 'Nombre', enabled: false)),
    );
    final field = tester.widget<TextFormField>(find.byType(TextFormField));
    expect(field.enabled, isFalse);
  });

  testWidgets('propaga autofillHints y textInputAction', (tester) async {
    await pumpEntry(
      tester,
      const Scaffold(
        body: AppTextField(
          label: 'Correo',
          autofillHints: <String>[AutofillHints.email],
          textInputAction: TextInputAction.next,
        ),
      ),
    );
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.autofillHints, contains(AutofillHints.email));
    expect(editable.textInputAction, TextInputAction.next);
  });

  testWidgets('onSubmitted se dispara al enviar desde el teclado', (
    tester,
  ) async {
    String? submitted;
    await pumpEntry(
      tester,
      Scaffold(
        body: AppTextField(
          label: 'Correo',
          onSubmitted: (value) => submitted = value,
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField), 'ada@autodoc.app');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(submitted, 'ada@autodoc.app');
  });

  testWidgets('obscureToggle muestra y oculta la contrasena', (tester) async {
    await pumpEntry(
      tester,
      const Scaffold(
        body: AppTextField(
          label: 'Contraseña',
          obscureText: true,
          obscureToggle: true,
        ),
      ),
    );

    expect(
      tester.widget<EditableText>(find.byType(EditableText)).obscureText,
      isTrue,
    );

    final toggle = find.byKey(const ValueKey('app-text-field-obscure-toggle'));
    expect(toggle, findsOneWidget);
    expect(tester.getSize(toggle).height, greaterThanOrEqualTo(48));

    await tester.tap(toggle);
    await tester.pump();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).obscureText,
      isFalse,
    );
  });

  testWidgets('el toggle tiene tooltip', (tester) async {
    await pumpEntry(
      tester,
      const Scaffold(
        body: AppTextField(
          label: 'Contraseña',
          obscureText: true,
          obscureToggle: true,
        ),
      ),
    );
    expect(find.byType(Tooltip), findsWidgets);
  });
}
