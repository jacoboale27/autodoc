import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/features/admin/presentation/widgets/workshops_growth_chart.dart';
import 'package:autodoc/l10n/app_localizations.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.light,
    locale: const Locale('es'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets(
    'WorkshopsGrowthChart muestra mensaje de sin datos cuando el mapa está vacío',
    (tester) async {
      await tester.pumpWidget(
        _wrap(const WorkshopsGrowthChart(dataPorMes: {})),
      );

      expect(find.byType(WorkshopsGrowthChart), findsOneWidget);
      expect(find.byType(BarChart), findsNothing);
      expect(
        find.text('No hay datos de tendencias disponibles.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('WorkshopsGrowthChart renderiza un BarChart cuando hay datos', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const WorkshopsGrowthChart(dataPorMes: {'2026-06': 3, '2026-07': 6}),
      ),
    );

    expect(find.byType(WorkshopsGrowthChart), findsOneWidget);
    expect(find.byType(BarChart), findsOneWidget);
  });

  testWidgets(
    'WorkshopsGrowthChart plotea el valor real para una clave zero-padded '
    '(yyyy-MM) del mes actual, no 0',
    (tester) async {
      final now = DateTime.now();
      final currentMonthKey =
          '${now.year}-${now.month.toString().padLeft(2, '0')}';

      await tester.pumpWidget(
        _wrap(WorkshopsGrowthChart(dataPorMes: {currentMonthKey: 17})),
      );

      final barChart = tester.widget<BarChart>(find.byType(BarChart));
      final barGroups = barChart.data.barGroups;

      // El mes actual es siempre el último grupo de la ventana de 6 meses.
      final lastGroup = barGroups.last;
      expect(
        lastGroup.barRods.single.toY,
        17,
        reason:
            'Si la clave del mapa no coincide con la clave zero-padded '
            'generada por el widget (yyyy-MM), el valor real cae a 0 '
            'silenciosamente.',
      );
    },
  );
}
