// Script de mantenimiento único (no es una Cloud Function desplegada).
//
// Limpia los `vehiculos.foto_url` que apuntan FUERA de nuestro Storage.
//
// **De dónde salen.** Hasta el 2026-09-17 `VehicleProvider.addVehicle`
// llamaba a `VehicleImageService`, que buscaba en SearchAPI.io (engine
// `google_images`) una foto "estilo concesionario" de la marca y el modelo y
// guardaba ESE enlace, tal cual, en el documento del vehículo. O sea: cada
// vehículo creado desde que existe la app lleva enlazada una imagen de un
// tercero, servida desde el CDN de su dueño.
//
// **Por qué hay que limpiarlos y no basta con dejar de crearlos.** Son dos
// problemas y el segundo es el que no caduca solo:
//
//   - Propiedad intelectual: son fotos de catálogos de concesionario y bancos
//     de imagen sobre las que AutoDoc no tiene ninguna licencia, pintadas
//     como si fueran el coche de la persona. En una ficha de Google Play eso
//     es exposición a una retirada.
//   - Privacidad: `foto_url` la lee todo el que puede ver el vehículo —el
//     taller vinculado y sus empleados, aquel con quien el dueño lo comparta,
//     y por la vista pública quien reciba un pase de historial—, así que cada
//     visita le entrega al servidor ajeno la IP y el User-Agent del visitante.
//     Es exactamente el agujero que FUNC-01 cerró en `resenias.fotos`.
//
// **Qué escribe.** Borra el campo (`FieldValue.delete()`), no lo pone a la
// ruta del asset. La app ya cae al placeholder local cuando `foto_url` es
// nulo —`VehicleImageWidget`—, y guardar 'assets/images/default_vehicle.jpg'
// como si fuera una URL es justo la confusión que dejó el servicio anterior.
//
// **Qué NO toca.** Las URLs que ya apuntan a nuestro Storage
// (`firebasestorage.googleapis.com/.../vehiculos%2F{id}%2F...`): esas son
// fotos que el propietario subió con `VehiclePhotoService` y son suyas.
//
// **Orden de despliegue.** Da igual si va antes o después de las reglas: la
// regla nueva valida `foto_url` solo cuando CAMBIA (ver
// `fotoDeVehiculoValidaEnUpdate`), así que un vehículo con enlace heredado se
// sigue pudiendo editar mientras tanto. Lo que sí importa es que este script
// se corra: sin él la fuga sigue viva en cada vehículo ya existente, y
// ninguna suite puede avisar de eso — los emuladores se siembran limpios.
//
// Uso (contra el proyecto real, con sus credenciales):
//   node backfill_foto_url_ajena.js            # dry-run: no escribe nada
//   node backfill_foto_url_ajena.js --apply

'use strict';

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

const APLICAR = process.argv.includes('--apply');
const LOTE = 400;

/**
 * ¿La URL apunta a la carpeta de ESTE vehículo en nuestro propio Storage?
 *
 * Mismo criterio que `esUrlDeStoragePropia` en `firestore.rules`, y se
 * comprueba también el id del vehículo: una URL de nuestro bucket pero de
 * OTRO vehículo tampoco es legítima aquí.
 */
function esNuestra(url, vehiculoId) {
  if (typeof url !== 'string') return false;
  const prefijo = new RegExp(
    `^https://firebasestorage\.googleapis\.com/v0/b/[^/]+/o/vehiculos%2F${vehiculoId}%2F`,
  );
  return prefijo.test(url);
}

async function main() {
  const resumen = {
    revisados: 0,
    sinFoto: 0,
    propias: 0,
    placeholder: 0,
    ajenas: 0,
  };
  const muestras = [];
  let lote = db.batch();
  let enLote = 0;
  let cursor = null;

  for (;;) {
    let consulta = db.collection('vehiculos').orderBy('__name__').limit(LOTE);
    if (cursor) consulta = consulta.startAfter(cursor);

    const pagina = await consulta.get();
    if (pagina.empty) break;

    for (const doc of pagina.docs) {
      resumen.revisados += 1;
      const url = doc.data().foto_url;

      if (url === undefined || url === null || url === '') {
        resumen.sinFoto += 1;
        continue;
      }
      if (url === 'assets/images/default_vehicle.jpg') {
        // Lo escribía el servicio retirado cuando la búsqueda no encontraba
        // nada. No es una fuga, pero tampoco es una URL: se limpia igual para
        // que el campo signifique una sola cosa.
        resumen.placeholder += 1;
      } else if (esNuestra(url, doc.id)) {
        resumen.propias += 1;
        continue;
      } else {
        resumen.ajenas += 1;
        if (muestras.length < 10) muestras.push(`${doc.id} -> ${url}`);
      }

      if (APLICAR) {
        lote.update(doc.ref, {
          foto_url: admin.firestore.FieldValue.delete(),
        });
        enLote += 1;
        if (enLote >= 400) {
          await lote.commit();
          lote = db.batch();
          enLote = 0;
        }
      }
    }

    cursor = pagina.docs[pagina.docs.length - 1];
    if (pagina.size < LOTE) break;
  }

  if (APLICAR && enLote > 0) await lote.commit();

  console.log(APLICAR ? '== APLICADO ==' : '== DRY-RUN (nada escrito) ==');
  console.table(resumen);
  if (muestras.length > 0) {
    console.log('\nMuestra de enlaces ajenos encontrados:');
    for (const m of muestras) console.log('  ' + m);
  }
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
