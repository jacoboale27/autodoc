// Vuelve a publicar la ficha pública de cada taller (`talleres/{uid}`) a
// partir de su documento en `usuarios`.
//
//   node republicar_talleres.js            # dry-run: solo cuenta y muestra
//   node republicar_talleres.js --apply    # escribe
//
// PARA QUÉ: `publishTallerProfile` es un trigger `onWrite` de
// `usuarios/{uid}`, así que un campo NUEVO en la proyección —`telefono` y
// `municipio` desde el 2026-09-19— no aparece en las fichas ya publicadas
// hasta que alguien vuelve a tocar el documento de origen. Observación del
// 2026-09-20: «cuando el propietario busca la info pública del mecánico no le
// aparece el número de teléfono». No era un defecto de la pantalla: el campo
// no estaba en `talleres/{uid}` porque nadie había reescrito ese usuario
// desde el despliegue.
//
// NO es `src/backfillTalleres.js`. Ese script lleva su PROPIA copia de
// `CAMPOS_PUBLICOS`, congelada en ocho campos: correrlo hoy borraría de las
// fichas la galería, el teléfono, el municipio y el logo. Este reutiliza
// `construirPerfilPublico`, que es el mismo código que usa el trigger, así
// que no puede divergir.
const admin = require('firebase-admin');
admin.initializeApp();

const {
  construirPerfilPublico,
  esMecanico,
} = require('./src/publishTallerProfile');

const APLICAR = process.argv.includes('--apply');
const MAX_POR_LOTE = 400;

(async () => {
  const db = admin.firestore();
  const snap = await db.collection('usuarios').get();

  let publicados = 0;
  let retirados = 0;
  let omitidos = 0;
  let lote = db.batch();
  let enLote = 0;

  const commit = async () => {
    if (!APLICAR || enLote === 0) return;
    await lote.commit();
    lote = db.batch();
    enLote = 0;
  };

  for (const doc of snap.docs) {
    const data = doc.data() || {};
    const ref = db.collection('talleres').doc(doc.id);

    // Misma condición que el trigger: una sub-cuenta de empleado no tiene
    // ficha pública (`id_taller_propietario`), y un no-mecánico tampoco.
    if (!esMecanico(data.rol) || data.id_taller_propietario) {
      omitidos += 1;
      continue;
    }

    const perfil = construirPerfilPublico(doc.id, data, {
      GeoPoint: admin.firestore.GeoPoint,
    });
    if (perfil === null) {
      retirados += 1;
      if (APLICAR) {
        lote.delete(ref);
        enLote += 1;
      }
    } else {
      publicados += 1;
      if (APLICAR) {
        // `set` sin merge, igual que el trigger: la ficha pública es una
        // proyección, no un documento con vida propia. Con merge, un campo
        // que dejó de ser público se quedaría ahí para siempre.
        lote.set(ref, perfil);
        enLote += 1;
      }
    }
    if (enLote >= MAX_POR_LOTE) await commit();
  }
  await commit();

  console.log(
    `${APLICAR ? 'Publicadas' : 'Se publicarían'} ${publicados} fichas; ` +
      `${retirados} se ${APLICAR ? 'retiraron' : 'retirarían'}; ` +
      `${omitidos} usuarios no son talleres con ficha.`
  );
  if (!APLICAR) console.log('Dry-run: no se escribió nada. Usa --apply.');
  process.exit(0);
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
