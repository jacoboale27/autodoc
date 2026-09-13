import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Centinela: el despliegue de `hosting:app` no puede publicar un bundle de
/// E2E.
///
/// **Por que existe, y no es hipotetico.** El 2026-09-13 se desplego a
/// produccion el bundle de E2E: `flutter build web --profile` con
/// `--dart-define=USE_FIREBASE_EMULATOR=true`. Los dos candados de
/// `lib/core/config/firebase_emulators.dart` son `_flagEmuladores &&
/// !kReleaseMode`, y en `--profile` `kReleaseMode` es false, asi que **los dos
/// se abrieron**: la app publicada llamo a `useAuthEmulator()` y el SDK pinto
/// su cartel «Running in emulator mode. Do not use with production
/// credentials» a todo el que abriera la web, apuntando Auth, Firestore y
/// Storage al `localhost` del visitante. No hubo fuga de datos —no se puede
/// leer produccion desde ahi— pero la web estuvo caida para todo el mundo.
///
/// **Ninguna suite podia verlo.** `flutter test`, `flutter analyze`, las
/// reglas y las dos suites de Playwright miran el CODIGO FUENTE, y el codigo
/// fuente estaba bien: los candados funcionan exactamente como se disenaron.
/// El defecto vivia en el ARTEFACTO — `build/web`, que no esta versionado— y
/// en el hecho de que `firebase deploy --only hosting` publica lo que haya en
/// ese directorio sin mirarlo. Un artefacto contaminado es indistinguible de
/// uno limpio para todas las puertas que este repo tenia.
///
/// Por eso la guarda va en `predeploy` de `firebase.json`, que es el unico
/// punto por el que pasa todo despliegue de hosting, y este test existe para
/// que nadie la quite. Mismo patron que `test/firestore_indices_test.dart` y
/// `test/alertas_campos_test.dart`: leer la configuracion es la unica forma de
/// ver esto.
void main() {
  final raiz = Directory.current.path;

  Map<String, dynamic> leerFirebaseJson() {
    final archivo = File('$raiz/firebase.json');
    expect(
      archivo.existsSync(),
      isTrue,
      reason: 'No hay firebase.json en la raiz del repositorio.',
    );
    return jsonDecode(archivo.readAsStringSync()) as Map<String, dynamic>;
  }

  Map<String, dynamic> objetivoApp() {
    final hosting = leerFirebaseJson()['hosting'] as List<dynamic>;
    return hosting.cast<Map<String, dynamic>>().firstWhere(
      (h) => h['target'] == 'app',
      orElse: () => {},
    );
  }

  test('el objetivo de hosting `app` declara una guarda predeploy', () {
    final app = objetivoApp();

    expect(
      app,
      isNotEmpty,
      reason: 'firebase.json ya no declara el objetivo de hosting `app`.',
    );

    final predeploy = app['predeploy'];

    expect(
      predeploy,
      isNotNull,
      reason:
          'El objetivo `app` de hosting no tiene guarda `predeploy`, asi que '
          '`firebase deploy --only hosting` publicaria lo que haya en '
          'build/web SIN MIRARLO. Eso es exactamente lo que puso el bundle de '
          'emuladores en produccion el 2026-09-13. Vuelve a declarar la '
          'guarda; no la quites para esquivar un fallo de build.',
    );

    final comandos = (predeploy is List ? predeploy : [predeploy])
        .map((c) => c.toString())
        .toList();

    expect(
      comandos.any((c) => c.contains('verificar_bundle_web')),
      isTrue,
      reason:
          'La guarda `predeploy` del objetivo `app` ya no invoca a '
          '`scripts/verificar_bundle_web.js`. Si la sustituyes por otra cosa, '
          'esa otra cosa tiene que detectar el bundle de emuladores; si no, '
          'la guarda es decorativa.',
    );
  });

  test('el script de la guarda existe', () {
    expect(
      File('$raiz/scripts/verificar_bundle_web.js').existsSync(),
      isTrue,
      reason:
          'El `predeploy` apunta a un script que no existe. Un predeploy que '
          'no puede ejecutarse aborta el despliegue, que es el lado seguro, '
          'pero deja la guarda sin hacer su trabajo real.',
    );
  });
}
