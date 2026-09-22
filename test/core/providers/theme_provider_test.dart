import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:autodoc/core/providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ThemeProvider Tests', () {
    test('initial theme is system', () {
      final provider = ThemeProvider();
      expect(provider.themeMode, ThemeMode.system);
    });

    test('setThemeMode updates theme', () async {
      final provider = ThemeProvider();
      await provider.setThemeMode(ThemeMode.dark);
      expect(provider.themeMode, ThemeMode.dark);
    });

    test('setThemeMode updates theme light', () async {
      final provider = ThemeProvider();
      await provider.setThemeMode(ThemeMode.light);
      expect(provider.themeMode, ThemeMode.light);
    });
  });

  // Observaciones del 2026-09-19: la app arranca con el modo del dispositivo
  // y, en cuanto el usuario elige otro, lo recuerda en los siguientes
  // arranques.
  group('el tema elegido se recuerda entre arranques', () {
    test('sin nada guardado, sigue al dispositivo', () async {
      final provider = ThemeProvider();
      await provider.listo;
      expect(provider.themeMode, ThemeMode.system);
    });

    test('lo que se elige hoy es lo que carga el siguiente arranque', () async {
      final primero = ThemeProvider();
      await primero.listo;
      await primero.setThemeMode(ThemeMode.dark);

      final siguiente = ThemeProvider();
      await siguiente.listo;
      expect(siguiente.themeMode, ThemeMode.dark);
    });

    test('una elección hecha mientras se lee lo guardado no se pisa', () async {
      SharedPreferences.setMockInitialValues({
        'theme_mode': ThemeMode.dark.index,
      });
      final provider = ThemeProvider();
      // El toque llega antes de que termine la lectura asíncrona.
      await provider.setThemeMode(ThemeMode.light);
      await provider.listo;
      expect(provider.themeMode, ThemeMode.light);
    });

    test('un valor guardado fuera de rango no tumba el arranque', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 42});
      final provider = ThemeProvider();
      await provider.listo;
      expect(provider.themeMode, ThemeMode.system);
    });
  });
}
