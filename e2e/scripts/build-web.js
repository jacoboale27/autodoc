#!/usr/bin/env node
'use strict';

// Compila el bundle web que ejercita la suite E2E, apuntado a los emuladores.
//
// Tres decisiones que parecen rodeos y no lo son:
//
// 1. `flutter build web`, no `flutter run`. El modo debug web admite un solo
//    cliente de depuracion: si Playwright abre la pagina servida por dwds
//    mientras el navegador propio de Flutter esta conectado, `-d chrome` muere
//    con "Cannot find context with specified id" y `-d web-server` deja la
//    pagina en blanco para siempre. Ademas el bundle compilado es el mismo
//    artefacto que publica Firebase Hosting, asi que la suite prueba lo que se
//    despliega.
//
// 2. `flutter clean` antes. Un `build/` sucio puede emitir un bundle
//    incompleto —`assets/` vacio, sin `manifest.json`— y el sintoma es una app
//    que arranca a medias sin ningun error de compilacion. No es opcional.
//
// 3. Los defines se expanden uno a uno en vez de usar
//    `--dart-define-from-file`. Esa bandera compila sin quejarse y deja el
//    bundle con las claves VACIAS; la app muere despues en
//    `auth/invalid-api-key`, lejos de la causa.

const { spawnSync } = require('child_process');
const path = require('path');
const fs = require('fs');

const raizRepo = path.resolve(__dirname, '..', '..');
const config = JSON.parse(
  fs.readFileSync(path.join(__dirname, '..', 'emulator-config.json'), 'utf8'),
);

const defines = Object.entries(config)
  .filter(([clave]) => !clave.startsWith('_'))
  .map(([clave, valor]) => `--dart-define=${clave}=${valor}`);

// El flag que redirige los SDK a los emuladores. Sin esto el bundle apunta a
// donde digan las claves de arriba, que son falsas: fallaria ruidosamente en
// vez de tocar produccion, pero fallaria.
defines.push('--dart-define=USE_FIREBASE_EMULATOR=true');

function corre(comando, args) {
  console.log(`\n> ${comando} ${args.join(' ')}\n`);
  const r = spawnSync(comando, args, {
    cwd: raizRepo,
    stdio: 'inherit',
    shell: process.platform === 'win32',
  });
  if (r.status !== 0) {
    console.error(`\nFallo: ${comando} salio con codigo ${r.status}`);
    process.exit(r.status === null ? 1 : r.status);
  }
}

// `--profile`, no el release por defecto de `flutter build web`.
//
// El cableado a emuladores esta protegido con `!kReleaseMode` (ver
// lib/core/config/firebase_emulators.dart), precisamente para que un
// `--dart-define` arrastrado por error a un build de produccion no publique
// una app apuntando a un localhost. En un build de release esa constante es
// true y el redirect no ocurre, asi que Auth se va al endpoint REAL con las
// claves falsas de emulator-config.json y todo muere en
// `auth/api-key-not-valid` — ruidoso e inofensivo, que era el diseño, pero
// inservible para la suite.
//
// Profile es codigo compilado igual que release (nada de dwds ni del cliente
// de depuracion unico que rompe Playwright), pero con kReleaseMode en false.
// Es el unico modo que satisface las dos condiciones a la vez.
corre('flutter', ['clean']);
corre('flutter', ['build', 'web', '--profile', ...defines]);

const indice = path.join(raizRepo, 'build', 'web', 'index.html');
if (!fs.existsSync(indice)) {
  console.error(`\nEl build termino pero no hay ${indice}.`);
  process.exit(1);
}
console.log('\nBundle listo en build/web, apuntado a los emuladores.');
