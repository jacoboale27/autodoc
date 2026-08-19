import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/features/profile/presentation/pages/profile_setup_screen.dart';

import '../../../../support/entry_harness.dart';
import '../../../../support/responsive_harness.dart';

void main() {
  testWidgets('CERO desbordamientos en los ocho anchos y los dos idiomas', (
    tester,
  ) async {
    for (final locale in kEntryLocales) {
      for (final width in kAuditWidths) {
        final errors = await pumpEntryCollecting(
          tester,
          const ProfileSetupScreen(),
          width: width,
          locale: locale,
        );
        expect(
          errors,
          isEmpty,
          reason:
              'profile_setup desborda a $width px en ${locale.languageCode}: '
              '${errors.map(overflowPixels).toList()}',
        );
      }
    }
    // Los `.animate()` de esta pantalla (titulo, avatar) programan un
    // `Future.delayed(Duration.zero, ...)` en su `initState`. `dispose()`
    // solo hace `.ignore()` sobre ese Future — no cancela el Timer
    // subyacente — asi que el de la ULTIMA iteracion sigue pendiente cuando
    // el test termina y el binding revienta con `!timersPending`.
    // `pumpEntryCollecting` solo asienta un frame (para poder capturar
    // errores de layout del primer pump), asi que hay que agotarlo aqui
    // explicitamente. Mismo patron que
    // test/features/onboarding/presentation/pages/onboarding_screen_test.dart.
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('el formulario no supera maxFormWidth', (tester) async {
    await pumpEntry(
      tester,
      const ProfileSetupScreen(),
      width: 1440,
      height: 900,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('setup-form'))).width,
      lessThanOrEqualTo(AppBreakpoints.maxFormWidth),
    );
  });

  testWidgets('no hay indicador de paso falso', (tester) async {
    await pumpEntry(tester, const ProfileSetupScreen(), width: 375);
    expect(find.textContaining('PASO 1 DE 1'), findsNothing);
  });

  testWidgets('las tarjetas de rol son un grupo de opcion exclusiva', (
    tester,
  ) async {
    // Sin este handle, `tester.getSemantics` lanza «Semantics are not
    // enabled» antes de llegar a la primera asercion. Y se cierra con
    // `dispose()` al final del cuerpo, no con `addTearDown` — ver la nota
    // de la Task 8.
    final handle = tester.ensureSemantics();

    await pumpEntry(tester, const ProfileSetupScreen(), width: 375);

    final owner = find.byKey(const ValueKey('setup-role-propietario'));
    final mechanic = find.byKey(const ValueKey('setup-role-mecanico'));
    expect(owner, findsOneWidget);
    expect(mechanic, findsOneWidget);

    // Propietario viene seleccionado por defecto.
    expect(
      tester.getSemantics(owner).flagsCollection.isSelected,
      Tristate.isTrue,
    );
    expect(
      tester.getSemantics(mechanic).flagsCollection.isSelected,
      Tristate.isFalse,
    );

    // Y son mutuamente exclusivas. El campo de fecha de nacimiento empuja
    // las tarjetas de rol fuera del viewport inicial en pantallas bajas,
    // asi que hay que desplazarlas a la vista antes de tocarlas.
    await tester.ensureVisible(mechanic);
    await tester.pumpAndSettle();
    await tester.tap(mechanic);
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(owner).flagsCollection.isSelected,
      Tristate.isFalse,
    );
    expect(
      tester.getSemantics(mechanic).flagsCollection.isSelected,
      Tristate.isTrue,
    );

    // Y cada una mide al menos 48 dp.
    for (final finder in <Finder>[owner, mechanic]) {
      expect(tester.getSize(finder).height, greaterThanOrEqualTo(48));
    }

    handle.dispose();
  });

  testWidgets('el contenido empieza por debajo de la AppBar', (tester) async {
    await pumpEntry(tester, const ProfileSetupScreen(), width: 375);
    final title = find.text('¡Bienvenido a AutoDoc!');
    final appBar = find.byType(AppBar);
    expect(
      tester.getTopLeft(title).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(appBar).dy),
      reason: 'el titulo queda debajo de la barra translucida',
    );
  });

  testWidgets('la camara de la foto mide 48x48', (tester) async {
    await pumpEntry(tester, const ProfileSetupScreen(), width: 375);
    final camera = find.byKey(const ValueKey('setup-pick-photo'));
    final size = tester.getSize(camera);
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });
}
