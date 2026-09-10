'use strict';

const { revocarVinculo } = require('./vinculoTaller');

/**
 * Residual 7.2 de FUNC-02 — la posesion del coche caduca sola.
 *
 * El vinculo taller-vehiculo sigue a la POSESION: se otorga al recibir el
 * coche y se revoca al cerrarse el ticket. Lo que faltaba es que **nadie
 * caduca la posesion**. Un taller que simplemente nunca mueva el ticket a
 * `entregado` conserva `talleres_vinculados` —y con el la ficha del coche, su
 * galeria, sus alertas y el historial que escribieron otros talleres—
 * indefinidamente. El cierre dependia por completo de su buena voluntad.
 *
 * **Caduca el ACCESO, no el ticket.** El ticket sigue abierto y en su estado:
 * es trabajo del taller y no le corresponde a una funcion programada darlo por
 * terminado ni inventarse una fecha de entrega. Y es reversible sin que nadie
 * intervenga — `recibirTicketYVincular` reasegura el vinculo mientras el
 * ticket no este cerrado, y la pantalla de servicio ya ofrece ese reintento—,
 * asi que una reparacion larga de verdad (un repuesto que tarda dos meses) se
 * recupera con un toque, mientras que una abandonada deja de dar acceso a la
 * ficha de un desconocido.
 *
 * **Por que el barrido filtra por `vinculo_activo` y no por el estado del
 * ticket.** Un ticket abandonado sigue abandonado despues de caducarle el
 * vinculo: si la consulta lo siguiera viendo, cada corrida reprocesaria los
 * mismos, la ventana se llenaria de tickets ya caducados y los que se quedan
 * rancios DESPUES no llegarian a barrerse nunca. El campo dice "este ticket
 * tiene ahora mismo un vinculo vivo" y lo mantienen los dos extremos: lo pone
 * `recibirTicketYVincular` al otorgar y lo quita `revocarVinculoAlCerrar` al
 * cerrar.
 *
 * Los tickets anteriores a este cambio no traen el campo, asi que el barrido
 * no los ve. No es un hueco nuevo: son exactamente la poblacion de vinculos
 * rancios que limpia la pasada 3 de `backfill_entregado.js`.
 */

/** Dias sin actividad tras los que el taller pierde el acceso a la ficha. */
const DIAS_CADUCIDAD_VINCULO = 30;

/** Campo que marca "este ticket tiene ahora mismo un vinculo vivo". */
const CAMPO_VINCULO_ACTIVO = 'vinculo_activo';

/**
 * Tope por corrida. Acota el coste de una sola invocacion; lo que sobre se
 * barre en la corrida siguiente, porque cada ticket procesado deja de
 * coincidir con la consulta.
 */
const TOPE_POR_CORRIDA = 200;

/** Cuantos tickets se caducan a la vez dentro de una corrida. */
const TANDA = 20;

/**
 * Revoca el vinculo de los tickets abiertos sin actividad desde hace `dias`.
 *
 * @param {FirebaseFirestore.Firestore} db
 * @param {{ahora: Date, dias?: number, tope?: number}} args
 * @returns {Promise<{revisados: number, caducados: number, fallidos: number}>}
 */
async function caducarVinculosInactivos(db, { ahora, dias, tope }) {
  const plazo = dias === undefined ? DIAS_CADUCIDAD_VINCULO : dias;
  const corte = new Date(ahora.getTime() - plazo * 24 * 60 * 60 * 1000);

  const snap = await db
    .collection('reparaciones')
    .where(CAMPO_VINCULO_ACTIVO, '==', true)
    .where('fecha_actualizacion', '<', corte)
    .limit(tope === undefined ? TOPE_POR_CORRIDA : tope)
    .get();

  const caducarUno = async (doc) => {
    const ticket = doc.data();
    try {
      await revocarVinculo(db, {
        idVehiculo: (ticket.id_vehiculo || '').toString(),
        idTaller: (ticket.id_taller || '').toString(),
      });
      // Las dos escrituras van EN ORDEN a proposito: si se marcara el ticket
      // antes de revocar y la revocacion fallara, el barrido no volveria a
      // verlo nunca y el vinculo quedaria vivo para siempre.
      //
      // Se marca aunque el vehiculo ya no exista: `revocarVinculo` trata el
      // not-found como caso normal (no hay vinculo que revocar), y dejar el
      // ticket marcado como vinculado solo haria que el barrido lo reintentara
      // en cada corrida.
      await doc.ref.update({ [CAMPO_VINCULO_ACTIVO]: false });
      return true;
    } catch (error) {
      // Un fallo no puede parar el barrido: los demas tickets del lote siguen
      // teniendo un vinculo que caducar. Se cuenta, se registra, y el ticket
      // sigue marcado como vinculado, asi que la corrida siguiente lo reintenta.
      console.error(
        `caducarVinculosInactivos: no se pudo caducar el vinculo del ticket ${doc.id}:`,
        error
      );
      return false;
    }
  };

  // Por tandas y no de uno en uno: son dos escrituras por ticket y hasta
  // `TOPE_POR_CORRIDA` tickets, o sea 400 idas y vueltas en serie en el peor
  // caso. Tampoco todas a la vez: un `Promise.all` de 400 escrituras contra
  // Firestore agota el pool de conexiones y se autoestrangula.
  let caducados = 0;
  for (let i = 0; i < snap.docs.length; i += TANDA) {
    const hechos = await Promise.all(
      snap.docs.slice(i, i + TANDA).map(caducarUno)
    );
    caducados += hechos.filter(Boolean).length;
  }

  return {
    revisados: snap.docs.length,
    caducados,
    fallidos: snap.docs.length - caducados,
  };
}

module.exports = {
  CAMPO_VINCULO_ACTIVO,
  DIAS_CADUCIDAD_VINCULO,
  TOPE_POR_CORRIDA,
  caducarVinculosInactivos,
};
