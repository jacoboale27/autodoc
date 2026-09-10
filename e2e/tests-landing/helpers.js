'use strict';

// Acceso al Firestore del emulador con el Admin SDK, para comprobar que lo que
// el formulario dice haber enviado esta realmente escrito.
//
// Es la diferencia entre probar la pantalla y probar el flujo: la version
// anterior del formulario de afiliacion tenia su estado de exito implementado
// y jamas lo alcanzaba, porque el POST se denegaba. Un test que solo mirase el
// mensaje verde no habria visto nada raro.

const path = require('path');
const fs = require('fs');
const admin = require('firebase-admin');

const config = JSON.parse(
  fs.readFileSync(path.join(__dirname, '..', 'emulator-config.json'), 'utf8'),
);
const PROJECT_ID = config.FIREBASE_PROJECT_ID;

// 127.0.0.1 y no 'localhost': el emulador de Firestore escucha en IPv4, y el
// fetch de Node resuelve 'localhost' a ::1 primero — la limpieza del buzon
// fallaba con un 'TypeError: fetch failed' que no dice nada.
process.env.FIRESTORE_EMULATOR_HOST ||= '127.0.0.1:8080';

let app;
function db() {
  if (!app) app = admin.initializeApp({ projectId: PROJECT_ID }, 'landing-e2e');
  return admin.firestore(app);
}

// `fetch` de Node envuelve cualquier fallo de red en un escueto "fetch failed"
// que no dice ni la URL ni la causa: ante un rojo intermitente no hay por donde
// empezar. Este envoltorio pega las dos cosas al mensaje, y reintenta una vez
// porque el emulador rechaza alguna conexion suelta bajo carga en Windows.
async function borrarColeccion(coleccion) {
  const url =
    `http://${process.env.FIRESTORE_EMULATOR_HOST}` +
    `/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents/${coleccion}`;

  let ultimo;
  for (let intento = 0; intento < 2; intento++) {
    try {
      const res = await fetch(url, { method: 'DELETE' });
      if (!res.ok) throw new Error(`respondio ${res.status}`);
      return;
    } catch (e) {
      const causa = e.cause ? `${e.cause.code || ''} ${e.cause.message || ''}`.trim() : '';
      ultimo = `${e.message}${causa ? ` (${causa})` : ''}`;
    }
  }
  throw new Error(`DELETE ${url} fallo tras dos intentos: ${ultimo}`);
}

async function limpiarSolicitudes() {
  await borrarColeccion('solicitudes_landing');
  // El contador del limitador vive aparte y sobrevive entre tests: si no se
  // borra, los envios de la suite entera se acumulan contra el mismo cupo y el
  // rojo aparece en el test que toque, no en el que lo provoco.
  await borrarColeccion('solicitudes_landing_control');
}

// Intercepta la lectura del directorio publico que hace la propia pagina.
//
// No es por comodidad. Esa lectura es un GET REST desde el navegador al
// emulador de Firestore, y Chromium aborta las conexiones en vuelo al navegar:
// el emulador (Java/netty) responde con "Connection reset", y en Windows acaba
// MURIENDO a media suite — a partir de ahi todo da ECONNREFUSED contra 8080 y
// los rojos aparecen en tests que no tienen nada que ver. Es la rareza que
// CLAUDE.md ya tenia documentada, aqui provocada de forma casi determinista.
//
// El directorio no es lo que prueba UX-01: los formularios siguen yendo al
// endpoint real contra el emulador de Functions, que es lo que importa. Y que
// el alta NO se publique en /talleres se comprueba mejor por el Admin SDK
// (`talleres()`) que mirando la pantalla.
async function stubDirectorio(page) {
  await page.route('**/documents/talleres*', (ruta) =>
    ruta.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        documents: [
          {
            name: 'projects/autodoc-e2e/databases/(default)/documents/talleres/demo',
            fields: {
              nombre: { stringValue: 'Taller Demo E2E' },
              especialidad: { stringValue: 'Mecánica General' },
              ubicacion_municipio: { stringValue: 'San Salvador' },
              estado: { stringValue: 'aprobado' },
              // Firestore REST serializa doubleValue e integerValue como
              // strings, aunque conceptualmente sean numeros.
              calificacion_promedio: { doubleValue: '4.5' },
            },
          },
        ],
      }),
    }),
  );
}

async function talleres() {
  const snap = await db().collection('talleres').get();
  return snap.docs.map((d) => d.data());
}

async function solicitudes(tipo) {
  const snap = await db().collection('solicitudes_landing').get();
  const docs = snap.docs.map((d) => d.data());
  return tipo ? docs.filter((d) => d.tipo === tipo) : docs;
}

module.exports = { PROJECT_ID, limpiarSolicitudes, solicitudes, talleres, stubDirectorio };
