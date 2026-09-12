'use strict';

/**
 * OPS-01 — respaldo programado de Firestore.
 *
 * `scheduledFirestoreExport` es la unica copia de seguridad del proyecto y
 * tampoco tenia test. Lo que la extraccion deja ver:
 *
 * **Sin `projectId` la exportacion no fallaba: exportaba a una ruta basura.**
 * `client.databasePath(undefined, '(default)')` construye
 * `projects/undefined/databases/(default)` sin protestar, y el bucket sale
 * como `gs://undefined-backups`. El error que llega despues habla de un
 * recurso que no existe, no de la variable que falta — y el respaldo diario
 * lleva sin hacerse desde que se desplego.
 *
 * **El bucket no se puede fijar por entorno.** Estaba cableado a
 * `gs://<projectId>-backups`, asi que staging y produccion no podian escribir
 * en destinos distintos del mismo modo que ya hacen con las claves.
 *
 * Lo que este archivo NO puede probar, y por eso va al runbook: que el bucket
 * exista, que la cuenta de servicio tenga `roles/datastore.importExportAdmin`
 * y que haya politica de ciclo de vida. Sin las tres, esta funcion falla —o
 * peor, acumula copias para siempre— y ningun test lo ve.
 */

const assert = require('assert');

const {
  SUFIJO_BUCKET_RESPALDO,
  rutaDeRespaldo,
  exportarFirestore,
} = require('../src/exportacionFirestore');

function fakeClient(opciones) {
  const o = opciones || {};
  const llamadas = [];
  return {
    llamadas,
    databasePath: (projectId, base) => `projects/${projectId}/databases/${base}`,
    async exportDocuments(peticion) {
      llamadas.push(peticion);
      if (o.falla) throw new Error(o.falla);
      return [{ name: 'operations/exportar-1' }];
    },
  };
}

describe('exportacionFirestore / rutaDeRespaldo', () => {
  it('deriva el bucket del proyecto cuando no se fija uno', () => {
    const r = rutaDeRespaldo({ projectId: 'autodoc-6ef5a' });
    assert.strictEqual(r.bucket, `gs://autodoc-6ef5a${SUFIJO_BUCKET_RESPALDO}`);
    assert.strictEqual(r.baseDeDatos, 'projects/autodoc-6ef5a/databases/(default)');
  });

  it('respeta un bucket fijado explicitamente, para separar staging de produccion', () => {
    const r = rutaDeRespaldo({ projectId: 'autodoc-staging', bucket: 'gs://respaldos-qa' });
    assert.strictEqual(r.bucket, 'gs://respaldos-qa');
  });

  it('sin projectId falla en vez de construir gs://undefined-backups', () => {
    // El defecto. Antes esto seguia adelante y el error posterior hablaba de
    // un bucket inexistente, no de la variable que falta.
    assert.throws(() => rutaDeRespaldo({}), /projectId/i);
  });
});

describe('exportacionFirestore / exportarFirestore', () => {
  it('pide la exportacion de la base entera al bucket del proyecto', async () => {
    const client = fakeClient();
    const r = await exportarFirestore(client, { projectId: 'autodoc-6ef5a' });

    assert.strictEqual(client.llamadas.length, 1);
    assert.deepStrictEqual(client.llamadas[0], {
      name: 'projects/autodoc-6ef5a/databases/(default)',
      outputUriPrefix: 'gs://autodoc-6ef5a-backups',
    });
    assert.strictEqual(r.name, 'operations/exportar-1');
  });

  it('propaga el fallo para que Cloud Scheduler reintente', async () => {
    // Un respaldo que falla en silencio es peor que no tener respaldo: nadie
    // se entera hasta que hace falta restaurar.
    const client = fakeClient({ falla: 'PERMISSION_DENIED' });
    await assert.rejects(
      () => exportarFirestore(client, { projectId: 'autodoc-6ef5a' }),
      /PERMISSION_DENIED/
    );
  });

  it('no llega a llamar al cliente si falta la configuracion', async () => {
    const client = fakeClient();
    await assert.rejects(() => exportarFirestore(client, {}), /projectId/i);
    assert.deepStrictEqual(client.llamadas, []);
  });
});
