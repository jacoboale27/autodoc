// test/features/auth/auth_screen_layout_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/features/auth/presentation/pages/auth_screen.dart';
import 'package:autodoc/features/auth/presentation/widgets/auth_logo_section.dart';

import '../../support/entry_harness.dart';
import '../../support/responsive_harness.dart';

void main() {
  testWidgets('la tarjeta nunca supera 400 px de ancho', (tester) async {
    for (final width in kAuditWidths) {
      await pumpEntry(tester, const AuthScreen(isLogin: true), width: width);
      final card = find.byKey(const ValueKey('auth-card'));
      expect(
        tester.getSize(card).width,
        lessThanOrEqualTo(400),
        reason: 'la tarjeta crece a $width px',
      );
    }
  });

  testWidgets('en expanded hay dos columnas; en compact una', (tester) async {
    await pumpEntry(tester, const AuthScreen(isLogin: true), width: 375);
    expect(find.byKey(const ValueKey('auth-brand-panel')), findsNothing);

    await pumpEntry(
      tester,
      const AuthScreen(isLogin: true),
      width: 1024,
      height: 900,
    );
    final brand = find.byKey(const ValueKey('auth-brand-panel'));
    final card = find.byKey(const ValueKey('auth-card'));
    expect(brand, findsOneWidget);
    // El panel de marca queda a la izquierda de la tarjeta.
    expect(tester.getTopLeft(brand).dx, lessThan(tester.getTopLeft(card).dx));
  });

  testWidgets('la barra inferior no se solapa con el contenido', (
    tester,
  ) async {
    await pumpEntry(tester, const AuthScreen(isLogin: true), width: 375);
    final nav = find.byKey(const ValueKey('auth-bottom-nav'));
    final card = find.byKey(const ValueKey('auth-card'));
    expect(
      tester.getBottomLeft(card).dy,
      lessThanOrEqualTo(tester.getTopLeft(nav).dy),
      reason: 'la tarjeta se mete debajo de la barra inferior',
    );
  });

  testWidgets('el logo de Google no viene de la red', (tester) async {
    final source = File(
      'lib/features/auth/presentation/pages/auth_screen.dart',
    ).readAsStringSync();
    expect(source.contains('Image.network'), isFalse);
    expect(source.contains('google.com/images'), isFalse);
  });

  testWidgets('no quedan colores literales en el fichero', (tester) async {
    final source = File(
      'lib/features/auth/presentation/pages/auth_screen.dart',
    ).readAsStringSync();
    final offenders = RegExp(
      r'Colors\.(white|black|grey|blue|red|green|orange|purple|amber)',
    ).allMatches(source).map((m) => m.group(0)).toList();
    expect(offenders, isEmpty, reason: 'quedan: $offenders');
  });

  testWidgets('AuthLogoSection sigue presente en ambas clases', (tester) async {
    for (final width in <double>[375, 1024]) {
      await pumpEntry(
        tester,
        const AuthScreen(isLogin: true),
        width: width,
        height: 900,
      );
      expect(find.byType(AuthLogoSection), findsOneWidget);
    }
  });
}
