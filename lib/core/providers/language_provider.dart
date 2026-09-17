import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  Locale _currentLocale = const Locale('es');

  Locale get currentLocale => _currentLocale;
  String get currentLanguageCode => _currentLocale.languageCode;

  /// Se completa cuando `intl` ya puede formatear fechas en el idioma activo.
  ///
  /// Existe para los tests: la carga de simbolos de `intl` es asincrona y el
  /// constructor no puede esperarla, asi que sin esto un test tendria que
  /// adivinar cuanto dormir. En la app nadie necesita aguardarla —las fechas
  /// se pintan mucho despues del arranque— pero se expone en vez de dejarla
  /// privada porque una espera explicita es mejor que un `pumpEventQueue`.
  Future<void> get listoParaFormatearFechas => _listo;
  Future<void> _listo = Future.value();

  /// Si la persona ya eligio idioma a mano en esta sesion.
  ///
  /// `_loadLocale` es asincrona y arranca en el constructor, asi que puede
  /// terminar DESPUES de que alguien toque el selector. Sin esta bandera,
  /// escribia encima y la eleccion se revertia sola unos instantes despues,
  /// sin error ni aviso. La ventana es corta, pero la pantalla de ajustes es
  /// alcanzable desde el arranque y el fallo es invisible: la app simplemente
  /// «no obedece».
  bool _elegidoPorLaPersona = false;

  LanguageProvider() {
    // El idioma por defecto tambien tiene que llegar a `intl`. Si solo se
    // sincronizara al CAMBIAR de idioma, el arranque normal —que es el caso
    // de casi todo el mundo, porque casi nadie toca el selector— seguiria
    // formateando en ingles.
    _listo = _sincronizarIntl(_currentLocale.languageCode);
    _loadLocale();
  }

  /// Pone `intl` en el mismo idioma que la app.
  ///
  /// Son dos pasos y los dos hacen falta:
  ///
  /// 1. `initializeDateFormatting` carga los simbolos del locale. Sin ella,
  ///    `DateFormat` no falla al construirse sino AL FORMATEAR, con un
  ///    `LocaleDataException`: fijar solo `defaultLocale` cambiaria las fechas
  ///    en ingles por un crash.
  /// 2. `Intl.defaultLocale` es lo que leen las **31** llamadas a `DateFormat`
  ///    repartidas por `lib/`, de las cuales solo una pasa locale explicito.
  ///    Arreglarlo aqui las arregla todas, y hace que la 32 nazca bien.
  ///
  /// El sintoma que destapo esto: el historial de servicios pintaba
  /// «14 Aug 2026» con el resto de la pantalla en español.
  Future<void> _sincronizarIntl(String codigo) async {
    try {
      await initializeDateFormatting(codigo);
      Intl.defaultLocale = codigo;
    } catch (e) {
      // Un idioma sin datos de locale no debe tumbar la app: se queda con el
      // anterior, que como minimo formatea.
      debugPrint('Error initializing date formatting for "$codigo": $e');
    }
  }

  Future<void> _loadLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Si la persona eligio mientras esto cargaba, su decision manda: lo que
      // hay en preferencias ya esta obsoleto (`changeLanguage` lo reescribe).
      if (_elegidoPorLaPersona) return;
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
      await _sincronizarIntl(_currentLocale.languageCode);
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading app locale: $e");
    }
  }

  Future<void> changeLanguage(String localeCode) async {
    final cleanCode = localeCode.trim().toLowerCase();
    // Se marca aunque el idioma no cambie: la intencion es la misma y basta
    // para que una `_loadLocale` en vuelo no pise nada despues.
    _elegidoPorLaPersona = true;
    if (_currentLocale.languageCode == cleanCode) return;

    _currentLocale = Locale(cleanCode);
    // Antes de `notifyListeners`: las pantallas se reconstruyen con el aviso y
    // formatean fechas durante ese rebuild. Sincronizar despues dejaria el
    // primer repintado con el idioma viejo en las fechas y el nuevo en el
    // resto del texto.
    await _sincronizarIntl(cleanCode);
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_locale', cleanCode);
    } catch (e) {
      debugPrint("Error saving app locale: $e");
    }
  }
}
