# Rol "Superusuario" Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `Superusuario` role above `Administrador` in AutoDoc's role hierarchy, with exclusive powers to create Administrador/Superusuario accounts, manually provision any user account without losing session, and permanently (hard) delete accounts.

**Architecture:** Firestore `usuarios.rol` gets a new allowed value (`'Superusuario'`), enforced both in `firestore.rules` (client-side authorization) and in two new Firebase Functions v1 callables that use the Admin SDK to create/delete Auth accounts server-side (mirroring the existing `crearEmpleadoTaller`/`desactivarEmpleadoTaller` pattern) so a Superusuario's own session is never disturbed. Flutter's admin panel (Clean Architecture + Provider) gets a role getter on `UserModel`, two new `AdminService`/`AdminProvider` methods that call the callables, and UI changes gated on `isSuperUser`.

**Tech Stack:** Flutter + Provider (client), Firebase Functions v1 (`firebase-functions` + `firebase-admin`, Node), Firestore + `firestore.rules`, `cloud_functions` package for callable invocation, Mockito-generated mocks for Dart unit tests, `@firebase/rules-unit-testing` + Mocha for rules tests.

## Global Constraints

- Firebase Functions SDK is v1 (`functions.https.onCall`, `functions.https.HttpsError`) — do not introduce v2 (`firebase-functions/v2/*`) syntax; it doesn't match the rest of `functions/index.js`.
- New Auth accounts created by a Superusuario get a fixed generic temporary password (`AutoDoc2026*`), never a Superusuario-supplied one — per user decision, the new user resets it later via the existing "Olvidé mi contraseña" flow. No password field goes in the creation dialog.
- Hard delete (`superUserDeleteAccount`) is exclusive to `Superusuario` — `Administrador` must never be able to trigger it, in rules, in the callable, or in the UI.
- `Administrador` must never be able to assign the `Administrador` or `Superusuario` role to any account (creation or role-change) — only `Superusuario` can.
- All new UI copy is Spanish, matching the existing hardcoded-string style in `admin_usuarios_screen.dart` (no new l10n keys required).
- Every new/modified Dart file must pass `flutter analyze --no-fatal-infos` and `dart format --output=none --set-exit-if-changed .`.
- Every new Cloud Function must reuse the orphaned-Auth-account rollback pattern already established in `crearEmpleadoTaller` (`functions/index.js:1211-1228`) — never leave an Auth user without a matching Firestore doc.

---

## File Structure

| File | Change |
|---|---|
| `.agents/rules/tablas-firebase.md` | Modify: add `'Superusuario'` to the `Usuarios.rol` CHECK constraint. |
| `firestore.rules` | Modify: `isAdmin()` includes `Superusuario`; new `isSuperUser()` helper; `usuarios` update rule blocks Administrador from setting `rol` to `Administrador`/`Superusuario`; `usuarios` delete restricted to `isSuperUser()`. |
| `test/firestore_rules/rules.test.js` | Modify: add tests for the new rules behavior. |
| `lib/core/models/user_model.dart` | Modify: add `bool get isSuperUser`. |
| `test/core/models/user_model_test.dart` | Modify: add test for `isSuperUser`. |
| `functions/index.js` | Modify: add `assertSuperUser()` helper, `superUserCreateAccount`, `superUserDeleteAccount` callables. |
| `lib/features/admin/data/services/admin_service.dart` | Modify: inject `FirebaseFunctions`, add `crearUsuarioComoSuperUser()`, `eliminarUsuarioPermanente()`. |
| `test/features/admin/data/services/admin_service_test.dart` | Modify: add error-path tests for the two new methods. |
| `lib/features/admin/presentation/providers/admin_provider.dart` | Modify: inject `AdminService`, add `crearUsuario()`, `eliminarUsuarioPermanente()`. |
| `test/features/admin/presentation/providers/admin_provider_test.dart` | Create: new test file for the two new provider methods. |
| `lib/features/admin/presentation/widgets/account_row.dart` | Modify: fix pre-existing `cambiar_rol`/`rol` value mismatch, add `onEliminar` + `canHardDelete` for the hard-delete menu item. |
| `lib/features/admin/presentation/widgets/dialog_crear_usuario.dart` | Create: modal form (nombre, correo, rol dropdown) that calls `AdminProvider.crearUsuario`. |
| `lib/features/admin/presentation/pages/admin_usuarios_screen.dart` | Modify: role-hierarchy-aware dropdown, `Superusuario` filter chip/desc, FAB gated on `isSuperUser`, hard-delete confirmation dialog. |

---

## Task 1: Schema doc + Firestore rules for the role hierarchy

**Files:**
- Modify: `.agents/rules/tablas-firebase.md:10`
- Modify: `firestore.rules:22-27` (helpers), `firestore.rules:92-141` (`usuarios` match block)
- Test: `test/firestore_rules/rules.test.js`

**Interfaces:**
- Produces: `isSuperUser()` rules helper (used nowhere else yet, but is the foundation later tasks rely on for the callables' equivalent server-side check — same semantics: `rol == 'Superusuario'`).
- Produces: `isAdmin()` now returns `true` for `Superusuario` too — every existing `isAdmin()`-gated collection (talleres, servicios, vehiculos, reparaciones, admin_logs, etc.) automatically grants Superusuario the same access Administrador has, satisfying the "Superusuario can do everything Administrador can" requirement without touching those other match blocks.

- [ ] **Step 1: Update the schema doc CHECK constraint**

In `.agents/rules/tablas-firebase.md`, change line 10 from:
```sql
rol VARCHAR(20) CHECK (rol IN ('Propietario', 'Administrador', 'Mecanico')),
```
to:
```sql
rol VARCHAR(20) CHECK (rol IN ('Propietario', 'Administrador', 'Mecanico', 'Superusuario')),
```

- [ ] **Step 2: Write the failing rules tests**

Add to `test/firestore_rules/rules.test.js`, inside `describe('1. Usuarios Collection', ...)` (after the existing `'should deny non-admins from changing their role'` test, before its closing `});` at line 87):

```js
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
```

- [ ] **Step 3: Run the rules tests to verify they fail**

Run:
```bash
cd test/firestore_rules
pnpm install --frozen-lockfile
pnpm test
```
Expected: the 8 new tests FAIL (rules not yet updated — `Superusuario` isn't recognized, delete is still allowed for Administrador).

- [ ] **Step 4: Update `isAdmin()` and add `isSuperUser()`**

In `firestore.rules`, replace lines 22-27:
```
    // Verifica si el usuario actual tiene rol de Administrador
    function isAdmin() {
      return isAuthenticated() &&
        exists(/databases/$(database)/documents/usuarios/$(request.auth.uid)) &&
        getUserData().rol in ['Administrador', 'admin'];
    }
```
with:
```
    // Verifica si el usuario actual tiene rol de Administrador o Superusuario
    // (Superusuario hereda todos los permisos de Administrador en cualquier
    // regla que use isAdmin(); sus permisos EXCLUSIVOS, como crear
    // Administradores o hacer hard-delete de cuentas, se controlan aparte
    // con isSuperUser()).
    function isAdmin() {
      return isAuthenticated() &&
        exists(/databases/$(database)/documents/usuarios/$(request.auth.uid)) &&
        getUserData().rol in ['Administrador', 'admin', 'Superusuario'];
    }

    // Verifica si el usuario actual tiene rol de Superusuario, el nivel por
    // encima de Administrador (crear Administradores/Superusuarios, hard
    // delete de cuentas).
    function isSuperUser() {
      return isAuthenticated() &&
        exists(/databases/$(database)/documents/usuarios/$(request.auth.uid)) &&
        getUserData().rol == 'Superusuario';
    }
```

- [ ] **Step 5: Restrict role-escalation and delete on the `usuarios` match block**

In `firestore.rules`, replace lines 136-140:
```
      allow update: if (isOwner(userId) && !request.resource.data.diff(resource.data)
                          .affectedKeys().hasAny(['rol', 'calificacion_promedio', 'total_resenias', 'estado', 'id_taller_propietario', 'suma_estrellas']))
                    || isAdmin();
      
      allow delete: if isAdmin();
```
with:
```
      // Un Administrador conserva acceso total salvo para asignar el propio
      // rol 'Administrador' o 'Superusuario': eso queda exclusivo de
      // isSuperUser(). Solo se bloquea cuando el update efectivamente toca
      // 'rol' Y el valor resultante es uno de esos dos — así un Administrador
      // sigue pudiendo aprobar/suspender/reasignar a Propietario/Mecanico
      // sin restricciones nuevas.
      allow update: if (isOwner(userId) && !request.resource.data.diff(resource.data)
                          .affectedKeys().hasAny(['rol', 'calificacion_promedio', 'total_resenias', 'estado', 'id_taller_propietario', 'suma_estrellas']))
                    || isSuperUser()
                    || (isAdmin() && !(
                         request.resource.data.diff(resource.data).affectedKeys().hasAny(['rol']) &&
                         request.resource.data.rol in ['Administrador', 'Superusuario']
                       ));

      // Hard delete de cuentas es exclusivo de Superusuario (ver
      // superUserDeleteAccount en functions/index.js, que además borra la
      // cuenta de Firebase Auth vía Admin SDK — este delete de Firestore
      // por sí solo nunca lo hace).
      allow delete: if isSuperUser();
```

- [ ] **Step 6: Run the rules tests to verify they pass**

Run:
```bash
cd test/firestore_rules
pnpm test
```
Expected: PASS for all tests, including the 8 new ones.

- [ ] **Step 7: Commit**

```bash
git add .agents/rules/tablas-firebase.md firestore.rules test/firestore_rules/rules.test.js
git commit -m "feat: add Superusuario role to schema and firestore.rules"
```

---

## Task 2: `UserModel.isSuperUser` getter

**Files:**
- Modify: `lib/core/models/user_model.dart:38-43` (add getter next to `idTallerEfectivo`)
- Test: `test/core/models/user_model_test.dart`

**Interfaces:**
- Produces: `UserModel.isSuperUser` (`bool`, computed from `rol == 'Superusuario'`) — consumed by Task 6 (`admin_usuarios_screen.dart`) to gate the FAB and role-dropdown options.

- [ ] **Step 1: Write the failing test**

Add to `test/core/models/user_model_test.dart`, inside `group('UserModel Tests', ...)`:

```dart
    test('isSuperUser is true only when rol is Superusuario', () {
      final superUser = UserModel(
        idUsuario: '1',
        nombreCompleto: 'n',
        correo: 'c',
        rol: 'Superusuario',
        fechaRegistro: DateTime(2023, 1, 1),
      );
      final admin = UserModel(
        idUsuario: '2',
        nombreCompleto: 'n',
        correo: 'c',
        rol: 'Administrador',
        fechaRegistro: DateTime(2023, 1, 1),
      );
      expect(superUser.isSuperUser, isTrue);
      expect(admin.isSuperUser, isFalse);
    });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/models/user_model_test.dart`
Expected: FAIL with "The getter 'isSuperUser' isn't defined for the class 'UserModel'".

- [ ] **Step 3: Add the getter**

In `lib/core/models/user_model.dart`, insert after the `idTallerEfectivo` getter (after line 43, before the `UserModel({` constructor on line 45):

```dart

  /// El nivel de rol más alto en AutoDoc, por encima de 'Administrador':
  /// puede crear cuentas de Administrador/Superusuario y eliminar cuentas
  /// de forma permanente (ver superUserCreateAccount/superUserDeleteAccount
  /// en functions/index.js y las reglas isSuperUser() en firestore.rules).
  bool get isSuperUser => rol == 'Superusuario';
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/core/models/user_model_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/models/user_model.dart test/core/models/user_model_test.dart
git commit -m "feat: add UserModel.isSuperUser getter"
```

---

## Task 3: Cloud Functions `superUserCreateAccount` and `superUserDeleteAccount`

**Files:**
- Modify: `functions/index.js` (insert after `desactivarEmpleadoTaller`, i.e. after line 1309, before the `exports.publishTallerProfile` line)

**Interfaces:**
- Consumes: `db` (`admin.firestore()`), `admin`, `functions` — already initialized at the top of `functions/index.js`.
- Produces: callable `superUserCreateAccount({ correo, nombreCompleto, rol })` → `{ idUsuario: string, passwordTemporal: string }`. Only accepts `rol` in `['Propietario', 'Mecanico', 'Administrador']` — creating another `Superusuario` account is intentionally NOT exposed through this callable (too high-privilege for a form; would need direct Firestore/Auth console access), matching the original spec's dialog role list.
- Produces: callable `superUserDeleteAccount({ uid })` → `{ ok: true }`. Deletes the Firebase Auth user; the existing `onUserDelete` trigger (`functions/index.js:767-802`, unchanged) handles cascading Firestore/Storage cleanup.
- Produces: local (non-exported) helper `assertSuperUser(uid)` — shared by both new callables, throws `HttpsError('permission-denied', ...)` unless `usuarios/{uid}.rol === 'Superusuario'`.

- [ ] **Step 1: Add the shared `assertSuperUser` helper and the two callables**

In `functions/index.js`, insert immediately after the `exports.desactivarEmpleadoTaller = ...});` block (after line 1309) and before `exports.publishTallerProfile = ...` (line 1311):

```js
/**
 * Verifica que `uid` tenga rol Superusuario en Firestore. Compartido por
 * superUserCreateAccount y superUserDeleteAccount: ambos requieren el mismo
 * nivel de privilegio (por encima de Administrador) y, como corren con
 * Admin SDK (bypassa firestore.rules), no pueden fiarse de ningún claim que
 * venga del cliente — solo del doc real en Firestore.
 */
async function assertSuperUser(uid) {
  const doc = await db.collection('usuarios').doc(uid).get();
  const rol = doc.exists ? doc.data().rol : null;
  if (rol !== 'Superusuario') {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Solo un Superusuario puede realizar esta acción.'
    );
  }
}

// Contraseña temporal fija para cuentas creadas manualmente por un
// Superusuario (decisión de producto: nunca pedirle al Superusuario que
// escriba/transmita una contraseña específica por usuario). El nuevo
// usuario debe cambiarla desde "Olvidé mi contraseña" en su primer login.
const SUPERUSER_TEMP_PASSWORD = 'AutoDoc2026*';

/**
 * Crea una cuenta (Auth + Firestore) en nombre de un Superusuario sin que
 * este pierda su propia sesión: FirebaseAuth.createUserWithEmailAndPassword
 * desde el cliente cerraría la sesión del Superusuario e iniciaría sesión
 * como el usuario recién creado (limitación conocida del SDK cliente). Al
 * crear la cuenta aquí con el Admin SDK, el cliente nunca cambia de sesión.
 * Mismo patrón de rollback que crearEmpleadoTaller: si el write de
 * Firestore falla, se borra el usuario de Auth para no dejarlo huérfano.
 */
exports.superUserCreateAccount = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Debes iniciar sesión.');
  }
  await assertSuperUser(context.auth.uid);

  const correo = (data && data.correo ? String(data.correo) : '').trim().toLowerCase();
  const nombreCompleto = (data && data.nombreCompleto ? String(data.nombreCompleto) : '').trim();
  const rol = data && data.rol ? String(data.rol) : '';

  if (!correo || !nombreCompleto) {
    throw new functions.https.HttpsError('invalid-argument', 'Correo y nombre son requeridos.');
  }
  // 'Superusuario' se excluye a propósito: crear otro Superusuario es
  // demasiado privilegiado para exponerlo en un formulario del panel.
  if (!['Propietario', 'Mecanico', 'Administrador'].includes(rol)) {
    throw new functions.https.HttpsError('invalid-argument', 'Rol inválido.');
  }

  let userRecord;
  try {
    userRecord = await admin.auth().createUser({
      email: correo,
      password: SUPERUSER_TEMP_PASSWORD,
      displayName: nombreCompleto,
    });
  } catch (err) {
    if (err && err.code === 'auth/email-already-exists') {
      throw new functions.https.HttpsError('already-exists', 'Ya existe una cuenta con ese correo.');
    }
    throw new functions.https.HttpsError('invalid-argument', err.message);
  }

  try {
    await db.collection('usuarios').doc(userRecord.uid).set({
      id_usuario: userRecord.uid,
      nombre_completo: nombreCompleto,
      correo,
      rol,
      estado: 'activo',
      fecha_registro: admin.firestore.Timestamp.now(),
    });
  } catch (err) {
    try {
      await admin.auth().deleteUser(userRecord.uid);
    } catch (cleanupErr) {
      console.error(
        `superUserCreateAccount: fallo al hacer rollback del usuario Auth huerfano ${userRecord.uid}:`,
        cleanupErr
      );
    }
    throw new functions.https.HttpsError(
      'internal',
      'No se pudo completar el registro. Intenta de nuevo.'
    );
  }

  return { idUsuario: userRecord.uid, passwordTemporal: SUPERUSER_TEMP_PASSWORD };
});

/**
 * Elimina una cuenta de forma permanente (Auth + cascada de Firestore/
 * Storage vía el trigger onUserDelete existente). Exclusivo de Superusuario:
 * ni firestore.rules (isSuperUser() en el delete de 'usuarios') ni este
 * callable lo permiten a un Administrador. No se puede auto-eliminar ni
 * eliminar a otro Superusuario (evita que una cuenta comprometida borre a
 * las demás cuentas de máximo privilegio).
 */
exports.superUserDeleteAccount = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Debes iniciar sesión.');
  }
  await assertSuperUser(context.auth.uid);

  const targetUid = data && data.uid ? String(data.uid) : '';
  if (!targetUid) {
    throw new functions.https.HttpsError('invalid-argument', 'uid es requerido.');
  }
  if (targetUid === context.auth.uid) {
    throw new functions.https.HttpsError('failed-precondition', 'No puedes eliminar tu propia cuenta.');
  }

  const targetDoc = await db.collection('usuarios').doc(targetUid).get();
  if (targetDoc.exists && targetDoc.data().rol === 'Superusuario') {
    throw new functions.https.HttpsError(
      'permission-denied',
      'No puedes eliminar la cuenta de otro Superusuario.'
    );
  }

  try {
    await admin.auth().deleteUser(targetUid);
  } catch (err) {
    if (err && err.code === 'auth/user-not-found') {
      throw new functions.https.HttpsError('not-found', 'La cuenta ya no existe.');
    }
    throw new functions.https.HttpsError('internal', err.message);
  }

  return { ok: true };
});
```

- [ ] **Step 2: Lint**

Run: `cd functions && npm run lint`
Expected: no new errors from the added code.

- [ ] **Step 3: Manual verification via emulator (no automated Cloud Functions test harness exists in this repo)**

Run:
```bash
firebase emulators:start --only functions,firestore,auth
```
In a separate shell, use `firebase functions:shell` or the emulator UI to:
1. Seed a `usuarios/{uid}` doc with `rol: 'Superusuario'`, `firebase.auth().createUser` a matching Auth user, and call `superUserCreateAccount({ correo: 'nuevo@test.com', nombreCompleto: 'Nuevo', rol: 'Mecanico' })` as that uid — confirm it returns `{ idUsuario, passwordTemporal: 'AutoDoc2026*' }` and that both an Auth user and a `usuarios/{idUsuario}` doc with `rol: 'Mecanico'` now exist.
2. Call it again as a `rol: 'Administrador'` uid — confirm `permission-denied`.
3. Call `superUserCreateAccount` with `rol: 'Superusuario'` — confirm `invalid-argument` (role not creatable via this callable).
4. Call `superUserDeleteAccount({ uid: idUsuario })` as the Superusuario — confirm the Auth user and `usuarios/{idUsuario}` doc are both gone (the latter via the existing `onUserDelete` trigger).
5. Call `superUserDeleteAccount({ uid: <own uid> })` — confirm `failed-precondition`.
6. Call `superUserDeleteAccount({ uid: <another Superusuario's uid> })` — confirm `permission-denied`.

- [ ] **Step 4: Commit**

```bash
git add functions/index.js
git commit -m "feat: add superUserCreateAccount and superUserDeleteAccount callables"
```

---

## Task 4: `AdminService` — call the new callables

**Files:**
- Modify: `lib/features/admin/data/services/admin_service.dart`
- Test: `test/features/admin/data/services/admin_service_test.dart`

**Interfaces:**
- Consumes: callable names `'superUserCreateAccount'` and `'superUserDeleteAccount'` from Task 3, with the exact payload/response shapes defined there.
- Produces: `AdminService.crearUsuarioComoSuperUser({required String nombreCompleto, required String correo, required String rol}) → Future<String>` (returns `passwordTemporal`). Consumed by Task 5.
- Produces: `AdminService.eliminarUsuarioPermanente(String uid) → Future<void>`. Consumed by Task 5.

- [ ] **Step 1: Write the failing tests**

Add to `test/features/admin/data/services/admin_service_test.dart`, at the top:
```dart
import 'package:mockito/mockito.dart';

import '../../../../helpers/test_helpers.mocks.dart';
```
(alongside the existing imports at the top of the file)

Then add, before the final closing `}` of `void main() { ... }`:
```dart
  group('Superusuario', () {
    test(
      'crearUsuarioComoSuperUser lanza cuando el callable falla',
      () async {
        final mockFunctions = MockFirebaseFunctions();
        when(
          mockFunctions.httpsCallable('superUserCreateAccount'),
        ).thenThrow(Exception('network error'));

        final service = AdminService(
          functions: mockFunctions,
          repository: _DummyAdminRepository(),
        );

        expect(
          () => service.crearUsuarioComoSuperUser(
            nombreCompleto: 'A',
            correo: 'a@x.com',
            rol: 'Propietario',
          ),
          throwsA(isA<Exception>()),
        );
      },
    );

    test(
      'eliminarUsuarioPermanente lanza cuando el callable falla',
      () async {
        final mockFunctions = MockFirebaseFunctions();
        when(
          mockFunctions.httpsCallable('superUserDeleteAccount'),
        ).thenThrow(Exception('network error'));

        final service = AdminService(
          functions: mockFunctions,
          repository: _DummyAdminRepository(),
        );

        expect(
          () => service.eliminarUsuarioPermanente('uid1'),
          throwsA(isA<Exception>()),
        );
      },
    );
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/admin/data/services/admin_service_test.dart`
Expected: FAIL — `AdminService` has no `functions` constructor parameter and no `crearUsuarioComoSuperUser`/`eliminarUsuarioPermanente` methods.

- [ ] **Step 3: Add `FirebaseFunctions` injection and the two methods**

In `lib/features/admin/data/services/admin_service.dart`, add the import at the top (after line 2, `import 'package:cloud_firestore/cloud_firestore.dart';`):
```dart
import 'package:cloud_functions/cloud_functions.dart';
```

Replace the class fields/constructor at lines 12-25:
```dart
class AdminService {
  final AdminRepository _repository;
  final FirebaseFirestore? _firestoreOverride;

  /// Se resuelve de forma perezosa (no en el constructor) para no forzar
  /// `FirebaseFirestore.instance` -y por tanto `Firebase.initializeApp()`-
  /// en tests que no pasan un `firestore` explícito y nunca llegan a usar
  /// `watchDashboardMetrics()`.
  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  AdminService({AdminRepository? repository, FirebaseFirestore? firestore})
    : _repository = repository ?? AdminRepository(),
      _firestoreOverride = firestore;
```
with:
```dart
class AdminService {
  final AdminRepository _repository;
  final FirebaseFirestore? _firestoreOverride;
  final FirebaseFunctions? _functionsOverride;

  /// Se resuelve de forma perezosa (no en el constructor) para no forzar
  /// `FirebaseFirestore.instance` -y por tanto `Firebase.initializeApp()`-
  /// en tests que no pasan un `firestore` explícito y nunca llegan a usar
  /// `watchDashboardMetrics()`.
  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  /// Mismo patrón perezoso que `_firestore`, para los callables de
  /// Superusuario (ver EmpleadoProvider._functions, mismo enfoque).
  FirebaseFunctions get _functions =>
      _functionsOverride ?? FirebaseFunctions.instance;

  AdminService({
    AdminRepository? repository,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _repository = repository ?? AdminRepository(),
       _firestoreOverride = firestore,
       _functionsOverride = functions;
```

Then add the two new methods at the end of the class, immediately before its closing `}`:
```dart

  // --- SUPERUSUARIO ---

  /// Crea una cuenta vía la Cloud Function `superUserCreateAccount` (Admin
  /// SDK, no cierra la sesión del Superusuario que llama). Devuelve la
  /// contraseña temporal genérica asignada, para mostrarla en la UI.
  Future<String> crearUsuarioComoSuperUser({
    required String nombreCompleto,
    required String correo,
    required String rol,
  }) async {
    final callable = _functions.httpsCallable('superUserCreateAccount');
    final result = await callable.call({
      'nombreCompleto': nombreCompleto,
      'correo': correo,
      'rol': rol,
    });
    return result.data['passwordTemporal'] as String;
  }

  /// Elimina una cuenta de forma permanente vía la Cloud Function
  /// `superUserDeleteAccount` (Auth + cascada de Firestore/Storage).
  Future<void> eliminarUsuarioPermanente(String uid) async {
    final callable = _functions.httpsCallable('superUserDeleteAccount');
    await callable.call({'uid': uid});
  }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/admin/data/services/admin_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/admin/data/services/admin_service.dart test/features/admin/data/services/admin_service_test.dart
git commit -m "feat: AdminService calls superUserCreateAccount/superUserDeleteAccount"
```

---

## Task 5: `AdminProvider` — expose the Superusuario actions to the UI

**Files:**
- Modify: `lib/features/admin/presentation/providers/admin_provider.dart`
- Test: `test/features/admin/presentation/providers/admin_provider_test.dart` (new)

**Interfaces:**
- Consumes: `AdminService.crearUsuarioComoSuperUser(...)` and `AdminService.eliminarUsuarioPermanente(uid)` from Task 4.
- Produces: `AdminProvider.crearUsuario({required String nombreCompleto, required String correo, required String rol}) → Future<bool>` (`true` on success, `false` on failure — mirrors `EmpleadoProvider.crearEmpleado`'s bool-return pattern so the calling dialog knows whether to close itself). Consumed by Task 7 (`DialogCrearUsuario`).
- Produces: `AdminProvider.eliminarUsuarioPermanente(String uid) → Future<void>`. Consumed by Task 8 (`admin_usuarios_screen.dart`).

- [ ] **Step 1: Write the failing tests**

Create `test/features/admin/presentation/providers/admin_provider_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:autodoc/features/admin/data/services/admin_service.dart';
import 'package:autodoc/features/admin/data/repositories/admin_repository.dart';
import 'package:autodoc/features/admin/presentation/providers/admin_provider.dart';

import '../../../../helpers/test_helpers.mocks.dart';

/// Repositorio dummy: crearUsuario/eliminarUsuarioPermanente nunca llegan a
/// tocarlo en el camino de error probado aquí (fallan antes, en el
/// callable), así que basta con no forzar Firebase.initializeApp() vía un
/// AdminRepository real (mismo enfoque que admin_service_test.dart).
class _DummyAdminRepository implements AdminRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'crearUsuario transiciona isLoading y expone error cuando el callable falla',
    () async {
      final mockFunctions = MockFirebaseFunctions();
      when(
        mockFunctions.httpsCallable('superUserCreateAccount'),
      ).thenThrow(Exception('network error'));

      final service = AdminService(
        functions: mockFunctions,
        repository: _DummyAdminRepository(),
      );
      final provider = AdminProvider(adminService: service);

      final loadingStates = <bool>[];
      provider.addListener(() => loadingStates.add(provider.isLoading));

      final result = await provider.crearUsuario(
        nombreCompleto: 'A',
        correo: 'a@x.com',
        rol: 'Propietario',
      );

      expect(result, false);
      expect(provider.isLoading, false);
      expect(provider.error, isNotNull);
      expect(loadingStates.first, true);
      expect(loadingStates.last, false);
    },
  );

  test(
    'eliminarUsuarioPermanente expone error cuando el callable falla',
    () async {
      final mockFunctions = MockFirebaseFunctions();
      when(
        mockFunctions.httpsCallable('superUserDeleteAccount'),
      ).thenThrow(Exception('network error'));

      final service = AdminService(
        functions: mockFunctions,
        repository: _DummyAdminRepository(),
      );
      final provider = AdminProvider(adminService: service);

      await provider.eliminarUsuarioPermanente('uid1');

      expect(provider.isLoading, false);
      expect(provider.error, isNotNull);
    },
  );
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/admin/presentation/providers/admin_provider_test.dart`
Expected: FAIL — `AdminProvider` has no `adminService`-named constructor parameter and no `crearUsuario`/`eliminarUsuarioPermanente` methods.

- [ ] **Step 3: Make `AdminService` injectable and add the two methods**

In `lib/features/admin/presentation/providers/admin_provider.dart`, replace line 10:
```dart
  final AdminService _adminService = AdminService();
```
with:
```dart
  final AdminService _adminService;
```
and replace the class opening on line 9 (`class AdminProvider with ChangeNotifier {`) plus that field to add a constructor immediately after it:
```dart
class AdminProvider with ChangeNotifier {
  final AdminService _adminService;

  AdminProvider({AdminService? adminService})
    : _adminService = adminService ?? AdminService();
```

Then add the two new methods at the end of the class, immediately before its closing `}` (after `fetchLogs()`, currently ending at line 269-270):
```dart

  // --- SUPERUSUARIO ---

  Future<bool> crearUsuario({
    required String nombreCompleto,
    required String correo,
    required String rol,
  }) async {
    _setLoading(true);
    try {
      final passwordTemporal = await _adminService.crearUsuarioComoSuperUser(
        nombreCompleto: nombreCompleto,
        correo: correo,
        rol: rol,
      );
      _setSuccess('Usuario creado. Contraseña temporal: $passwordTemporal');
      await fetchUsuarios();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> eliminarUsuarioPermanente(String uid) async {
    _setLoading(true);
    try {
      await _adminService.eliminarUsuarioPermanente(uid);
      _setSuccess('Cuenta eliminada permanentemente');
      await fetchUsuarios();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/admin/presentation/providers/admin_provider_test.dart`
Expected: PASS.

- [ ] **Step 5: Run the full existing admin test suite to check for regressions**

Run: `flutter test test/features/admin`
Expected: PASS (the `AdminProvider()` no-arg construction used elsewhere still works because `adminService` is optional).

- [ ] **Step 6: Commit**

```bash
git add lib/features/admin/presentation/providers/admin_provider.dart test/features/admin/presentation/providers/admin_provider_test.dart
git commit -m "feat: AdminProvider.crearUsuario and eliminarUsuarioPermanente"
```

---

## Task 6: `AccountRow` — fix role-change bug, add hard-delete action

**Files:**
- Modify: `lib/features/admin/presentation/widgets/account_row.dart`

**Interfaces:**
- Consumes: nothing new from earlier tasks — this is a leaf widget.
- Produces: `AccountRow(..., required bool canHardDelete, required VoidCallback onEliminar)` — new required constructor params consumed by Task 8 (`admin_usuarios_screen.dart`).

**Note:** `onSelected` (line 82-88) checks `value == 'rol'`, but the `PopupMenuItem` at line 114-118 emits `value: 'cambiar_rol'` — these never match, so "Cambiar Rol" is currently dead in the UI. This must be fixed as part of this task: Task 8's manual verification (testing that Administrador can't assign privileged roles) depends on this menu item actually working.

- [ ] **Step 1: Fix the `cambiar_rol` value mismatch and add the hard-delete menu item**

In `lib/features/admin/presentation/widgets/account_row.dart`, replace the whole class body (lines 5-124) with:
```dart
class AccountRow extends StatelessWidget {
  final UserModel usuario;
  final VoidCallback onAprobar;
  final VoidCallback onSuspender;
  final VoidCallback onReactivar;
  final VoidCallback onCambiarRol;
  final VoidCallback onEliminar;
  final bool isCurrentAdmin;
  final bool canHardDelete;

  const AccountRow({
    super.key,
    required this.usuario,
    required this.onAprobar,
    required this.onSuspender,
    required this.onReactivar,
    required this.onCambiarRol,
    required this.onEliminar,
    required this.isCurrentAdmin,
    required this.canHardDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(
          context,
        ).colorScheme.primary.withValues(alpha: 0.1),
        child: Text(
          usuario.nombreCompleto.isNotEmpty
              ? usuario.nombreCompleto[0].toUpperCase()
              : '?',
        ),
      ),
      title: Text(usuario.nombreCompleto),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(usuario.correo),
          Row(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 4, right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  usuario.rol.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: usuario.estado == 'activo'
                      ? Colors.green.withValues(alpha: 0.2)
                      : Colors.red.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  usuario.estado.toUpperCase(),
                  style: TextStyle(
                    color: usuario.estado == 'activo'
                        ? Colors.green[800]
                        : Colors.red[800],
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'aprobar') onAprobar();
          if (value == 'suspender') onSuspender();
          if (value == 'reactivar') onReactivar();
          if (value == 'cambiar_rol') onCambiarRol();
          if (value == 'eliminar') onEliminar();
        },
        itemBuilder: (context) => [
          if (usuario.estado != 'activo' && usuario.estado != 'suspendido')
            PopupMenuItem(
              value: 'aprobar',
              child: Text(
                context.l10n.adminApproveAccount,
                style: const TextStyle(color: Colors.green),
              ),
            ),
          if (usuario.estado == 'activo' && !isCurrentAdmin)
            PopupMenuItem(
              value: 'suspender',
              child: Text(
                context.l10n.adminSuspendAccount,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          if (usuario.estado == 'suspendido')
            PopupMenuItem(
              value: 'reactivar',
              child: Text(
                context.l10n.adminReactivateAccount,
                style: const TextStyle(color: Colors.green),
              ),
            ),
          if (!isCurrentAdmin)
            PopupMenuItem(
              value: 'cambiar_rol',
              child: Text(context.l10n.adminChangeUserRole),
            ),
          if (canHardDelete && !isCurrentAdmin && usuario.rol != 'Superusuario')
            const PopupMenuItem(
              value: 'eliminar',
              child: Text(
                'Eliminar cuenta (permanente)',
                style: TextStyle(color: Colors.red),
              ),
            ),
        ],
      ),
      isThreeLine: true,
    );
  }
}
```

- [ ] **Step 2: Update the existing call site so the widget still compiles**

`admin_usuarios_screen.dart` (line 345-381) constructs `AccountRow(...)` without `onEliminar`/`canHardDelete` yet — that's fixed in Task 8. For now, run:

Run: `flutter analyze --no-fatal-infos lib/features/admin`
Expected: an error on `admin_usuarios_screen.dart`'s `AccountRow(...)` call, missing required arguments `onEliminar` and `canHardDelete`. This is expected — Task 8 resolves it. Do not modify `admin_usuarios_screen.dart` in this task.

- [ ] **Step 3: Commit**

```bash
git add lib/features/admin/presentation/widgets/account_row.dart
git commit -m "fix: AccountRow cambiar_rol value mismatch; add hard-delete menu item"
```

---

## Task 7: `DialogCrearUsuario` widget

**Files:**
- Create: `lib/features/admin/presentation/widgets/dialog_crear_usuario.dart`

**Interfaces:**
- Consumes: `AdminProvider.crearUsuario({required nombreCompleto, required correo, required rol}) → Future<bool>` from Task 5.
- Produces: `DialogCrearUsuario` widget, a `StatefulWidget` with no constructor params, meant to be opened via `showDialog(context: context, builder: (_) => const DialogCrearUsuario())`. Consumed by Task 8.

- [ ] **Step 1: Create the widget**

Create `lib/features/admin/presentation/widgets/dialog_crear_usuario.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/admin_provider.dart';

/// Formulario modal exclusivo de Superusuario para registrar una cuenta
/// manualmente sin perder la sesión propia (ver superUserCreateAccount en
/// functions/index.js). No incluye campo de contraseña: se asigna una
/// genérica en el backend y el usuario la cambia después vía "Olvidé mi
/// contraseña".
class DialogCrearUsuario extends StatefulWidget {
  const DialogCrearUsuario({super.key});

  @override
  State<DialogCrearUsuario> createState() => _DialogCrearUsuarioState();
}

class _DialogCrearUsuarioState extends State<DialogCrearUsuario> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _correoController = TextEditingController();
  String _rolSeleccionado = 'Propietario';
  bool _isSubmitting = false;

  static const _roles = ['Propietario', 'Mecanico', 'Administrador'];

  @override
  void dispose() {
    _nombreController.dispose();
    _correoController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    final ok = await context.read<AdminProvider>().crearUsuario(
      nombreCompleto: _nombreController.text.trim(),
      correo: _correoController.text.trim(),
      rol: _rolSeleccionado,
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Crear Usuario'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _nombreController,
              decoration: const InputDecoration(labelText: 'Nombre completo'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _correoController,
              decoration: const InputDecoration(
                labelText: 'Correo electrónico',
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (v) =>
                  (v == null || !v.contains('@')) ? 'Correo inválido' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _rolSeleccionado,
              decoration: const InputDecoration(labelText: 'Rol'),
              items: _roles
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (v) => setState(() => _rolSeleccionado = v!),
            ),
            const SizedBox(height: 12),
            const Text(
              'Se asignará una contraseña temporal genérica. El usuario '
              'deberá cambiarla desde "Olvidé mi contraseña" en el login.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Crear'),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Verify it compiles standalone**

Run: `flutter analyze --no-fatal-infos lib/features/admin/presentation/widgets/dialog_crear_usuario.dart`
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add lib/features/admin/presentation/widgets/dialog_crear_usuario.dart
git commit -m "feat: add DialogCrearUsuario widget for Superusuario account creation"
```

---

## Task 8: Wire it all into `admin_usuarios_screen.dart`

**Files:**
- Modify: `lib/features/admin/presentation/pages/admin_usuarios_screen.dart`

**Interfaces:**
- Consumes: `UserModel.isSuperUser` (Task 2), `AdminProvider.eliminarUsuarioPermanente` (Task 5), `AccountRow(onEliminar, canHardDelete, ...)` (Task 6), `DialogCrearUsuario` (Task 7).

- [ ] **Step 1: Make the role dropdown hierarchy-aware**

In `lib/features/admin/presentation/pages/admin_usuarios_screen.dart`, replace the `_mostrarDialogoCambiarRol` signature and role list (lines 69-75):
```dart
  void _mostrarDialogoCambiarRol(
    BuildContext context,
    String targetUid,
    String rolActual,
    String adminUid,
  ) {
    final roles = ['Propietario', 'Mecanico', 'Administrador'];
    String? selectedRol;
```
with:
```dart
  void _mostrarDialogoCambiarRol(
    BuildContext context,
    String targetUid,
    String rolActual,
    String adminUid,
    bool esSuperUser,
  ) {
    // Solo un Superusuario puede promover a Administrador/Superusuario
    // (ver isSuperUser() en firestore.rules, que bloquea el update si no
    // lo es); un Administrador solo puede mover entre Propietario/Mecanico.
    final roles = esSuperUser
        ? ['Propietario', 'Mecanico', 'Administrador', 'Superusuario']
        : ['Propietario', 'Mecanico'];
    String? selectedRol;
```

- [ ] **Step 2: Add the `Superusuario` description**

Replace `_descRol` (lines 153-164):
```dart
  String _descRol(String rol) {
    switch (rol) {
      case 'Propietario':
        return 'Puede registrar vehículos y ver historial';
      case 'Mecanico':
        return 'Puede iniciar servicios y buscar vehículos';
      case 'Administrador':
        return 'Acceso total al panel de administración';
      default:
        return '';
    }
  }
```
with:
```dart
  String _descRol(String rol) {
    switch (rol) {
      case 'Propietario':
        return 'Puede registrar vehículos y ver historial';
      case 'Mecanico':
        return 'Puede iniciar servicios y buscar vehículos';
      case 'Administrador':
        return 'Acceso total al panel de administración';
      case 'Superusuario':
        return 'Acceso total, incluye crear administradores y eliminar cuentas';
      default:
        return '';
    }
  }
```

- [ ] **Step 3: Add a hard-delete confirmation dialog helper**

Add a new method right after `_mostrarDialogoMotivo` (after its closing `}` at line 67, before `_mostrarDialogoCambiarRol`):
```dart

  void _mostrarDialogoEliminarPermanente(
    BuildContext context,
    String nombreUsuario,
    VoidCallback onConfirm,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar cuenta permanentemente'),
        content: Text(
          'Esta acción borrará la cuenta de "$nombreUsuario" de forma '
          'irreversible (login y todos sus datos). ¿Deseas continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.adminCancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
```

- [ ] **Step 4: Gate the role dropdown, filter chip, FAB, and wire `AccountRow`'s new params**

In `build()`, after `final currentUid = (userSession.userData?.idUsuario ?? "");` (line 225), add:
```dart
    final esSuperUser = userSession.userData?.isSuperUser ?? false;
```

Add a filter chip for `Superusuario` — replace the `Row` at lines 293-303:
```dart
            child: Row(
              children: [
                _buildFilterChip('Todos'),
                const SizedBox(width: 8),
                _buildFilterChip('Propietario'),
                const SizedBox(width: 8),
                _buildFilterChip('Mecanico'),
                const SizedBox(width: 8),
                _buildFilterChip('Administrador'),
              ],
            ),
```
with:
```dart
            child: Row(
              children: [
                _buildFilterChip('Todos'),
                const SizedBox(width: 8),
                _buildFilterChip('Propietario'),
                const SizedBox(width: 8),
                _buildFilterChip('Mecanico'),
                const SizedBox(width: 8),
                _buildFilterChip('Administrador'),
                const SizedBox(width: 8),
                _buildFilterChip('Superusuario'),
              ],
            ),
```

Update the `AccountRow(...)` construction (lines 345-381) to pass the new required params and the updated `_mostrarDialogoCambiarRol` signature:
```dart
                              return AccountRow(
                                usuario: usuario,
                                isCurrentAdmin: usuario.idUsuario == currentUid,
                                canHardDelete: esSuperUser,
                                onAprobar: () {
                                  provider.aprobarUsuario(
                                    currentUid,
                                    usuario.idUsuario,
                                  );
                                },
                                onSuspender: () {
                                  _mostrarDialogoMotivo(
                                    context,
                                    'Suspender Usuario',
                                    (motivo) {
                                      provider.suspenderUsuario(
                                        currentUid,
                                        usuario.idUsuario,
                                        motivo,
                                      );
                                    },
                                  );
                                },
                                onReactivar: () {
                                  provider.reactivarUsuario(
                                    currentUid,
                                    usuario.idUsuario,
                                  );
                                },
                                onCambiarRol: () {
                                  _mostrarDialogoCambiarRol(
                                    context,
                                    usuario.idUsuario,
                                    usuario.rol,
                                    currentUid,
                                    esSuperUser,
                                  );
                                },
                                onEliminar: () {
                                  _mostrarDialogoEliminarPermanente(
                                    context,
                                    usuario.nombreCompleto,
                                    () => provider.eliminarUsuarioPermanente(
                                      usuario.idUsuario,
                                    ),
                                  );
                                },
                              );
```

- [ ] **Step 5: Add the FAB, gated on `isSuperUser`**

In the `Scaffold(...)` returned by `build()`, add a `floatingActionButton` right after the `body: Column(...)` closing (the `Scaffold` currently ends at line 388 with no `floatingActionButton`). Replace:
```dart
          ),
        ],
      ),
    );
  }
```
(the final lines of `build()`, closing `body: Column`, then `Scaffold`) with:
```dart
          ),
        ],
      ),
      floatingActionButton: esSuperUser
          ? FloatingActionButton.extended(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => const DialogCrearUsuario(),
              ),
              icon: const Icon(Icons.person_add),
              label: const Text('Crear Usuario'),
            )
          : null,
    );
  }
```

- [ ] **Step 6: Add the new import**

At the top of the file, alongside the other widget imports (after `import '../widgets/account_row.dart';` on line 8), add:
```dart
import '../widgets/dialog_crear_usuario.dart';
```

- [ ] **Step 7: Run analyzer and format**

Run:
```bash
flutter analyze --no-fatal-infos lib/features/admin
dart format --output=none --set-exit-if-changed lib/features/admin
```
Expected: no errors (the missing-argument error from Task 6, Step 2 is now resolved).

- [ ] **Step 8: Run the full unit/widget suite for regressions**

Run: `flutter test test/features/admin`
Expected: PASS.

- [ ] **Step 9: Manual verification**

1. Seed a Firestore `usuarios/{uid}` doc for your own logged-in test account with `rol: 'Superusuario'`.
2. Open the admin panel → Usuarios screen. Confirm the "Crear Usuario" FAB is visible.
3. Tap it, fill the form (nombre, correo, rol = Mecanico), submit. Confirm: your own session is NOT logged out, a success snackbar shows the temporary password, and the new user appears in the list.
4. Open the "⋮" menu on another user, tap "Cambiar Rol" — confirm the dialog now opens (previously dead due to the `cambiar_rol`/`rol` mismatch) and offers `Superusuario` as an option.
5. Change a user's role to `Superusuario`, confirm it succeeds and the badge updates.
6. Open the "⋮" menu on a non-Superusuario user — confirm "Eliminar cuenta (permanente)" is present; confirm it, and verify the user disappears from the list and can no longer log in.
7. Open the "⋮" menu on a `Superusuario` user — confirm "Eliminar cuenta (permanente)" is NOT present.
8. Change your test account's `rol` back to `'Administrador'` and reload. Confirm: the "Crear Usuario" FAB is gone, "Cambiar Rol" no longer offers `Administrador`/`Superusuario`, and no "Eliminar cuenta" option appears anywhere.
9. As that Administrador account, attempt (e.g. via browser devtools / a raw Firestore SDK call) to `update({ rol: 'Administrador' })` on another user's doc directly — confirm Firestore rejects it (defense in depth, matches the rules test from Task 1).

- [ ] **Step 10: Commit**

```bash
git add lib/features/admin/presentation/pages/admin_usuarios_screen.dart
git commit -m "feat: wire Superusuario role hierarchy, creation, and hard-delete into admin_usuarios_screen"
```

---

## Self-Review Notes

- **Spec coverage:** hierarchy table rows are covered — approve/moderate/change-role (unchanged, already `isAdmin()`-gated, now inherited by Superusuario via Task 1), create Administradores/Superusuario (Task 8's dropdown gating + Task 1's rules), manual registration without losing session (Task 3's Admin-SDK callable), hard delete (Tasks 1, 3, 5, 6, 8). Both original open questions are resolved by user decision: generic temp password (Task 3/7) and hard delete in scope (Tasks 1, 3, 5, 6, 8).
- **Pre-existing bug found and fixed in-scope:** `AccountRow`'s `cambiar_rol`/`rol` value mismatch (Task 6) — left unfixed, Task 8's manual verification of the role hierarchy would be untestable through the UI.
- **Type/name consistency checked:** `superUserCreateAccount`/`superUserDeleteAccount` callable names match exactly between Task 3 (Functions) and Task 4 (`AdminService`); `crearUsuarioComoSuperUser`/`eliminarUsuarioPermanente` names match exactly between Tasks 4 and 5; `AccountRow`'s `onEliminar`/`canHardDelete` match exactly between Tasks 6 and 8; `isSuperUser` getter name matches between Task 2 and its Task 8 usage (`userSession.userData?.isSuperUser`).
- **Out of scope, flagged for a future plan:** `.agents/rules/tablas-firebase.md`'s `Usuarios.rol` CHECK constraint is already missing `'Taller'` (a role actively used by `crearEmpleadoTaller`) independent of this feature — not fixed here to avoid scope creep, but worth a follow-up doc fix.
