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
| `e2e/tests/deep-links.spec.js` | 4/4 |
| Suite E2E completa de la app | **31 pasan, 2 `fixme`, exit 0**, en **tres corridas seguidas** |
| Puertos 8080/9099/9199/4400/5555 al salir | libres |

### TDD — los rojos que se vieron antes de implementar

Ambas suites se corrieron y fallaron antes de escribir una línea de implementación:

- 404: `The getter 'notFoundTitle' isn't defined for the type 'AppLocalizations'`.
- Arranque: `No named parameter with the name 'onRetry'` y las claves ARB ausentes.

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

### 2. Una sesión persistida rompe el cableado a emuladores en la siguiente carga completa

Con sesión iniciada, `page.goto('/garage')` arranca la app pero `auth.emulatorConfig`
**nunca** se pone: sondeado cada 5 s durante 60 s, siempre `false`, sin usuario y con el
router en `/login`. Sin sesión previa, la misma URL cablea emuladores en menos de 15 s.

En la consola del navegador de esa carga aparecen las dos cosas a la vez: un **400 contra
Auth de producción** —el intento de restaurar la sesión persistida con las claves falsas—
*antes* de que la app anuncie `EMULADORES: Auth :9099 ... NO se esta usando produccion`.
O sea, Auth se toca antes del redirect, que es justo la ventana contra la que avisa QA-01.

Consecuencia práctica: **no se puede ejercer por E2E ningún flujo que exija sesión y una
navegación de página completa.** Por eso el 404 autenticado se prueba por widget test y no
aquí, y el spec lo dice en su propio comentario. No se ha arreglado: cae del lado del
harness de QA-01, no de UX-02.

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
- **El 404 con sesión no tiene cobertura E2E**, por el defecto 2 de arriba. Sí la tiene
  por widget test contra el router real (5 casos).
- No se probó el reintento de arranque de extremo a extremo: forzar un fallo de Firebase
  Core en el navegador exigiría un bundle con opciones inválidas, que es una suite aparte.
  Está cubierto por widget test, incluido el segundo toque y el reintento fallido.
