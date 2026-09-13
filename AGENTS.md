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

**Estado a 2026-09-13 — 17 tareas cerradas y verificadas:** SEC-01, SEC-02, SEC-03, DATA-01,
VER-01, ROLE-01, QA-02, QA-01, UX-01, UX-02, FUNC-01, FUNC-02, UX-03 / UX-04,
**SEC-04 / OPS-01** y **H-01**.
**Siguiente por orden §12: INNO-01** —solo si el mock judge lo
exige— y FINAL-01. Las tandas de drenaje de gaps están cerradas: `fix/gaps-02`
(residuales de FUNC-02), `fix/gaps-03` (accesibilidad de la landing que dejó UX-03) y
**`fix/gaps-04`** (lo que quedaba abierto antes de H-01, cerrada el 2026-09-13).

### Incidente de despliegue del 2026-09-13 — nunca publiques `build/web` sin verificarlo

Se desplego a hosting el artefacto de E2E (`e2e/scripts/build-web.js`). Ese build es
**`--profile`**, y los candados de `lib/core/config/firebase_emulators.dart` son
`_flagEmuladores && !kReleaseMode`: en profile **los dos se abren**. La web publicada apunto
Auth/Firestore/Storage al `localhost` del visitante y mostro el cartel «Running in emulator
mode». Caida total de disponibilidad; sin fuga de datos.

**Lo que hay que retener:** ninguna suite del repo podia verlo porque todas miran el **codigo
fuente**, que estaba bien. El defecto vivia en el **artefacto**, que no se versiona. Hay ahora una
guarda `predeploy` en `firebase.json` (`scripts/verificar_bundle_web.js`) y un centinela
(`test/despliegue_web_protegido_test.dart`) que impide quitarla. Antes de un build de produccion,
`flutter clean` **no es opcional**.

**`.firebaserc` tiene `"default": "autodoc-staging"`**: todo `firebase deploy` sin `--project` va
a staging. Usa siempre el alias explicito.

### H-01 está cerrada (2026-09-13, `hardening/h-01`)

Hardening, QA destructivo, matriz de evidencia y **segunda auditoría adversarial desde cero**.
Evidencia en `docs/evidencia/H-01-hardening.md` y `docs/AUDITORIA_CREA_J_2026_v2.md`.
**Veredicto del juez independiente: 85/100, sin P0.** Lo que hay que saber sin leerlas:

- **⚠️ RUNBOOK, Pendiente 0, BLOQUEANTE antes de desplegar reglas.** Las reglas nuevas resuelven
  el estado del taller con `.get('estado','pendiente')`, así que **un taller de producción sin
  ese campo pierde de golpe las facturas y la galería**. Hay que contarlos antes de desplegar, y
  **no** hacer un backfill ciego a `'aprobado'`: eso convertiría el arreglo en su contrario.
  Ninguna suite puede avisar — todas siembran `estado`.
- **El registro por UI ya no está en `fixme`**, y su razón documentada era falsa a medias: los
  rótulos seguían vivos en el ARB; lo que cambió fue el final del recorrido. La otra mitad sí era
  cierta y tiene arreglo: **en Flutter web `fill()` no sirve y `keyboard.type` sí** — el primero
  escribe en el `<input>` del proxy y Flutter lo descarta al cambiar de foco.
- **El `errorText` de un campo NO es un nodo del árbol de semántica en Flutter web**: viaja
  pegado al `aria-label` del `<input>`. `getByText` no puede verlo nunca. Afirmarlo ahí prueba
  además que el error se anuncia a un lector de pantalla.
- **Dos auditores independientes encontraron conjuntos DISTINTOS.** El agujero de Storage lo vio
  solo el abogado del diablo; el juez, que puntuó Seguridad 16/20, no lo detectó. Y **uno de los
  cinco cargos era falso**, con cita de `ruta:línea` igual que los verdaderos: la cita hace el
  cargo comprobable, no cierto.
- **El gate de revisión tumbó mi propio arreglo.** Atar la cita a su conversación no cerraba
  nada: el `create` de `/conversaciones` dejaba fabricarse esa conversación nombrando de mecánico
  a la víctima. La rama del mecánico se cerró en la Ronda 3; la del propietario seguía abierta
  desde entonces.
- **Recargar la página en `/task_config` o `/task_complete` reventaba la app** — `state.extra` no
  sobrevive a un refresh y el cast era incondicional. No hace falta teclear la URL: basta F5.
- **Refutar un cargo dio un defecto que nadie pidió**: el chat no duplica mensajes, pero el envío
  es fire-and-forget y el texto ya se borró, así que si falla la persona lo pierde sin ver error.
- **Centinela nuevo** `test/core/providers/salidas_de_sesion_test.dart`: obliga a que toda
  pantalla que cierre sesión limpie los providers, con un mapa de exenciones razonadas y un
  segundo test que rompe si una exención se queda huérfana.

**Cifras:** `flutter analyze` limpio, `flutter test` **1227/1227**, Functions **276**, reglas
**465/465** en 28 suites, E2E de la app **37/37 en serie y cero `fixme`**, E2E de la landing
**42/42**, puertos libres al salir.

**Quedan diez gaps anotados** en el §6 de la evidencia de H-01, más los quince de GAPS-04. Los de
más peso: App Check en `monitor` por defecto (deliberado, es paso de runbook), seis formularios
sin defensa contra doble envío —solo uno verificado a mano— y las lecturas sin cota del panel del
mecánico y del barrido de alertas.

### La tanda GAPS-04 está cerrada (2026-09-13, `fix/gaps-04`, fusionada)

Drenaje de los gaps que quedaban abiertos antes de H-01. Evidencia en
`docs/evidencia/GAPS-04-drenaje.md`. Lo que hay que saber sin leerla:

- **Remitir un gap a una tarea futura NO lo cierra.** Dos gaps se habían «remitido a
  OPS-01», OPS-01 cerró sin recogerlos y ahí se quedaron. Son justo los dos de más valor de
  la tanda. Si mandas un gap a una tarea, esa tarea tiene que recogerlo explícitamente en su
  evidencia o volver a quedar anotado.
- **Otra vez dos descripciones de gap estaban mal, y la peor tranquilizaba.** El gap 9.6
  decía que nadie recogía `vinculo_revocacion_pendiente`; en realidad el barrido sí la
  recoge, pero **a los 30 días** — o sea que un fallo de revocación regalaba un mes de
  acceso a la ficha de un coche ya devuelto. Ya van tres rondas seguidas: **la anotación
  sirve para no perder el gap, no como diagnóstico.**
- **`/alertas` pasa de denylist a allowlist.** Una denylist cubre los campos de servidor que
  existían el día que se escribió y deja nacer escribible cualquiera posterior — por ahí
  llegó el hallazgo de SEC-04. Hay un centinela nuevo, `test/alertas_campos_test.dart`, que
  cruza `camposDeAlerta()` de las reglas con `AlertModel.toMap()` **en las dos direcciones**:
  sin él, un campo nuevo del modelo se denegaría **solo en producción**, porque los
  emuladores obedecen la regla igual de bien que Firestore.
- **Trigger nuevo `borrarFotosAlEliminarResenia`.** Al eliminar una reseña sus fotos se
  quedaban en Storage. Son **dos** caminos y el segundo no estaba anotado: el borrado de
  cuenta barre reseñas en lotes de 500 sin pasar por la app.
- **Retirado `streamReservasUsuario` y toda su rama** (cero consumidores en `lib/`,
  sostenida por tres tests — el patrón de FUNC-02). **Y el centinela de índices paró un
  defecto real**: con sus dos índices se iba también un tercero de `reservas` que usa el
  recordatorio de citas, que es del **servidor**. Vaciar `lib/` de consultas a una colección
  no significa que la colección se quede sin consultas.
- **Los dos revisores encontraron siete defectos que las suites propias no veían**, y el peor
  era mío repitiendo el gap 9.1: **en un `whereIn` el `limit` se aplica por subconsulta**, así
  que un `limit(50)` con 30 vehículos lee hasta 1500 documentos. Es la tercera tanda seguida
  en que los gates pagan su coste.
- **Runbook nuevo:** `firebase deploy --only firestore:indexes` antes que la app — crea uno
  (`servicios (id_vehiculo, id_taller, fecha DESC)`) y retira dos de `reservas`.

**Cifras al día:** `flutter analyze` limpio, `flutter test` **1221 / 1221**, Functions
**276**, reglas **454 / 454** en 26 suites, puertos libres al salir.

**Quedan quince gaps anotados** en el §7 de esa evidencia, con su razón. Los de más peso: la
denormalización de `avisos_pendientes` (el barrido de alertas relee cada día todo lo ya
avisado), el N+1 de los barridos, los siete triggers de notificación sin test, y el panel del
mecánico con cuatro streams sin tope.

### SEC-04 / OPS-01 — enforcement de App Check y tareas programadas

Rama `fix/sec04-ops01`. Evidencia en
`docs/evidencia/SEC-04-OPS-01-enforcement-y-tareas-programadas.md`. Lo que hay que saber
sin leerla:

- **App Check estaba a medias, y faltaba la mitad que protege.** El cliente firma desde
  `lib/main.dart:183` y **ningún servidor comprobaba la firma**. Y la trampa: este repo usa
  Cloud Functions **v1**, donde el enforcement **no tiene interruptor de consola**. Activar
  App Check en la consola habría mostrado el producto «protegido» mientras los doce
  callables aceptaban cualquier llamada. Ahora los 12 llaman a `exigirAppCheck`, con un
  centinela que corta el entrypoint por bloques `exports.` — **no cuenta ocurrencias**,
  porque contar `onCall` y contar `exigirAppCheck` daría el mismo número aunque uno llevara
  dos y otro ninguna.
- **El modo por defecto es `monitor`, no `enforce`, y es deliberado.** Con `enforce` la
  suite E2E entera dejaría de pasar: el emulador de Functions no emite tokens. Encenderlo
  es un paso de runbook, y un valor no reconocido cae a `monitor` (caer a `off` sería
  inseguro en silencio; caer a `enforce` por una errata tiraría la app entera).
- **El barrido de alertas mandaba el mismo push cada día, para siempre.** Nada marcaba la
  alerta como avisada y `estado` solo lo cambia el usuario a mano. Ahora hay dos escalones
  y dos notificaciones en toda la vida de una alerta. `ultimo_aviso` queda cerrado al
  cliente en las reglas, por `affectedKeys()` y **también en el `create`** — sin eso se
  podía nacer la alerta ya silenciada, y de forma irreversible.
- **El recordatorio de citas leía todas las reservas confirmadas de la historia, cada día**,
  y calculaba «mañana» en UTC: Colombia es UTC-5, así que las citas de tarde salían
  descolocadas. Ahora la cota va en el servidor, con índice `reservas (estado,
  fecha_hora_propuesta)`.
- **El respaldo no fallaba sin `projectId`: exportaba a `gs://undefined-backups`.** Es la
  única copia de seguridad del proyecto y podía llevar meses sin hacerse.
- **Los dos revisores encontraron tres defectos que los tests propios no veían**, y uno
  grave: el `update` de contabilidad estaba fuera del `try`, así que **borrar una alerta a
  media pasada abortaba el barrido del día entero** — denegación de servicio con una
  operación que las reglas autorizan. También que `startAfter` era un no-op en los dos
  dobles, por lo que la paginación no la ejercía ningún test.
- **Cuatro pasos de runbook nuevos** en `docs/RUNBOOK.md`: desplegar índices y correr
  `node backfill_ultimo_aviso.js --apply` **antes** que las funciones (sin el backfill, la
  primera corrida notifica de golpe todo el histórico); cómo llega `APP_CHECK_ENFORCEMENT`
  a las funciones desplegadas (archivos `.env` por proyecto, no un ajuste de consola); y
  los prerrequisitos del respaldo (bucket, rol IAM y política de ciclo de vida).

### Los gaps de accesibilidad de UX-03 están cerrados (`fix/gaps-03`)

Evidencia en `docs/evidencia/GAPS-03-accesibilidad-de-la-landing.md`. Dos cosas que valen:

- **Las cifras de contraste heredadas eran aproximadas.** Venían de los hex de Tailwind 3 y
  la landing usa Tailwind **4**, que computa en OKLCH: medido de verdad, `amber-600` seguía
  fallando (3.058:1) y hubo que subir a `amber-700`.
- **La anotación no decía el tema, y no todos fallaban en el mismo.** El pie fallaba en
  oscuro y pasaba en claro; la calificación, al revés. Arreglar «el contraste del pie» sin
  medir habría tocado el lado que ya cumplía.
- Las cuatro imágenes de fondo por CSS **son decorativas** y por tanto no necesitan
  alternativa textual: quedan con un comentario para que la próxima auditoría no las
  levante otra vez.

**La E2E de la app en paralelo no es reproducible, y su rojo no es senal.** El emulador Java
de Firestore no da abasto cuando cuatro workers arrancan la app a la vez, y lo que se pierde
es la primera lectura del perfil: el router ve `userData == null` y manda a `/profile_setup`.
UX-03/04 anoto que la corrida siguiente salia 32/32; en SEC-04/OPS-01 **no se curo sola** —dos
corridas paralelas seguidas fallaron, la segunda peor que la primera— y solo
`npm test -- --workers=1` la saca entera en verde. **Toma el numero de gate de esta suite en
serie**; en paralelo cada rojo cuesta una investigacion.

**Cifras al día del árbol combinado:** `flutter analyze` limpio, `flutter test`
**1216/1216**, Functions **263**, reglas **446/446** en 25 suites, E2E de la landing
**42/42**.

UX-03 / UX-04 ya estan cerradas y fusionadas (`fix/ux03-ux04`). Evidencia en
`docs/evidencia/UX-03-UX-04-accesibilidad-y-errores.md`. Lo que hay que saber sin leerla:

- **No habia un menu movil inaccesible: no habia menu.** La navegacion de la landing es
  `hidden md:flex`, asi que por debajo de 768 px los tres enlaces de seccion desaparecian, y
  «Iniciar Sesion» (`hidden sm:block`) tambien: a 320 px solo quedaba «Probar Gratis».
- **Quitar las animaciones bajo `prefers-reduced-motion` deja la landing PEOR que antes.** Es
  un export estatico: framer-motion hornea el valor de `initial` como estilo inline en el HTML
  y en el servidor `useReducedMotion()` no sabe nada. Sin nadie que anime esos estilos, el
  elemento se queda congelado donde lo dejo el servidor — **invisible para siempre**. Medido:
  con `{}` y tambien con solo `{initial: false}`, el titulo de talleres seguia en `opacity: 0`
  a los 2,5 s. Hace falta un destino explicito (`animate: REPOSO`) que PISE el estilo inline.
- **`test.use({ reducedMotion })` NO surte efecto en Playwright 1.62.1.** `matchMedia(...)`
  dentro de la pagina seguia dando `false` y los casos fallaban con el arreglo ya puesto. Usa
  `page.emulateMedia()`, y antes del `goto`.
- **El `Error: ${snapshot.error}` del enunciado era uno de cuarenta, y el patron estaba una
  capa mas abajo:** quince providers guardaban `_error = e.toString()` (77 sitios) y las
  pantallas pintan ese campo tal cual. Consecuencia que nadie habia visto: donde la pantalla
  hace `provider.error ?? context.l10n.loQueSea`, **la cadena traducida no se veia nunca** —
  el error crudo no es null cuando algo falla. Habia ARB traducido al ingles inalcanzable.
- **Ocho tests existentes se pusieron rojos y los ocho probaban de mentira.** Lanzaban una
  CADENA suelta (`thenThrow('email-already-in-use')`) y afirmaban que `provider.error` la
  contenia: con `_error = e.toString()` eso pasaba por construccion, sin ejercer una linea del
  manejo real de errores de Firebase. Ahora lanzan `FirebaseAuthException`.
- **Los codigos de Auth no caen en el mensaje generico, a proposito:** son los unicos errores
  de la app que la persona puede resolver sola. Taparlos habria sido cambiar un defecto por
  otro.
- **Centinela nuevo: `test/errores_sin_detalle_tecnico_test.dart`.** Ninguna otra suite ve
  este defecto — un `Text('Error: $e')` compila, analiza limpio y pasa cualquier test de
  widget. Destapo cinco fugas mas. Mira solo presentacion y providers; `data/` queda fuera
  adrede.
- **El hook de pre-commit daba un falso positivo:** `dart format .` no falla, MUERE recorriendo
  `landing-web/node_modules` tras un `pnpm install` en el worktree (rutas de pnpm mas largas de
  lo que Windows admite). Decia «hay Dart sin formatear» sin listar un archivo. Ya lo
  distingue.
- **La E2E de la app dio 2 rojos en la primera corrida y 0 en la segunda.** Es la contencion ya
  conocida, no una regresion: los dos specs solos dan 9/9.

Cifras del arbol con UX-03/UX-04: `flutter analyze` limpio, `flutter test` **1216/1216**,
E2E de la landing **40/40**, E2E de la app **32 pasan y 2 `fixme`**.

Gaps anotados en el §Gaps de esa evidencia: contraste por debajo de 4.5:1 en seis sitios de la
landing (cifras de un worker, **sin verificar a mano**), jerarquia de encabezados con saltos,
cuatro imagenes de fondo por CSS sin alternativa textual, el fundido de `FeaturesGrid` bajo
movimiento reducido (deliberado) y una clave de ARB que no hace falta todavia.

**Los nueve residuales de FUNC-02 estan cerrados** en la rama `fix/gaps-func02`. No es una
tarea del plan: es el drenaje del §7 de la evidencia de FUNC-02. Evidencia en
`docs/evidencia/GAPS-FUNC-02-cierre-de-residuales.md`. Lo esencial:

- **Dos estaban mal descritos.** El «indice muerto `Servicios`» era `servicios` con la S
  MAYUSCULA, o sea el indice VIVO mal escrito: el historial de servicios del propietario moria
  con `failed-precondition` por su culpa. Y la «consulta que falla en silencio» no daba un
  mensaje equivocado: dejaba la pantalla pintando el FORMULARIO MANUAL, asi que el mecanico
  re-tecleaba el importe ya aprobado y era ese el que se guardaba en `servicios`.
- **Centinela nuevo: `test/firestore_indices_test.dart`.** Los emuladores sirven cualquier
  consulta sin mirar `firestore.indexes.json`: una consulta sin indice NO la detecta ninguna
  suite, solo produccion. Cruza el inventario con los indices en las dos direcciones y cuenta
  los `.orderBy(` de `lib/` y los `.where(` de `functions/` como disparador. Destapo seis
  consultas mas sin indice y cuatro indices huerfanos.
- **`InitiateServiceScreen` acepta ahora un `firestore` inyectable.** Sus trece tests corrian
  contra `FirebaseFirestore.instance` sin Firebase real, o sea contra una consulta que
  SIEMPRE fallaba, y nadie lo sabia porque el `.then` sin `catchError` se lo tragaba. Si
  montas esa pantalla en un test, pasale un `FakeFirebaseFirestore`.
- **La recepcion usa `runTransaction`** y la autorizacion viaja dentro como callback. **El
  vinculo caduca solo** a los 30 dias sin actividad: caduca el ACCESO, no el ticket.
- **Runbook, y el primero no es negociable:** `node backfill_entregado.js --apply` ANTES de
  desplegar la app web (el tablero ordena por `fecha_actualizacion` y un `orderBy` excluye los
  documentos sin el campo), y `firebase deploy --only firestore:indexes` antes que la app.
- **Quedan nueve gaps NUEVOS** en el §9 de esa evidencia. El que mas vale: el tope del tablero
  acota documentos, no lecturas — un `whereIn` de 5 estados con `limit(200)` aplica el limite
  a CADA subconsulta, asi que lee hasta 1000 para devolver 200.

FUNC-02 esta fusionada en `integracion/ola-1` (`58f5dd9`, sin conflictos). Evidencia en
`docs/evidencia/FUNC-02-apertura-unica-de-tickets.md`. Lo que hay que saber sin leerla:

- **Los cuatro metodos `@Deprecated` de `ReparacionProvider` y los dos del repositorio tenian
  CERO consumidores en `lib/`.** Lo unico que los sostenia vivos era la siembra de 19 tests.
  Esa siembra vive ahora en `test/support/sembrar_reparacion.dart`, donde no puede compilarse
  dentro de la app. Si vas a retirar codigo muerto, mira primero quien lo sostiene.
- **El peor camino obsoleto seguia VIVO en el servidor.** El callable
  `iniciarReparacionPorVehiculo` no tenia llamador pero seguia desplegado e invocable por
  cualquier mecanico autenticado: abria el ticket directamente en `'recibido'` —saltandose la
  recepcion fisica— y se otorgaba `vehiculos.talleres_vinculados`. Su unica compuerta era
  «existe una cotizacion aceptada para este vehiculo+taller», y **una cotizacion se queda en
  `aceptada` para siempre**: con una visita YA ENTREGADA bastaba para recuperar el acceso al
  coche que `revocarVinculoAlCerrarTicket` acababa de revocar.
- **`firestore.rules` no podia taparlo.** `allow create: if false` sobre `/reparaciones` NO
  alcanza a callables ni triggers: corren con Admin SDK. Cualquier funcion nueva sobre esa
  coleccion tiene que replicar la autorizacion a mano.
- **Paso de runbook, sin el cual la tarea esta cerrada en el repo y abierta en produccion:**
  `firebase functions:delete iniciarReparacionPorVehiculo`. Borrar el export no retira el
  endpoint desplegado, y `firebase deploy --only functions:<otra>` tampoco lo purga.
- **Quedan tres escritores server-side sobre `/reparaciones` y ninguno mas:**
  `onCotizacionAceptada` (crea, en `pendiente_recepcion`), `recibirVehiculoDelTicket`
  (transiciona) y el barrido de `onVehicleDelete` (cierra). Lo vigila
  `functions/test/apertura_unica_ticket.test.js`, que cuenta los accesos **por archivo**: su
  primera version miraba solo el cuerpo de cada `exports.` y pasaba por casualidad, porque la
  escritura real de `recibirVehiculoDelTicket` vive en `src/vinculoTaller.js`.
- **Nueve gaps abiertos y anotados** en el §7 de esa evidencia. Los dos que mas valen: el
  dedup de tickets puede fallar por volumen (`.limit(20)` sin filtro de estado ni orden en
  `aceptarCotizacion.js:247`), y hay una consulta compuesta **sin indice declarado que falla
  en silencio** (`initiate_service_screen.dart:269`, en un `.then` sin `catchError`; la
  pantalla acaba diciendo «no hay cotizacion aceptada» por un `failed-precondition`).

FUNC-01 esta fusionada en `integracion/ola-1` (`18c73d7`, sin conflictos). Evidencia en
`docs/evidencia/FUNC-01-fotos-de-resenias.md`. Lo que hay que saber sin leerla:

- **El enunciado del plan describe mal el bug.** «La edicion descarta fotos» no era cierto: el
  sheet escondia el selector en modo edicion precisamente para que no se descartara nada. El
  defecto real era que `ReviewService.updateReview` **no mencionaba `fotos`** —tras publicar no
  habia forma de tocarlas— y que `storage.rules` **no dejaba al autor borrar las suyas**
  (`allow delete: if isAdmin()`). Sin ese segundo cambio la tarea no se cerraba: limpiar un
  huerfano moria en `permission-denied`.
- **Agujero destapado por el gate de reglas:** `resenias` es de lectura ANONIMA y la rama del
  autor del `allow update` aceptaba cualquier URL en `fotos`. Era teorico mientras el cliente no
  escribia `fotos` en un update; FUNC-01 es justo lo que lo vuelve alcanzable. Cerrado con
  `fotosBajoServicio` (hermano de `esUrlDeStoragePropia`): ancla host y prefijo
  `resenia_fotos%2F{idServicio}%2F`, tope de 3. **En un update valida solo si `fotos` cambia**,
  porque `request.resource.data` es el documento resultante y validar siempre dejaria
  ineditables las resenias con URLs heredadas.
- **Contrato nuevo:** `updateReview(..., fotosConservadas, fotosNuevas)`. `null` = no tocar, y
  devuelve `null` y no `[]` porque una lista vacia seria indistinguible de «se borraron todas».
  Storage se inyecta con dos typedefs, misma costura que `GaleriaService`.
- **Residuales anotados, no cerrados:** el «vehiculo fantasma» (`vehiculos` admite `create` con
  ID elegido por el cliente y `onVehicleDelete` es asincrono) —endurecerlo es una migracion, no
  un ajuste— y que nadie borra las fotos al ELIMINAR una resena, que toca a un trigger
  `onDelete` con Admin SDK y encaja en OPS-01.

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
cerradas estan todas en **`integracion/ola-1`**. Las tres de ola 2 (`fix/qa02`,
`fix/ver01`, `fix/role`) se fusionaron el 2026-09-07, QA-01 el 2026-09-08, y UX-01 y UX-02 el
2026-09-09, **ninguna con un solo conflicto**. Encima va `fix/landing-crash`, que **no es una
tarea del plan** pero si trabajo real sobre la landing: normaliza las calificaciones que
llegan por la REST de Firestore (de ahi salia el crash) y retira Vercel Analytics.

**Ya no queda ninguna rama `fix/*` pendiente de fusionar.** Corta de `integracion/ola-1`.

**Arbol combinado verificado entero el 2026-09-10** en
`C:/Users/User/Documents/creaj/wt-integra`:

| Suite | Resultado |
|---|---|
| `flutter analyze` | limpio |
| `flutter test` | **1180 / 1180**, exit 0 |
| `functions` (Mocha) | **197 passing** |
| `test_rules` (Jest + emuladores) | **426 / 426**, 24 suites, exit 0 |
| E2E de la app (Playwright) | **32 pasan, 2 `fixme`**, exit 0 |
| E2E de la landing | **20 / 20**, exit 0 |
| Puertos al salir | 0 en `LISTENING` |

**La tanda de drenaje `fix/gaps-02` esta cerrada** (2026-09-11). Cuatro cosas que un worker
en frio tiene que saber antes de tocar `reparaciones` o el chat:

- **El tablero ya NO filtra por `estado`.** Es la igualdad `abierto == true` sobre un booleano
  denormalizado en el ticket (gap 9.1): un `whereIn` aplica el `limit` a CADA subconsulta, asi
  que leia hasta 1000 documentos para devolver 200. Si siembras un ticket en un test **tienes
  que escribir `abierto`**: una igualdad sobre un campo ausente no devuelve nada, y eso puso
  rojos diez tests de golpe.
- **`abierto` se deriva SIEMPRE del estado, nunca se pasa como parametro.** Lo escriben el
  cliente (`ReparacionModel.toMap`, `cambiarEstado`), los tres escritores server-side y el
  backfill; `firestore.rules` lo ata al estado RESULTANTE y exige ademas que un campo que
  estaba siga estando — sin eso, un `FieldValue.delete()` esquivaba la regla entera.
- **El barrido de `onVehicleDelete` vive ahora en `functions/src/cerrarTicketsDeVehiculo.js`**,
  no inline en `index.js`. El centinela de accesos por archivo cuenta `index.js`: 1.
- **El centinela de indices ya no exige compuesto a las consultas de solo igualdades** (gap
  9.4): Firestore las resuelve por index merging. Se retiraron cuatro indices. Si tu consulta
  lleva un `not-in` o un `in`, eso es una DESIGUALDAD y va en `orden`, no en `igualdades`.

**El gap 7.1 de esa tanda esta cerrado aparte** (`fix/marcar-leidos`, fusionada el
2026-09-11): `marcarComoLeidos` leia el hilo entero y su WriteBatch reventaba con mas de
499 mensajes del otro participante, dejando el contador de no leidos sin resetear para
siempre. Ahora filtra en el servidor (`id_remitente` + `estado != 'visto'`) y marca por
lotes de 400. Indice nuevo: `mensajes (id_remitente, estado)`.

**Siguiente tarea del plan: SEC-04 / OPS-01** (operacion y suites confiables). UX-03 / UX-04
se cerraron el 2026-09-12; lo que dejaron esta arriba y en
`docs/evidencia/UX-03-UX-04-accesibilidad-y-errores.md`.

**El script `test` de `test_rules/` no acepta argumentos** (es un `firebase emulators:exec`;
`npm test -- storage.test.js` muere con «Too many arguments»). Para una sola suite:
`npx firebase emulators:exec --only firestore,storage --project autodoc-rules-test "npx jest
--runInBand storage.test.js"`.

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
