const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { makeEnv, seed, withRole, UIDS } = require('./helpers');

let env;
beforeAll(async () => { env = await makeEnv(); });
afterAll(async () => { await env.cleanup(); });
beforeEach(async () => { await env.clearFirestore(); });

const seedCotizacion = async () => {
  await seed(env, async (s) => {
    await s.collection('cotizaciones').doc('c1').set({
      id_propietario: UIDS.owner1,
      id_mecanico: UIDS.taller1,
      id_taller: UIDS.taller1,
      items: [{ material: 'Aceite', cantidad: 1, costo: 20 }],
      estado: 'pendiente',
    });
  });
};

describe('cotizaciones update (hallazgo H1: campo abierto permitia alterar precio/partes)', () => {
  test('el propietario SI puede aceptar (solo estado)', async () => {
    await seedCotizacion();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertSucceeds(
      db.collection('cotizaciones').doc('c1').update({ estado: 'aceptada' }),
    );
  });

  test('el mecanico SI puede finalizar (solo estado)', async () => {
    await seedCotizacion();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertSucceeds(
      db.collection('cotizaciones').doc('c1').update({ estado: 'finalizada' }),
    );
  });

  test('el propietario NO puede alterar los items (precio) al aceptar', async () => {
    await seedCotizacion();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db.collection('cotizaciones').doc('c1').update({
        estado: 'aceptada',
        items: [{ material: 'Aceite', cantidad: 1, costo: 1 }],
      }),
    );
  });

  test('el mecanico NO puede reasignar id_propietario', async () => {
    await seedCotizacion();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(
      db.collection('cotizaciones').doc('c1').update({
        id_propietario: UIDS.owner2,
      }),
    );
  });

  test('un tercero no vinculado NO puede actualizar la cotizacion', async () => {
    await seedCotizacion();
    const db = await withRole(env, UIDS.taller2, 'Taller');
    await assertFails(
      db.collection('cotizaciones').doc('c1').update({ estado: 'aceptada' }),
    );
  });
});

describe('cotizaciones update (revision de rama completa, hallazgo C1: el mecanico se auto-emitia el gate del trigger)', () => {
  // Antes de esta ronda, `update` solo comprobaba QUIEN escribia, nunca QUE
  // valor de `estado` escribia cada uno. Un mecanico podia aceptar su propia
  // cotizacion sobre un vehiculo ajeno y con eso disparar el unico requisito
  // que `onCotizacionAceptada` exige para abrir un ticket de `reparaciones`.
  test('el mecanico NO puede auto-aceptar su propia cotizacion', async () => {
    await seedCotizacion();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(
      db.collection('cotizaciones').doc('c1').update({ estado: 'aceptada' }),
    );
  });

  test('el mecanico NO puede auto-rechazar la cotizacion tampoco (solo el propietario resuelve pendiente/aceptada/rechazada)', async () => {
    await seedCotizacion();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(
      db.collection('cotizaciones').doc('c1').update({ estado: 'rechazada' }),
    );
  });

  test('el propietario SI puede aceptar la cotizacion (camino legitimo)', async () => {
    await seedCotizacion();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertSucceeds(
      db.collection('cotizaciones').doc('c1').update({ estado: 'aceptada' }),
    );
  });

  test('el mecanico SI puede marcar finalizada (camino legitimo)', async () => {
    await seedCotizacion();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertSucceeds(
      db.collection('cotizaciones').doc('c1').update({ estado: 'finalizada' }),
    );
  });

  test('el propietario NO puede marcar finalizada', async () => {
    await seedCotizacion();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db.collection('cotizaciones').doc('c1').update({ estado: 'finalizada' }),
    );
  });
});

describe('cotizaciones/privado/margen (hallazgo H2: el beneficio no debe ser legible por el propietario)', () => {
  const seedMargen = async () => {
    await seed(env, async (s) => {
      await s.collection('cotizaciones').doc('c1').set({
        id_propietario: UIDS.owner1,
        id_mecanico: UIDS.taller1,
        id_taller: UIDS.taller1,
        items: [{ material: 'Aceite', cantidad: 1, costo: 20 }],
        estado: 'pendiente',
      });
      await s.collection('cotizaciones').doc('c1').collection('privado').doc('margen').set({
        beneficios: [8],
      });
    });
  };

  test('el mecanico dueño SI puede leer su margen', async () => {
    await seedMargen();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertSucceeds(
      db.collection('cotizaciones').doc('c1').collection('privado').doc('margen').get(),
    );
  });

  test('el propietario NO puede leer el margen del mecanico', async () => {
    await seedMargen();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db.collection('cotizaciones').doc('c1').collection('privado').doc('margen').get(),
    );
  });

  test('un tercero no vinculado NO puede leer el margen', async () => {
    await seedMargen();
    const db = await withRole(env, UIDS.taller2, 'Taller');
    await assertFails(
      db.collection('cotizaciones').doc('c1').collection('privado').doc('margen').get(),
    );
  });

  test('el mecanico SI puede crear la cotizacion y su margen privado en dos pasos (flujo real de ChatRepository.crearCotizacion)', async () => {
    // FIX 1 (Ronda 2): `create` ahora exige que id_propietario sea el dueño
    // REAL de id_vehiculo (getVehicleOwner), asi que este fixture necesita
    // un vehiculo de verdad en vez de solo los ids sueltos que bastaban antes.
    await seed(env, async (s) => {
      await s.collection('vehiculos').doc('v-c2').set({
        id_propietario: UIDS.owner1,
        placa: 'DEF456',
      });
    });
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertSucceeds(
      db.collection('cotizaciones').doc('c2').set({
        id_propietario: UIDS.owner1,
        id_mecanico: UIDS.taller1,
        id_vehiculo: 'v-c2',
        id_taller: UIDS.taller1,
        items: [{ material: 'Aceite', cantidad: 1, costo: 20 }],
        estado: 'pendiente',
      }),
    );
    await assertSucceeds(
      db.collection('cotizaciones').doc('c2').collection('privado').doc('margen').set({
        beneficios: [8],
      }),
    );
  });

  // Residual encontrado en la re-revision de la revision de rama: acotar el
  // `update` por rol y valor no sirve de nada si el `create` deja elegir el
  // estado inicial. Crear ya en 'aceptada' no dispara `onCotizacionAceptada`
  // (es un onUpdate), pero SI satisface la mitad "cotizacion aceptada" del
  // gate de `verificarAperturaManual`, que es el predicado que R14 anadio
  // para proteger `iniciarReparacionPorVehiculo`.
  test('el mecanico NO puede crear la cotizacion ya en estado aceptada', async () => {
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(
      db.collection('cotizaciones').doc('c3').set({
        id_propietario: UIDS.owner1,
        id_mecanico: UIDS.taller1,
        id_taller: UIDS.taller1,
        id_vehiculo: 'v-ajeno',
        items: [{ material: 'Aceite', cantidad: 1, costo: 20 }],
        estado: 'aceptada',
      }),
    );
  });

  // Flujo real: un cliente contacta a un taller desde el DIRECTORIO
  // (workshop_directory_screen.dart:1209), que NO pasa idVehiculo. Esa
  // conversacion no tiene vehiculo, asi que CotizacionModel.toMap() omite
  // la clave 'id_vehiculo' por completo (cotizacion_model.dart:111). Si la
  // regla hace getVehicleOwner() sobre un campo inexistente, revienta con
  // "property is undefined" y DENIEGA — rompiendo la via mas comun de
  // cotizar. No hay riesgo en permitirlo: sin id_vehiculo no se puede
  // encadenar el ataque (existeCotizacionAceptada busca por vehiculo), y
  // aceptar sigue exigiendo ser el id_propietario nombrado.
  test('el mecanico SI puede cotizar en un chat SIN vehiculo (contacto desde el directorio)', async () => {
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertSucceeds(
      db.collection('cotizaciones').doc('c5').set({
        id_propietario: UIDS.owner1,
        id_mecanico: UIDS.taller1,
        id_taller: UIDS.taller1,
        items: [{ material: 'Diagnostico', cantidad: 1, costo: 15 }],
        estado: 'pendiente',
      }),
    );
  });

  test('el mecanico NO puede crear la cotizacion ya en estado finalizada', async () => {
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(
      db.collection('cotizaciones').doc('c4').set({
        id_propietario: UIDS.owner1,
        id_mecanico: UIDS.taller1,
        id_taller: UIDS.taller1,
        items: [],
        estado: 'finalizada',
      }),
    );
  });
});

// Ronda 2 (FIX 1): hasta aqui, `create` solo comprobaba `id_mecanico ==
// auth.uid` y `estado == 'pendiente'`. NADA ataba `id_propietario`,
// `id_vehiculo` o `id_taller` a la realidad. Un reviewer PROBO contra el
// emulador que un mecanico podia crear
// {id_mecanico: self, id_propietario: SELF, id_vehiculo: <vehiculo ajeno>,
// estado: 'pendiente'} y luego, con la rama DEL PROPIETARIO de `update` (ya
// blindada por rol+valor), aceptarsela el mismo — dos escrituras hasta
// 'aceptada'. Eso es justo lo que `existeCotizacionAceptada`
// (iniciarReparacionPorVehiculo.js:47-56) busca.
describe('cotizaciones create (FIX 1: ataque de auto-aceptacion en dos escrituras)', () => {
  const seedVehiculoAjeno = async () =>
    seed(env, async (s) => {
      await s.collection('vehiculos').doc('v-victima').set({
        id_propietario: UIDS.owner1,
        placa: 'XYZ999',
        talleres_vinculados: [],
      });
    });

  test('ATAQUE: el mecanico NO puede crear una cotizacion nombrandose a si mismo id_propietario sobre el vehiculo de otro', async () => {
    await seedVehiculoAjeno();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(
      db.collection('cotizaciones').doc('ataque1').set({
        id_mecanico: UIDS.taller1,
        id_propietario: UIDS.taller1, // se nombra a si mismo, no al dueño real
        id_vehiculo: 'v-victima',
        id_taller: UIDS.taller1,
        items: [],
        estado: 'pendiente',
      }),
    );
  });

  test('ATAQUE (variante): id_propietario apunta a un tercero cualquiera, no al dueño real del vehiculo', async () => {
    await seedVehiculoAjeno();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(
      db.collection('cotizaciones').doc('ataque2').set({
        id_mecanico: UIDS.taller1,
        id_propietario: UIDS.owner2, // no es el dueño real (owner1)
        id_vehiculo: 'v-victima',
        id_taller: UIDS.taller1,
        items: [],
        estado: 'pendiente',
      }),
    );
  });

  test('ATAQUE: un mecanico NO puede crear en nombre de un taller ajeno (actuaPorTaller falla)', async () => {
    await seedVehiculoAjeno();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(
      db.collection('cotizaciones').doc('ataque3').set({
        id_mecanico: UIDS.taller1,
        id_propietario: UIDS.owner1, // dueño real, para aislar el chequeo de taller
        id_vehiculo: 'v-victima',
        id_taller: UIDS.taller2, // taller ajeno
        items: [],
        estado: 'pendiente',
      }),
    );
  });

  test('LEGITIMO: el mecanico crea la cotizacion sobre su propio vehiculo del dueño real', async () => {
    await seedVehiculoAjeno();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertSucceeds(
      db.collection('cotizaciones').doc('legitimo1').set({
        id_mecanico: UIDS.taller1,
        id_propietario: UIDS.owner1,
        id_vehiculo: 'v-victima',
        id_taller: UIDS.taller1,
        items: [],
        estado: 'pendiente',
      }),
    );
  });

  test('LEGITIMO: un EMPLEADO del taller crea la cotizacion en nombre del taller dueño (actuaPorTaller)', async () => {
    await seedVehiculoAjeno();
    const db = await withRole(env, UIDS.empleado1, 'Mecanico', {
      id_taller_propietario: UIDS.taller1,
    });
    await assertSucceeds(
      db.collection('cotizaciones').doc('legitimo2').set({
        id_mecanico: UIDS.empleado1,
        id_propietario: UIDS.owner1,
        id_vehiculo: 'v-victima',
        id_taller: UIDS.taller1, // uid del DUEÑO, no del empleado
        items: [],
        estado: 'pendiente',
      }),
    );
  });

  test('LEGITIMO: cotizacion con reserva asociada (reserva_chat_card/reserva_detail_screen), mismo dueño real', async () => {
    await seedVehiculoAjeno();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertSucceeds(
      db.collection('cotizaciones').doc('legitimo3').set({
        id_mecanico: UIDS.taller1,
        id_propietario: UIDS.owner1,
        id_vehiculo: 'v-victima',
        id_taller: UIDS.taller1,
        id_reserva: 'r1',
        items: [],
        estado: 'pendiente',
      }),
    );
  });

  test('ATAQUE: el mecanico no puede ser su propio propietario aunque de casualidad sea dueño de su propio vehiculo', async () => {
    await seed(env, async (s) => {
      await s.collection('vehiculos').doc('v-propio').set({
        id_propietario: UIDS.taller1,
        placa: 'ABC111',
        talleres_vinculados: [],
      });
    });
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(
      db.collection('cotizaciones').doc('ataque4').set({
        id_mecanico: UIDS.taller1,
        id_propietario: UIDS.taller1,
        id_vehiculo: 'v-propio',
        id_taller: UIDS.taller1,
        items: [],
        estado: 'pendiente',
      }),
    );
  });
});
