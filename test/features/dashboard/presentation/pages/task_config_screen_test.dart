import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/core/models/maintenance_task_model.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/features/dashboard/presentation/pages/task_config_screen.dart';
import 'package:autodoc/features/dashboard/presentation/providers/alert_provider.dart';

import '../../../../support/responsive_harness.dart';

MaintenanceTask _task() => MaintenanceTask(
  id: 't1',
  vehicleId: 'v1',
  nombre: 'Cambio de aceite',
  ultimoKm: 10000,
  fechaUltimoServicio: DateTime(2026, 1, 1),
  frecuenciaKm: 5000,
  frecuenciaMeses: 6,
);

Future<void> pumpScreen(WidgetTester tester, double width) async {
  await pumpAtWidth(
    tester,
    ChangeNotifierProvider<AlertProvider>(
      create: (_) => AlertProvider(),
      child: TaskConfigScreen(task: _task()),
    ),
    width: width,
  );
  await tester.pump();
}

void main() {
  test('no usa GoogleFonts directamente', () {
    final source = File(
      'lib/features/dashboard/presentation/pages/task_config_screen.dart',
    ).readAsStringSync();
    expect(
      source.contains('GoogleFonts.'),
      isFalse,
      reason:
          'usa AppTextStyles; GoogleFonts solo vive en app_text_styles.dart',
    );
  });

  testWidgets('el formulario se acota en pantallas grandes', (tester) async {
    await pumpScreen(tester, 1440);

    final field = tester.getSize(find.byType(TextFormField).first).width;
    expect(
      field,
      lessThanOrEqualTo(AppBreakpoints.maxFormWidth),
      reason: 'el campo mide ${field}px; un input de 1400px es inusable',
    );
  });

  testWidgets('en móvil el formulario ocupa el ancho menos el gutter', (
    tester,
  ) async {
    await pumpScreen(tester, 375);

    final field = tester.getSize(find.byType(TextFormField).first).width;
    expect(field, closeTo(375 - 16 * 2, 1.0));
  });

  testWidgets('no desborda en ningún ancho de auditoría', (tester) async {
    await forEachAuditWidth(tester, (width) async {
      await pumpScreen(tester, width);
      expectNoOverflow(tester);
    });
  });

  testWidgets('el preajuste aplicado queda marcado como seleccionado', (
    tester,
  ) async {
    await pumpScreen(tester, 375);

    await tester.tap(find.text('5,000 km / 6 m'));
    await tester.pump();

    final chip = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, '5,000 km / 6 m'),
    );
    expect(
      chip.selected,
      isTrue,
      reason:
          'tras aplicar un preajuste el usuario no tiene forma de saber '
          'cuál está activo',
    );
  });

  testWidgets('renderiza en dark mode sin excepciones', (tester) async {
    await pumpAtWidth(
      tester,
      ChangeNotifierProvider<AlertProvider>(
        create: (_) => AlertProvider(),
        child: TaskConfigScreen(task: _task()),
      ),
      width: 375,
      brightness: Brightness.dark,
    );
    expectNoOverflow(tester);
  });
}
