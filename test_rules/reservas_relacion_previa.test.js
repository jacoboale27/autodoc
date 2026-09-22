const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { makeEnv, seed, withRole, UIDS } = require('./helpers');

let env;
beforeAll(async () => { env = await makeEnv(); });
afterAll(async () => { await env.cleanup(); });
beforeEach(async () => { await env.clearFirestore(); });

// Crear una cita exigia solo «asignate a ti mismo en tu propio campo». El
// comentario de la regla lo reconocia como riesgo residual: no se comprobaba
// que existiera relacion previa entre los dos uid.
//
// Lo que eso permite: cualquier cuenta autenticada crea una reserva con
// `id_mecanico` = la victima, y `onReservaCreada` (functions/index.js:467-500)
// confia en ese campo y le manda una notificacion. Es suplantacion con
// notificacion dirigida, reproducible sin tocar la UI.
//
// El arreglo ata la cita a su conversacion, que ya es una relacion de fiar:
// crear una conversacion se endurecio en el hallazgo C2 justo porque
// `obtenerPerfilPublico` se apoya en que existir implica relacion legitima.
// `ReservaModel.toMap()` ya escribe `id_conversacion` siempre
// (reserva_model.dart:66) y en `lib/` solo hay UN creador de reservas
// (reserva_repository.dart:25), asi que el contrato no cambia para la app.

const seedConversacion = () => seed(env, async (s) => {
  await s.collection('conversaciones').doc('c1').set({
    id_conversacion: 'c1',
    id_propietario: UIDS.owner1,
    id_mecanico: UIDS.taller1,
    ultimo_mensaje_ts: new Date(),
  });
});

const cita = (extra = {}) => ({
  id_conversacion: 'c1',
  id_propietario: UIDS.owner1,
  id_mecanico: UIDS.taller1,
  id_taller: UIDS.taller1,
  id_vehiculo: 'v1',
  id_proponente: UIDS.owner1,
  estado: 'pendiente',
  fecha_hora_propuesta: new Date('2026-10-01T10:00:00Z'),
  fecha_creacion: new Date(),
  tipo_servicio: 'Cita General',
  ...extra,
});

describe('reservas: una cita nace de una conversacion existente', () => {
  test('un extrano NO puede citar a un mecanico con el que no habla', async () => {
    await seedConversacion();
    const db = await withRole(env, UIDS.owner2, 'Propietario');
    await assertFails(
      db.collection('reservas').doc('r-spam').set(
        cita({ id_propietario: UIDS.owner2, id_proponente: UIDS.owner2 }),
      ),
    );
  });

  test('tampoco inventandose una conversacion que no existe', async () => {
    await seedConversacion();
    const db = await withRole(env, UIDS.owner2, 'Propietario');
    await assertFails(
      db.collection('reservas').doc('r-spam').set(
        cita({
          id_conversacion: 'no-existe',
          id_propietario: UIDS.owner2,
          id_proponente: UIDS.owner2,
        }),
      ),
    );
  });

  test('ni colandose en una conversacion ajena poniendose de mecanico', async () => {
    await seedConversacion();
    const db = await withRole(env, UIDS.taller2, 'Taller');
    await assertFails(
      db.collection('reservas').doc('r-spam').set(
        cita({ id_mecanico: UIDS.taller2, id_proponente: UIDS.taller2 }),
      ),
    );
  });

  // Los dos controles positivos. El flujo real permite que proponga
  // CUALQUIERA de los dos participantes (el mecanico proponiendo fecha es la
  // mitad del flujo de cotizacion+agenda), asi que si estos se caen, el
  // acotado se paso de frenada.
  test('el propietario de la conversacion SI puede proponer la cita', async () => {
    await seedConversacion();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertSucceeds(db.collection('reservas').doc('r-ok').set(cita()));
  });

  test('y el mecanico de esa misma conversacion tambien', async () => {
    await seedConversacion();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertSucceeds(
      db.collection('reservas').doc('r-ok2').set(
        cita({ id_proponente: UIDS.taller1 }),
      ),
    );
  });
});

// El gate de revision de reglas encontro que atar la cita a su conversacion
// NO cerraba el ataque: solo lo encarecia en una escritura. El `allow create`
// de /conversaciones tiene una rama —la del propietario— que no comprueba NADA
// sobre `id_mecanico`, asi que el atacante se fabrica primero la conversacion
// nombrando a la victima de mecanico, y despues la cita pasa el gate nuevo.
//
// La "relacion de fiar" solo era de fiar en la rama del mecanico, que exige
// isMecanico() y actuaPorTaller(). Justo la que el atacante no usa.
describe('reservas: el atacante tampoco puede fabricarse la relacion', () => {
  test('no puede abrir una conversacion nombrando de mecanico a quien no lo es', async () => {
    const db = await withRole(env, UIDS.owner2, 'Propietario');
    await assertFails(
      db.collection('conversaciones').doc('c-falsa').set({
        id_conversacion: 'c-falsa',
        id_propietario: UIDS.owner2,
        // La victima es un PROPIETARIO, no un taller.
        id_mecanico: UIDS.owner1,
        ultimo_mensaje_ts: new Date(),
      }),
    );
  });

  // Control positivo: un propietario SI puede abrir conversacion con un taller
  // aprobado de verdad. Sin esto, el acotado podria cerrar el flujo real de
  // "contactar al taller" y los negativos seguirian verdes.
  test('un propietario SI puede abrir conversacion con un taller aprobado', async () => {
    await seed(env, async (s) => {
      await s.collection('usuarios').doc(UIDS.taller1).set({
        id_usuario: UIDS.taller1, rol: 'Taller', estado: 'aprobado',
      });
    });
    const db = await withRole(env, UIDS.owner2, 'Propietario');
    await assertSucceeds(
      db.collection('conversaciones').doc('c-ok').set({
        id_conversacion: 'c-ok',
        id_propietario: UIDS.owner2,
        id_mecanico: UIDS.taller1,
        ultimo_mensaje_ts: new Date(),
      }),
    );
  });

  test('el ataque completo en dos pasos no llega a crear la cita', async () => {
    const db = await withRole(env, UIDS.owner2, 'Propietario');
    // Paso 1: fabricar la conversacion. Debe denegarse ya aqui.
    await assertFails(
      db.collection('conversaciones').doc('c-falsa').set({
        id_conversacion: 'c-falsa',
        id_propietario: UIDS.owner2,
        id_mecanico: UIDS.taller1,
        ultimo_mensaje_ts: new Date(),
      }),
    );
    // Paso 2: sin conversacion, la cita tampoco.
    await assertFails(
      db.collection('reservas').doc('r-spam2').set(
        cita({
          id_conversacion: 'c-falsa',
          id_propietario: UIDS.owner2,
          id_proponente: UIDS.owner2,
        }),
      ),
    );
  });
});

// Observaciones del 2026-09-18: la cita lleva `vehiculo_resumen` (el taller no
// puede leer la ficha del coche hasta recibirlo) y Buscar Vehiculo busca la
// cita vigente del taller para ese coche. Ninguna de las dos cosas toco las
// reglas; estos casos dejan escrito que las reglas vigentes las admiten.
describe('reservas: cotizar desde Buscar Vehiculo (observaciones 2026-09-18)', () => {
  test('el propietario puede crear la cita con el resumen del vehiculo', async () => {
    await seedConversacion();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertSucceeds(
      db.collection('reservas').add(cita({
        vehiculo_resumen: { marca: 'NISSAN', modelo: 'Rogue', placa: 'P123-123', kilometraje: 75 },
      })),
    );
  });

  test('el taller puede listar SUS citas de un vehiculo (id_mecanico + id_vehiculo)', async () => {
    await seed(env, async (s) => {
      await s.collection('reservas').doc('r1').set(cita());
    });
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertSucceeds(
      db.collection('reservas')
        .where('id_mecanico', '==', UIDS.taller1)
        .where('id_vehiculo', '==', 'v1')
        .limit(20)
        .get(),
    );
  });

  test('otro taller NO puede listar las citas de ese vehiculo con el primero', async () => {
    await seed(env, async (s) => {
      await s.collection('reservas').doc('r1').set(cita());
    });
    const db = await withRole(env, UIDS.taller2, 'Taller');
    await assertFails(
      db.collection('reservas')
        .where('id_mecanico', '==', UIDS.taller1)
        .where('id_vehiculo', '==', 'v1')
        .limit(20)
        .get(),
    );
  });
});
