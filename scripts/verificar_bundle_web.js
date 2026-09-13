// Guarda de despliegue: aborta si `build/web` no es un bundle de produccion.
//
// Se invoca desde el `predeploy` del objetivo `app` en `firebase.json`, que es
// el unico punto por el que pasa todo `firebase deploy --only hosting`.
//
// **El incidente que la origina (2026-09-13).** Se desplego a produccion el
// bundle de E2E. `e2e/scripts/build-web.js` compila con `--profile` y
// `--dart-define=USE_FIREBASE_EMULATOR=true`, y los dos candados de
// `lib/core/config/firebase_emulators.dart` son
// `_flagEmuladores && !kReleaseMode`: en `--profile` los DOS se abren. La app
// publicada llamo a `useAuthEmulator()`, el SDK de Firebase pinto su cartel
// «Running in emulator mode. Do not use with production credentials» a todo
// visitante, y Auth/Firestore/Storage apuntaron al `localhost` del propio
// visitante. Web caida para todo el mundo.
//
// **Por que ninguna suite podia verlo.** Todas miran el codigo fuente, y el
// codigo fuente estaba bien — los candados hacen justo lo que prometen. Lo que
// estaba mal era el ARTEFACTO, que no se versiona, y `firebase deploy` publica
// ese directorio sin mirarlo.
//
// **Que comprueba, y por que estas tres cosas.**
//
// 1. `main.dart.js` no contiene el rastro de `firebase_emulators.dart`. Es la
//    comprobacion que importa: detecta la CONDICION PELIGROSA (el cableado a
//    emuladores viaja compilado en el bundle), no un sintoma. En un build de
//    release ese archivo se elimina entero por tree-shaking, asi que su
//    ausencia es prueba positiva de que la conexion no puede ocurrir.
// 2. `index.html` no lleva el shim de emuladores que inyecta
//    `e2e/scripts/shim-emuladores.js`. Hoy ese shim se autodesactiva por
//    hostname, asi que por si solo es inocuo en un dominio real — pero su
//    presencia prueba que el artefacto salio del pipeline de E2E, y entonces
//    (1) tambien va a fallar. Se comprueba igual para dar un mensaje que diga
//    la verdad sobre el origen del bundle.
// 3. El bundle existe y no esta vacio. Un `build/web` a medias se publica tan
//    campante y deja la web en blanco.
//
// Uso directo (util antes de desplegar a mano):
//   node scripts/verificar_bundle_web.js

'use strict';

const fs = require('fs');
const path = require('path');

const raiz = path.resolve(__dirname, '..');
// Directorio a inspeccionar. Por defecto el que publica `firebase.json`; se
// puede pasar otro como argumento para verificar un bundle en CI o para
// ejercer esta guarda desde una prueba.
const dirBundle = process.argv[2]
  ? path.resolve(process.argv[2])
  : path.join(raiz, 'build', 'web');

/// Rastro de `conectarEmuladoresFirebase()` en el bundle compilado. Es el
/// `debugPrint` de `lib/core/config/firebase_emulators.dart`, que solo
/// sobrevive si ese archivo NO se elimino por tree-shaking — o sea, solo si el
/// build no es de release.
const RASTRO_EMULADORES = 'EMULADORES';

/// Marca literal que escribe `e2e/scripts/shim-emuladores.js` al inyectarse.
const MARCA_SHIM = 'AutoDoc E2E: inyectado por';

const problemas = [];

function exigirArchivo(relativo) {
  const completo = path.join(dirBundle, relativo);
  if (!fs.existsSync(completo)) {
    problemas.push(
      `Falta \`build/web/${relativo}\`. El bundle no esta compilado o quedo a medias.`,
    );
    return null;
  }
  const contenido = fs.readFileSync(completo, 'utf8');
  if (contenido.length === 0) {
    problemas.push(`\`build/web/${relativo}\` esta vacio.`);
    return null;
  }
  return contenido;
}

const indice = exigirArchivo('index.html');
const principal = exigirArchivo('main.dart.js');

if (indice !== null && indice.includes(MARCA_SHIM)) {
  problemas.push(
    '`index.html` lleva el shim de emuladores inyectado por ' +
      '`e2e/scripts/shim-emuladores.js`. Este bundle salio del pipeline de ' +
      'E2E, no de un build de produccion.',
  );
}

if (principal !== null && principal.includes(RASTRO_EMULADORES)) {
  problemas.push(
    '`main.dart.js` contiene el cableado a emuladores de ' +
      '`lib/core/config/firebase_emulators.dart`. En un build `--release` ese ' +
      'archivo se elimina por tree-shaking, asi que este bundle NO es de ' +
      'release: es `--profile` o `--debug`, donde `kReleaseMode` es false y ' +
      'los dos candados se abren. Publicarlo apunta Auth, Firestore y Storage ' +
      'al localhost de cada visitante y muestra el cartel de modo emulador.',
  );
}

if (problemas.length === 0) {
  console.log('[verificar_bundle_web] build/web es un bundle de produccion. OK.');
  process.exit(0);
}

console.error('');
console.error('DESPLIEGUE ABORTADO — build/web no es publicable:');
console.error('');
for (const p of problemas) console.error(`  - ${p}`);
console.error('');
console.error('Como arreglarlo:');
console.error('');
console.error('  flutter clean');
console.error('  flutter build web --release --dart-define=RECAPTCHA_SITE_KEY=... (y el resto)');
console.error('');
console.error('`flutter clean` no es opcional: sin el, el index.html inyectado');
console.error('por el pipeline de E2E sobrevive al siguiente build.');
console.error('');
process.exit(1);
