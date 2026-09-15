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
  // GAPS-05: la denormalizacion del barrido. Nace `true` y solo el
  // servidor la apaga.
  avisos_pendientes: true,
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
  // Los dos rojos que motivan el cambio, con un campo de servidor que todavia
  // no existe.
  //
  // Antes ese papel lo hacia `avisos_pendientes`, «justo el que introduciria
  // la tanda de denormalizacion del barrido». GAPS-05 lo introdujo, asi que
  // dejo de servir: estos tres tests habrian seguido en VERDE, pero por otra
  // regla —el pin a `true` del create y la allowlist de mutables— en vez de
  // por el `hasOnly` que dicen cubrir. Verde por el motivo equivocado es
  // exactamente la enfermedad que este repo lleva cinco tandas persiguiendo,
  // asi que el marcador vuelve a ser un campo que de verdad no existe.
  test('el propietario NO puede crear una alerta con un campo que el modelo no declara', async () => {
    await seedEscenario();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db.collection('alertas').doc('a2').set({
        ...CAMPOS_DEL_MODELO,
        id_alerta: 'a2',
        campo_de_servidor_futuro: false,
      }),
    );
  });

  test('el propietario NO puede anadir un campo que el modelo no declara en un update', async () => {
    await seedEscenario();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db.collection('alertas').doc('a1').update({ campo_de_servidor_futuro: false }),
    );
  });

  // El admin queda atado igual que el propietario, por el mismo criterio que
  // ya aplica el acotado de `id_vehiculo`: una correccion real de moderacion
  // se hace con Admin SDK, que no pasa por estas reglas.
  test('el admin TAMPOCO puede colar un campo fuera del modelo', async () => {
    await seedEscenario();
    const db = await withRole(env, UIDS.admin, 'Administrador');
    await assertFails(
      db.collection('alertas').doc('a1').update({ campo_de_servidor_futuro: false }),
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

// GAPS-05 — gap 14 de GAPS-04: el `create` no exigia NINGUN campo.
//
// `hasOnly` acota por arriba (nada fuera de la lista) pero no por abajo:
// admitia cualquier subconjunto, incluido el conjunto vacio. La consecuencia
// concreta es que `estado` podia no existir, y el barrido diario filtra por
// `where('estado','==','Pendiente')` (`alertasVencidas.js:97`): una alerta sin
// ese campo no la ve nunca y no avisa jamas. Es auto-silenciarse —solo afecta
// a los documentos del propio atacante— pero es irreversible en la practica,
// porque nadie vuelve a mirar una alerta que no sale en ninguna consulta.
//
// Exigir el documento completo es gratis aqui: **en `lib/` no hay ningun
// creador cliente de `/alertas`**. Se buscaron los cuatro accesos a la
// coleccion (admin_service.dart:296, vehicle_service.dart:145,
// alert_provider.dart:55 y :304) y son un `snapshots()`, un borrado en lote,
// otro `snapshots()` y un `update({'estado': ...})`. Las alertas las crea el
// servidor con Admin SDK, que no pasa por estas reglas. Y la lista no se puede
// desincronizar del modelo: `camposDeAlerta()` la cruza con `AlertModel.toMap()`
// en las dos direcciones el centinela `test/alertas_campos_test.dart`.
describe('alertas: el create exige el documento entero', () => {
  test('una alerta SIN estado no se puede crear', async () => {
    await seedEscenario();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    const sinEstado = { ...CAMPOS_DEL_MODELO, id_alerta: 'a3' };
    delete sinEstado.estado;
    await assertFails(db.collection('alertas').doc('a3').set(sinEstado));
  });

  test('tampoco una a medias, aunque todo lo que traiga este permitido', async () => {
    await seedEscenario();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db.collection('alertas').doc('a4').set({
        id_alerta: 'a4',
        id_vehiculo: 'v1',
        estado: 'Pendiente',
      }),
    );
  });

  test('con `estado` de un tipo que la consulta no puede casar, tampoco', async () => {
    await seedEscenario();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db.collection('alertas').doc('a5').set({
        ...CAMPOS_DEL_MODELO,
        id_alerta: 'a5',
        estado: 42,
      }),
    );
  });

  test('el documento completo del modelo SI se crea', async () => {
    await seedEscenario();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertSucceeds(
      db.collection('alertas').doc('a6').set({
        ...CAMPOS_DEL_MODELO,
        id_alerta: 'a6',
      }),
    );
  });

  test('y `estado` no se puede BORRAR despues con FieldValue.delete()', async () => {
    // El otro extremo del mismo agujero: cerrar el create y dejar el update
    // abierto deja llegar al mismo sitio en dos pasos. Es la leccion de
    // `abierto` en GAPS-02, que se podia borrar aunque no se pudiera falsear.
    await seedEscenario();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    const { deleteField } = require('firebase/firestore');
    await assertFails(
      db.collection('alertas').doc('a1').update({ estado: deleteField() }),
    );
  });
});

// GAPS-05, del gate de revision — `hasAll` cerro UNA de las tres formas de
// dejar una alerta fuera del barrido. Las otras dos:
//
//   a) `estado` con un VALOR que la consulta no casa. El filtro es
//      `where('estado','==','Pendiente')`, asi que nacer 'Completada' es tan
//      invisible como nacer sin el campo. `estado is string` ataba el tipo y
//      no el valor.
//   b) `fecha_limite` corrupta. El barrido tiene un SEGUNDO filtro dentro del
//      bucle (`leerFechaLimite` -> `resumen.ilegibles`), y ese campo si es
//      mutable: un update que lo deje en un string saca la alerta del aviso
//      para siempre dejandola `Pendiente`. Es el mismo agujero por el campo de
//      al lado.
//
// `null` SI es legitimo y por eso no se prohibe: `AlertModel.toMap()` escribe
// `fecha_limite: null` cuando no hay fecha. Una alerta sin fecha es silenciosa
// por diseno; lo que no puede es serlo por confusion de tipo.
describe('alertas: las otras dos vias de auto-silenciado', () => {
  test('no se puede nacer con un estado que el barrido no casa', async () => {
    await seedEscenario();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db.collection('alertas').doc('a7').set({
        ...CAMPOS_DEL_MODELO,
        id_alerta: 'a7',
        estado: 'Completada',
      }),
    );
  });

  test('ni corromper el tipo de fecha_limite en un update', async () => {
    await seedEscenario();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db.collection('alertas').doc('a1').update({ fecha_limite: 'el martes' }),
    );
  });

  test('pero dejarla en null SI vale: es una alerta sin fecha', async () => {
    await seedEscenario();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertSucceeds(
      db.collection('alertas').doc('a1').update({ fecha_limite: null }),
    );
  });

  test('y cambiarla a otra fecha tambien', async () => {
    await seedEscenario();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertSucceeds(
      db.collection('alertas').doc('a1').update({
        fecha_limite: new Date('2027-01-01T00:00:00Z'),
      }),
    );
  });
});

describe('alertas: avisos_pendientes es contabilidad del servidor', () => {
  // Es la denormalizacion que hace que el barrido diario no relea lo ya
  // avisado (gap 1 del §5 de `GAPS-05-drenaje.md`). Como el barrido consulta
  // `avisos_pendientes == true`, poder apagarlo es poder silenciarse los
  // avisos para siempre — y de forma irreversible en la practica, porque un
  // documento que no sale en ninguna consulta ya no lo mira nadie.
  //
  // Es la tercera via de auto-silenciado que se cierra en /alertas, despues de
  // nacer sin `estado` y de nacer con `estado` equivocado.

  test('no se puede nacer con los avisos ya apagados', async () => {
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db.collection('alertas').doc('nueva').set({
        ...CAMPOS_DEL_MODELO,
        id_alerta: 'nueva',
        avisos_pendientes: false,
      })
    );
  });

  test('tampoco se puede nacer SIN el campo', async () => {
    // Una igualdad sobre un campo ausente no devuelve nada, asi que omitirlo
    // es exactamente tan invisible como ponerlo a false. Lo cierra `hasAll`.
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    const sinCampo = { ...CAMPOS_DEL_MODELO, id_alerta: 'nueva' };
    delete sinCampo.avisos_pendientes;
    await assertFails(db.collection('alertas').doc('nueva').set(sinCampo));
  });

  test('el propietario NO puede apagarlos despues, en un update', async () => {
    await seedEscenario();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db.collection('alertas').doc('a1').update({ avisos_pendientes: false })
    );
  });

  test('ni BORRARLOS con FieldValue.delete()', async () => {
    // Atar el valor y no la presencia deja pasar el borrado, que es como se
    // esquivo una regla equivalente en GAPS-02 con `abierto`. Aqui va por
    // allowlist de `camposMutablesDeAlerta()`, que cierra las dos.
    await seedEscenario();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db.collection('alertas').doc('a1').update({
        avisos_pendientes: require('firebase/firestore').deleteField(),
      })
    );
  });

  test('el admin TAMPOCO puede apagarlos', async () => {
    // El acotado va fuera del parentesis, como `id_vehiculo`: una correccion
    // real de contabilidad se hace con Admin SDK, que no pasa por las reglas.
    await seedEscenario();
    const db = await withRole(env, UIDS.admin, 'Administrador');
    await assertFails(
      db.collection('alertas').doc('a1').update({ avisos_pendientes: false })
    );
  });

  test('y el resto de la alerta se sigue pudiendo editar', async () => {
    // Que el campo sea inmutable no debe volver la alerta ineditable: si esto
    // fallara, el acotado estaria cerrando mas de lo que dice.
    await seedEscenario();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertSucceeds(
      db.collection('alertas').doc('a1').update({ titulo: 'otro titulo' })
    );
  });
});

describe('alertas: lo que levanto el gate de revision de GAPS-05', () => {
  test('una alerta HEREDADA con fecha_limite en cadena SI se puede completar', async () => {
    // El defecto de usuario mas claro de la tanda, y era invisible: el guard
    // de tipo miraba `request.resource.data`, o sea el documento RESULTANTE.
    // En un `update({estado:'Completada'})` el `fecha_limite` heredado
    // sobrevive al merge, no es timestamp, y la escritura moria con
    // permission-denied. O sea que el dueño de una alerta heredada no podia
    // cerrarla —solo borrarla— mientras el barrido, que si parsea cadenas a
    // proposito, le seguia mandando cada escalon. Cerrar el tipo hacia
    // ineditable justo la alerta que mas molesta.
    await seed(env, async (s) => {
      await s.collection('vehiculos').doc('v1').set({
        id_vehiculo: 'v1', id_propietario: UIDS.owner1, placa: 'P-1',
        talleres_vinculados: [],
      });
      await s.collection('alertas').doc('a1').set({
        ...CAMPOS_DEL_MODELO,
        fecha_limite: '2026-12-01T00:00:00Z',
      });
    });
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertSucceeds(
      db.collection('alertas').doc('a1').update({ estado: 'Completada' }),
    );
  });

  test('pero seguir ESCRIBIENDO una cadena en fecha_limite no vale', async () => {
    // El guard se relaja solo para el valor heredado que no se toca. Si el
    // update CAMBIA el campo, el tipo se sigue exigiendo: si no, la relajacion
    // reabriria el agujero entero.
    await seedEscenario();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db.collection('alertas').doc('a1').update({ fecha_limite: 'manana' }),
    );
  });

  test('id_alerta tiene que casar con el id del documento', async () => {
    // El update ya sacaba `id_alerta` de los mutables, porque reescribirlo a un
    // prefijo sintetico hace que `completeAlert` se salte la escritura en
    // silencio. Ese mismo estado se alcanzaba de NACIMIENTO.
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db.collection('alertas').doc('a2').set({
        ...CAMPOS_DEL_MODELO,
        id_alerta: 'soat_v1',
      }),
    );
  });

  test('un avisos_pendientes de otro TIPO tampoco cuela', async () => {
    // La regla es solida por construccion —en el lenguaje de reglas
    // `"true" == true` es false—, pero sin estos casos, reescribir el pin como
    // `is bool` dejaria los otros tests en verde y abriria el agujero.
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    for (const valor of ['true', 1]) {
      await assertFails(
        db.collection('alertas').doc('a2').set({
          ...CAMPOS_DEL_MODELO,
          id_alerta: 'a2',
          avisos_pendientes: valor,
        }),
      );
    }
  });
});

