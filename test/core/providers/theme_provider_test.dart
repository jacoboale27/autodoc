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
}
