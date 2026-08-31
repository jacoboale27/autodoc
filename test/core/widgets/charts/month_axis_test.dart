import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/core/widgets/charts/month_axis.dart';

import '../../../support/responsive_harness.dart';

/// Monta un `LineChart` mínimo de 6 puntos (índices 0..5) usando
/// [monthAxisSideTitles] para el eje X, igual que lo hacen las cuatro
/// gráficas de producción (`ServicesTrendChart`, `UserGrowthChart`,
/// `WorkshopsGrowthChart`, `ExpenseSummaryCard`).
Widget _chartWithMonthAxis(List<int> monthNumbers, AppColors colors) {
  return SizedBox(
    height: 250,
    width: 800,
    child: LineChart(
      LineChartData(
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: monthAxisSideTitles(
              monthNumbers: monthNumbers,
              colors: colors,
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: monthNumbers
                .asMap()
                .entries
                .map((e) => FlSpot(e.key.toDouble(), e.value.toDouble()))
                .toList(),
          ),
        ],
      ),
    ),
  );
}

void main() {
  test('monthAbbreviation devuelve la abreviatura de 3 letras en español', () {
    expect(monthAbbreviation(1), 'Ene');
    expect(monthAbbreviation(3), 'Mar');
    expect(monthAbbreviation(12), 'Dic');
  });

  test('monthAbbreviation devuelve cadena vacía fuera de rango', () {
    expect(monthAbbreviation(0), '');
    expect(monthAbbreviation(13), '');
  });

  testWidgets(
    'monthAxisSideTitles dibuja exactamente una etiqueta por mes, sin '
    'repetidos, fijando interval:1 (el eje 0..5 sin interval explícito '
    'produce ticks fraccionarios como 0.5 que colapsan al truncarlos con '
    'toInt(), duplicando la etiqueta del mes — el hallazgo de QA "Mar Mar '
    'Mar Mar Abr Abr")',
    (tester) async {
      final colors = AppTheme.light.extension<AppColors>()!;
      // Marzo, Abril, Mayo, Junio, Julio, Agosto: 6 meses distintos.
      const monthNumbers = [3, 4, 5, 6, 7, 8];

      await pumpAtWidth(
        tester,
        _chartWithMonthAxis(monthNumbers, colors),
        width: 800,
      );
      await tester.pumpAndSettle();

      final expectedLabels = monthNumbers.map(monthAbbreviation).toList();
      final renderedLabels = tester
          .widgetList<Text>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Text && expectedLabels.contains(widget.data),
            ),
          )
          .map((text) => text.data)
          .toList();

      expect(
        renderedLabels.toSet(),
        expectedLabels.toSet(),
        reason:
            'Deben aparecer las 6 etiquetas de mes, cada una al menos '
            'una vez.',
      );
      expect(
        renderedLabels.length,
        expectedLabels.length,
        reason:
            'Cada etiqueta de mes debe dibujarse exactamente una vez, no '
            'repetida: $renderedLabels',
      );
    },
  );
}
