import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  String _currentLocale = 'es';
  
  String get currentLocale => _currentLocale;

  LanguageProvider() {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentLocale = prefs.getString('app_locale') ?? 'es';
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading app locale: $e");
    }
  }

  Future<void> changeLanguage(String localeCode) async {
    final cleanCode = localeCode.trim().toLowerCase();
    if (_currentLocale == cleanCode) return;
    
    _currentLocale = cleanCode;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_locale', cleanCode);
    } catch (e) {
      debugPrint("Error saving app locale: $e");
    }
  }
}
