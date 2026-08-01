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
}
