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
}
