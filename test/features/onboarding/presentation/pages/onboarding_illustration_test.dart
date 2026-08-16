import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/features/onboarding/presentation/pages/onboarding_screen.dart';

import '../../../../support/entry_harness.dart';

void main() {
  testWidgets('el panel crece con la ventana y respeta el ancho de lectura', (
    tester,
  ) async {
    await pumpEntry(tester, const OnboardingScreen(), width: 375, height: 812);
    final narrow = tester.getSize(
      find.byKey(const ValueKey('onboarding-panel')),
    );

    await pumpEntry(tester, const OnboardingScreen(), width: 1440, height: 900);
    final wide = tester.getSize(find.byKey(const ValueKey('onboarding-panel')));

    expect(
      wide.width,
      greaterThan(narrow.width),
      reason: 'el panel sigue clavado en 280 px',
    );
    expect(
      wide.width,
      lessThanOrEqualTo(AppBreakpoints.maxReadingWidth),
      reason: 'el panel se desborda del ancho de lectura',
    );
  });

  testWidgets('la ilustracion tiene estado de error visible', (tester) async {
    // En test las peticiones de red fallan por defecto, asi que este
    // pump ejercita exactamente la rama de error.
    await pumpEntry(tester, const OnboardingScreen(), width: 375);
    expect(
      find.byKey(const ValueKey('onboarding-illustration-fallback')),
      findsOneWidget,
      reason: 'sin errorWidget el panel se queda vacio y mudo',
    );
  });

  testWidgets('las tres diapositivas no comparten la misma ilustracion', (
    tester,
  ) async {
    final source = File(
      'lib/features/onboarding/presentation/pages/onboarding_screen.dart',
    ).readAsStringSync();
    expect(
      source.contains('lh3.googleusercontent.com'),
      isFalse,
      reason: 'sigue el marcador de posicion del CDN de Google',
    );
    expect(source.contains('Reusing placeholder as requested'), isFalse);
  });

  testWidgets('como mucho una capa de desenfoque por pagina visible', (
    tester,
  ) async {
    await pumpEntry(tester, const OnboardingScreen(), width: 375);
    // BackdropFilter del panel: 1. ImageFiltered de los blobs: 0.
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.byType(ImageFiltered), findsNothing);
  });
}
