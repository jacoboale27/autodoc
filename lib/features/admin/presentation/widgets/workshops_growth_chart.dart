import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/widgets/app_card.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:autodoc/core/utils/l10n_extension.dart';

/// Gráfico de barras que muestra la cantidad de talleres afiliados
/// por mes, a partir del mapa `talleresPorMes` producido por
/// `AdminService.watchDashboardMetrics()`.
class WorkshopsGrowthChart extends StatelessWidget {
  final Map<String, int> dataPorMes;

  const WorkshopsGrowthChart({super.key, required this.dataPorMes});

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
      monthsOrder.add('${date.year}-${date.month}');
    }

    final barGroups = monthsOrder.asMap().entries.map((entry) {
      final index = entry.key;
      final key = entry.value;
      final value = (dataPorMes[key] ?? 0).toDouble();
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: value,
            color: colors.primary,
            width: 16,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    }).toList();

    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Talleres Afiliados (Últimos 6 meses)',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 250,
            child: BarChart(
              BarChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 &&
                            value.toInt() < monthsOrder.length) {
                          final key = monthsOrder[value.toInt()];
                          final month = int.parse(key.split('-')[1]);
                          final monthNames = [
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
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              monthNames[month - 1],
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
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
                barGroups: barGroups,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
