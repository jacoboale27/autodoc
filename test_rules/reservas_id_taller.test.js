const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { makeEnv, seed, withRole, UIDS } = require('./helpers');

let env;
beforeAll(async () => { env = await makeEnv(); });
afterAll(async () => { await env.cleanup(); });
beforeEach(async () => { await env.clearFirestore(); });

// GAPS-05, gap 7 de H-01 y P1 de la auditoria final: el `create` de /reservas
// fijaba quien va en `id_propietario` e `id_mecanico` —la conversacion los
// pinea— pero dejaba `id_taller` LIBRE. Una cita legitima entre dos personas
// reales podia apuntar ese campo al taller de un tercero.
//
// LO QUE LA ANOTACION NO DECIA, y es lo que hizo falta comprobar antes de
// escribir la regla: el unico creador de reservas de `lib/`
// (`chat_screen.dart:346`) escribe SIEMPRE `idTaller: isMecanico ? userId :
// receptorId`, o sea exactamente el mismo valor que `id_mecanico`. Nunca
// `idTallerEfectivo` —eso lo usan las COTIZACIONES (`chat_screen.dart:1095`,
// `reserva_detail_screen.dart:207`), que son otra coleccion—. Asi que atar el
// campo a `id_mecanico` no rompe ningun flujo real: fija lo que la app ya
// hace.
//
// De paso queda dicho lo que eso significa: en una cuenta de EMPLEADO,
// `reservas.id_taller` guarda el uid del empleado y no el del taller, al reves
// que en cotizaciones. Hoy no lo lee nadie —ninguna Function lo consulta y en
// Dart solo se serializa—, pero un panel futuro que agrupe citas por taller se
// dejaria fuera las de los empleados sin que nada avise.

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

describe('reservas: id_taller no se puede apuntar a un tercero', () => {
  test('la cita que escribe la app se sigue creando', async () => {
    await seedConversacion();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertSucceeds(
      db.collection('reservas').doc('r-ok').set(cita()),
    );
  });

  test('el propietario NO puede apuntar la cita a un taller ajeno', async () => {
    await seedConversacion();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db.collection('reservas').doc('r-contaminada').set(
        cita({ id_taller: UIDS.taller2 }),
      ),
    );
  });

  test('el mecanico tampoco, ni siquiera en su propia cita', async () => {
    await seedConversacion();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(
      db.collection('reservas').doc('r-contaminada-2').set(
        cita({ id_proponente: UIDS.taller1, id_taller: UIDS.taller2 }),
      ),
    );
  });

  test('omitir id_taller tampoco cuela', async () => {
    // Sin esta comprobacion la regla se podria escribir con `.get(campo, x)`
    // y degenerar en una tautologia sobre un campo ausente — el defecto
    // exacto que GAPS-02 encontro en `abierto`.
    await seedConversacion();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    const sinTaller = cita();
    delete sinTaller.id_taller;
    await assertFails(
      db.collection('reservas').doc('r-sin-taller').set(sinTaller),
    );
  });

  test('ni dejarlo en blanco', async () => {
    await seedConversacion();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db.collection('reservas').doc('r-taller-vacio').set(
        cita({ id_taller: '' }),
      ),
    );
  });
});

// GAPS-05, del gate de revision — los otros campos de identidad del `create`.
//
// Atar `id_taller` dejo a la vista que no era el unico libre. El que importa es
// `id_proponente`, porque de el depende TODA la maquina de transiciones del
// `update`: confirmar exige `request.auth.uid != resource.data.id_proponente`,
// o sea «no puedes aceptar tu propia propuesta».
//
// Y detras habia un defecto de cliente, no solo de regla: `ReservaModel` hace
// `idProponente = idProponente ?? idPropietario` y `chat_screen.dart` NO lo
// pasaba. Cuando proponia el MECANICO, la cita nacia con el uid del
// propietario en `id_proponente`, asi que:
//   - el propietario NO podia confirmar la cita que le proponian (la regla lo
//     ve como el proponente), y
//   - el mecanico SI podia confirmar su propia propuesta.
// Justo al reves de lo que la regla quiere decir. Por eso el cliente se
// arregla primero y la regla se pinea despues: al reves se rompe la mitad del
// flujo.
describe('reservas: el resto de la identidad tambien se ata', () => {
  test('no se puede nacer nombrando proponente a la otra persona', async () => {
    await seedConversacion();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(
      db.collection('reservas').doc('r-prop').set(
        cita({ id_proponente: UIDS.owner1 }),
      ),
    );
  });

  test('el mecanico que propone queda como proponente, y el dueño puede confirmar', async () => {
    await seedConversacion();
    const dbMec = await withRole(env, UIDS.taller1, 'Taller');
    await assertSucceeds(
      dbMec.collection('reservas').doc('r-mec').set(
        cita({ id_proponente: UIDS.taller1 }),
      ),
    );

    const dbProp = await withRole(env, UIDS.owner1, 'Propietario');
    await assertSucceeds(
      dbProp.collection('reservas').doc('r-mec').update({ estado: 'confirmada' }),
    );
  });

  test('y quien propuso NO puede confirmar su propia cita', async () => {
    await seedConversacion();
    const dbMec = await withRole(env, UIDS.taller1, 'Taller');
    await dbMec.collection('reservas').doc('r-mec2').set(
      cita({ id_proponente: UIDS.taller1 }),
    );
    await assertFails(
      dbMec.collection('reservas').doc('r-mec2').update({ estado: 'confirmada' }),
    );
  });

  test('una cita no puede nacer ya confirmada', async () => {
    // /cotizaciones ya pinea su estado inicial por esta misma razon: nacer en
    // el estado final se salta el `update` entero. Aqui ademas mete la cita
    // directamente en el barrido de recordatorios sin que la contraparte haya
    // aceptado nada.
    await seedConversacion();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db.collection('reservas').doc('r-confirmada').set(
        cita({ estado: 'confirmada' }),
      ),
    );
  });

  test('ni con la fecha propuesta en texto', async () => {
    // `ReservaModel.fromMap` hace `map['fecha_hora_propuesta'] as Timestamp`
    // sin `?`: un string ahi revienta el parseo para los DOS participantes, y
    // la pantalla no tiene forma de recuperarse.
    await seedConversacion();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db.collection('reservas').doc('r-fecha-texto').set(
        cita({ fecha_hora_propuesta: 'lunes 10:00' }),
      ),
    );
  });
});
