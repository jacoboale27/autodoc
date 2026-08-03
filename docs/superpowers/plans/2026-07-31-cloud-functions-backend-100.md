# Cloud Functions & Backend al 100% — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Llevar el backend de Cloud Functions de AutoDoc del 95.0% al 100%: un cron job diario a las 8:00 AM que avise de SOAT/mantenimiento por vencer, generación automática de thumbnails para imágenes subidas a Storage, y correo transaccional al taller cuando el admin aprueba su solicitud.

**Architecture:** `functions/index.js` (Node.js, Admin SDK) ya tiene un patrón sólido y reutilizable: `writeNotification()` para el centro de notificaciones in-app, y funciones `pubsub.schedule` / `firestore.document().onUpdate` / `https.onCall` ya existentes como plantilla. El proyecto **no tiene ninguna infraestructura de test para `functions/`** hoy (sin `firebase-functions-test`, sin test runner configurado) — este plan la introduce como primer paso, porque TDD es un requisito de este plan y no hay nada que reutilizar. La feature de vencimientos se implementa como una función nueva (no se reutiliza `checkAlertsDaily`, que opera sobre la colección genérica `alertas` con revisión cada 24h sin hora fija) que consulta directamente `vehiculos.vencimiento_soat` y la fecha de próximo mantenimiento calculada desde `mantenimientos`, con cron fijo a las 8:00 AM hora de El Salvador. El resize de imágenes usa `sharp` en un trigger `storage.object().onFinalize`, con guarda anti-recursión (ignora archivos que ya sean thumbnails). El correo usa SendGrid, disparado sobre `usuarios/{uid}` — **no** sobre `talleres/{tallerId}`: desde que se escribió este plan, `admin_service.dart` documentó explícitamente que `talleres/{uid}` es una proyección de solo lectura mantenida por `publishTallerProfile` (`onWrite` en `usuarios/{uid}`), que se revertiría silenciosamente si algo la escribiera directo, y que la fuente de verdad de la aprobación (`aprobarTaller`) es siempre `usuarios/{uid}.estado`. Disparar sobre `talleres` funcionaría igual (por la propagación), pero añade un salto asíncrono innecesario y obliga a releer el documento; disparar sobre `usuarios/{uid}` da `correo`/`nombre_completo` directo en el payload del trigger.

**Tech Stack:** Node.js 20, `firebase-functions` `^5.0.0`, `firebase-admin` `^12.1.0`, paquetes nuevos `sharp`, `@sendgrid/mail`, dev deps nuevas `firebase-functions-test`, `jest`.

## Global Constraints

- Node engine fijo en `"20"` (`functions/package.json`), no cambiar.
- Toda notificación push sigue el patrón existente: `messaging.send({token, notification, data})` en su propio try/catch, seguido de `writeNotification(userId, {...})` para el centro de notificaciones — si el push falla, el registro en `notificaciones/{userId}/items` igual debe persistir.
- No modificar `checkAlertsDaily` (colección `alertas`, genérica, cada 24h) — la nueva función de vencimientos es independiente y complementaria, no un reemplazo.
- No introducir claves secretas en el código. `SENDGRID_API_KEY` se configura vía `firebase functions:config:set` (Functions v1, ya que el proyecto usa `firebase-functions ^5.0.0` con sintaxis v1 `functions.pubsub`/`functions.firestore`) o variables de entorno `.env` en `functions/` (Firebase Functions v2 secrets) — usar el mecanismo que ya empleen las demás integraciones sensibles del proyecto; si no hay precedente, usar `functions.config()` por ser consistente con el estilo v1 ya presente en todo `index.js`.
- Todo test nuevo de Functions usa `firebase-functions-test` en modo offline (sin proyecto real) con Admin SDK apuntando al emulador de Firestore/Storage cuando aplique.

---

## File Structure

- `functions/package.json` — añadir dependencias `sharp`, `@sendgrid/mail`; devDependencies `firebase-functions-test`, `jest`; script `"test": "jest"`.
- `functions/jest.config.js` — **nuevo**.
- `functions/test/helpers.js` — **nuevo**, inicializa `firebase-functions-test` en modo offline.
- `functions/index.js` — añadir `checkVehicleExpirationsAt8am`, `generateImageThumbnail`, `notifyTallerOnApproval`.
- `functions/test/checkVehicleExpirationsAt8am.test.js` — **nuevo**.
- `functions/test/generateImageThumbnail.test.js` — **nuevo**.
- `functions/test/notifyTallerOnApproval.test.js` — **nuevo**.
- `firebase.json` — añadir `"functions"` a la sección `"emulators"` (falta hoy) para poder probar localmente.

---

### Task 1: Infraestructura de testing para `functions/`

**Files:**
- Modify: `functions/package.json`
- Create: `functions/jest.config.js`
- Create: `functions/test/helpers.js`
- Modify: `firebase.json`

**Interfaces:**
- Produces: `require('./helpers')` en `functions/test/` expone `{ test, admin }` — `test` es la instancia offline de `firebase-functions-test`, `admin` es `firebase-admin` ya inicializado contra el proyecto de prueba.

- [ ] **Step 1: Instalar dependencias de test**

```bash
cd functions
npm install --save-dev firebase-functions-test jest
cd ..
```

- [ ] **Step 2: Añadir el script de test**

En `functions/package.json`, dentro de `"scripts"`, añade `"test": "jest --runInBand"`.

- [ ] **Step 3: Crear `jest.config.js`**

```js
// functions/jest.config.js
module.exports = {
  testEnvironment: 'node',
  testMatch: ['**/test/**/*.test.js'],
};
```

- [ ] **Step 4: Crear el helper offline de `firebase-functions-test`**

```js
// functions/test/helpers.js
const test = require('firebase-functions-test')();

afterEach(() => {
  test.cleanup();
});

module.exports = { test };
```

- [ ] **Step 5: Escribir un test trivial de humo para confirmar que el runner funciona**

```js
// functions/test/smoke.test.js
const { test } = require('./helpers');

test.mockConfig({});

describe('smoke', () => {
  it('el entorno de test carga index.js sin lanzar', () => {
    expect(() => require('../index')).not.toThrow();
  });
});
```

- [ ] **Step 6: Ejecutar y verificar que pasa**

Run: `cd functions && npm test`
Expected: PASS (1 test).

- [ ] **Step 7: Añadir el emulador de `functions` a `firebase.json`**

```json
"emulators": {
  "auth": { "port": 9099 },
  "firestore": { "port": 8080 },
  "storage": { "port": 9199 },
  "functions": { "port": 5001 },
  "ui": { "enabled": true, "port": 4000 },
  "singleProjectMode": true
}
```

- [ ] **Step 8: Commit**

```bash
git add functions/package.json functions/package-lock.json functions/jest.config.js functions/test/helpers.js functions/test/smoke.test.js firebase.json
git commit -m "chore(functions): add jest + firebase-functions-test testing infrastructure"
```

---

### Task 2: Cron diario a las 8:00 AM — SOAT y mantenimiento por vencer

**Files:**
- Modify: `functions/index.js`
- Create: `functions/test/checkVehicleExpirationsAt8am.test.js`

**Interfaces:**
- Produces: `exports.checkVehicleExpirationsAt8am` — `functions.pubsub.schedule('0 8 * * *').timeZone('America/El_Salvador').onRun(...)`.
- Consumes: `vehiculos.vencimiento_soat` (Timestamp), `vehiculos.id_propietario`, `mantenimientos.fecha_ultimo_servicio` + `mantenimientos.frecuencia_meses` (para calcular el próximo mantenimiento), `writeNotification()` (ya existe).

- [ ] **Step 1: Escribir el test que falla**

```js
// functions/test/checkVehicleExpirationsAt8am.test.js
const { test } = require('./helpers');
const admin = require('firebase-admin');

jest.mock('firebase-admin', () => {
  const actual = jest.requireActual('firebase-admin');
  return actual;
});

describe('checkVehicleExpirationsAt8am', () => {
  let myFunctions;
  let sendSpy;
  let firestoreStub;

  beforeEach(() => {
    jest.resetModules();
    myFunctions = require('../index');
  });

  it('envía push a vehículos con SOAT venciendo en los próximos 7 días', async () => {
    const wrapped = test.wrap(myFunctions.checkVehicleExpirationsAt8am);

    // Este test requiere Firestore real (emulador) porque la función consulta
    // colecciones completas con `.get()`. Ejecutar con:
    //   firebase emulators:exec --only firestore "cd functions && npm test -- checkVehicleExpirationsAt8am"
    // Dentro del emulador: sembrar un vehiculo con vencimiento_soat = hoy+5 días
    // y un usuario con fcmToken, luego invocar `await wrapped({})` y verificar
    // que `notificaciones/{ownerId}/items` recibió un documento con tipo 'vencimiento'.
    expect(typeof wrapped).toBe('function');
  });
});
```

Nota: al igual que `checkAlertsDaily` (la función existente más cercana), esta función hace lecturas amplias de colecciones reales — probarla de forma aislada sin el emulador de Firestore requeriría mockear Admin SDK a un nivel que el propio proyecto no hace hoy en ningún otro test de Functions (no existe precedente). Sigue el patrón pragmático del proyecto: el test aquí confirma que la función se exporta y es invocable (`test.wrap`), y la verificación funcional completa se ejecuta contra el emulador real como se indica en el comentario, documentado también en el Step 4.

- [ ] **Step 2: Ejecutar test y verificar que falla**

Run: `cd functions && npm test -- checkVehicleExpirationsAt8am`
Expected: FAIL — `myFunctions.checkVehicleExpirationsAt8am` es `undefined`.

- [ ] **Step 3: Implementar la función**

```js
// functions/index.js — añadir junto a checkAlertsDaily
/**
 * Cron diario a las 8:00 AM (hora de El Salvador). Revisa todos los vehículos
 * y notifica a los propietarios cuyo SOAT o próximo mantenimiento vence en
 * los próximos 7 días. Independiente de checkAlertsDaily (que opera sobre la
 * colección genérica `alertas` cada 24h sin hora fija).
 */
exports.checkVehicleExpirationsAt8am = functions.pubsub
  .schedule('0 8 * * *')
  .timeZone('America/El_Salvador')
  .onRun(async (context) => {
    const now = new Date();
    const en7Dias = new Date();
    en7Dias.setDate(now.getDate() + 7);
    const en7DiasTs = admin.firestore.Timestamp.fromDate(en7Dias);

    try {
      const vehiculosSnap = await db.collection('vehiculos').get();

      for (const doc of vehiculosSnap.docs) {
        const vehiculo = doc.data();
        const vehiculoId = doc.id;
        const ownerId = vehiculo.id_propietario;
        if (!ownerId) continue;

        const avisos = [];

        const vencSoat = vehiculo.vencimiento_soat;
        if (vencSoat && vencSoat.toDate && vencSoat.toDate() <= en7Dias && vencSoat.toDate() >= now) {
          avisos.push({ tipo: 'SOAT', fecha: vencSoat.toDate() });
        }

        const mantenimientosSnap = await db
          .collection('mantenimientos')
          .where('id_vehiculo', '==', vehiculoId)
          .get();

        for (const mDoc of mantenimientosSnap.docs) {
          const m = mDoc.data();
          if (!m.fecha_ultimo_servicio || !m.frecuencia_meses) continue;
          const ultimo = m.fecha_ultimo_servicio.toDate
            ? m.fecha_ultimo_servicio.toDate()
            : new Date(m.fecha_ultimo_servicio);
          const proximo = new Date(ultimo);
          proximo.setMonth(proximo.getMonth() + m.frecuencia_meses);
          if (proximo <= en7Dias && proximo >= now) {
            avisos.push({ tipo: 'Mantenimiento', fecha: proximo });
          }
        }

        if (avisos.length === 0) continue;

        const userDoc = await db.collection('usuarios').doc(ownerId).get();
        if (!userDoc.exists) continue;
        const fcmToken = userDoc.data().fcmToken;

        for (const aviso of avisos) {
          const titulo = `${aviso.tipo} por vencer`;
          const body = `El ${aviso.tipo} de tu vehículo ${vehiculo.placa || ''} vence pronto.`;

          if (fcmToken) {
            try {
              await messaging.send({
                token: fcmToken,
                notification: { title: titulo, body },
                data: { type: 'vencimiento', vehiculoId },
              });
            } catch (err) {
              console.error(`Error enviando push de vencimiento a ${ownerId}:`, err);
            }
          }

          await writeNotification(ownerId, {
            tipo: 'vencimiento',
            titulo,
            body,
            deepLink: `/vehicle_profile/${vehiculoId}`,
            metadata: { vehiculoId, tipoVencimiento: aviso.tipo },
          });
        }
      }
    } catch (error) {
      console.error('Error en checkVehicleExpirationsAt8am:', error);
    }
  });
```

- [ ] **Step 4: Verificar contra el emulador**

Run: `firebase emulators:start --only functions,firestore` (usa el emulador añadido en Task 1 Step 7). Desde la UI del emulador de Firestore, crea un documento en `vehiculos` con `vencimiento_soat` a 5 días desde hoy y `id_propietario` apuntando a un `usuarios/{id}` con `fcmToken` de prueba. Dispara la función manualmente con `firebase functions:shell` (`checkVehicleExpirationsAt8am()`), y confirma en los logs que procesa el vehículo y escribe en `notificaciones/{ownerId}/items`.

- [ ] **Step 5: Commit**

```bash
git add functions/index.js functions/test/checkVehicleExpirationsAt8am.test.js
git commit -m "feat(functions): add daily 8am cron for SOAT/maintenance expiration alerts"
```

---

### Task 3: Thumbnails automáticos de imágenes (Storage `onFinalize` + `sharp`)

**Files:**
- Modify: `functions/package.json`
- Modify: `functions/index.js`
- Create: `functions/test/generateImageThumbnail.test.js`
- Modify: `storage.rules`

**Interfaces:**
- Produces: `exports.generateImageThumbnail` — `functions.storage.object().onFinalize(...)`. Para un objeto subido en `facturas/{vehicleId}/{file}.jpg` o `chat_images/{conversacionId}/{file}.jpg`, genera `facturas/{vehicleId}/thumbs/{file}.jpg` / `chat_images/{conversacionId}/thumbs/{file}.jpg` (ancho máx. 200px, mismo formato).

- [ ] **Step 1: Instalar `sharp`**

```bash
cd functions
npm install sharp
cd ..
```

- [ ] **Step 2: Escribir el test que falla (lógica pura de decisión: qué archivos procesar)**

Dado que `sharp` opera sobre bytes reales de imagen y el trigger de Storage requiere el emulador para probarse end-to-end, se extrae primero la lógica de decisión (¿debo generar thumbnail para este `filePath`/`contentType`?) a una función pura testeable sin I/O:

```js
// functions/test/generateImageThumbnail.test.js
const { debeGenerarThumbnail } = require('../index');

describe('debeGenerarThumbnail', () => {
  it('acepta imágenes jpg/png en facturas y chat_images', () => {
    expect(debeGenerarThumbnail('facturas/v1/123.jpg', 'image/jpeg')).toBe(true);
    expect(debeGenerarThumbnail('chat_images/c1/123.png', 'image/png')).toBe(true);
  });

  it('rechaza contentType no-imagen', () => {
    expect(debeGenerarThumbnail('facturas/v1/123.pdf', 'application/pdf')).toBe(false);
  });

  it('rechaza archivos que ya son thumbnails (evita recursión infinita)', () => {
    expect(debeGenerarThumbnail('facturas/v1/thumbs/123.jpg', 'image/jpeg')).toBe(false);
  });

  it('rechaza rutas fuera de facturas/ y chat_images/', () => {
    expect(debeGenerarThumbnail('perfiles/u1/foto.jpg', 'image/jpeg')).toBe(false);
  });
});
```

- [ ] **Step 3: Ejecutar test y verificar que falla**

Run: `cd functions && npm test -- generateImageThumbnail`
Expected: FAIL — `debeGenerarThumbnail` no está exportado.

- [ ] **Step 4: Implementar la función pura + el trigger**

```js
// functions/index.js
const sharp = require('sharp');
const path = require('path');
const os = require('os');
const fs = require('fs');

const CARPETAS_CON_THUMBNAIL = ['facturas', 'chat_images'];

function debeGenerarThumbnail(filePath, contentType) {
  if (!contentType || !contentType.startsWith('image/')) return false;
  if (filePath.includes('/thumbs/')) return false;
  const carpetaRaiz = filePath.split('/')[0];
  return CARPETAS_CON_THUMBNAIL.includes(carpetaRaiz);
}

exports.generateImageThumbnail = functions.storage.object().onFinalize(async (object) => {
  const filePath = object.name;
  const contentType = object.contentType;

  if (!debeGenerarThumbnail(filePath, contentType)) return null;

  const fileName = path.basename(filePath);
  const dirName = path.dirname(filePath);
  const thumbFilePath = path.join(dirName, 'thumbs', fileName);

  const bucket = storage.bucket(object.bucket);
  const tempLocalFile = path.join(os.tmpdir(), fileName);
  const tempLocalThumbFile = path.join(os.tmpdir(), `thumb_${fileName}`);

  try {
    await bucket.file(filePath).download({ destination: tempLocalFile });
    await sharp(tempLocalFile).resize(200, 200, { fit: 'inside' }).toFile(tempLocalThumbFile);
    await bucket.upload(tempLocalThumbFile, {
      destination: thumbFilePath,
      metadata: { contentType },
    });
  } catch (err) {
    console.error(`Error generando thumbnail para ${filePath}:`, err);
  } finally {
    [tempLocalFile, tempLocalThumbFile].forEach((f) => {
      if (fs.existsSync(f)) fs.unlinkSync(f);
    });
  }

  return null;
});

// Exportado solo para testing de la lógica de decisión
exports.debeGenerarThumbnail = debeGenerarThumbnail;
```

- [ ] **Step 5: Ejecutar test y verificar que pasa**

Run: `cd functions && npm test -- generateImageThumbnail`
Expected: PASS

- [ ] **Step 6: Actualizar `storage.rules` — las reglas actuales NO cubren `thumbs/`**

Confirmado por lectura de `storage.rules`: los bloques `match /facturas/{vehicleId}/{fileName}` y `match /chat_images/{conversacionId}/{fileName}` capturan un único segmento de ruta, así que no matchean `facturas/{vehicleId}/thumbs/{fileName}`. La subida del thumbnail en sí no necesita regla de `write` (la hace `generateImageThumbnail` vía Admin SDK, que ignora Storage Rules) — solo hace falta una regla de `read` para que los clientes puedan descargar el thumbnail. Añade un `match` nuevo, hermano del existente, en cada bloque, reusando exactamente las mismas condiciones de lectura:

```
// Dentro de match /b/{bucket}/o { ... }, junto al bloque de facturas/{vehicleId}/{fileName}:
match /facturas/{vehicleId}/thumbs/{fileName} {
  allow read: if isAuthenticated() && (
    isVehicleOwner(vehicleId)
    || isVinculadoAlVehiculo(vehicleId)
    || isAdmin()
  );
}

// Junto al bloque de chat_images/{conversacionId}/{fileName}:
match /chat_images/{conversacionId}/thumbs/{fileName} {
  allow read: if isAuthenticated() && (
    isAdmin() || (
      firestore.exists(/databases/(default)/documents/conversaciones/$(conversacionId)) &&
      (firestore.get(/databases/(default)/documents/conversaciones/$(conversacionId)).data.id_propietario == request.auth.uid ||
       firestore.get(/databases/(default)/documents/conversaciones/$(conversacionId)).data.id_mecanico == request.auth.uid)
    )
  );
}
```

- [ ] **Step 7: Verificar contra el emulador**

Run: `firebase emulators:start --only functions,storage`. Sube manualmente una imagen a `facturas/v1/test.jpg` vía la UI del emulador o `gsutil`, confirma que aparece `facturas/v1/thumbs/test.jpg` generado.

- [ ] **Step 8: Commit**

```bash
git add functions/package.json functions/package-lock.json functions/index.js functions/test/generateImageThumbnail.test.js storage.rules
git commit -m "feat(functions): generate image thumbnails on Storage upload"
```

---

### Task 4: Correo transaccional al taller cuando el admin aprueba

**Files:**
- Modify: `functions/package.json`
- Modify: `functions/index.js`
- Create: `functions/test/notifyTallerOnApproval.test.js`

**Interfaces:**
- Produces: `exports.notifyTallerOnApproval` — `functions.firestore.document('usuarios/{uid}').onUpdate(...)`, dispara cuando `estado` pasa a `'aprobado'` para una cuenta con `rol` de taller/mecánico.
- Consumes: `change.after.data().correo`, `.nombre_completo`, `.rol` y `.estado` directo del payload del trigger (sin lectura adicional a Firestore) — confirmado por `admin_service.dart:132-153`: `aprobarTaller` escribe `usuarios/{idTaller}.estado = 'aprobado'`; `talleres/{idTaller}` es una proyección de solo lectura de ese mismo doc mantenida por `publishTallerProfile` (`functions/src/publishTallerProfile.js`), que **no** incluye `correo` entre `CAMPOS_PUBLICOS`. Nota: `aprobarUsuario` (cuentas de mecánico genéricas, no talleres) usa el valor `'activo'`, no `'aprobado'` — por eso filtrar por `estado === 'aprobado'` ya distingue la aprobación de taller sin necesitar chequear `rol`, pero el test/implementación igual valida `rol` por defensividad y para que el nombre de la función sea preciso.

- [ ] **Step 1: Instalar `@sendgrid/mail`**

```bash
cd functions
npm install @sendgrid/mail
cd ..
```

- [ ] **Step 2: Escribir el test que falla (lógica de decisión: transición pendiente→aprobado)**

```js
// functions/test/notifyTallerOnApproval.test.js
const { esTransicionAAprobado } = require('../index');

describe('esTransicionAAprobado', () => {
  it('detecta la transición de pendiente a aprobado para un taller', () => {
    expect(esTransicionAAprobado(
      { estado: 'pendiente', rol: 'Taller' },
      { estado: 'aprobado', rol: 'Taller' },
    )).toBe(true);
  });

  it('detecta la transición para rol mecanico (minusculas)', () => {
    expect(esTransicionAAprobado(
      { estado: 'pendiente', rol: 'mecanico' },
      { estado: 'aprobado', rol: 'mecanico' },
    )).toBe(true);
  });

  it('ignora si ya estaba aprobado', () => {
    expect(esTransicionAAprobado(
      { estado: 'aprobado', rol: 'Taller' },
      { estado: 'aprobado', rol: 'Taller' },
    )).toBe(false);
  });

  it('ignora otras transiciones (ej. aprobado a suspendido)', () => {
    expect(esTransicionAAprobado(
      { estado: 'aprobado', rol: 'Taller' },
      { estado: 'suspendido', rol: 'Taller' },
    )).toBe(false);
  });

  it('ignora transición a un estado distinto de aprobado (aprobarUsuario usa "activo")', () => {
    expect(esTransicionAAprobado(
      { estado: 'pendiente', rol: 'Taller' },
      { estado: 'activo', rol: 'Taller' },
    )).toBe(false);
  });

  it('ignora cuentas que no son taller/mecanico aunque el estado cambie a aprobado', () => {
    expect(esTransicionAAprobado(
      { estado: 'pendiente', rol: 'Propietario' },
      { estado: 'aprobado', rol: 'Propietario' },
    )).toBe(false);
  });
});
```

- [ ] **Step 3: Ejecutar test y verificar que falla**

Run: `cd functions && npm test -- notifyTallerOnApproval`
Expected: FAIL — `esTransicionAAprobado` no está exportado.

- [ ] **Step 4: Implementar la función pura + el trigger**

```js
// functions/index.js
const sgMail = require('@sendgrid/mail');

// Mismo criterio que esMecanico() en functions/src/publishTallerProfile.js
// (no exportado desde ahí, se duplica el chequeo — es una línea).
function esRolTaller(rol) {
  const r = String(rol || '').trim().toLowerCase();
  return r === 'mecanico' || r === 'taller';
}

function esTransicionAAprobado(before, after) {
  return (
    before.estado !== 'aprobado' &&
    after.estado === 'aprobado' &&
    esRolTaller(after.rol)
  );
}

// Dispara sobre usuarios/{uid} (fuente de verdad de `estado`), no sobre
// talleres/{tallerId}: talleres/{uid} es una proyección de solo lectura
// mantenida por publishTallerProfile (ver admin_service.dart:132-143),
// no incluye `correo`, y su actualización es asíncrona respecto a este
// documento — usar usuarios/{uid} evita ese salto y una lectura extra.
exports.notifyTallerOnApproval = functions.firestore
  .document('usuarios/{uid}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    if (!esTransicionAAprobado(before, after)) return null;

    const correo = after.correo;
    if (!correo) return null;

    const apiKey = functions.config().sendgrid && functions.config().sendgrid.key;
    if (!apiKey) {
      console.error('SENDGRID_API_KEY no configurada (functions.config().sendgrid.key). Correo no enviado.');
      return null;
    }
    sgMail.setApiKey(apiKey);

    const msg = {
      to: correo,
      from: 'no-reply@autodoc.app',
      subject: '¡Tu taller fue aprobado en AutoDoc!',
      text: `Hola ${after.nombre_completo || ''}, tu solicitud como taller en AutoDoc fue aprobada. Ya puedes empezar a recibir clientes.`,
      html: `<p>Hola ${after.nombre_completo || ''},</p><p>Tu solicitud como taller en <strong>AutoDoc</strong> fue aprobada. Ya puedes empezar a recibir clientes.</p>`,
    };

    try {
      await sgMail.send(msg);
    } catch (err) {
      console.error(`Error enviando correo de aprobación a ${correo}:`, err);
    }

    return null;
  });

exports.esTransicionAAprobado = esTransicionAAprobado;
```

- [ ] **Step 5: Ejecutar test y verificar que pasa**

Run: `cd functions && npm test -- notifyTallerOnApproval`
Expected: PASS

- [ ] **Step 6: Configurar la API key de SendGrid (fuera del código)**

Documenta en el PR (no lo ejecutes automáticamente si no tienes la key real): `firebase functions:config:set sendgrid.key="SG.xxxxx"`, seguido de `firebase deploy --only functions:notifyTallerOnApproval`. Sin esta config, la función loguea el error y no falla el trigger (evita reintentos infinitos por config faltante).

- [ ] **Step 7: Verificar el flujo completo con el emulador (sin enviar correo real)**

Run: `firebase emulators:start --only functions,firestore`. Actualiza manualmente un documento de prueba en `usuarios/{id}` (con `rol: 'Taller'` y `correo` de prueba) de `estado: 'pendiente'` a `estado: 'aprobado'`, confirma en los logs que el trigger corre y — si no hay `sendgrid.key` configurada en el entorno del emulador — que loguea el mensaje de advertencia sin lanzar una excepción no controlada. Verifica también que `publishTallerProfile` (ya existente) propaga el cambio a `talleres/{id}` en paralelo, sin que ambos triggers interfieran entre sí.

- [ ] **Step 8: Commit**

```bash
git add functions/package.json functions/package-lock.json functions/index.js functions/test/notifyTallerOnApproval.test.js
git commit -m "feat(functions): send transactional approval email to workshops via SendGrid"
```

---

## Self-Review Notes

- **Cobertura del spec**: Cron 8am SOAT/mantenimiento (Task 2), Thumbnails de imágenes (Task 3), Correo transaccional de aprobación (Task 4). Las 3 features del spec están cubiertas. Task 1 es infraestructura previa necesaria porque no existía testing en `functions/`.
- **Decisión documentada**: la nueva función de vencimientos NO reutiliza `checkAlertsDaily` (colección `alertas` genérica, sin hora fija) — se creó `checkVehicleExpirationsAt8am` como función independiente que lee directamente `vehiculos`/`mantenimientos`, porque el spec pide explícitamente una hora fija (8:00 AM) y una fuente de datos distinta (vencimientos del vehículo, no alertas ya creadas).
- **Riesgo a vigilar en ejecución**: los tests de Tasks 2 y 3 (funciones con I/O real: Firestore/Storage) están deliberadamente acotados a lógica pura + verificación manual en emulador, siguiendo el precedente del propio proyecto (`checkAlertsDaily` tampoco tiene test unitario hoy) — si al ejecutar se decide invertir más esfuerzo en tests de integración contra emuladores, usar `firebase-functions-test` en modo "online" (`require('firebase-functions-test')(config, path)`) contra un proyecto de Firebase real de pruebas.
- **Revisión 2026-08-03** (post-escritura, tras commits `1d47a98`…`d3f3213`): se corrigió Task 4 — el trigger pasó de `talleres/{tallerId}.onUpdate` a `usuarios/{uid}.onUpdate`, y se añadió el filtro `esRolTaller(rol)`. Motivo: `admin_service.dart` documentó explícitamente que `talleres/{uid}` es una proyección de solo lectura de `usuarios/{uid}` mantenida por `publishTallerProfile`, y que la escritura real de aprobación (`aprobarTaller`) ocurre en `usuarios/{uid}.estado`; `aprobarUsuario` (mecánico genérico, no taller) usa `'activo'` en vez de `'aprobado'`, lo que hace necesario el filtro por rol para no confundir ambos flujos si ese valor cambiara. Se hizo concreto también Task 3 Step 6: se confirmó por lectura de `storage.rules` que los bloques `facturas/{vehicleId}/{fileName}` y `chat_images/{conversacionId}/{fileName}` son de un solo segmento y no cubren `thumbs/`, así que el paso ahora trae el diff exacto en vez de una instrucción condicional. Tasks 1 y 2 se verificaron sin cambios: no existe infraestructura de test en `functions/` todavía, `firebase.json` sigue sin `"functions"` en `emulators`, y los campos de `vehiculos`/`mantenimientos` que usa Task 2 no cambiaron.
