import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/widgets/app_card.dart';
import 'package:google_fonts/google_fonts.dart';

class ServicesTrendChart extends StatelessWidget {
  final Map<int, int> serviciosPorMes;

  const ServicesTrendChart({super.key, required this.serviciosPorMes});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    
    if (serviciosPorMes.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(24),
        child: const Center(child: Text("No hay datos de tendencias disponibles.")),
      );
    }

    final now = DateTime.now();
    List<int> monthsOrder = [];
    for (int i = 5; i >= 0; i--) {
      monthsOrder.add(DateTime(now.year, now.month - i, 1).month);
    }

    final spots = monthsOrder.asMap().entries.map((entry) {
      final index = entry.key.toDouble();
      final month = entry.value;
      final value = (serviciosPorMes[month] ?? 0).toDouble();
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
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 && value.toInt() < monthsOrder.length) {
                          final month = monthsOrder[value.toInt()];
                          final monthNames = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              monthNames[month - 1],
                              style: TextStyle(color: colors.textSecondary, fontSize: 12),
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
                          style: TextStyle(color: colors.textSecondary, fontSize: 12),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
