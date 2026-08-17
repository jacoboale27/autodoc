import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/widgets/app_text_field.dart';
import 'package:autodoc/features/mechanic/presentation/pages/workshop_settings_screen.dart';

import '../../../../support/mechanic_harness.dart';
import '../../../../support/responsive_harness.dart';

void main() {
  Future<void> pumpAjustes(WidgetTester tester, double width) async {
    await pumpMechanicScreen(
      tester,
      const WorkshopSettingsScreen(),
      width: width,
      location: '/workshop_settings',
      disableAnimations: true,
    );
    await tester.pump();
  }

  testWidgets('a 1440 px el formulario usa dos columnas', (tester) async {
    await pumpAjustes(tester, 1440);

    final nombre = tester.getTopLeft(find.text('Nombre del Taller')).dx;
    final ubicacion = tester.getTopLeft(find.text('Ubicación Geográfica')).dx;
    expect(
      ubicacion,
      greaterThan(nombre + 100),
      reason: 'la ubicación debe ir en la segunda columna, no debajo',
    );
  });

  testWidgets('a 375 px el formulario es una sola columna', (tester) async {
    await pumpAjustes(tester, 375);

    final nombre = tester.getTopLeft(find.text('Nombre del Taller'));
    final ubicacion = tester.getTopLeft(find.text('Ubicación Geográfica'));
    expect(ubicacion.dx, closeTo(nombre.dx, 1));
    expect(ubicacion.dy, greaterThan(nombre.dy));
  });

  testWidgets('los campos usan AppTextField, con la etiqueta asociada', (
    tester,
  ) async {
    await pumpAjustes(tester, 375);

    expect(find.byType(AppTextField), findsWidgets);
    final semantics = tester.getSemantics(find.byType(EditableText).first);
    expect(semantics.label, contains('Nombre del Taller'));
  });

  testWidgets('el error de coordenadas se muestra junto al campo', (
    tester,
  ) async {
    await pumpAjustes(tester, 375);

    await tester.tap(find.text('Guardar Cambios'));
    await tester.pump();

    expect(
      find.text('Registra tu ubicación para que los clientes te encuentren'),
      findsOneWidget,
      reason: 'antes era un SnackBar que desaparecía sin señalar el campo',
    );
  });

  testWidgets('no desborda en ninguno de los anchos de auditoría', (
    tester,
  ) async {
    for (final width in kAuditWidths) {
      await pumpAjustes(tester, width);
      expectNoOverflow(tester);
    }
  });

  test('no queda la tercera familia tipográfica ni colores literales', () {
    final source = File(
      'lib/features/mechanic/presentation/pages/workshop_settings_screen.dart',
    ).readAsStringSync();

    expect(source.contains('GoogleFonts.montserrat'), isFalse);
    expect(source.contains('GoogleFonts.'), isFalse);
    expect(source.contains('Colors.green'), isFalse);
    expect(source.contains('Colors.grey'), isFalse);
    expect(source.contains('Colors.white'), isFalse);
    expect(source.contains('size.width < 700'), isFalse);
  });
}
