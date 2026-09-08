'use strict';

// Siembra los fixtures antes de la suite. Va como globalSetup y no como un
// paso previo del `npm test` para que tambien corra cuando alguien lanza un
// solo spec desde el editor: un fixture sembrado "a veces" es peor que ninguno,
// porque el spec pasa o falla segun lo que dejara la corrida anterior.

const { spawnSync } = require('child_process');
const path = require('path');

module.exports = async () => {
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
