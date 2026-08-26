import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:autodoc/core/providers/theme_provider.dart';

/// Regresión del toggle de tema claro/oscuro.
///
/// Los tres interruptores de la UI (barra superior, dashboard de admin y
/// dashboard de mecánico) calculaban el estado actual como
/// `themeMode == ThemeMode.dark`. El valor inicial es `ThemeMode.system`, así
/// que con el sistema operativo en oscuro la app YA se veía oscura pero ese
/// cálculo daba `false`: el primer toque hacía `setThemeMode(dark)`, que no
/// cambiaba absolutamente nada en pantalla. Había que pulsar dos veces, y el
/// síntoma era "el cambio de tema no funciona".
///
/// `ThemeProvider.isDarkMode` sí resuelve `system` contra el brillo real de la
/// plataforma, y `toggleTheme()` se apoya en él. Estos tests fijan ese
/// contrato para que los tres interruptores puedan delegar en él con confianza.
void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    binding.platformDispatcher.clearPlatformBrightnessTestValue();
  });

  group('ThemeProvider.isDarkMode resuelve ThemeMode.system', () {
    test('con la plataforma en oscuro y modo system, isDarkMode es true', () {
      binding.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      final provider = ThemeProvider();

      expect(provider.themeMode, ThemeMode.system);
      expect(provider.isDarkMode, isTrue);
    });

    test('con la plataforma en claro y modo system, isDarkMode es false', () {
      binding.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      final provider = ThemeProvider();

      expect(provider.themeMode, ThemeMode.system);
      expect(provider.isDarkMode, isFalse);
    });
  });

  group('toggleTheme cambia el tema al PRIMER toque', () {
    test('sistema en oscuro + modo system: un toque lleva a claro', () {
      // Este es exactamente el caso que estaba roto: antes el primer toque
      // ponía ThemeMode.dark sobre una app que ya se veía oscura.
      binding.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      final provider = ThemeProvider();

      provider.toggleTheme();

      expect(provider.themeMode, ThemeMode.light);
      expect(provider.isDarkMode, isFalse);
    });

    test('sistema en claro + modo system: un toque lleva a oscuro', () {
      binding.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      final provider = ThemeProvider();

      provider.toggleTheme();

      expect(provider.themeMode, ThemeMode.dark);
      expect(provider.isDarkMode, isTrue);
    });

    test('cada toque sucesivo alterna, sin quedarse pegado', () {
      binding.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      final provider = ThemeProvider();

      provider.toggleTheme();
      expect(provider.themeMode, ThemeMode.light);

      provider.toggleTheme();
      expect(provider.themeMode, ThemeMode.dark);

      provider.toggleTheme();
      expect(provider.themeMode, ThemeMode.light);
    });

    test('notifica a los oyentes en cada toque', () {
      binding.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      final provider = ThemeProvider();
      var avisos = 0;
      provider.addListener(() => avisos++);

      provider.toggleTheme();
      expect(avisos, 1);

      provider.toggleTheme();
      expect(avisos, 2);
    });
  });
}
