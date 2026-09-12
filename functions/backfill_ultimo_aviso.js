// Script de mantenimiento único (no es una Cloud Function desplegada) para
// OPS-01: `checkAlertsDaily` gana un campo de control, `ultimo_aviso`, que
// impide que la misma alerta se notifique cada 24 h para siempre.
//
// **Por qué hace falta correrlo ANTES de desplegar las funciones.**
// `ultimo_aviso` no existe en ningún documento de producción, así que en la
// primera corrida del barrido nuevo `yaSeAviso()` devuelve false para TODAS
// las alertas pendientes que estén vencidas o dentro de la ventana de siete
// días. Eso es el volumen acumulado histórico entero en una sola ejecución:
// N pushes, N escrituras en `notificaciones` y N `update` sobre `alertas`,
// todo secuencial y con el presupuesto de tiempo de una sola invocación.
//
// Y el caso que más documentos acumula es justamente el que este cambio
// arregla: alertas vencidas que nadie cierra a mano, que llevan meses
// notificándose a diario. Cuanto peor era el defecto, más grande es la
// estampida al arreglarlo.
//
// **Qué estampa, y por qué eso no le quita ningún aviso a nadie.** A cada
// alerta pendiente se le escribe el escalón en el que está HOY — `por_vencer`
// o `vencida`— y nada más:
//
//   - una alerta que hoy está `por_vencer` recibe `por_vencer`, así que su
//     aviso de vencimiento seguirá saliendo cuando de verdad venza;
//   - una que ya está `vencida` recibe `vencida`, y deja de repetirse;
//   - una que aún no entra en la ventana no recibe nada, y avisará normal
//     cuando le toque.
//
// Ninguna pierde información: el sistema anterior ya les venía mandando ese
// mismo aviso todos los días, así que el usuario ya está enterado. Lo único
// que se suprime es la repetición.
//
// **No estampa ningún centinela de migración, y es deliberado.** `alertas` no
// tiene ningún trigger `onUpdate` (los únicos accesos del servidor a esa
// colección son este barrido y el borrado en cascada de `onVehicleDelete`),
// así que no hay nada que silenciar. La tanda de drenaje anterior aprendió por
// las malas que estampar el centinela de más deja documentos vivos sin
// notificar sus transiciones PARA SIEMPRE, porque ese centinela es pegajoso:
// aquí no se toca.
//
// Uso (contra el proyecto real, con sus credenciales):
//   node backfill_ultimo_aviso.js            # dry-run: no escribe nada
//   node backfill_ultimo_aviso.js --apply

'use strict';

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

const { estadoDeAviso } = require('./src/alertasVencidas');

const APLICAR = process.argv.includes('--apply');
const LOTE = 400;

function leerFechaLimite(valor) {
  if (!valor) return null;
  const fecha = typeof valor.toDate === 'function' ? valor.toDate() : new Date(valor);
  return Number.isNaN(fecha.getTime()) ? null : fecha;
}

async function main() {
  const ahora = new Date();
  const resumen = { revisadas: 0, porVencer: 0, vencidas: 0, fueraDeVentana: 0, ilegibles: 0, yaTenian: 0 };
  let lote = db.batch();
  let enLote = 0;
  let cursor = null;

  for (;;) {
    let consulta = db
      .collection('alertas')
      .where('estado', '==', 'Pendiente')
      .orderBy('__name__')
      .limit(LOTE);
    if (cursor) consulta = consulta.startAfter(cursor);

    const pagina = await consulta.get();
    if (pagina.empty) break;

    for (const doc of pagina.docs) {
      resumen.revisadas += 1;
      const alerta = doc.data();

      if (alerta.ultimo_aviso) {
        resumen.yaTenian += 1;
        continue;
      }
      const fechaLimite = leerFechaLimite(alerta.fecha_limite);
      if (!fechaLimite) {
        resumen.ilegibles += 1;
        continue;
      }
      const escalon = estadoDeAviso(fechaLimite, ahora);
      if (!escalon) {
        // Todavía no entra en la ventana: no se estampa nada, para que su
        // primer aviso salga normal cuando le toque.
        resumen.fueraDeVentana += 1;
        continue;
      }

      if (escalon === 'vencida') resumen.vencidas += 1;
      else resumen.porVencer += 1;

      if (APLICAR) {
        lote.update(doc.ref, { ultimo_aviso: escalon, fecha_ultimo_aviso: ahora });
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

  console.log(JSON.stringify(resumen, null, 2));
  console.log(
    APLICAR
      ? `\nEstampadas ${resumen.porVencer + resumen.vencidas} alertas. Ya se puede desplegar el barrido nuevo.`
      : '\nDry-run terminado: vuelve a correrlo con --apply para escribir.'
  );
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
