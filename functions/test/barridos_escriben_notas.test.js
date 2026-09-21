'use strict';

/**
 * Centinela: los dos barridos programados **cablean** el centro de
 * notificaciones.
 *
 * `notificarAlertasVencidas` y `enviarRecordatoriosDeReserva` exigen
 * `escribirNotificacion` y lanzan `TypeError` si falta, asi que un olvido de
 * cableado no es silencioso... pero se descubre **a las 9 de la manana del
 * dia siguiente**, cuando el scheduler corre y nadie recibe su recordatorio.
 * El coste de enterarse es un dia de avisos perdidos, y no hay reintento: el
 * recordatorio no tiene marca de idempotencia, asi que ni relanzarlo arregla
 * ese dia.
 *
 * Este centinela mueve el descubrimiento al commit. Lee el FUENTE del
 * entrypoint —no lo invoca— porque cargar `index.js` arrastra firebase-admin y
 * las treinta funciones.
 *
 * Y el recordatorio **no escribia nada** hasta 2026-09-21: un push es efimero,
 * y quien lo perdia (telefono apagado, notificaciones silenciadas, token
 * muerto por reinstalar la app) no tenia NINGUNA via para enterarse de su
 * cita. El barrido de alertas, hermano suyo y del mismo OPS-01, si lo hacia.
 * Este fichero existe para que esa asimetria no vuelva.
 *
 * **Sin regex, a proposito.** Un centinela que busca una cadena que no esta
 * pasa siempre, y un `\\s` mal escapado produce exactamente eso — la cicatriz
 * que ya dejo el centinela de `e.message` de IA-01. Con `indexOf` no hay nada
 * que escapar mal.
 */

const assert = require('assert');
const fs = require('fs');
const path = require('path');

const FUENTE = fs.readFileSync(path.join(__dirname, '..', 'index.js'), 'utf8');

/** Los barridos que TIENEN que dejar rastro en el centro de notificaciones. */
const BARRIDOS = ['notificarAlertasVencidas', 'enviarRecordatoriosDeReserva'];

/** El cableado que se exige, literal. */
const CABLEADO = 'escribirNotificacion: writeNotification';

/** Cuanto se mira despues de abrir la llamada. Las dos caben de sobra. */
const VENTANA = 600;

describe('OPS-01 / los barridos programados escriben en el centro de notificaciones', () => {
  it('el centinela esta mirando el fichero correcto', () => {
    // Sin esto, todo lo de abajo pasaria igual de bien sobre una cadena vacia.
    assert.ok(FUENTE.length > 5000, 'index.js se leyo truncado: ' + FUENTE.length);
    assert.ok(
      FUENTE.indexOf('async function writeNotification(') !== -1,
      'no existe writeNotification en index.js: si se renombro, este centinela ' +
        'hay que reapuntarlo en vez de borrarlo'
    );
  });

  BARRIDOS.forEach((barrido) => {
    it(barrido + ' recibe escribirNotificacion', () => {
      // La llamada, no el `require`: se busca el nombre seguido del parentesis.
      const inicio = FUENTE.indexOf(barrido + '(');
      assert.notStrictEqual(
        inicio,
        -1,
        'no se encontro ninguna llamada a ' +
          barrido +
          ' en index.js. Si el barrido se retiro, retira tambien su entrada de ' +
          'BARRIDOS; si se renombro, actualizala.'
      );

      const argumentos = FUENTE.slice(inicio, inicio + VENTANA);
      assert.ok(
        argumentos.indexOf(CABLEADO) !== -1,
        barrido +
          ' se invoca sin `' +
          CABLEADO +
          '`. Ese barrido lanzaria TypeError a las 9:00 del dia siguiente y ese ' +
          'dia de avisos se pierde sin reintento posible. Lo que se vio:\n' +
          argumentos.slice(0, 200)
      );
    });
  });
});
