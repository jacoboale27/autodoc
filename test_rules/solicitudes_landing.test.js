const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { makeEnv, seed, withRole, anon, UIDS } = require('./helpers');

let env;
beforeAll(async () => { env = await makeEnv(); });
afterAll(async () => { await env.cleanup(); });
beforeEach(async () => { await env.clearFirestore(); });

// El buzon de los formularios de la landing (UX-01).
//
// Lo unico que escribe aqui es la Cloud Function `recibirSolicitudLanding`,
// con el Admin SDK, que no pasa por estas reglas. Desde el cliente la
// coleccion tiene que estar cerrada por los dos lados:
//
//  - escribir seria volver al problema que UX-01 cierra. El formulario de
//    afiliacion POSTeaba sin autenticar a la REST API de Firestore contra
//    /talleres; que ahora apunte a otra coleccion no arregla nada si esa
//    coleccion admite escrituras anonimas: seria un buzon que cualquiera puede
//    llenar sin pasar por la validacion ni por el limitador del endpoint.
//  - leer expone correos, telefonos y mensajes de personas que escribieron a
//    soporte. Es el dato mas sensible que produce la landing.
//
// El positivo emparejado —el administrador SI lee— es lo que demuestra que
// quien decide es el rol y no que la ruta este simplemente mal escrita.

const solicitudValida = {
  tipo: 'contacto',
  nombre: 'Ana Perez',
  correo: 'ana@example.com',
  mensaje: 'Quiero saber si cubren Santa Ana.',
  estado: 'nueva',
  origen: 'landing_web',
  ip_hash: 'abc123',
};

const sembrarSolicitud = async (id = 'sol-1') => {
  await seed(env, async (s) => {
    await s.collection('solicitudes_landing').doc(id).set(solicitudValida);
  });
};

describe('solicitudes_landing: nadie escribe desde el cliente', () => {
  test('un anonimo NO puede crear una solicitud saltandose el endpoint', async () => {
    await assertFails(
      anon(env).collection('solicitudes_landing').doc('sol-anon').set(solicitudValida)
    );
  });

  test('un usuario autenticado tampoco puede crearla', async () => {
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db.collection('solicitudes_landing').doc('sol-auth').set(solicitudValida)
    );
  });

  test('ni siquiera un Administrador escribe aqui: el buzon lo llena el Admin SDK', async () => {
    const db = await withRole(env, UIDS.admin, 'Administrador');
    await assertFails(
      db.collection('solicitudes_landing').doc('sol-admin').set(solicitudValida)
    );
  });

  test('un Administrador NO puede reescribir el contenido de una solicitud', async () => {
    await sembrarSolicitud();
    const db = await withRole(env, UIDS.admin, 'Administrador');
    await assertFails(
      db.collection('solicitudes_landing').doc('sol-1').update({ mensaje: 'otra cosa' })
    );
  });

  test('un Administrador SI puede marcarla como atendida', async () => {
    await sembrarSolicitud();
    const db = await withRole(env, UIDS.admin, 'Administrador');
    await assertSucceeds(
      db.collection('solicitudes_landing').doc('sol-1').update({ estado: 'atendida' })
    );
  });

  test('un estado inventado no pasa: la lista de estados es cerrada', async () => {
    await sembrarSolicitud();
    const db = await withRole(env, UIDS.admin, 'Administrador');
    await assertFails(
      db.collection('solicitudes_landing').doc('sol-1').update({ estado: 'lo-que-sea' })
    );
  });

  // El bypass canonico del patron, y el unico caso que distingue "el hasOnly
  // esta" de "el hasOnly se evalua JUNTO con el estado valido": colar el cambio
  // prohibido escondido detras de uno permitido. Los dos tests de arriba lo
  // atacan por separado y ninguno cubre la combinacion.
  test('cambiar el estado NO sirve de tapadera para reescribir el mensaje', async () => {
    await sembrarSolicitud();
    const db = await withRole(env, UIDS.admin, 'Administrador');
    await assertFails(
      db.collection('solicitudes_landing').doc('sol-1').update({
        estado: 'atendida',
        mensaje: 'otra cosa',
      })
    );
  });

  test('anadir un campo nuevo tampoco cuela, aunque no toque ninguno existente', async () => {
    await sembrarSolicitud();
    const db = await withRole(env, UIDS.admin, 'Administrador');
    await assertFails(
      db.collection('solicitudes_landing').doc('sol-1').update({ nota_interna: 'x' })
    );
  });

  // Borrar el campo pasa el hasOnly (affectedKeys sigue siendo ['estado']) y
  // llega a la comprobacion del valor con el campo ausente. Con `.get(...)`
  // deniega limpio; con `.estado` a secas seria un error de evaluacion.
  test('borrar el estado deniega, y deniega limpio', async () => {
    await sembrarSolicitud();
    const { deleteField } = require('firebase/firestore');

    // Antes de afirmar que la regla deniega el borrado, comprobar que lo que se
    // manda ES un borrado: si el centinela no fuese el de esta instancia,
    // llegaria un objeto raro, la regla lo rechazaria por otro motivo y el
    // verde no probaria nada. Con las reglas desactivadas el campo tiene que
    // desaparecer de verdad.
    await seed(env, async (s) => {
      await s.collection('solicitudes_landing').doc('sol-centinela').set(solicitudValida);
      await s
        .collection('solicitudes_landing')
        .doc('sol-centinela')
        .update({ estado: deleteField() });
      const doc = await s.collection('solicitudes_landing').doc('sol-centinela').get();
      expect(doc.data().estado).toBeUndefined();
    });

    const db = await withRole(env, UIDS.admin, 'Administrador');
    await assertFails(
      db.collection('solicitudes_landing').doc('sol-1').update({ estado: deleteField() })
    );
  });
});

describe('solicitudes_landing: quien puede leer el buzon', () => {
  test('un anonimo NO puede leer una solicitud', async () => {
    await sembrarSolicitud();
    await assertFails(anon(env).collection('solicitudes_landing').doc('sol-1').get());
  });

  // `get` y `list` son permisos distintos: denegar el documento suelto no
  // implica denegar la coleccion entera.
  test('un anonimo NO puede listar la coleccion', async () => {
    await sembrarSolicitud();
    await assertFails(anon(env).collection('solicitudes_landing').get());
  });

  test('un propietario cualquiera NO puede leerla', async () => {
    await sembrarSolicitud();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(db.collection('solicitudes_landing').doc('sol-1').get());
  });

  // El taller es el caso interesante: la solicitud de afiliacion la envia un
  // taller, pero eso no le da derecho a leer el buzon entero.
  test('un taller aprobado NO puede leer el buzon', async () => {
    await sembrarSolicitud();
    const db = await withRole(env, UIDS.taller1, 'Taller', { estado: 'aprobado' });
    await assertFails(db.collection('solicitudes_landing').doc('sol-1').get());
  });

  test('un Administrador SI puede leerla', async () => {
    await sembrarSolicitud();
    const db = await withRole(env, UIDS.admin, 'Administrador');
    await assertSucceeds(db.collection('solicitudes_landing').doc('sol-1').get());
  });

  test('un Administrador SI puede listar el buzon para atenderlo', async () => {
    await sembrarSolicitud('sol-1');
    await sembrarSolicitud('sol-2');
    const db = await withRole(env, UIDS.admin, 'Administrador');
    await assertSucceeds(db.collection('solicitudes_landing').get());
  });

  test('solo el Superusuario borra una solicitud', async () => {
    await sembrarSolicitud();
    const admin = await withRole(env, UIDS.admin, 'Administrador');
    await assertFails(admin.collection('solicitudes_landing').doc('sol-1').delete());

    const superusuario = await withRole(env, UIDS.superusuario, 'Superusuario');
    await assertSucceeds(superusuario.collection('solicitudes_landing').doc('sol-1').delete());
  });
});

describe('solicitudes_landing_control: el contador del limitador', () => {
  // Si un cliente pudiera tocar el contador, el limitador por IP seria
  // decorativo: bastaria con poner el conteo a cero entre envio y envio.
  const sembrarContador = async () => {
    await seed(env, async (s) => {
      await s.collection('solicitudes_landing_control').doc('hash-1').set({
        ventana_inicio: 1757000000000,
        conteo: 5,
      });
    });
  };

  // Los demas casos parten de un documento ya sembrado, o sea que ejercen la
  // puerta `update`. Esta es la de `create`, que es otra.
  test('un anonimo NO puede crear un contador nuevo', async () => {
    await assertFails(
      anon(env)
        .collection('solicitudes_landing_control')
        .doc('hash-nuevo')
        .set({ ventana_inicio: 0, conteo: 0 })
    );
  });

  test('un anonimo NO puede reiniciar el contador', async () => {
    await sembrarContador();
    await assertFails(
      anon(env).collection('solicitudes_landing_control').doc('hash-1').set({ conteo: 0 })
    );
  });

  test('un autenticado tampoco', async () => {
    await sembrarContador();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db.collection('solicitudes_landing_control').doc('hash-1').update({ conteo: 0 })
    );
  });

  test('ni un Administrador: nadie lee ni escribe el contador desde el cliente', async () => {
    await sembrarContador();
    const db = await withRole(env, UIDS.admin, 'Administrador');
    await assertFails(db.collection('solicitudes_landing_control').doc('hash-1').get());
    await assertFails(
      db.collection('solicitudes_landing_control').doc('hash-1').update({ conteo: 0 })
    );
  });
});
