// Gap 9.1 — el booleano `abierto` que el tablero consulta va atado al `estado`
// RESULTANTE del ticket, en las reglas.
//
// El tablero pasa de `whereIn` sobre cinco estados a la igualdad
// `abierto == true` (un `in` aplica el `limit` a cada subconsulta, así que
// leía hasta 1000 documentos para devolver 200). El precio de esa
// denormalizacion es que el campo puede mentir, y quien lo escribe es el
// cliente: si un taller pudiera poner `abierto: false` en un ticket vivo,
// escondería un coche de su propio tablero — y si pudiera ponerlo en `true`
// sobre uno entregado, lo resucitaría a efectos de la consulta.
//
// La atadura mira `request.resource.data` —el documento que QUEDA— y no
// `resource.data`. Esa distincion no es un detalle: autorizar mirando el
// documento VIEJO es exactamente el patron que destapo los cinco huecos de
// autorizacion de QA-01.
const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { makeEnv, seed, withRole, UIDS } = require('./helpers');
// El SDK modular, igual que en `solicitudes_landing.test.js`: hace falta para
// poder ejercer el BORRADO del campo, que es el caso que la regla tolera mal.
const { deleteField } = require('firebase/firestore');

let env;
beforeAll(async () => { env = await makeEnv(); }, 60000);
afterAll(async () => { await env.cleanup(); });
beforeEach(async () => { await env.clearFirestore(); });

const seedTicket = async (estado, abierto) => {
  await seed(env, async (s) => {
    await s.collection('vehiculos').doc('v1').set({
      id_vehiculo: 'v1', id_propietario: UIDS.owner1, placa: 'ABC123',
      talleres_vinculados: [UIDS.taller1], talleres_conocidos: [UIDS.taller1],
    });
    await s.collection('reparaciones').doc('rep1').set({
      id_propietario: UIDS.owner1, id_taller: UIDS.taller1,
      id_vehiculo: 'v1', placa: 'ABC123', estado, abierto,
      historial_estados: [],
    });
  });
};

const comoTaller1 = () => withRole(env, UIDS.taller1, 'Taller');

describe('reparaciones: `abierto` sigue al estado resultante', () => {
  test('avanzar de columna con `abierto` en true se permite', async () => {
    await seedTicket('recibido', true);
    const db = await comoTaller1();
    await assertSucceeds(
      db.collection('reparaciones').doc('rep1')
        .update({ estado: 'en_revision', abierto: true })
    );
  });

  test('entregar poniendo `abierto` en false se permite', async () => {
    await seedTicket('listo_para_entrega', true);
    const db = await comoTaller1();
    await assertSucceeds(
      db.collection('reparaciones').doc('rep1')
        .update({ estado: 'entregado', abierto: false })
    );
  });

  test('entregar SIN bajar `abierto` se deniega', async () => {
    await seedTicket('listo_para_entrega', true);
    const db = await comoTaller1();
    // El ticket quedaria cerrado y en el tablero a la vez: un coche entregado
    // ocupando una columna para siempre.
    await assertFails(
      db.collection('reparaciones').doc('rep1').update({ estado: 'entregado' })
    );
  });

  test('cancelar SIN bajar `abierto` se deniega', async () => {
    await seedTicket('recibido', true);
    const db = await comoTaller1();
    await assertFails(
      db.collection('reparaciones').doc('rep1').update({ estado: 'cancelado' })
    );
  });

  test('bajar `abierto` en un ticket vivo se deniega', async () => {
    await seedTicket('en_revision', true);
    const db = await comoTaller1();
    // Esconder el coche del propio tablero sin cerrarlo: el ticket sigue
    // abierto para el propietario y para el vinculo con el vehiculo, pero el
    // taller deja de verlo. Es la incoherencia que el test de Dart fabrica a
    // mano para distinguir las dos consultas.
    await assertFails(
      db.collection('reparaciones').doc('rep1').update({ abierto: false })
    );
  });

  test('BORRAR `abierto` en un ticket vivo se deniega', async () => {
    await seedTicket('en_revision', true);
    const db = await comoTaller1();
    // El gate de revision de esta misma rama: la atadura miraba el valor, y
    // un campo BORRADO no tiene valor — `.get(campo, derivado)` degeneraba en
    // `derivado == derivado`, una tautologia. El efecto es identico al que la
    // regla dice impedir: el ticket sigue vivo, con el vinculo al vehiculo
    // intacto, y desaparece del tablero. Por omision en vez de por valor
    // falso.
    await assertFails(
      db.collection('reparaciones').doc('rep1')
        .update({ abierto: deleteField() })
    );
  });

  test('entregar BORRANDO `abierto` tampoco cuela', async () => {
    await seedTicket('listo_para_entrega', true);
    const db = await comoTaller1();
    await assertFails(
      db.collection('reparaciones').doc('rep1')
        .update({ estado: 'entregado', abierto: deleteField() })
    );
  });

  test('subir `abierto` sin mover el estado tampoco cuela', async () => {
    await seedTicket('recibido', true);
    const db = await comoTaller1();
    await assertFails(
      db.collection('reparaciones').doc('rep1')
        .update({ estado: 'cancelado', abierto: true })
    );
  });

  test('un ticket legado sin `abierto` sigue pudiendo avanzar', async () => {
    // Los tickets anteriores a este cambio no traen el campo, y el backfill
    // aun no ha corrido. Un update que no lo mencione deja el documento igual
    // de mudo que estaba: no aparece en el tablero (una igualdad sobre un
    // campo ausente no devuelve nada), pero la regla no puede denegar la
    // transicion por eso — el taller se quedaria sin poder tocar sus propios
    // tickets viejos.
    await seed(env, async (s) => {
      await s.collection('reparaciones').doc('rep1').set({
        id_propietario: UIDS.owner1, id_taller: UIDS.taller1,
        id_vehiculo: 'v1', placa: 'ABC123', estado: 'recibido',
        historial_estados: [],
      });
    });
    const db = await comoTaller1();
    await assertSucceeds(
      db.collection('reparaciones').doc('rep1').update({ estado: 'en_revision' })
    );
  });
});
