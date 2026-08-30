import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:autodoc/core/theme/app_colors.dart';

/// Abreviaturas de mes usadas en el eje X de las gráficas de tendencia
/// mensual (línea y barras) del panel de administración y del dashboard.
///
/// Nota de localización: estos textos están hardcodeados en español, igual
/// que ya lo estaban -duplicados cuatro veces- en cada gráfica antes de esta
/// refactorización (y que otros usos de fecha en el código, p. ej.
/// `DateFormat('MMM yyyy')` en `user_profile_screen.dart`, que tampoco están
/// conectados a `initializeDateFormatting`/al locale activo de la app).
/// Localizar correctamente estos nombres de mes requeriría además
/// inicializar los datos de `intl` por locale soportado y no es parte del
/// hallazgo de QA que esta tarea corrige (etiquetas del eje X repetidas).
/// Se centraliza aquí para eliminar la duplicación de código, pero se deja
/// documentado como deuda de localización pendiente.
const List<String> kMonthAbbreviations = [
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

/// Abreviatura de 3 letras para el número de mes [month] (1-12).
///
/// Devuelve cadena vacía si [month] está fuera de rango.
String monthAbbreviation(int month) {
  if (month < 1 || month > 12) return '';
  return kMonthAbbreviations[month - 1];
}

/// Construye el `SideTitles` del eje X compartido por las gráficas de
/// tendencia mensual (línea o barras), dibujando una etiqueta por cada
/// entrada de [monthNumbers] (un número de mes 1-12 por índice, en el mismo
/// orden que los `FlSpot`/`BarChartGroupData` de la gráfica).
///
/// Fija `interval: 1` explícitamente — **este es el fix real** del hallazgo
/// de QA "Mar Mar Mar Mar Abr Abr" en el eje X. Sin `interval`, fl_chart
/// (`Utils().getEfficientInterval`) elige su propio intervalo "bonito" para
/// el rango `0..N-1` del eje (p. ej. `0.5` en un eje 0..5 con suficiente
/// ancho), y como `getTitlesWidget` recibe ese valor y lo trunca con
/// `toInt()`, dos ticks fraccionarios consecutivos (`0.0` y `0.5`) colapsan
/// al mismo índice y la etiqueta de ese mes se dibuja dos veces.
///
/// No es, como se pensó originalmente, un problema de "una etiqueta por
/// punto de datos": cada gráfica ya construye su `monthsOrder`/`monthNumbers`
/// con una única entrada por mes (`services_trend_chart.dart`,
/// `user_growth_chart.dart`, `workshops_growth_chart.dart`,
/// `expense_summary_card.dart` iteran `for (int i = 5; i >= 0; i--)` una
/// sola vez), así que un deduplicador por mes repetido en `monthsOrder`
/// nunca tendría nada que deduplicar.
SideTitles monthAxisSideTitles({
  required List<int> monthNumbers,
  required AppColors colors,
}) {
  return SideTitles(
    showTitles: true,
    reservedSize: 30,
    interval: 1,
    getTitlesWidget: (value, meta) {
      final index = value.toInt();
      if (index < 0 || index >= monthNumbers.length) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: Text(
          monthAbbreviation(monthNumbers[index]),
          style: TextStyle(color: colors.textSecondary, fontSize: 12),
        ),
      );
    },
  );
}
