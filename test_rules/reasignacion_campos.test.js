const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { deleteField } = require('firebase/firestore');
const { makeEnv, seed, withRole, UIDS } = require('./helpers');

let env;
beforeAll(async () => { env = await makeEnv(); });
afterAll(async () => { await env.cleanup(); });
beforeEach(async () => { await env.clearFirestore(); });

// Dos vehiculos de DUEÑOS distintos, cada uno vinculado a su propio taller.
// El punto de estos tests es el update: las reglas de alertas/mantenimientos/
// historial_mantenimientos autorizan mirando `resource.data` (el documento
// VIEJO) y no acotan que campos puede tocar el update, asi que un actor
// legitimo sobre el documento de v1 puede reescribir id_vehiculo a v2 y
// arrastrar el registro al coche de otra persona.
const seedEscenario = async () => {
  await seed(env, async (s) => {
    await s.collection('vehiculos').doc('v1').set({
      id_vehiculo: 'v1', id_propietario: UIDS.owner1, placa: 'P-1',
      talleres_vinculados: [UIDS.taller1],
    });
    await s.collection('vehiculos').doc('v2').set({
      id_vehiculo: 'v2', id_propietario: UIDS.owner2, placa: 'P-2',
      talleres_vinculados: [UIDS.taller2],
    });
    await s.collection('alertas').doc('a1').set({
      id_vehiculo: 'v1', tipo: 'soat', descripcion: 'vence pronto',
    });
    await s.collection('mantenimientos').doc('m1').set({
      id_vehiculo: 'v1', nombre: 'Pastillas de Freno', frecuencia_km: 20000,
    });
    await s.collection('historial_mantenimientos').doc('h1').set({
      id_vehiculo: 'v1', id_taller: UIDS.taller1, nombre_tarea: 'Filtro de Aceite',
      descripcion: 'original',
    });
  });
};

describe('un update legitimo no puede reasignar el registro a otro vehiculo/taller', () => {
  test('el propietario NO puede mover su alerta al vehiculo de otro', async () => {
    await seedEscenario();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(db.collection('alertas').doc('a1').update({ id_vehiculo: 'v2' }));
  });

  test('el propietario NO puede mover su mantenimiento al vehiculo de otro', async () => {
    await seedEscenario();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(db.collection('mantenimientos').doc('m1').update({ id_vehiculo: 'v2' }));
  });

  test('el taller NO puede mover una entrada de historial al vehiculo de otro', async () => {
    await seedEscenario();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(
      db.collection('historial_mantenimientos').doc('h1').update({ id_vehiculo: 'v2' }),
    );
  });

  test('el taller NO puede atribuir su entrada de historial a otro taller', async () => {
    await seedEscenario();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(
      db.collection('historial_mantenimientos').doc('h1').update({ id_taller: UIDS.taller2 }),
    );
  });

  // /vehiculos tiene la misma forma por el otro lado: la rama del propietario
  // autoriza con `resource.data.id_propietario == request.auth.uid` y no acota
  // campos, asi que el dueño podia REGALAR el vehiculo reescribiendo ese mismo
  // campo. El coche aparecia en el panel de la victima como suyo, con su
  // historial y sus alertas colgando, y el atacante ya no podia deshacerlo:
  // el update que le quitaba el permiso era el ultimo que las reglas le
  // dejaban hacer.
  test('el propietario NO puede reasignar su vehiculo a otra persona', async () => {
    await seedEscenario();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db.collection('vehiculos').doc('v1').update({ id_propietario: UIDS.owner2 }),
    );
  });

  test('el propietario SI conserva el consentimiento de taller (talleres_vinculados)', async () => {
    await seedEscenario();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    // Es la primitiva de consentimiento que escribe VehicleService
    // .confirmarVinculoTaller / .rechazarVinculoTaller desde el propio
    // cliente: acotarla aqui romperia el modelo de vinculos de las rondas 5/6.
    await assertSucceeds(
      db.collection('vehiculos').doc('v1').update({ talleres_vinculados: [UIDS.taller1, UIDS.taller2] }),
    );
  });

  // `talleres_conocidos` es append-only por contrato (firestore.rules:134-137
  // lo dice con todas las letras: lo escribe recibirTicketYVincular con Admin
  // SDK y no se revoca nunca), pero las reglas no lo enforzaban. Vaciar los
  // DOS arrays devuelve el vehiculo al estado que la rama de walk-in de
  // puedeMecanicoAtenderVehiculo considera "coche que ningun taller ha
  // atendido jamas", y ese estado abre el coche a CUALQUIER mecanico: es
  // exactamente el agujero que la ronda 6 cerro, reabierto desde el lado del
  // propietario. Con una cuenta de Mecanico propia, el dueño se fabrica
  // historial de taller verificado y, via isOwnFinishedService, reseñas
  // legitimas para un taller que controla.
  test('el propietario NO puede vaciar talleres_conocidos para volver al estado walk-in', async () => {
    await seed(env, async (s) => {
      await s.collection('vehiculos').doc('v3').set({
        id_vehiculo: 'v3', id_propietario: UIDS.owner1, placa: 'P-3',
        talleres_vinculados: [UIDS.taller1], talleres_conocidos: [UIDS.taller1],
      });
    });
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db.collection('vehiculos').doc('v3').update({
        talleres_conocidos: [], talleres_vinculados: [],
      }),
    );
  });

  test('el propietario SI puede revocar el vinculo vivo sin tocar el historico', async () => {
    await seed(env, async (s) => {
      await s.collection('vehiculos').doc('v3').set({
        id_vehiculo: 'v3', id_propietario: UIDS.owner1, placa: 'P-3',
        talleres_vinculados: [UIDS.taller1], talleres_conocidos: [UIDS.taller1],
      });
    });
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    // Es lo que hace VehicleService.revocarAccesoTaller: quita el vinculo
    // vivo y deja intacto el registro de que ese taller estuvo ahi.
    await assertSucceeds(
      db.collection('vehiculos').doc('v3').update({ talleres_vinculados: [] }),
    );
  });

  test('el propietario SI puede editar los datos de su vehiculo', async () => {
    await seedEscenario();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertSucceeds(db.collection('vehiculos').doc('v1').update({ placa: 'P-9' }));
  });

  // Controles positivos: el acotado no debe romper el update legitimo, que es
  // el unico que ejecutan los flujos reales.
  test('el propietario SI puede editar el resto de su alerta', async () => {
    await seedEscenario();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertSucceeds(db.collection('alertas').doc('a1').update({ descripcion: 'ya vencio' }));
  });

  test('el propietario SI puede editar el resto de su mantenimiento', async () => {
    await seedEscenario();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertSucceeds(db.collection('mantenimientos').doc('m1').update({ frecuencia_km: 15000 }));
  });

  test('el taller SI puede editar el resto de su entrada de historial', async () => {
    await seedEscenario();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertSucceeds(
      db.collection('historial_mantenimientos').doc('h1').update({ descripcion: 'corregido' }),
    );
  });
});

describe('la contabilidad del barrido de alertas es del servidor (OPS-01)', () => {
  // `ultimo_aviso` es lo que impide que `checkAlertsDaily` reenvie el mismo
  // push cada 24 h mientras la alerta siga 'Pendiente'. Lo escribe el barrido
  // con Admin SDK, que no pasa por estas reglas. Si el cliente pudiera
  // tocarlo, el propietario podria devolverse a si mismo el aviso diario que
  // el arreglo elimina — y, peor, cualquier escritura descuidada de la app
  // sobre el documento entero lo borraria sin querer.
  const conAviso = async () => {
    await seed(env, async (s) => {
      await s.collection('vehiculos').doc('v1').set({
        id_vehiculo: 'v1', id_propietario: UIDS.owner1, placa: 'P-1',
      });
      await s.collection('alertas').doc('a1').set({
        id_vehiculo: 'v1', tipo: 'soat', descripcion: 'vence pronto',
        ultimo_aviso: 'por_vencer',
        // Tiene que estar sembrado: borrar un campo que no existe no afecta a
        // ninguna clave, asi que el update pasaria por ser un no-op y el test
        // seria rojo por el fixture, no por la regla.
        fecha_ultimo_aviso: new Date('2026-09-10T00:00:00Z'),
      });
    });
  };

  test('el propietario NO puede reescribir ultimo_aviso', async () => {
    // El payload es un escalon valido y no `null` a proposito: con `null`,
    // este test seguiria verde aunque alguien reescribiera la regla como
    // "solo se aceptan valores de ESCALONES", que es justo el agujero.
    await conAviso();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(db.collection('alertas').doc('a1').update({ ultimo_aviso: 'vencida' }));
  });

  test('el propietario NO puede BORRAR ultimo_aviso', async () => {
    // El caso que se escapa si la regla ata el valor en vez de la clave: un
    // `FieldValue.delete()` no escribe ningun valor que validar. Asi se
    // esquivo una regla equivalente en la tanda de drenaje anterior.
    await conAviso();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db.collection('alertas').doc('a1').update({ ultimo_aviso: deleteField() }),
    );
  });

  test('el propietario NO puede retrasar fecha_ultimo_aviso', async () => {
    await conAviso();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db.collection('alertas').doc('a1').update({ fecha_ultimo_aviso: new Date(0) }),
    );
  });

  test('ni siquiera el admin: una correccion real se hace con Admin SDK', async () => {
    await conAviso();
    const db = await withRole(env, UIDS.admin, 'Administrador');
    await assertFails(db.collection('alertas').doc('a1').update({ ultimo_aviso: null }));
  });

  test('tampoco por set() con merge, que es otra forma de escribir', async () => {
    // Hoy denegado, pero nada lo fijaba. Es la forma exacta en que un cliente
    // esquivaria una futura reescritura de la regla hacia validacion por
    // valor: `affectedKeys()` sobre `diff()` es insensible a la forma del
    // write, y este test es lo que impide que se pierda esa propiedad.
    await conAviso();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db.collection('alertas').doc('a1').set({ ultimo_aviso: 'vencida' }, { merge: true }),
    );
  });

  test('tampoco borrandolo con set() y merge', async () => {
    await conAviso();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db.collection('alertas').doc('a1').set({ ultimo_aviso: deleteField() }, { merge: true }),
    );
  });

  test('tampoco con un set() completo que se deje el campo fuera', async () => {
    // El patron "leer, modelar, reescribir el documento entero" con un
    // `AlertModel.toMap()` que no conoce estos campos. Omitirlos en un
    // overwrite es borrarlos, y la regla tiene que verlo igual.
    await conAviso();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db.collection('alertas').doc('a1').set({
        id_vehiculo: 'v1', tipo: 'soat', descripcion: 'reescrita',
      }),
    );
  });

  test('el propietario NO puede BORRAR fecha_ultimo_aviso', async () => {
    await conAviso();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db.collection('alertas').doc('a1').update({ fecha_ultimo_aviso: deleteField() }),
    );
  });

  test('el propietario NO puede CREAR una alerta ya silenciada', async () => {
    // Lo encontro el revisor de reglas, y era alcanzable: el `allow update`
    // cerraba la puerta pero el `allow create` la dejaba abierta. Crear con
    // `ultimo_aviso: 'vencida'` hace que el barrido no avise nunca de esa
    // alerta, y el propio candado del update lo vuelve irreversible desde el
    // cliente.
    await seed(env, async (s) => {
      await s.collection('vehiculos').doc('v1').set({
        id_vehiculo: 'v1', id_propietario: UIDS.owner1, placa: 'P-1',
      });
    });
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db.collection('alertas').doc('nueva').set({
        id_vehiculo: 'v1', estado: 'Pendiente', tipo: 'soat', ultimo_aviso: 'vencida',
      }),
    );
  });

  test('pero SI puede crear una alerta normal', async () => {
    // Control positivo del acotado del create: sin esto, cerrar la puerta de
    // mas pasaria desapercibido.
    await seed(env, async (s) => {
      await s.collection('vehiculos').doc('v1').set({
        id_vehiculo: 'v1', id_propietario: UIDS.owner1, placa: 'P-1',
      });
    });
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertSucceeds(
      db.collection('alertas').doc('nueva').set({
        id_vehiculo: 'v1', estado: 'Pendiente', tipo: 'soat',
      }),
    );
  });

  test('el propietario SI puede seguir editando su alerta con el campo puesto', async () => {
    await conAviso();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertSucceeds(db.collection('alertas').doc('a1').update({ descripcion: 'renovado' }));
  });
});
