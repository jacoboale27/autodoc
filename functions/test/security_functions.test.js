'use strict';
const assert = require('assert');
const fs = require('fs');
const vm = require('vm');

// Execute actual callable bodies with ephemeral Auth/Firestore fixtures only.
describe('SEC-01 / SEC-03', () => {
  let api, records, accounts, writes, resetFailure;
  const owner = { auth: { uid: 'owner' } };
  const root = { auth: { uid: 'root' } };
  const input = { correo: 'new@example.test', nombreCompleto: 'New', rol: 'Administrador' };
  beforeEach(() => {
    records = new Map([
      ['usuarios/root', { rol: 'Superusuario' }],
      ['usuarios/owner', { rol: 'Propietario' }],
      ['usuarios/recipient', { rol: 'Propietario' }],
      ['vehiculos/car', { id_propietario: 'owner', shared_with: [] }],
    ]);
    accounts = new Map(); writes = []; resetFailure = false;
    const ref = path => ({
      path,
      get: async () => ({ exists: records.has(path), data: () => records.get(path) }),
      set: async value => { records.set(path, value); writes.push(value); },
      update: async value => { records.set(path, { ...records.get(path), ...value }); writes.push(value); },
      delete: async () => records.delete(path),
    });
    let queue = Promise.resolve();
    const db = {
      collection: name => ({
        doc: id => ref(`${name}/${id}`),
        where: () => ({ limit: () => ({ get: async () => ({ empty: false, docs: [{ id: 'recipient', data: () => ({ rol: 'Propietario', correo: 'found@example.test', nombre_completo: 'PRIVATE' }) }] }) }) }),
      }),
      runTransaction: task => {
        const run = queue.then(() => task({ get: r => r.get(), set: (r,v) => r.set(v), update: (r,v) => r.update(v) }));
        queue = run.catch(() => {}); return run;
      },
    };
    const auth = {
      createUser: async value => { accounts.set('new', value); return { uid: 'new' }; },
      deleteUser: async uid => accounts.delete(uid),
      getUser: async uid => ({ uid, email: uid === 'recipient' ? 'found@example.test' : 'new@example.test', emailVerified: true, metadata: {}, ...accounts.get(uid) }),
      updateUser: async (uid, value) => accounts.set(uid, { ...accounts.get(uid), ...value }),
      revokeRefreshTokens: async () => {},
      generatePasswordResetLink: async () => { if (resetFailure) throw new Error('SECRET_LINK'); return 'https://example.test/reset?oobCode=SECRET'; },
    };
    const admin = { auth: () => auth, firestore: { Timestamp: { now: () => 123 } } };
    const functions = { https: { onCall: fn => fn, HttpsError: class extends Error { constructor(code,msg) { super(msg); this.code = code; } } } };
    const source = fs.readFileSync(require.resolve('../index.js'), 'utf8').replace(/\r\n/g, '\n');
    let selected = source.slice(source.indexOf('async function assertSuperUser'), source.indexOf('/**\n * Elimina una cuenta de forma permanente'));
    const lookup = source.indexOf('exports.buscarPropietarioPorCorreo');
    selected += '\n' + source.slice(lookup, source.indexOf('/**\n * 13.', lookup));
    // El harness evalua un RECORTE del fuente, asi que los `require` de la
    // cabecera de index.js no entran en el sandbox: las dependencias que use
    // el trozo recortado hay que inyectarlas aqui. `exigirAppCheck` es la de
    // SEC-04, y se inyecta la de verdad —no un doble— para que estos tests
    // corran contra el mismo guard que produccion.
    const { exigirAppCheck } = require('../src/appCheck');
    const sandbox = {
      exports: {}, admin, db, functions, require, console, Date, Buffer, exigirAppCheck,
    };
    vm.runInNewContext(selected, sandbox); api = sandbox.exports;
  });
  it('creates an account without a shared password and returns only a manual invitation', async () => {
    const result = await api.superUserCreateAccount(input, root);
    assert.ok(!accounts.get('new').password);
    assert.strictEqual(result.passwordTemporal, undefined);
    assert.strictEqual(result.enlaceInvitacion, 'https://example.test/reset?oobCode=SECRET');
    assert.ok(!JSON.stringify(writes).includes('SECRET'));
  });
  it('rolls back Auth if invitation generation fails without exposing the link', async () => {
    resetFailure = true;
    await assert.rejects(() => api.superUserCreateAccount(input, root), e => e.code === 'internal' && !e.message.includes('SECRET'));
    assert.strictEqual(accounts.size, 0);
  });
  it('rejects unprivileged account creation', async () => {
    await assert.rejects(() => api.superUserCreateAccount(input, owner), e => e.code === 'permission-denied');
  });
  it('regenerates invitations by rotating an unknown credential before issuing a link', async () => {
    await api.superUserCreateAccount(input, root);
    await api.superUserRegenerateInvitation({ uid: 'new' }, root);
    const first = accounts.get('new').password;
    assert.ok(first.length >= 32);
    const result = await api.superUserRegenerateInvitation({ uid: 'new' }, root);
    assert.notStrictEqual(accounts.get('new').password, first);
    assert.ok(!JSON.stringify(result).includes(first));
    assert.ok(!JSON.stringify(writes).includes(first));
  });
  it('does not resolve arbitrary emails or grant access before consent', async () => {
    for (const correo of ['found@example.test', 'missing@example.test']) {
      const result = await api.buscarPropietarioPorCorreo({ vehicleId: 'car', correo }, owner);
      assert.strictEqual(result.estado, 'pendiente');
      assert.deepStrictEqual(Object.keys(result).sort(), ['codigoInvitacion', 'estado']);
      assert.strictEqual(result.codigoInvitacion.length, 64);
    }
    assert.deepStrictEqual(records.get('vehiculos/car').shared_with, []);
  });
  it('limits concurrent attempts per caller, across target emails', async () => {
    const results = await Promise.allSettled(Array.from({ length: 12 }, (_, i) => api.buscarPropietarioPorCorreo({ vehicleId: 'car', correo: `p${i}@example.test` }, owner)));
    assert.strictEqual(results.filter(r => r.status === 'fulfilled').length, 10);
    assert.ok(results.filter(r => r.status === 'rejected').every(r => r.reason.code === 'resource-exhausted'));
  });
  it('requires the verified recipient consent and prevents replay', async () => {
    const invitation = await api.buscarPropietarioPorCorreo({ vehicleId: 'car', correo: 'found@example.test' }, owner);
    await assert.rejects(() => api.aceptarInvitacionVehiculo(invitation, owner), e => e.code === 'permission-denied');
    await api.aceptarInvitacionVehiculo(invitation, { auth: { uid: 'recipient' } });
    assert.ok(records.get('vehiculos/car').shared_with.includes('recipient'));
    await assert.rejects(() => api.aceptarInvitacionVehiculo(invitation, { auth: { uid: 'recipient' } }), e => e.code === 'failed-precondition');
  });
  it('rejects requests from non owners', async () => {
    await assert.rejects(() => api.buscarPropietarioPorCorreo({ vehicleId: 'car', correo: 'found@example.test' }, root), e => e.code === 'permission-denied');
  });
  it('rejects expired requests and ownership changes without granting access', async () => {
    const invitation = await api.buscarPropietarioPorCorreo({ vehicleId: 'car', correo: 'found@example.test' }, owner);
    const stored = [...records.entries()].find(([key]) => key.startsWith('solicitudesCompartir/'))[1];
    stored.expira = 0;
    await assert.rejects(() => api.aceptarInvitacionVehiculo(invitation, { auth: { uid: 'recipient' } }), e => e.code === 'failed-precondition');
    stored.expira = Date.now() + 10000;
    records.get('vehiculos/car').id_propietario = 'someone-else';
    await assert.rejects(() => api.aceptarInvitacionVehiculo(invitation, { auth: { uid: 'recipient' } }), e => e.code === 'failed-precondition');
    assert.deepStrictEqual(records.get('vehiculos/car').shared_with, []);
  });
  it('does not regenerate for accounts outside the invitation flow', async () => {
    records.set('usuarios/legacy', { rol: 'Administrador' });
    await assert.rejects(() => api.superUserRegenerateInvitation({ uid: 'legacy' }, root), e => e.code === 'failed-precondition');
  });
  it('serializes regeneration so concurrent admins cannot receive superseded links', async () => {
    await api.superUserCreateAccount(input, root);
    const results = await Promise.allSettled([
      api.superUserRegenerateInvitation({ uid: 'new' }, root),
      api.superUserRegenerateInvitation({ uid: 'new' }, root),
    ]);
    assert.strictEqual(results.filter(r => r.status === 'fulfilled').length, 1);
    assert.strictEqual(results.find(r => r.status === 'rejected').reason.code, 'aborted');
  });
});

