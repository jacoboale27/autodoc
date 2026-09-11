# Tanda de drenaje 2 — evidencia

**Rama:** `fix/gaps-02`, cortada de `integracion/ola-1` (`af5f3c0`).
**Plan:** `docs/evidencia/GAPS-02-plan-de-drenaje.md`. **Origen:** §9 de
`docs/evidencia/GAPS-FUNC-02-cierre-de-residuales.md`.
**Fecha:** 2026-09-11. No es una tarea del plan de remediación: es el drenaje de los gaps
que dejó la tanda anterior, y va antes de UX-03/UX-04 por decisión del usuario.

Cerrados: **9.1, 9.2, 9.3 y 9.4**. Remitidos a OPS-01: 9.5 y 9.6 (ya lo estaban).
Se quedan anotados a propósito: 9.7, 9.8 y 9.9.

---

## 1. Lo que hay que saber sin leer el resto

- **La trampa que el plan mandaba comprobar ANTES de tocar la bandeja no existía.** El
  plan advertía que poner `orderBy('ultimo_mensaje_ts')` haría desaparecer en silencio las
  conversaciones sin ese campo, y pedía una pasada de backfill si podían existir. **No
  pueden.** El campo es obligatorio en `ConversacionModel` (no nulable, y `toMap` siempre
  lo escribe), `ChatProvider.iniciarOCrearConversacion` es el único creador de `lib/`, las
  Functions solo LEEN esa colección, y el modelo nació con el campo en su primer commit
  (`50b8c87`). Ni backfill ni paso de runbook. Comprobarlo costó diez minutos y ahorró una
  migración inventada.
- **En el lote C la trampa sí era real, y se cobró diez tests de golpe.** Denormalizar
  `abierto` y consultar por igualdad hace desaparecer todo documento que no tenga el campo
  — y eso incluye las **siembras de los tests**, que no lo escribían. Diez tests de Kanban
  y de reseteo de sesión se pusieron rojos con «Found 0 widgets». Es exactamente lo que le
  pasaría a producción sin el backfill, ensayado gratis.
- **El gate de revisión encontró el agujero por el lado que la regla no miraba.** La regla
  ataba `abierto` a su VALOR, y un campo **borrado** no tiene valor: con
  `update({abierto: FieldValue.delete()})` un taller escondía de su propio tablero un
  ticket vivo —con el vínculo al coche intacto— sin que la regla lo tocara, porque
  `.get(campo, derivado) == derivado` degenera en una tautología. El test que decía cubrir
  ese caso solo ejercitaba el valor `false`: una puerta más estrecha que la que su
  comentario prometía.
- **Y el otro revisor encontró que el backfill iba a silenciar media base de datos.** La
  pasada nueva de `abierto` toca la colección entera, y el script estampaba el centinela
  `migracion_ronda6` en **cada** cambio. Ese centinela es **pegajoso** (`esMigracion` mira
  el documento resultante, nunca el delta, y nadie lo borra): todo ticket vivo el día de
  la migración habría dejado de notificar sus transiciones al propietario **y** de revocar
  el vínculo al entregarse. El runbook obliga a correr ese script contra producción antes
  de desplegar, así que se habría ejecutado.
- **Un `limit` que nadie mira:** `ReservaProvider.inicializarReservasUsuario` no tiene
  **ningún llamador en `lib/`** — solo `session_reset.dart`, que lo limpia, y los tests.
  El stream de reservas está acotado igual (es correcto y barato), pero ninguna pantalla
  lo consume, así que no tiene aviso de truncado. Es el mismo patrón que FUNC-02: código
  vivo sostenido por sus pruebas. Anotado como gap nuevo.

---

## 2. Lote A — los streams sin tope (gaps 9.2 y 9.3)

| Stream | Antes | Ahora |
|---|---|---|
| Bandeja de chat (`chat_repository.dart:52`) | `where(rol)` + `list.sort()` en memoria | `orderBy('ultimo_mensaje_ts' DESC).limit(100)` |
| Hilo de mensajes (`chat_repository.dart:88`) | `orderBy(timestamp DESC)` sin tope | `.limit(200)`, por el final |
| Historial de reservas (`reserva_repository.dart:24`) | `orderBy` sin tope | `.limit(100)` |

Ordenar en memoria no acota nada: el coste ya se pagó. Un mecánico con 800 conversaciones
pagaba 800 lecturas en cada apertura del chat y en cada reattach del listener.

El recorte del hilo va **por el final** (los más recientes): un hilo al que le falta lo
último dicho es peor que uno lento. La consulta ya venía descendente, así que el `limit`
cae del lado correcto por construcción — y el test lo fija afirmando que `m0` (el más
antiguo) NO está y que el primero es el último enviado.

Los topes se anuncian: `AvisoListaTruncada` (nuevo, en `core/widgets/`), con copy en el
ARB (`bandejaTruncada`, `hiloTruncado`). En el hilo va como elemento extra al final de la
`ListView` invertida, o sea arriba del todo — justo donde se quedaron los mensajes que no
se cargaron.

**Dos índices repuestos:** `conversaciones (id_propietario, ultimo_mensaje_ts DESC)` y
`(id_mecanico, …)`. La tanda anterior los retiró por huérfanos, y lo estaban **porque el
orden se hacía en memoria**: este arreglo es justo lo que vuelve a necesitarlos.

**Evidencia:** `test/features/chat/streams_acotados_test.dart` (8 casos) y
`test/features/chat/presentation/pages/avisos_truncado_test.dart` (3). Los cuatro
primeros se vieron rojos por aserción —no por compilación— antes de implementar.

---

## 3. Lote B — los cuatro índices de solo igualdades (gap 9.4)

**Decisión: se retiran los cuatro.** Firestore resuelve las consultas de solo igualdades
por *index merging* sobre los índices automáticos de un campo; las cuatro son muy
selectivas (ids de vehículo, taller, usuario) y las cuatro llevan `limit(1)` o similar,
así que el merge join no es un problema. Cada índice compuesto, en cambio, se paga en cada
escritura de su colección — y `conversaciones` se escribe en **cada mensaje enviado**.

Retirados: `conversaciones (id_propietario, id_mecanico)`,
`conversaciones (…, id_vehiculo)`, `cotizaciones (id_vehiculo, id_taller, estado)` y
`reparaciones (id_vehiculo, id_taller)` — este último, además, es prefijo del compuesto
que se conserva para el `not-in` del dedup.

**El centinela era más estricto que Firestore y había que relajarlo**
(`test/firestore_indices_test.dart`): ahora solo exige compuesto a las consultas que
ordenan o llevan desigualdad (`_Consulta.necesitaCompuesto`), y un índice solo cuenta como
«usado» si sirve a una de esas. Sin la segunda mitad, el test de huérfanos seguía dando
verde y no habría obligado a borrar nada.

**Trampa dentro de la trampa:** el dedup del servidor (`aceptarCotizacion.js:247`) estaba
modelado en el inventario como **tres igualdades**, pero su tercer filtro es un `not-in`.
Con la regla nueva habría dejado de exigir su índice y el test de huérfanos lo habría
mandado a borrar — un `failed-precondition` en producción, que es exactamente la clase de
fallo que este centinela existe para impedir. Se remodeló con la desigualdad en `orden`,
como ya hacía el barrido de caducidad.

---

## 4. Lote C — `abierto` denormalizado (gap 9.1)

`watchReparacionesActivas` era `whereIn` de 5 estados + `orderBy` + `limit(200)`. Firestore
ejecuta un `in` como **N subconsultas y aplica el límite a cada una** antes de fusionar:
hasta **1000 documentos leídos para devolver 200**, en cada `attach`. El tope acotaba
documentos, no lecturas.

Ahora es la igualdad `abierto == true`, que lee exactamente 200. El precio es un campo que
puede mentir, y por eso se deriva **siempre** del estado y nunca se pasa como parámetro:

| Quién | Dónde |
|---|---|
| Cliente | `ReparacionModel.toMap` y `ReparacionRepository.cambiarEstado` |
| Reglas | `ticketAbierto()` + `abiertoCoherente()` en `firestore.rules`, sobre `request.resource.data` |
| Servidor | `construirTicketReparacion`, `recibirTicketYVincular`, `cerrarTicketsDeVehiculo` |
| Legados | pasada 4 de `backfill_entregado.js` |

**La regla ata el estado RESULTANTE, no el viejo.** `request.resource.data` y no
`resource.data`: autorizar mirando el documento viejo es el patrón exacto que destapó los
cinco huecos de QA-01. Y va **fuera** de la rama del taller, aplicándose también al admin:
un admin que cerrara un ticket sin bajar `abierto` dejaría una tarjeta clavada en el
tablero que el taller **no puede** arreglar, porque un ticket cerrado le es inmutable.

**El barrido de `onVehicleDelete` se extrajo a `functions/src/cerrarTicketsDeVehiculo.js`.**
Vivía inline en el cuerpo del trigger, donde ninguna prueba podía ejercerlo — y es el
escritor cuyo olvido más caro cuesta: desde que la consulta no mira `estado`, un barrido
que cierre el ticket sin bajar `abierto` deja la tarjeta en el tablero para siempre. El
centinela de accesos por archivo detectó el movimiento y obligó a justificarlo, que es su
trabajo.

**Lo que NO se hizo, a propósito:** acotar ese mismo barrido con
`where('abierto','==',true)`, que el revisor proponía. Haría que la corrección del barrido
dependa de que el backfill haya corrido: un ticket legado abierto y sin el campo dejaría
de cerrarse al borrar su vehículo. La lectura no acotada es el precio de no depender.

**Evidencia:** `test/features/mechanic/tablero_abierto_test.dart` (6),
`test_rules/reparaciones_abierto.test.js` (9), `functions/test/ticket_abierto.test.js` (7),
`functions/test/backfill_abierto.test.js` (6) y tres casos nuevos en
`functions/test/vinculo_taller.test.js` y cuatro en `functions/test/migracion.test.js`.

Los tests de Functions se escribieron **después** de implementar en dos casos; para no
dar por buena una prueba que no se ha visto fallar, se revirtió la implementación a
propósito y se confirmó que los dos se ponen rojos (`abierto` fuera de
`construirTicketReparacion` y fuera del barrido) antes de restaurarla.

---

## 5. Los dos gates de revisión

Ambos obligatorios (el lote C toca `firestore.rules` y `functions/`), corridos en paralelo
después de implementar y antes de cerrar. Encontraron **cuatro cosas que estaban mal**, dos
de ellas graves:

| # | Hallazgo | Qué se hizo |
|---|---|---|
| 1 | `abierto` se podía **borrar** con `FieldValue.delete()` y la regla lo dejaba pasar | Cerrado: `abiertoCoherente()` exige además que un campo que estaba siga estando. Dos tests nuevos |
| 2 | El backfill estampaba `migracion_ronda6` en **todos** los tickets vivos: dejarían de notificar y de revocar el vínculo, para siempre | Cerrado: `cambioNecesitaCentinela` lo limita a los cambios que mueven el estado |
| 3 | `recibirTicketYVincular` reparaba `abierto` justo en el caso que no lo necesitaba, y lo omitía en los legados, que son los que no salen en el tablero | Cerrado: la escritura pasa a la rama idempotente |
| 4 | La pasada 4 escribía `abierto: false` a todo el historial cerrado: N escrituras y 2N triggers que ninguna consulta aprovecha | Cerrado: no se escribe si el campo falta y el ticket queda cerrado |
| 5 | La rama de `isAdmin()` no pasaba por la coherencia | Cerrado: la comprobación salió de la rama del taller |
| 6 | Punteros a `functions/src/estadosTicket.js`, que no existe, y dos comentarios que seguían describiendo un `whereIn` | Corregidos |

El resto de lo que señalaron —el `limit` del barrido, el batch de `marcarComoLeidos`, el
colapso del dedup— va al §7 como gaps nuevos, con su razón.

---

## 6. Gates

| Gate | Resultado |
|---|---|
| `flutter analyze` | `No issues found!` |
| `flutter test` | **1197 / 1197**, exit 0 (salida entera a archivo, nunca por `tail`) |
| `functions` (Mocha) | **218 passing** |
| `test_rules` (Jest + emuladores) | **435 / 435**, 25 suites, exit 0 |
| E2E de la app (Playwright) | **32 pasan, 2 `fixme`**, exit 0. No ejercita chat ni `reparaciones` (ninguna de sus siembras toca esas colecciones), así que lo que confirma es que la app sigue arrancando |
| Puertos al salir | 0 en `LISTENING` |
| E2E de la landing | no se relanza: no se toca `landing-web/` ni `e2e/tests-landing/` |

---

## 7. Gaps nuevos que deja esta tanda

### 7.1 `marcarComoLeidos` lee el hilo entero y su batch puede reventar (MEDIO)

`chat_repository.dart`: `.where('id_remitente', isNotEqualTo: uid).get()` **sin `limit`**
cada vez que se abre una conversación, filtrando `estado != 'visto'` en memoria, y todo
dentro de un único `WriteBatch`. Un hilo con más de 499 mensajes del otro participante
**revienta el commit** (límite de 500 escrituras) y el contador de no leídos no se resetea
nunca más. El gap 9.3 acotó el stream de al lado y dejó esta lectura intacta.

### 7.2 El stream de reservas no lo consume ninguna pantalla (BAJO)

`ReservaProvider.inicializarReservasUsuario` no tiene llamadores en `lib/`. Se acotó igual
—correcto y barato— pero no tiene aviso de truncado porque no hay dónde pintarlo. O se
conecta a una pantalla o se retira; es el patrón de FUNC-02.

### 7.3 El dedup de tickets podría colapsar en una sola consulta (BAJO)

Con `abierto` backfilleado, las dos consultas de `aceptarCotizacion.js` (un `not-in` más
un rescate con `.limit(20)` sin filtro, que es el gap conocido de que el dedup puede fallar
por volumen) se reducen a tres igualdades con `limit(1)`, y se podría retirar el último
compuesto de `reparaciones` por vehículo+taller. **Requiere que el backfill haya corrido**,
así que es trabajo posterior al despliegue, no de esta rama.

### 7.4 Dos consultas más de la misma familia que el gap 9.1 (BAJO)

`workshop_service.dart:33` y `:47` siguen con `whereIn` + `orderBy` + `limit(50)`: leen
hasta 2×50 para devolver 50. Y `review_service.dart:133` lee `servicios` con un `whereIn`
de 30 vehículos **sin `limit`**, ordenando en memoria.

### 7.5 El barrido de `onVehicleDelete` lee el historial completo del vehículo (BAJO)

Decisión consciente, ver §4. Acotarlo con `abierto` lo haría depender del backfill.

### 7.6 Lo de siempre, sin dueño

El rojo intermitente de `flutter test` que nunca se identificó, y el emulador Java de
Firestore muriéndose ~1 de cada 6 corridas en Windows.

---

Antes de la tanda: 1180 / 426 / 197. Los diez rojos que aparecieron a mitad de camino eran
siembras de test sin el campo `abierto` — el defecto ensayado, no una regresión.

## 8. Runbook — lo que esta tanda añade y hereda

**El orden importa y no es negociable.**

1. `node backfill_entregado.js --apply` **antes** de desplegar la app web. Ahora con
   **cuatro** pasadas: la 4 escribe `abierto` a los tickets abiertos que no lo tienen. Sin
   ella, el tablero de todos los talleres aparece **vacío** — una igualdad sobre un campo
   ausente no devuelve nada.
2. `firebase deploy --only firestore:indexes` antes que la app. Esta corrida **retira seis
   índices de producción** (los cuatro del gap 9.4 más el `(id_taller, estado,
   fecha_actualizacion)` que sustituye el del tablero) y crea tres.
3. `firebase deploy --only firestore:rules` — la regla nueva exige coherencia de `abierto`;
   una app vieja que escriba `estado` sin él empezaría a recibir `permission-denied`. Va
   **después** del backfill y **junto** a la app, no antes.
4. Pendientes de antes: `SOLICITUDES_LANDING_SALT` y la política TTL de
   `solicitudes_landing_control`. Ya ejecutado el 2026-09-10:
   `firebase functions:delete iniciarReparacionPorVehiculo`.
