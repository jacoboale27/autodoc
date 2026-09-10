# UX-02 — Recuperación ante error y deep links

Rama `fix/ux02`, cortada de `integracion/ola-1` (`ed2e8e1`).
Plan: `docs/superpowers/plans/2026-09-06-remediation-master-plan-crea-j-10-10.md` §7 UX-02.
Evidence IDs `EVID-UX-020..025`.

## Lo que estaba roto

El enunciado del plan pedía tres cosas. Dos eran defectos reales; la tercera resultó
ser un hueco de **evidencia**, no de configuración, y conviene decirlo sin adornos.

### 1. La pantalla de arranque fallido pedía algo que no se podía hacer

`lib/core/widgets/firebase_initialization_error_screen.dart` es lo único que ve el
usuario cuando Firebase Core no arranca (`lib/main.dart`, tras `FirebaseBootstrap`).
Su texto decía «Verifica tu conexión e **intenta recargar la página**» y la pantalla
**no ofrecía ningún control para hacerlo**: ni botón de reintento, ni de recarga. En
móvil, donde no hay barra de direcciones a mano, eso es un callejón sin salida.

Además sus textos eran literales en español dentro del widget — la única pantalla de
la app fuera del sistema de localización —, porque su `MaterialApp` de emergencia se
construía sin `localizationsDelegates`.

### 2. El 404 del router era una frase suelta

`lib/core/router/app_router.dart:385-386` resolvía cualquier ruta sin match con:

```dart
errorBuilder: (context, state) =>
    const Scaffold(body: Center(child: Text('Página no encontrada (404)'))),
```

Sin Inicio, sin Volver, sin localizar, y sin decir qué dirección había fallado.

### 3. El rewrite SPA ya existía — lo que faltaba era probarlo

`firebase.json` ya traía `{"source": "**", "destination": "/index.html"}` para el
target `app`. El hueco real: **ningún spec de la suite E2E de la app navegaba a otra
cosa que `/`** — todos los `page.goto` entraban por la raíz y seguían clicando. El
caso que rompe en producción (pegar una URL profunda, o recargar sobre ella) no
estaba cubierto por nada.

Lo que sí desinformaba era el `README.md`: documentaba servir la app con
`python -m http.server`, que no reescribe rutas, y presentaba el 404 resultante como
una limitación a sortear («navega desde la raíz») en vez de como un artefacto del
servidor de pruebas. Ahora apunta al emulador de Hosting, que lee el mismo
`firebase.json` que producción.

## Lo que se cambió

| Archivo | Cambio |
|---|---|
| `lib/core/widgets/firebase_initialization_error_screen.dart` | `StatefulWidget` con reintento, estado en vuelo y aviso de reintento fallido; textos por ARB; `MaterialApp` de emergencia con delegates |
| `lib/core/widgets/not_found_screen.dart` (nuevo) | 404 localizada con Inicio, Volver condicional y la ruta pedida |
| `lib/core/router/app_router.dart` | `errorBuilder` → `NotFoundScreen(attemptedPath: state.uri.path)` |
| `lib/main.dart` | `_startFirebaseCore` extraído; `_retryStartup` cableado al botón; `main` pasa a `Future<void>` |
| `lib/l10n/app_es.arb`, `app_en.arb` | 8 claves nuevas (`startupError*`, `notFound*`) en ambos idiomas |
| `README.md` | servir en local con el emulador de Hosting, no con `python -m http.server` |
| `e2e/tests/deep-links.spec.js` (nuevo) | 4 casos: fallback del servidor, coherencia con `firebase.json`, deep link a ruta pública + recarga, y ruta inexistente sin varar |
| `e2e/scripts/global-setup.js` | esperar también a Auth (9099), no solo a Firestore, antes de sembrar |
| `e2e/tests/propietario.spec.js`, `mecanico.spec.js` | la aserción de URL espera a la condición (30 s) en vez de fiarse del `sleep` fijo del `beforeEach` |

### Decisiones que no eran obvias

**El reintento devuelve `bool`, no `void`.** La primera versión hacía `await onRetry()`
y no podía distinguir un arranque recuperado de uno que seguía fallando. Ahora
`_retryStartup` sondea Firebase primero: si sigue caído devuelve `false` y la pantalla
dice que el intento falló; solo si Core levanta re-ejecuta `main`, que completa el
arranque y llama a `runApp` con la app real, sustituyendo la pantalla de error.

**Segundo toque bloqueado mientras hay un intento en vuelo.** Dos bootstraps
concurrentes de Firebase son exactamente el caso `duplicate-app` que `main.dart` ya
tiene que parchear.

**La causa del fallo nunca llega a la UI.** Va solo a `debugPrint`. Hay un test que lo
afirma (`never leaks the raw exception to the user`).

**La ruta inválida sí se le muestra al usuario, pero se registra solo el `path`.**
Es su propia entrada — un typo o un marcador viejo — y es lo que hace accionable la
página. En la telemetría se omite el query string, que es donde viajarían ids y tokens.

**«Volver» solo aparece si hay historial.** Entrando por deep link no lo hay, y un
botón que no hace nada es peor que ninguno. El test cubre la rama alcanzable (llegar
al 404 por `push` desde dentro de la app), no una inventada.

## Verificación

| Gate | Resultado |
|---|---|
| `flutter analyze` | `No issues found!` |
| `flutter test` (suite completa) | **1149/1149**, exit 0 |
| `test/core/widgets/firebase_initialization_error_screen_test.dart` | 6/6 |
| `test/core/router/app_router_not_found_screen_test.dart` | 5/5 |
| `e2e/tests/deep-links.spec.js` | 4/4, incluido el 404 **con sesión** |
| `e2e/tests/sesion-persistida.spec.js` | 1/1 |
| `e2e/tests/roles.spec.js` aislada | 3/3 corridas |
| Suite E2E completa de la app | **32 pasan, 2 `fixme`, exit 0**, en **tres corridas seguidas** |
| Puertos 8080/9099/9199/4400/5555 al salir | libres |

Tras cerrar el defecto 2 no se tocó ni un archivo Dart, así que `flutter analyze` y
`flutter test` siguen valiendo tal cual: el cambio vive entero en `e2e/`.

### TDD — los rojos que se vieron antes de implementar

Las tres suites se corrieron y fallaron antes de escribir una línea de implementación:

- 404: `The getter 'notFoundTitle' isn't defined for the type 'AppLocalizations'`.
- Arranque: `No named parameter with the name 'onRetry'` y las claves ARB ausentes.
- Sesión persistida: `TimeoutError: page.waitForFunction: Timeout 120000ms exceeded` en
  `esperarAppLista`, justo después del `page.reload()` — el punto exacto que predecía la
  lectura del plugin.

### Tests preexistentes que hubo que actualizar

Tres afirmaciones fijaban el literal viejo y por tanto **tenían que** romperse:
`app_router_test.dart:223`, `:312` y `app_router_unknown_route_test.dart:119`.
Ahora afirman `find.byType(NotFoundScreen)`, que es el contrato real y no una cadena.

## Trampas encontradas

**Un widget test sin `locale` no renderiza en español.** Los primeros cuatro rojos
tras implementar no eran del producto: el harness montaba `MaterialApp` sin `locale`,
así que la app pintaba en inglés mientras el test buscaba las cadenas ES cargadas a
mano con `AppLocalizations.delegate.load(const Locale('es'))`. Fijar
`locale: const Locale('es')` los puso los cuatro en verde de golpe.

**`SplashScreen` no se puede construir en un widget test.** Tocar «Ir al inicio»
navegando por el router *real* lleva a `/`, que monta `SplashScreen`, que hace un
null-check sobre algo que solo existe con Firebase vivo. Perseguir su árbol de
providers habría producido un test que prueba el harness, no la app. Se partió en dos
afirmaciones honestas: que el router real usa `NotFoundScreen`, y que el botón de la
pantalla navega a `/` — esto último contra un router mínimo con un destino de pega.

**`main` era `void`, no `Future<void>`.** El reintento no podía esperarla; `analyze`
lo cazó como `use_of_void_result`.

## Tres defectos del harness que salieron al escribir esto

Ninguno estaba en el enunciado de UX-02. Los tres los destapó el ser **el primer spec de
la suite de la app que navega a algo que no es `/`** — hasta ahora todos los `page.goto`
entraban por la raíz.

### 1. La siembra corría antes de que Auth estuviera arriba

`global-setup.js` esperaba a Firestore (8080) y sembraba. Pero sembrar **también crea
usuarios**, o sea habla con Auth (9099), que levanta por su cuenta y puede ir por detrás.
El síntoma: `FirebaseAppError ... ECONNREFUSED` dentro de `crearUsuario`, con Firestore ya
sirviendo, y la corrida entera cayéndose antes de empezar. Es exactamente el bug que QA-01
arregló un emulador más allá. Reproducido a voluntad: revirtiendo solo este arreglo, la
suite vuelve a caerse al sembrar.

Ahora espera a los dos, cada uno por su propio puerto.

### 2. Una sesión persistida rompía el cableado a emuladores en la siguiente carga completa

Con sesión iniciada, `page.goto('/garage')` arrancaba la app pero `auth.emulatorConfig`
**nunca** se pone: sondeado cada 5 s durante 60 s, siempre `false`, sin usuario y con el
router en `/login`. Sin sesión previa, la misma URL cablea emuladores en menos de 15 s.

En la consola del navegador de esa carga aparecen las dos cosas a la vez: un **400 contra
Auth de producción** —el intento de restaurar la sesión persistida con las claves falsas—
*antes* de que la app anuncie `EMULADORES: Auth :9099 ... NO se esta usando produccion`.
O sea, Auth se toca antes del redirect, que es justo la ventana contra la que avisa QA-01.

Consecuencia práctica: **no se podía ejercer por E2E ningún flujo que exigiera sesión y una
navegación de página completa.**

**Arreglado.** La causa está en el orden de arranque de flutterfire, no en la app:

`Firebase.initializeApp()` en web no retorna hasta que cada plugin termina su
`ensurePluginInitialized`, y el de `firebase_auth_web` (6.2.5,
`lib/firebase_auth_web.dart:84`) acaba con `await authDelegate.onWaitInitState()` —el
primer evento de `onAuthStateChanged`—. Con sesión persistida en IndexedDB ese evento no
llega hasta que el SDK de JS refresca el token guardado, o sea una petición de red, y todo
eso ocurre **dentro** del `initializeApp`. Como `main.dart` solo puede llamar a
`conectarEmuladoresFirebase()` después, llega tarde por construcción: la petición ya salió
a producción y el instance de Auth ya está usado, así que el `connectAuthEmulator`
posterior no tiene efecto.

No es un bug de la app. En producción no hay emulador y restaurar la sesión contra el
backend real es exactamente lo correcto; es un límite del orden de arranque que solo se
puede romper desde fuera de Dart.

El arreglo es `e2e/scripts/shim-emuladores.js`, que `build-web.js` inyecta en
`build/web/index.html` **después** de compilar. Crea la app de JS y conecta el emulador de
Auth antes de cargar `flutter_bootstrap.js`; flutterfire reutiliza la app que ya existe
(`firebase.app()`, `firebase_core_web.dart:307`) y le sale un Auth ya cableado, así que
`onWaitInitState()` restaura la sesión contra el emulador. Va sobre el artefacto y no sobre
`web/index.html`, que es el que se despliega y no debe llevar andamiaje de pruebas.

Tres detalles sin los que no funciona, los tres encontrados chocando con ellos:

- **`initializeAuth` con las mismas opciones que usa flutterfire**
  (`firebase_auth_web/lib/src/interop/auth.dart:22`), no un `getAuth` a secas. El SDK
  devuelve el instance ya creado solo si las dependencias coinciden; si difieren lanza
  `auth/already-initialized`. El primer intento usó `getAuth` y el resultado fue que
  `Firebase.initializeApp` moría y la app caía a la pantalla de error de arranque.
- **`window.flutterfire_web_sdk_version`** fuerza a flutterfire a importar la misma URL de
  gstatic que importa el shim. Los módulos ES se deduplican por URL, y esa igualdad es lo
  que garantiza que las dos mitades salgan del mismo registro. Es la letra pequeña del
  aviso de `tests/helpers.js`: importar gstatic crea otro registro solo si la URL difiere.
  `verificarVersionSdk()` compara contra la versión del plugin y **aborta el build** si
  divergen.
- **`sessionStorage['[DEFAULT]-firebaseEmulatorOrigin']`**, que convierte el
  `useAuthEmulator` de `main.dart` en un no-op en vez de un segundo `connectAuthEmulator`
  sobre un Auth ya inicializado.

Cubierto por `e2e/tests/sesion-persistida.spec.js`, que además afirma que **no sale ni una
petición** a `identitytoolkit`, `securetoken`, `firestore` ni `firebasestorage` de
producción en toda la corrida.

#### El falso verde que produjo este arreglo, y cómo se cazó

El primer intento puso el test en verde con la app **rota**: el SDK de JS quedaba perfecto
—`emulatorConfig` puesto, sesión restaurada— mientras `Firebase.initializeApp` moría con
`auth/already-initialized` y Flutter mostraba la pantalla de error de arranque. Todas las
afirmaciones miraban el SDK, que es la capa equivocada para detectar eso. Es la misma
enfermedad que `CLAUDE.md` ya documenta dos veces: un test que ejercita una puerta distinta
de la que dice probar.

Se destapó porque dos specs que sí pasaban antes se pusieron rojas —los deep links
aterrizaban en `/`— y la línea de tiempo de la consola lo dijo en una línea. El spec lleva
ahora dos afirmaciones que lo habrían cazado solo: que no aparece `ERROR al inicializar
Firebase` en consola, y que Flutter llegó a montar su árbol.

#### El segundo agujero: `esperarAppLista` prometía más de lo que comprobaba

`helpers.js` esperaba a `auth.emulatorConfig`, y eso implicaba —sin decirlo— que Firestore
y Storage también estaban cableados, porque `main.dart` los conecta en las tres líneas
siguientes. El shim rompe esa implicación: Auth queda cableado desde el arranque.

Medido, no supuesto: a los ~3,1 s ya existe `<flutter-view>` y `auth.emulatorConfig` es
`true`, pero `window.firebase_firestore` no existe hasta ~1 s más tarde, y en esa ventana
`getFirestore()` devuelve una instancia apuntando a **producción**. `roles.spec.js`, que lee
Firestore nada más entrar, falló en 2 de 3 corridas por eso; sin el shim daba 3/3.

`esperarAppLista` espera ahora a las tres piezas de verdad: `<flutter-view>` montado, Auth
en su emulador y Firestore en el suyo. Con eso `roles.spec.js` da 3/3 y la suite entera tres
corridas seguidas en verde.

### 3. Dos specs ajenas se apoyaban en un `sleep` fijo

`propietario.spec.js:35` y `mecanico.spec.js:29` afirmaban la URL con el timeout por
defecto de 5 s justo después de un `beforeEach` que espera 7 s a ojo. Bajo la carga de
arrancar la app unas cuantas veces más, esa espera adivinada se queda corta y el router
sigue en `/?redirect=/profile_setup`. Ahora esperan a la condición.

**Atribución, medida y no supuesta:** con el arreglo de la siembra pero **sin** el spec
nuevo, la suite da 27/27 exit 0; con el spec nuevo repartido en más arranques de la app,
caían esas dos. Fusionar el `goto` y el `reload` en un solo test —un arranque menos, ya
que cada uno levanta CanvasKit y la persistencia offline de Firestore— dejó las tres
corridas siguientes en verde. El emulador Java degradándose bajo carga en Windows ya
estaba documentado en `CLAUDE.md`.

## Lo que queda fuera

- El target `landing` no tiene rewrite SPA (solo el redirect `/` → `/es`). Es un
  export estático de Next con `cleanUrls`, así que no le hace falta el mismo
  tratamiento, pero **no se ha probado** su comportamiento ante una ruta inexistente.
- El emulador de Hosting no está declarado en el bloque `emulators` de
  `firebase.json`; el README se apoya en el puerto por defecto (5000). No se tocó la
  config, que es canónica y compartida.
- ~~El 404 con sesión no tiene cobertura E2E~~. Ya la tiene: al cerrarse el defecto 2,
  `deep-links.spec.js` ejerce las dos mitades del mismo deep link —sin sesión lleva a
  `/login`, con sesión muestra el 404 real, con su copy en español, la ruta que falló y el
  botón de salida—. Sigue cubierto además por widget test contra el router (5 casos).
- No se probó el reintento de arranque de extremo a extremo: forzar un fallo de Firebase
  Core en el navegador exigiría un bundle con opciones inválidas, que es una suite aparte.
  Está cubierto por widget test, incluido el segundo toque y el reintento fallido.
