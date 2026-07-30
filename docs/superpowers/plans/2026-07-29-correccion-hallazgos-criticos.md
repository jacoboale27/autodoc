# Corrección de hallazgos críticos de la auditoría de producción — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cerrar los ocho hallazgos de severidad Crítica de la auditoría del 29/07/2026 — fuga de datos entre inquilinos, cinco pantallas en blanco, imposibilidad de desplegar correcciones, dependencia de CDN externa para renderizar, Storage sin límites, ausencia de App Check y de separación de entornos — dejando cada corrección respaldada por un test automatizado.

**Architecture:** El plan se ordena por dependencia, no por severidad. Primero las correcciones de configuración que **restauran la capacidad de desplegar** (Fase A), porque sin ellas ninguna corrección posterior llega a los usuarios. Después se construye la **suite de tests de reglas** (Fase B), que es el instrumento de medición: sin ella no se puede afirmar que la fuga esté cerrada. Solo entonces se toca el modelo de datos y las reglas (Fase C), porque la regla insegura de `usuarios` está *impuesta* por el hecho de que el directorio de talleres lee de esa colección; cerrarla antes de mover los datos rompe el producto. Fases D y E corrigen enrutado/autenticación y endurecen el entorno.

**Tech Stack:** Flutter 3.32 / Dart SDK ^3.11.4 · Firebase (Auth, Firestore, Storage, Functions v1, FCM, Crashlytics, App Check) · `go_router` 17.2 · `provider` 6.1 · Node 20 para Cloud Functions y para la suite de reglas · `@firebase/rules-unit-testing` sobre el emulador de Firestore · `firebase-tools` (ya instalado globalmente) · Playwright 1.62 para verificación end-to-end.

## Global Constraints

- Proyecto Firebase actual: `autodoc-6ef5a`. Es **el único** declarado en `.firebaserc` y contiene datos reales. **Ninguna tarea de este plan escribe en él**; todas las pruebas usan el emulador.
- Nombres de colección: usar siempre `FirestoreCollections` (`lib/core/constants/firestore_collections.dart`). Valores literales: `usuarios`, `talleres`, `vehiculos`, `servicios`, `alertas`, `resenias`, `conversaciones`, `reservas`, `cotizaciones`, `mantenimientos`, `historial_mantenimientos`, `admin_logs`, `mensajes`.
- Roles en Firestore, tal cual están escritos en los documentos: `'Propietario'`, `'Mecanico'`, `'Taller'`, `'Administrador'`, `'admin'`. La normalización vive en `_normalizeRole` (`lib/core/router/app_router.dart:96-102`) y no se modifica.
- `UserModel.estado` (`lib/core/models/user_model.dart:14`) tiene **valor por defecto `'activo'`** cuando el campo falta (`:149`). Este comportamiento *fail-open* se corrige en la Tarea 13; hasta entonces, asumirlo.
- Idioma de todo texto visible al usuario: **español**, y **obligatoriamente** vía `context.l10n` (`lib/l10n/`). No se admiten cadenas literales nuevas en la UI.
- Secretos: exclusivamente vía `--dart-define` leído por `lib/config/secrets.dart`. Prohibido añadir claves literales a ningún archivo versionado.
- Commits: uno por tarea como mínimo, en formato Conventional Commits (`fix:`, `feat:`, `test:`, `chore:`, `security:`), siguiendo el estilo del historial existente.
- No trabajar sobre `main`. Crear la rama `fix/auditoria-criticos` antes de la Tarea 1.

---

## Estructura de archivos

**Archivos nuevos**

| Archivo | Responsabilidad |
|---|---|
| `test_rules/package.json` | Dependencias y script de la suite de reglas. Aislado de `functions/` para no contaminar el bundle de despliegue. |
| `test_rules/usuarios.test.js` | Fija el alcance de lectura/escritura de `usuarios` por rol. |
| `test_rules/vehiculos.test.js` | Fija el aislamiento de `vehiculos` entre propietarios y talleres. |
| `test_rules/mecanico-scope.test.js` | Fija que un taller **no** lee `mantenimientos`, `historial_mantenimientos` ni `alertas` ajenos. |
| `test_rules/talleres-publico.test.js` | Fija qué es legítimamente público en `talleres` y `resenias`. |
| `test_rules/storage.test.js` | Fija límites de tamaño, `contentType` y aislamiento de `facturas`. |
| `test_rules/helpers.js` | Fábrica de contextos autenticados y semillas de datos, compartida por los cinco archivos anteriores. |
| `functions/src/publishTallerProfile.js` | Cloud Function que proyecta los campos públicos de un mecánico desde `usuarios` a `talleres`. |
| `test/core/router/app_router_guard_test.dart` | Tests del enrutado para los huecos detectados (cold-load, `/admin/seed`, estado pendiente). |

**Archivos modificados**

| Archivo | Cambio |
|---|---|
| `firebase.json` | Cabeceras `Cache-Control` correctas; bloque `emulators`. |
| `.github/workflows/ci.yml` | Build con `--no-web-resources-cdn`; job de tests de reglas; puerta de cobertura bloqueante. |
| `.github/workflows/flutter_ci.yml` | Se elimina (duplica `ci.yml` con reglas contradictorias). |
| `web/index.html` | `google-signin-client_id` real; se elimina la etiqueta duplicada de Google Maps. |
| `lib/features/admin/data/services/admin_auth_service.dart` | `signOut()` en las rutas de fallo posteriores a la autenticación. |
| `lib/core/router/app_router.dart` | `/admin/seed` en `_adminRoutes`; el estado de carga de perfil deja de permitir rutas protegidas. |
| `lib/core/models/user_model.dart` | `estado` por defecto pasa a `'pendiente'` para mecánicos. |
| `firestore.rules` | Cierre de `usuarios`; eliminación de las seis cláusulas `|| isMecanico()` sin vínculo; `isMecanico()` exige estado aprobado. |
| `storage.rules` | Límites de tamaño y `contentType`; aislamiento de `facturas`; extensiones de perfil ampliadas. |
| `lib/features/dashboard/presentation/pages/vehicle_profile_screen.dart` | Argumento por parámetro de ruta y estado de error. |
| `lib/features/dashboard/presentation/pages/service_history_screen.dart` | Ídem. |
| `lib/features/mechanic/presentation/pages/initiate_service_screen.dart` | Ídem. |
| `lib/features/chat/presentation/pages/reserva_detail_screen.dart` | Ídem. |
| `lib/features/dashboard/presentation/pages/workshop_directory_screen.dart` | Lee de `talleres` en lugar de `usuarios`. |
| `assets/images/default_vehicle.png` | Se renombra a `.jpg` (el archivo es un JPEG) y se optimiza. |

---

## Fase A — Restaurar la capacidad de desplegar

> Sin esta fase, cualquier corrección posterior queda atrapada en la caché de los navegadores existentes. Es la fase de mayor retorno del plan y no depende de ninguna otra.

### Task 1: Cabeceras de caché que permitan desplegar correcciones

Corrige **C-04**. Hoy `firebase.json` marca `**/*.@(js|css|...)` como `immutable, max-age=31536000` y `build/web/main.dart.js` **no lleva hash de contenido**, por lo que un navegador que ya abrió la app no volverá a pedirlo durante un año — incluido `flutter_service_worker.js`, que es el mecanismo de invalidación.

**Files:**
- Modify: `firebase.json` (bloque `hosting[0].headers`)

**Interfaces:**
- Consumes: nada.
- Produces: nada en código. Habilita que todas las tareas siguientes sean entregables.

- [ ] **Step 1: Crear la rama de trabajo**

```bash
git checkout -b fix/auditoria-criticos
```

- [ ] **Step 2: Comprobar el problema en el artefacto actual**

```bash
ls -la build/web/main.dart.js build/web/flutter_bootstrap.js build/web/flutter_service_worker.js
```

Esperado: los tres existen y **ninguno** tiene hash en el nombre. Esto confirma que la regla `immutable` sobre `*.js` los alcanza.

- [ ] **Step 3: Reemplazar el bloque `headers` de `hosting[0]`**

Sustituir el array `headers` completo del target `app` por:

```json
      "headers": [
        {
          "source": "/@(index.html|flutter_bootstrap.js|flutter_service_worker.js|main.dart.js|flutter.js|version.json|manifest.json)",
          "headers": [
            { "key": "Cache-Control", "value": "no-cache, max-age=0, must-revalidate" }
          ]
        },
        {
          "source": "/canvaskit/**",
          "headers": [
            { "key": "Cache-Control", "value": "public, max-age=31536000, immutable" }
          ]
        },
        {
          "source": "/assets/**",
          "headers": [
            { "key": "Cache-Control", "value": "public, max-age=604800" }
          ]
        },
        {
          "source": "/icons/**",
          "headers": [
            { "key": "Cache-Control", "value": "public, max-age=604800" }
          ]
        },
        {
          "source": "/**",
          "headers": [
            { "key": "Cache-Control", "value": "no-cache, max-age=0, must-revalidate" }
          ]
        }
      ],
```

Razonamiento de cada regla: los archivos de arranque y el bundle **nunca** se cachean, porque su nombre no cambia entre despliegues; `canvaskit/**` sí es inmutable porque su ruta incluye la revisión del motor; el resto usa una semana, suficiente para el rendimiento y corto para revertir.

- [ ] **Step 4: Validar que el JSON sigue siendo válido**

```bash
node -e "const c=require('./firebase.json'); const h=c.hosting[0].headers; console.log('reglas:', h.length); console.log(JSON.stringify(h[0],null,1));"
```

Esperado: `reglas: 5` y la primera regla mostrando `no-cache` sobre el grupo de arranque.

- [ ] **Step 5: Verificar que ningún patrón deja `main.dart.js` como inmutable**

```bash
node -e "
const h=require('./firebase.json').hosting[0].headers;
const immutable=h.filter(r=>JSON.stringify(r.headers).includes('immutable')).map(r=>r.source);
console.log('patrones inmutables:', immutable);
if (immutable.some(s=>s==='/**'||s.includes('*.js'))) { console.error('FALLO: un patron inmutable alcanza main.dart.js'); process.exit(1); }
console.log('OK: ningun patron inmutable alcanza los archivos sin hash');
"
```

Esperado: `patrones inmutables: [ '/canvaskit/**' ]` y `OK: ...`.

- [ ] **Step 6: Commit**

```bash
git add firebase.json
git commit -m "fix(hosting): no cachear artefactos sin hash para permitir desplegar correcciones

main.dart.js, flutter_bootstrap.js y flutter_service_worker.js no llevan hash
de contenido, por lo que la regla immutable/max-age=31536000 dejaba a los
navegadores existentes ejecutando la version anterior hasta un ano.
Solo /canvaskit/** conserva immutable, ya que su ruta incluye la revision."
```

---

### Task 2: Autoalojar CanvasKit

Corrige **C-05**. `build/web/flutter_bootstrap.js` contiene `gstatic.com/flutter-canvaskit` y `main.dart.js` embebe `flutter-canvaskit/425cfb54.../`: el renderizador se descarga de `www.gstatic.com` en cada visita. Verificado en ejecución: al no alcanzarse ese host, `TypeError: Failed to fetch dynamically imported module` y **la aplicación no pinta nada**. La copia local ya se despliega (39 MB en `build/web`) y nunca se usa.

**Files:**
- Modify: `.github/workflows/ci.yml` (tres pasos `flutter build web`)

**Interfaces:**
- Consumes: nada.
- Produces: builds cuyo `flutter_bootstrap.js` referencia `/canvaskit/` local.

- [ ] **Step 1: Confirmar la dependencia externa en el artefacto actual**

```bash
grep -o "gstatic.com/flutter-canvaskit" build/web/flutter_bootstrap.js | head -1
grep -o "useLocalCanvasKit[^,}]*" build/web/flutter_bootstrap.js | head -1
```

Esperado: aparece `gstatic.com/flutter-canvaskit`. Esto es el fallo a corregir.

- [ ] **Step 2: Añadir el flag a los tres builds de `ci.yml`**

Localizar las tres apariciones de `flutter build web --release` y añadir `--no-web-resources-cdn`:

```yaml
      - name: Build Flutter Web (release)
        run: flutter build web --release --no-web-resources-cdn --dart-define=FLAVOR=dev
```

```yaml
      - name: Build Flutter Web for staging
        run: flutter build web --release --no-web-resources-cdn --dart-define=FLAVOR=staging
```

```yaml
      - name: Build Flutter Web for production
        run: flutter build web --release --no-web-resources-cdn --dart-define=FLAVOR=prod
```

- [ ] **Step 3: Reconstruir localmente y verificar que desaparece la URL externa**

```bash
flutter build web --release --no-web-resources-cdn --dart-define=FLAVOR=dev
grep -c "gstatic.com/flutter-canvaskit" build/web/flutter_bootstrap.js || echo "0 coincidencias (correcto)"
```

Esperado: `0 coincidencias (correcto)`. Si `grep` devuelve un número mayor que 0, el flag no surtió efecto y hay que revisar la versión de Flutter.

- [ ] **Step 4: Verificar que la app arranca sin acceso a gstatic**

```bash
cd "$LOCALAPPDATA/../Local/Temp" 2>/dev/null || cd /tmp
```

Servir el build y comprobar con Playwright que renderiza bloqueando `gstatic.com`:

```javascript
// verify-canvaskit.js
const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch({ headless: true });
  const ctx = await b.newContext();
  await ctx.route('**://www.gstatic.com/**', r => r.abort());
  const p = await ctx.newPage();
  const errs = [];
  p.on('pageerror', e => errs.push(String(e)));
  await p.goto('http://localhost:5000/', { waitUntil: 'load', timeout: 60000 });
  await p.waitForTimeout(20000);
  const txt = await p.evaluate(() => document.body.innerText || '');
  console.log('gstatic bloqueado. Texto renderizado:', JSON.stringify(txt.slice(0, 200)));
  console.log('pageerrors:', errs.length, errs.slice(0, 3));
  if (txt.trim().length === 0) { console.error('FALLO: pantalla en blanco'); process.exit(1); }
  console.log('OK: la app renderiza sin gstatic');
  await b.close();
})();
```

Ejecutar:

```bash
firebase emulators:start --only hosting --project autodoc-6ef5a &
sleep 10
NODE_PATH="$APPDATA/npm/node_modules" node verify-canvaskit.js
```

Esperado: `OK: la app renderiza sin gstatic`.

- [ ] **Step 5: Dejar de desplegar los archivos de símbolos**

En `firebase.json`, dentro de `hosting[0].ignore`, añadir la entrada de símbolos:

```json
      "ignore": [
        "firebase.json",
        "**/.*",
        "**/node_modules/**",
        "**/*.symbols"
      ],
```

Son ~7 MB (`canvaskit.js.symbols`, `skwasm*.symbols`, `wimp.js.symbols`) que nunca se cargan y exponen internos.

- [ ] **Step 6: Commit**

```bash
git add .github/workflows/ci.yml firebase.json
git commit -m "fix(web): autoalojar CanvasKit y excluir archivos de simbolos del despliegue

El bundle descargaba el renderizador de www.gstatic.com; si ese host no es
alcanzable la aplicacion no renderiza nada. La copia local ya se desplegaba
sin usarse. Se excluyen tambien los *.symbols (~7 MB no utilizados)."
```

---

### Task 3: Cerrar la sesión en los fallos de login administrativo

Corrige **H-01**. `admin_auth_service.dart` autentica con `signInWithEmailAndPassword` y **después** comprueba el rol. El comentario del código dice *«Not an admin — sign out and return null»*, pero el código solo hace `return null`: la sesión de Firebase Auth queda establecida mientras la interfaz informa de un login fallido.

**Files:**
- Modify: `lib/features/admin/data/services/admin_auth_service.dart` (método `loginAsAdmin`)
- Test: `test/features/admin/admin_auth_service_test.dart` (crear)

**Interfaces:**
- Consumes: nada.
- Produces: `AdminAuthService.loginAsAdmin(String input, String password)` mantiene su firma `Future<UserModel?>`; cambia su efecto secundario: al devolver `null` después de haber autenticado, la sesión queda cerrada.

- [ ] **Step 1: Escribir el test que falla**

Crear `test/features/admin/admin_auth_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:autodoc/features/admin/data/services/admin_auth_service.dart';

void main() {
  group('AdminAuthService.loginAsAdmin', () {
    test(
      'cierra la sesion cuando el usuario autentica pero NO es administrador',
      () async {
        final auth = MockFirebaseAuth(
          mockUser: MockUser(uid: 'uid-propietario', email: 'p@x.com'),
        );
        final firestore = FakeFirebaseFirestore();
        await firestore.collection('usuarios').doc('uid-propietario').set({
          'id_usuario': 'uid-propietario',
          'correo': 'p@x.com',
          'rol': 'Propietario',
        });

        final service = AdminAuthService(auth: auth, firestore: firestore);
        final result = await service.loginAsAdmin('p@x.com', 'password123');

        expect(result, isNull, reason: 'no es administrador');
        expect(
          auth.currentUser,
          isNull,
          reason: 'un login administrativo fallido no debe dejar sesion viva',
        );
      },
    );

    test('devuelve el UserModel y mantiene la sesion si SI es administrador', () async {
      final auth = MockFirebaseAuth(
        mockUser: MockUser(uid: 'uid-admin', email: 'a@x.com'),
      );
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('usuarios').doc('uid-admin').set({
        'id_usuario': 'uid-admin',
        'correo': 'a@x.com',
        'rol': 'Administrador',
        'nombre_completo': 'Admin',
      });

      final service = AdminAuthService(auth: auth, firestore: firestore);
      final result = await service.loginAsAdmin('a@x.com', 'password123');

      expect(result, isNotNull);
      expect(auth.currentUser, isNotNull);
    });
  });
}
```

- [ ] **Step 2: Añadir las dependencias de test necesarias**

```bash
flutter pub add --dev fake_cloud_firestore firebase_auth_mocks
```

- [ ] **Step 3: Ejecutar el test y confirmar que falla**

```bash
flutter test test/features/admin/admin_auth_service_test.dart
```

Esperado: FALLA. Primero por compilación (`AdminAuthService` no acepta parámetros `auth`/`firestore`), lo que obliga al paso siguiente.

- [ ] **Step 4: Hacer inyectables las dependencias**

Reemplazar las dos declaraciones de campo al inicio de la clase:

```dart
class AdminAuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AdminAuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;
```

Este cambio es también el que permite testear el servicio; sin él la clase solo funciona contra Firebase real.

- [ ] **Step 5: Cerrar la sesión en cada retorno nulo posterior a la autenticación**

En `loginAsAdmin`, sustituir el bloque que va desde `final user = credential.user;` hasta el `return UserModel.fromMap(...)` por:

```dart
      final user = credential.user;
      if (user == null) return null;

      // Validar rol de administrador en Firestore
      final userDoc = await _firestore
          .collection(FirestoreCollections.usuarios)
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        await _auth.signOut();
        return null;
      }

      final data = userDoc.data()!;
      final rol = (data['rol'] as String? ?? '').trim().toLowerCase();

      if (rol != 'administrador' && rol != 'admin') {
        // No es administrador: cerrar la sesion que acabamos de abrir.
        await _auth.signOut();
        return null;
      }

      return UserModel.fromMap(data, user.uid);
```

- [ ] **Step 6: Ejecutar los tests y confirmar que pasan**

```bash
flutter test test/features/admin/admin_auth_service_test.dart
```

Esperado: 2 tests PASAN.

- [ ] **Step 7: Commit**

```bash
git add lib/features/admin/data/services/admin_auth_service.dart test/features/admin/admin_auth_service_test.dart pubspec.yaml pubspec.lock
git commit -m "security: cerrar sesion cuando loginAsAdmin rechaza por rol

loginAsAdmin autenticaba y despues comprobaba el rol, pero no llamaba a
signOut() al rechazar: la UI informaba de login fallido mientras la sesion
de Firebase Auth quedaba viva. El comentario del codigo ya describia el
comportamiento correcto, que no estaba implementado."
```

---

### Task 4: Reparar la inicialización de Google Sign-In y la carga duplicada de Maps

Corrige la causa raíz común de **C-03** (`TypeError: Cannot read properties of undefined (reading 'VL')`, observado en `/user_profile`, `/service_history`, `/reserva_detail`, `/task_complete`, `/admin/usuarios`, `/mechanic_reviews` **y en la propia página 404**) y **S-03** (`You have included the Google Maps JavaScript API multiple times on this page`).

**Files:**
- Modify: `web/index.html:24` y `web/index.html:37`
- Modify: `lib/config/secrets.dart` (añadir el getter)
- Modify: `.env.example`

**Interfaces:**
- Consumes: nada.
- Produces: `AppSecrets.googleSignInClientIdWeb` → `String` (getter estático).

- [ ] **Step 1: Reproducir el error `'VL'` antes del cambio**

```javascript
// verify-vl.js
const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch({ headless: true });
  const p = await (await b.newContext()).newPage();
  const errs = [];
  p.on('pageerror', e => errs.push(String(e)));
  await p.goto('http://localhost:51046/no-existe-404', { waitUntil: 'load', timeout: 90000 });
  await p.waitForTimeout(25000);
  console.log('pageerrors:', JSON.stringify(errs, null, 1));
  console.log("contiene 'VL':", errs.some(e => e.includes("'VL'")));
  await b.close();
})();
```

```bash
NODE_PATH="$APPDATA/npm/node_modules" node verify-vl.js
```

Esperado antes del cambio: `contiene 'VL': true`.

- [ ] **Step 2: Añadir el getter del client ID a `secrets.dart`**

Al final de la clase `AppSecrets`, antes del cierre:

```dart
  // Google Sign-In (web)
  static String get googleSignInClientIdWeb =>
      const String.fromEnvironment('GOOGLE_SIGNIN_CLIENT_ID_WEB', defaultValue: '');
```

- [ ] **Step 3: Documentar la variable en `.env.example`**

Añadir al final del archivo:

```
# Google Sign-In (web) — Client ID OAuth 2.0 de tipo "Aplicación web"
GOOGLE_SIGNIN_CLIENT_ID_WEB=
```

- [ ] **Step 4: Sustituir el marcador de `index.html` y eliminar la etiqueta duplicada de Maps**

Reemplazar la línea 24:

```html
  <meta name="google-signin-client_id" content="$GOOGLE_SIGNIN_CLIENT_ID_WEB">
```

Y **eliminar por completo** la línea 37:

```html
  <script src="https://maps.googleapis.com/maps/api/js?key=***REMOVED-GOOGLE-MAPS-API-KEY***"></script>
```

El plugin `google_maps_flutter_web` carga la API por sí mismo; la etiqueta manual provoca la doble carga (facturación duplicada de cargas de mapa) y además fija una clave literal en el repositorio. La sustitución de `$GOOGLE_SIGNIN_CLIENT_ID_WEB` la realiza el paso de build de la Tarea 5.

- [ ] **Step 5: Verificar que la clave de Maps ya no está en el árbol de trabajo**

```bash
grep -rn "AIzaSyBp0xI7P" web/ lib/ || echo "OK: la clave ya no esta en el arbol de trabajo"
```

Esperado: `OK: la clave ya no esta en el arbol de trabajo`.

> La clave **sigue en el historial de git** (introducida en `89e9f6b`). Eliminarla del árbol no la revoca: la rotación se hace en la Tarea 16.

- [ ] **Step 6: Commit**

```bash
git add web/index.html lib/config/secrets.dart .env.example
git commit -m "fix(web): inicializar Google Sign-In y eliminar la carga duplicada de Maps

El marcador YOUR_GOOGLE_CLIENT_ID sin sustituir dejaba Google Identity
Services sin inicializar, provocando 'TypeError: ... reading VL' en cada
carga de pagina y dejando en blanco /user_profile, /service_history y
/reserva_detail. Se elimina tambien la etiqueta manual de Maps, que
duplicaba la carga de la API y fijaba una clave literal en el repositorio."
```

---

### Task 5: Inyectar el client ID en el build y reparar la imagen por defecto

Cierra la Tarea 4 (la sustitución del marcador) y corrige **F-13**: `assets/images/default_vehicle.png` **es un JPEG** (`file` → `JPEG image data, JFIF standard 1.01, 1024x1024`; bytes iniciales `ffd8ffe0`), lo que produce `EncodingError: The source image cannot be decoded` en cada carga del dashboard.

**Files:**
- Modify: `.github/workflows/ci.yml` (paso de sustitución antes de cada build)
- Rename: `assets/images/default_vehicle.png` → `assets/images/default_vehicle.jpg`
- Modify: los archivos Dart que referencian esa ruta

**Interfaces:**
- Consumes: `AppSecrets.googleSignInClientIdWeb` (Tarea 4).
- Produces: asset `assets/images/default_vehicle.jpg`.

- [ ] **Step 1: Confirmar la discrepancia de formato**

```bash
file assets/images/default_vehicle.png
head -c 4 assets/images/default_vehicle.png | xxd
```

Esperado: `JPEG image data, JFIF standard 1.01` y bytes `ffd8 ffe0` (firma JPEG, no PNG).

- [ ] **Step 2: Renombrar el asset y actualizar todas las referencias**

```bash
git mv assets/images/default_vehicle.png assets/images/default_vehicle.jpg
grep -rln "default_vehicle.png" lib/ pubspec.yaml
```

Sustituir `default_vehicle.png` por `default_vehicle.jpg` en cada archivo listado por el `grep`.

- [ ] **Step 3: Verificar que no queda ninguna referencia obsoleta**

```bash
grep -rn "default_vehicle.png" lib/ pubspec.yaml test/ && echo "FALLO: quedan referencias" || echo "OK: sin referencias obsoletas"
```

Esperado: `OK: sin referencias obsoletas`.

- [ ] **Step 4: Añadir el paso de sustitución del client ID en `ci.yml`**

Insertar este paso **antes** de cada uno de los tres `flutter build web`:

```yaml
      - name: Inject Google Sign-In client ID into web/index.html
        run: |
          if [ -z "${{ secrets.GOOGLE_SIGNIN_CLIENT_ID_WEB }}" ]; then
            echo "❌ Falta el secreto GOOGLE_SIGNIN_CLIENT_ID_WEB"
            exit 1
          fi
          sed -i "s|\$GOOGLE_SIGNIN_CLIENT_ID_WEB|${{ secrets.GOOGLE_SIGNIN_CLIENT_ID_WEB }}|g" web/index.html
          grep -q 'YOUR_GOOGLE_CLIENT_ID' web/index.html && { echo "❌ Quedo el marcador sin sustituir"; exit 1; } || true
          echo "✅ client ID inyectado"
```

El paso **falla el build** si el secreto no está configurado, de modo que el marcador no puede volver a llegar a producción sin sustituir.

- [ ] **Step 5: Verificar en local que el dashboard ya no lanza `EncodingError`**

Reiniciar la aplicación y comprobar:

```javascript
// verify-encoding.js
const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch({ headless: true });
  const p = await (await b.newContext()).newPage();
  const enc = [];
  p.on('console', m => { if (m.text().includes('EncodingError')) enc.push(m.text()); });
  await p.goto('http://localhost:51046/', { waitUntil: 'load', timeout: 90000 });
  await p.waitForTimeout(30000);
  console.log('EncodingError encontrados:', enc.length);
  if (enc.length > 0) { console.error('FALLO:', enc[0]); process.exit(1); }
  console.log('OK: sin EncodingError');
  await b.close();
})();
```

Esperado: `OK: sin EncodingError`.

- [ ] **Step 6: Commit**

```bash
git add -A assets/images lib pubspec.yaml .github/workflows/ci.yml
git commit -m "fix(assets): default_vehicle era un JPEG con extension .png

Provocaba 'EncodingError: The source image cannot be decoded' en cada carga
del dashboard. Se anade tambien el paso de CI que inyecta
GOOGLE_SIGNIN_CLIENT_ID_WEB y falla el build si el marcador no se sustituye."
```

---

## Fase B — Construir el instrumento de medición

> **Esta fase es la puerta de todo lo que sigue.** La auditoría no pudo dirimir si la fuga de `vehiculos` proviene de la regla o del comportamiento del endpoint REST, y nadie en el proyecto puede afirmar hoy qué protegen sus reglas. Cinco commits de seguridad consecutivos no detectaron el problema porque no hay ninguna prueba. Sin la Fase B, cualquier corrección de la Fase C es una afirmación sin verificar.

### Task 6: Suite de tests de las reglas de Firestore y Storage

Corrige **T-02** y establece la matriz de la auditoría como test de regresión.

**Files:**
- Create: `test_rules/package.json`, `test_rules/helpers.js`, `test_rules/usuarios.test.js`, `test_rules/vehiculos.test.js`, `test_rules/mecanico-scope.test.js`, `test_rules/talleres-publico.test.js`
- Modify: `firebase.json` (bloque `emulators`)
- Modify: `.gitignore`

**Interfaces:**
- Consumes: `firestore.rules`, `storage.rules` (sin modificar todavía).
- Produces: helpers reutilizados por la Tarea 10:
  - `withRole(env, uid, rol, extra = {})` → `Promise<Firestore>` — contexto autenticado cuyo documento `usuarios/{uid}` ya existe con ese `rol`.
  - `anon(env)` → `Firestore` — contexto sin autenticar.
  - `seed(env, fn)` → `Promise<void>` — siembra datos saltándose las reglas.
  - `UIDS` → `{ owner1, owner2, taller1, taller2, admin }` — identificadores fijos.

- [ ] **Step 1: Añadir el bloque `emulators` a `firebase.json`**

Al nivel superior del objeto:

```json
  "emulators": {
    "auth": { "port": 9099 },
    "firestore": { "port": 8080 },
    "storage": { "port": 9199 },
    "ui": { "enabled": true, "port": 4000 },
    "singleProjectMode": true
  }
```

- [ ] **Step 2: Crear `test_rules/package.json`**

```json
{
  "name": "autodoc-rules-tests",
  "private": true,
  "type": "commonjs",
  "scripts": {
    "test": "firebase emulators:exec --only firestore,storage --project autodoc-rules-test \"jest --runInBand --forceExit\""
  },
  "devDependencies": {
    "@firebase/rules-unit-testing": "^3.0.4",
    "jest": "^29.7.0"
  }
}
```

Se usa un `projectId` inventado (`autodoc-rules-test`) para que sea imposible tocar `autodoc-6ef5a`.

- [ ] **Step 3: Crear `test_rules/helpers.js`**

```javascript
const fs = require('fs');
const path = require('path');
const { initializeTestEnvironment } = require('@firebase/rules-unit-testing');

const UIDS = {
  owner1: 'uid-owner-1',
  owner2: 'uid-owner-2',
  taller1: 'uid-taller-1',
  taller2: 'uid-taller-2',
  admin: 'uid-admin-1',
};

async function makeEnv() {
  return initializeTestEnvironment({
    projectId: 'autodoc-rules-test',
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
    storage: {
      rules: fs.readFileSync(path.join(__dirname, '..', 'storage.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 9199,
    },
  });
}

// Ejecuta una funcion con las reglas desactivadas, para sembrar datos.
async function seed(env, fn) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await fn(ctx.firestore());
  });
}

// Devuelve un Firestore autenticado como `uid`, con su documento de usuario ya creado.
async function withRole(env, uid, rol, extra = {}) {
  await seed(env, async (db) => {
    await db.collection('usuarios').doc(uid).set({
      id_usuario: uid,
      correo: `${uid}@test.com`,
      nombre_completo: `Usuario ${uid}`,
      rol,
      estado: 'activo',
      ...extra,
    });
  });
  return env.authenticatedContext(uid).firestore();
}

function anon(env) {
  return env.unauthenticatedContext().firestore();
}

module.exports = { makeEnv, seed, withRole, anon, UIDS };
```

- [ ] **Step 4: Crear `test_rules/usuarios.test.js`**

```javascript
const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { makeEnv, seed, withRole, anon, UIDS } = require('./helpers');

let env;
beforeAll(async () => { env = await makeEnv(); });
afterAll(async () => { await env.cleanup(); });
beforeEach(async () => { await env.clearFirestore(); });

describe('usuarios', () => {
  test('un propietario NO puede listar toda la coleccion de usuarios', async () => {
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await seed(env, async (s) => {
      await s.collection('usuarios').doc(UIDS.owner2).set({
        id_usuario: UIDS.owner2, correo: 'victima@x.com', nombre_completo: 'Victima', rol: 'Propietario',
      });
    });
    await assertFails(db.collection('usuarios').get());
  });

  test('un taller NO puede listar toda la coleccion de usuarios', async () => {
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(db.collection('usuarios').get());
  });

  test('un propietario NO puede leer el documento de otro usuario', async () => {
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await seed(env, async (s) => {
      await s.collection('usuarios').doc(UIDS.owner2).set({ id_usuario: UIDS.owner2, rol: 'Propietario' });
    });
    await assertFails(db.collection('usuarios').doc(UIDS.owner2).get());
  });

  test('un usuario SI puede leer su propio documento', async () => {
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertSucceeds(db.collection('usuarios').doc(UIDS.owner1).get());
  });

  test('un administrador SI puede listar usuarios', async () => {
    const db = await withRole(env, UIDS.admin, 'Administrador');
    await assertSucceeds(db.collection('usuarios').get());
  });

  test('un usuario NO puede elevar su propio rol', async () => {
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db.collection('usuarios').doc(UIDS.owner1).update({ rol: 'Administrador' }),
    );
  });

  test('un usuario NO puede escribir sus metricas de reputacion', async () => {
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(
      db.collection('usuarios').doc(UIDS.taller1).update({ calificacion_promedio: 5 }),
    );
  });

  test('un usuario SI puede editar su nombre', async () => {
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertSucceeds(
      db.collection('usuarios').doc(UIDS.owner1).update({ nombre_completo: 'Nuevo Nombre' }),
    );
  });

  test('sin autenticar NO se puede leer usuarios', async () => {
    await assertFails(anon(env).collection('usuarios').get());
  });
});
```

- [ ] **Step 5: Crear `test_rules/vehiculos.test.js`**

```javascript
const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { makeEnv, seed, withRole, anon, UIDS } = require('./helpers');

let env;
beforeAll(async () => { env = await makeEnv(); });
afterAll(async () => { await env.cleanup(); });
beforeEach(async () => { await env.clearFirestore(); });

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

describe('vehiculos', () => {
  test('un propietario NO puede listar todos los vehiculos', async () => {
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await seed(env, seedVehiculo('v-ajeno', UIDS.owner2));
    await assertFails(db.collection('vehiculos').get());
  });

  test('un propietario NO puede leer el vehiculo de otro', async () => {
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await seed(env, seedVehiculo('v-ajeno', UIDS.owner2));
    await assertFails(db.collection('vehiculos').doc('v-ajeno').get());
  });

  test('un propietario SI puede leer su propio vehiculo', async () => {
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await seed(env, seedVehiculo('v-mio', UIDS.owner1));
    await assertSucceeds(db.collection('vehiculos').doc('v-mio').get());
  });

  test('un propietario SI puede listar filtrando por su propio id', async () => {
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await seed(env, seedVehiculo('v-mio', UIDS.owner1));
    await assertSucceeds(
      db.collection('vehiculos').where('id_propietario', '==', UIDS.owner1).get(),
    );
  });

  test('un taller NO vinculado NO puede leer el vehiculo', async () => {
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await seed(env, seedVehiculo('v-ajeno', UIDS.owner1, []));
    await assertFails(db.collection('vehiculos').doc('v-ajeno').get());
  });

  test('un taller vinculado SI puede leer el vehiculo', async () => {
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await seed(env, seedVehiculo('v-vinc', UIDS.owner1, [UIDS.taller1]));
    await assertSucceeds(db.collection('vehiculos').doc('v-vinc').get());
  });

  test('un taller vinculado solo puede actualizar kilometraje_actual', async () => {
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await seed(env, seedVehiculo('v-vinc', UIDS.owner1, [UIDS.taller1]));
    await assertSucceeds(
      db.collection('vehiculos').doc('v-vinc').update({ kilometraje_actual: 5000 }),
    );
    await assertFails(db.collection('vehiculos').doc('v-vinc').update({ placa: 'ROBADA' }));
  });

  test('sin autenticar NO se puede leer vehiculos', async () => {
    await seed(env, seedVehiculo('v1', UIDS.owner1));
    await assertFails(anon(env).collection('vehiculos').get());
  });
});
```

- [ ] **Step 6: Crear `test_rules/mecanico-scope.test.js`**

```javascript
const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { makeEnv, seed, withRole, UIDS } = require('./helpers');

let env;
beforeAll(async () => { env = await makeEnv(); });
afterAll(async () => { await env.cleanup(); });
beforeEach(async () => { await env.clearFirestore(); });

// Vehiculo del propietario 1, vinculado UNICAMENTE al taller 1.
const seedEscenario = async () => {
  await seed(env, async (s) => {
    await s.collection('vehiculos').doc('v1').set({
      id_vehiculo: 'v1', id_propietario: UIDS.owner1, placa: 'P-1',
      talleres_vinculados: [UIDS.taller1],
    });
    await s.collection('mantenimientos').doc('m1').set({
      id_vehiculo: 'v1', nombre: 'Pastillas de Freno', frecuencia_km: 20000,
    });
    await s.collection('historial_mantenimientos').doc('h1').set({
      id_vehiculo: 'v1', id_taller: UIDS.taller1, nombre_tarea: 'Filtro de Aceite',
    });
    await s.collection('alertas').doc('a1').set({ id_vehiculo: 'v1', tipo: 'soat' });
  });
};

describe('alcance del rol mecanico (regresion de la fuga verificada)', () => {
  test('un taller NO vinculado NO lee mantenimientos ajenos', async () => {
    await seedEscenario();
    const db = await withRole(env, UIDS.taller2, 'Taller');
    await assertFails(db.collection('mantenimientos').get());
    await assertFails(db.collection('mantenimientos').doc('m1').get());
  });

  test('un taller NO vinculado NO lee historial_mantenimientos ajeno', async () => {
    await seedEscenario();
    const db = await withRole(env, UIDS.taller2, 'Taller');
    await assertFails(db.collection('historial_mantenimientos').get());
    await assertFails(db.collection('historial_mantenimientos').doc('h1').get());
  });

  test('un taller NO vinculado NO puede MODIFICAR historial ajeno', async () => {
    await seedEscenario();
    const db = await withRole(env, UIDS.taller2, 'Taller');
    await assertFails(
      db.collection('historial_mantenimientos').doc('h1').update({ descripcion: 'falsificado' }),
    );
  });

  test('un taller NO vinculado NO puede CREAR historial sobre un vehiculo ajeno', async () => {
    await seedEscenario();
    const db = await withRole(env, UIDS.taller2, 'Taller');
    await assertFails(
      db.collection('historial_mantenimientos').add({
        id_vehiculo: 'v1', id_taller: UIDS.taller2, nombre_tarea: 'inventado',
      }),
    );
  });

  test('un taller NO vinculado NO lee alertas ajenas', async () => {
    await seedEscenario();
    const db = await withRole(env, UIDS.taller2, 'Taller');
    await assertFails(db.collection('alertas').get());
  });

  test('un taller vinculado SI lee el historial del vehiculo vinculado', async () => {
    await seedEscenario();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertSucceeds(db.collection('historial_mantenimientos').doc('h1').get());
  });

  test('el propietario SI lee el historial de su vehiculo', async () => {
    await seedEscenario();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertSucceeds(db.collection('historial_mantenimientos').doc('h1').get());
  });

  test('un taller NO puede actualizar un taller ajeno', async () => {
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await seed(env, async (s) => {
      await s.collection('talleres').doc(UIDS.taller2).set({
        id_taller: UIDS.taller2, nombre: 'Taller Ajeno', especialidad: 'General',
      });
    });
    await assertFails(
      db.collection('talleres').doc(UIDS.taller2).update({ nombre: 'Secuestrado' }),
    );
  });
});
```

- [ ] **Step 7: Crear `test_rules/talleres-publico.test.js`**

```javascript
const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { makeEnv, seed, withRole, anon, UIDS } = require('./helpers');

let env;
beforeAll(async () => { env = await makeEnv(); });
afterAll(async () => { await env.cleanup(); });
beforeEach(async () => { await env.clearFirestore(); });

describe('datos legitimamente publicos', () => {
  test('el directorio de talleres SI es legible sin autenticar', async () => {
    await seed(env, async (s) => {
      await s.collection('talleres').doc(UIDS.taller1).set({
        id_taller: UIDS.taller1, nombre: 'Taller Uno', especialidad: 'Motores',
        calificacion_promedio: 4.5, total_resenias: 2,
      });
    });
    await assertSucceeds(anon(env).collection('talleres').get());
  });

  test('talleres NO expone correo ni telefono personal', async () => {
    await seed(env, async (s) => {
      await s.collection('talleres').doc(UIDS.taller1).set({
        id_taller: UIDS.taller1, nombre: 'Taller Uno', especialidad: 'Motores',
      });
    });
    const snap = await anon(env).collection('talleres').get();
    const campos = Object.keys(snap.docs[0].data());
    expect(campos).not.toContain('correo');
    expect(campos).not.toContain('telefono');
  });

  test('las resenias NO son legibles sin autenticar', async () => {
    await seed(env, async (s) => {
      await s.collection('resenias').doc('r1').set({
        id_resenia: 'r1', id_usuario: UIDS.owner1, id_taller: UIDS.taller1,
        estrellas: 5, comentario: 'Excelente',
      });
    });
    await assertFails(anon(env).collection('resenias').get());
  });

  test('un usuario autenticado SI puede leer resenias', async () => {
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await seed(env, async (s) => {
      await s.collection('resenias').doc('r1').set({
        id_resenia: 'r1', id_usuario: UIDS.owner2, id_taller: UIDS.taller1, estrellas: 4,
      });
    });
    await assertSucceeds(db.collection('resenias').get());
  });

  test('un usuario NO puede resenar un taller sin servicio previo', async () => {
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db.collection('resenias').add({
        id_usuario: UIDS.owner1, id_taller: UIDS.taller1, estrellas: 1,
        comentario: 'resena falsa', id_servicio: 'no-existe',
      }),
    );
  });

  test('el autor NO puede reapuntar su resenia a otro taller', async () => {
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await seed(env, async (s) => {
      await s.collection('resenias').doc('r1').set({
        id_resenia: 'r1', id_usuario: UIDS.owner1, id_taller: UIDS.taller1, estrellas: 5,
      });
    });
    await assertFails(db.collection('resenias').doc('r1').update({ id_taller: UIDS.taller2 }));
  });
});
```

- [ ] **Step 8: Instalar dependencias y ejecutar la suite contra las reglas ACTUALES**

```bash
cd test_rules && npm install && npm test 2>&1 | tail -50
```

Esperado: **muchos fallos.** Esto es el resultado correcto y es el objetivo de la tarea: la suite documenta el estado deseado y demuestra la brecha. Deben fallar al menos:
- los cuatro tests de `usuarios` que niegan la lectura ajena (por `firestore.rules:53`),
- los tests de `vehiculos` que niegan la lectura ajena,
- los cinco tests de `mecanico-scope` (por las cláusulas `|| isMecanico()`),
- `resenias NO legibles sin autenticar` (por `firestore.rules:164`),
- los dos tests de integridad de reseñas,
- `un taller NO puede actualizar un taller ajeno` (por `firestore.rules:80-84`).

Anotar el recuento exacto de fallos: es la línea base contra la que se mide la Fase C.

- [ ] **Step 9: Ignorar los artefactos de la suite**

Añadir a `.gitignore`:

```
test_rules/node_modules/
```

- [ ] **Step 10: Commit**

```bash
git add test_rules firebase.json .gitignore
git commit -m "test(rules): suite de regresion de firestore.rules y storage.rules

Fija como test la matriz de acceso verificada en la auditoria del 29/07/2026.
En este commit la suite FALLA a proposito: documenta la brecha antes de
corregirla. Se anade tambien el bloque emulators, ausente hasta ahora, que
permite por primera vez un entorno local reproducible."
```

---

## Fase C — Cerrar la fuga de datos

> Orden obligatorio: la Tarea 7 **antes** de la 8. `talleres` está vacía y el directorio lee de `usuarios`; cerrar `usuarios` primero rompe la función central del producto para el propietario.

### Task 7: Proyectar el perfil público del taller a la colección `talleres`

Corrige **C-02**, prerrequisito de C-01. Verificado: `talleres` devuelve `count=0` mientras el dashboard lista cinco talleres → el directorio lee de `usuarios` filtrando por rol, y eso es lo que obliga a mantener `usuarios` abierta.

**Files:**
- Create: `functions/src/publishTallerProfile.js`
- Modify: `functions/index.js` (exportar la nueva función)
- Modify: `lib/features/dashboard/presentation/pages/workshop_directory_screen.dart`
- Modify: `lib/features/dashboard/presentation/pages/dashboard_screen.dart` (sección «Talleres Cercanos»)
- Test: `test_rules/talleres-publico.test.js` (ya creado en la Tarea 6)

**Interfaces:**
- Consumes: `FirestoreCollections.talleres`, `FirestoreCollections.usuarios`.
- Produces: documentos `talleres/{uid}` con exactamente este esquema — y ningún otro campo:
  - `id_taller: String` (igual al uid del mecánico)
  - `nombre: String`
  - `especialidad: String`
  - `ubicacion: GeoPoint?`
  - `direccion: String?`
  - `foto_url: String?`
  - `calificacion_promedio: double`
  - `total_resenias: int`
  - `estado: String`

- [ ] **Step 1: Escribir el test de la proyección**

Añadir a `test_rules/talleres-publico.test.js`:

```javascript
describe('proyeccion de perfil publico', () => {
  test('un mecanico NO puede escribir directamente en talleres', async () => {
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(
      db.collection('talleres').doc(UIDS.taller1).set({
        id_taller: UIDS.taller1, nombre: 'Autoproclamado',
      }),
    );
  });
});
```

Solo la Cloud Function (Admin SDK) escribe en `talleres`.

- [ ] **Step 2: Crear la Cloud Function de proyección**

Crear `functions/src/publishTallerProfile.js`:

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');

const CAMPOS_PUBLICOS = [
  'nombre', 'especialidad', 'ubicacion', 'direccion', 'foto_url',
  'calificacion_promedio', 'total_resenias', 'estado',
];

function esMecanico(rol) {
  const r = String(rol || '').trim().toLowerCase();
  return r === 'mecanico' || r === 'taller';
}

/**
 * Proyecta a `talleres/{uid}` unicamente los campos publicos del documento
 * `usuarios/{uid}` cuando ese usuario es mecanico. Es la unica escritura
 * permitida en `talleres`, lo que hace posible cerrar la lectura de `usuarios`.
 */
exports.publishTallerProfile = functions.firestore
  .document('usuarios/{uid}')
  .onWrite(async (change, context) => {
    const uid = context.params.uid;
    const tallerRef = admin.firestore().collection('talleres').doc(uid);

    // Usuario borrado, o ya no es mecanico -> retirar del directorio.
    if (!change.after.exists) {
      await tallerRef.delete().catch(() => {});
      return null;
    }
    const data = change.after.data() || {};
    if (!esMecanico(data.rol)) {
      await tallerRef.delete().catch(() => {});
      return null;
    }

    const perfil = { id_taller: uid };
    for (const campo of CAMPOS_PUBLICOS) {
      if (data[campo] !== undefined) perfil[campo] = data[campo];
    }
    perfil.nombre = perfil.nombre || data.nombre_completo || 'Taller sin nombre';
    perfil.especialidad = perfil.especialidad || 'General';
    perfil.calificacion_promedio = perfil.calificacion_promedio || 0;
    perfil.total_resenias = perfil.total_resenias || 0;
    perfil.estado = perfil.estado || 'pendiente';

    await tallerRef.set(perfil, { merge: false });
    return null;
  });
```

`merge: false` es deliberado: garantiza que un campo retirado de la lista pública desaparezca del documento en lugar de quedar residual.

- [ ] **Step 3: Exportar la función desde `functions/index.js`**

Añadir al final del archivo:

```javascript
exports.publishTallerProfile = require('./src/publishTallerProfile').publishTallerProfile;
```

- [ ] **Step 4: Escribir el script de relleno inicial**

Crear `functions/src/backfillTalleres.js`:

```javascript
// Relleno puntual: proyecta a `talleres` los mecanicos ya existentes.
// Ejecutar UNA vez con: node functions/src/backfillTalleres.js
const admin = require('firebase-admin');
admin.initializeApp();

const CAMPOS_PUBLICOS = [
  'nombre', 'especialidad', 'ubicacion', 'direccion', 'foto_url',
  'calificacion_promedio', 'total_resenias', 'estado',
];

(async () => {
  const db = admin.firestore();
  const snap = await db.collection('usuarios').get();
  let escritos = 0;
  const batch = db.batch();
  for (const doc of snap.docs) {
    const d = doc.data();
    const rol = String(d.rol || '').trim().toLowerCase();
    if (rol !== 'mecanico' && rol !== 'taller') continue;
    const perfil = { id_taller: doc.id };
    for (const c of CAMPOS_PUBLICOS) if (d[c] !== undefined) perfil[c] = d[c];
    perfil.nombre = perfil.nombre || d.nombre_completo || 'Taller sin nombre';
    perfil.especialidad = perfil.especialidad || 'General';
    perfil.calificacion_promedio = perfil.calificacion_promedio || 0;
    perfil.total_resenias = perfil.total_resenias || 0;
    perfil.estado = perfil.estado || 'pendiente';
    batch.set(db.collection('talleres').doc(doc.id), perfil, { merge: false });
    escritos++;
  }
  await batch.commit();
  console.log(`talleres proyectados: ${escritos}`);
  process.exit(0);
})();
```

- [ ] **Step 5: Probar la proyección en el emulador**

```bash
firebase emulators:start --only firestore,functions --project autodoc-rules-test &
sleep 15
cd test_rules && npx jest talleres-publico --runInBand --forceExit 2>&1 | tail -20
```

Esperado: el test `un mecanico NO puede escribir directamente en talleres` PASA (ya lo impedía `firestore.rules:75`, que exige rol mecánico **y** no valida pertenencia — la Tarea 9 lo endurece).

- [ ] **Step 6: Reapuntar el directorio a `talleres`**

En `lib/features/dashboard/presentation/pages/workshop_directory_screen.dart`, sustituir la consulta que lee de `usuarios` filtrando por rol por:

```dart
    return FirebaseFirestore.instance
        .collection(FirestoreCollections.talleres)
        .where('estado', isEqualTo: 'aprobado')
        .orderBy('calificacion_promedio', descending: true)
        .limit(50)
        .snapshots();
```

El `.limit(50)` es obligatorio: la auditoría verificó consultas que devolvían colecciones completas.

- [ ] **Step 7: Aplicar el mismo cambio a «Talleres Cercanos» del dashboard**

En `lib/features/dashboard/presentation/pages/dashboard_screen.dart`, localizar la consulta de la sección «Talleres Cercanos» y sustituirla por la misma lectura de `talleres` con `.limit(5)`.

- [ ] **Step 8: Añadir el índice compuesto necesario**

Añadir a `firestore.indexes.json`, dentro del array `indexes`:

```json
    {
      "collectionGroup": "talleres",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "estado", "order": "ASCENDING" },
        { "fieldPath": "calificacion_promedio", "order": "DESCENDING" }
      ]
    }
```

Sin este índice la consulta del paso 6 falla en tiempo de ejecución con `FAILED_PRECONDITION`.

- [ ] **Step 9: Verificar que el directorio ya no consulta `usuarios`**

```bash
grep -n "FirestoreCollections.usuarios\|'usuarios'" lib/features/dashboard/presentation/pages/workshop_directory_screen.dart lib/features/dashboard/presentation/pages/dashboard_screen.dart && echo "FALLO: sigue leyendo usuarios" || echo "OK: ya no lee usuarios"
```

Esperado: `OK: ya no lee usuarios`.

- [ ] **Step 10: Commit**

```bash
git add functions/src/publishTallerProfile.js functions/src/backfillTalleres.js functions/index.js lib/features/dashboard/presentation/pages/workshop_directory_screen.dart lib/features/dashboard/presentation/pages/dashboard_screen.dart firestore.indexes.json test_rules/talleres-publico.test.js
git commit -m "feat(talleres): proyectar el perfil publico del taller a su propia coleccion

El directorio leia de 'usuarios' filtrando por rol, que es lo que obligaba a
mantener 'usuarios' con lectura abierta a cualquier autenticado. Una Cloud
Function proyecta ahora solo los campos publicos a 'talleres', que ya existia
y estaba vacia. Prerrequisito para cerrar la regla de 'usuarios'."
```

---

### Task 8: Cerrar la lectura de `usuarios`

Corrige el vector principal de **C-01**. Verificado: con el token del rol de **menor privilegio** se leyeron 30 documentos de `usuarios` con `correo` y `nombre_completo` (`oscar@gmail.com` / `Oscar Hernandez`). Causa: `firestore.rules:53`.

**Files:**
- Modify: `firestore.rules:52-67`

**Interfaces:**
- Consumes: la colección `talleres` poblada (Tarea 7).
- Produces: nada en código.

- [ ] **Step 1: Confirmar que los tests de `usuarios` fallan antes del cambio**

```bash
cd test_rules && npx jest usuarios --runInBand --forceExit 2>&1 | tail -25
```

Esperado: fallan los tests que niegan la lectura ajena.

- [ ] **Step 2: Reemplazar la regla de lectura de `usuarios`**

En `firestore.rules`, sustituir la línea 53 (`allow read: if isAuthenticated();`) por:

```
      // Cada usuario lee unicamente su propio documento. El perfil publico de
      // los talleres vive en la coleccion `talleres`, proyectado por la Cloud
      // Function publishTallerProfile.
      allow read: if isOwner(userId) || isAdmin();
```

- [ ] **Step 3: Ejecutar los tests y confirmar que pasan**

```bash
cd test_rules && npx jest usuarios --runInBand --forceExit 2>&1 | tail -25
```

Esperado: los 9 tests de `usuarios.test.js` PASAN.

- [ ] **Step 4: Comprobar que no se ha roto ningún otro test**

```bash
cd test_rules && npm test 2>&1 | tail -30
```

Esperado: los tests de `usuarios` y `talleres-publico` pasan; los de `vehiculos` y `mecanico-scope` siguen fallando (los corrige la Tarea 9). El recuento total de fallos debe ser **menor** que la línea base de la Tarea 6, Paso 8.

- [ ] **Step 5: Verificar que la aplicación sigue funcionando**

```bash
flutter test 2>&1 | tail -20
```

Esperado: sin regresiones. Si algún test de widget o de provider falla porque leía `usuarios` de forma amplia, ese es un uso que también hay que reapuntar a `talleres`.

- [ ] **Step 6: Commit**

```bash
git add firestore.rules
git commit -m "security: restringir la lectura de usuarios a su propio documento

Verificado en la auditoria: con el token del rol de menor privilegio se leian
30 documentos con correo y nombre completo de todos los usuarios. El perfil
publico de taller vive ahora en 'talleres' (tarea anterior), por lo que cerrar
esta regla ya no rompe el directorio."
```

---

### Task 9: Eliminar las cláusulas `|| isMecanico()` sin comprobación de vínculo

Corrige el resto de **C-01**. El mismo error conceptual se repite en seis puntos de `firestore.rules` (`:138`, `:245`, `:256`, `:272`, `:277`, `:282`) y en la regla de actualización de `talleres` (`:80-84`), que permite a **cualquier** mecánico modificar **cualquier** taller. Verificado: un token de taller leyó 240 documentos de `mantenimientos` y 12 de `historial_mantenimientos` con `id_taller` de otro taller.

**Files:**
- Modify: `firestore.rules` (funciones auxiliares y bloques 2, 5, 10, 11)

**Interfaces:**
- Consumes: nada.
- Produces: función de reglas `isVinculadoAlVehiculo(vehiculoId)` → `bool`, usada por los bloques de `alertas`, `mantenimientos` e `historial_mantenimientos`.

- [ ] **Step 1: Confirmar que los tests de alcance fallan**

```bash
cd test_rules && npx jest mecanico-scope --runInBand --forceExit 2>&1 | tail -30
```

Esperado: fallan los cinco tests que niegan el acceso del taller no vinculado.

- [ ] **Step 2: Añadir la función auxiliar de vínculo**

En `firestore.rules`, tras `isVehicleOwner` (línea 46), añadir:

```
    // Verifica que el usuario es un mecanico cuyo taller esta vinculado al vehiculo.
    function isVinculadoAlVehiculo(vehiculoId) {
      return isMecanico() &&
        exists(/databases/$(database)/documents/vehiculos/$(vehiculoId)) &&
        get(/databases/$(database)/documents/vehiculos/$(vehiculoId))
          .data.get('talleres_vinculados', []).hasAny([request.auth.uid]);
    }
```

- [ ] **Step 3: Corregir el bloque de `alertas`**

Sustituir `|| isMecanico()` en la regla de lectura (línea 138) por:

```
        || isVinculadoAlVehiculo(resource.data.id_vehiculo)
```

- [ ] **Step 4: Corregir el bloque de `mantenimientos`**

Sustituir las dos apariciones de `|| isMecanico()` (líneas 245 y 256) por:

```
        || isVinculadoAlVehiculo(resource.data.id_vehiculo)
```

- [ ] **Step 5: Corregir el bloque de `historial_mantenimientos`**

Reemplazar las tres reglas del bloque por:

```
      allow read: if isAuthenticated() && (
        isVehicleOwner(resource.data.id_vehiculo)
        || isVinculadoAlVehiculo(resource.data.id_vehiculo)
        || isAdmin()
      );

      allow create: if isAuthenticated() && (
        (isVinculadoAlVehiculo(request.resource.data.id_vehiculo)
          && request.resource.data.id_taller == request.auth.uid)
        || isAdmin()
      );

      allow update: if isAuthenticated() && (
        (isVinculadoAlVehiculo(resource.data.id_vehiculo)
          && resource.data.id_taller == request.auth.uid)
        || isAdmin()
      );

      allow delete: if isAdmin();
```

La doble condición es deliberada: estar vinculado al vehículo **y** ser el taller que firmó el registro. Sin la segunda, un taller vinculado podría reescribir el trabajo de otro taller sobre el mismo vehículo.

- [ ] **Step 6: Corregir la actualización de `talleres`**

Reemplazar el bloque de `talleres` (líneas 70-87) por:

```
    match /talleres/{tallerId} {
      // El directorio de talleres es de lectura publica.
      allow read: if true;

      // Solo la Cloud Function publishTallerProfile (Admin SDK) escribe aqui.
      allow create, update: if isAdmin();

      allow delete: if isAdmin();
    }
```

Los mecánicos editan su perfil en su propio documento de `usuarios`; la proyección la hace la función. Esto elimina de raíz el IDOR de «cualquier mecánico actualiza cualquier taller».

- [ ] **Step 7: Endurecer la integridad de `resenias`**

Reemplazar las reglas de `create` y `update` del bloque `resenias` (líneas 167-170) por:

```
      // Solo se puede resenar un servicio real, propio, y una sola vez.
      allow create: if isAuthenticated()
        && request.resource.data.id_usuario == request.auth.uid
        && exists(/databases/$(database)/documents/servicios/$(request.resource.data.id_servicio))
        && isVehicleOwner(
             get(/databases/$(database)/documents/servicios/$(request.resource.data.id_servicio))
               .data.id_vehiculo);

      // El autor puede corregir su texto y su puntuacion, nada mas.
      allow update: if isAuthenticated()
        && resource.data.id_usuario == request.auth.uid
        && request.resource.data.diff(resource.data)
             .affectedKeys().hasOnly(['comentario', 'estrellas']);
```

Y restringir su lectura (línea 164) a usuarios autenticados:

```
      allow read: if isAuthenticated();
```

- [ ] **Step 8: Ejecutar la suite completa**

```bash
cd test_rules && npm test 2>&1 | tail -40
```

Esperado: **todos los tests PASAN**. Este es el criterio de éxito de la Fase C.

- [ ] **Step 9: Reproducir el sondeo original de la auditoría contra el emulador**

Comprobar que la fuga concreta que se verificó ya no es posible:

```javascript
// verify-fuga.js  — replica el sondeo de la auditoria contra el EMULADOR
const { initializeTestEnvironment, assertFails } = require('@firebase/rules-unit-testing');
const fs = require('fs');
(async () => {
  const env = await initializeTestEnvironment({
    projectId: 'autodoc-rules-test',
    firestore: { rules: fs.readFileSync('firestore.rules', 'utf8'), host: '127.0.0.1', port: 8080 },
  });
  const db = env.authenticatedContext('atacante').firestore();
  const objetivos = ['usuarios', 'vehiculos', 'servicios', 'mantenimientos', 'historial_mantenimientos'];
  let fugas = 0;
  for (const col of objetivos) {
    try { await db.collection(col).get(); console.error(`FUGA: ${col} legible`); fugas++; }
    catch (e) { console.log(`OK: ${col} denegado`); }
  }
  await env.cleanup();
  if (fugas > 0) { console.error(`FALLO: ${fugas} colecciones siguen expuestas`); process.exit(1); }
  console.log('OK: ninguna coleccion completa es legible por un usuario cualquiera');
})();
```

```bash
firebase emulators:exec --only firestore --project autodoc-rules-test "node verify-fuga.js"
```

Esperado: `OK: ninguna coleccion completa es legible por un usuario cualquiera`.

- [ ] **Step 10: Commit**

```bash
git add firestore.rules
git commit -m "security: exigir vinculo con el vehiculo en todo acceso de mecanico

El patron '|| isMecanico()' sin comprobacion de pertenencia se repetia en seis
puntos y permitia a cualquier taller leer 240 mantenimientos y modificar el
historial de vehiculos ajenos. Se anade isVinculadoAlVehiculo(), se cierra el
IDOR de actualizacion de 'talleres' y se exige servicio previo para resenar.
Verificado por test_rules: la suite completa pasa."
```

---

### Task 10: Límites y aislamiento en Storage

Corrige **C-06**. `storage.rules` (77 líneas) **no contiene ninguna** comprobación de `request.resource.size` ni de `contentType`, y `facturas/{vehicleId}/{fileName}` concede `read, write` a cualquier mecánico. Corrige además **F-12**: la regla de `perfiles` solo admite los nombres exactos `{uid}` y `{uid}.jpg`, por lo que la subida de foto de perfil falla para PNG — coherente con que los 30 usuarios de la base tengan `foto_perfil_url: null`.

**Files:**
- Modify: `storage.rules`
- Create: `test_rules/storage.test.js`

**Interfaces:**
- Consumes: `makeEnv`, `UIDS`, `seed` de `test_rules/helpers.js`.
- Produces: función de reglas `esImagenValida()` → `bool`.

- [ ] **Step 1: Escribir los tests de Storage**

Crear `test_rules/storage.test.js`:

```javascript
const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { makeEnv, seed, UIDS } = require('./helpers');

let env;
beforeAll(async () => { env = await makeEnv(); });
afterAll(async () => { await env.cleanup(); });
beforeEach(async () => { await env.clearStorage(); await env.clearFirestore(); });

const imagen = (kb) => Buffer.alloc(kb * 1024, 1);
const META_JPEG = { contentType: 'image/jpeg' };

const seedUsuario = (uid, rol) => seed(env, async (db) => {
  await db.collection('usuarios').doc(uid).set({ id_usuario: uid, rol, estado: 'activo' });
});

const seedVehiculo = (id, propietario, vinculados = []) => seed(env, async (db) => {
  await db.collection('vehiculos').doc(id).set({
    id_vehiculo: id, id_propietario: propietario, talleres_vinculados: vinculados,
  });
});

describe('storage: limites', () => {
  test('rechaza una subida por encima de 5 MB', async () => {
    await seedUsuario(UIDS.owner1, 'Propietario');
    const st = env.authenticatedContext(UIDS.owner1).storage();
    await assertFails(
      st.ref(`perfiles/${UIDS.owner1}.jpg`).put(imagen(6 * 1024), META_JPEG),
    );
  });

  test('acepta una imagen pequena', async () => {
    await seedUsuario(UIDS.owner1, 'Propietario');
    const st = env.authenticatedContext(UIDS.owner1).storage();
    await assertSucceeds(
      st.ref(`perfiles/${UIDS.owner1}.jpg`).put(imagen(200), META_JPEG),
    );
  });

  test('rechaza un contentType que no sea imagen', async () => {
    await seedUsuario(UIDS.owner1, 'Propietario');
    const st = env.authenticatedContext(UIDS.owner1).storage();
    await assertFails(
      st.ref(`perfiles/${UIDS.owner1}.jpg`).put(imagen(10), { contentType: 'text/html' }),
    );
    await assertFails(
      st.ref(`perfiles/${UIDS.owner1}.jpg`).put(imagen(10), { contentType: 'image/svg+xml' }),
    );
  });

  test('acepta PNG y WebP en la foto de perfil', async () => {
    await seedUsuario(UIDS.owner1, 'Propietario');
    const st = env.authenticatedContext(UIDS.owner1).storage();
    await assertSucceeds(
      st.ref(`perfiles/${UIDS.owner1}.png`).put(imagen(50), { contentType: 'image/png' }),
    );
    await assertSucceeds(
      st.ref(`perfiles/${UIDS.owner1}.webp`).put(imagen(50), { contentType: 'image/webp' }),
    );
  });
});

describe('storage: aislamiento de facturas', () => {
  test('un taller NO vinculado NO puede leer facturas ajenas', async () => {
    await seedUsuario(UIDS.taller2, 'Taller');
    await seedVehiculo('v1', UIDS.owner1, [UIDS.taller1]);
    const st = env.authenticatedContext(UIDS.taller2).storage();
    await assertFails(st.ref('facturas/v1/f.jpg').getDownloadURL());
  });

  test('un taller NO vinculado NO puede SOBRESCRIBIR facturas ajenas', async () => {
    await seedUsuario(UIDS.taller2, 'Taller');
    await seedVehiculo('v1', UIDS.owner1, [UIDS.taller1]);
    const st = env.authenticatedContext(UIDS.taller2).storage();
    await assertFails(st.ref('facturas/v1/f.jpg').put(imagen(10), META_JPEG));
  });

  test('el propietario del vehiculo SI puede subir su factura', async () => {
    await seedUsuario(UIDS.owner1, 'Propietario');
    await seedVehiculo('v1', UIDS.owner1);
    const st = env.authenticatedContext(UIDS.owner1).storage();
    await assertSucceeds(st.ref('facturas/v1/f.jpg').put(imagen(100), META_JPEG));
  });

  test('un taller vinculado SI puede subir la factura del servicio', async () => {
    await seedUsuario(UIDS.taller1, 'Taller');
    await seedVehiculo('v1', UIDS.owner1, [UIDS.taller1]);
    const st = env.authenticatedContext(UIDS.taller1).storage();
    await assertSucceeds(st.ref('facturas/v1/f.jpg').put(imagen(100), META_JPEG));
  });

  test('un usuario cualquiera NO puede leer fotos de vehiculos ajenos', async () => {
    await seedUsuario(UIDS.owner2, 'Propietario');
    await seedVehiculo('v1', UIDS.owner1);
    const st = env.authenticatedContext(UIDS.owner2).storage();
    await assertFails(st.ref('vehiculos/v1/foto.jpg').getDownloadURL());
  });
});
```

- [ ] **Step 2: Ejecutar y confirmar que fallan**

```bash
cd test_rules && npx jest storage --runInBand --forceExit 2>&1 | tail -30
```

Esperado: fallan los tests de tamaño, `contentType` y aislamiento de facturas.

- [ ] **Step 3: Añadir las funciones auxiliares a `storage.rules`**

Tras `isMecanico()` (línea 29), añadir:

```
    // Toda escritura de imagen: maximo 5 MB y tipo de imagen permitido.
    // Se excluye deliberadamente image/svg+xml: un SVG puede contener script
    // y se serviria desde el dominio del propio proyecto.
    function esImagenValida() {
      return request.resource.size < 5 * 1024 * 1024 &&
        request.resource.contentType.matches('image/(jpeg|jpg|png|webp)');
    }

    // Mecanico cuyo taller esta vinculado al vehiculo.
    function isVinculadoAlVehiculo(vehicleId) {
      return isMecanico() &&
        firestore.exists(/databases/(default)/documents/vehiculos/$(vehicleId)) &&
        firestore.get(/databases/(default)/documents/vehiculos/$(vehicleId))
          .data.get('talleres_vinculados', []).hasAny([request.auth.uid]);
    }
```

- [ ] **Step 4: Reemplazar el bloque de `perfiles`**

```
    match /perfiles/{fileId} {
      allow read: if isAuthenticated();
      allow write: if isAuthenticated()
        && esImagenValida()
        && fileId.matches('^' + request.auth.uid + '(\\.(jpg|jpeg|png|webp))?$');
    }
```

Amplía las extensiones admitidas manteniendo la restricción de que el nombre sea el uid del autor.

- [ ] **Step 5: Reemplazar el bloque de `facturas`**

```
    match /facturas/{vehicleId}/{fileName} {
      allow read: if isAuthenticated() && (
        isVehicleOwner(vehicleId)
        || isVinculadoAlVehiculo(vehicleId)
        || isAdmin()
      );
      allow write: if isAuthenticated()
        && esImagenValida()
        && (isVehicleOwner(vehicleId) || isVinculadoAlVehiculo(vehicleId) || isAdmin());
      // Las facturas son el rastro documental del producto: solo un admin las borra.
      allow delete: if isAdmin();
    }
```

- [ ] **Step 6: Reemplazar el bloque de `vehiculos`**

```
    match /vehiculos/{vehicleId}/{fileName} {
      allow read: if isAuthenticated() && (
        isVehicleOwner(vehicleId)
        || isVinculadoAlVehiculo(vehicleId)
        || isAdmin()
      );
      allow write: if isAuthenticated()
        && esImagenValida()
        && (isVehicleOwner(vehicleId) || isAdmin());
      allow delete: if isAuthenticated() && (isVehicleOwner(vehicleId) || isAdmin());
    }
```

- [ ] **Step 7: Añadir el límite a las imágenes de chat**

En el bloque `chat_images`, separar lectura de escritura y añadir la validación:

```
    match /chat_images/{conversacionId}/{fileName} {
      allow read: if isAuthenticated() && (
        isAdmin() || (
          firestore.exists(/databases/(default)/documents/conversaciones/$(conversacionId)) &&
          (firestore.get(/databases/(default)/documents/conversaciones/$(conversacionId)).data.id_propietario == request.auth.uid ||
           firestore.get(/databases/(default)/documents/conversaciones/$(conversacionId)).data.id_mecanico == request.auth.uid)
        )
      );
      allow write: if isAuthenticated() && esImagenValida() && (
        firestore.exists(/databases/(default)/documents/conversaciones/$(conversacionId)) &&
        (firestore.get(/databases/(default)/documents/conversaciones/$(conversacionId)).data.id_propietario == request.auth.uid ||
         firestore.get(/databases/(default)/documents/conversaciones/$(conversacionId)).data.id_mecanico == request.auth.uid)
      );
    }
```

- [ ] **Step 8: Ejecutar la suite de Storage y confirmar que pasa**

```bash
cd test_rules && npx jest storage --runInBand --forceExit 2>&1 | tail -30
```

Esperado: los 9 tests PASAN.

- [ ] **Step 9: Ejecutar la suite completa**

```bash
cd test_rules && npm test 2>&1 | tail -20
```

Esperado: todos los tests de Firestore y Storage PASAN.

- [ ] **Step 10: Commit**

```bash
git add storage.rules test_rules/storage.test.js
git commit -m "security: limitar tamano y tipo en Storage y aislar las facturas

storage.rules no validaba size ni contentType (denial of wallet y XSS
almacenado desde el dominio del proyecto) y concedia read/write de las
facturas de cualquier vehiculo a cualquier mecanico. Se amplian tambien las
extensiones de foto de perfil, cuya regla solo admitia .jpg y hacia que la
subida fallase para PNG."
```

---

## Fase D — Corregir enrutado y autenticación

### Task 11: Cerrar el hueco de guarda durante la carga de perfil

Corrige un hallazgo nuevo, causa verificada de que **`/dashboard` se renderizara con el rol de taller** pese a estar en `_ownerRoutes` (`app_router.dart:66`). En `appRouterRedirect`, la rama `isLoggedIn && (isProfileLoading || !hasAttemptedFetch)` (`:168-178`) devuelve `null`, es decir **permite**, cualquier ruta protegida mientras el perfil se carga. En una carga en frío la pantalla del rol equivocado se monta, lanza sus consultas y renderiza. Corrige también **P-06**: `/admin/seed` **no está** en `_adminRoutes` (`:87-93`), único motivo por el que se renderizó con el token de taller mientras las otras cinco rutas `/admin/*` redirigían.

**Files:**
- Modify: `lib/core/router/app_router.dart:87-93` y `:167-178`
- Test: `test/core/router/app_router_guard_test.dart` (crear)

**Interfaces:**
- Consumes: `_publicRoutes`, `_ownerRoutes`, `_mechanicRoutes`, `_adminRoutes`, `_normalizeRole`, `_homeForRole`, `_matchesRouteSet` (todos ya en `app_router.dart:62-126`).
- Produces: `resolveRedirect({required bool isLoggedIn, required UserModel? userData, required bool isLoading, required bool hasAttemptedFetch, required String? profileError, required String currentPath, String? redirectParam})` → `String?` — función pura, sin dependencias de Flutter, invocada por `appRouterRedirect` y por los tests. `appRouterRedirect` conserva su firma actual.

- [ ] **Step 1: Escribir los tests que fallan**

Crear `test/core/router/app_router_guard_test.dart`. Invoca la función pura `resolveRedirect` que se crea en el Step 2, por lo que no necesita dobles de providers:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/models/user_model.dart';
import 'package:autodoc/core/router/app_router.dart';

// `fechaRegistro` es obligatorio en el constructor de UserModel
// (lib/core/models/user_model.dart:25).
UserModel _user(String uid, String rol, {String estado = 'activo'}) => UserModel(
  idUsuario: uid,
  correo: '$uid@test.com',
  nombreCompleto: 'Usuario $uid',
  rol: rol,
  fechaRegistro: DateTime(2026, 1, 1),
  estado: estado,
);

String? _redirect({
  required String currentPath,
  UserModel? userData,
  bool isLoggedIn = true,
  bool hasAttemptedFetch = true,
  bool isLoading = false,
}) => resolveRedirect(
  isLoggedIn: isLoggedIn,
  userData: userData,
  isLoading: isLoading,
  hasAttemptedFetch: hasAttemptedFetch,
  profileError: null,
  currentPath: currentPath,
);

void main() {
  group('guarda del router durante la carga de perfil', () {
    test('no permite una ruta protegida mientras el perfil aun no se ha leido', () {
      expect(
        _redirect(currentPath: '/dashboard', hasAttemptedFetch: false),
        '/',
        reason: 'debe retener en el splash, no renderizar la pantalla del rol equivocado',
      );
    });

    test('no permite una ruta de mecanico mientras el perfil carga', () {
      expect(
        _redirect(currentPath: '/mechanic_dashboard', hasAttemptedFetch: false),
        '/',
      );
    });

    test('permite quedarse en el splash mientras carga', () {
      expect(_redirect(currentPath: '/', hasAttemptedFetch: false), isNull);
    });
  });

  group('guarda de rutas admin', () {
    test('un taller NO puede acceder a /admin/seed', () {
      expect(
        _redirect(currentPath: '/admin/seed', userData: _user('uid-t', 'Taller')),
        '/mechanic_dashboard',
      );
    });

    test('un propietario NO puede acceder a /admin/seed', () {
      expect(
        _redirect(currentPath: '/admin/seed', userData: _user('uid-o', 'Propietario')),
        '/dashboard',
      );
    });

    test('un admin SI puede acceder a /admin/seed', () {
      expect(
        _redirect(currentPath: '/admin/seed', userData: _user('uid-a', 'Administrador')),
        isNull,
      );
    });
  });

  group('separacion de roles', () {
    test('un taller NO puede acceder al dashboard de propietario', () {
      expect(
        _redirect(currentPath: '/dashboard', userData: _user('uid-t', 'Taller')),
        '/mechanic_dashboard',
      );
    });

    test('un propietario NO puede acceder al panel de taller', () {
      expect(
        _redirect(currentPath: '/mechanic_dashboard', userData: _user('uid-o', 'Propietario')),
        '/dashboard',
      );
    });
  });

  group('mecanico pendiente de aprobacion', () {
    test('un mecanico pendiente es enviado a /mechanic_pending', () {
      expect(
        _redirect(
          currentPath: '/mechanic_dashboard',
          userData: _user('uid-t', 'Taller', estado: 'pendiente'),
        ),
        '/mechanic_pending',
      );
    });

    test('un mecanico pendiente puede permanecer en /mechanic_pending', () {
      expect(
        _redirect(
          currentPath: '/mechanic_pending',
          userData: _user('uid-t', 'Taller', estado: 'pendiente'),
        ),
        isNull,
      );
    });
  });

  group('rutas de chat con parametro', () {
    test('/reserva_detail/:id sigue permitido para ambos roles', () {
      expect(
        _redirect(currentPath: '/reserva_detail/r1', userData: _user('uid-t', 'Taller')),
        isNull,
      );
      expect(
        _redirect(currentPath: '/reserva_detail/r1', userData: _user('uid-o', 'Propietario')),
        isNull,
      );
    });
  });
}
```

El test del valor por defecto de `UserModel.estado` va en la Tarea 13, junto al cambio que lo produce.

- [ ] **Step 2: Extraer la decisión a una función pura**

`appRouterRedirect` recibe un `BuildContext` que no usa y un `GoRouterState` costoso de construir en un test. Extraer el núcleo de decisión a una función pura y dejar que `appRouterRedirect` sea un adaptador. Añadir a `app_router.dart`, antes de `appRouterRedirect`:

```dart
/// Núcleo de decisión del enrutado, sin dependencias de Flutter ni de go_router.
/// `appRouterRedirect` es un adaptador sobre esta función; los tests la invocan
/// directamente.
String? resolveRedirect({
  required bool isLoggedIn,
  required UserModel? userData,
  required bool isLoading,
  required bool hasAttemptedFetch,
  required String? profileError,
  required String currentPath,
  String? redirectParam,
}) {
  final isPublicRoute = _publicRoutes.contains(currentPath);
  final isProfileLoading = isLoading || (isLoggedIn && !hasAttemptedFetch);

  if (!isLoggedIn && !isPublicRoute) return '/login';

  // NOTA: este bloque es copia fiel del comportamiento actual. El Step 5 lo
  // corrige; aqui se preserva para que este Step sea un refactor puro y los
  // tests del Step 1 sigan fallando por el motivo correcto.
  if (isLoggedIn && (isProfileLoading || !hasAttemptedFetch)) {
    if (currentPath == '/' ||
        currentPath == '/login' ||
        currentPath == '/register') {
      return null;
    }
    return null;
  }

  if (isLoggedIn && (currentPath == '/login' || currentPath == '/register')) {
    if (userData == null) {
      if (profileError != null) return null;
      return '/profile_setup';
    }
    if (redirectParam != null && redirectParam.isNotEmpty) {
      return Uri.decodeComponent(redirectParam);
    }
    return _homeForRole(_normalizeRole(userData.rol));
  }

  if (isLoggedIn &&
      userData == null &&
      profileError == null &&
      currentPath != '/profile_setup' &&
      !isPublicRoute) {
    return '/profile_setup';
  }

  if (isLoggedIn && userData != null) {
    final role = _normalizeRole(userData.rol);
    final home = _homeForRole(role);

    final estado = userData.estado.trim().toLowerCase();
    if (role == 'mechanic' && (estado == 'pendiente' || estado == 'pending')) {
      return currentPath == '/mechanic_pending' ? null : '/mechanic_pending';
    }

    if (currentPath.startsWith('/chat/') ||
        currentPath == '/chat_list' ||
        currentPath.startsWith('/reserva_detail')) {
      return null;
    }

    if (currentPath == '/task_config' || currentPath == '/task_complete') {
      return (role != 'owner' && role != 'admin') ? home : null;
    }

    if (currentPath == '/profile_setup') return home;

    if (role == 'owner' &&
        (_matchesRouteSet(currentPath, _mechanicRoutes) ||
            _matchesRouteSet(currentPath, _adminRoutes))) {
      return '/dashboard';
    }
    if (role == 'mechanic' &&
        (_matchesRouteSet(currentPath, _ownerRoutes) ||
            _matchesRouteSet(currentPath, _adminRoutes))) {
      return '/mechanic_dashboard';
    }
    if (role != 'admin' && _matchesRouteSet(currentPath, _adminRoutes)) {
      return home;
    }
  }

  return null;
}
```

Dos detalles: `currentPath.startsWith('/reserva_detail')` porque la Tarea 12 convierte esa ruta en `/reserva_detail/:reservaId` y una comparación por igualdad dejaría de reconocerla; y `_adminRoutes` se deja **sin** `/admin/seed` en este paso, porque añadirlo es el cambio de comportamiento del Step 4.

- [ ] **Step 2b: Convertir `appRouterRedirect` en adaptador**

Reemplazar el cuerpo completo de `appRouterRedirect` por:

```dart
String? appRouterRedirect(
  AuthSessionProvider authProvider,
  UserProfileProvider profileProvider,
  BuildContext context,
  GoRouterState state,
) {
  final currentUid = authProvider.currentUid;
  final rawUserData = profileProvider.userData;
  final userData =
      (rawUserData != null &&
              (rawUserData.idUsuario == currentUid ||
                  rawUserData.idUsuario.isEmpty))
          ? rawUserData
          : null;

  return resolveRedirect(
    isLoggedIn: authProvider.isLoggedIn,
    userData: userData,
    isLoading: profileProvider.isLoading,
    hasAttemptedFetch: profileProvider.hasAttemptedFetchFor(currentUid),
    profileError: profileProvider.error,
    currentPath: state.uri.path,
    redirectParam: state.uri.queryParameters['redirect'],
  );
}
```

- [ ] **Step 2c: Comprobar que el test existente sigue compilando**

`test/core/router/app_router_test.dart` invoca `appRouterRedirect` con sus dobles `FakeAuthSessionProvider` y `FakeUserProfileProvider`. Como la firma de `appRouterRedirect` no cambia (solo su cuerpo), esos tests deben seguir válidos:

```bash
flutter test test/core/router/app_router_test.dart 2>&1 | tail -15
```

Esperado: PASAN sin modificaciones. Si alguno falla, es porque dependía del comportamiento antiguo de permitir rutas protegidas durante la carga de perfil — en ese caso el test codificaba el defecto y hay que actualizar su expectativa, dejando constancia en el mensaje del commit.

- [ ] **Step 3: Ejecutar los tests y confirmar que fallan por el motivo correcto**

```bash
flutter test test/core/router/app_router_guard_test.dart 2>&1 | tail -30
```

Esperado: compila y **fallan exactamente 5 tests**:
- los tres de «guarda del router durante la carga de perfil» que esperan `'/'` (obtienen `null`),
- los dos de `/admin/seed` para taller y propietario que esperan la home del rol (obtienen `null`).

Los demás deben **pasar** ya, porque el Step 2 fue un refactor sin cambio de comportamiento. Si falla alguno más, el refactor introdujo una regresión: revisarlo antes de continuar.

- [ ] **Step 4: Añadir `/admin/seed` al conjunto de rutas admin**

```dart
/// Routes exclusively for Admin role
const _adminRoutes = <String>{
  '/admin/dashboard',
  '/admin/usuarios',
  '/admin/talleres',
  '/admin/resenias',
  '/admin/logs',
  '/admin/seed',
};
```

- [ ] **Step 5: Retener en el splash mientras el perfil carga**

En `resolveRedirect`, sustituir el bloque marcado con la nota del Step 2 por:

```dart
  // Mientras el perfil se carga no se puede decidir el rol, asi que no se
  // permite montar ninguna ruta protegida: se retiene en el splash. Devolver
  // null aqui permitia renderizar la pantalla de otro rol en una carga en frio,
  // que es como un token de taller llegaba a ver /dashboard.
  if (isLoggedIn && (isProfileLoading || !hasAttemptedFetch)) {
    if (currentPath == '/' ||
        currentPath == '/login' ||
        currentPath == '/register') {
      return null;
    }
    return '/';
  }
```

`refreshListenable` (`app_router.dart:277`) vuelve a evaluar el redirect cuando el perfil llega, y desde `/` se envía a la home del rol correcto.

- [ ] **Step 5b: Comprobar que no quedó lógica duplicada**

```bash
grep -c "isPublicRoute" lib/core/router/app_router.dart
```

Esperado: `1` — una sola aparición, dentro de `resolveRedirect`. Si devuelve `2`, quedó sin borrar el cuerpo antiguo de `appRouterRedirect` (líneas 143-266 del archivo original), que el Step 2b debía reemplazar por completo.

- [ ] **Step 6: Ejecutar los tests y confirmar que pasan**

```bash
flutter test test/core/router/app_router_guard_test.dart test/core/router/app_router_test.dart
```

Esperado: PASAN todos, incluidos los del archivo original (sin regresiones).

- [ ] **Step 7: Verificar en el navegador que `/dashboard` ya no se renderiza con rol de taller**

```javascript
// verify-guard.js
const H = require('./lib.js'); // harness de la auditoria
(async () => {
  const { browser, page } = await H.launch();
  await H.boot(page);
  await H.login(page, 'taller');
  await page.waitForTimeout(5000);
  await page.goto('http://localhost:51046/dashboard', { waitUntil: 'load', timeout: 120000 });
  await page.waitForTimeout(15000);
  const r = await page.evaluate(() => ({ url: location.pathname, txt: (document.body.innerText||'').slice(0,200) }));
  console.log('aterrizo en:', r.url);
  console.log('texto:', JSON.stringify(r.txt));
  if (r.url === '/dashboard' && /Registrar Veh|Listo para la carretera/.test(r.txt)) {
    console.error('FALLO: el taller sigue viendo el dashboard de propietario'); process.exit(1);
  }
  console.log('OK: el taller no accede al dashboard de propietario');
  await browser.close();
})();
```

Esperado: `OK: el taller no accede al dashboard de propietario`.

- [ ] **Step 8: Commit**

```bash
git add lib/core/router/app_router.dart test/core/router/app_router_guard_test.dart
git commit -m "security(router): cerrar el hueco de guarda durante la carga de perfil

La rama 'esperando perfil' devolvia null (permitir) para cualquier ruta
protegida, por lo que en una carga en frio se renderizaba la pantalla de otro
rol: verificado con un token de taller accediendo a /dashboard. Ahora retiene
en el splash. Se anade tambien /admin/seed a _adminRoutes, la unica ruta
/admin/* que carecia de guarda."
```

---

### Task 12: Eliminar las pantallas en blanco

Corrige el resto de **C-03**. Cinco pantallas renderizan `undefined` con 2-6 nodos semánticos porque reciben su argumento por `state.extra` y lo castean a un tipo **no nulable**: en una carga directa o un F5 no hay `extra`. Verificado: `TypeError: null: type 'Null' is not a subtype of type 'VehicleModel'` en `/vehicle_profile` y `'Null' is not a subtype of type 'String'` en `/service_history`. El contrato está documentado en `app_router.dart:130-135`.

**Files:**
- Modify: `lib/core/router/app_router.dart` (rutas `/vehicle_profile`, `/service_history`, `/initiate_service`, `/reserva_detail`)
- Modify: `lib/features/dashboard/presentation/pages/vehicle_profile_screen.dart`
- Modify: `lib/features/dashboard/presentation/pages/service_history_screen.dart`
- Modify: `lib/features/mechanic/presentation/pages/initiate_service_screen.dart`
- Modify: `lib/features/chat/presentation/pages/reserva_detail_screen.dart`
- Create: `lib/core/widgets/missing_argument_screen.dart`
- Test: `test/core/widgets/missing_argument_screen_test.dart`

**Interfaces:**
- Consumes: `context.l10n`.
- Produces: `MissingArgumentScreen({required String mensaje, String rutaVuelta = '/dashboard'})` — widget que muestra un mensaje accionable y un botón de regreso, en lugar de una pantalla en blanco.

- [ ] **Step 1: Escribir el test del widget de recuperación**

Crear `test/core/widgets/missing_argument_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/widgets/missing_argument_screen.dart';

void main() {
  testWidgets('muestra el mensaje y un boton de regreso', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MissingArgumentScreen(mensaje: 'No se encontró el vehículo'),
      ),
    );
    expect(find.text('No se encontró el vehículo'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);
  });

  testWidgets('nunca renderiza una pantalla vacia', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: MissingArgumentScreen(mensaje: 'Falta el dato')),
    );
    expect(find.byType(Text), findsWidgets);
  });
}
```

- [ ] **Step 2: Ejecutar el test y confirmar que falla**

```bash
flutter test test/core/widgets/missing_argument_screen_test.dart
```

Esperado: FALLA — `missing_argument_screen.dart` no existe.

- [ ] **Step 3: Crear el widget**

Crear `lib/core/widgets/missing_argument_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Se muestra cuando una ruta se abre sin el argumento que necesita —
/// por ejemplo al recargar la pagina o al compartir un enlace directo.
/// Sustituye a la pantalla en blanco que producia el cast de un `extra` nulo.
class MissingArgumentScreen extends StatelessWidget {
  final String mensaje;
  final String rutaVuelta;

  const MissingArgumentScreen({
    super.key,
    required this.mensaje,
    this.rutaVuelta = '/dashboard',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.search_off, size: 64),
              const SizedBox(height: 16),
              Text(mensaje, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go(rutaVuelta),
                child: const Text('Volver'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Ejecutar el test y confirmar que pasa**

```bash
flutter test test/core/widgets/missing_argument_screen_test.dart
```

Esperado: 2 tests PASAN.

- [ ] **Step 5: Pasar el identificador por parámetro de ruta**

En `app_router.dart`, cambiar `/vehicle_profile` para aceptar el id en la ruta y conservar `extra` solo como atajo de rendimiento:

```dart
      GoRoute(
        path: '/vehicle_profile/:vehiculoId',
        pageBuilder: (context, state) {
          final id = state.pathParameters['vehiculoId'];
          if (id == null || id.isEmpty) {
            return buildPageWithFadeThrough(
              context: context,
              state: state,
              child: const MissingArgumentScreen(
                mensaje: 'No se indicó ningún vehículo.',
              ),
            );
          }
          return buildPageWithFadeThrough(
            context: context,
            state: state,
            child: VehicleProfileScreen(
              vehiculoId: id,
              vehiculoPrecargado: state.extra is VehicleModel
                  ? state.extra as VehicleModel
                  : null,
            ),
          );
        },
      ),
```

- [ ] **Step 6: Hacer que la pantalla cargue el vehículo cuando no venga precargado**

En `vehicle_profile_screen.dart`, sustituir el constructor y el acceso al `extra` por:

```dart
class VehicleProfileScreen extends StatefulWidget {
  final String vehiculoId;
  final VehicleModel? vehiculoPrecargado;

  const VehicleProfileScreen({
    super.key,
    required this.vehiculoId,
    this.vehiculoPrecargado,
  });
  ...
```

Y en el `State`, resolver el modelo con carga diferida:

```dart
  VehicleModel? _vehiculo;
  bool _cargando = false;
  String? _errorCarga;

  @override
  void initState() {
    super.initState();
    _vehiculo = widget.vehiculoPrecargado;
    if (_vehiculo == null) _cargarVehiculo();
  }

  Future<void> _cargarVehiculo() async {
    setState(() { _cargando = true; _errorCarga = null; });
    try {
      final doc = await FirebaseFirestore.instance
          .collection(FirestoreCollections.vehiculos)
          .doc(widget.vehiculoId)
          .get();
      if (!mounted) return;
      if (!doc.exists) {
        setState(() { _cargando = false; _errorCarga = 'notFound'; });
        return;
      }
      setState(() {
        _vehiculo = VehicleModel.fromMap(doc.data()!, doc.id);
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _cargando = false; _errorCarga = 'error'; });
    }
  }
```

Y al inicio del `build`, antes de usar `_vehiculo`:

```dart
    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_errorCarga != null || _vehiculo == null) {
      return const MissingArgumentScreen(
        mensaje: 'No se pudo cargar este vehículo.',
        rutaVuelta: '/garage',
      );
    }
    final vehiculo = _vehiculo!;
```

- [ ] **Step 7: Aplicar el mismo patrón a las tres pantallas restantes**

Repetir exactamente los pasos 5 y 6 para:

- `/service_history` → `path: '/service_history/:vehiculoId'`; `ServiceHistoryScreen({required String vehiculoId})`; mensaje `'No se pudo cargar el historial de este vehículo.'`, `rutaVuelta: '/garage'`.
- `/initiate_service` → `path: '/initiate_service/:vehiculoId'`; `InitiateServiceScreen({required String vehiculoId, VehicleModel? vehiculoPrecargado})`; mensaje `'No se pudo cargar el vehículo del servicio.'`, `rutaVuelta: '/mechanic_dashboard'`.
- `/reserva_detail` → `path: '/reserva_detail/:reservaId'`; `ReservaDetailScreen({required String reservaId, ReservaModel? reservaPrecargada})`; carga desde `FirestoreCollections.reservas`; mensaje `'No se pudo cargar esta reserva.'`, `rutaVuelta: '/chat_list'`.

- [ ] **Step 8: Actualizar todas las llamadas de navegación**

```bash
grep -rn "vehicle_profile\|service_history'\|initiate_service\|reserva_detail" lib/ --include=*.dart | grep -v "app_router.dart"
```

Sustituir cada `context.push('/vehicle_profile', extra: v)` por `context.push('/vehicle_profile/${v.idVehiculo}', extra: v)`, y análogamente para las otras tres. El `extra` se conserva para evitar una lectura extra cuando ya se tiene el modelo.

- [ ] **Step 9: Actualizar el contrato documentado y los conjuntos de rutas**

En `app_router.dart:130-135`, reemplazar el comentario por:

```dart
/// Route expectations:
/// - /vehicle_profile/:vehiculoId   — extra opcional: VehicleModel (precarga)
/// - /service_history/:vehiculoId   — extra opcional: VehicleModel (precarga)
/// - /initiate_service/:vehiculoId  — extra opcional: VehicleModel (precarga)
/// - /reserva_detail/:reservaId     — extra opcional: ReservaModel (precarga)
/// Ninguna pantalla depende de `extra`: todas resuelven el argumento desde su id.
```

`_matchesRouteSet` (`:117-126`) ya cubre los prefijos con `path.startsWith('$route/')`, por lo que `_ownerRoutes` y `_mechanicRoutes` no requieren cambios.

- [ ] **Step 10: Verificar en el navegador que ninguna de las cinco queda en blanco**

```javascript
// verify-blancas.js
const H = require('./lib.js');
const RUTAS = [
  ['owner', '/vehicle_profile/no-existe'],
  ['owner', '/service_history/no-existe'],
  ['owner', '/user_profile'],
  ['taller', '/initiate_service/no-existe'],
  ['taller', '/reserva_detail/no-existe'],
];
(async () => {
  let fallos = 0;
  for (const [rol, ruta] of RUTAS) {
    const { browser, page } = await H.launch();
    await H.boot(page);
    await H.login(page, rol);
    await page.waitForTimeout(5000);
    await page.goto('http://localhost:51046' + ruta, { waitUntil: 'load', timeout: 120000 });
    await page.waitForTimeout(15000);
    const txt = await page.evaluate(() => (document.body.innerText || '').trim());
    const ok = txt.length > 0;
    console.log(`${ok ? 'OK  ' : 'FALLO'} ${ruta} -> ${JSON.stringify(txt.slice(0, 90))}`);
    if (!ok) fallos++;
    await browser.close();
  }
  if (fallos > 0) { console.error(`${fallos} rutas siguen en blanco`); process.exit(1); }
  console.log('OK: ninguna ruta queda en blanco');
})();
```

Esperado: `OK: ninguna ruta queda en blanco`.

- [ ] **Step 11: Ejecutar la suite completa de Dart**

```bash
flutter test 2>&1 | tail -20
flutter analyze --no-fatal-infos 2>&1 | tail -10
```

Esperado: tests PASAN, `analyze` sin errores nuevos.

- [ ] **Step 12: Commit**

```bash
git add lib/core/router/app_router.dart lib/core/widgets/missing_argument_screen.dart lib/features test/core/widgets/missing_argument_screen_test.dart
git commit -m "fix(router): resolver argumentos desde la ruta y no desde extra

Cinco pantallas casteaban state.extra a un tipo no nulable, por lo que una
recarga o un enlace directo producia 'Null is not a subtype of VehicleModel'
y una pantalla en blanco. Ahora el id viaja en la ruta, el modelo se carga si
no viene precargado, y el caso de fallo muestra MissingArgumentScreen."
```

---

### Task 13: Hacer que la aprobación de taller restrinja el acceso

Corrige **P-03**. El enrutado **sí** bloquea a un mecánico pendiente (`app_router.dart:216-221`), pero: (a) `UserModel.estado` toma por defecto `'activo'` cuando el campo falta (`user_model.dart:149`), un *fail-open* que deja pasar a todo documento heredado — el sondeo de `usuarios` confirmó que los documentos existentes **no tienen** campo `estado`; y (b) `firestore.rules` `isMecanico()` (`:30-34`) nunca consulta el estado, así que un mecánico pendiente bloqueado en la interfaz conserva el acceso completo a los datos vía API.

**Files:**
- Modify: `lib/core/models/user_model.dart:149`
- Modify: `firestore.rules:30-34`
- Test: `test/core/models/user_model_test.dart` (ampliar)
- Test: `test_rules/mecanico-scope.test.js` (ampliar)

**Interfaces:**
- Consumes: `isVinculadoAlVehiculo` (Tarea 9).
- Produces: sin cambios de firma. `UserModel.fromMap` cambia su valor por defecto de `estado`.

- [ ] **Step 1: Escribir el test de reglas que falla**

Añadir a `test_rules/mecanico-scope.test.js`:

```javascript
describe('estado de aprobacion del mecanico', () => {
  test('un mecanico PENDIENTE no accede a datos aunque este vinculado', async () => {
    await seed(env, async (s) => {
      await s.collection('usuarios').doc(UIDS.taller1).set({
        id_usuario: UIDS.taller1, rol: 'Taller', estado: 'pendiente',
      });
      await s.collection('vehiculos').doc('v1').set({
        id_vehiculo: 'v1', id_propietario: UIDS.owner1,
        talleres_vinculados: [UIDS.taller1],
      });
      await s.collection('historial_mantenimientos').doc('h1').set({
        id_vehiculo: 'v1', id_taller: UIDS.taller1,
      });
    });
    const db = env.authenticatedContext(UIDS.taller1).firestore();
    await assertFails(db.collection('vehiculos').doc('v1').get());
    await assertFails(db.collection('historial_mantenimientos').doc('h1').get());
  });

  test('un mecanico SIN campo estado tampoco accede (fail-closed)', async () => {
    await seed(env, async (s) => {
      await s.collection('usuarios').doc(UIDS.taller1).set({
        id_usuario: UIDS.taller1, rol: 'Taller',
      });
      await s.collection('vehiculos').doc('v1').set({
        id_vehiculo: 'v1', id_propietario: UIDS.owner1,
        talleres_vinculados: [UIDS.taller1],
      });
    });
    const db = env.authenticatedContext(UIDS.taller1).firestore();
    await assertFails(db.collection('vehiculos').doc('v1').get());
  });
});
```

- [ ] **Step 2: Añadir el test del modelo**

Añadir a `test/core/models/user_model_test.dart`:

```dart
  test('estado por defecto es pendiente cuando el campo falta (fail-closed)', () {
    final u = UserModel.fromMap(
      {'id_usuario': 'u1', 'correo': 'u@x.com', 'rol': 'Taller'},
      'u1',
    );
    expect(u.estado, 'pendiente');
  });

  test('estado explicito se respeta', () {
    final u = UserModel.fromMap(
      {'id_usuario': 'u1', 'correo': 'u@x.com', 'rol': 'Taller', 'estado': 'aprobado'},
      'u1',
    );
    expect(u.estado, 'aprobado');
  });
```

- [ ] **Step 3: Ejecutar ambos y confirmar que fallan**

```bash
flutter test test/core/models/user_model_test.dart 2>&1 | tail -15
cd test_rules && npx jest mecanico-scope --runInBand --forceExit 2>&1 | tail -20
```

Esperado: FALLAN los cuatro tests nuevos.

- [ ] **Step 4: Cambiar el valor por defecto en el modelo**

En `lib/core/models/user_model.dart:149`, sustituir:

```dart
      estado: (map['estado'] ?? 'pendiente').toString(),
```

- [ ] **Step 5: Exigir estado aprobado en `isMecanico()`**

En `firestore.rules`, reemplazar `isMecanico()` (líneas 30-34) por:

```
    // Mecanico APROBADO. Un taller pendiente de aprobacion no accede a datos:
    // el bloqueo del enrutador no basta, la API es accesible directamente.
    function isMecanico() {
      return isAuthenticated() &&
        exists(/databases/$(database)/documents/usuarios/$(request.auth.uid)) &&
        getUserData().rol in ['Mecanico', 'Taller'] &&
        getUserData().get('estado', 'pendiente') in ['aprobado', 'activo'];
    }
```

Se acepta `'activo'` además de `'aprobado'` porque es el valor que ya usan los documentos migrados; el `default` de `get()` es `'pendiente'`, de modo que un documento sin el campo queda fuera.

- [ ] **Step 6: Ejecutar ambos y confirmar que pasan**

```bash
flutter test test/core/models/user_model_test.dart 2>&1 | tail -10
cd test_rules && npm test 2>&1 | tail -20
```

Esperado: todo PASA.

- [ ] **Step 7: Escribir la migración de los documentos existentes**

Los mecánicos ya operativos tienen documentos **sin** campo `estado` y ahora quedarían bloqueados. Crear `functions/src/backfillEstadoMecanicos.js`:

```javascript
// Relleno puntual: marca 'aprobado' a los mecanicos ya operativos, para que el
// nuevo defecto fail-closed de `estado` no los expulse.
// REVISAR LA LISTA A MANO antes de ejecutar: aprobar en masa es una decision
// de negocio, no tecnica.
const admin = require('firebase-admin');
admin.initializeApp();

(async () => {
  const db = admin.firestore();
  const snap = await db.collection('usuarios').get();
  const candidatos = [];
  snap.forEach((doc) => {
    const d = doc.data();
    const rol = String(d.rol || '').trim().toLowerCase();
    if ((rol === 'mecanico' || rol === 'taller') && d.estado === undefined) {
      candidatos.push({ uid: doc.id, correo: d.correo, nombre: d.nombre_completo });
    }
  });
  console.log(`Mecanicos sin campo estado: ${candidatos.length}`);
  console.table(candidatos);
  if (process.argv[2] !== '--aplicar') {
    console.log('\nEjecucion en seco. Repite con --aplicar para escribir.');
    process.exit(0);
  }
  const batch = db.batch();
  for (const c of candidatos) {
    batch.update(db.collection('usuarios').doc(c.uid), { estado: 'aprobado' });
  }
  await batch.commit();
  console.log(`Actualizados: ${candidatos.length}`);
  process.exit(0);
})();
```

Ejecutar primero en seco (`node functions/src/backfillEstadoMecanicos.js`) y revisar la tabla antes de `--aplicar`.

- [ ] **Step 8: Commit**

```bash
git add lib/core/models/user_model.dart firestore.rules test/core/models/user_model_test.dart test_rules/mecanico-scope.test.js functions/src/backfillEstadoMecanicos.js
git commit -m "security: la aprobacion de taller pasa a restringir el acceso a datos

El enrutador bloqueaba al mecanico pendiente, pero isMecanico() no consultaba
el estado, asi que la API seguia accesible; y UserModel.estado tomaba 'activo'
por defecto, dejando pasar a todo documento sin el campo. Ambos pasan a ser
fail-closed. Se incluye migracion en seco para los mecanicos ya operativos."
```

---

## Fase E — Endurecer el entorno

### Task 14: Activar App Check

Corrige **C-07**. `grep -rni "app_check|appcheck"` sobre `lib/`, `pubspec.yaml`, `functions/index.js` y `web/index.html` devuelve **cero coincidencias**. Sin App Check, la configuración pública del bundle permite operar contra Auth, Firestore, Storage y Functions **sin pasar por la aplicación** — es exactamente el método con el que esta auditoría demostró C-01.

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/main.dart` (tras la inicialización de Firebase)
- Modify: `lib/config/secrets.dart`, `.env.example`

**Interfaces:**
- Consumes: `AppSecrets`.
- Produces: `AppSecrets.recaptchaSiteKey` → `String`.

- [ ] **Step 1: Añadir la dependencia**

```bash
flutter pub add firebase_app_check
```

- [ ] **Step 2: Añadir el getter de la clave de reCAPTCHA**

En `lib/config/secrets.dart`:

```dart
  // App Check (web) — clave de sitio de reCAPTCHA Enterprise
  static String get recaptchaSiteKey =>
      const String.fromEnvironment('RECAPTCHA_SITE_KEY', defaultValue: '');
```

Y en `.env.example`:

```
# App Check — clave de sitio de reCAPTCHA Enterprise (web)
RECAPTCHA_SITE_KEY=
```

- [ ] **Step 3: Activar App Check en el arranque**

En `lib/main.dart`, inmediatamente después de la línea que registra `=== [AutoDoc Init] Firebase inicializado con éxito ===` (`:105`), añadir:

```dart
  try {
    await FirebaseAppCheck.instance.activate(
      webProvider: ReCaptchaEnterpriseProvider(AppSecrets.recaptchaSiteKey),
      androidProvider: AndroidProvider.playIntegrity,
      appleProvider: AppleProvider.deviceCheck,
    );
    debugPrint("=== [AutoDoc Init] App Check activado ===");
  } catch (e) {
    // No bloquear el arranque si App Check falla: se despliega primero en modo
    // monitorizacion y solo despues se activa el enforcement en la consola.
    debugPrint("=== [AutoDoc Init] App Check no disponible: $e ===");
  }
```

Con el correspondiente import:

```dart
import 'package:firebase_app_check/firebase_app_check.dart';
```

- [ ] **Step 4: Verificar que el arranque emite el token de App Check**

```javascript
// verify-appcheck.js
const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch({ headless: true });
  const p = await (await b.newContext()).newPage();
  const appcheck = [];
  p.on('response', r => { if (r.url().includes('firebaseappcheck.googleapis.com')) appcheck.push(r.status()); });
  const logs = [];
  p.on('console', m => { if (m.text().includes('App Check')) logs.push(m.text()); });
  await p.goto('http://localhost:51046/', { waitUntil: 'load', timeout: 120000 });
  await p.waitForTimeout(30000);
  console.log('peticiones a firebaseappcheck:', appcheck);
  console.log('logs:', logs);
  if (appcheck.length === 0) { console.error('FALLO: no se emitio ningun token de App Check'); process.exit(1); }
  console.log('OK: App Check activo');
  await b.close();
})();
```

Esperado: `OK: App Check activo`.

- [ ] **Step 5: Documentar el despliegue en dos fases**

Añadir a `docs/RUNBOOK.md` una sección:

```markdown
## App Check — activación

App Check debe desplegarse en **dos fases** para no dejar fuera a usuarios con
clientes antiguos en caché:

1. **Monitorización** (semana 1): registrar las apps en la consola de Firebase
   → App Check, con enforcement **desactivado**. Revisar en las métricas el
   porcentaje de peticiones con token válido.
2. **Enforcement** (semana 2, si el porcentaje supera el 98 %): activar el
   enforcement en Firestore, Storage y Functions, uno a uno, verificando entre
   cada paso.

Requisito previo: la Tarea 1 de este plan (cabeceras de caché) debe estar en
producción, porque de lo contrario los clientes antiguos sin App Check quedan
atrapados en caché y el enforcement los expulsaría de forma permanente.
```

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/main.dart lib/config/secrets.dart .env.example docs/RUNBOOK.md
git commit -m "security: activar App Check en web, Android e iOS

Sin App Check, la configuracion publica del bundle permite operar contra
Firestore, Storage y Functions sin pasar por la aplicacion, que es como se
demostro la fuga C-01. Se activa en modo tolerante a fallos; el enforcement se
habilita en consola en una segunda fase documentada en el RUNBOOK."
```

---

### Task 15: Ejecutar los tests de reglas en CI y unificar los workflows

Corrige **T-04**, **T-05** y **T-06**. Hoy `ci.yml` y `flutter_ci.yml` se disparan en el mismo evento con reglas contradictorias (`--no-fatal-infos` frente a `analyze` estricto; Flutter 3.32.0 fijo frente a `channel: stable`), la puerta de cobertura lleva `continue-on-error: true`, y ningún job ejecuta tests de reglas, de integración ni de funciones.

**Files:**
- Modify: `.github/workflows/ci.yml`
- Delete: `.github/workflows/flutter_ci.yml`

**Interfaces:**
- Consumes: `test_rules/` (Tarea 6).
- Produces: job `rules_tests`, requisito de los jobs de despliegue.

- [ ] **Step 1: Eliminar el workflow duplicado**

```bash
git rm .github/workflows/flutter_ci.yml
```

Todo lo que aportaba (`dart format --set-exit-if-changed`, `flutter analyze` estricto) se integra en `ci.yml` en el paso siguiente, de modo que no se pierde ninguna comprobación.

- [ ] **Step 2: Añadir el job de tests de reglas**

Insertar en `ci.yml`, tras `analyze_and_test`:

```yaml
  rules_tests:
    name: Firestore & Storage Rules Tests
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install Firebase CLI
        run: npm install -g firebase-tools

      - name: Install rules test dependencies
        working-directory: test_rules
        run: npm ci

      - name: Run rules tests against the emulator
        working-directory: test_rules
        run: npm test
```

- [ ] **Step 3: Endurecer el job de análisis y tests**

Reemplazar los pasos de `analyze_and_test` posteriores a `flutter pub get` por:

```yaml
      - name: Check formatting
        run: dart format --output=none --set-exit-if-changed .

      - name: Run flutter analyze
        run: flutter analyze

      - name: Run unit & widget tests
        run: flutter test --coverage

      - name: Install lcov
        run: sudo apt-get update && sudo apt-get install -y lcov bc

      - name: Check test coverage threshold
        run: |
          COVERAGE=$(lcov --summary coverage/lcov.info 2>&1 | grep "lines" | awk '{print $2}' | sed 's/%//')
          echo "Coverage: $COVERAGE%"
          MIN=25
          if (( $(echo "$COVERAGE < $MIN" | bc -l) )); then
            echo "❌ Coverage $COVERAGE% está por debajo del mínimo $MIN%"
            exit 1
          fi
          echo "✅ Coverage $COVERAGE% pasa el umbral"
```

Dos cambios deliberados: se instalan `lcov` y `bc` (antes ausentes, por lo que el paso fallaba en silencio) y **se elimina `continue-on-error`**. El umbral baja de 55 a **25** porque 55 era inalcanzable —la cobertura real es de ~2.263 líneas de test para 35.712 de producción— y una puerta que no se puede pasar se acaba desactivando. 25 es superable con las tareas de este plan y sube desde ahí.

- [ ] **Step 4: Exigir los tests de reglas antes de desplegar**

En los jobs `deploy_staging` y `deploy_production`, ampliar `needs`:

```yaml
    needs: [analyze_and_test, rules_tests, build_web_smoke]
```

Es el cambio que impide desplegar reglas sin haberlas probado.

- [ ] **Step 5: Añadir una prueba de humo posterior al despliegue**

Al final de `deploy_production`, sustituir el paso `Create GitHub Release tag` —que hoy solo ejecuta `echo` y no crea ninguna etiqueta— por:

```yaml
      - name: Post-deploy smoke test
        run: |
          URL="https://autodoc-6ef5a.web.app"
          CODE=$(curl -s -o /dev/null -w "%{http_code}" "$URL")
          if [ "$CODE" != "200" ]; then echo "❌ Hosting responde $CODE"; exit 1; fi
          if ! curl -s "$URL" | grep -q 'flutter_bootstrap.js'; then
            echo "❌ index.html no referencia flutter_bootstrap.js"; exit 1
          fi
          CC=$(curl -s -I "$URL/main.dart.js" | grep -i '^cache-control' || true)
          echo "Cache-Control de main.dart.js: $CC"
          if echo "$CC" | grep -qi 'immutable'; then
            echo "❌ main.dart.js sigue marcado como immutable"; exit 1
          fi
          echo "✅ Smoke test correcto"

      - name: Create version tag
        run: |
          VERSION=$(grep '^version:' pubspec.yaml | head -1 | awk '{print $2}')
          git tag "v$VERSION"
          git push origin "v$VERSION"
```

El humo verifica explícitamente que la corrección de la Tarea 1 sigue en vigor.

- [ ] **Step 6: Validar la sintaxis de los workflows**

```bash
node -e "
const fs=require('fs');
const y=fs.readFileSync('.github/workflows/ci.yml','utf8');
for (const j of ['analyze_and_test','rules_tests','build_web_smoke','deploy_staging','deploy_production']) {
  if (!y.includes(j+':')) { console.error('FALTA el job '+j); process.exit(1); }
}
if (y.includes('continue-on-error: true')) { console.error('FALLO: queda un continue-on-error'); process.exit(1); }
if (!y.includes('--no-web-resources-cdn')) { console.error('FALLO: falta --no-web-resources-cdn'); process.exit(1); }
console.log('OK: ci.yml contiene los 5 jobs, sin continue-on-error y con CanvasKit local');
"
ls .github/workflows/
```

Esperado: el mensaje `OK: ...` y que `flutter_ci.yml` ya no aparezca.

- [ ] **Step 7: Commit**

```bash
git add .github/workflows/
git commit -m "ci: ejecutar los tests de reglas y convertir la cobertura en puerta real

Se elimina flutter_ci.yml, que duplicaba ci.yml con reglas contradictorias, y
se integran sus comprobaciones. Se anade el job rules_tests como requisito de
ambos despliegues, se instalan lcov y bc (ausentes, el paso fallaba en
silencio), se quita continue-on-error y se ajusta el umbral de 55 a 25, que es
alcanzable. El paso final crea ahora una etiqueta real en lugar de un echo, y
el humo post-despliegue verifica que main.dart.js no vuelva a ser immutable."
```

---

### Task 16: Separar entornos y rotar la clave expuesta

Corrige **C-08** y **S-01**. `.firebaserc` declara **un único** proyecto, `autodoc-6ef5a`, y la prueba de que se usa como entorno de pruebas está en los datos: talleres llamados «wowow», «Mecánico 1» y «Gola», el token del taller con `name: "hola"`, una placa `"128"`. La clave de Maps `AIzaSyBp0xI7P-...` está en el historial de git desde `89e9f6b`, por lo que retirarla del árbol (Tarea 4) no la revoca.

**Files:**
- Modify: `.firebaserc`
- Modify: `.github/workflows/ci.yml`
- Modify: `web/firebase-messaging-sw.js`
- Modify: `docs/RUNBOOK.md`

**Interfaces:**
- Consumes: nada.
- Produces: alias de proyecto `staging` y `production` en `.firebaserc`.

- [ ] **Step 1: Crear el proyecto de staging**

```bash
firebase projects:create autodoc-staging --display-name "AutoDoc Staging"
firebase use --add
```

Seleccionar `autodoc-staging` y asignarle el alias `staging`. Requiere permisos de facturación en la organización; si no están disponibles, este paso lo ejecuta quien los tenga y el resto del plan continúa.

- [ ] **Step 2: Declarar los alias en `.firebaserc`**

```json
{
  "projects": {
    "default": "autodoc-staging",
    "staging": "autodoc-staging",
    "production": "autodoc-6ef5a"
  },
  "targets": {
    "autodoc-6ef5a": {
      "hosting": {
        "app": ["autodoc-6ef5a"],
        "landing": ["autodoc-landing-6ef5a"]
      }
    },
    "autodoc-staging": {
      "hosting": {
        "app": ["autodoc-staging"]
      }
    }
  }
}
```

`default` apunta deliberadamente a **staging**: un `firebase deploy` sin `--project` explícito no debe poder alcanzar producción.

- [ ] **Step 3: Parametrizar el service worker de FCM**

`web/firebase-messaging-sw.js:4-11` codifica a mano el proyecto de producción, mientras `lib/firebase_options.dart` lee de `AppSecrets`: son dos fuentes de verdad, y un build de staging usaría el FCM de producción. Sustituir los valores literales por marcadores:

```javascript
firebase.initializeApp({
  apiKey: '$FIREBASE_WEB_API_KEY',
  appId: '$FIREBASE_APP_ID_WEB',
  messagingSenderId: '$FIREBASE_MESSAGING_SENDER_ID',
  projectId: '$FIREBASE_PROJECT_ID',
  authDomain: '$FIREBASE_AUTH_DOMAIN',
  storageBucket: '$FIREBASE_STORAGE_BUCKET',
});
```

- [ ] **Step 4: Sustituir los marcadores en el build**

Ampliar el paso de inyección creado en la Tarea 5:

```yaml
      - name: Inject web runtime config
        run: |
          sed -i "s|\$GOOGLE_SIGNIN_CLIENT_ID_WEB|${{ secrets.GOOGLE_SIGNIN_CLIENT_ID_WEB }}|g" web/index.html
          sed -i \
            -e "s|\$FIREBASE_WEB_API_KEY|${{ secrets.FIREBASE_WEB_API_KEY }}|g" \
            -e "s|\$FIREBASE_APP_ID_WEB|${{ secrets.FIREBASE_APP_ID_WEB }}|g" \
            -e "s|\$FIREBASE_MESSAGING_SENDER_ID|${{ secrets.FIREBASE_MESSAGING_SENDER_ID }}|g" \
            -e "s|\$FIREBASE_PROJECT_ID|${{ secrets.FIREBASE_PROJECT_ID }}|g" \
            -e "s|\$FIREBASE_AUTH_DOMAIN|${{ secrets.FIREBASE_AUTH_DOMAIN }}|g" \
            -e "s|\$FIREBASE_STORAGE_BUCKET|${{ secrets.FIREBASE_STORAGE_BUCKET }}|g" \
            web/firebase-messaging-sw.js
          grep -q '\$FIREBASE' web/firebase-messaging-sw.js && { echo "❌ Quedan marcadores sin sustituir"; exit 1; } || true
          echo "✅ configuracion web inyectada"
```

- [ ] **Step 5: Apuntar el despliegue de staging al nuevo proyecto**

En `deploy_staging`, añadir el despliegue de reglas —hoy solo se despliegan en producción, es decir, **las reglas nunca se prueban en un entorno real antes de producción**:

```yaml
      - name: Deploy Firestore Rules & Indexes to Staging
        run: firebase deploy --only firestore --project staging
        env:
          FIREBASE_TOKEN: ${{ secrets.FIREBASE_TOKEN }}

      - name: Deploy Storage Rules to Staging
        run: firebase deploy --only storage --project staging
        env:
          FIREBASE_TOKEN: ${{ secrets.FIREBASE_TOKEN }}
```

- [ ] **Step 6: Rotar la clave de Google Maps**

Ejecutar en Google Cloud Console, sobre el proyecto `autodoc-6ef5a`:

1. APIs y servicios → Credenciales → localizar la clave `***REMOVED-GOOGLE-MAPS-API-KEY***`.
2. Crear una **clave nueva** restringida por: referrers HTTP (`https://autodoc-6ef5a.web.app/*`, `https://autodocsv.com/*`, `http://localhost:*`) y por APIs (solo Maps JavaScript API y las que realmente se usen).
3. Guardar la clave nueva como secreto `GOOGLE_MAPS_API_KEY` en GitHub y en el `.env` local.
4. **Eliminar la clave antigua**, no solo restringirla: está en el historial de git de forma permanente.

- [ ] **Step 7: Documentar el mapa de entornos**

Añadir a `docs/RUNBOOK.md`:

```markdown
## Entornos

| Alias | Proyecto Firebase | Uso | Datos |
|---|---|---|---|
| `staging` | `autodoc-staging` | Desarrollo y QA. **Alias por defecto.** | Sintéticos, desechables |
| `production` | `autodoc-6ef5a` | Producción | Reales. Nunca para pruebas |

Reglas de operación:
- `firebase deploy` sin `--project` va a **staging** por diseño.
- Toda regla de Firestore o Storage se despliega **primero** en staging, donde
  CI la valida con `test_rules/`, y solo después en producción.
- Desarrollo local: `firebase emulators:start`. Nunca apuntar a `production`.
- Los datos de prueba presentes hoy en producción («wowow», «Mecánico 1»,
  «Gola», placa «128») deben migrarse a staging y eliminarse de producción.
```

- [ ] **Step 8: Verificar que el proyecto por defecto no es producción**

```bash
node -e "
const c=require('./.firebaserc');
console.log('default =', c.projects.default);
if (c.projects.default === 'autodoc-6ef5a') { console.error('FALLO: el proyecto por defecto es produccion'); process.exit(1); }
console.log('OK: el proyecto por defecto no es produccion');
"
grep -rn "AIzaSyBp0xI7P" web/ lib/ .github/ && echo "FALLO: la clave antigua sigue presente" || echo "OK: la clave antigua no esta en el arbol"
```

Esperado: ambos `OK`.

- [ ] **Step 9: Commit**

```bash
git add .firebaserc .github/workflows/ci.yml web/firebase-messaging-sw.js docs/RUNBOOK.md
git commit -m "chore(env): separar staging de produccion y parametrizar el SW de FCM

.firebaserc declaraba un solo proyecto y se desarrollaba contra produccion
(talleres 'wowow', 'Gola', placa '128' en datos reales). El alias por defecto
pasa a ser staging para que un deploy sin --project no alcance produccion, y
staging despliega ahora tambien las reglas, que hasta ahora solo se
desplegaban directamente en produccion. El service worker de FCM deja de
codificar el proyecto a mano."
```

---

## Verificación final

- [ ] **Suite de reglas completa en verde**

```bash
cd test_rules && npm test 2>&1 | tail -20
```

Esperado: todos los tests de `usuarios`, `vehiculos`, `mecanico-scope`, `talleres-publico` y `storage` PASAN.

- [ ] **Suite de Dart en verde y análisis limpio**

```bash
flutter test 2>&1 | tail -15
flutter analyze 2>&1 | tail -10
dart format --output=none --set-exit-if-changed .
```

- [ ] **Reproducir el sondeo de la auditoría contra el emulador**

```bash
firebase emulators:exec --only firestore --project autodoc-rules-test "node verify-fuga.js"
```

Esperado: `OK: ninguna coleccion completa es legible por un usuario cualquiera`.

- [ ] **Recorrido en navegador de las cinco pantallas antes en blanco**

```bash
NODE_PATH="$APPDATA/npm/node_modules" node verify-blancas.js
```

Esperado: `OK: ninguna ruta queda en blanco`.

- [ ] **Comprobar las cabeceras de caché en staging tras el primer despliegue**

```bash
curl -s -I https://autodoc-staging.web.app/main.dart.js | grep -i cache-control
curl -s -I https://autodoc-staging.web.app/ | grep -i cache-control
```

Esperado: `no-cache` en ambos, y `immutable` **únicamente** bajo `/canvaskit/`.

- [ ] **Actualizar la lista de comprobación de la auditoría**

Revisar el checklist de la sección 9 del informe de auditoría y marcar los elementos 1, 2, 3, 4, 6, 11, 11b, 11c, 12, 15, 23, 24, 25, 26, 27, 28, 30, 31, 44 y 45. Los elementos de accesibilidad (16, 17), rendimiento (47) y legales (42, 43) **quedan fuera del alcance de este plan** y requieren uno propio.

---

## Fuera de alcance

Este plan cubre exclusivamente los hallazgos de severidad **Crítica**. Quedan pendientes de un plan propio, en orden de prioridad sugerido:

1. **Accesibilidad** (F-01 a F-09): la navegación principal del propietario es inalcanzable por teclado y lector de pantalla; trampa de foco; controles sin nombre; el campo de contraseña se anuncia como «••••••••»; `autocomplete="off"`; sin encabezados ni regiones. Son fallos de **nivel A** de WCAG 2.1 y bloquean cualquier compromiso de accesibilidad.
2. **Bloqueantes legales y de tienda** (P-01, P-02): los enlaces de privacidad y términos apuntan a `autodoc.app`, un dominio distinto del producto; no hay borrado de cuenta ni exportación de datos iniciados por el usuario, ambos exigidos por App Store y Play.
3. **Migración de Cloud Functions a la API v2**: las 12 funciones usan la v1, con fin de soporte anunciado.
4. **Autorización por *custom claims*** (A-01, H-04): ninguno de los tres tokens verificados contiene claims de rol, de modo que cada regla paga lecturas de Firestore y puede alcanzar el límite de 20 `get()` por consulta.
5. **Separación del identificador de taller del `uid` del usuario** (H-05): hoy un taller con dos empleados es irrepresentable.
6. **Rendimiento** (F-14, F-16, D-06): 30 s hasta el render completo del dashboard, directorio sin resultados, ~12 MB de carga inicial.
7. **Dependencias externas en la UI** (F-11, F-17, A-08): avatar desde `w3schools.com`, logotipo de Google desde `www.google.com`, imágenes de vehículo hotlinkeadas desde CDNs de terceros.
