import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/features/admin/presentation/widgets/services_trend_chart.dart';
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
    'ServicesTrendChart muestra mensaje de sin datos cuando el mapa está '
    'vacío',
    (tester) async {
      await tester.pumpWidget(
        _wrap(const ServicesTrendChart(serviciosPorMes: {})),
      );

      expect(find.byType(ServicesTrendChart), findsOneWidget);
      expect(find.byType(LineChart), findsNothing);
    },
  );

  testWidgets('ServicesTrendChart renderiza un LineChart cuando hay datos', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const ServicesTrendChart(serviciosPorMes: {'2026-06': 5, '2026-07': 8}),
      ),
    );

    expect(find.byType(ServicesTrendChart), findsOneWidget);
    expect(find.byType(LineChart), findsOneWidget);
  });

  testWidgets(
    'ServicesTrendChart plotea el valor real para una clave zero-padded '
    '(yyyy-MM) del mes actual, no 0',
    (tester) async {
      final now = DateTime.now();
      final currentMonthKey =
          '${now.year}-${now.month.toString().padLeft(2, '0')}';

      await tester.pumpWidget(
        _wrap(ServicesTrendChart(serviciosPorMes: {currentMonthKey: 37})),
      );

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      final spots = lineChart.data.lineBarsData.single.spots;

      // El mes actual es siempre el último punto de la ventana de 6 meses.
      final lastSpot = spots.last;
      expect(
        lastSpot.y,
        37,
        reason:
            'Si la clave del mapa (construida por AdminService, ahora '
            'zero-padded) no coincide con la clave que este widget genera '
            'internamente, el valor real cae a 0 silenciosamente — esta es '
            'exactamente la regresión que ya ocurrió una vez con '
            'usuariosPorMes/talleresPorMes (commit c8db6bb) y que la '
            'normalización de serviciosPorMes a zero-padded busca evitar '
            'también aquí.',
      );
    },
  );

  testWidgets(
    'ServicesTrendChart no repite ninguna etiqueta de mes en el eje X '
    '(hallazgo QA: "Mar Mar Mar Mar Abr Abr")',
    (tester) async {
      final now = DateTime.now();
      final serviciosPorMes = <String, int>{};
      for (var i = 5; i >= 0; i--) {
        final date = DateTime(now.year, now.month - i, 1);
        final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
        serviciosPorMes[key] = i + 1;
      }

      await pumpAtWidth(
        tester,
        ServicesTrendChart(serviciosPorMes: serviciosPorMes),
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
    },
  );
}
