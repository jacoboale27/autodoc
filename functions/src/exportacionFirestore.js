'use strict';

/**
 * OPS-01 — respaldo programado de Firestore.
 *
 * Extraido de `scheduledFirestoreExport` para poder ejercerlo con un cliente
 * doble. Ver `functions/test/exportacion_firestore.test.js`.
 *
 * **Prerrequisitos que este modulo no puede comprobar** y que van al runbook
 * (`docs/RUNBOOK.md`, seccion "Respaldo de Firestore"):
 *
 *   1. el bucket de destino debe existir y estar en la misma region;
 *   2. la cuenta de servicio de la funcion necesita
 *      `roles/datastore.importExportAdmin` y permiso de escritura en el bucket;
 *   3. el bucket necesita politica de ciclo de vida, o las copias diarias se
 *      acumulan indefinidamente y el coste crece sin techo.
 *
 * Ninguno de los tres lo ve un test, y sin los tres esta funcion no respalda
 * nada.
 */

const SUFIJO_BUCKET_RESPALDO = '-backups';

/**
 * Resuelve a donde va la copia.
 *
 * @param {{projectId?: string, bucket?: string}} config
 * @returns {{baseDeDatos: string, bucket: string}}
 */
function rutaDeRespaldo(config = {}) {
  const projectId = config.projectId;
  if (!projectId) {
    // Antes esto seguia adelante: `databasePath(undefined, ...)` construye
    // `projects/undefined/...` sin protestar y el bucket salia
    // `gs://undefined-backups`. El error que llegaba despues hablaba de un
    // recurso inexistente, no de la variable que faltaba, y el respaldo
    // diario podia llevar meses sin hacerse sin que nadie lo notara.
    throw new Error(
      'No hay projectId: define GCP_PROJECT o GCLOUD_PROJECT antes de exportar Firestore'
    );
  }
  return {
    baseDeDatos: `projects/${projectId}/databases/(default)`,
    bucket: config.bucket || `gs://${projectId}${SUFIJO_BUCKET_RESPALDO}`,
  };
}

/**
 * Lanza la exportacion completa de Firestore a Cloud Storage.
 *
 * @param {object} client `firestore.v1.FirestoreAdminClient` o un doble
 * @param {{projectId?: string, bucket?: string}} config
 */
async function exportarFirestore(client, config = {}) {
  const { baseDeDatos, bucket } = rutaDeRespaldo(config);
  const [respuesta] = await client.exportDocuments({
    name: baseDeDatos,
    outputUriPrefix: bucket,
  });
  return respuesta;
}

module.exports = {
  SUFIJO_BUCKET_RESPALDO,
  rutaDeRespaldo,
  exportarFirestore,
};
