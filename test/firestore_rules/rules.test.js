const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const fs = require('fs');

let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'autodoc-6ef5a',
    firestore: {
      rules: fs.readFileSync('../../firestore.rules', 'utf8'),
    },
  });
});

after(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

describe('Firestore Security Rules', () => {

  // Setup common scenarios
  function getUnauthedDb() {
    return testEnv.unauthenticatedContext().firestore();
  }
  function getAuthedDb(uid) {
    return testEnv.authenticatedContext(uid).firestore();
  }

  // Seed user data to satisfy isAdmin/isMecanico helper functions
  // `extra` permite anadir campos que las reglas miran de verdad. El mas
  // importante es 'estado': isMecanico() exige `estado in ['aprobado','activo']`
  // y por defecto asume 'pendiente', asi que un mecanico sembrado sin ese campo
  // NO es un mecanico a efectos de reglas.
  async function seedUser(uid, rol, extra = {}) {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.collection('usuarios').doc(uid).set({
        id_usuario: uid,
        nombre_completo: `Test User ${rol}`,
        correo: `test${uid}@test.com`,
        rol: rol,
        ...extra
      });
    });
  }

  // Un mecanico solo alcanza los datos de un vehiculo si ADEMAS de estar
  // aprobado figura en `talleres_vinculados` (ver isVinculadoAlVehiculo).
  async function seedVehicle(vehiculoId, ownerId, talleresVinculados = []) {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.collection('vehiculos').doc(vehiculoId).set({
        id_vehiculo: vehiculoId,
        id_propietario: ownerId,
        placa: 'TEST123',
        talleres_vinculados: talleresVinculados
      });
    });
  }

  async function seedConversation(convId, ownerId, mechanicId) {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.collection('conversaciones').doc(convId).set({
        id_conversacion: convId,
        id_propietario: ownerId,
        id_mecanico: mechanicId
      });
    });
  }

  describe('1. Usuarios Collection', () => {
    it('should deny unauthenticated read/write to usuarios', async () => {
      const db = getUnauthedDb();
      await assertFails(db.collection('usuarios').doc('user1').get());
      await assertFails(db.collection('usuarios').doc('user1').set({ foo: 'bar' }));
    });

    it('should allow a user to create and read their own Propietario profile', async () => {
      const db = getAuthedDb('user1');
      await assertSucceeds(
        db.collection('usuarios').doc('user1').set({ rol: 'Propietario', estado: 'activo' })
      );
      await assertSucceeds(db.collection('usuarios').doc('user1').get());
    });

    // Este test afirmaba `assertSucceeds(...doc('user2').get())`, es decir, que
    // cualquier autenticado puede leer el perfil de cualquier otro: correo,
    // telefono y fcm_token incluidos. Las reglas lo deniegan correctamente
    // (`allow read: if isOwner(userId) || isAdmin()`), asi que el test estaba
    // fijando un IDOR que no existe. El perfil publico de un taller vive en
    // `talleres`, proyectado por publishTallerProfile.
    it('should deny reading another user profile', async () => {
      await seedUser('user1', 'Propietario');
      await seedUser('user2', 'Propietario');
      const db = getAuthedDb('user1');
      await assertFails(db.collection('usuarios').doc('user2').get());
    });

    // Regresion del "Property rol is undefined on object": un create sin 'rol'
    // debe denegarse limpiamente, no reventar la evaluacion de la regla.
    it('should deny creating a profile with no rol', async () => {
      const db = getAuthedDb('user1');
      await assertFails(db.collection('usuarios').doc('user1').set({ foo: 'bar' }));
    });

    it('should deny self-registering a Mecanico as already approved', async () => {
      const db = getAuthedDb('mec1');
      await assertFails(
        db.collection('usuarios').doc('mec1').set({ rol: 'Mecanico', estado: 'activo' })
      );
      await assertSucceeds(
        db.collection('usuarios').doc('mec1').set({ rol: 'Mecanico', estado: 'pendiente' })
      );
    });

    it('should deny non-admins from changing their role', async () => {
      await seedUser('user1', 'Propietario');
      const db = getAuthedDb('user1');
      await assertFails(db.collection('usuarios').doc('user1').update({ rol: 'Administrador' }));
    });

    it('should deny Administrador from promoting a user to Administrador', async () => {
      await seedUser('admin1', 'Administrador');
      await seedUser('user1', 'Propietario');
      const db = getAuthedDb('admin1');
      await assertFails(
        db.collection('usuarios').doc('user1').update({ rol: 'Administrador' })
      );
    });

    it('should deny Administrador from promoting a user to Superusuario', async () => {
      await seedUser('admin1', 'Administrador');
      await seedUser('user1', 'Propietario');
      const db = getAuthedDb('admin1');
      await assertFails(
        db.collection('usuarios').doc('user1').update({ rol: 'Superusuario' })
      );
    });

    it('should allow Administrador to promote a user to Mecanico', async () => {
      await seedUser('admin1', 'Administrador');
      await seedUser('user1', 'Propietario');
      const db = getAuthedDb('admin1');
      await assertSucceeds(
        db.collection('usuarios').doc('user1').update({ rol: 'Mecanico' })
      );
    });

    it('should allow Superusuario to promote a user to Administrador', async () => {
      await seedUser('super1', 'Superusuario');
      await seedUser('user1', 'Propietario');
      const db = getAuthedDb('super1');
      await assertSucceeds(
        db.collection('usuarios').doc('user1').update({ rol: 'Administrador' })
      );
    });

    it('should allow Superusuario to promote a user to Superusuario', async () => {
      await seedUser('super1', 'Superusuario');
      await seedUser('user1', 'Propietario');
      const db = getAuthedDb('super1');
      await assertSucceeds(
        db.collection('usuarios').doc('user1').update({ rol: 'Superusuario' })
      );
    });

    it('should give Superusuario the same read/admin access as Administrador', async () => {
      await seedUser('super1', 'Superusuario');
      await seedUser('user1', 'Propietario');
      const db = getAuthedDb('super1');
      await assertSucceeds(db.collection('usuarios').doc('user1').get());
    });

    it('should deny Administrador from deleting a usuarios doc', async () => {
      await seedUser('admin1', 'Administrador');
      await seedUser('user1', 'Propietario');
      const db = getAuthedDb('admin1');
      await assertFails(db.collection('usuarios').doc('user1').delete());
    });

    it('should allow Superusuario to delete a usuarios doc', async () => {
      await seedUser('super1', 'Superusuario');
      await seedUser('user1', 'Propietario');
      const db = getAuthedDb('super1');
      await assertSucceeds(db.collection('usuarios').doc('user1').delete());
    });
  });

  describe('2. Mantenimientos & Historial (Propietario, Mecanico, Admin)', () => {
    it('should allow owner to read their vehicle maintenance', async () => {
      await seedUser('owner1', 'Propietario');
      await seedVehicle('veh1', 'owner1');
      const db = getAuthedDb('owner1');
      await assertSucceeds(db.collection('mantenimientos').doc('m1').set({ id_vehiculo: 'veh1' }));
    });

    it('should deny random user from reading maintenance', async () => {
      await seedUser('random1', 'Propietario');
      await seedVehicle('veh1', 'owner1');
      const db = getAuthedDb('random1');
      await assertFails(db.collection('mantenimientos').doc('m1').set({ id_vehiculo: 'veh1' }));
      await assertFails(db.collection('mantenimientos').doc('m1').get());
    });
    
    // Este test sembraba `seedUser('mec1','Mecanico')` sin 'estado' y un
    // vehiculo sin 'talleres_vinculados', y aun asi esperaba exito. Las reglas
    // lo denegaban con razon: isVinculadoAlVehiculo() exige las DOS cosas.
    // El test se habia quedado atras respecto a las reglas, no al reves.
    it('should allow a linked, approved mechanic to update maintenance', async () => {
      await seedUser('mec1', 'Mecanico', { estado: 'activo' });
      await seedVehicle('veh1', 'owner1', ['mec1']);
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('mantenimientos').doc('m1').set({ id_vehiculo: 'veh1' });
      });
      const db = getAuthedDb('mec1');
      await assertSucceeds(db.collection('mantenimientos').doc('m1').update({ status: 'done' }));
    });

    it('should deny a mechanic not linked to the vehicle', async () => {
      await seedUser('mec1', 'Mecanico', { estado: 'activo' });
      await seedVehicle('veh1', 'owner1');
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('mantenimientos').doc('m1').set({ id_vehiculo: 'veh1' });
      });
      const db = getAuthedDb('mec1');
      await assertFails(db.collection('mantenimientos').doc('m1').update({ status: 'done' }));
    });

    // El bloqueo del enrutador no basta: la API es accesible directamente, asi
    // que un taller pendiente de aprobacion no puede tocar datos aunque este
    // vinculado al vehiculo.
    it('should deny a linked but still pending mechanic', async () => {
      await seedUser('mec1', 'Mecanico', { estado: 'pendiente' });
      await seedVehicle('veh1', 'owner1', ['mec1']);
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('mantenimientos').doc('m1').set({ id_vehiculo: 'veh1' });
      });
      const db = getAuthedDb('mec1');
      await assertFails(db.collection('mantenimientos').doc('m1').update({ status: 'done' }));
    });
  });

  describe('3. Alertas', () => {
    it('should allow owner to read their alerts', async () => {
      await seedUser('owner1', 'Propietario');
      await seedVehicle('veh1', 'owner1');
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('alertas').doc('a1').set({ id_vehiculo: 'veh1' });
      });
      const db = getAuthedDb('owner1');
      await assertSucceeds(db.collection('alertas').doc('a1').get());
    });

    it('should allow admin to create alerts', async () => {
      await seedUser('admin1', 'Administrador');
      const db = getAuthedDb('admin1');
      await assertSucceeds(db.collection('alertas').doc('a2').set({ id_vehiculo: 'veh1' }));
    });
  });

  describe('4. Conversaciones', () => {
    it('should deny non-participants from reading conversation', async () => {
      await seedUser('random', 'Propietario');
      await seedConversation('conv1', 'owner1', 'mec1');
      const db = getAuthedDb('random');
      await assertFails(db.collection('conversaciones').doc('conv1').get());
    });

    it('should allow participants to read conversation and write messages', async () => {
      await seedUser('owner1', 'Propietario');
      await seedConversation('conv1', 'owner1', 'mec1');
      const db = getAuthedDb('owner1');
      await assertSucceeds(db.collection('conversaciones').doc('conv1').get());
      await assertSucceeds(db.collection('conversaciones').doc('conv1').collection('mensajes').doc('msg1').set({ text: 'hello' }));
    });
  });

  describe('5. Admin Logs & Notificaciones', () => {
    // Este test esperaba que NINGUN cliente pudiera escribir el log. Es la
    // postura correcta para una auditoria, pero no es la arquitectura actual:
    // AdminService._logAction escribe la entrada desde el cliente tras cada
    // accion de administracion, asi que denegarlo tumbaria el panel entero.
    // Lo que si se puede exigir, y ahora se exige, es que la entrada este
    // firmada por quien la escribe.
    it('should allow an admin to write a log entry signed with their own uid', async () => {
      await seedUser('admin1', 'Administrador');
      const db = getAuthedDb('admin1');
      await assertSucceeds(
        db.collection('admin_logs').doc('log1').set({ admin_uid: 'admin1', accion: 'APROBAR_USUARIO' })
      );
    });

    it('should deny an admin from signing a log entry as another admin', async () => {
      await seedUser('admin1', 'Administrador');
      await seedUser('admin2', 'Administrador');
      const db = getAuthedDb('admin1');
      await assertFails(
        db.collection('admin_logs').doc('log1').set({ admin_uid: 'admin2', accion: 'APROBAR_USUARIO' })
      );
    });

    it('should deny a log entry with no admin_uid at all', async () => {
      await seedUser('admin1', 'Administrador');
      const db = getAuthedDb('admin1');
      await assertFails(db.collection('admin_logs').doc('log1').set({ event: 'test' }));
    });

    it('should deny a non-admin from writing logs', async () => {
      await seedUser('user1', 'Propietario');
      const db = getAuthedDb('user1');
      await assertFails(db.collection('admin_logs').doc('log1').set({ admin_uid: 'user1' }));
    });

    it('should keep log entries immutable once written', async () => {
      await seedUser('admin1', 'Administrador');
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('admin_logs').doc('log1').set({ admin_uid: 'admin1' });
      });
      const db = getAuthedDb('admin1');
      await assertFails(db.collection('admin_logs').doc('log1').update({ accion: 'otra cosa' }));
      await assertFails(db.collection('admin_logs').doc('log1').delete());
    });

    it('should allow admin to read admin_logs', async () => {
      await seedUser('admin1', 'Administrador');
      const db = getAuthedDb('admin1');
      await assertSucceeds(db.collection('admin_logs').doc('log1').get());
    });

    it('should deny non-admin reading admin_logs', async () => {
      await seedUser('user1', 'Propietario');
      const db = getAuthedDb('user1');
      await assertFails(db.collection('admin_logs').doc('log1').get());
    });

    it('should allow user to read their own notifications but deny create', async () => {
      await seedUser('user1', 'Propietario');
      const db = getAuthedDb('user1');
      await assertSucceeds(db.collection('notificaciones').doc('user1').collection('items').doc('n1').get());
      await assertFails(db.collection('notificaciones').doc('user1').collection('items').doc('n2').set({ test: 'x' }));
    });
  });

  describe('6b. Resenias — reply permissions', () => {
    async function seedResenia(id, ownerUid, tallerUid) {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await db.collection('resenias').doc(id).set({
          id_resenia: id,
          id_usuario: ownerUid,
          id_taller: tallerUid,
          id_servicio: 'servicio1',
          estrellas: 5,
          comentario: 'Buen trabajo',
        });
      });
    }

    it('allows the taller owner to reply', async () => {
      await seedResenia('r1', 'owner1', 'taller1');
      await seedUser('taller1', 'Taller');
      const db = getAuthedDb('taller1');
      await assertSucceeds(
        db.collection('resenias').doc('r1').update({
          respuesta_taller: { texto: 'Gracias!', fecha: new Date() },
        })
      );
    });

    it('denies a random authenticated user from replying', async () => {
      await seedResenia('r2', 'owner1', 'taller1');
      await seedUser('random1', 'Propietario');
      const db = getAuthedDb('random1');
      await assertFails(
        db.collection('resenias').doc('r2').update({
          respuesta_taller: { texto: 'Gracias!', fecha: new Date() },
        })
      );
    });

    it('allows a taller employee sub-account to reply on behalf of the owner', async () => {
      await seedResenia('r3', 'owner1', 'taller1');
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('usuarios').doc('empleado1').set({
          id_usuario: 'empleado1',
          nombre_completo: 'Empleado Uno',
          correo: 'empleado1@test.com',
          rol: 'Mecanico',
          id_taller_propietario: 'taller1',
        });
      });
      const db = getAuthedDb('empleado1');
      await assertSucceeds(
        db.collection('resenias').doc('r3').update({
          respuesta_taller: { texto: 'Gracias!', fecha: new Date() },
        })
      );
    });
  });

  describe('verificaciones/{tallerId}', () => {

    // El expediente ya resuelto por un admin, sembrado saltandose las reglas.
    async function seedExpediente(tallerId, extra) {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('verificaciones').doc(tallerId).set(
          Object.assign({ id_taller: tallerId, estado_verificacion: 'listo_para_revision' }, extra || {})
        );
      });
    }

    it('deja al taller crear su propio expediente y enviarlo a revision', async () => {
      await seedUser('taller1', 'Taller');
      await assertSucceeds(
        getAuthedDb('taller1').collection('verificaciones').doc('taller1').set({
          id_taller: 'taller1',
          estado_verificacion: 'listo_para_revision',
          documentos: { fachada: new Date() },
        })
      );
    });

    it('impide que un taller se autoverifique escribiendo aprobada', async () => {
      await seedUser('taller1', 'Taller');
      await assertFails(
        getAuthedDb('taller1').collection('verificaciones').doc('taller1').set({
          id_taller: 'taller1',
          estado_verificacion: 'aprobada',
        })
      );
    });

    it('impide que un taller se ponga en_revision (tomar el caso es de admin)', async () => {
      await seedUser('taller1', 'Taller');
      await assertFails(
        getAuthedDb('taller1').collection('verificaciones').doc('taller1').set({
          id_taller: 'taller1',
          estado_verificacion: 'en_revision',
        })
      );
    });

    it('impide que un taller se invente un motivo_rechazo o un revisado_por', async () => {
      await seedUser('taller1', 'Taller');
      for (const campo of ['motivo_rechazo', 'revisado_por', 'fecha_revision']) {
        const payload = {
          id_taller: 'taller1',
          estado_verificacion: 'listo_para_revision',
        };
        payload[campo] = campo === 'fecha_revision' ? new Date() : 'inventado';
        await assertFails(
          getAuthedDb('taller1').collection('verificaciones').doc('taller1').set(payload)
        );
      }
    });

    it('deja al taller LIMPIAR el motivo de rechazo al reenviar', async () => {
      await seedUser('taller1', 'Taller');
      await seedExpediente('taller1', {
        estado_verificacion: 'rechazada',
        motivo_rechazo: 'La foto no es legible',
        revisado_por: 'admin1',
      });
      // set() sin merge reemplaza el documento entero: el resultado ya no
      // contiene los campos de resolucion, que es lo que la regla exige.
      await assertSucceeds(
        getAuthedDb('taller1').collection('verificaciones').doc('taller1').set({
          id_taller: 'taller1',
          estado_verificacion: 'listo_para_revision',
          documentos: { fachada: new Date() },
        })
      );
    });

    it('impide que un taller toque el expediente de otro', async () => {
      await seedUser('taller1', 'Taller');
      await seedUser('taller2', 'Taller');
      await seedExpediente('taller2');
      await assertFails(
        getAuthedDb('taller1').collection('verificaciones').doc('taller2').set({
          id_taller: 'taller2',
          estado_verificacion: 'listo_para_revision',
        })
      );
    });

    it('impide que un taller LEA el expediente de otro', async () => {
      await seedUser('taller1', 'Taller');
      await seedExpediente('taller2');
      await assertFails(
        getAuthedDb('taller1').collection('verificaciones').doc('taller2').get()
      );
    });

    it('nunca es de lectura anonima, al reves que talleres/', async () => {
      await seedExpediente('taller1');
      await assertFails(
        getUnauthedDb().collection('verificaciones').doc('taller1').get()
      );
    });

    it('deja al admin leer y resolver el expediente', async () => {
      await seedUser('admin1', 'Administrador');
      await seedExpediente('taller1');
      const db = getAuthedDb('admin1');
      await assertSucceeds(db.collection('verificaciones').doc('taller1').get());
      await assertSucceeds(
        db.collection('verificaciones').doc('taller1').update({
          estado_verificacion: 'rechazada',
          motivo_rechazo: 'La direccion no coincide',
          revisado_por: 'admin1',
          fecha_revision: new Date(),
        })
      );
    });

    it('solo el admin borra el expediente', async () => {
      await seedUser('taller1', 'Taller');
      await seedExpediente('taller1');
      await assertFails(
        getAuthedDb('taller1').collection('verificaciones').doc('taller1').delete()
      );
    });
  });

});
