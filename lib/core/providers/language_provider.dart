import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  Locale _currentLocale = const Locale('es');

  Locale get currentLocale => _currentLocale;
  String get currentLanguageCode => _currentLocale.languageCode;

  LanguageProvider() {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString('app_locale');
      if (code != null && code.isNotEmpty) {
        _currentLocale = Locale(code);
      } else {
        final deviceLanguage = WidgetsBinding
            .instance
            .platformDispatcher
            .locale
            .languageCode
            .toLowerCase();
        final autoCode = (deviceLanguage == 'en') ? 'en' : 'es';
        _currentLocale = Locale(autoCode);
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading app locale: $e");
    }
  }

  Future<void> changeLanguage(String localeCode) async {
    final cleanCode = localeCode.trim().toLowerCase();
    if (_currentLocale.languageCode == cleanCode) return;

    _currentLocale = Locale(cleanCode);
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_locale', cleanCode);
    } catch (e) {
      debugPrint("Error saving app locale: $e");
    }
  }
}
