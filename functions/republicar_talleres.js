// Vuelve a publicar la ficha pública de cada taller (`talleres/{uid}`) a
// partir de su documento en `usuarios`.
//
// SE CORRE DESDE `functions/`, que es donde está firebase-admin:
//
//   cd functions
//   node republicar_talleres.js            # dry-run: solo cuenta y muestra
//   node republicar_talleres.js --apply    # escribe
//
// CREDENCIALES. Igual que `backfill_ultimo_aviso.js`: pon la clave de cuenta
// de servicio del proyecto en `functions/serviceAccountKey.json` (Firebase →
// Configuración del proyecto → Cuentas de servicio → Generar nueva clave
// privada) y bórrala al terminar; está en `.gitignore`, pero es una llave
// maestra del proyecto. Si no hay fichero se usan las credenciales por
// defecto del entorno (`GOOGLE_APPLICATION_CREDENTIALS` o
// `gcloud auth application-default login`), y entonces hay que decir a qué
// proyecto se escribe con `--project=<id>`.
//
// El proyecto SIEMPRE se imprime antes de tocar nada, y sin uno resuelto el
// script se niega a arrancar: `.firebaserc` tiene `default: autodoc-staging`,
// así que «el de por defecto» no es producción y una republicación contra el
// proyecto equivocado no avisa de nada.
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
const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

const APLICAR = process.argv.includes('--apply');
const MAX_POR_LOTE = 400;

/** `--project=<id>`, o `null`. */
function proyectoDeLosArgumentos() {
  const arg = process.argv.find((a) => a.startsWith('--project='));
  return arg ? arg.slice('--project='.length) : null;
}

/**
 * Arranca el Admin SDK y devuelve el id del proyecto al que se va a escribir.
 *
 * Con clave de cuenta de servicio el proyecto sale de la propia clave, que es
 * lo más difícil de equivocar. Sin ella hay que nombrarlo: no se hereda
 * ningún valor por defecto a ciegas.
 */
function arrancar() {
  const ruta = path.join(__dirname, 'serviceAccountKey.json');
  if (fs.existsSync(ruta)) {
    const sa = JSON.parse(fs.readFileSync(ruta, 'utf8'));
    const pedido = proyectoDeLosArgumentos();
    if (pedido && pedido !== sa.project_id) {
      throw new Error(
        `La clave es del proyecto ${sa.project_id} y pediste ${pedido}. ` +
          'Usa la clave del proyecto correcto.'
      );
    }
    admin.initializeApp({
      credential: admin.credential.cert(sa),
      projectId: sa.project_id,
    });
    return sa.project_id;
  }

  const proyecto =
    proyectoDeLosArgumentos() ||
    process.env.GOOGLE_CLOUD_PROJECT ||
    process.env.GCLOUD_PROJECT;
  if (!proyecto) {
    throw new Error(
      'No sé a qué proyecto escribir. Pon la clave en ' +
        'functions/serviceAccountKey.json, o pasa --project=<id> ' +
        '(producción es autodoc-6ef5a; el de por defecto es staging).'
    );
  }
  admin.initializeApp({ projectId: proyecto });
  return proyecto;
}

const PROYECTO = arrancar();

const {
  construirPerfilPublico,
  esMecanico,
} = require('./src/publishTallerProfile');

(async () => {
  console.log(
    `Proyecto: ${PROYECTO}` +
      (APLICAR ? '  (ESCRIBIENDO)' : '  (dry-run, no escribe)')
  );
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
  const texto = String((e && e.message) || e);
  // El fallo típico de la primera vez: se nombró el proyecto pero la máquina
  // no tiene credenciales. El mensaje de Google dice «Could not load the
  // default credentials» y enlaza a su documentación genérica; esto dice qué
  // hacer AQUÍ.
  if (/default credentials|GOOGLE_APPLICATION_CREDENTIALS/i.test(texto)) {
    console.error(
      'Faltan credenciales de administrador. ' +
        'Descarga la clave en Firebase → Configuración del proyecto → ' +
        'Cuentas de servicio → Generar nueva clave privada, guárdala como ' +
        'functions/serviceAccountKey.json, vuelve a correr esto y BÓRRALA al ' +
        'terminar: es una llave maestra del proyecto.'
    );
  }
  console.error(e);
  process.exit(1);
});
