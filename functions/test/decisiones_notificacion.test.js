'use strict';

const assert = require('assert');
const decisiones = require('../src/decisionesNotificacion');

function decidir(nombre, ...args) {
  return decisiones[nombre](...args);
}

describe('checkMileageOnVehicleUpdate / decision pura', () => {
  const antes = { kilometraje_actual: 9000 };
  const despues = { kilometraje_actual: 9500, id_propietario: 'p1' };
  const tarea = { ultimo_km: 5000, frecuencia_km: 5000 };
  const evaluar = (a = antes, d = despues, t = tarea, token = 'token') =>
    decidir('decidirAvisoKilometraje', a, d, { tarea: t, fcmToken: token });

  it('un cambio ajeno al odometro no repite el aviso', () => {
    assert.strictEqual(evaluar(despues), null);
  });
  it('sin propietario no hay destinatario al que consultar', () => {
    assert.strictEqual(evaluar(antes, { kilometraje_actual: 9500 }), null);
  });
  it('sin token se conservan apagados ambos canales', () => {
    // Este comportamiento heredado no debe convertirse en centro sin push al extraerlo.
    assert.deepStrictEqual(evaluar(antes, despues, tarea, null), {
      targetId: 'p1', push: false, centro: false, tipo: null, diff: null,
    });
  });
  for (const [km, tipo, diff] of [
    [9499, null, 501], [9500, 'cercano', 500], [9999, 'cercano', 1],
    [10000, 'requerido', 0], [10001, 'requerido', -1],
  ]) {
    it(`el limite ${km} km decide ${tipo || 'ningun aviso'}`, () => {
      // Un <= cambiado por < duplica o pierde el escalon exacto de mantenimiento.
      assert.deepStrictEqual(evaluar(antes, { ...despues, kilometraje_actual: km }), {
        targetId: 'p1', push: tipo !== null, centro: tipo !== null, tipo, diff,
      });
    });
  }
  for (const frecuencia_km of [undefined, 0, -100]) {
    it(`una frecuencia ${frecuencia_km} no genera vencimientos ficticios`, () => {
      assert.deepStrictEqual(evaluar(antes, despues, { ultimo_km: 5000, frecuencia_km }), {
        targetId: 'p1', push: false, centro: false, tipo: null, diff: null,
      });
    });
  }
  it('sin ultimo_km toma cero y puede avisar al alcanzar la frecuencia', () => {
    assert.strictEqual(evaluar(antes, { ...despues, kilometraje_actual: 5000 },
      { frecuencia_km: 5000 }).tipo, 'requerido');
  });
  it('sin kilometraje actual conserva el cero heredado', () => {
    assert.strictEqual(evaluar(antes, { id_propietario: 'p1' },
      { frecuencia_km: 500 }).tipo, 'cercano');
  });
  it('una correccion hacia atras sigue notificando si queda en el tramo cercano', () => {
    // La guarda compara desigualdad; no exige que el odometro crezca.
    assert.strictEqual(evaluar({ kilometraje_actual: 10000 }).tipo, 'cercano');
  });
  it('no requiere mantenimiento antes de superar el ultimo kilometraje', () => {
    // En datos numericos validos esta guarda es redundante con frecuencia > 0.
    // Un dato legado coercible alcanza la rama y distingue > de >=.
    assert.strictEqual(evaluar(antes, { ...despues, kilometraje_actual: -1 },
      { ultimo_km: -1, frecuencia_km: '1' }).tipo, null);
  });
  it('un dato legado coercible conserva la rama requerida si supera ultimo_km', () => {
    assert.strictEqual(evaluar(antes, { ...despues, kilometraje_actual: 0 },
      { ultimo_km: -1, frecuencia_km: '1' }).tipo, 'requerido');
  });
});

describe('requestReviewOnServiceComplete / decision pura', () => {
  const servicio = { id_taller: 't1', id_vehiculo: 'v1' };
  const vehiculo = { id_propietario: 'p1' };
  const evaluar = (s = servicio, v = vehiculo, token = 'token') =>
    decidir('decidirSolicitudResenia', s, v, token);

  for (const s of [{ id_vehiculo: 'v1' }, { id_taller: 't1' },
    { ...servicio, id_taller: 'Manual' }, { ...servicio, id_taller: 'tallerManual123' }]) {
    it(`no consulta ni notifica el servicio ${JSON.stringify(s)}`, () => {
      // Manual se busca como subcadena, no como igualdad ni prefijo.
      const d = evaluar(s);
      assert.strictEqual(d.consultarVehiculo, false);
      assert.strictEqual(d.push, false);
      assert.strictEqual(d.centro, false);
      assert.strictEqual(d.confirmacion, false);
    });
  }
  it('un taller con manual en minusculas conserva el comportamiento existente', () => {
    assert.strictEqual(evaluar({ ...servicio, id_taller: 'manual' }).push, true);
  });
  it('un vehiculo inexistente impide avisar y marcar una solicitud', () => {
    const d = evaluar(servicio, null);
    assert.strictEqual(d.vehiculoExiste, false);
    assert.strictEqual(d.targetId, null);
    assert.strictEqual(d.debeMarcarPendiente, false);
    assert.strictEqual(d.push, false);
    assert.strictEqual(d.centro, false);
  });
  it('sin propietario puede marcar pendiente pero no puede notificar', () => {
    // El update del vehiculo ocurre ANTES de esta guarda en el handler.
    const d = evaluar(servicio, {});
    assert.strictEqual(d.debeMarcarPendiente, true);
    assert.strictEqual(d.targetId, null);
    assert.strictEqual(d.push, false);
    assert.strictEqual(d.centro, false);
    assert.strictEqual(d.confirmacion, false);
  });
  it('sin token sigue marcando pendiente pero no escribe ningun aviso', () => {
    const d = evaluar(servicio, vehiculo, null);
    assert.strictEqual(d.debeMarcarPendiente, true);
    assert.strictEqual(d.push, false);
    assert.strictEqual(d.centro, false);
    assert.strictEqual(d.confirmacion, false);
  });
  for (const [motivo, extra, pendiente, vinculado] of [
    ['primera visita', {}, true, false],
    ['pendiente del mismo taller', { taller_pendiente_confirmacion: 't1' }, true, false],
    ['vinculo previo', { talleres_vinculados: ['t1'] }, false, true],
    ['pendiente ajeno', { taller_pendiente_confirmacion: 't2' }, false, false],
    ['rechazo previo', { talleres_rechazados: ['t1'] }, false, false],
    ['rechazo ajeno', { talleres_rechazados: ['t2'] }, true, false],
    ['vinculo ajeno', { talleres_vinculados: ['t2'] }, true, false],
  ]) {
    it(`${motivo}: conserva la reseña y decide el consentimiento por separado`, () => {
      // Bloquear un consentimiento no debe silenciar la peticion de reseña.
      assert.deepStrictEqual(evaluar(servicio, { ...vehiculo, ...extra }), {
        consultarVehiculo: true, vehiculoExiste: true, targetId: 'p1',
        yaVinculado: vinculado, debeMarcarPendiente: pendiente,
        push: true, centro: true, confirmacion: pendiente,
      });
    });
  }
});

describe('notifyOnNewChatMessage / decision pura', () => {
  const conversacion = { id_mecanico: 'm1', id_propietario: 'p1' };
  const evaluar = (remitente, conv = conversacion, token = 'token') =>
    decidir('decidirMensajeChat', { id_remitente: remitente }, conv, token);

  it('una conversacion borrada no produce destinatarios fantasma', () => {
    assert.strictEqual(evaluar('m1', null), null);
  });
  for (const [remitente, targetId] of [['m1', 'p1'], ['p1', 'm1']]) {
    it(`${remitente} avisa al otro participante y no a si mismo`, () => {
      assert.deepStrictEqual(evaluar(remitente), { targetId, push: true, centro: true });
    });
  }
  for (const remitente of ['ajeno', undefined]) {
    it(`un remitente ${remitente} no se adjudica un receptor`, () => {
      assert.strictEqual(evaluar(remitente), null);
    });
  }
  for (const [remitente, conv] of [['m1', { id_mecanico: 'm1' }],
    ['p1', { id_propietario: 'p1' }]]) {
    it(`sin contraparte de ${remitente} corta antes de consultar usuarios`, () => {
      assert.strictEqual(evaluar(remitente, conv), null);
    });
  }
  it('sin token no escribe tampoco en el centro', () => {
    assert.deepStrictEqual(evaluar('m1', conversacion, null), {
      targetId: 'p1', push: false, centro: false,
    });
  });
});

describe('notifyOnNewReservation / decision pura', () => {
  it('no usa al propietario como sustituto de un mecanico ausente', () => {
    assert.strictEqual(decidir('decidirNuevaReserva', { id_propietario: 'p1' }, 'token'), null);
  });
  it('avisa al mecanico incluso si el proponente es el propio mecanico', () => {
    // La extraccion no corrige la seleccion actual del destinatario.
    assert.deepStrictEqual(decidir('decidirNuevaReserva', {
      id_mecanico: 'm1', id_propietario: 'p1', id_proponente: 'm1',
    }, 'token'), { targetId: 'm1', push: true, centro: true });
  });
  it('sin token no persiste la solicitud en el centro', () => {
    assert.deepStrictEqual(decidir('decidirNuevaReserva', { id_mecanico: 'm1' }, null), {
      targetId: 'm1', push: false, centro: false,
    });
  });
});

describe('notifyOnReservationStatusChange / decision pura', () => {
  const antes = { estado: 'pendiente' };
  const despues = { estado: 'confirmada', id_propietario: 'p1', id_mecanico: 'm1' };
  const evaluar = (a = antes, d = despues, token = 'token') =>
    decidir('decidirCambioReserva', a, d, token);

  it('editar una reserva ya confirmada no repite la confirmacion', () => {
    assert.strictEqual(evaluar(despues), null);
  });
  for (const estado of ['pendiente', 'cancelada', 'aceptada']) {
    it(`el estado ${estado} no se confunde con confirmada o rechazada`, () => {
      assert.strictEqual(evaluar({ estado: 'otro' }, { ...despues, estado }), null);
    });
  }
  for (const estado of ['confirmada', 'rechazada']) {
    for (const token of ['token', null]) {
      it(`${estado}, token ${token}: el centro sobrevive a la ausencia de push`, () => {
        assert.deepStrictEqual(evaluar(antes, { ...despues, estado }, token), {
          isAccepted: estado === 'confirmada', recipientIds: ['p1', 'm1'],
          push: token !== null, centro: true,
        });
      });
    }
  }
  for (const [extra, ids] of [
    [{ id_mecanico: null }, ['p1']], [{ id_propietario: '' }, ['m1']],
    [{ id_propietario: null, id_mecanico: null }, []],
    [{ id_mecanico: 'p1' }, ['p1', 'p1']],
  ]) {
    it(`conserva los destinatarios ${JSON.stringify(ids)}`, () => {
      // Mantiene orden y duplicados; deduplicar seria cambiar el comportamiento.
      assert.deepStrictEqual(evaluar(antes, { ...despues, ...extra }), {
        isAccepted: true, recipientIds: ids, push: ids.length > 0, centro: ids.length > 0,
      });
    });
  }
});

describe('onCotizacionAceptada / decision pura de notificacion', () => {
  const abierto = { id: 'r1', ticket: { id_propietario: 'p1', id_vehiculo: 'v1' } };
  it('un resultado sin apertura no anuncia un servicio nuevo', () => {
    assert.strictEqual(decidir('decidirCotizacionAceptada', { id: null, ticket: null }, 'token'), null);
  });
  it('sin id no basta con traer datos de un ticket para notificar', () => {
    assert.strictEqual(decidir('decidirCotizacionAceptada', { ...abierto, id: null }, 'token'), null);
  });
  it('sin ticket conserva la lectura de respaldo sin anunciar aun', () => {
    assert.deepStrictEqual(decidir('decidirCotizacionAceptada', { id: 'r1', ticket: null }, 'token'), {
      id: 'r1', targetId: null, leerTicket: true, push: false, centro: false,
    });
  });
  it('sin propietario no intenta consultar un usuario vacio', () => {
    assert.deepStrictEqual(decidir('decidirCotizacionAceptada', { id: 'r1', ticket: {} }, 'token'), {
      id: 'r1', targetId: null, leerTicket: false, push: false, centro: false,
    });
  });
  for (const token of ['token', null]) {
    it(`ticket abierto, token ${token}: conserva el anuncio persistente`, () => {
      assert.deepStrictEqual(decidir('decidirCotizacionAceptada', abierto, token), {
        id: 'r1', targetId: 'p1', leerTicket: false, push: token !== null, centro: true,
      });
    });
  }
});

describe('notifyOnReparacionStatusChange / decision pura', () => {
  const antes = { estado: 'recibido' };
  const despues = { estado: 'en_revision', id_propietario: 'p1' };
  const evaluar = (a = antes, d = despues, token = 'token') =>
    decidir('decidirCambioReparacion', a, d, token);

  it('un update sin transicion no vuelve a avisar', () => {
    assert.strictEqual(evaluar(despues), null);
  });
  it('la marca de migracion silencia tambien el centro', () => {
    assert.strictEqual(evaluar(antes, { ...despues, migracion_ronda6: true }), null);
  });
  it('sin propietario no notifica al taller como sustituto', () => {
    assert.strictEqual(evaluar(antes, { estado: 'en_revision', id_taller: 't1' }), null);
  });
  for (const marca of [undefined, false, 'true', 1]) {
    it(`la marca ${JSON.stringify(marca)} no silencia una transicion normal`, () => {
      assert.deepStrictEqual(evaluar(antes, { ...despues, migracion_ronda6: marca }), {
        targetId: 'p1', push: true, centro: true,
      });
    });
  }
  it('sin token escribe igualmente la actualizacion persistente', () => {
    assert.deepStrictEqual(evaluar(antes, despues, null), {
      targetId: 'p1', push: false, centro: true,
    });
  });
  it('un estado desconocido tambien se anuncia con la politica heredada', () => {
    assert.deepStrictEqual(evaluar(antes, { ...despues, estado: 'estado_futuro' }), {
      targetId: 'p1', push: true, centro: true,
    });
  });
});
