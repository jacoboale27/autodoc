// test/features/auth/auth_screen_form_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/widgets/app_text_field.dart';
import 'package:autodoc/features/auth/presentation/pages/auth_screen.dart';

import '../../support/entry_harness.dart';

void main() {
  testWidgets('no desborda a 320 px en NINGUNO de los dos idiomas', (
    tester,
  ) async {
    for (final locale in kEntryLocales) {
      final errors = await pumpEntryCollecting(
        tester,
        const AuthScreen(isLogin: true),
        width: 320,
        locale: locale,
      );
      // AuthBackgroundBlobs (widget decorativo, fuera del alcance de esta
      // tarea) anima con flutter_animate durante 2.5s reales. pumpEntryCollecting
      // solo asienta un frame (para poder capturar errores de layout del
      // primer pump), asi que hay que agotar ese timer aqui antes de que el
      // arbol se destruya o el binding revienta con '!timersPending'.
      await tester.pump(const Duration(seconds: 3));
      expect(
        errors,
        isEmpty,
        reason:
            'auth_screen desborda a 320 px en ${locale.languageCode}: '
            '${errors.map(overflowPixels).toList()}',
      );
    }
  });

  testWidgets('el checkbox de recordarme mide al menos 48x48', (tester) async {
    await pumpEntry(tester, const AuthScreen(isLogin: true), width: 375);
    final target = find.byKey(const ValueKey('auth-remember-me'));
    expect(target, findsOneWidget);
    final size = tester.getSize(target);
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('el enlace de contrasena olvidada mide al menos 48 de alto', (
    tester,
  ) async {
    await pumpEntry(tester, const AuthScreen(isLogin: true), width: 375);
    final target = find.byKey(const ValueKey('auth-forgot-password'));
    expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
  });

  testWidgets('los campos declaran teclado, autofill y accion', (tester) async {
    await pumpEntry(tester, const AuthScreen(isLogin: true), width: 375);

    final email = tester.widget<AppTextField>(
      find.byKey(const ValueKey('auth-email-field')),
    );
    expect(email.keyboardType, TextInputType.emailAddress);
    expect(email.autofillHints, contains(AutofillHints.username));
    expect(email.textInputAction, TextInputAction.next);

    final password = tester.widget<AppTextField>(
      find.byKey(const ValueKey('auth-password-field')),
    );
    expect(password.autofillHints, contains(AutofillHints.password));
    expect(password.textInputAction, TextInputAction.done);
    expect(password.obscureToggle, isTrue);
  });

  testWidgets('el formulario esta dentro de un AutofillGroup', (tester) async {
    await pumpEntry(tester, const AuthScreen(isLogin: true), width: 375);
    expect(find.byType(AutofillGroup), findsOneWidget);
  });

  testWidgets('registro con correo invalido muestra el error JUNTO al campo', (
    tester,
  ) async {
    await pumpEntry(tester, const AuthScreen(isLogin: false), width: 375);

    await tester.enterText(
      find.byKey(const ValueKey('auth-email-field')),
      'no-es-un-correo',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-password-field')),
      'secreta123',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('auth-submit')));
    await tester.tap(find.byKey(const ValueKey('auth-submit')));
    await tester.pumpAndSettle();

    // El error vive en el formulario, no en un SnackBar encima de el.
    expect(find.byType(SnackBar), findsNothing);
    // Desviacion documentada respecto al brief: el texto literal del ARB
    // (authEnterValidEmail) es "Ingresa un correo electrónico válido.", no
    // "Ingresa un correo válido" como aparecia en el esqueleto del brief.
    // Se usa la clave existente cableada, sin inventar una nueva.
    expect(find.text('Ingresa un correo electrónico válido.'), findsOneWidget);
  });

  testWidgets('el campo del correo no tiene altura fija', (tester) async {
    // pumpEntryCollecting (no pumpEntry): a 200% de escala de fuente,
    // AuthBottomNav (widget decorativo fuera del alcance de esta tarea, ver
    // reporte de desviaciones) desborda en la barra inferior. Ese defecto es
    // preexistente y no forma parte de los ficheros de esta tarea; usar la
    // variante que captura errores de layout evita que un pumpAndSettle lo
    // convierta en un fallo de este test, que solo verifica el alto del
    // campo de correo.
    await pumpEntryCollecting(
      tester,
      const AuthScreen(isLogin: true),
      width: 375,
    );
    final small = tester.getSize(
      find.byKey(const ValueKey('auth-email-field')),
    );
    // Agota el timer de 2.5s de AuthBackgroundBlobs antes del siguiente pump.
    await tester.pump(const Duration(seconds: 3));

    await pumpEntryCollecting(
      tester,
      const AuthScreen(isLogin: true),
      width: 375,
      textScaler: const TextScaler.linear(2.0),
    );
    final scaled = tester.getSize(
      find.byKey(const ValueKey('auth-email-field')),
    );
    await tester.pump(const Duration(seconds: 3));

    expect(small.height, greaterThan(0));
    expect(scaled.height, greaterThan(small.height));
  });
}
