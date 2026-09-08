const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
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
