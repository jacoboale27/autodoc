// Script de mantenimiento único (no es una Cloud Function desplegada) para el
// gap 1 del §5 de `docs/evidencia/GAPS-05-drenaje.md`: `checkAlertsDaily` pasa
// a consultar `avisos_pendientes == true` en vez de traerse todas las alertas
// `Pendiente` y descartar en memoria las que ya avisaron su último escalón.
//
// **Por qué es BLOQUEANTE y va ANTES de desplegar las funciones.**
// Una igualdad sobre un campo AUSENTE no devuelve nada. Ninguna alerta de
// producción tiene `avisos_pendientes`, así que en cuanto se despliegue el
// barrido nuevo sin haber corrido esto, la consulta diaria devuelve CERO
// documentos y **todas las alertas dejan de avisar, en silencio**. No hay
// error, no hay log, no hay suite que lo vea: el barrido informa de una
// corrida limpia con cero alertas revisadas.
//
// Es la misma trampa que `abierto` en GAPS-02 (el tablero de todos los
// talleres salía vacío) y que `estado` en H-01. Aquí se ensayó gratis: al
// añadir el filtro, once tests del barrido se pusieron rojos de golpe porque
// sus siembras no escribían el campo.
//
// **Qué estampa.** `avisos_pendientes = !(ultimo_aviso === 'vencida')`, que es
// la negación del estado terminal: con el último escalón ya consumido no queda
// ninguno por delante —`yaSeAviso()` devuelve true para todos— y esa alerta no
// volverá a avisar nunca. Cualquier otro valor de `ultimo_aviso`, incluido no
// tenerlo, deja avisos por delante.
//
// **Recorre TODAS las alertas, no solo las `Pendiente`.** El barrido solo mira
// las pendientes, pero `estado` es mutable: una alerta `Completada` que el
// usuario reabra volvería a la cola sin el campo, y sería invisible para
// siempre. Backfillear solo lo que hoy consulta el barrido deja esa puerta.
//
// **Va DESPUÉS de `backfill_ultimo_aviso.js`**, del que deriva: si se corre
// antes, las alertas que aquel va a marcar como `vencida` quedarían aquí con
// `avisos_pendientes: true` y recibirían un aviso de más. Uno, no una cascada.
//
// **No estampa ningún centinela de migración, y es deliberado**, por la misma
// razón que su hermano: `alertas` no tiene ningún trigger `onUpdate` que
// silenciar, y la tanda de drenaje anterior aprendió que estampar el centinela
// de más deja documentos vivos sin notificar PARA SIEMPRE.
//
// Uso (contra el proyecto real, con sus credenciales):
//   node backfill_avisos_pendientes.js            # dry-run: no escribe nada
//   node backfill_avisos_pendientes.js --apply

'use strict';

const admin = require('firebase-admin');

const APLICAR = process.argv.includes('--apply');
const LOTE = 500;

/**
 * La negación del estado terminal del barrido.
 *
 * Se deriva de ESCALONES en vez de comparar con `'vencida'` a pelo, para que
 * añadir un escalón nuevo no deje este backfill apagando alertas que todavía
 * tienen avisos por delante.
 *
 * @param {object} alerta
 * @param {string[]} escalones
 * @returns {boolean}
 */
function avisosPendientesDe(alerta, escalones) {
  const ultimo = escalones[escalones.length - 1];
  return (alerta || {}).ultimo_aviso !== ultimo;
}

async function main() {
  const { ESCALONES } = require('./src/alertasVencidas');
  admin.initializeApp();
  const db = admin.firestore();

  const resumen = { revisadas: 0, conAvisos: 0, sinAvisos: 0, yaTenian: 0 };
  let lote = db.batch();
  let enLote = 0;
  let cursor = null;

  for (;;) {
    let consulta = db.collection('alertas').orderBy('__name__').limit(LOTE);
    if (cursor) consulta = consulta.startAfter(cursor);

    const pagina = await consulta.get();
    if (pagina.empty) break;

    for (const doc of pagina.docs) {
      resumen.revisadas += 1;
      const alerta = doc.data();

      if (alerta.avisos_pendientes !== undefined) {
        // Idempotente: el script se puede volver a correr sin efecto.
        resumen.yaTenian += 1;
        continue;
      }

      const valor = avisosPendientesDe(alerta, ESCALONES);
      if (valor) resumen.conAvisos += 1;
      else resumen.sinAvisos += 1;

      if (APLICAR) {
        lote.update(doc.ref, { avisos_pendientes: valor });
        enLote += 1;
        if (enLote >= 400) {
          await lote.commit();
          lote = db.batch();
          enLote = 0;
        }
      }
    }

    if (pagina.size < LOTE) break;
    cursor = pagina.docs[pagina.docs.length - 1];
  }

  if (APLICAR && enLote > 0) await lote.commit();

  console.log(APLICAR ? 'APLICADO' : 'DRY-RUN (nada escrito)', resumen);
}

module.exports = { avisosPendientesDe };

if (require.main === module) {
  main().then(
    () => process.exit(0),
    (e) => {
      console.error(e);
      process.exit(1);
    }
  );
}
