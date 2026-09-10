# AGENTS.md — AutoDoc

Contexto permanente para cualquier agente Codex que trabaje en este repo. Codex carga este
archivo automaticamente en cada sesion: lo que este aqui NO hay que repetirlo en el prompt.

## Que es

App Flutter + Firebase (Auth/Firestore/Storage/Functions) para conectar propietarios de
vehiculos con talleres. ~213 archivos `.dart` bajo `lib/` (features 115, core 92).
Landing separada en `landing-web/` (Next.js).

## Arquitectura y estilo

- Clean Architecture + **Provider** (no Bloc, no Riverpod) + GoRouter. No introducir
  microservicios ni reescrituras: los cambios son quirurgicos y localizados.
- Detalle de capas, reglas de Firestore y estilo: `CONVENTIONS.md`.
- **Todo copy visible se localiza** en `lib/l10n/app_es.arb` y `app_en.arb`. Nunca hardcodear
  texto de UI.
- La barrera de autorizacion son **las reglas de Firestore y las Functions**. Los guards de UI
  solo complementan; nunca son la unica defensa.

## Reglas duras

- **Nunca** tocar ni volcar el contenido de: `.env`, `.env.example`, `lib/config/secrets.dart`,
  `functions/serviceAccountKey*.json`, `android/key.properties`, `*.keystore`. El repo es
  **publico** (github.com/jacoboale27/autodoc). Un hook local bloquea editarlos.
- **Nunca** desplegar a produccion (`firebase deploy` contra el proyecto prod) ni usar cuentas
  reales para QA. Pruebas siempre contra **emuladores** con fixtures efimeros.
- La app apunta a produccion por defecto: cuidado al ejecutar nada que escriba datos.
- **No cambies los puertos de emulador** de `firebase.json` ni de `test_rules/helpers.js` para
  esquivar una colision local. Son canonicos y compartidos: si el puerto esta ocupado, mata el
  proceso que lo tiene. Ya paso una vez y hubo que revertirlo.

## Como se prueba

- Unitarias/widget: `flutter test`
- Reglas: suite en `test_rules/` (Jest + `@firebase/rules-unit-testing`), **24 suites**.
  Corre siempre por `npm test`, que envuelve todo en `firebase emulators:exec`; invocar
  `npx jest` a pelo da ECONNREFUSED porque no hay emulador levantado.
- Functions: Mocha
- E2E: Playwright, en `e2e/`. Desde QA-01 corre **contra emuladores**, nunca contra produccion.
  `cd e2e && npm run build:web` (compila el bundle; tarda minutos) y luego `npm test`, que
  levanta emuladores y siembra fixtures por rol solo. Cuatro cosas que cuestan una tarde:
  - **El bundle se compila con `--profile`, no con el release por defecto.** En release,
    `kReleaseMode` desactiva el cableado a emuladores y Auth sale al endpoint REAL con las
    claves falsas, muriendo en `auth/api-key-not-valid`.
  - **`getByLabel` NO puede funcionar**: la app no emite ni un `aria-label`. Flutter web expone
    la semantica como `<flt-semantics role="button">` con el rotulo como texto — usa
    `getByRole`. Y hace falta un `page.mouse.click(10,10)` para que Flutter construya ese arbol.
  - **No importes el SDK de gstatic dentro de `page.evaluate`**: crea su propio registro de apps
    y no hereda el `useAuthEmulator`, o sea que hablaria con PRODUCCION desde dentro de una
    suite que se cree aislada. Usa los globales `window.firebase_core` / `firebase_auth` /
    `firebase_firestore`.
  - **Usa `esperarAppLista()` de `tests/helpers.js`; no inventes tu propia espera.** Espera a
    tres cosas y las tres hacen falta: `<flutter-view>` montado, Auth en su emulador y
    **Firestore en el suyo**. Desde el shim de emuladores, Auth queda cableado antes de que
    arranque Flutter, asi que `auth.emulatorConfig` por si solo ya no implica que Firestore
    lo este: queda ~1 s en el que `getFirestore()` apunta a produccion.
- E2E de la landing (UX-01): suite y config aparte —`cd e2e && npm run build:landing` y
  `npm run test:landing`—, sin bundle de Flutter ni emulador de Auth. Los formularios van al
  emulador de Functions y se comprueba en Firestore que lo enviado quedo escrito.
- Emuladores en 8080 (Firestore) / 9199 (Storage) / 9099 (Auth) / 5001 (Functions) / 4400 (hub).
  **No des por listos los emuladores porque responda el hub**: abre antes que Firestore.

## No confiar en el verde: los dobles de prueba no aplican reglas

Hay tests de autorizacion escritos contra `FakeFirebaseFirestore` y
`fake_firebase_security_rules`. **Esos motores falsos no aplican las reglas reales.** En
concreto el motor falso solo conoce los metodos `read, write, update, delete, list`: **no
existe `create` ni `get`**, `write` ya incluye `update` y `delete`, y `isAllowed` hace OR de
todos los `allow` que casen. Un verde ahi **no prueba autorizacion**; eso solo lo prueba
`test_rules/` contra los emuladores.

Ese patron ya produjo dos falsos verdes reales en este repo, y los dos son la misma
enfermedad — un test que ejercita una puerta distinta de la que dice probar:

1. **VER-01 (cerrada):** el test del PDF del NIT inyectaba un `XFile` que el picker real nunca
   podia producir, sobre una pantalla que usaba `ImagePicker` y por tanto no admitia PDF jamas.
   Verde sobre un flujo inalcanzable. Hoy la pantalla usa `FilePicker` y el test sustituye
   `FilePickerPlatform.instance`, o sea recorre la ruta de seleccion de verdad.
2. **ROLE-01 (cerrada):** el test de variantes de rol apuntaba a
   `talleres/{id}/catalogo_servicios`, cuya regla es `actuaPorTaller()` — **propiedad pura, sin
   mirar el rol**. Habria pasado con cualquier cadena de rol. Se repunto a la lectura de
   `vehiculos` vinculados, que si pasa por `isMecanico()`.

**Antes de dar por bueno un test de autorizacion, abre la regla que dice cubrir y comprueba que
el predicado que te importa es el que decide.**

## Trabajo en curso

Plan maestro: `docs/superpowers/plans/2026-09-06-remediation-master-plan-crea-j-10-10.md`
(baseline 64/100, objetivo 10/10 rubrica CREA J 2026). Orden de ejecucion en su §12,
Definition of Done al final, evidencia base en `docs/AUDITORIA_CREA_J_2026_CODEX.md` —
**no repetir la auditoria antes de implementar**.

**Estado a 2026-09-09. Cerradas y verificadas 10 tareas:** SEC-01, SEC-02, SEC-03, DATA-01,
VER-01, ROLE-01, QA-02, QA-01, UX-01 y UX-02.

**Siguiente por orden §12: FUNC-01.** Luego FUNC-02, UX-03/04, SEC-04, OPS-01, H-01,
INNO-01, FINAL-01.

QA-01 ya esta fusionada en `integracion/ola-1` (`c17fead`, sin conflictos; arbol combinado
verificado: reglas 395/395 en 23 suites). Destapo cinco huecos de autorizacion reales, todos de
la misma forma: una regla que autoriza mirando `resource.data` (el documento VIEJO) y luego no
acota lo que el write deja escrito. Los peores: el propietario podia REGALAR su vehiculo
reescribiendo `id_propietario`, y podia vaciar `talleres_conocidos` para devolver el coche al
estado walk-in, que lo abre a CUALQUIER mecanico. Ademas saco la suite E2E de produccion.
Queda abierto: los dos flujos de registro por UI estan en `fixme`, y no hay E2E de Storage ni
de callables. Evidencia en `docs/evidencia/QA-01-matriz.md`.

UX-01 ya esta fusionada en `integracion/ola-1` (`ed2e8e1`).
Evidencia en `docs/evidencia/UX-01-contacto-y-ctas.md`. Lo que hay que saber:

- **La landing tenia DOS formularios que fingian enviar, no uno.** El de contacto era
  `<form action="#">`. El de afiliacion de talleres —que no estaba en el enunciado del plan y
  era el peor— hacia un POST **sin autenticar a la REST API de Firestore de PRODUCCION** contra
  `/talleres`; como esa coleccion tiene `allow create: if isAdmin()`, se denegaba SIEMPRE y el
  taller veia un error generico, con un estado de exito implementado e inalcanzable.
- **El contrato ahora es una Cloud Function**, `recibirSolicitudLanding`: valida, honeypot,
  cupo por IP con contador transaccional, y escribe con Admin SDK en `solicitudes_landing`,
  cerrada a los clientes por los dos lados. La landing es un export estatico y no tiene
  servidor propio, de ahi el endpoint.
- **Los gates encontraron cosas serias y todas estan cerradas:** `X-Forwarded-For` se leia por
  el primer elemento (el que escribe quien llama), asi que el limitador era decoracion; no
  habia `try/catch` (un fallo de Firestore mata la instancia y escribe su error sobre la
  respuesta de OTRA peticion); y la sal del hash de IP era una cadena versionada.
- **Sin dos pasos de runbook el endpoint NO debe desplegarse:** definir
  `SOLICITUDES_LANDING_SALT` (sin ella la funcion se niega a arrancar, a proposito) y crear la
  politica TTL de `solicitudes_landing_control`, que no se configura desde
  `firestore.indexes.json`.
- **Suite nueva:** `e2e/tests-landing/` con su propia config (`npm run build:landing` y
  `npm run test:landing`). No necesita el bundle de Flutter ni el emulador de Auth.

**Playwright esperaba a la pieza equivocada, y esto afecta a las dos suites.** La config espera
al puerto del HUB (4400), que abre antes que Firestore y mucho antes de que Functions cargue
los triggers: los dos primeros tests fallaban en 53 ms con ECONNREFUSED contra 8080 y el
tercero pasaba tras 8 s — que parece el emulador muriendose a media suite (la rareza de
Windows) y es justo lo contrario. Ambas suites esperan ahora a Firestore de verdad.

**El navegador leyendo Firestore por REST desestabiliza el emulador**: Chromium aborta esas
conexiones al navegar y netty acumula "Connection reset". En la suite de la landing esa lectura
se intercepta.

### Estado de ramas — todo vive en `integracion/ola-1`

`main` sigue en `1265d23`: **ninguna tarea del plan esta fusionada a `main`.** Las 10 tareas
cerradas estan todas en **`integracion/ola-1` (`564fdf0`)**. Las tres de ola 2 (`fix/qa02`,
`fix/ver01`, `fix/role`) se fusionaron el 2026-09-07, QA-01 el 2026-09-08, y UX-01 y UX-02 el
2026-09-09, **ninguna con un solo conflicto**. Encima va `fix/landing-crash`, que **no es una
tarea del plan** pero si trabajo real sobre la landing: normaliza las calificaciones que
llegan por la REST de Firestore (de ahi salia el crash) y retira Vercel Analytics.

**Ya no queda ninguna rama `fix/*` pendiente de fusionar.** Corta de `integracion/ola-1`.

**Arbol combinado verificado entero el 2026-09-09** en
`C:/Users/User/Documents/creaj/wt-integra`:

| Suite | Resultado |
|---|---|
| `flutter analyze` | limpio |
| `flutter test` | **1150 / 1150**, exit 0 |
| `functions` (Mocha) | **173 passing** |
| `test_rules` (Jest + emuladores) | **415 / 415**, 24 suites, exit 0 |
| E2E de la app (Playwright) | **32 pasan, 2 `fixme`**, exit 0 |
| E2E de la landing | **20 / 20**, exit 0 |
| Puertos al salir | 0 en `LISTENING` |

**Siguiente tarea: FUNC-01** (edicion completa de resenas con fotos). Toca Storage y
probablemente `firestore.rules`: el revisor de reglas es gate obligatorio antes de cerrarla.

Dos trampas de entorno, ambas pagadas ya:

- **Un worktree recien creado no tiene dependencias, y el error no lo dice.** El build de la
  landing muere con `Cannot find module 'next-intl/plugin'`, que suena a bug del codigo y solo
  significa que falta `pnpm install` en `landing-web/`. Siembra por worktree:
  `flutter pub get`, `functions/npm ci`, `test_rules/npm ci`, `e2e/npm ci`,
  `landing-web/pnpm install`.
- **No encadenes corridas de Playwright sin esperar a que se liberen los puertos.** Falla en
  `global-setup` con "El emulador de Auth no respondio en 90 s", que parece un emulador roto y
  es la corrida anterior soltando 8080/9099/9199/4400/5555.

Lo que UX-02 dejo dicho, y que un worker en frio necesita saber antes de tocar `e2e/`:

- **El rewrite SPA ya existia** en `firebase.json` (target `app`). El hueco era de evidencia:
  ningun spec de la suite de la app navegaba a otra cosa que `/`. El README si desinformaba
  (`python -m http.server`, que no reescribe rutas); ahora apunta al emulador de Hosting.
- **RESUELTO — el cableado a emuladores no se puede hacer desde Dart.**
  `Firebase.initializeApp()` en web espera a que `firebase_auth_web` reciba el primer
  `onAuthStateChanged`, y con sesion persistida eso obliga a refrescar el token guardado:
  una peticion contra PRODUCCION que sale **dentro** del `initializeApp` y deja el Auth ya
  usado, asi que el `conectarEmuladoresFirebase()` de `main.dart` llega tarde siempre.
  Lo arregla `e2e/scripts/shim-emuladores.js`, que `build-web.js` inyecta en
  `build/web/index.html` tras compilar — **nunca en `web/index.html`, que es lo que se
  despliega**. Si lo tocas: tiene que usar `initializeAuth` con las mismas opciones que
  flutterfire, no `getAuth`, o el arranque muere con `auth/already-initialized`.
- **`esperarAppLista` espera a tres cosas, y las tres hacen falta:** `<flutter-view>`
  montado, Auth en su emulador y **Firestore en el suyo**. Con el shim, Auth queda cableado
  desde el arranque y queda ~1 s en el que `getFirestore()` apunta a produccion; sin la
  tercera condicion, `roles.spec.js` falla en 2 de cada 3 corridas.
- **Un test de E2E sobre Firebase tiene que afirmar tambien que la app de Flutter arranco.**
  Afirmar solo sobre el SDK de JS da verdes con la app en la pantalla de error de arranque:
  ya paso una vez. Comprueba que no hay `ERROR al inicializar Firebase` en consola y que hay
  arbol montado.
- **La siembra esperaba solo a Firestore**, pero tambien crea usuarios: ECONNREFUSED contra
  Auth. Arreglado en `global-setup.js`, que ahora espera a los dos puertos.
- **Cada arranque de la app en un test degrada el emulador Java** (CanvasKit + persistencia
  offline). Un test de mas tumbaba specs ajenas por timeout: agrupa `goto` y `reload` en el
  mismo test, y no afirmes URLs con el timeout por defecto tras un `sleep` fijo.

`fix/ux1` (sin el cero) es de un intento anterior y **no tiene ni un commit propio**: es
ancestro de `integracion/ola-1`. Ignorala; la buena es `fix/ux01`.

Las ramas `fix/*` ya integradas: **no trabajes sobre ellas**, parte de `integracion/ola-1`.

Antes de empezar una tarea, mira que ramas `fix/*` existen ya para no duplicar.

### Rarezas

- **Resuelta — el fallo de la primera corrida de Mocha tras `npm ci`.** No era intermitente: el
  hook `before()` de `functions/test/empleados.test.js` termina con un `require` *sincrono* de
  `index.js`, que arrastra firebase-admin y firebase-functions. En frio ese require tarda ~4s
  leyendo de disco y bloquea el event loop, asi que el timeout por defecto de Mocha (2000ms)
  vencia y la suite daba 147/1. En caliente la suite entera corre en 294ms, de ahi la apariencia
  de azar. Arreglado con `--timeout 20000` en el script `test`.
- **Acotada (UX-01):** parte de lo que parecia "el emulador se muere" era otra cosa —
  Playwright esperaba al puerto del hub, que abre antes que Firestore, asi que los primeros
  tests corrian contra un puerto todavia cerrado. Y el navegador leyendo Firestore por REST
  provoca "Connection reset" en netty al abortar Chromium las conexiones. Las dos suites
  esperan ahora a Firestore de verdad.
- **Abierta — un rojo de `flutter test` que no se ha podido identificar.** El 2026-09-08
  aparecio dos veces `1139 +1 -1` (en `fix/ux01` y en el arbol fusionado) contra cuatro corridas
  de 1140/1140, incluida una repitiendo `analyze` justo antes para forzar la hipotesis obvia. Las
  dos rojas tenian en comun que la salida pasaba por `tail`, que **se comio el nombre del test y
  ademas falseo el codigo de salida a 0** (el del pipe es el de `tail`). Si vuelve a salir:
  **captura la salida entera a un archivo, nunca por `tail`**, y apunta aqui el nombre. Puede ser
  una dependencia de orden o de temporizacion; hoy no hay evidencia para afirmar ni descartar.
- **Abierta:** el emulador Java de Firestore se muere a media suite en Windows
  (`Connection reset`) aproximadamente 1 de cada 6 corridas. Si te pasa, reintenta; no es tuyo.

## Formato de respuesta

Vas a ser invocado casi siempre como worker de una tarea acotada por otro agente. Responde
**solo lo que te pidieron**, en el formato que te pidan, sin preambulo ni resumen de lo que
hiciste. Si no puedes completar algo, di `NO_PUDE:` y la razon en una linea — no inventes.
Cita siempre `ruta/archivo.dart:linea` para que quien te lea pueda verificarte.
