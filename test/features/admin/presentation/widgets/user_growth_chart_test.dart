import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/features/admin/presentation/widgets/user_growth_chart.dart';
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
    'UserGrowthChart muestra mensaje de sin datos cuando el mapa está vacío',
    (tester) async {
      await tester.pumpWidget(_wrap(const UserGrowthChart(dataPorMes: {})));

      expect(find.byType(UserGrowthChart), findsOneWidget);
      expect(find.byType(LineChart), findsNothing);
      expect(
        find.text('No hay datos de tendencias disponibles.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('UserGrowthChart renderiza un LineChart cuando hay datos', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const UserGrowthChart(dataPorMes: {'2026-06': 5, '2026-07': 8})),
    );

    expect(find.byType(UserGrowthChart), findsOneWidget);
    expect(find.byType(LineChart), findsOneWidget);
  });

  testWidgets('UserGrowthChart plotea el valor real para una clave zero-padded '
      '(yyyy-MM) del mes actual, no 0', (tester) async {
    final now = DateTime.now();
    final currentMonthKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';

    await tester.pumpWidget(
      _wrap(UserGrowthChart(dataPorMes: {currentMonthKey: 42})),
    );

    final lineChart = tester.widget<LineChart>(find.byType(LineChart));
    final spots = lineChart.data.lineBarsData.single.spots;

    // El mes actual es siempre el último punto de la ventana de 6 meses.
    final lastSpot = spots.last;
    expect(
      lastSpot.y,
      42,
      reason:
          'Si la clave del mapa no coincide con la clave zero-padded '
          'generada por el widget (yyyy-MM), el valor real cae a 0 '
          'silenciosamente.',
    );
  });
}
