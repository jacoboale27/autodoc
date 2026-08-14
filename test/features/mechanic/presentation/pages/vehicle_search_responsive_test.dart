// test/features/mechanic/presentation/pages/vehicle_search_responsive_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/features/mechanic/presentation/pages/vehicle_search_screen.dart';

import '../../../../support/contrast.dart';
import '../../../../support/mechanic_harness.dart';
import '../../../../support/responsive_harness.dart';

void main() {
  Future<void> pumpBusqueda(WidgetTester tester, double width) async {
    await pumpMechanicScreen(
      tester,
      const VehicleSearchScreen(),
      width: width,
      location: '/mechanic_search',
      disableAnimations: true,
    );
    await tester.pump();
  }

  testWidgets('el placeholder de la placa cumple el contraste de texto', (
    tester,
  ) async {
    await pumpBusqueda(tester, 375);

    final context = tester.element(find.byType(VehicleSearchScreen));
    final colors = context.appColors;
    final field = tester.widget<TextField>(find.byType(TextField).first);
    final hintColor = field.decoration!.hintStyle!.color!;

    expect(
      contrastRatio(hintColor, colors.surfaceContainer),
      greaterThanOrEqualTo(4.5),
      reason: 'el hint dice el formato de la placa: hay que poder leerlo',
    );
  });

  testWidgets('el botón de QR mide al menos 48 dp y se anuncia', (
    tester,
  ) async {
    await pumpBusqueda(tester, 375);

    final boton = find.bySemanticsLabel(RegExp('QR'));
    expect(boton, findsOneWidget);
    final size = tester.getSize(boton.first);
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('no desborda en ninguno de los anchos de auditoría', (
    tester,
  ) async {
    for (final width in kAuditWidths) {
      await pumpBusqueda(tester, width);
      expectNoOverflow(tester);
    }
  });

  test('no quedan controles muertos ni colores literales', () {
    final source = File(
      'lib/features/mechanic/presentation/pages/vehicle_search_screen.dart',
    ).readAsStringSync();

    expect(
      source.contains('onPressed: () {}'),
      isFalse,
      reason: '"SABER MÁS" era un botón enfocable sin destino',
    );
    expect(source.contains('Colors.white'), isFalse);
    expect(source.contains('GoogleFonts.'), isFalse);
    expect(source.contains('size.width < 700'), isFalse);
    expect(
      source.contains('dynamic vehicle'),
      isFalse,
      reason: 'el parámetro dynamic desactivaba el chequeo de tipos',
    );
  });
}
