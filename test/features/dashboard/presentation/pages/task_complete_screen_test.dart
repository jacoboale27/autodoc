import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/core/models/maintenance_task_model.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/widgets/app_text_field.dart';
import 'package:autodoc/features/dashboard/presentation/pages/task_complete_screen.dart';
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

Future<void> pumpScreen(
  WidgetTester tester,
  double width, {
  Brightness brightness = Brightness.light,
}) async {
  await pumpAtWidth(
    tester,
    ChangeNotifierProvider<AlertProvider>(
      create: (_) => AlertProvider(),
      child: TaskCompleteScreen(task: _task(), currentKm: 16000),
    ),
    width: width,
    brightness: brightness,
  );
  await tester.pump();
}

void main() {
  final source = File(
    'lib/features/dashboard/presentation/pages/task_complete_screen.dart',
  ).readAsStringSync();

  test('no re-deriva la paleta a mano', () {
    for (final literal in [
      '0xFF522C81',
      '0xFF0F172A',
      '0xFF64748B',
      '0xFFF7F6F8',
      '0xFF18141E',
    ]) {
      expect(
        source.contains(literal),
        isFalse,
        reason:
            '$literal duplica un valor de AppPalette; usa '
            'context.appColors',
      );
    }
  });

  test('no usa GoogleFonts ni colores de Material', () {
    expect(source.contains('GoogleFonts.'), isFalse);
    for (final banned in [
      'Colors.red',
      'Colors.green',
      'Colors.amber',
      'Colors.white',
      'Colors.grey',
      'Colors.black54',
    ]) {
      expect(source.contains(banned), isFalse, reason: banned);
    }
  });

  test('usa los componentes del design system', () {
    expect(source.contains('AppTextField'), isTrue);
    expect(source.contains('AppButton'), isTrue);
    expect(
      RegExp(r'\bTextField\(').hasMatch(source),
      isFalse,
      reason: 'TextField crudo en vez de AppTextField',
    );
    expect(
      source.contains('ElevatedButton'),
      isFalse,
      reason: 'ElevatedButton crudo en vez de AppButton',
    );
  });

  testWidgets('el primary sale del tema y se invierte en dark', (tester) async {
    late Color lightPrimary;
    late Color darkPrimary;

    await pumpAtWidth(
      tester,
      Builder(
        builder: (context) {
          lightPrimary = context.appColors.primary;
          return const SizedBox.shrink();
        },
      ),
      width: 375,
    );
    await pumpAtWidth(
      tester,
      Builder(
        builder: (context) {
          darkPrimary = context.appColors.primary;
          return const SizedBox.shrink();
        },
      ),
      width: 375,
      brightness: Brightness.dark,
    );

    expect(
      lightPrimary,
      isNot(darkPrimary),
      reason:
          'la marca invierte primary entre temas; una pantalla que fija '
          '#522C81 se queda morada en dark',
    );
  });

  testWidgets('el formulario se acota en pantallas grandes', (tester) async {
    await pumpScreen(tester, 1440);

    final field = tester.getSize(find.byType(AppTextField).first).width;
    expect(field, lessThanOrEqualTo(AppBreakpoints.maxFormWidth));
  });

  testWidgets('no desborda en ningún ancho de auditoría, en ambos temas', (
    tester,
  ) async {
    for (final brightness in Brightness.values) {
      await forEachAuditWidth(tester, (width) async {
        await pumpScreen(tester, width, brightness: brightness);
        expectNoOverflow(tester);
      });
    }
  });
}
