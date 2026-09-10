#!/usr/bin/env node
'use strict';

// Cablea el Auth de Firebase al emulador ANTES de que arranque Flutter, y
// parchea build/web/index.html para hacerlo. Solo toca el artefacto del E2E:
// web/index.html, que es el que se despliega, no se modifica.
//
// POR QUE HACE FALTA (y por que no basta con main.dart)
//
// `Firebase.initializeApp()` en web no retorna hasta que cada plugin termina
// su `ensurePluginInitialized`. El de firebase_auth_web (6.2.5,
// lib/firebase_auth_web.dart:84) acaba con `await authDelegate
// .onWaitInitState()`, que espera al PRIMER evento de `onAuthStateChanged`.
// Cuando hay una sesion persistida en IndexedDB, ese evento no llega hasta que
// el SDK de JS refresca el token guardado — una peticion de red — y todo eso
// pasa dentro del `initializeApp`.
//
// main.dart solo puede llamar a `conectarEmuladoresFirebase()` DESPUES de que
// ese future resuelva, asi que llega tarde por construccion: la peticion ya
// salio al Auth de PRODUCCION (400, la key del E2E es falsa) y el instance de
// Auth ya esta usado, asi que el `connectAuthEmulator` posterior no tiene
// efecto y `emulatorConfig` se queda en null para siempre. Sintoma: con
// sesion, ninguna carga completa de pagina vuelve a estar cableada.
//
// No es un bug de la app: en produccion no hay emulador y restaurar la sesion
// contra el backend real es exactamente lo correcto. Es un limite del orden de
// arranque que solo se puede romper desde fuera de Dart.
//
// COMO LO ROMPE ESTE SHIM
//
// firebase_core_web reutiliza la app de JS que ya exista (`firebase.app()` en
// firebase_core_web.dart:307) en vez de crear otra. Asi que creamos nosotros la
// app por defecto y conectamos el emulador antes de cargar
// flutter_bootstrap.js. Cuando Flutter arranca, `getAuthInstance(app)` le
// devuelve ESE instance, ya apuntado al emulador, y `onWaitInitState()`
// restaura la sesion contra el emulador: sin peticion a produccion y sin
// perder el cableado.
//
// Dos detalles sin los que no funciona:
//
// 1. `window.flutterfire_web_sdk_version` fuerza a flutterfire a importar la
//    MISMA URL de gstatic que importamos aqui. Los modulos ES se deduplican por
//    URL, asi que esa igualdad es lo que garantiza que la app que creamos y la
//    que ve Flutter salgan del mismo registro. Es la letra pequeña de la nota
//    de tests/helpers.js: importar gstatic crea otro registro solo si la URL
//    difiere.
// 2. Escribimos `sessionStorage['[DEFAULT]-firebaseEmulatorOrigin']`. El
//    `useAuthEmulator` de firebase_auth_web (linea 552) se corta solo si el
//    origen coincide con esa clave, asi que la llamada de main.dart pasa a ser
//    un no-op en vez de un segundo `connectAuthEmulator` sobre un Auth ya
//    inicializado, que lanzaria `auth/emulator-config-failed`.
//
// El bootstrap de Flutter deja de ser `async` y lo inyectamos nosotros al
// final: si siguiera compitiendo, Flutter podria llamar a `initializeApp` antes
// de que el shim terminara y volveriamos al mismo fallo, ahora intermitente.

const fs = require('fs');
const path = require('path');

const raizRepo = path.resolve(__dirname, '..', '..');

// Tiene que ser una version que flutterfire soporte. `verificarVersionSdk`
// compara contra la del plugin y aborta el build si divergen: preferimos que el
// dia que firebase_core_web suba de version esto falle de golpe y no que el
// shim quede cargando un SDK distinto del de la app.
const VERSION_SDK_JS = '12.15.0';

const PUERTO_AUTH = 9099;

// Version de SDK de JS que espera firebase_core_web, o null si no se puede
// localizar el paquete en el cache de pub.
function versionSdkDelPlugin() {
  // Sin normalizar los saltos de linea esto no casa en Windows: pubspec.lock
  // llega con CRLF y el retorno de carro se cuela justo antes de cada salto,
  // asi que ningun salto del patron encuentra lo que busca.
  const lock = fs
    .readFileSync(path.join(raizRepo, 'pubspec.lock'), 'utf8')
    .split(String.fromCharCode(13))
    .join('');
  const bloque = lock.match(/^ {2}firebase_core_web:\n(?: {4,}.*\n)*/m);
  if (!bloque) return null;
  const version = bloque[0].match(/^ {4}version: "(.+)"$/m);
  if (!version) return null;

  const candidatos = [
    process.env.PUB_CACHE,
    path.join(process.env.LOCALAPPDATA || '', 'Pub', 'Cache'),
    path.join(process.env.APPDATA || '', 'Pub', 'Cache'),
    path.join(process.env.HOME || process.env.USERPROFILE || '', '.pub-cache'),
  ].filter(Boolean);

  for (const cache of candidatos) {
    const archivo = path.join(
      cache,
      'hosted',
      'pub.dev',
      `firebase_core_web-${version[1]}`,
      'lib',
      'src',
      'firebase_sdk_version.dart',
    );
    if (fs.existsSync(archivo)) {
      const m = fs
        .readFileSync(archivo, 'utf8')
        .match(/supportedFirebaseJsSdkVersion\s*=\s*'([^']+)'/);
      if (m) return m[1];
    }
  }
  return null;
}

function verificarVersionSdk() {
  const delPlugin = versionSdkDelPlugin();
  if (delPlugin === null) {
    console.warn(
      'Aviso: no se pudo leer la version de SDK de JS de firebase_core_web; ' +
        `el shim usara ${VERSION_SDK_JS} sin comprobarla.`,
    );
    return;
  }
  if (delPlugin !== VERSION_SDK_JS) {
    throw new Error(
      `firebase_core_web espera el SDK de JS ${delPlugin} pero el shim de ` +
        `emuladores fija ${VERSION_SDK_JS}. Actualiza VERSION_SDK_JS en ` +
        'e2e/scripts/shim-emuladores.js y vuelve a correr la suite: cargar una ' +
        'version distinta de la que flutterfire da por probada es exactamente ' +
        'el tipo de divergencia que este build no debe esconder.',
    );
  }
}

function opcionesFirebase() {
  const config = JSON.parse(
    fs.readFileSync(path.join(__dirname, '..', 'emulator-config.json'), 'utf8'),
  );
  // Los mismos valores que `--dart-define` mete en firebase_options.dart. Si
  // apiKey, databaseURL o storageBucket no coincidieran, firebase_core_web
  // lanzaria `duplicate-app` al encontrarse la app ya creada.
  return {
    apiKey: config.FIREBASE_WEB_API_KEY,
    appId: config.FIREBASE_APP_ID_WEB,
    messagingSenderId: config.FIREBASE_MESSAGING_SENDER_ID,
    projectId: config.FIREBASE_PROJECT_ID,
    authDomain: config.FIREBASE_AUTH_DOMAIN,
    databaseURL: config.FIREBASE_DATABASE_URL,
    storageBucket: config.FIREBASE_STORAGE_BUCKET,
    measurementId: config.FIREBASE_MEASUREMENT_ID,
  };
}

function html() {
  const opciones = JSON.stringify(opcionesFirebase(), null, 2).replace(
    /\n/g,
    '\n    ',
  );
  return [
    '<!-- AutoDoc E2E: inyectado por e2e/scripts/shim-emuladores.js. NO editar',
    '       aqui; esto es build/web, un artefacto. El original vive en',
    '       web/index.html y no lleva nada de esto. -->',
    `  <script>window.flutterfire_web_sdk_version = '${VERSION_SDK_JS}';</script>`,
    '  <script type="module">',
    `    const VERSION = '${VERSION_SDK_JS}';`,
    `    const OPCIONES = ${opciones};`,
    '',
    '    async function cablearAuthAlEmulador() {',
    '      // Candado: este bundle solo tiene sentido servido en local. Si',
    '      // acabara en un host real preferimos que no cree ninguna app aqui y',
    '      // que falle ruidosamente mas adelante, no que apunte a un localhost',
    '      // ajeno.',
    "      const local = ['localhost', '127.0.0.1'];",
    '      if (!local.includes(window.location.hostname)) return;',
    '',
    "      const base = 'https://www.gstatic.com/firebasejs/' + VERSION;",
    '      const [core, auth] = await Promise.all([',
    "        import(base + '/firebase-app.js'),",
    "        import(base + '/firebase-auth.js'),",
    '      ]);',
    '',
    '      const app = core.initializeApp(OPCIONES);',
    '',
    '      // `initializeAuth` con EXACTAMENTE las mismas opciones que usa',
    '      // flutterfire (firebase_auth_web/lib/src/interop/auth.dart:22), no un',
    '      // `getAuth` a secas. El SDK devuelve el instance ya creado solo si las',
    '      // dependencias coinciden; si difieren lanza `auth/already-initialized`,',
    '      // que es lo que hacia fallar el arranque entero y mandaba a la app a la',
    '      // pantalla de error de Firebase.',
    '      const instancia = auth.initializeAuth(app, {',
    '        errorMap: auth.debugErrorMap,',
    '        persistence: [',
    '          auth.indexedDBLocalPersistence,',
    '          auth.browserLocalPersistence,',
    '          auth.browserSessionPersistence,',
    '        ],',
    '        popupRedirectResolver: auth.browserPopupRedirectResolver,',
    '      });',
    '',
    `      const origen = 'http://' + window.location.hostname + ':${PUERTO_AUTH}';`,
    '      auth.connectAuthEmulator(instancia, origen, {',
    '        disableWarnings: true,',
    '      });',
    '      // Hace que el useAuthEmulator de main.dart sea un no-op en vez de un',
    '      // segundo connectAuthEmulator sobre un Auth ya inicializado.',
    "      window.sessionStorage.setItem('[DEFAULT]-firebaseEmulatorOrigin', origen);",
    '    }',
    '',
    '    try {',
    '      await cablearAuthAlEmulador();',
    '    } catch (e) {',
    '      // Que se vea en la consola que Playwright ya captura, y que la app',
    '      // arranque igual: sin el shim el sintoma es el de siempre y los',
    '      // tests que dependen de el fallan por su cuenta.',
    "      console.error('[AutoDoc E2E] fallo el shim de emuladores:', e);",
    '    }',
    '',
    '    // Flutter arranca AHORA, no en paralelo.',
    "    const bootstrap = document.createElement('script');",
    "    bootstrap.src = 'flutter_bootstrap.js';",
    '    document.body.appendChild(bootstrap);',
    '  </script>',
  ].join('\n');
}

const ETIQUETA_BOOTSTRAP = '<script src="flutter_bootstrap.js" async></script>';

function inyectar() {
  verificarVersionSdk();

  const indice = path.join(raizRepo, 'build', 'web', 'index.html');
  const original = fs.readFileSync(indice, 'utf8');

  if (original.includes('shim-emuladores.js')) {
    console.log('El shim de emuladores ya estaba inyectado.');
    return;
  }
  if (!original.includes(ETIQUETA_BOOTSTRAP)) {
    throw new Error(
      `No se encontro ${ETIQUETA_BOOTSTRAP} en ${indice}. Si Flutter cambio ` +
        'como arranca el bundle, este shim hay que reescribirlo: dejarlo pasar ' +
        'en silencio devolveria el fallo de la sesion persistida.',
    );
  }

  fs.writeFileSync(indice, original.replace(ETIQUETA_BOOTSTRAP, html()), 'utf8');
  console.log('Shim de emuladores inyectado en build/web/index.html.');
}

module.exports = { inyectar, VERSION_SDK_JS };

if (require.main === module) inyectar();
