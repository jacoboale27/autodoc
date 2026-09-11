# AutoDoc — Guía para Claude Code

## ⚠️ Trabajo actual — plan de remediación CREA J 2026

El trabajo se dirige desde `docs/superpowers/plans/2026-09-06-remediation-master-plan-crea-j-10-10.md`
(baseline 64/100 → objetivo 10/10). Su **§12 fija el orden**, y la Definition of Done del final
manda sobre cualquier atajo. Para orquestarlo, usa la skill `ejecutar-plan-remediacion`.

Evidencia base: `docs/AUDITORIA_CREA_J_2026_CODEX.md` y `docs/AUDITORIA_CREA_J_2026_CLAUDE.md`
(dos auditorías independientes, ambas 64/100 por rutas distintas). **No repitas la auditoría
antes de implementar**; el plan lo prohíbe.

**Estado a 2026-09-11 — 12 tareas cerradas y verificadas:** SEC-01, SEC-02, SEC-03, DATA-01,
VER-01, ROLE-01, QA-02, QA-01, UX-01, UX-02, FUNC-01 y **FUNC-02**.
**Siguiente por orden §12: UX-03 / UX-04.** La tanda de drenaje de gaps que iba antes ya
está cerrada (rama `fix/gaps-02`, evidencia en `docs/evidencia/GAPS-02-drenaje.md`) — ver
más abajo.

QA-01 ya esta fusionada en `integracion/ola-1` (`c17fead`), sin conflictos. Evidencia completa
en `docs/evidencia/QA-01-matriz.md`. Lo que hay que saber sin leerla:

- **Construir la matriz destapo cinco huecos de autorizacion reales**, todos de la misma forma:
  una regla que autoriza mirando `resource.data` —el documento VIEJO— y luego no mira lo que el
  write deja escrito. Los peores: el propietario podia **regalar su vehiculo** reescribiendo
  `id_propietario`, y podia vaciar `talleres_conocidos` para devolver el coche al estado walk-in,
  que lo abre a **cualquier** mecanico (el agujero de la ronda 6, reabierto desde el otro lado).
- **La suite E2E corria contra PRODUCCION** y `registro.spec.js` creaba usuarios reales en cada
  corrida. Ya no: la app tiene cableado a emuladores (`lib/core/config/firebase_emulators.dart`)
  tras un doble candado (`--dart-define` **y** `!kReleaseMode`).
- **Queda abierto:** los dos flujos de registro por UI estan en `fixme`; sin cobertura E2E de
  Storage ni callables.

UX-01 ya esta fusionada en `integracion/ola-1` (`ed2e8e1`). Evidencia en
`docs/evidencia/UX-01-contacto-y-ctas.md`. Lo esencial:

- **Eran DOS los formularios que fingian enviar, no uno.** El de contacto era `<form action="#">`.
  El de afiliacion de talleres —que no estaba en el enunciado del plan y era el peor— POSTeaba
  **sin autenticar a la REST API de Firestore de PRODUCCION** contra `/talleres`, cuya regla es
  `allow create: if isAdmin()`: se denegaba siempre, con un estado de exito implementado que
  nadie podia alcanzar. Ademas los legales del pie apuntaban fuera del sitio, las anclas del menu
  morian fuera de la home, y la pagina de contacto **no la enlazaba nadie**.
- **El contrato ahora es la Cloud Function `recibirSolicitudLanding`** (la landing es un export
  estatico y no tiene servidor): valida, honeypot, cupo por IP con contador transaccional, y
  escribe con Admin SDK en `solicitudes_landing`, cerrada a los clientes por los dos lados.
- **Sin dos pasos de runbook el endpoint NO debe desplegarse:** definir `SOLICITUDES_LANDING_SALT`
  (sin ella la funcion se niega a arrancar, a proposito: con la sal versionada el hash de IP era
  reversible) y crear la politica TTL de `solicitudes_landing_control`, que no se configura desde
  `firestore.indexes.json`.
- **Suite nueva con config propia:** `cd e2e && npm run build:landing && npm run test:landing`
  (20 casos tras `fix/landing-crash`). No necesita el bundle de Flutter ni el emulador de Auth.

**El bundle E2E de la app se compila con `--profile`, no con el release por defecto.**
`flutter build web` compila en release, donde `kReleaseMode` desactiva el cableado a emuladores y
Auth sale al endpoint REAL con las claves falsas, muriendo en `auth/api-key-not-valid`.

**Playwright esperaba a la pieza equivocada, en las dos suites.** La config espera al puerto del
**hub** (4400), que abre antes que Firestore y mucho antes de que Functions cargue los triggers:
los dos primeros tests fallaban en 53 ms con ECONNREFUSED contra 8080 y el tercero pasaba tras
8 s — que parece el emulador muriendose a media suite y es justo lo contrario. Ambas esperan ya a
Firestore de verdad. Y **el navegador leyendo Firestore por REST desestabiliza el emulador**
(Chromium aborta las conexiones al navegar, netty acumula "Connection reset"): en la suite de la
landing esa lectura se intercepta.

### Ramas — nada está fusionado a `main`

`main` sigue en `1265d23`. **Las 12 tareas cerradas viven en `integracion/ola-1`**: ola 1
(SEC-01/02/03, DATA-01), las tres de ola 2 (QA-02, VER-01, ROLE-01),
QA-01, UX-01 y **UX-02** (fusionada el 2026-09-09, `d5c707a`, sin conflictos). Encima va
`fix/landing-crash` (`564fdf0`), que **no es una tarea del plan** pero sí trabajo real sobre
la landing ya integrada: normaliza las calificaciones que llegan por la REST de Firestore
—de ahí salía el crash— y retira Vercel Analytics, que en Firebase Hosting no tiene backend
al que hablar.

**Pendiente de fusionar: `fix/gaps-02`** (la tanda de drenaje, cerrada el 2026-09-11).
Ninguna otra.

#### Árbol combinado, verificado entero el 2026-09-09

| Gate | Resultado |
|---|---|
| `flutter analyze` | `No issues found!` |
| `flutter test` | **1167 / 1167**, exit 0 |
| `functions` (Mocha) | **170 passing** |
| `test_rules` (Jest + emuladores) | **426 / 426**, 24 suites |
| E2E de la app (Playwright) | **32 pasan, 2 `fixme`**, exit 0 |
| E2E de la landing | **20 / 20**, exit 0 |
| Puertos al salir | 0 en `LISTENING` |

UX-02 cerró dos callejones sin salida en la app y, en un segundo commit, el defecto del
harness que ella misma había destapado. Evidencia en
`docs/evidencia/UX-02-errores-y-deep-links.md`. Lo que hay que saber sin leerla:

- **El rewrite SPA ya existia** en `firebase.json` para el target `app`. El hueco era de
  evidencia: **ningun spec de la suite de la app navegaba a otra cosa que `/`**. El README si
  desinformaba, documentando `python -m http.server` (que no reescribe rutas) y presentando su
  404 como una limitacion a sortear. Ahora apunta al emulador de Hosting.
- **RESUELTO — el cableado a emuladores no se puede hacer desde Dart.**
  `Firebase.initializeApp()` en web no retorna hasta que `firebase_auth_web` termina su
  `ensurePluginInitialized`, que espera al primer `onAuthStateChanged`. Con sesion persistida
  ese evento exige refrescar el token guardado: una peticion de red que sale **dentro** del
  `initializeApp`, contra PRODUCCION, y que deja el Auth ya usado — asi que el
  `conectarEmuladoresFirebase()` de `main.dart` llega tarde por construccion y
  `emulatorConfig` se queda en null para siempre. No es un bug de la app: en produccion
  restaurar la sesion contra el backend real es lo correcto.
  El arreglo es `e2e/scripts/shim-emuladores.js`, que `build-web.js` inyecta en
  `build/web/index.html` **despues** de compilar (nunca en `web/index.html`, que es lo que se
  despliega): crea la app de JS y conecta el emulador antes de cargar `flutter_bootstrap.js`,
  y flutterfire reutiliza esa app. Tiene que usar **`initializeAuth` con las mismas opciones
  que flutterfire**, no `getAuth`, o el arranque muere con `auth/already-initialized`.
- **`esperarAppLista` ya no implica lo que implicaba.** Esperar a `auth.emulatorConfig`
  significaba que Firestore y Storage tambien estaban cableados, porque `main.dart` los conecta
  en las tres lineas siguientes. Con el shim, Auth queda cableado desde el arranque y hay ~1 s
  en el que `getFirestore()` apunta a **produccion**: `roles.spec.js` fallaba en 2 de 3
  corridas por eso. El helper espera ahora a las tres piezas: `<flutter-view>` montado, Auth en
  su emulador y Firestore en el suyo.
- **Ese arreglo produjo un falso verde de manual, y merece recordarse.** El primer intento
  dejaba el SDK de JS perfecto mientras Flutter caia a la pantalla de error de arranque: todas
  las afirmaciones miraban el SDK, la capa equivocada. **Un test de E2E sobre Firebase tiene
  que afirmar tambien que la app de Flutter arranco** — que no hay `ERROR al inicializar
  Firebase` en consola y que hay arbol montado.
- **La siembra corria antes de que Auth estuviera arriba** (`global-setup.js` esperaba solo a
  Firestore, pero sembrar tambien crea usuarios). Arreglado; reproducible al revertirlo.
- **Cada arranque de la app en un test cuesta caro** (CanvasKit + persistencia offline de
  Firestore) y degrada el emulador Java: un test de mas tumbaba specs ajenas por timeout.
  Agrupa `goto` y `reload` en el mismo test en vez de partirlos.

Ojo con el nombre: `fix/ux1` (sin el cero) es de un intento anterior y **no tiene ni un commit
propio** — es ancestro de `integracion/ola-1`. La buena es `fix/ux01`.

Las ramas `fix/*` ya integradas: **no trabajes sobre ellas**, parte de `integracion/ola-1`.

Antes de empezar una tarea, mira qué ramas `fix/*` existen ya para no duplicar.

### La tanda de drenaje `fix/gaps-02` está cerrada (2026-09-11)

Cierra los gaps **9.1, 9.2, 9.3 y 9.4** del §9 de `GAPS-FUNC-02-cierre-de-residuales.md`.
Evidencia en `docs/evidencia/GAPS-02-drenaje.md`. Lo que hay que saber sin leerla:

- **La trampa que el plan mandaba comprobar antes de tocar la bandeja de chat NO existía.**
  Ninguna conversación puede nacer sin `ultimo_mensaje_ts` (campo obligatorio del modelo,
  único creador en `lib/`, las Functions solo leen esa colección, y el modelo nació con el
  campo). Ni backfill ni paso de runbook. Comprobarlo ahorró una migración inventada — y es
  el contrapunto del lote C, donde la misma trampa sí era real.
- **Denormalizar `abierto` puso rojos diez tests de golpe**, todos por siembras que no
  escribían el campo: una igualdad sobre un campo ausente no devuelve NADA. Es exactamente
  lo que le pasaría a producción sin correr el backfill, ensayado gratis.
- **Los dos revisores encontraron cuatro cosas mal, dos graves.** (1) `abierto` se podía
  **borrar** con `FieldValue.delete()` y la regla lo dejaba pasar —`.get(campo, derivado)`
  degenera en una tautología sobre un campo ausente—, así que un taller escondía un ticket
  vivo de su propio tablero con el vínculo al coche intacto. (2) El backfill estampaba el
  centinela `migracion_ronda6` en TODOS los tickets, y ese centinela es **pegajoso**: cada
  ticket vivo el día de la migración habría dejado de notificar sus transiciones y de
  revocar el vínculo al entregarse, para siempre. Los dos cerrados, con sus tests.
- **`ReservaProvider.inicializarReservasUsuario` no tiene ningún llamador en `lib/`**: lo
  sostienen sus tests, como los `iniciar*` de FUNC-02. Se acotó igual; anotado como gap.
- **El runbook creció:** el backfill tiene ahora una pasada 4 (`abierto`) y **sin ella el
  tablero de todos los talleres sale vacío**; el despliegue de índices **retira seis** de
  producción; y las reglas van DESPUÉS del backfill y JUNTO a la app, nunca antes.

Cifras de la rama: `flutter analyze` limpio, Functions **218**, reglas **435 / 435** en 25
suites.

### Lo siguiente: UX-03 / UX-04

**"Accesibilidad y errores de datos"** (§7 del plan, P2). Áreas que señala:
`landing-web/src`, `service_history_screen.dart`, componentes de error/empty state, ARB y
pruebas. Dos frentes distintos: la landing (Next.js, `prefers-reduced-motion`, menú móvil
accesible, `Link > button` anidado) y la app (`Error: ${snapshot.error}` crudo → estado
localizado con reintento). Se pueden inventariar en paralelo.

Y **antes de UX-03/UX-04 hay que decidir qué se hace con los gaps nuevos** del §7 de
`GAPS-02-drenaje.md` — la regla del 2026-09-10 es permanente: un gap documentado no está
cerrado. El que más vale: **el batch de `marcarComoLeidos` revienta** con un hilo de más de
499 mensajes del otro participante (límite de 500 escrituras por `WriteBatch`), y a partir
de ahí el contador de no leídos no se resetea nunca más.

Corta la rama de la punta de `integracion/ola-1`, nunca de una `fix/*`.

Tres cosas que ahorran una hora:

- **Un worktree nuevo no tiene dependencias instaladas, y el fallo no lo dice.** El build de
  la landing murió con `Cannot find module 'next-intl/plugin'`, que suena a bug del código y
  solo significaba que faltaba `pnpm install` en `landing-web/`. Por worktree hay que sembrar
  `flutter pub get`, `functions/npm ci`, `test_rules/npm ci`, `e2e/npm ci` y
  `landing-web/pnpm install`.
- **No encadenes corridas de Playwright sin esperar a que se liberen los puertos.** Dos de
  tres fallaron en `global-setup` con «El emulador de Auth no respondio en 90 s», que parece
  un emulador roto y es solo la corrida anterior soltando los puertos. Comprueba 8080, 9099,
  9199, 4400, 5555 antes de relanzar.
- **El script `test` de `test_rules/` no acepta argumentos.** Es un `firebase emulators:exec`,
  así que `npm test -- storage.test.js` muere con «Too many arguments». Para correr una sola
  suite: `npx firebase emulators:exec --only firestore,storage --project autodoc-rules-test
  "npx jest --runInBand storage.test.js"`.
- **Cifras al día tras cerrar los residuales:** `flutter test` **1180**, reglas **426**
  en 24 suites, Functions **197**, E2E de la app **32**.

### Los nueve residuales de FUNC-02 están cerrados (rama `fix/gaps-func02`)

No es una tarea del plan: es el drenaje del §7 de la evidencia de FUNC-02. Evidencia en
`docs/evidencia/GAPS-FUNC-02-cierre-de-residuales.md`. Lo que hay que saber sin leerla:

- **Dos de los nueve estaban mal descritos, y en la dirección peligrosa.** El «índice muerto
  `Servicios`» no estaba muerto: era `servicios` **con la S mayúscula**, o sea el índice VIVO
  mal escrito, y el historial de servicios del propietario moría con `failed-precondition` en
  producción por su culpa. Y la «consulta que falla en silencio» no daba un mensaje
  equivocado: dejaba a la pantalla pintando el **formulario manual**, así que el mecánico
  re-tecleaba a mano el importe que el cliente ya había aprobado y era ese el que se guardaba
  en `servicios`.
- **Hay un centinela nuevo de índices: `test/firestore_indices_test.dart`.** Los emuladores
  sirven cualquier consulta sin mirar `firestore.indexes.json`, así que una consulta sin
  índice **no la detecta ninguna suite** — solo un usuario en producción. Cruza el inventario
  con los índices en las dos direcciones y cuenta los `.orderBy(` de `lib/` y los `.where(` de
  `functions/` como disparador. Destapó **seis consultas más sin índice** (reservas ×2,
  servicios, cotizaciones, conversaciones) y **cuatro índices huérfanos**.
- **Todos los tests de `InitiateServiceScreen` corrían contra un Firestore roto.** La pantalla
  usaba `FirebaseFirestore.instance` (su propio test lo llamaba «no inyectable»); al
  inyectarlo, trece se pusieron rojos de golpe. Llevaban ejerciendo el camino de fallo sin
  saberlo, porque el `.then` sin `catchError` se lo tragaba.
- **Dos dobles de prueba no podían ver el defecto que cubrían.** Uno tenía `limit()` como
  no-op; el otro devolvía el documento **vivo** desde `get()` en vez de una copia, y un
  snapshot de Firestore es inmutable — con eso, el primer test de la carrera del historial dio
  **falso verde**. Los dos modelan ahora esas propiedades.
- **La recepción pasa de `batch` a `runTransaction`** y la autorización viaja dentro, lo que
  retira además la segunda lectura del ticket. **El vínculo caduca solo** a los 30 días sin
  actividad (`caducarVinculosDeTalleresInactivos`): caduca el ACCESO, no el ticket, y el
  reintento que ya existe lo recupera mientras el ticket siga abierto.
- **Dos pasos de runbook nuevos, y uno no es negociable:** `node backfill_entregado.js --apply`
  ANTES de desplegar la app web (el tablero pasa a ordenar por `fecha_actualizacion`, y un
  `orderBy` excluye los documentos sin el campo, igual que el `whereIn` de la ronda 6), y
  `firebase deploy --only firestore:indexes` antes que la app.
- **Quedan nueve gaps NUEVOS anotados** en el §9 de esa evidencia, casi todos destapados por
  el gate de revisión. El que más vale: **el tope del tablero acota documentos, no lecturas** —
  un `whereIn` de 5 estados con `limit(200)` aplica el límite a cada subconsulta, así que lee
  hasta 1000 para devolver 200. Sigue siendo mejor que el stream sin tope de antes, pero no
  es lo que parece.

FUNC-02 retiró los caminos muertos de reparación y, al inventariarlos, destapó que el peor
seguía **vivo en el servidor**. Evidencia en
`docs/evidencia/FUNC-02-apertura-unica-de-tickets.md`. Lo esencial:

- **Lo que sostenía vivo a `iniciarReparacion` no era la app: eran sus tests.** Los cuatro
  métodos `@Deprecated` de `ReparacionProvider` y los dos del repositorio tenían **cero**
  consumidores en `lib/`; solo la siembra de 19 tests. Esa siembra vive ahora en
  `test/support/sembrar_reparacion.dart`, donde no compila dentro de la app.
- **El callable `iniciarReparacionPorVehiculo` seguía desplegado e invocable sin tener
  llamador.** Abría el ticket directamente en `'recibido'` —saltándose la recepción física—
  y se otorgaba `vehiculos.talleres_vinculados`. Su única compuerta era «existe una
  cotización aceptada para este vehículo+taller», y **una cotización se queda en `aceptada`
  para siempre**: con una visita YA ENTREGADA bastaba para recuperar el acceso al coche que
  `revocarVinculoAlCerrarTicket` acababa de revocar. El `allow create: if false` de
  `firestore.rules` no lo alcanzaba — los callables corren con Admin SDK.
- **`firebase functions:delete iniciarReparacionPorVehiculo` es paso de runbook.** Borrar el
  export NO retira el endpoint desplegado: mientras siga vivo en el proyecto de Firebase, el
  replay sigue disponible en producción. Va en el mismo cajón que `SOLICITUDES_LANDING_SALT`.
- **Quedan tres escritores server-side sobre `/reparaciones` y ninguno más**:
  `onCotizacionAceptada` (crea, en `pendiente_recepcion`), `recibirVehiculoDelTicket`
  (transiciona) y el barrido de `onVehicleDelete` (cierra). Lo vigila un centinela que
  cuenta los accesos **por archivo** — la primera versión miraba solo el cuerpo de cada
  `exports.` y pasaba por casualidad, porque la escritura real vive en `src/vinculoTaller.js`.
- **Nueve gaps quedan abiertos y anotados** en el §7 de esa evidencia, con su razón. Los dos
  que más valen: el **dedup de tickets puede fallar por volumen** (`.limit(20)` sin filtro de
  estado ni orden en `aceptarCotizacion.js:247`) y una **consulta sin índice que falla en
  silencio** (`initiate_service_screen.dart:269`, `.then` sin `catchError`, y la pantalla
  acaba diciendo «no hay cotización aceptada» por un `failed-precondition`).

FUNC-01 cerró el defecto de las fotos y, de camino, un agujero de reglas que no estaba en el
enunciado. Evidencia en `docs/evidencia/FUNC-01-fotos-de-resenias.md`. Lo esencial:

- **El enunciado del plan describe mal el bug.** «La edición descarta fotos» no era cierto: el
  sheet escondía el selector en modo edición precisamente para que no se descartara nada. El
  defecto real era que **`updateReview` no mencionaba `fotos`**, así que tras publicar no había
  forma de tocarlas, y que **`storage.rules` no dejaba al autor borrar las suyas**
  (`allow delete: if isAdmin()`): sin ese segundo cambio la tarea no se podía cerrar, porque
  limpiar un huérfano moría en `permission-denied`.
- **`resenias` es de lectura ANÓNIMA y `fotos` aceptaba cualquier URL.** Era teórico mientras
  el cliente no escribía `fotos` en un update; FUNC-01 es justo lo que lo vuelve alcanzable. Un
  propietario con una reseña legítima podía apuntar a un servidor propio y cosechar IP y
  User-Agent de todo el que abriera la ficha del taller. Cerrado con `fotosBajoServicio`,
  hermano de `esUrlDeStoragePropia`. **En un update valida solo si `fotos` cambia**:
  `request.resource.data` es el documento *resultante*, así que validar siempre dejaría
  ineditables las reseñas con URLs heredadas, ni siquiera para corregir el texto.
- **Queda residual y anotado:** el «vehículo fantasma» (`vehiculos` admite `create` con ID
  elegido por el cliente, y `onVehicleDelete` es asíncrono), cuyo endurecimiento limpio —atar
  el nombre del objeto al uid— es una migración, no un ajuste; y que **nadie borra las fotos
  al ELIMINAR una reseña**, que es trabajo de un trigger `onDelete` con Admin SDK y encaja en
  OPS-01.

Sigue **abierto y sin dueño**: el rojo intermitente de `flutter test` (`1139 +1 -1`) que no
se ha llegado a identificar — ver «Rarezas» más abajo — y el emulador Java de Firestore
muriéndose ~1 de cada 6 corridas en Windows.

### La trampa a vigilar: los dobles de prueba no aplican las reglas

Hay tests de autorización escritos contra `FakeFirebaseFirestore` y
`fake_firebase_security_rules`, que **no aplican las reglas reales**. El motor falso solo
conoce `read, write, update, delete, list` — **no existe `create` ni `get`** —, `write` ya
incluye `update` y `delete`, y `isAllowed` hace OR de todos los `allow` que casen. Un verde ahí
no prueba autorización; eso solo lo prueba `test_rules/` contra los emuladores.

Ese patrón ya produjo **dos** falsos verdes reales, y ambos son la misma enfermedad — un test
que ejercita una puerta distinta de la que dice probar:

1. **VER-01 (cerrada):** el test del PDF del NIT inyectaba un `XFile` que el picker real nunca
   podía producir, sobre una pantalla que usaba `ImagePicker` y por tanto jamás admitía un PDF.
   Verde sobre un flujo inalcanzable en producción. Hoy la pantalla usa `FilePicker` y el test
   sustituye `FilePickerPlatform.instance`, o sea recorre la ruta de selección de verdad.
   Al escribir los negativos apareció además un agujero de MIME spoofing (`nit.jpg` declarando
   `application/pdf`) que se cerró emparejando nombre y content-type en `storage.rules`.
2. **ROLE-01 (cerrada):** el test de variantes de rol apuntaba a
   `talleres/{id}/catalogo_servicios`, cuya regla es `actuaPorTaller()` — **propiedad pura, sin
   mirar el rol**. Habría pasado con cualquier cadena. Se repuntó a la lectura de `vehiculos`
   vinculados (`firestore.rules:516`), que sí pasa por `isMecanico()`.

**Antes de dar por bueno un test de autorización, abre la regla que dice cubrir y comprueba que
el predicado que te importa es el que decide.**

### Rarezas

- **Resuelta — el fallo de la primera corrida de Mocha tras `npm ci`.** No era intermitente:
  el hook `before()` de `functions/test/empleados.test.js` termina con un `require` *síncrono*
  de `index.js`, que arrastra firebase-admin y firebase-functions. En frío ese require tarda
  ~4 s leyendo de disco y bloquea el event loop, así que el timeout por defecto de Mocha
  (2000 ms) vencía y la suite daba 147/1. En caliente la suite entera corre en 294 ms, de ahí
  la apariencia de azar. Arreglado con `--timeout 20000` en el script `test` de
  `functions/package.json`, verificado borrando `node_modules` y reinstalando (150/150 en frío).
- **Abierta — un rojo de `flutter test` que no se ha podido identificar.** El 2026-09-08
  aparecio dos veces `1139 +1 -1` (en `fix/ux01` y en el arbol fusionado) contra cuatro corridas
  de 1140/1140, incluida una repitiendo `analyze` justo antes para forzar la hipotesis obvia. Las
  dos rojas tenian en comun que la salida pasaba por `tail`, que **se comio el nombre del test y
  ademas falseo el codigo de salida a 0** (el del pipe es el de `tail`). Si vuelve a salir:
  **captura la salida entera a un archivo, nunca por `tail`**, y apunta aqui el nombre. Puede ser
  una dependencia de orden o de temporizacion; hoy no hay evidencia para afirmar ni descartar.
- **Abierta:** el emulador Java de Firestore muere a media suite en Windows
  (`Connection reset`) ~1 de cada 6 corridas.

El plan `docs/superpowers/plans/2026-09-02-hallazgos-uso-real.md` (anexo S2–S6, Bloques B–G)
sigue pendiente y se retoma cuando el plan de remediación cierre.

## Flujo de trabajo obligatorio para cada petición

1. **Contexto del proyecto**: usa **graphify** (`/graphify`, o las skills `graphify` instaladas) como fuente principal de contexto del código — grafo de conocimiento ya construido en `graphify-out/graph.json` (7802 nodos, 12106 edges). Si el grafo no responde lo suficiente, complementa buscando directamente en el código (Grep/Glob/Read).
2. **Superpowers**: usa las skills de `superpowers` (brainstorming, TDD, debugging sistemático, subagent-driven development, code review) según corresponda al tipo de tarea.
3. **find-skills**: antes de improvisar una solución, usa `find-skills` para revisar si ya existe una skill relevante instalada o disponible en las marketplaces configuradas.

Ver también `CONVENTIONS.md` para arquitectura (Clean Architecture + Provider), reglas de Firestore/roles, y estilo de código.

## Cómo se corren las suites (detalles que cuestan una hora si se ignoran)

- `test_rules/` va **siempre por `npm test`**, que envuelve todo en `firebase emulators:exec`.
  Invocar `npx jest` a pelo da ECONNREFUSED porque no hay emulador levantado.
- **No cambies los puertos de emulador** de `firebase.json` ni de `test_rules/helpers.js` para
  esquivar una colisión local: son canónicos y compartidos. Si el puerto está ocupado, mata el
  proceso que lo tiene — normalmente es una corrida tuya anterior que sigue viva.
- Un hook de pre-commit rechaza el commit si queda Dart sin formatear: `dart format` antes.
- **Dos suites de Playwright, cada una con su config.** La de la app va contra emuladores
  desde QA-01; la de la landing (`e2e/tests-landing/`, UX-01) se lanza con
  `npm run build:landing && npm run test:landing` y no necesita ni el bundle de Flutter ni el
  emulador de Auth. **Ninguna de las dos espera al puerto del hub para dar por listos los
  emuladores**: el hub abre antes que Firestore, y eso hacia fallar los primeros tests con
  ECONNREFUSED como si el emulador se hubiera muerto.
- **`e2e/` (Playwright) va contra emuladores desde QA-01.** Primero `cd e2e && npm run build:web`
  (compila el bundle en `--profile`, tarda varios minutos, incluye un `flutter clean` que no es
  opcional), luego `npm test`. La config levanta los emuladores y siembra los fixtures sola.
  Tres cosas que cuestan una tarde si se ignoran:
  - **`getByLabel` no puede funcionar**: la app no emite ni un `aria-label`. Flutter web expone la
    semántica como `<flt-semantics role="button">` con el rótulo como texto — usa `getByRole`. Y
    hace falta un clic (`page.mouse.click(10,10)`) para que Flutter construya ese árbol; sin él
    ningún selector encuentra nada.
  - **No importes el SDK de gstatic dentro de `page.evaluate`**: crea su propio registro de apps
    (`getApps()` vacío) y, peor, no hereda el `useAuthEmulator` — hablaría con producción desde
    dentro de una suite que se cree aislada. Usa los globales `window.firebase_core` /
    `firebase_auth` / `firebase_firestore`, que son la instancia real.
  - **Usa `esperarAppLista()` de `e2e/tests/helpers.js`; no improvises la espera.** Comprueba
    tres cosas, y las tres hacen falta: `<flutter-view>` montado, Auth en su emulador y
    **Firestore en el suyo**. Desde el shim de emuladores (UX-02), Auth queda cableado antes
    de que arranque Flutter, así que `auth.emulatorConfig` por sí solo dejó de implicar que
    Firestore lo esté: hay ~1 s en el que `getFirestore()` apunta a producción.

## Skills/plugins instalados (scope: user)

- `claude-code-setup@claude-plugins-official` — recomendador de automatizaciones.
- `superpowers@claude-plugins-official` — brainstorming, TDD, debugging, code review, subagentes.
- `andrej-karpathy-skills@karpathy-skills` — guías de comportamiento (pensar antes de codear, simplicidad, cambios quirúrgicos, criterios de éxito claros).
- `find-skills@easier-life-skills` — descubrimiento de skills relevantes para el repo activo.
- `graphify` (CLI vía `uv tool install graphifyy` + skill en `~/.claude/skills/graphify/`) — grafo de conocimiento del código, `/graphify` para re-indexar.

## Automatizaciones locales del proyecto (`.claude/`)

- Hooks: bloqueo de edición de `.env`/credenciales, auto-`dart format` post-edición.
- Subagentes: `firestore-rules-reviewer`, `functions-perf-reviewer`. Son **gate obligatorio**,
  no opinión opcional: pásalos después de implementar y antes de cerrar cualquier tarea que
  toque `firestore.rules` o `functions/index.js`.
- Slash commands: `/test [unit|rules|integration|all]`, `/delegate-to-codex`.
- Skills: `firebase-deploy-check`, `ejecutar-plan-remediacion`.
- `AGENTS.md` (raíz) repite el estado del plan para los workers de Codex, que arrancan en frío.
  **Si cierras una tarea del plan, actualiza los dos archivos.**
