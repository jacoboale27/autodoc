import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/widgets/app_card.dart';
import 'package:autodoc/core/widgets/charts/month_axis.dart';
import 'package:autodoc/core/utils/l10n_extension.dart';

/// Gráfico de línea que muestra el crecimiento de usuarios registrados
/// por mes, a partir del mapa `usuariosPorMes` producido por
/// `AdminService.watchDashboardMetrics()`.
class UserGrowthChart extends StatelessWidget {
  final Map<String, int> dataPorMes;

  const UserGrowthChart({super.key, required this.dataPorMes});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    if (dataPorMes.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(24),
        child: Center(child: Text(context.l10n.adminNoTrendData)),
      );
    }

    final now = DateTime.now();
    List<String> monthsOrder = [];
    for (int i = 5; i >= 0; i--) {
      final date = DateTime(now.year, now.month - i, 1);
      monthsOrder.add('${date.year}-${date.month.toString().padLeft(2, '0')}');
    }

    final monthNumbers = monthsOrder
        .map((key) => int.parse(key.split('-')[1]))
        .toList();

    final spots = monthsOrder.asMap().entries.map((entry) {
      final index = entry.key.toDouble();
      final key = entry.value;
      final value = (dataPorMes[key] ?? 0).toDouble();
      return FlSpot(index, value);
    }).toList();

    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Crecimiento de Usuarios (Últimos 6 meses)',
            style: AppTextStyles.titleMedium.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 250,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: monthAxisSideTitles(
                      monthNumbers: monthNumbers,
                      colors: colors,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: colors.primary,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: colors.primary.withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
