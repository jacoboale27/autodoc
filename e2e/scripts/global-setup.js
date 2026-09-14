'use strict';

// Siembra los fixtures antes de la suite. Va como globalSetup y no como un
// paso previo del `npm test` para que tambien corra cuando alguien lanza un
// solo spec desde el editor: un fixture sembrado "a veces" es peor que ninguno,
// porque el spec pasa o falla segun lo que dejara la corrida anterior.

const { spawnSync } = require('child_process');
const path = require('path');

// Esperar al puerto del hub (4400), que es a lo que espera playwright.config.js,
// NO garantiza que los emuladores esten arriba: el hub abre antes que todos. En
// la suite de la landing eso se vio como los dos primeros tests fallando en
// 53 ms con ECONNREFUSED contra 8080 mientras el tercero pasaba tras 8 s. Aqui
// el sintoma es peor: la siembra falla y la corrida entera se cae antes de
// empezar.
//
// Y no basta con esperar a Firestore. La siembra tambien crea usuarios, o sea
// habla con Auth (9099), que levanta por su cuenta y puede ir por detras: el
// sintoma es `FirebaseAppError ... ECONNREFUSED` dentro de `crearUsuario`, con
// Firestore ya sirviendo. Se espera a los dos, cada uno por su propio puerto.
async function esperarEmulador(nombre, url, intentos = 90) {
  for (let i = 0; i < intentos; i++) {
    try {
      const res = await fetch(url);
      if (res.status < 500) return;
    } catch {
      // todavia no
    }
    await new Promise((r) => setTimeout(r, 1000));
  }
  throw new Error(`El emulador de ${nombre} no respondio en ${intentos} s.`);
}

module.exports = async () => {
  await Promise.all([
    esperarEmulador('Firestore', 'http://127.0.0.1:8080/'),
    esperarEmulador('Auth', 'http://127.0.0.1:9099/'),
    // INNO-01: el pase de historial son tres callables, asi que Functions
    // tambien tiene que estar arriba. Es el emulador mas lento de los cuatro
    // —carga `functions/index.js` entero con sus triggers— y si la suite
    // arrancara sin el, el primer canje fallaria con `internal` y se leeria
    // como un defecto de la pantalla.
    esperarEmulador('Functions', 'http://127.0.0.1:5001/'),
  ]);

  const r = spawnSync(
    process.execPath,
    [path.join(__dirname, 'seed-emulators.js')],
    { stdio: 'inherit' },
  );
  if (r.status !== 0) {
    throw new Error(
      'No se pudieron sembrar los fixtures. Sin ellos la suite mediria una app vacia.',
    );
  }
};
