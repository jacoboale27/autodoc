'use strict';

// Espera a que los emuladores esten REALMENTE listos antes del primer test.
//
// El sintoma que motiva este archivo: los dos primeros tests fallaban en 53 ms
// con ECONNREFUSED contra 8080 y el tercero pasaba tras 8 s. No era el emulador
// muriendose a media suite (la rareza de Windows que ya esta documentada), era
// que aun no habia arrancado: la config de Playwright espera al puerto del HUB
// (4400), que abre bastante antes que Firestore y mucho antes de que el
// emulador de Functions termine de cargar los triggers del entrypoint.
//
// Esperar al hub es esperar a la pieza equivocada. Aqui se espera a las dos que
// la suite usa de verdad, cada una por su propia senal.

const PROJECT_ID = 'autodoc-e2e';
const FIRESTORE = 'http://127.0.0.1:8080/';
const FUNCION =
  `http://127.0.0.1:5001/${PROJECT_ID}/us-central1/recibirSolicitudLanding`;

async function esperar(nombre, comprobar, intentos = 90) {
  for (let i = 0; i < intentos; i++) {
    try {
      if (await comprobar()) return;
    } catch {
      // todavia no
    }
    await new Promise((r) => setTimeout(r, 1000));
  }
  throw new Error(`${nombre} no respondio tras ${intentos}s`);
}

module.exports = async () => {
  await esperar('El emulador de Firestore', async () => {
    const res = await fetch(FIRESTORE);
    return res.status < 500;
  });

  // El preflight es la senal buena: solo responde cuando el runtime ya cargo
  // index.js y registro la funcion. Un 404 significa que sigue cargando.
  await esperar('El endpoint recibirSolicitudLanding', async () => {
    const res = await fetch(FUNCION, {
      method: 'OPTIONS',
      headers: { origin: 'http://localhost:5556' },
    });
    return res.status === 204;
  });

  console.log('Emuladores listos: Firestore (8080) y la funcion (5001).');
};
