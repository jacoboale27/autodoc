const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { deleteField } = require('firebase/firestore');
const { makeEnv, seed, withRole, anon, UIDS } = require('./helpers');

let env;

beforeAll(async () => { env = await makeEnv(); }, 30000);
afterAll(async () => { await env.cleanup(); });
beforeEach(async () => { await env.clearFirestore(); }, 30000);

const docDe = (db, uid) => db.collection('verificaciones').doc(uid);

const sembrarExpediente = (uid, datos) => seed(env, async (db) => {
  await db.collection('verificaciones').doc(uid).set({ id_taller: uid, ...datos });
});

describe('verificaciones/{tallerId}: quien puede mover el expediente', () => {
  test('el taller crea su expediente subiendo evidencia, sin tocar el estado', async () => {
    // Es la ruta EXACTA de VerificacionService.subirEvidencia sobre un taller
    // que aun no tiene documento: un set(merge:true) con id_taller y
    // documentos, y NADA de estado_verificacion. Si las reglas exigieran esa
    // clave, el motor la leeria de un documento que no la tiene y el primer
    // archivo que sube cualquier taller nuevo se denegaria.
    const db = await withRole(env, UIDS.taller1, 'Taller', { estado: 'pendiente' });

    await assertSucceeds(
      docDe(db, UIDS.taller1).set({
        id_taller: UIDS.taller1,
        documentos: { fachada: { nombre_archivo: 'fachada.jpg', fecha: new Date() } },
      }, { merge: true }),
    );
    await assertSucceeds(
      docDe(db, UIDS.taller1).set(
        { estado_verificacion: 'listo_para_revision' },
        { merge: true },
      ),
    );
  });

  test('un taller NO puede autodegradarse a perfil_incompleto', async () => {
    // Es la puerta de atras de la re-revision. Un taller aprobado edita su
    // direccion, la Cloud Function le devuelve el expediente a la cola
    // ('listo_para_revision'), y si pudiera escribir 'perfil_incompleto'
    // desapareceria de la bandeja del administrador conservando la cuenta
    // activa: datos sin verificar publicados para siempre.
    //
    // Cerrarlo sale gratis porque NADA en la app escribe ese valor: es solo el
    // default al leer un expediente que todavia no existe.
    await sembrarExpediente(UIDS.taller1, {
      estado_verificacion: 'listo_para_revision',
      reapertura: { fecha: new Date(), campos: ['Dirección'] },
    });
    const db = await withRole(env, UIDS.taller1, 'Taller', { estado: 'activo' });

    await assertFails(
      docDe(db, UIDS.taller1).set(
        { estado_verificacion: 'perfil_incompleto' },
        { merge: true },
      ),
    );
  });

  test('un taller no puede borrar el motivo de su reapertura', async () => {
    // 'reapertura' la escribe la Cloud Function y es lo unico que le dice al
    // administrador que mirar. Un set(merge:false) la quitaria del documento.
    await sembrarExpediente(UIDS.taller1, {
      estado_verificacion: 'listo_para_revision',
      reapertura: { fecha: new Date(), campos: ['Nombre del taller'] },
    });
    const db = await withRole(env, UIDS.taller1, 'Taller', { estado: 'activo' });

    await assertFails(
      docDe(db, UIDS.taller1).set({
        id_taller: UIDS.taller1,
        estado_verificacion: 'listo_para_revision',
      }),
    );

    // Pero seguir trabajando sobre el expediente reabierto si vale: el taller
    // puede adjuntar evidencia nueva mientras espera.
    await assertSucceeds(
      docDe(db, UIDS.taller1).set({
        documentos: { rotulo: { nombre_archivo: 'rotulo.jpg', fecha: new Date() } },
      }, { merge: true }),
    );
  });

  test('un taller NO puede autoverificarse', async () => {
    // Sin esto, un taller se aprueba a si mismo con un solo write. Es el mismo
    // agujero que ya cierra la exclusion de 'estado' en el update de usuarios.
    const db = await withRole(env, UIDS.taller1, 'Taller', { estado: 'pendiente' });

    for (const estado of ['aprobada', 'rechazada', 'en_revision', 'perfil_incompleto']) {
      await assertFails(
        docDe(db, UIDS.taller1).set({
          id_taller: UIDS.taller1,
          estado_verificacion: estado,
        }),
      );
    }
  });

  test('un taller no puede inventarse el resultado de la revision', async () => {
    const db = await withRole(env, UIDS.taller1, 'Taller', { estado: 'pendiente' });

    for (const campo of ['motivo_rechazo', 'revisado_por', 'fecha_revision']) {
      await assertFails(
        docDe(db, UIDS.taller1).set({
          id_taller: UIDS.taller1,
          estado_verificacion: 'listo_para_revision',
          [campo]: 'lo que sea',
        }),
      );
    }
  });

  test('pero SI puede limpiar el rechazo anterior al reenviar', async () => {
    // Se comprueba sobre el documento RESULTANTE y no sobre el diff justo para
    // esto: el taller borra la resolucion vieja al corregir, pero no puede
    // escribirla. El historial no se pierde, queda en admin_logs.
    await sembrarExpediente(UIDS.taller1, {
      estado_verificacion: 'rechazada',
      motivo_rechazo: 'El rotulo no es legible',
      revisado_por: UIDS.admin,
      fecha_revision: new Date(),
    });
    const db = await withRole(env, UIDS.taller1, 'Taller', { estado: 'pendiente' });

    await assertSucceeds(
      docDe(db, UIDS.taller1).set({
        id_taller: UIDS.taller1,
        estado_verificacion: 'listo_para_revision',
      }),
    );
  });

  test('el reenvio real del cliente (merge + deleteField) pasa las reglas', async () => {
    // Es la ruta EXACTA de VerificacionService.enviarARevision: un
    // set(merge:true) que borra los tres campos de resolucion con
    // FieldValue.delete(). Se prueba aparte del set plano de arriba porque lo
    // que las reglas miran es el documento resultante, y un merge lo compone
    // de forma distinta: si deleteField no llegara a quitar la clave, este
    // write se denegaria en produccion y el taller no podria reenviar nunca.
    await sembrarExpediente(UIDS.taller1, {
      estado_verificacion: 'rechazada',
      motivo_rechazo: 'El rotulo no es legible',
      revisado_por: UIDS.admin,
      fecha_revision: new Date(),
    });
    const db = await withRole(env, UIDS.taller1, 'Taller', { estado: 'pendiente' });

    await assertSucceeds(
      docDe(db, UIDS.taller1).set({
        id_taller: UIDS.taller1,
        estado_verificacion: 'listo_para_revision',
        fecha_envio: new Date(),
        motivo_rechazo: deleteField(),
        revisado_por: deleteField(),
        fecha_revision: deleteField(),
      }, { merge: true }),
    );
  });

  test('un taller no toca el expediente de otro', async () => {
    await sembrarExpediente(UIDS.taller2, { estado_verificacion: 'listo_para_revision' });
    const db = await withRole(env, UIDS.taller1, 'Taller', { estado: 'pendiente' });

    await assertFails(
      docDe(db, UIDS.taller2).set(
        { estado_verificacion: 'listo_para_revision' },
        { merge: true },
      ),
    );
  });
});

describe('verificaciones/{tallerId}: lectura', () => {
  beforeEach(async () => {
    await sembrarExpediente(UIDS.taller1, {
      estado_verificacion: 'rechazada',
      motivo_rechazo: 'El rotulo no es legible',
    });
  });

  test('el propio taller y un admin lo leen', async () => {
    const suyo = await withRole(env, UIDS.taller1, 'Taller', { estado: 'pendiente' });
    const admin = await withRole(env, UIDS.admin, 'Administrador');

    await assertSucceeds(docDe(suyo, UIDS.taller1).get());
    await assertSucceeds(docDe(admin, UIDS.taller1).get());
  });

  test('otro taller no lo lee', async () => {
    const otro = await withRole(env, UIDS.taller2, 'Taller');
    await assertFails(docDe(otro, UIDS.taller1).get());
  });

  test('nunca es de lectura anonima, al reves que talleres/', async () => {
    await assertFails(docDe(anon(env), UIDS.taller1).get());
  });
});

describe('verificaciones/{tallerId}: resolucion del admin', () => {
  test('el admin toma el caso, lo resuelve y deja motivo', async () => {
    await sembrarExpediente(UIDS.taller1, { estado_verificacion: 'listo_para_revision' });
    const db = await withRole(env, UIDS.admin, 'Administrador');

    await assertSucceeds(
      docDe(db, UIDS.taller1).set({ estado_verificacion: 'en_revision' }, { merge: true }),
    );
    await assertSucceeds(
      docDe(db, UIDS.taller1).set({
        estado_verificacion: 'rechazada',
        motivo_rechazo: 'La direccion no coincide',
        revisado_por: UIDS.admin,
        fecha_revision: new Date(),
      }, { merge: true }),
    );
  });

  test('el lote real del cliente (expediente + cuenta + log) pasa las reglas', async () => {
    // Ruta EXACTA de VerificacionService.aprobar: un WriteBatch con las tres
    // escrituras. Las reglas evaluan cada write del lote por separado, asi que
    // basta con que una sola sea denegada para que el admin no pueda aprobar
    // nada. Se prueba entero y no write a write por eso.
    await sembrarExpediente(UIDS.taller1, { estado_verificacion: 'en_revision' });
    await withRole(env, UIDS.taller1, 'Taller', { estado: 'pendiente' });
    const db = await withRole(env, UIDS.admin, 'Administrador');

    const lote = db.batch();
    lote.set(db.collection('verificaciones').doc(UIDS.taller1), {
      estado_verificacion: 'aprobada',
      revisado_por: UIDS.admin,
      fecha_revision: new Date(),
    }, { merge: true });
    lote.set(db.collection('usuarios').doc(UIDS.taller1), {
      estado: 'activo',
    }, { merge: true });
    lote.set(db.collection('admin_logs').doc('log-aprobacion'), {
      id_log: 'log-aprobacion',
      admin_uid: UIDS.admin,
      accion: 'APROBAR_VERIFICACION',
      referencia_id: UIDS.taller1,
      fecha: new Date(),
    });

    await assertSucceeds(lote.commit());
  });

  test('ese mismo lote, firmado por un no-admin, no pasa', async () => {
    await sembrarExpediente(UIDS.taller1, { estado_verificacion: 'en_revision' });
    const db = await withRole(env, UIDS.taller1, 'Taller', { estado: 'pendiente' });

    const lote = db.batch();
    lote.set(db.collection('verificaciones').doc(UIDS.taller1), {
      estado_verificacion: 'aprobada',
    }, { merge: true });
    lote.set(db.collection('usuarios').doc(UIDS.taller1), { estado: 'activo' }, { merge: true });

    await assertFails(lote.commit());
  });

  test('solo el admin borra el expediente', async () => {
    await sembrarExpediente(UIDS.taller1, { estado_verificacion: 'aprobada' });

    const taller = await withRole(env, UIDS.taller1, 'Taller', { estado: 'activo' });
    await assertFails(docDe(taller, UIDS.taller1).delete());

    const admin = await withRole(env, UIDS.admin, 'Administrador');
    await assertSucceeds(docDe(admin, UIDS.taller1).delete());
  });
});

describe('admin_logs: la auditoria va firmada por quien la escribe', () => {
  const log = (db, id) => db.collection('admin_logs').doc(id);

  test('un admin firma su propia entrada', async () => {
    const db = await withRole(env, UIDS.admin, 'Administrador');
    await assertSucceeds(
      log(db, 'log1').set({ admin_uid: UIDS.admin, accion: 'APROBAR_TALLER' }),
    );
  });

  test('un admin no puede firmar en nombre de otro admin', async () => {
    // 'admin_uid' viaja en el payload del cliente (AdminLogModel.toMap), asi
    // que sin este chequeo un administrador podia ensuciarle el historial a
    // otro.
    await withRole(env, 'uid-admin-2', 'Administrador');
    const db = await withRole(env, UIDS.admin, 'Administrador');

    await assertFails(
      log(db, 'log1').set({ admin_uid: 'uid-admin-2', accion: 'APROBAR_TALLER' }),
    );
  });

  test('una entrada sin admin_uid no pasa', async () => {
    const db = await withRole(env, UIDS.admin, 'Administrador');
    await assertFails(log(db, 'log1').set({ accion: 'APROBAR_TALLER' }));
  });

  test('un no-admin no escribe logs', async () => {
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(log(db, 'log1').set({ admin_uid: UIDS.owner1 }));
  });

  test('las entradas son inmutables', async () => {
    await seed(env, async (db) => {
      await db.collection('admin_logs').doc('log1').set({ admin_uid: UIDS.admin });
    });
    const db = await withRole(env, UIDS.admin, 'Administrador');

    await assertFails(log(db, 'log1').update({ accion: 'otra cosa' }));
    await assertFails(log(db, 'log1').delete());
  });
});

describe('usuarios: el create deniega limpio en vez de reventar', () => {
  test('un create sin rol se deniega, no lanza "Property rol is undefined"', async () => {
    // Sin el guarda `'rol' in request.resource.data` el motor de reglas
    // produce un error de evaluacion en vez de un false: mismo efecto sobre
    // ese write, pero un modo de fallo mucho peor de diagnosticar y que se
    // propaga en cuanto la condicion entre en un `||`.
    const db = env.authenticatedContext(UIDS.owner1).firestore();
    await assertFails(db.collection('usuarios').doc(UIDS.owner1).set({ foo: 'bar' }));
  });

  test('un mecanico no se autoregistra ya aprobado', async () => {
    const db = env.authenticatedContext(UIDS.taller1).firestore();

    await assertFails(
      db.collection('usuarios').doc(UIDS.taller1).set({ rol: 'Mecanico', estado: 'activo' }),
    );
    await assertSucceeds(
      db.collection('usuarios').doc(UIDS.taller1).set({ rol: 'Mecanico', estado: 'pendiente' }),
    );
  });
});
