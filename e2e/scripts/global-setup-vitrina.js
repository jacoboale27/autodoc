'use strict';

// globalSetup de la suite de CAPTURAS. Es gemelo de global-setup.js salvo en
// una linea —siembra seed-vitrina.js en vez de seed-emulators.js— y se
// mantiene aparte a proposito: si las capturas reutilizaran el setup de la
// suite de tests, cada corrida de capturas dejaria los fixtures de vitrina
// donde los specs de test esperan los suyos, y al reves. Los dos seeds empiezan
// por borrar Firestore entero, asi que el ultimo que corre gana.
//
// Las esperas son las mismas y por los mismos motivos que alli: el puerto del
// hub (4400) abre antes que los emuladores de verdad, y sembrar toca Firestore
// Y Auth, que levantan por separado.

const { spawnSync } = require('child_process');
const path = require('path');

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
    esperarEmulador('Functions', 'http://127.0.0.1:5001/'),
  ]);

  const r = spawnSync(
    process.execPath,
    [path.join(__dirname, 'seed-vitrina.js')],
    { stdio: 'inherit' },
  );
  if (r.status !== 0) {
    throw new Error(
      'No se pudo sembrar la vitrina. Sin fixtures, las capturas saldrian de una app vacia.',
    );
  }
};
