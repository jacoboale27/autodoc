import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/core/providers/theme_provider.dart';
import 'package:autodoc/core/widgets/app_top_nav_bar.dart';
import 'package:autodoc/core/widgets/navigation/app_nav_destination.dart';
import 'package:autodoc/l10n/app_localizations.dart';

import '../../support/shell_harness.dart';
import '../../support/responsive_harness.dart';

void main() {
  // El tooltip del boton de tema vive en l10n (topNavThemeTooltip): no se
  // puede asumir un literal fijo como 'Theme'.
  String themeTooltipDe(WidgetTester tester) => AppLocalizations.of(
    tester.element(find.byType(AppTopNavBar)),
  )!.topNavThemeTooltip;

  testWidgets('no desborda a 1200px, el ancho mínimo donde se muestra', (
    tester,
  ) async {
    await pumpTopNav(
      tester,
      width: 1200,
      userName: 'Un Nombre Largo De Verdad',
    );
    expectNoOverflow(tester);
  });

  testWidgets('no desborda a 1200px con el nombre más largo plausible', (
    tester,
  ) async {
    await pumpTopNav(
      tester,
      width: 1200,
      userName: 'María de los Ángeles Hernández Villalobos',
    );
    expectNoOverflow(tester);
  });

  testWidgets('muestra los mismos destinos que AppNavDestinations', (
    tester,
  ) async {
    await pumpTopNav(tester, width: 1440);

    for (final destination in AppNavDestinations.owner) {
      expect(
        find.text(destination.label),
        findsWidgets,
        reason: 'falta ${destination.route} en la barra superior',
      );
    }
  });

  testWidgets('los controles de icono tienen tooltip', (tester) async {
    await pumpTopNav(tester, width: 1440);

    for (final button in tester.widgetList<IconButton>(
      find.byType(IconButton),
    )) {
      expect(
        button.tooltip,
        isNotNull,
        reason: 'IconButton sin tooltip: ${button.icon}',
      );
      expect(button.tooltip, isNotEmpty);
    }
  });

  testWidgets('renderiza en dark mode sin excepciones', (tester) async {
    await pumpTopNav(tester, width: 1440, brightness: Brightness.dark);
    expectNoOverflow(tester);
  });

  // Regresion del interruptor de tema.
  //
  // El boton calculaba el estado actual como `themeMode == ThemeMode.dark`.
  // Arrancando en ThemeMode.system con el sistema operativo en oscuro, eso da
  // `false` aunque la app YA se vea oscura, asi que el primer toque hacia
  // setThemeMode(dark): no cambiaba nada en pantalla y habia que pulsar dos
  // veces. El sintoma reportado era "el cambio de tema no funciona".
  //
  // El contrato es: UN toque siempre invierte lo que el usuario esta viendo.
  ThemeProvider themeProviderDe(WidgetTester tester) =>
      Provider.of<ThemeProvider>(
        tester.element(find.byType(AppTopNavBar)),
        listen: false,
      );

  testWidgets(
    'con el sistema en oscuro, UN toque en el interruptor pasa a claro',
    (tester) async {
      final binding = tester.binding;
      binding.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(binding.platformDispatcher.clearPlatformBrightnessTestValue);

      await pumpTopNav(tester, width: 1440, brightness: Brightness.dark);

      final theme = themeProviderDe(tester);
      expect(
        theme.themeMode,
        ThemeMode.system,
        reason: 'el estado de partida del bug es ThemeMode.system',
      );

      await tester.tap(find.byTooltip(themeTooltipDe(tester)));
      await tester.pumpAndSettle();

      expect(
        themeProviderDe(tester).themeMode,
        ThemeMode.light,
        reason:
            'un solo toque debe invertir el tema que el usuario esta viendo',
      );
    },
  );

  testWidgets(
    'con el sistema en claro, UN toque en el interruptor pasa a oscuro',
    (tester) async {
      final binding = tester.binding;
      binding.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(binding.platformDispatcher.clearPlatformBrightnessTestValue);

      await pumpTopNav(tester, width: 1440);

      await tester.tap(find.byTooltip(themeTooltipDe(tester)));
      await tester.pumpAndSettle();

      expect(themeProviderDe(tester).themeMode, ThemeMode.dark);
    },
  );
}
