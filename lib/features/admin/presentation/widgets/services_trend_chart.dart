import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/widgets/app_card.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:autodoc/core/utils/l10n_extension.dart';

class ServicesTrendChart extends StatelessWidget {
  final Map<String, int> serviciosPorMes;

  const ServicesTrendChart({super.key, required this.serviciosPorMes});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    if (serviciosPorMes.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(24),
        child: Center(child: Text(context.l10n.adminNoTrendData)),
      );
    }

    final now = DateTime.now();
    List<String> monthsOrder = [];
    for (int i = 5; i >= 0; i--) {
      final date = DateTime(now.year, now.month - i, 1);
      // Debe coincidir con el formato zero-padded (p.ej. "2026-07") que usa
      // AdminService.watchDashboardMetrics() al construir serviciosPorMes;
      // una discrepancia aqui hace que el grafico muestre 0 para los meses
      // 1-9 (ver commit c8db6bb).
      monthsOrder.add('${date.year}-${date.month.toString().padLeft(2, '0')}');
    }

    final spots = monthsOrder.asMap().entries.map((entry) {
      final index = entry.key.toDouble();
      final key = entry.value;
      final value = (serviciosPorMes[key] ?? 0).toDouble();
      return FlSpot(index, value);
    }).toList();

    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tendencia de Servicios (Últimos 6 meses)',
            style: GoogleFonts.inter(
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
