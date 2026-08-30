import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/features/admin/presentation/widgets/user_growth_chart.dart';
import 'package:autodoc/l10n/app_localizations.dart';

import '../../../../support/responsive_harness.dart';

/// Abreviaturas de mes usadas por el widget en el eje X. Duplicada aquí a
/// propósito (en vez de importar la constante de producción) para que este
/// test verifique el comportamiento visible del eje, no un detalle interno
/// de implementación.
const _monthAbbreviations = [
  'Ene',
  'Feb',
  'Mar',
  'Abr',
  'May',
  'Jun',
  'Jul',
  'Ago',
  'Sep',
  'Oct',
  'Nov',
  'Dic',
];

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

  testWidgets('UserGrowthChart no repite ninguna etiqueta de mes en el eje X '
      '(hallazgo QA: "Mar Mar Mar Mar Abr Abr")', (tester) async {
    final now = DateTime.now();
    final dataPorMes = <String, int>{};
    for (var i = 5; i >= 0; i--) {
      final date = DateTime(now.year, now.month - i, 1);
      final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      dataPorMes[key] = i + 1;
    }

    await pumpAtWidth(
      tester,
      UserGrowthChart(dataPorMes: dataPorMes),
      width: 800,
    );
    await tester.pumpAndSettle();

    final monthLabels = tester
        .widgetList<Text>(
          find.byWidgetPredicate(
            (widget) =>
                widget is Text && _monthAbbreviations.contains(widget.data),
          ),
        )
        .map((text) => text.data)
        .toList();

    expect(
      monthLabels.toSet().length,
      monthLabels.length,
      reason:
          'El eje X dibuja la misma etiqueta de mes más de una vez en '
          'lugar de una sola vez por mes: $monthLabels',
    );
  });
}
