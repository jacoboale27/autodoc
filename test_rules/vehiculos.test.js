const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { makeEnv, seed, withRole, anon, UIDS } = require('./helpers');

let env;
beforeAll(async () => { env = await makeEnv(); });
afterAll(async () => { await env.cleanup(); });
beforeEach(async () => { await env.clearFirestore(); });

const seedVehiculo = (id, propietario, vinculados = [], sharedWith = []) => async (s) => {
  await s.collection('vehiculos').doc(id).set({
    id_vehiculo: id,
    id_propietario: propietario,
    placa: 'P-' + id,
    marca: 'AUDI',
    modelo: 'A3',
    anio: 2023,
    talleres_vinculados: vinculados,
    shared_with: sharedWith,
  });
};

describe('vehiculos', () => {
  test('un propietario NO puede listar todos los vehiculos', async () => {
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await seed(env, seedVehiculo('v-ajeno', UIDS.owner2));
    await assertFails(db.collection('vehiculos').get());
  });

  test('un propietario NO puede leer el vehiculo de otro', async () => {
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await seed(env, seedVehiculo('v-ajeno', UIDS.owner2));
    await assertFails(db.collection('vehiculos').doc('v-ajeno').get());
  });

  test('un propietario SI puede leer su propio vehiculo', async () => {
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await seed(env, seedVehiculo('v-mio', UIDS.owner1));
    await assertSucceeds(db.collection('vehiculos').doc('v-mio').get());
  });

  test('un propietario SI puede listar filtrando por su propio id', async () => {
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await seed(env, seedVehiculo('v-mio', UIDS.owner1));
    await assertSucceeds(
      db.collection('vehiculos').where('id_propietario', '==', UIDS.owner1).get(),
    );
  });

  test('un taller NO vinculado NO puede leer el vehiculo', async () => {
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await seed(env, seedVehiculo('v-ajeno', UIDS.owner1, []));
    await assertFails(db.collection('vehiculos').doc('v-ajeno').get());
  });

  test('un taller vinculado SI puede leer el vehiculo', async () => {
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await seed(env, seedVehiculo('v-vinc', UIDS.owner1, [UIDS.taller1]));
    await assertSucceeds(db.collection('vehiculos').doc('v-vinc').get());
  });

  test('un taller vinculado solo puede actualizar kilometraje_actual', async () => {
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await seed(env, seedVehiculo('v-vinc', UIDS.owner1, [UIDS.taller1]));
    await assertSucceeds(
      db.collection('vehiculos').doc('v-vinc').update({ kilometraje_actual: 5000 }),
    );
    await assertFails(db.collection('vehiculos').doc('v-vinc').update({ placa: 'ROBADA' }));
  });

  test('sin autenticar NO se puede leer vehiculos', async () => {
    await seed(env, seedVehiculo('v1', UIDS.owner1));
    await assertFails(anon(env).collection('vehiculos').get());
  });

  // Cierre C1: confirmacion del propietario para talleres_vinculados/taller_pendiente_confirmacion
  test('un taller vinculado NO puede escribir talleres_vinculados directamente', async () => {
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await seed(env, seedVehiculo('v-vinc', UIDS.owner1, [UIDS.taller1]));
    await assertFails(
      db.collection('vehiculos').doc('v-vinc').update({
        talleres_vinculados: [UIDS.taller1, UIDS.taller2],
      }),
    );
  });

  test('un taller vinculado NO puede escribir taller_pendiente_confirmacion directamente', async () => {
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await seed(env, seedVehiculo('v-vinc', UIDS.owner1, [UIDS.taller1]));
    await assertFails(
      db.collection('vehiculos').doc('v-vinc').update({
        taller_pendiente_confirmacion: UIDS.taller1,
      }),
    );
  });

  test('el propietario SI puede confirmar el vinculo de un taller pendiente', async () => {
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await seed(env, async (s) => {
      await s.collection('vehiculos').doc('v-pend').set({
        id_vehiculo: 'v-pend',
        id_propietario: UIDS.owner1,
        placa: 'P-v-pend',
        talleres_vinculados: [],
        taller_pendiente_confirmacion: UIDS.taller1,
      });
    });
    await assertSucceeds(
      db.collection('vehiculos').doc('v-pend').update({
        talleres_vinculados: [UIDS.taller1],
        taller_pendiente_confirmacion: null,
      }),
    );
  });

  test('el propietario SI puede rechazar el vinculo de un taller pendiente', async () => {
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await seed(env, async (s) => {
      await s.collection('vehiculos').doc('v-pend').set({
        id_vehiculo: 'v-pend',
        id_propietario: UIDS.owner1,
        placa: 'P-v-pend',
        talleres_vinculados: [],
        taller_pendiente_confirmacion: UIDS.taller1,
      });
    });
    await assertSucceeds(
      db.collection('vehiculos').doc('v-pend').update({
        taller_pendiente_confirmacion: null,
      }),
    );
  });

  // Cierre I-1 (revision adversarial de la tarea C1): talleres_rechazados
  // debe tener la misma proteccion de escritura que talleres_vinculados/
  // taller_pendiente_confirmacion -- el mecanico no puede manipularlo (por
  // ejemplo, para borrarse a si mismo de la lista de rechazados y forzar
  // un reintento), solo el propietario.
  test('un taller vinculado NO puede escribir talleres_rechazados directamente', async () => {
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await seed(env, seedVehiculo('v-vinc', UIDS.owner1, [UIDS.taller1]));
    await assertFails(
      db.collection('vehiculos').doc('v-vinc').update({
        talleres_rechazados: [],
      }),
    );
  });

  test('el propietario SI puede registrar un taller como rechazado', async () => {
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await seed(env, async (s) => {
      await s.collection('vehiculos').doc('v-pend').set({
        id_vehiculo: 'v-pend',
        id_propietario: UIDS.owner1,
        placa: 'P-v-pend',
        talleres_vinculados: [],
        taller_pendiente_confirmacion: UIDS.taller1,
        taller_pendiente_nombre: 'Taller Uno',
        taller_pendiente_servicio_id: 'serv-1',
        talleres_rechazados: [],
      });
    });
    await assertSucceeds(
      db.collection('vehiculos').doc('v-pend').update({
        taller_pendiente_confirmacion: null,
        taller_pendiente_nombre: null,
        taller_pendiente_servicio_id: null,
        talleres_rechazados: [UIDS.taller1],
      }),
    );
  });

  test('un usuario en shared_with SI puede leer el vehiculo', async () => {
    const db = await withRole(env, UIDS.owner2, 'Propietario');
    await seed(env, seedVehiculo('v-compartido', UIDS.owner1, [], [UIDS.owner2]));
    await assertSucceeds(db.collection('vehiculos').doc('v-compartido').get());
  });

  test('un usuario que NO esta en shared_with NO puede leer el vehiculo', async () => {
    const db = await withRole(env, UIDS.owner2, 'Propietario');
    await seed(env, seedVehiculo('v-no-compartido', UIDS.owner1, [], []));
    await assertFails(db.collection('vehiculos').doc('v-no-compartido').get());
  });

  test('un usuario en shared_with NO puede actualizar el vehiculo', async () => {
    const db = await withRole(env, UIDS.owner2, 'Propietario');
    await seed(env, seedVehiculo('v-compartido', UIDS.owner1, [], [UIDS.owner2]));
    await assertFails(
      db.collection('vehiculos').doc('v-compartido').update({ placa: 'ROBADA' }),
    );
  });
});

// Galeria de fotos: vehiculos/{id}/fotos/{fotoId} (VehiclePhotoService).
// Las reglas NO se heredan de la coleccion padre; sin el match anidado tanto
// el stream como el set() morian en permission-denied y la galeria salia
// siempre vacia sin poder subir nada.
describe('vehiculos/{id}/fotos (galeria)', () => {
  const foto = { url: 'https://x/f.jpg', timestamp: new Date() };

  test('el propietario SI puede añadir una foto a su vehiculo', async () => {
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await seed(env, seedVehiculo('v-mio', UIDS.owner1));
    await assertSucceeds(
      db.collection('vehiculos').doc('v-mio').collection('fotos').doc('f1').set(foto),
    );
  });

  test('el propietario SI puede leer y borrar las fotos de su vehiculo', async () => {
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await seed(env, seedVehiculo('v-mio', UIDS.owner1));
    await seed(env, async (s) => {
      await s.collection('vehiculos').doc('v-mio').collection('fotos').doc('f1').set(foto);
    });
    await assertSucceeds(db.collection('vehiculos').doc('v-mio').collection('fotos').get());
    await assertSucceeds(
      db.collection('vehiculos').doc('v-mio').collection('fotos').doc('f1').delete(),
    );
  });

  test('un tercero NO puede leer ni escribir las fotos de un vehiculo ajeno', async () => {
    const db = await withRole(env, UIDS.owner2, 'Propietario');
    await seed(env, seedVehiculo('v-ajeno', UIDS.owner1));
    await assertFails(db.collection('vehiculos').doc('v-ajeno').collection('fotos').get());
    await assertFails(
      db.collection('vehiculos').doc('v-ajeno').collection('fotos').doc('f1').set(foto),
    );
  });

  test('un EMPLEADO del taller vinculado tambien ve las fotos (ronda 4)', async () => {
    // `talleres_vinculados` guarda el uid del DUEÑO, nunca el del empleado.
    // La regla del vehiculo padre ya comparaba contra `idTallerActor()`, pero
    // esta copia anidada se quedo comparando contra `request.auth.uid`: el
    // empleado abria la ficha del coche que su propio taller esta atendiendo
    // y la galeria le salia vacia, con permission-denied en consola.
    const db = await withRole(env, UIDS.empleado1, 'Mecanico', {
      id_taller_propietario: UIDS.taller1,
    });
    await seed(env, seedVehiculo('v-vinculado', UIDS.owner1, [UIDS.taller1]));
    await seed(env, async (s) => {
      await s.collection('vehiculos').doc('v-vinculado').collection('fotos').doc('f1').set(foto);
    });
    await assertSucceeds(
      db.collection('vehiculos').doc('v-vinculado').collection('fotos').get(),
    );
  });

  test('un EMPLEADO de OTRO taller sigue sin ver las fotos', async () => {
    const db = await withRole(env, UIDS.empleado2, 'Mecanico', {
      id_taller_propietario: UIDS.taller2,
    });
    await seed(env, seedVehiculo('v-vinculado', UIDS.owner1, [UIDS.taller1]));
    await assertFails(
      db.collection('vehiculos').doc('v-vinculado').collection('fotos').get(),
    );
  });

  test('un taller vinculado SI puede ver las fotos pero NO añadir ni borrar', async () => {
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await seed(env, seedVehiculo('v-vinculado', UIDS.owner1, [UIDS.taller1]));
    await seed(env, async (s) => {
      await s.collection('vehiculos').doc('v-vinculado').collection('fotos').doc('f1').set(foto);
    });
    await assertSucceeds(db.collection('vehiculos').doc('v-vinculado').collection('fotos').get());
    await assertFails(
      db.collection('vehiculos').doc('v-vinculado').collection('fotos').doc('f2').set(foto),
    );
    await assertFails(
      db.collection('vehiculos').doc('v-vinculado').collection('fotos').doc('f1').delete(),
    );
  });

  test('un taller NO vinculado NO puede ver las fotos', async () => {
    const db = await withRole(env, UIDS.taller2, 'Taller');
    await seed(env, seedVehiculo('v-ajeno', UIDS.owner1, [UIDS.taller1]));
    await assertFails(db.collection('vehiculos').doc('v-ajeno').collection('fotos').get());
  });

  test('sin autenticar NO se pueden leer las fotos', async () => {
    await seed(env, seedVehiculo('v-mio', UIDS.owner1));
    await assertFails(anon(env).collection('vehiculos').doc('v-mio').collection('fotos').get());
  });
});

// Leer un vehiculo que TODAVIA no existe.
//
// Sin la rama `resource == null` del allow read, un get() sobre un id
// inexistente no devuelve "no existe": evalua resource.data.id_propietario
// sobre null, error de evaluacion, PERMISSION_DENIED. Eso rompia
// VehicleImageService.getVehicleImage(), que consulta el vehiculo ANTES de que
// addVehicle() lo escriba: la excepcion tumbaba la funcion y el vehiculo nuevo
// se guardaba con el asset por defecto en foto_url sin haber buscado nunca.
describe('vehiculos: documento inexistente', () => {
  test('un usuario autenticado SI puede consultar un id que aun no existe', async () => {
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    const snap = await assertSucceeds(
      db.collection('vehiculos').doc('todavia-no-existe').get(),
    );
    expect(snap.exists).toBe(false);
  });

  test('sin autenticar NO se puede consultar un id inexistente', async () => {
    await assertFails(anon(env).collection('vehiculos').doc('todavia-no-existe').get());
  });

  test('la lectura de un vehiculo AJENO que SI existe sigue denegada', async () => {
    // La rama de null no debe haber abierto la lectura de datos reales.
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await seed(env, seedVehiculo('v-ajeno', UIDS.owner2));
    await assertFails(db.collection('vehiculos').doc('v-ajeno').get());
  });
});
