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
  async function seedUser(uid, rol) {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.collection('usuarios').doc(uid).set({
        id_usuario: uid,
        nombre_completo: `Test User ${rol}`,
        correo: `test${uid}@test.com`,
        rol: rol
      });
    });
  }

  async function seedVehicle(vehiculoId, ownerId) {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.collection('vehiculos').doc(vehiculoId).set({
        id_vehiculo: vehiculoId,
        id_propietario: ownerId,
        placa: 'TEST123'
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

    it('should allow authenticated users to read and create their own profile', async () => {
      const db = getAuthedDb('user1');
      await assertSucceeds(db.collection('usuarios').doc('user1').set({ foo: 'bar' }));
      await assertSucceeds(db.collection('usuarios').doc('user1').get());
      await assertSucceeds(db.collection('usuarios').doc('user2').get());
    });

    it('should deny non-admins from changing their role', async () => {
      await seedUser('user1', 'Propietario');
      const db = getAuthedDb('user1');
      await assertFails(db.collection('usuarios').doc('user1').update({ rol: 'Administrador' }));
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
    
    it('should allow mechanic to update maintenance', async () => {
      await seedUser('mec1', 'Mecanico');
      await seedVehicle('veh1', 'owner1');
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('mantenimientos').doc('m1').set({ id_vehiculo: 'veh1' });
      });
      const db = getAuthedDb('mec1');
      await assertSucceeds(db.collection('mantenimientos').doc('m1').update({ status: 'done' }));
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
    it('should deny writing to admin_logs from any client (even admin)', async () => {
      await seedUser('admin1', 'Administrador');
      const db = getAuthedDb('admin1');
      await assertFails(db.collection('admin_logs').doc('log1').set({ event: 'test' }));
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

});
