import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/features/onboarding/presentation/pages/onboarding_screen.dart';

import '../../../../support/entry_harness.dart';
import '../../../../support/responsive_harness.dart';

void main() {
  testWidgets('en horizontal de telefono NO lanza aserciones', (tester) async {
    // 800x400 es un telefono girado. Hoy esto produce
    // "BoxConstraints has non-normalized height constraints".
    final errors = await pumpEntryCollecting(
      tester,
      const OnboardingScreen(),
      width: 800,
      height: 400,
    );
    // Ver la nota en el siguiente test: los `.animate()` de esta pantalla
    // dejan un Timer pendiente que hay que agotar antes de que termine el
    // test.
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      errors,
      isEmpty,
      reason: '${errors.map((e) => e.exception).toList()}',
    );
  });

  testWidgets('no desborda en ningun ancho auditado ni en ningun idioma', (
    tester,
  ) async {
    for (final locale in kEntryLocales) {
      for (final width in kAuditWidths) {
        final errors = await pumpEntryCollecting(
          tester,
          const OnboardingScreen(),
          width: width,
          locale: locale,
        );
        expect(
          errors,
          isEmpty,
          reason: 'desborda a $width px en ${locale.languageCode}',
        );
      }
    }
    // Los varios `.animate()` de esta pantalla (blobs decorativos, texto)
    // programan un `Future.delayed(Duration.zero, ...)` en su `initState`.
    // `dispose()` solo hace `.ignore()` sobre ese Future — no cancela el
    // Timer subyacente — asi que el de la ULTIMA iteracion sigue pendiente
    // cuando el test termina y el binding revienta con `!timersPending`.
    // `pumpEntryCollecting` solo asienta un frame (para poder capturar
    // errores de layout del primer pump), asi que hay que agotarlo aqui
    // explicitamente. Mismo patron que
    // test/features/auth/login_screen_test.dart.
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('el boton de retroceso no existe en la primera pagina', (
    tester,
  ) async {
    await pumpEntry(tester, const OnboardingScreen(), width: 375);
    expect(find.byKey(const ValueKey('onboarding-back')), findsNothing);
  });

  testWidgets('los puntos anuncian el paso actual', (tester) async {
    // `tester.getSemantics` lanza «Semantics are not enabled» si nadie ha
    // pedido el arbol semantico: hay que abrir el handle ANTES del pump.
    // Y hay que cerrarlo con `dispose()` AL FINAL DEL CUERPO: `addTearDown`
    // NO sirve aqui (ver la nota debajo del bloque).
    final handle = tester.ensureSemantics();

    await pumpEntry(tester, const OnboardingScreen(), width: 375);
    final dots = find.byKey(const ValueKey('onboarding-dots'));
    expect(dots, findsOneWidget);
    final semantics = tester.getSemantics(dots);
    expect(semantics.label, contains('1'));
    expect(semantics.label, contains('3'));

    handle.dispose();
  });

  testWidgets('el boton principal es un boton de verdad', (tester) async {
    final handle = tester.ensureSemantics();

    await pumpEntry(tester, const OnboardingScreen(), width: 375);
    final button = find.byKey(const ValueKey('onboarding-next'));
    expect(button, findsOneWidget);
    expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
    expect(
      tester.getSemantics(button),
      matchesSemantics(
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        label: 'Siguiente',
        hasTapAction: true,
      ),
    );

    handle.dispose();
  });

  testWidgets('el PageController se libera', (tester) async {
    await pumpEntry(tester, const OnboardingScreen(), width: 375);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    // Si el controller no se libera, Flutter registra el objeto como
    // no dispuesto y el binding lo denuncia en el teardown.
    expect(tester.takeException(), isNull);
  });
}
