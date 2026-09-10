'use strict';

/**
 * FUNC-02 — una sola puerta de apertura de tickets de reparacion.
 *
 * Hasta esta tarea habia DOS creadores de `reparaciones` del lado servidor:
 *
 *  1. `onCotizacionAceptada` -> `abrirTicketDeReparacion`, que abre el ticket
 *     en `pendiente_recepcion` (el flujo oficial, cubierto en
 *     aceptar_cotizacion.test.js).
 *  2. El callable `iniciarReparacionPorVehiculo`, herencia de "Buscar
 *     Vehiculo", que llamaba a `crearOReutilizarTicketReparacion` y abria el
 *     ticket **directamente en 'recibido'** ademas de anadir el taller a
 *     `vehiculos.talleres_vinculados`.
 *
 * El segundo no tenia ya ningun consumidor en el cliente (su unico llamador,
 * `ReparacionRepository.iniciarOReutilizarPorVehiculo`, estaba a su vez sin
 * consumidores), pero seguia siendo un endpoint desplegado e invocable por
 * cualquier mecanico autenticado. Su compuerta solo exigia "existe una
 * cotizacion 'aceptada' para este vehiculo+taller", y una cotizacion se queda
 * en 'aceptada' para siempre despues de la visita: bastaba reutilizar la de
 * una visita YA ENTREGADA para reabrir un ticket dandolo por recibido y
 * **recuperar el vinculo al vehiculo que `revocarVinculoAlCerrarTicket` habia
 * revocado al entregar el coche**. Es decir, deshacia el modelo de
 * consentimiento entero sin que el propietario interviniera.
 *
 * Estas afirmaciones son de superficie desplegada a proposito: lo que hay que
 * impedir no es un comportamiento concreto, es que vuelva a EXISTIR una
 * segunda puerta. `firestore.rules` no puede pinchar aqui — su
 * `allow create: if false` sobre /reparaciones no alcanza a los callables,
 * que corren con Admin SDK.
 */

const assert = require('assert');
const fs = require('fs');
const path = require('path');

const RAIZ = path.join(__dirname, '..');

function fuentes() {
  const dirSrc = path.join(RAIZ, 'src');
  const archivos = [path.join(RAIZ, 'index.js')].concat(
    fs
      .readdirSync(dirSrc)
      .filter((f) => f.endsWith('.js'))
      .map((f) => path.join(dirSrc, f))
  );
  return archivos.map((f) => ({
    nombre: path.relative(RAIZ, f).split(path.sep).join('/'),
    codigo: fs.readFileSync(f, 'utf8'),
  }));
}

/** Quita comentarios de bloque y de linea, para no afirmar sobre prosa. */
function sinComentarios(codigo) {
  return codigo.replace(/\/\*[\s\S]*?\*\//g, '').replace(/^\s*\/\/.*$/gm, '');
}

describe('FUNC-02 / una sola puerta de apertura de tickets', () => {
  it('no queda ningun callable de apertura manual de tickets', () => {
    for (const { nombre, codigo } of fuentes()) {
      const vivo = sinComentarios(codigo);
      assert.ok(
        !/exports\.iniciarReparacionPorVehiculo/.test(vivo),
        `${nombre} vuelve a exponer el callable de apertura manual`
      );
      assert.ok(
        !/crearOReutilizarTicketReparacion/.test(vivo),
        `${nombre} vuelve a usar el helper que abria el ticket en 'recibido'`
      );
    }
  });

  it('ninguna funcion crea un ticket de reparacion ya en "recibido"', () => {
    for (const { nombre, codigo } of fuentes()) {
      const vivo = sinComentarios(codigo);
      assert.ok(
        !/estado:\s*['"]recibido['"]/.test(vivo),
        `${nombre} escribe un ticket naciendo en 'recibido'; el unico estado ` +
          `inicial legitimo es 'pendiente_recepcion' (la recepcion fisica la ` +
          `hace recibirVehiculoDelTicket)`
      );
    }
  });

  it('el unico creador abre el ticket en pendiente_recepcion', () => {
    const { construirTicketReparacion } = require('../src/aceptarCotizacion');
    const ahora = new Date('2026-09-10T00:00:00Z');
    const ticket = construirTicketReparacion({
      cotizacionId: 'c1',
      cotizacion: { id_vehiculo: 'v1', id_taller: 't1', id_propietario: 'owner' },
      vehiculo: { placa: 'ABC123', id_propietario: 'owner' },
      idTaller: 't1',
      ahora,
    });
    assert.strictEqual(ticket.estado, 'pendiente_recepcion');
  });

  it('no aparece ninguna puerta nueva sobre /reparaciones', () => {
    // Tripwire deliberado, no una afirmacion de comportamiento: cuenta los
    // puntos del codigo server-side que tocan la coleccion y exige que sean
    // EXACTAMENTE los conocidos. Cualquier acceso nuevo —un callable, un
    // trigger, o una linea mas dentro de un archivo que ya la toca— rompe
    // este test y obliga a justificarlo aqui, que es justo lo que no ocurrio
    // cuando `iniciarReparacionPorVehiculo` se quedo vivo sin consumidor.
    //
    // La primera version de este test solo miraba el cuerpo de cada
    // `exports.` y pasaba por casualidad: la escritura de
    // `recibirVehiculoDelTicket` no esta en index.js sino en
    // src/vinculoTaller.js, y solo la LECTURA inline de index.js la delataba.
    // Un callable nuevo que delegara en un helper de src/ —el patron de todo
    // el modulo— no se habria visto. Por eso se cuenta por archivo.
    const esperado = {
      // El unico CREADOR: el trigger de aceptacion de cotizacion.
      'src/aceptarCotizacion.js': 2,
      // La transicion `pendiente_recepcion` -> `recibido`, junto con el
      // vinculo al vehiculo, en un solo lote atomico.
      'src/vinculoTaller.js': 1,
      // index.js: la relectura del ticket para notificar, la lectura que
      // autoriza `recibirVehiculoDelTicket`, y el barrido de `onVehicleDelete`
      // que CIERRA los tickets del vehiculo borrado.
      'index.js': 3,
    };

    const real = {};
    for (const { nombre, codigo } of fuentes()) {
      const n = (
        sinComentarios(codigo).match(/collection\(\s*['"]reparaciones['"]\s*\)/g) || []
      ).length;
      if (n > 0) real[nombre] = n;
    }

    assert.deepStrictEqual(
      real,
      esperado,
      'cambio el conjunto de accesos server-side a /reparaciones. `firestore.rules` ' +
        'NO protege a callables ni triggers (corren con Admin SDK): si el acceso ' +
        'nuevo es legitimo, replica a mano la autorizacion que la regla haria y ' +
        'actualiza este mapa explicando por que.'
    );
  });
});
