# Security Findings Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the security/correctness gaps found in the post-merge review of `main` (2026-08-01): unrestricted field writes on `cotizaciones`/`reservas`, a confidentiality leak of the mechanic's profit margin, an unbounded rating-recompute in Cloud Functions, two dead notification triggers with an N+1 read pattern, and a missing read rule for the vehicle-sharing feature.

**Architecture:** Each fix follows the pattern already established in this codebase: Firestore Firestore-side authorization uses `request.resource.data.diff(resource.data).affectedKeys().hasOnly([...])` field-scoping (see the existing `usuarios`/`resenias`/`servicios` rules), Dart repositories are constructor-injectable with `FirebaseFirestore` for testing with `fake_cloud_firestore`, and rule changes get a matching Jest test in `test_rules/` using the existing `@firebase/rules-unit-testing` harness. The mechanic-margin leak needs an actual data-model change (a private subcollection), since Firestore rules cannot filter fields within a single document read.

**Tech Stack:** Flutter/Dart (client), Cloud Functions for Firebase (Node.js, `functions/index.js`), Firestore Security Rules, `fake_cloud_firestore` + `flutter_test` (Dart unit tests), Jest + `@firebase/rules-unit-testing` + Firebase Emulator (rules tests).

## Global Constraints

- Field-scoped update rules use the established pattern: `request.resource.data.diff(resource.data).affectedKeys().hasOnly([...])` (or `.hasAny([...])` for exclusion) — see `firestore.rules` `usuarios`/`resenias`/`servicios` blocks for precedent.
- Every `firestore.rules` change must explain **why** in a comment referencing the finding, matching the file's existing "hallazgo" documentation convention.
- Immutable Dart model updates use a `copyWith`-style method name (see `UserModel.copyWith`, `ReviewModel.copyWith`) — do not introduce a different naming convention.
- Repositories that talk to Firestore accept an optional injectable `FirebaseFirestore` in their constructor (see `ReviewService({FirebaseFirestore? firestore})`) so tests can pass `FakeFirebaseFirestore()`.
- `functions/` has **no test harness** in this repo (no `jest`/`firebase-functions-test` dependency, and `npm run lint` has no eslint config installed — it fails with "eslint no se reconoce"). Verify Cloud Functions changes with `node --check functions/index.js` (syntax) plus manual code review; do not introduce a new test framework as part of this plan (out of scope / YAGNI).
- Firestore rules tests live in `test_rules/` (plain `npm`, not `pnpm` — ignore any doc that says otherwise) and run via `cd test_rules && npm install && npm test`, which wraps Jest in `firebase emulators:exec --only firestore,storage`. This requires the Firebase CLI and Java (for the emulator) to be available locally.
- Flutter unit/widget tests run via `flutter test` from the repo root; static analysis via `flutter analyze`.
- Never touch `isVehicleOwner()` in `firestore.rules` to add the vehicle-sharing read grant (Task 8) — it is reused by `isOwnFinishedService` (review eligibility) and other ownership checks; broadening it would let a "shared with" viewer masquerade as the real owner elsewhere.

---

## File Structure

- `firestore.rules` — modify `usuarios`, `vehiculos`, `reservas`, `cotizaciones` blocks; add a new `cotizaciones/{id}/privado/{docId}` subcollection block.
- `functions/index.js` — modify `notifyOnReservationStatusChange`, `sendReservationReminders`, `aggregateRatings`.
- `lib/features/chat/data/models/cotizacion_model.dart` — split public/private serialization for `CotizacionItem.beneficio`.
- `lib/features/chat/data/repositories/chat_repository.dart` — make `FirebaseFirestore` injectable; write/read the private margin subcollection.
- `lib/features/chat/presentation/providers/chat_provider.dart` — add a passthrough for reading the private margin.
- `lib/features/chat/presentation/widgets/cards/cotizacion_chat_card.dart` — fetch and merge the mechanic's own margin for display.
- `test/features/chat/data/models/cotizacion_model_test.dart` (new) — unit tests for the model split.
- `test/features/chat/data/repositories/chat_repository_test.dart` (new) — unit tests for the repository split, using `FakeFirebaseFirestore`.
- `test_rules/cotizaciones.test.js` (new) — rule tests for field-scoping and the private subcollection.
- `test_rules/reservas.test.js`, `test_rules/usuarios.test.js`, `test_rules/vehiculos.test.js` — extended with new cases.

---

## Priority: P0 (High) — financial/confidentiality impact

### Task 1: Lock `cotizaciones` updates to the `estado` field only

**Files:**
- Modify: `firestore.rules:368-370`
- Test: Create `test_rules/cotizaciones.test.js`

**Interfaces:**
- Consumes: `isAuthenticated()` (already defined in `firestore.rules`).
- Produces: nothing new consumed by later tasks (Task 3 appends more `describe` blocks to the same test file).

**Why:** `allow update` currently only checks who is updating, not what they change. The app's only two write paths — `ChatRepository.actualizarEstadoCotizacion` (`lib/features/chat/data/repositories/chat_repository.dart:177-181`) and `ChatRepository.finalizarServicioDesdeCotizacion` (same file, line 226) — only ever touch `estado`. Anyone on either side of the quote can currently rewrite `items` (price/materials) or reassign `id_propietario`/`id_mecanico` via a direct SDK call.

- [ ] **Step 1: Write the failing rules test**

Create `test_rules/cotizaciones.test.js`:

```js
const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { makeEnv, seed, withRole, UIDS } = require('./helpers');

let env;
beforeAll(async () => { env = await makeEnv(); });
afterAll(async () => { await env.cleanup(); });
beforeEach(async () => { await env.clearFirestore(); });

const seedCotizacion = async () => {
  await seed(env, async (s) => {
    await s.collection('cotizaciones').doc('c1').set({
      id_propietario: UIDS.owner1,
      id_mecanico: UIDS.taller1,
      id_taller: UIDS.taller1,
      items: [{ material: 'Aceite', cantidad: 1, costo: 20 }],
      estado: 'pendiente',
    });
  });
};

describe('cotizaciones update (hallazgo H1: campo abierto permitia alterar precio/partes)', () => {
  test('el propietario SI puede aceptar (solo estado)', async () => {
    await seedCotizacion();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertSucceeds(
      db.collection('cotizaciones').doc('c1').update({ estado: 'aceptada' }),
    );
  });

  test('el mecanico SI puede finalizar (solo estado)', async () => {
    await seedCotizacion();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertSucceeds(
      db.collection('cotizaciones').doc('c1').update({ estado: 'finalizada' }),
    );
  });

  test('el propietario NO puede alterar los items (precio) al aceptar', async () => {
    await seedCotizacion();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db.collection('cotizaciones').doc('c1').update({
        estado: 'aceptada',
        items: [{ material: 'Aceite', cantidad: 1, costo: 1 }],
      }),
    );
  });

  test('el mecanico NO puede reasignar id_propietario', async () => {
    await seedCotizacion();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(
      db.collection('cotizaciones').doc('c1').update({
        id_propietario: UIDS.owner2,
      }),
    );
  });

  test('un tercero no vinculado NO puede actualizar la cotizacion', async () => {
    await seedCotizacion();
    const db = await withRole(env, UIDS.taller2, 'Taller');
    await assertFails(
      db.collection('cotizaciones').doc('c1').update({ estado: 'aceptada' }),
    );
  });
});
```

- [ ] **Step 2: Run the test to verify the tampering cases currently fail (i.e., the rule is too permissive)**

Run: `cd test_rules && npm install && npm test -- cotizaciones.test.js`
Expected: FAIL — specifically `'el propietario NO puede alterar los items...'` and `'el mecanico NO puede reasignar id_propietario'` fail because `assertFails` doesn't see a failure (the update currently succeeds).

- [ ] **Step 3: Field-scope the `cotizaciones` update rule**

In `firestore.rules`, replace:

```
      allow update: if isAuthenticated() &&
        (resource.data.id_propietario == request.auth.uid ||
         resource.data.id_mecanico == request.auth.uid);
```

with:

```
      // Solo el campo 'estado' es escribible tras la creacion: el
      // propietario acepta/rechaza (actualizarEstadoCotizacion) y el
      // mecanico la marca 'finalizada' (finalizarServicioDesdeCotizacion);
      // ninguno de los dos flujos reales toca otro campo. Sin este acotado,
      // cualquiera de los dos podia reescribir 'items' (precio) o
      // reasignar id_propietario/id_mecanico despues de creada (hallazgo H1).
      allow update: if isAuthenticated() &&
        (resource.data.id_propietario == request.auth.uid ||
         resource.data.id_mecanico == request.auth.uid) &&
        request.resource.data.diff(resource.data).affectedKeys().hasOnly(['estado']);
```

- [ ] **Step 4: Run the test again to verify it passes**

Run: `cd test_rules && npm test -- cotizaciones.test.js`
Expected: PASS (all 5 tests green).

- [ ] **Step 5: Commit**

```bash
git add firestore.rules test_rules/cotizaciones.test.js
git commit -m "security: restrict cotizaciones update to the estado field only"
```

---

### Task 2: Stop embedding the mechanic's profit margin in the public quote payload

**Files:**
- Modify: `lib/features/chat/data/models/cotizacion_model.dart`
- Test: Create `test/features/chat/data/models/cotizacion_model_test.dart`

**Interfaces:**
- Produces: `CotizacionItem.copyWithBeneficio(double beneficio)`, `CotizacionModel.toPrivateMap()` returning `{'beneficios': List<double>}`, `CotizacionModel.copyWithBeneficios(List<double> beneficios)`. Task 3's `ChatRepository` and Task 4's widget consume these exact names.
- `CotizacionItem.toMap()` no longer includes the `'beneficio'` key (breaking change to the public serialization, intentional).

**Why:** `CotizacionItem.beneficio` is documented as "solo debe mostrarse al mecánico, nunca al cliente," but `CotizacionModel.toMap()` (written to the `cotizaciones` document, which `id_propietario` can read in full per `firestore.rules`) includes it in every item. The UI hides it from the client visually, but nothing stops the owner from reading it directly via the Firestore SDK.

- [ ] **Step 1: Write the failing tests**

Create `test/features/chat/data/models/cotizacion_model_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/features/chat/data/models/cotizacion_model.dart';

void main() {
  group('CotizacionItem.toMap', () {
    test('never includes beneficio (el cliente no debe verlo)', () {
      final item = CotizacionItem(
        material: 'Filtro de aceite',
        cantidad: 1,
        costo: 15,
        beneficio: 5,
      );

      final map = item.toMap();

      expect(map.containsKey('beneficio'), isFalse);
      expect(map, {'material': 'Filtro de aceite', 'cantidad': 1.0, 'costo': 15.0});
    });
  });

  group('CotizacionModel.toPrivateMap', () {
    test('lista los beneficios en el mismo orden que items', () {
      final cotizacion = CotizacionModel(
        id: 'c1',
        idPropietario: 'owner1',
        idMecanico: 'taller1',
        items: [
          CotizacionItem(material: 'A', cantidad: 1, costo: 10, beneficio: 3),
          CotizacionItem(material: 'B', cantidad: 2, costo: 5, beneficio: 1.5),
        ],
        fecha: DateTime(2026, 1, 1),
      );

      expect(cotizacion.toPrivateMap(), {'beneficios': [3.0, 1.5]});
    });
  });

  group('CotizacionModel.copyWithBeneficios', () {
    test('rellena el beneficio de cada item por posicion', () {
      final cotizacion = CotizacionModel(
        id: 'c1',
        idPropietario: 'owner1',
        idMecanico: 'taller1',
        items: [
          CotizacionItem(material: 'A', cantidad: 1, costo: 10),
          CotizacionItem(material: 'B', cantidad: 2, costo: 5),
        ],
        fecha: DateTime(2026, 1, 1),
      );

      final conBeneficios = cotizacion.copyWithBeneficios([3.0, 1.5]);

      expect(conBeneficios.items[0].beneficio, 3.0);
      expect(conBeneficios.items[1].beneficio, 1.5);
    });

    test('rellena con 0 si la lista de beneficios es mas corta que items', () {
      final cotizacion = CotizacionModel(
        id: 'c1',
        idPropietario: 'owner1',
        idMecanico: 'taller1',
        items: [
          CotizacionItem(material: 'A', cantidad: 1, costo: 10),
          CotizacionItem(material: 'B', cantidad: 2, costo: 5),
        ],
        fecha: DateTime(2026, 1, 1),
      );

      final conBeneficios = cotizacion.copyWithBeneficios([3.0]);

      expect(conBeneficios.items[0].beneficio, 3.0);
      expect(conBeneficios.items[1].beneficio, 0.0);
    });
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/chat/data/models/cotizacion_model_test.dart`
Expected: FAIL with "The method 'toPrivateMap' isn't defined" / "The method 'copyWithBeneficios' isn't defined" / the `toMap` test failing because `'beneficio'` is present.

- [ ] **Step 3: Split public/private serialization in `CotizacionItem`**

In `lib/features/chat/data/models/cotizacion_model.dart`, replace the `CotizacionItem` class body's `toMap()` method:

```dart
  Map<String, dynamic> toMap() {
    return {
      'material': material,
      'cantidad': cantidad,
      'costo': costo,
      'beneficio': beneficio,
    };
  }
```

with:

```dart
  /// Payload publico (escrito en el documento cotizaciones/{id}, legible por
  /// el propietario): nunca incluye [beneficio]. Ver
  /// CotizacionModel.toPrivateMap para donde vive el beneficio.
  Map<String, dynamic> toMap() {
    return {'material': material, 'cantidad': cantidad, 'costo': costo};
  }
```

Then add a `copyWithBeneficio` method to `CotizacionItem`, right after `factory CotizacionItem.fromMap(...)`:

```dart
  CotizacionItem copyWithBeneficio(double beneficio) {
    return CotizacionItem(
      material: material,
      cantidad: cantidad,
      costo: costo,
      beneficio: beneficio,
    );
  }
```

- [ ] **Step 4: Add `toPrivateMap` and `copyWithBeneficios` to `CotizacionModel`**

In the same file, right after `CotizacionModel.toMap()`, add:

```dart
  /// Documento privado (cotizaciones/{id}/privado/margen): el beneficio por
  /// renglon, visible solo para el mecanico dueño de la cotizacion (ver
  /// firestore.rules). Nunca debe fusionarse con [toMap].
  Map<String, dynamic> toPrivateMap() {
    return {'beneficios': items.map((i) => i.beneficio).toList()};
  }

  /// Copia este modelo sustituyendo el beneficio de cada item por el valor
  /// en la misma posicion de [beneficios] (leido de toPrivateMap). Si
  /// [beneficios] es mas corto que [items], los renglones sobrantes quedan
  /// en 0.
  CotizacionModel copyWithBeneficios(List<double> beneficios) {
    final nuevosItems = <CotizacionItem>[];
    for (var i = 0; i < items.length; i++) {
      final beneficio = i < beneficios.length ? beneficios[i] : 0.0;
      nuevosItems.add(items[i].copyWithBeneficio(beneficio));
    }
    return CotizacionModel(
      id: id,
      idPropietario: idPropietario,
      idMecanico: idMecanico,
      idVehiculo: idVehiculo,
      idTaller: idTaller,
      items: nuevosItems,
      fechaPropuesta: fechaPropuesta,
      estado: estado,
      fecha: fecha,
      manoDeObra: manoDeObra,
      materiales: materiales,
    );
  }
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/features/chat/data/models/cotizacion_model_test.dart`
Expected: PASS (4 tests green).

- [ ] **Step 6: Run `flutter analyze` to catch any other caller relying on the old `toMap` shape**

Run: `flutter analyze`
Expected: "No issues found!" (repository/widget code isn't updated until Tasks 3-4, but `toMap()`'s return type is unchanged (`Map<String, dynamic>`), so no other file breaks yet.)

- [ ] **Step 7: Commit**

```bash
git add lib/features/chat/data/models/cotizacion_model.dart test/features/chat/data/models/cotizacion_model_test.dart
git commit -m "security: split mechanic profit margin out of the public cotizacion payload"
```

---

### Task 3: Persist and read the mechanic's margin via a private subcollection

**Files:**
- Modify: `lib/features/chat/data/repositories/chat_repository.dart:1-8` (constructor), `:167-174` (`crearCotizacion`)
- Modify: `lib/features/chat/presentation/providers/chat_provider.dart:235-243` area (add passthrough)
- Modify: `firestore.rules` (add subcollection block inside `match /cotizaciones/{cotizacionId}`)
- Modify: `test_rules/cotizaciones.test.js` (append tests)
- Test: Create `test/features/chat/data/repositories/chat_repository_test.dart`

**Interfaces:**
- Consumes: `CotizacionModel.toPrivateMap()` (Task 2).
- Produces: `ChatRepository({FirebaseFirestore? firestore})` constructor, `ChatRepository.obtenerBeneficiosCotizacion(String cotizacionId) -> Future<List<double>>`, `ChatProvider.obtenerBeneficiosCotizacion(String cotizacionId) -> Future<List<double>>`. Task 4 consumes the `ChatProvider` method.

**Why:** Task 2 stopped writing `beneficio` into the public document; this task gives it a real, access-controlled home so the mechanic can still see their own margin.

- [ ] **Step 1: Write the failing repository tests**

Create `test/features/chat/data/repositories/chat_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:autodoc/features/chat/data/repositories/chat_repository.dart';
import 'package:autodoc/features/chat/data/models/cotizacion_model.dart';

void main() {
  group('ChatRepository.crearCotizacion', () {
    test('el documento publico nunca incluye beneficio en los items', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = ChatRepository(firestore: firestore);
      final cotizacion = CotizacionModel(
        id: '',
        idPropietario: 'owner1',
        idMecanico: 'taller1',
        items: [
          CotizacionItem(material: 'Filtro', cantidad: 1, costo: 20, beneficio: 8),
        ],
        fecha: DateTime(2026, 1, 1),
      );

      final id = await repo.crearCotizacion(cotizacion);

      final publicDoc = await firestore.collection('cotizaciones').doc(id).get();
      final items = publicDoc.data()!['items'] as List;
      expect((items.first as Map).containsKey('beneficio'), isFalse);
    });

    test('escribe el beneficio en la subcoleccion privada', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = ChatRepository(firestore: firestore);
      final cotizacion = CotizacionModel(
        id: '',
        idPropietario: 'owner1',
        idMecanico: 'taller1',
        items: [
          CotizacionItem(material: 'Filtro', cantidad: 1, costo: 20, beneficio: 8),
        ],
        fecha: DateTime(2026, 1, 1),
      );

      final id = await repo.crearCotizacion(cotizacion);
      final beneficios = await repo.obtenerBeneficiosCotizacion(id);

      expect(beneficios, [8.0]);
    });

    test('obtenerBeneficiosCotizacion devuelve lista vacia si no existe', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = ChatRepository(firestore: firestore);

      final beneficios = await repo.obtenerBeneficiosCotizacion('no-existe');

      expect(beneficios, isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/chat/data/repositories/chat_repository_test.dart`
Expected: FAIL with "No named parameter with the name 'firestore'" (constructor doesn't accept it yet) and "The method 'obtenerBeneficiosCotizacion' isn't defined".

- [ ] **Step 3: Make `ChatRepository` constructor-injectable**

In `lib/features/chat/data/repositories/chat_repository.dart`, replace:

```dart
class ChatRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
```

with:

```dart
class ChatRepository {
  ChatRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
```

- [ ] **Step 4: Batch-write the public doc and the private margin subdocument in `crearCotizacion`**

In the same file, replace:

```dart
  // Crear cotización
  Future<String> crearCotizacion(CotizacionModel cotizacion) async {
    final docRef = _firestore.collection('cotizaciones').doc();
    final data = cotizacion.toMap();
    data['id_cotizacion'] = docRef.id; // o id, dependiendo de la convención
    await docRef.set(data);
    return docRef.id;
  }
```

with:

```dart
  // Crear cotización
  Future<String> crearCotizacion(CotizacionModel cotizacion) async {
    final docRef = _firestore.collection('cotizaciones').doc();
    final data = cotizacion.toMap();
    data['id_cotizacion'] = docRef.id; // o id, dependiendo de la convención

    final batch = _firestore.batch();
    batch.set(docRef, data);
    // Beneficio por renglon: subcoleccion privada, ver firestore.rules
    // cotizaciones/{id}/privado/{docId} (hallazgo H2).
    batch.set(docRef.collection('privado').doc('margen'), cotizacion.toPrivateMap());
    await batch.commit();

    return docRef.id;
  }

  // Beneficio por renglon de una cotizacion (solo el mecanico dueño puede
  // leerlo, ver firestore.rules).
  Future<List<double>> obtenerBeneficiosCotizacion(String cotizacionId) async {
    final doc = await _firestore
        .collection('cotizaciones')
        .doc(cotizacionId)
        .collection('privado')
        .doc('margen')
        .get();
    if (!doc.exists) return const [];
    final raw = doc.data()?['beneficios'] as List?;
    if (raw == null) return const [];
    return raw.map((e) => (e as num).toDouble()).toList();
  }
```

- [ ] **Step 5: Run the repository tests to verify they pass**

Run: `flutter test test/features/chat/data/repositories/chat_repository_test.dart`
Expected: PASS (3 tests green).

- [ ] **Step 6: Add the `ChatProvider` passthrough**

In `lib/features/chat/presentation/providers/chat_provider.dart`, right after the existing `crearCotizacion` method:

```dart
  Future<String?> crearCotizacion(CotizacionModel cotizacion) async {
    try {
      return await _chatRepository.crearCotizacion(cotizacion);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }
```

add:

```dart
  Future<List<double>> obtenerBeneficiosCotizacion(String cotizacionId) async {
    try {
      return await _chatRepository.obtenerBeneficiosCotizacion(cotizacionId);
    } catch (e) {
      return const [];
    }
  }
```

- [ ] **Step 7: Add the Firestore rule for the private subcollection**

In `firestore.rules`, inside `match /cotizaciones/{cotizacionId} { ... }`, right before its closing `}` (after the `allow update` block from Task 1), add:

```
      // Beneficio por renglon (ver CotizacionItem.beneficio en el cliente):
      // documento privado fuera del doc principal porque 'cotizaciones' es
      // de lectura compartida con el propietario, y el beneficio del
      // mecanico nunca debe ser visible para el cliente (hallazgo H2).
      match /privado/{docId} {
        allow read: if isAuthenticated() && (
          get(/databases/$(database)/documents/cotizaciones/$(cotizacionId)).data.id_mecanico == request.auth.uid
          || isAdmin()
        );
        allow write: if isAuthenticated() &&
          get(/databases/$(database)/documents/cotizaciones/$(cotizacionId)).data.id_mecanico == request.auth.uid;
      }
```

- [ ] **Step 8: Write the failing rules tests for the subcollection**

Append to `test_rules/cotizaciones.test.js` (after the existing `describe` block, before the file ends):

```js
describe('cotizaciones/privado/margen (hallazgo H2: el beneficio no debe ser legible por el propietario)', () => {
  const seedMargen = async () => {
    await seed(env, async (s) => {
      await s.collection('cotizaciones').doc('c1').set({
        id_propietario: UIDS.owner1,
        id_mecanico: UIDS.taller1,
        id_taller: UIDS.taller1,
        items: [{ material: 'Aceite', cantidad: 1, costo: 20 }],
        estado: 'pendiente',
      });
      await s.collection('cotizaciones').doc('c1').collection('privado').doc('margen').set({
        beneficios: [8],
      });
    });
  };

  test('el mecanico dueño SI puede leer su margen', async () => {
    await seedMargen();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertSucceeds(
      db.collection('cotizaciones').doc('c1').collection('privado').doc('margen').get(),
    );
  });

  test('el propietario NO puede leer el margen del mecanico', async () => {
    await seedMargen();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db.collection('cotizaciones').doc('c1').collection('privado').doc('margen').get(),
    );
  });

  test('un tercero no vinculado NO puede leer el margen', async () => {
    await seedMargen();
    const db = await withRole(env, UIDS.taller2, 'Taller');
    await assertFails(
      db.collection('cotizaciones').doc('c1').collection('privado').doc('margen').get(),
    );
  });
});
```

- [ ] **Step 9: Run the rules tests to verify they pass**

Run: `cd test_rules && npm test -- cotizaciones.test.js`
Expected: PASS (8 tests green: 5 from Task 1 + 3 new).

- [ ] **Step 10: Run `flutter analyze` and the full Dart test suite**

Run: `flutter analyze && flutter test`
Expected: "No issues found!" and all tests passing (this task doesn't change any widget yet, so no regressions expected).

- [ ] **Step 11: Commit**

```bash
git add lib/features/chat/data/repositories/chat_repository.dart lib/features/chat/presentation/providers/chat_provider.dart firestore.rules test_rules/cotizaciones.test.js test/features/chat/data/repositories/chat_repository_test.dart
git commit -m "security: persist mechanic margin in a private cotizaciones subcollection"
```

---

### Task 4: Show the mechanic's own margin from the private subcollection

**Files:**
- Modify: `lib/features/chat/presentation/widgets/cards/cotizacion_chat_card.dart`

**Interfaces:**
- Consumes: `ChatProvider.obtenerBeneficiosCotizacion` (Task 3), `CotizacionModel.copyWithBeneficios` (Task 2).
- Produces: nothing consumed by later tasks.

**Why:** `_CotizacionCardBody` still computes `beneficioTotal` from `cotizacion.items`, which after Task 2 always has `beneficio == 0` (the public doc no longer carries it). The mechanic's own "Tu beneficio" line would silently show `$0.00` unless the state class fetches the private doc and merges it back in for its own view.

- [ ] **Step 1: Add a `_beneficios` field and fetch it on init when the viewer is the mechanic**

In `lib/features/chat/presentation/widgets/cards/cotizacion_chat_card.dart`, replace:

```dart
class _CotizacionChatCardState extends State<CotizacionChatCard> {
  bool _isFinalizing = false;
  bool _isCheckingReview = false;

  String? get _cotizacionId => widget.metadata['id_cotizacion'] as String?;
```

with:

```dart
class _CotizacionChatCardState extends State<CotizacionChatCard> {
  bool _isFinalizing = false;
  bool _isCheckingReview = false;
  List<double>? _beneficios;

  String? get _cotizacionId => widget.metadata['id_cotizacion'] as String?;

  @override
  void initState() {
    super.initState();
    // Solo el mecanico (emisor de la cotizacion) necesita ver su beneficio;
    // el propietario nunca debe leer cotizaciones/{id}/privado/margen
    // (hallazgo H2), asi que ni siquiera se intenta el fetch para el.
    if (widget.isMe) _cargarBeneficios();
  }

  Future<void> _cargarBeneficios() async {
    final cotizacionId = _cotizacionId;
    if (cotizacionId == null) return;
    final beneficios = await context.read<ChatProvider>()
        .obtenerBeneficiosCotizacion(cotizacionId);
    if (!mounted) return;
    setState(() => _beneficios = beneficios);
  }
```

- [ ] **Step 2: Merge the fetched margin into the model before building the card body**

In the same file, in `build()`, replace:

```dart
        final cotizacion = CotizacionModel.fromMap(
          snapshot.data!.data()!,
          snapshot.data!.id,
        );
        return _CotizacionCardBody(
```

with:

```dart
        var cotizacion = CotizacionModel.fromMap(
          snapshot.data!.data()!,
          snapshot.data!.id,
        );
        if (widget.isMe && _beneficios != null) {
          cotizacion = cotizacion.copyWithBeneficios(_beneficios!);
        }
        return _CotizacionCardBody(
```

- [ ] **Step 3: Run `flutter analyze` and the full test suite**

Run: `flutter analyze && flutter test`
Expected: "No issues found!" and all tests passing.

- [ ] **Step 4: Manual verification (no existing widget test covers this card; verify by hand)**

1. Run the app (`flutter run -d chrome --dart-define-from-file=.env` or your usual dev target).
2. As a `Mecanico`/`Taller` user, send a quote with a non-zero `beneficio` on at least one item.
3. Still logged in as the mechanic, confirm the "Tu beneficio" line under the quote card shows the correct total (not `$0.00`).
4. Log in as the `Propietario` who received the quote and confirm no beneficio/margin figure is shown or present in the rendered card (this was already true before this task; the check here is that it's still true).

- [ ] **Step 5: Commit**

```bash
git add lib/features/chat/presentation/widgets/cards/cotizacion_chat_card.dart
git commit -m "fix: restore mechanic's own margin display via the private cotizacion subcollection"
```

---

## Priority: P1 (Medium) — data-integrity and cost impact

### Task 5: Lock `reservas` updates to the fields the real flows use

**Files:**
- Modify: `firestore.rules:353-357`
- Modify: `test_rules/reservas.test.js` (append tests)

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: nothing consumed by later tasks.

**Why:** `allow update` today lets either `id_propietario` or `id_mecanico` write *any* field. The two real write paths — `ReservaRepository.actualizarEstadoReserva` (writes `estado` and optionally `fecha_hora_confirmada`, `lib/features/chat/data/repositories/reserva_repository.dart:56-69`) and `ReservaRepository.reprogramarReserva` (writes `fecha_hora_propuesta` and resets `estado`, same file lines 45-53) — never touch anything else. Without scoping, either party can reassign `id_propietario`, `id_mecanico`, `id_vehiculo`, or `id_taller` after creation. (Note: confirming/rejecting an appointment is done by the `Propietario` in this app's current UI — see `reserva_detail_screen.dart:428-485`, where the `_cambiarEstado('confirmada'/'rechazada')` buttons render in the `!isMecanico` branch — so this fix is a field-scoping fix, not a role-restriction fix; restricting `confirmada`/`rechazada` to the mechanic would break the real confirmation flow.)

- [ ] **Step 1: Write the failing rules tests**

Append to `test_rules/reservas.test.js`, after the existing `describe(...)` block's closing `});`:

```js
describe('reservas update field scoping (hallazgo M1: cualquier campo era escribible)', () => {
  test('el propietario NO puede reasignar id_mecanico', async () => {
    await seedReserva();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db.collection('reservas').doc('r1').update({ id_mecanico: UIDS.taller2 }),
    );
  });

  test('el mecanico NO puede reasignar id_vehiculo', async () => {
    await seedReserva();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(
      db.collection('reservas').doc('r1').update({ id_vehiculo: 'v2' }),
    );
  });

  test('el mecanico SI puede reprogramar (fecha_hora_propuesta + estado)', async () => {
    await seedReserva();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertSucceeds(
      db.collection('reservas').doc('r1').update({
        fecha_hora_propuesta: new Date(),
        estado: 'pendiente',
      }),
    );
  });
});
```

- [ ] **Step 2: Run the tests to verify the tampering cases currently fail**

Run: `cd test_rules && npm test -- reservas.test.js`
Expected: FAIL — `'el propietario NO puede reasignar id_mecanico'` and `'el mecanico NO puede reasignar id_vehiculo'` fail because those updates currently succeed.

- [ ] **Step 3: Field-scope the `reservas` update rule**

In `firestore.rules`, replace:

```
      allow update: if isAuthenticated() && (
        resource.data.id_propietario == request.auth.uid ||
        resource.data.id_mecanico == request.auth.uid ||
        isAdmin()
      );
```

(in the `match /reservas/{reservaId}` block) with:

```
      // Tras crearse, solo estado/fecha_hora_confirmada/fecha_hora_propuesta
      // son escribibles (ver ReservaRepository.actualizarEstadoReserva y
      // .reprogramarReserva, los unicos dos flujos reales de escritura):
      // sin este acotado, cualquiera de los dos participantes podia
      // reescribir id_propietario/id_mecanico/id_vehiculo/id_taller despues
      // de creada la reserva (hallazgo M1).
      allow update: if isAuthenticated() && (
        isAdmin() || (
          (resource.data.id_propietario == request.auth.uid ||
           resource.data.id_mecanico == request.auth.uid) &&
          request.resource.data.diff(resource.data).affectedKeys()
            .hasOnly(['estado', 'fecha_hora_confirmada', 'fecha_hora_propuesta'])
        )
      );
```

- [ ] **Step 4: Run the full `reservas.test.js` suite to verify everything passes**

Run: `cd test_rules && npm test -- reservas.test.js`
Expected: PASS (6 tests green: 3 pre-existing + 3 new — the pre-existing tests only ever set `estado`, so they remain valid under the new scoping).

- [ ] **Step 5: Commit**

```bash
git add firestore.rules test_rules/reservas.test.js
git commit -m "security: restrict reservas update to known state-transition fields"
```

---

### Task 6: Fix the dead `'aprobada'` reservation state and its N+1 reads

**Files:**
- Modify: `functions/index.js:541-593` (`notifyOnReservationStatusChange`), `functions/index.js:599-660` (`sendReservationReminders`)

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: nothing consumed by later tasks.

**Why:** `ReservaModel.estado` (`lib/features/chat/data/models/reserva_model.dart:15`) only ever takes the values `'pendiente' | 'confirmada' | 'rechazada' | 'completada' | 'cancelada'`. Both Cloud Functions check/query for `'aprobada'`, a value the app never writes — so `notifyOnReservationStatusChange` never sends its "Reserva Confirmada/Rechazada" notification, and `sendReservationReminders`'s daily query always returns zero documents. `sendReservationReminders` also compares against a `reserva.fecha` string field that doesn't exist (the real field is `fecha_hora_propuesta`, a Firestore `Timestamp` — see `reserva_repository.dart:16` `orderBy('fecha_hora_propuesta', ...)`), and does an unbatched `usuarios` read per reservation per role inside its loop (lines 627, 641) — the same N+1 pattern already fixed elsewhere in this file via a `usuariosCache` (see `checkAlertsDaily`, lines 74-75, 106-120).

- [ ] **Step 1: Fix the dead state check in `notifyOnReservationStatusChange`**

In `functions/index.js`, replace:

```js
      const isAccepted = newValue.estado === 'aprobada';
      const isRejected = newValue.estado === 'rechazada';
```

with:

```js
      const isAccepted = newValue.estado === 'confirmada';
      const isRejected = newValue.estado === 'rechazada';
```

- [ ] **Step 2: Fix the dead state/field and add read caching in `sendReservationReminders`**

Replace the whole function body (from `exports.sendReservationReminders = functions.pubsub.schedule(...)` through its closing `});`) with:

```js
exports.sendReservationReminders = functions.pubsub.schedule('every 24 hours').onRun(async (context) => {
  const tomorrow = new Date();
  tomorrow.setDate(tomorrow.getDate() + 1);
  const dateString = tomorrow.toISOString().split('T')[0]; // 'YYYY-MM-DD'

  const limit = 500;
  let lastDoc = null;

  const usuariosCache = {};

  try {
    while (true) {
      let q = db.collection('reservas')
        .where('estado', '==', 'confirmada')
        .orderBy(admin.firestore.FieldPath.documentId())
        .limit(limit);
      if (lastDoc) {
        q = q.startAfter(lastDoc);
      }
      const reservasSnapshot = await q.get();
      if (reservasSnapshot.empty) break;

      for (const doc of reservasSnapshot.docs) {
        const reserva = doc.data();

        const fechaPropuesta = reserva.fecha_hora_propuesta && reserva.fecha_hora_propuesta.toDate
          ? reserva.fecha_hora_propuesta.toDate()
          : null;
        if (!fechaPropuesta) continue;
        const fechaPropuestaString = fechaPropuesta.toISOString().split('T')[0];
        if (fechaPropuestaString !== dateString) continue;

        // Notify Owner
        if (reserva.id_propietario) {
          if (!(reserva.id_propietario in usuariosCache)) {
            const ownerDoc = await db.collection('usuarios').doc(reserva.id_propietario).get();
            usuariosCache[reserva.id_propietario] = ownerDoc.exists ? ownerDoc.data() : null;
          }
          const ownerData = usuariosCache[reserva.id_propietario];
          if (ownerData && ownerData.fcmToken) {
            await messaging.send({
              token: ownerData.fcmToken,
              notification: {
                title: 'Recordatorio de Cita',
                body: 'Tienes una cita programada para mañana a la hora acordada.'
              }
            });
          }
        }

        // Notify Mechanic
        if (reserva.id_mecanico) {
          if (!(reserva.id_mecanico in usuariosCache)) {
            const mechanicDoc = await db.collection('usuarios').doc(reserva.id_mecanico).get();
            usuariosCache[reserva.id_mecanico] = mechanicDoc.exists ? mechanicDoc.data() : null;
          }
          const mechanicData = usuariosCache[reserva.id_mecanico];
          if (mechanicData && mechanicData.fcmToken) {
            await messaging.send({
              token: mechanicData.fcmToken,
              notification: {
                title: 'Recordatorio de Cita',
                body: 'Tienes una cita programada para mañana con el vehículo del cliente.'
              }
            });
          }
        }
      }

      lastDoc = reservasSnapshot.docs[reservasSnapshot.docs.length - 1];
    }
  } catch (error) {
    console.error('Error in sendReservationReminders:', error);
  }
});
```

- [ ] **Step 3: Verify syntax (no test harness exists for `functions/`)**

Run: `node --check functions/index.js`
Expected: no output (exit code 0 means the file parses correctly).

- [ ] **Step 4: Commit**

```bash
git add functions/index.js
git commit -m "fix: match reservas notification/reminder functions to the real 'confirmada' state and field names, cache user reads"
```

---

### Task 7: Replace the unbounded `aggregateRatings` rescan with incremental counters

**Files:**
- Modify: `functions/index.js:775-795` (`aggregateRatings`)
- Modify: `firestore.rules:91-93` (`usuarios` update — protect the new `suma_estrellas` field)
- Modify: `test_rules/usuarios.test.js` (append test)

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: a new `suma_estrellas` field on `usuarios/{tallerId}` documents (internal bookkeeping, never read by the client).

**Why:** `aggregateRatings` re-reads **every** review for a taller on every single write to any review for that taller (including edits that don't touch `estrellas`, like a `respuesta_taller` reply or an `is_reported` flag), to recompute the average from scratch. This is O(n) per write with no bound. Since Firestore can't atomically maintain an average from `FieldValue.increment()` alone (average needs both sum and count together), this task adds a `suma_estrellas` running-sum field plus the existing `total_resenias`, updated inside a transaction from a delta — O(1) per write after a one-time lazy migration per taller.

- [ ] **Step 1: Rewrite `aggregateRatings` to skip no-op writes and use incremental counters**

In `functions/index.js`, replace:

```js
exports.aggregateRatings = functions.firestore
  .document('resenias/{reseniaId}')
  .onWrite(async (change, context) => {
    const resenia = change.after.exists ? change.after.data() : change.before.data();
    const tallerId = resenia.id_taller;
    if (!tallerId) return null;

    const reseniasSnap = await db.collection('resenias').where('id_taller', '==', tallerId).get();
    let total = 0;
    let sum = 0;
    reseniasSnap.forEach(doc => {
      total++;
      sum += doc.data().estrellas || 0;
    });

    const avg = total > 0 ? sum / total : 0;
    await db.collection('usuarios').doc(tallerId).update({
      calificacion_promedio: avg,
      total_resenias: total
    });
  });
```

with:

```js
exports.aggregateRatings = functions.firestore
  .document('resenias/{reseniaId}')
  .onWrite(async (change, context) => {
    const before = change.before.exists ? change.before.data() : null;
    const after = change.after.exists ? change.after.data() : null;
    const tallerId = (after || before || {}).id_taller;
    if (!tallerId) return null;

    const beforeEstrellas = before ? (before.estrellas || 0) : 0;
    const afterEstrellas = after ? (after.estrellas || 0) : 0;
    const deltaCount = (after ? 1 : 0) - (before ? 1 : 0);
    const deltaSum = afterEstrellas - beforeEstrellas;
    // Un update que no toca 'estrellas' (respuesta_taller, is_reported, etc.)
    // no cambia el agregado: nos ahorramos la escritura.
    if (deltaCount === 0 && deltaSum === 0) return null;

    const userRef = db.collection('usuarios').doc(tallerId);
    const userSnap = await userRef.get();
    if (!userSnap.exists) return null;

    if (userSnap.data().suma_estrellas === undefined) {
      // Migracion perezosa: este taller aun no paso por la version
      // incremental. Se siembra suma_estrellas con un recuento completo,
      // una sola vez; las escrituras futuras ya son incrementales (O(1) en
      // vez de O(n) reseñas del taller).
      const reseniasSnap = await db.collection('resenias').where('id_taller', '==', tallerId).get();
      let total = 0;
      let sum = 0;
      reseniasSnap.forEach((doc) => {
        total++;
        sum += doc.data().estrellas || 0;
      });
      await userRef.update({
        calificacion_promedio: total > 0 ? sum / total : 0,
        total_resenias: total,
        suma_estrellas: sum,
      });
      return null;
    }

    await db.runTransaction(async (tx) => {
      const snap = await tx.get(userRef);
      if (!snap.exists) return;
      const data = snap.data();
      const count = Math.max(0, (data.total_resenias || 0) + deltaCount);
      const sum = Math.max(0, (data.suma_estrellas || 0) + deltaSum);
      tx.update(userRef, {
        calificacion_promedio: count > 0 ? sum / count : 0,
        total_resenias: count,
        suma_estrellas: sum,
      });
    });
  });
```

- [ ] **Step 2: Verify syntax**

Run: `node --check functions/index.js`
Expected: no output (exit code 0).

- [ ] **Step 3: Write the failing rules test protecting the new field**

In `test_rules/usuarios.test.js`, replace:

```js
  test('un usuario NO puede escribir sus metricas de reputacion', async () => {
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(
      db.collection('usuarios').doc(UIDS.taller1).update({ calificacion_promedio: 5 }),
    );
  });
```

with:

```js
  test('un usuario NO puede escribir sus metricas de reputacion', async () => {
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(
      db.collection('usuarios').doc(UIDS.taller1).update({ calificacion_promedio: 5 }),
    );
  });

  test('un usuario NO puede escribir suma_estrellas (contador interno de aggregateRatings)', async () => {
    // Sin excluir este campo, el propietario de la cuenta podria inflar su
    // propio promedio escribiendo directamente el acumulador que la Cloud
    // Function usa para el calculo incremental (hallazgo M2).
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(
      db.collection('usuarios').doc(UIDS.taller1).update({ suma_estrellas: 999 }),
    );
  });
```

- [ ] **Step 4: Run the test to verify it currently fails**

Run: `cd test_rules && npm test -- usuarios.test.js`
Expected: FAIL — `'un usuario NO puede escribir suma_estrellas...'` fails because the field isn't excluded yet, so the write currently succeeds.

- [ ] **Step 5: Add `suma_estrellas` to the excluded fields on self-update**

In `firestore.rules`, replace:

```
      allow update: if (isOwner(userId) && !request.resource.data.diff(resource.data)
                          .affectedKeys().hasAny(['rol', 'calificacion_promedio', 'total_resenias', 'estado']))
                    || isAdmin();
```

with:

```
      allow update: if (isOwner(userId) && !request.resource.data.diff(resource.data)
                          .affectedKeys().hasAny(['rol', 'calificacion_promedio', 'total_resenias', 'estado', 'suma_estrellas']))
                    || isAdmin();
```

- [ ] **Step 6: Run the full `usuarios.test.js` suite to verify everything passes**

Run: `cd test_rules && npm test -- usuarios.test.js`
Expected: PASS (all tests green, including the new one).

- [ ] **Step 7: Commit**

```bash
git add functions/index.js firestore.rules test_rules/usuarios.test.js
git commit -m "perf: replace aggregateRatings full rescan with incremental counters"
```

---

## Priority: P2 (Low) — currently broken feature, not exploitable

### Task 8: Grant `shared_with` viewers read access to `vehiculos`

**Files:**
- Modify: `firestore.rules:123-127`
- Modify: `test_rules/vehiculos.test.js` (append tests)

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: nothing consumed by later tasks.

**Why:** `share_vehicle_sheet.dart` writes uids into `vehiculos/{id}.shared_with` (`FieldValue.arrayUnion`/`arrayRemove`, lines 355/376) and `vehicle_service.dart:159` queries `vehiculos` `where('shared_with', arrayContains: userId)`, but `firestore.rules`'s `vehiculos` read rule has no clause granting access to uids in `shared_with` — so the feature is currently non-functional (fails closed), not a vulnerability. Per the Global Constraints, this grant must land as its own `allow read` clause, not by widening `isVehicleOwner()`, so a shared viewer never gains owner-level privileges in `isOwnFinishedService`/reseña creation elsewhere.

- [ ] **Step 1: Write the failing rules tests**

In `test_rules/vehiculos.test.js`, replace the existing `seedVehiculo` helper:

```js
const seedVehiculo = (id, propietario, vinculados = []) => async (s) => {
  await s.collection('vehiculos').doc(id).set({
    id_vehiculo: id,
    id_propietario: propietario,
    placa: 'P-' + id,
    marca: 'AUDI',
    modelo: 'A3',
    anio: 2023,
    talleres_vinculados: vinculados,
  });
};
```

with a version that accepts `shared_with`:

```js
const seedVehiculo = (id, propietario, vinculados = [], sharedWith = []) => async (s) => {
  await s.collection('vehiculos').doc(id).set({
    id_vehiculo: id,
    id_propietario: propietario,
    placa: 'P-' + id,
    marca: 'AUDI',
    modelo: 'A3',
    anio: 2023,
    talleres_vinculados: vinculados,
    shared_with: sharedWith,
  });
};
```

Then append, right before the `});` that closes `describe('vehiculos', ...)`:

```js
  test('un usuario en shared_with SI puede leer el vehiculo', async () => {
    const db = await withRole(env, UIDS.owner2, 'Propietario');
    await seed(env, seedVehiculo('v-compartido', UIDS.owner1, [], [UIDS.owner2]));
    await assertSucceeds(db.collection('vehiculos').doc('v-compartido').get());
  });

  test('un usuario que NO esta en shared_with NO puede leer el vehiculo', async () => {
    const db = await withRole(env, UIDS.owner2, 'Propietario');
    await seed(env, seedVehiculo('v-no-compartido', UIDS.owner1, [], []));
    await assertFails(db.collection('vehiculos').doc('v-no-compartido').get());
  });

  test('un usuario en shared_with NO puede actualizar el vehiculo', async () => {
    const db = await withRole(env, UIDS.owner2, 'Propietario');
    await seed(env, seedVehiculo('v-compartido', UIDS.owner1, [], [UIDS.owner2]));
    await assertFails(
      db.collection('vehiculos').doc('v-compartido').update({ placa: 'ROBADA' }),
    );
  });
```

- [ ] **Step 2: Run the tests to verify the read-grant cases currently fail**

Run: `cd test_rules && npm test -- vehiculos.test.js`
Expected: FAIL — `'un usuario en shared_with SI puede leer el vehiculo'` fails (currently denied); the other two should already pass (they assert the current, correct behavior).

- [ ] **Step 3: Add the `shared_with` read clause**

In `firestore.rules`, inside `match /vehiculos/{vehiculoId}`, replace:

```
      allow read: if isAuthenticated() && (
        resource.data.id_propietario == request.auth.uid
        || isAdmin()
        || (isMecanico() && resource.data.get('talleres_vinculados', []).hasAny([request.auth.uid]))
      );
```

with:

```
      allow read: if isAuthenticated() && (
        resource.data.id_propietario == request.auth.uid
        || isAdmin()
        || (isMecanico() && resource.data.get('talleres_vinculados', []).hasAny([request.auth.uid]))
        // Usuarios con quien el propietario comparte el vehiculo (ver
        // share_vehicle_sheet.dart) obtienen SOLO lectura aqui; a proposito
        // esto NO se agrega a isVehicleOwner(), que sigue significando "es
        // el dueño real" para isOwnFinishedService/servicios/reseñas.
        || resource.data.get('shared_with', []).hasAny([request.auth.uid])
      );
```

- [ ] **Step 4: Run the full `vehiculos.test.js` suite to verify everything passes**

Run: `cd test_rules && npm test -- vehiculos.test.js`
Expected: PASS (all pre-existing tests plus the 3 new ones green).

- [ ] **Step 5: Commit**

```bash
git add firestore.rules test_rules/vehiculos.test.js
git commit -m "fix: grant shared_with viewers read access to vehiculos"
```

---

## Final verification (after all 8 tasks)

- [ ] Run the full Flutter suite: `flutter analyze && flutter test`
  Expected: "No issues found!" and all tests passing.
- [ ] Run the full rules suite: `cd test_rules && npm test`
  Expected: all suites passing.
- [ ] Run `node --check functions/index.js`
  Expected: exit code 0.
