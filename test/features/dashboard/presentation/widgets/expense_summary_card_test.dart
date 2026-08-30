import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/features/dashboard/presentation/widgets/expense_summary_card.dart';
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
    'ExpenseSummaryCard no renderiza nada cuando "por_mes" está vacío',
    (tester) async {
      await tester.pumpWidget(
        _wrap(const ExpenseSummaryCard(summary: {'por_mes': <int, double>{}})),
      );

      expect(find.byType(ExpenseSummaryCard), findsOneWidget);
      expect(find.byType(LineChart), findsNothing);
    },
  );

  testWidgets('ExpenseSummaryCard renderiza un LineChart cuando hay datos', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        ExpenseSummaryCard(
          summary: {
            'por_mes': <int, double>{DateTime.now().month: 120.5},
            'total': 500.0,
            'mes_actual': 120.5,
            'promedio': 83.3,
          },
        ),
      ),
    );

    expect(find.byType(ExpenseSummaryCard), findsOneWidget);
    expect(find.byType(LineChart), findsOneWidget);
  });

  testWidgets(
    'ExpenseSummaryCard no repite ninguna etiqueta de mes en el eje X '
    '(hallazgo QA: "Mar Mar Mar Mar Abr Abr")',
    (tester) async {
      final now = DateTime.now();
      final porMes = <int, double>{};
      for (var i = 5; i >= 0; i--) {
        final month = DateTime(now.year, now.month - i, 1).month;
        porMes[month] = (i + 1) * 10.0;
      }

      await pumpAtWidth(
        tester,
        ExpenseSummaryCard(
          summary: {
            'por_mes': porMes,
            'total': 500.0,
            'mes_actual': 120.5,
            'promedio': 83.3,
          },
        ),
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
