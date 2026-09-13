const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { makeEnv, seed, withRole, UIDS } = require('./helpers');

let env;
beforeAll(async () => { env = await makeEnv(); });
afterAll(async () => { await env.cleanup(); });
beforeEach(async () => { await env.clearFirestore(); });

// El acotado de campos de servidor en /alertas era una DENYLIST:
// `!keys().hasAny(['ultimo_aviso', 'fecha_ultimo_aviso'])`. Enumera lo
// prohibido, asi que cubre exactamente los dos campos de servidor que existian
// el dia que se escribio, y **cualquier campo de servidor futuro nace
// escribible por el cliente** hasta que alguien recuerde ampliarla.
//
// No es hipotetico: el hallazgo de la ronda de SEC-04/OPS-01 llego por ahi
// mismo —se podia CREAR una alerta ya silenciada— y la denormalizacion de
// `avisos_pendientes` que queda pendiente anadiria el tercer campo de
// servidor. Con la denylist, ese campo nacera escribible.
//
// /reservas ya usa allowlist (`hasOnly`) y es el patron que estos tests fijan
// para /alertas. El inventario legitimo sale de `AlertModel.toMap()`
// (lib/core/models/alert_model.dart:57-71), que son los diez campos de abajo.
const CAMPOS_DEL_MODELO = {
  id_alerta: 'a1',
  id_vehiculo: 'v1',
  tipo_alerta: 'soat',
  titulo: 'SOAT por vencer',
  descripcion: 'vence pronto',
  fecha_limite: new Date('2026-12-01T00:00:00Z'),
  kilometraje_objetivo: 40000,
  estado: 'Pendiente',
  // `AlertPriority.name`: 'high' | 'medium' | 'low'.
  prioridad: 'high',
  metadata: { origen: 'manual' },
};

const seedEscenario = async () => {
  await seed(env, async (s) => {
    await s.collection('vehiculos').doc('v1').set({
      id_vehiculo: 'v1', id_propietario: UIDS.owner1, placa: 'P-1',
      talleres_vinculados: [],
    });
    await s.collection('alertas').doc('a1').set({ ...CAMPOS_DEL_MODELO });
  });
};

describe('/alertas acota los campos por allowlist, no por denylist', () => {
  // Los dos rojos que motivan el cambio. Un campo de servidor que todavia no
  // existe se modela aqui con `avisos_pendientes`, que es justo el que
  // introduciria la tanda de denormalizacion del barrido de alertas.
  test('el propietario NO puede crear una alerta con un campo que el modelo no declara', async () => {
    await seedEscenario();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db.collection('alertas').doc('a2').set({
        ...CAMPOS_DEL_MODELO,
        id_alerta: 'a2',
        avisos_pendientes: false,
      }),
    );
  });

  test('el propietario NO puede anadir un campo que el modelo no declara en un update', async () => {
    await seedEscenario();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db.collection('alertas').doc('a1').update({ avisos_pendientes: false }),
    );
  });

  // El admin queda atado igual que el propietario, por el mismo criterio que
  // ya aplica el acotado de `id_vehiculo`: una correccion real de moderacion
  // se hace con Admin SDK, que no pasa por estas reglas.
  test('el admin TAMPOCO puede colar un campo fuera del modelo', async () => {
    await seedEscenario();
    const db = await withRole(env, UIDS.admin, 'Administrador');
    await assertFails(
      db.collection('alertas').doc('a1').update({ avisos_pendientes: false }),
    );
  });

  // Los verdes que impiden que el acotado se pase de frenada. Sin estos, un
  // `hasOnly` demasiado estrecho rompe el unico flujo de escritura que la app
  // tiene hoy sobre /alertas y ninguna suite se entera.
  test('el propietario SI puede crear una alerta con los campos del modelo', async () => {
    await seedEscenario();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertSucceeds(
      db.collection('alertas').doc('a2').set({ ...CAMPOS_DEL_MODELO, id_alerta: 'a2' }),
    );
  });

  // Es literalmente lo que hace AlertProvider.completeAlert
  // (lib/features/dashboard/presentation/providers/alert_provider.dart:304).
  // `id_alerta` es identidad, como `id_vehiculo`: la app lo usa como destino
  // de la escritura al completar, asi que reescribirlo deja la alerta pintada
  // como completada y `Pendiente` en el servidor, avisando para siempre.
  test('el propietario NO puede reescribir id_alerta', async () => {
    await seedEscenario();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db.collection('alertas').doc('a1').update({ id_alerta: 'soat_colado' }),
    );
  });

  test('el propietario SI puede marcar su alerta como completada', async () => {
    await seedEscenario();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertSucceeds(
      db.collection('alertas').doc('a1').update({ estado: 'Completada' }),
    );
  });

  // La allowlist tiene que seguir cubriendo lo que cubria la denylist: estos
  // dos ya estaban cerrados y no pueden reabrirse al cambiar de forma.
  test('el propietario SIGUE sin poder crear una alerta ya silenciada', async () => {
    await seedEscenario();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db.collection('alertas').doc('a2').set({
        ...CAMPOS_DEL_MODELO,
        id_alerta: 'a2',
        ultimo_aviso: 'vencida',
      }),
    );
  });

  test('el propietario SIGUE sin poder mover su alerta a otro vehiculo', async () => {
    await seedEscenario();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db.collection('alertas').doc('a1').update({ id_vehiculo: 'v2' }),
    );
  });
});
