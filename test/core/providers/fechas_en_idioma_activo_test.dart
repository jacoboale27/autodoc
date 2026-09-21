import 'package:autodoc/core/providers/language_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Las fechas tienen que salir en el idioma activo de la app.
///
/// No es un detalle cosmetico y no lo veia ninguna suite: `flutter analyze`
/// pasa, los tests de widget pasan, y la app pinta «14 Aug 2026» en una
/// pantalla cuyo resto del texto esta en español. Se descubrio mirando una
/// captura para la ficha de Google Play.
///
/// La causa es de una sola linea y estaba en el arranque, no en las pantallas:
/// `Intl.defaultLocale` no se fijaba nunca, asi que las **31** llamadas a
/// `DateFormat(...)` de `lib/` —de las cuales solo UNA pasa locale explicito—
/// caian al ingles por defecto de `intl`.
///
/// Por eso el test mira el PROVIDER y no una pantalla: arreglarlo pantalla por
/// pantalla serian 31 sitios y el 32 volveria a nacer roto.
void main() {
  // Hace falta para que `_loadLocale` llegue a ejecutarse: lee
  // `WidgetsBinding.instance.platformDispatcher`, y sin binding lanza y su
  // `catch` se lo traga. Sin esta linea los casos pasan igual —el constructor
  // ya sincroniza— pero la rama de carga quedaria sin ejercer, que es justo la
  // que corre en la app de verdad.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Con idioma guardado, y no vacio, para que `_loadLocale` sea
    // determinista: sin preferencia cae al locale del DISPOSITIVO, que en
    // `flutter test` es en_US, y entonces estos casos dependerian de la
    // maquina que los corre.
    SharedPreferences.setMockInitialValues({'app_locale': 'es'});
    // Se ensucia a proposito antes de cada caso: si el arreglo no hiciera
    // nada, el test podria pasar por lo que dejo el caso anterior.
    Intl.defaultLocale = 'en_US';
  });

  group('las fechas siguen al idioma activo', () {
    test('al construirse, el provider deja intl en español', () async {
      final provider = LanguageProvider();
      await provider.listoParaFormatearFechas;

      expect(Intl.defaultLocale, 'es');
      expect(provider.currentLocale, const Locale('es'));
    });

    test('un mes abreviado sale en español, no en ingles', () async {
      final provider = LanguageProvider();
      await provider.listoParaFormatearFechas;

      // 14 de agosto: en ingles seria «14 Aug 2026», que es exactamente lo que
      // salia en la captura del historial de servicios.
      final texto = DateFormat('dd MMM yyyy').format(DateTime(2026, 8, 14));

      expect(texto, isNot(contains('Aug')));
      expect(texto.toLowerCase(), contains('ago'));
    });

    test('cambiar a ingles cambia tambien el formato de fecha', () async {
      final provider = LanguageProvider();
      await provider.listoParaFormatearFechas;

      await provider.changeLanguage('en');

      expect(Intl.defaultLocale, 'en');
      final texto = DateFormat('dd MMM yyyy').format(DateTime(2026, 8, 14));
      expect(texto, contains('Aug'));
    });

    test('y volver a español lo deshace', () async {
      final provider = LanguageProvider();
      await provider.listoParaFormatearFechas;
      await provider.changeLanguage('en');

      await provider.changeLanguage('es');

      expect(Intl.defaultLocale, 'es');
      final texto = DateFormat('dd MMM yyyy').format(DateTime(2026, 8, 14));
      expect(texto.toLowerCase(), contains('ago'));
    });

    test('una eleccion durante el arranque NO la pisa la carga', () async {
      // Carrera real, encontrada al hacer pasar el caso anterior.
      //
      // `_loadLocale` arranca en el constructor y no se espera, asi que puede
      // terminar DESPUES de que alguien toque el selector de idioma. Sin
      // proteccion escribia encima con el valor guardado y la eleccion se
      // revertia sola unos instantes despues, sin error ni aviso.
      //
      // Aqui se reproduce al milimetro: preferencias dicen «es», la persona
      // pide «en» de inmediato, y `_loadLocale` termina despues.
      SharedPreferences.setMockInitialValues({'app_locale': 'es'});
      final provider = LanguageProvider();

      await provider.changeLanguage('en');
      await pumpEventQueue(); // deja terminar a `_loadLocale`

      expect(provider.currentLocale, const Locale('en'));
      expect(Intl.defaultLocale, 'en');
    });

    test('el idioma guardado en preferencias tambien llega a intl', () async {
      // Cubre la rama `_loadLocale`, que es la que corre en la app real al
      // arrancar con un idioma ya elegido. El constructor sincroniza en
      // español por defecto, asi que si `_loadLocale` no sincronizara, este
      // caso vería «es» y pasaría por el motivo equivocado: de ahi que el
      // idioma guardado sea «en».
      SharedPreferences.setMockInitialValues({'app_locale': 'en'});

      final provider = LanguageProvider();
      await provider.listoParaFormatearFechas;
      // El constructor no espera a `_loadLocale`; se le da su turno.
      await pumpEventQueue();

      expect(provider.currentLocale, const Locale('en'));
      expect(Intl.defaultLocale, 'en');
      expect(
        DateFormat('dd MMM yyyy').format(DateTime(2026, 8, 14)),
        contains('Aug'),
      );
    });

    test(
      'formatear un mes en español no lanza: los simbolos estan cargados',
      () async {
        // `intl` exige `initializeDateFormatting(locale)` antes de usar un
        // locale que no sea en_US: sin esa carga, `DateFormat` no falla al
        // construirse sino AL FORMATEAR, con un LocaleDataException. O sea que
        // fijar `Intl.defaultLocale` a secas cambiaria el defecto por una
        // excepcion en tiempo de ejecucion, que es peor.
        final provider = LanguageProvider();
        await provider.listoParaFormatearFechas;

        expect(
          () => DateFormat.yMMMMd().format(DateTime(2026, 8, 14)),
          returnsNormally,
        );
      },
    );
  });
}
