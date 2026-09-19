import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tema claro/oscuro de la app.
///
/// Arranca con el modo del dispositivo (`ThemeMode.system`) mientras el
/// usuario no haya elegido otro; en cuanto lo cambia, la elección queda
/// guardada y es la que se usa en los siguientes arranques (observaciones del
/// 2026-09-19).
class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  ThemeMode _themeMode = ThemeMode.system;

  /// `true` en cuanto el usuario elige un tema en esta sesión. La lectura de
  /// la preferencia guardada es asíncrona: si terminara DESPUÉS de un toque,
  /// pisaría lo que el usuario acaba de elegir con lo que había antes.
  bool _eleccionEnEstaSesion = false;

  /// Se completa al terminar de leer la preferencia guardada. `main` lo
  /// espera antes de pintar la app, para que quien eligió un tema distinto
  /// del de su dispositivo no vea un destello del otro al abrirla.
  late final Future<void> listo;

  ThemeProvider() {
    listo = _loadTheme();
  }

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeIndex = prefs.getInt(_themeKey);
      if (themeIndex == null || _eleccionEnEstaSesion) return;
      // Un valor fuera de rango (almacenamiento manipulado o de otra versión)
      // no puede tumbar el arranque: se sigue con el modo del dispositivo.
      if (themeIndex < 0 || themeIndex >= ThemeMode.values.length) return;
      _themeMode = ThemeMode.values[themeIndex];
      notifyListeners();
    } catch (e) {
      debugPrint('No se pudo leer el tema guardado: $e');
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _eleccionEnEstaSesion = true;
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_themeKey, mode.index);
    } catch (e) {
      debugPrint('No se pudo guardar el tema: $e');
    }
  }

  void toggleTheme() {
    if (isDarkMode) {
      setThemeMode(ThemeMode.light);
    } else {
      setThemeMode(ThemeMode.dark);
    }
  }
}
