'use strict';

// Siembra los fixtures antes de la suite. Va como globalSetup y no como un
// paso previo del `npm test` para que tambien corra cuando alguien lanza un
// solo spec desde el editor: un fixture sembrado "a veces" es peor que ninguno,
// porque el spec pasa o falla segun lo que dejara la corrida anterior.

const { spawnSync } = require('child_process');
const path = require('path');

// Esperar al puerto del hub (4400), que es a lo que espera playwright.config.js,
// NO garantiza que Firestore este arriba: el hub abre antes. En la suite de la
// landing eso se vio como los dos primeros tests fallando en 53 ms con
// ECONNREFUSED contra 8080 mientras el tercero pasaba tras 8 s. Aqui el sintoma
// seria peor —la siembra falla y la corrida entera se cae antes de empezar—,
// asi que se espera a Firestore de verdad antes de sembrar.
async function esperarFirestore(intentos = 90) {
  for (let i = 0; i < intentos; i++) {
    try {
      const res = await fetch('http://127.0.0.1:8080/');
      if (res.status < 500) return;
    } catch {
      // todavia no
    }
    await new Promise((r) => setTimeout(r, 1000));
  }
  throw new Error('El emulador de Firestore no respondio en 90 s.');
}

module.exports = async () => {
  await esperarFirestore();

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
