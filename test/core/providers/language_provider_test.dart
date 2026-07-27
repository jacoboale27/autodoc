import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:autodoc/core/providers/language_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('LanguageProvider Tests', () {
    test('initial language is es', () {
      final provider = LanguageProvider();
      expect(provider.currentLocale, const Locale('es'));
    });

    test('changeLanguage updates locale to en', () async {
      final provider = LanguageProvider();
      await provider.changeLanguage('en');
      expect(provider.currentLocale, const Locale('en'));
    });

    test('changeLanguage updates locale back to es', () async {
      final provider = LanguageProvider();
      await provider.changeLanguage('en');
      await provider.changeLanguage('es');
      expect(provider.currentLocale, const Locale('es'));
    });
  });
}
