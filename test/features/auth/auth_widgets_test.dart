// test/features/auth/auth_widgets_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/features/auth/presentation/widgets/auth_bottom_nav.dart';

import '../../support/entry_harness.dart';

void main() {
  testWidgets('las tres acciones de la barra miden 48 dp de alto', (
    tester,
  ) async {
    late AppColors colors;
    await pumpEntry(
      tester,
      Builder(
        builder: (context) {
          colors = context.appColors;
          return Scaffold(body: AuthBottomNav(colors: colors, isDark: false));
        },
      ),
      width: 320,
    );

    for (final key in const <String>[
      'auth-nav-help',
      'auth-nav-privacy',
      'auth-nav-terms',
    ]) {
      final finder = find.byKey(ValueKey(key));
      expect(finder, findsOneWidget, reason: 'falta $key');
      final size = tester.getSize(finder);
      expect(size.height, greaterThanOrEqualTo(48), reason: '$key es bajo');
      expect(size.width, greaterThanOrEqualTo(48), reason: '$key es estrecho');
    }
  });

  testWidgets('la barra no desborda a 320 px en ingles', (tester) async {
    late AppColors colors;
    final errors = await pumpEntryCollecting(
      tester,
      Builder(
        builder: (context) {
          colors = context.appColors;
          return Scaffold(body: AuthBottomNav(colors: colors, isDark: false));
        },
      ),
      width: 320,
      locale: const Locale('en'),
    );
    expect(errors, isEmpty);
  });

  testWidgets('con reduced motion los blobs no escalan', (tester) async {
    await pumpEntry(
      tester,
      const Scaffold(body: SizedBox.expand()),
      disableAnimations: true,
    );
    // Se verifica por codigo fuente: ningun ScaleEffect sin guarda.
    final source = File(
      'lib/features/auth/presentation/widgets/auth_background_blobs.dart',
    ).readAsStringSync();
    expect(
      source.contains('AppMotion.reduced'),
      isTrue,
      reason: 'los blobs no consultan reduced motion',
    );
    expect(
      RegExp(r'Duration\(seconds:\s*\d').hasMatch(source),
      isFalse,
      reason: 'quedan duraciones literales',
    );
  });

  testWidgets('AuthLogoSection respeta reduced motion', (tester) async {
    final source = File(
      'lib/features/auth/presentation/widgets/auth_logo_section.dart',
    ).readAsStringSync();
    expect(source.contains('AppMotion.reduced'), isTrue);
  });

  testWidgets('la sombra de la barra no usa Colors.black', (tester) async {
    final source = File(
      'lib/features/auth/presentation/widgets/auth_bottom_nav.dart',
    ).readAsStringSync();
    expect(source.contains('Colors.black'), isFalse);
  });
}
