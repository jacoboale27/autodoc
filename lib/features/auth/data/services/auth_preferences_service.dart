import 'package:shared_preferences/shared_preferences.dart';

/// Persiste preferencias de inicio de sesión (correo recordado, sin guardar contraseña).
class AuthPreferencesService {
  static const String _keyRememberMe = 'auth_remember_me';
  static const String _keySavedEmail = 'auth_saved_email';
  static const String _keyOnboardingCompleted = 'auth_onboarding_completed';

  Future<bool> getRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyRememberMe) ?? false;
  }

  Future<void> setRememberMe(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyRememberMe, value);
    if (!value) {
      await prefs.remove(_keySavedEmail);
    }
  }

  Future<String?> getSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySavedEmail);
  }

  Future<void> saveEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySavedEmail, email.trim());
  }

  Future<bool> isOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyOnboardingCompleted) ?? false;
  }

  Future<void> setOnboardingCompleted(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnboardingCompleted, value);
  }

  Future<void> clearSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySavedEmail);
    await prefs.setBool(_keyRememberMe, false);
  }
}

