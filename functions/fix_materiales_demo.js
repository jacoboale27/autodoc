// Arreglo de un solo uso: `seed_demo_interacciones.js` escribió
// `servicios/demo-servicio-historico` con `materiales: 25` (un monto) en vez
// de la lista de repuestos que espera `ServiceRecordModel.materiales` /
// `CotizacionItem` (List<Map>). `List<Map>.from(25)` revienta con
// "type 'int' is not a subtype of type 'Iterable<dynamic>'" al leer ESE
// documento, y como se lee dentro de un `.map()` sobre TODO el historial del
// taller, tira abajo la pantalla completa de "Mis Servicios", no solo la
// tarjeta de este servicio.
//
// Este script reescribe el campo con la lista correcta (ya corregida también
// en seed_demo_interacciones.js, para que una re-siembra no vuelva a romperlo).
//
// Uso: node fix_materiales_demo.js

const admin = require('firebase-admin');
const path = require('path');

admin.initializeApp({
  credential: admin.credential.cert(require(path.join(__dirname, 'serviceAccountKey.json'))),
  projectId: 'autodoc-6ef5a',
});
const db = admin.firestore();

async function main() {
  const ref = db.collection('servicios').doc('demo-servicio-historico');
  const doc = await ref.get();
  if (!doc.exists) {
    console.log('demo-servicio-historico no existe, nada que arreglar.');
    process.exit(0);
  }

  console.log('Antes:', JSON.stringify(doc.data()));

  if (Array.isArray(doc.data().materiales)) {
    console.log('El campo materiales ya es una lista, nada que arreglar.');
    process.exit(0);
  }

  await ref.update({
    materiales: [
      { nombre: 'Aceite sintético 5W-30', costo: 15 },
      { nombre: 'Filtro de aceite', costo: 10 },
    ],
  });

  const after = await ref.get();
  console.log('Después:', JSON.stringify(after.data()));
  console.log('Listo.');
  process.exit(0);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
