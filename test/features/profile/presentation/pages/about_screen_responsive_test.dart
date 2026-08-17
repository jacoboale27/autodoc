import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/features/profile/presentation/pages/about_screen.dart';

import '../../../../support/contrast.dart';
import '../../../../support/entry_harness.dart';
import '../../../../support/responsive_harness.dart'; // kAuditWidths

void main() {
  testWidgets('el contenido no supera el ancho de lectura en large', (
    tester,
  ) async {
    await pumpEntry(tester, const AboutScreen(), width: 1440, height: 900);

    final card = find.byKey(const ValueKey('about-info-card'));
    expect(card, findsOneWidget);
    expect(
      tester.getSize(card).width,
      lessThanOrEqualTo(AppBreakpoints.maxReadingWidth),
    );
  });

  testWidgets('el copyright cumple 4.5:1 en claro y en oscuro', (tester) async {
    for (final brightness in Brightness.values) {
      await pumpEntry(
        tester,
        const AboutScreen(),
        width: 375,
        brightness: brightness,
      );
      final context = tester.element(find.byType(AboutScreen));
      final colors = context.appColors;

      final copyright = tester.widget<Text>(
        find.byKey(const ValueKey('about-copyright')),
      );
      final color = copyright.style!.color!;
      expect(
        contrastRatio(composite(color, colors.surface), colors.surface),
        greaterThanOrEqualTo(4.5),
        reason: 'copyright ilegible en $brightness',
      );
    }
  });

  testWidgets('no desborda en ningun ancho auditado, en ambos idiomas', (
    tester,
  ) async {
    for (final locale in kEntryLocales) {
      for (final width in kAuditWidths) {
        final errors = await pumpEntryCollecting(
          tester,
          const AboutScreen(),
          width: width,
          locale: locale,
        );
        expect(
          errors,
          isEmpty,
          reason: 'about_screen desborda a $width px en ${locale.languageCode}',
        );
      }
    }
  });

  testWidgets('no usa GoogleFonts ni tamanos de fuente literales', (
    tester,
  ) async {
    final source = File(
      'lib/features/profile/presentation/pages/about_screen.dart',
    ).readAsStringSync();
    expect(source.contains('GoogleFonts'), isFalse);
    expect(RegExp(r'fontSize:\s*\d').hasMatch(source), isFalse);
  });
}
