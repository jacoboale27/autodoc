# Tanda de drenaje 2 — los gaps que dejó el cierre de los residuales de FUNC-02

**Estado:** no empezada. Preparada el 2026-09-10 para arrancar el 2026-09-11.
**Rama:** `fix/gaps-02`, cortada de la punta de `integracion/ola-1` (`67046ce`). Nunca de una `fix/*`.
**Origen:** §9 de `docs/evidencia/GAPS-FUNC-02-cierre-de-residuales.md`.

Esto **no es una tarea del plan de remediación**. Es el drenaje de los gaps que dejó la
tanda anterior, y va **antes** de UX-03/UX-04 por decisión explícita del usuario el
2026-09-10: *un gap documentado no está cerrado*. Cuando esta tanda cierre, el orden §12
se retoma en UX-03/UX-04.

---

## 0. Antes de escribir una línea

- [ ] `git worktree add .claude/worktrees/gaps02 -b fix/gaps-02 integracion/ola-1`
- [ ] Sembrar dependencias — **un worktree nuevo no las trae y el fallo no lo dice**:
      `flutter pub get`, `functions/npm ci`, `test_rules/npm ci`, `e2e/npm ci`,
      `landing-web/pnpm install`.
- [ ] Comprobar que 8080, 9099, 9199, 4400 y 5555 están libres antes de cualquier suite.
- [ ] Leer el §9 de la evidencia anterior. Las anotaciones de esta tanda son **hipótesis**,
      no diagnósticos: en la tanda anterior **dos de los nueve estaban mal descritos, y en
      la dirección que esconde el peligro**. Verificar cada una contra el código antes de
      arreglarla es parte del trabajo, no un paso opcional.

---

## 1. Orden de la tanda

Tres lotes. El criterio no es la severidad: es **cuánto arrastra cada uno**. Los dos
primeros son cambios de consulta contenidos; el tercero toca reglas y los tres escritores
server-side, así que va con los dos gates de revisión y al final.

| Lote | Gaps | Por qué juntos |
|---|---|---|
| **A** | 9.2, 9.3 | Todos son streams sin tope. Mismo patrón, mismos repositorios, misma trampa. |
| **B** | 9.4 | Decisión sobre índices + relajar el centinela. Independiente de A. |
| **C** | 9.1 | Denormalizar `abierto`. Toca reglas, Functions y el backfill: lote propio. |

Fuera de la tanda a propósito: **9.5 y 9.6 van a OPS-01** (son trabajo de trigger/barrido
con Admin SDK, y ese es su sitio); **9.7 y 9.8** se quedan documentados (paginar el Kanban
es una feature de UI con su propia evidencia; el filtro redundante es limpieza, no
arreglo); **9.9** sigue sin dueño.

---

## 2. Lote A — los streams sin tope

### 2.1 Gap 9.2 · La bandeja de chat lee la colección entera

`chat_repository.dart:37-49`: `where(id_mecanico|id_propietario)` sin `orderBy` ni `limit`,
y un `list.sort(...)` por `ultimoMensajeTs` en el cliente. Un mecánico con 800
conversaciones paga 800 lecturas en cada apertura del chat y en cada reattach.

**La trampa, y hay que comprobarla ANTES de tocar la consulta:** poner el `orderBy` hace
que Firestore **excluya toda conversación sin `ultimo_mensaje_ts`** — desaparecerían de la
bandeja en silencio. Es exactamente el mismo fallo que el `whereIn` sobre `estado` de la
ronda 6 y que el `orderBy('fecha_actualizacion')` del tablero acaban de pagar, cada uno con
su pasada de backfill. **Primera pregunta, antes que ninguna otra: ¿puede crearse una
conversación sin ese campo?** Si sí, hay pasada de backfill y va al runbook.

**Y hay que reponer dos índices.** Los `conversaciones (id_propietario, ultimo_mensaje_ts DESC)`
y `(id_mecanico, ultimo_mensaje_ts DESC)` se retiraron por huérfanos en la tanda anterior:
estaban huérfanos **porque el orden se hacía en memoria**, o sea que este arreglo es justo
lo que vuelve a necesitarlos. Se retiraron a propósito, para no dejar índices declarados
«por si acaso» — que es como se llegó al `Servicios` con mayúscula.

Rojo primero: un test que siembre N+1 conversaciones y afirme que el stream entrega como
mucho el tope **y las más recientes**, más uno que afirme que una conversación sin
`ultimo_mensaje_ts` sigue apareciendo (si se decide tolerarla) o que el backfill la cubre.
Modelo a copiar: `test/features/mechanic/tablero_acotado_test.dart`.

**El centinela de índices no se actualiza solo:** al añadir el `orderBy` hay que meter la
consulta en el `_inventario` de `test/firestore_indices_test.dart` y subir
`_orderByEsperados`. Si no, el test se pone rojo — que es justo su trabajo.

### 2.2 Gap 9.3 · Dos streams más sin tope

- `reserva_repository.dart:17-25` — todas las reservas históricas del usuario. **El más
  barato de toda la tanda:** ya tiene `orderBy` e índice declarado; le falta el `limit` y
  el aviso de truncado. El widget ya existe: `aviso_tablero_truncado.dart`.
- `chat_repository.dart:55-63` — el hilo de mensajes entero. Aquí el tope tiene que ser
  **por el final** (los N más recientes) y, si se pagina, hacia atrás. Un hilo recortado
  por delante sin avisar es peor que uno lento.

---

## 3. Lote B — gap 9.4 · Los cuatro índices de solo igualdades

Firestore resuelve las consultas de **solo igualdades** por *index merging* sobre índices
de un campo: no necesitan compuesto. Son `conversaciones (id_propietario, id_mecanico)`,
`conversaciones (…, id_vehiculo)`, `cotizaciones (id_vehiculo, id_taller, estado)` y
`reparaciones (id_vehiculo, id_taller)` — **dos de ellos añadidos en la tanda anterior**.

Es una decisión, no un bug: conservarlos es defendible (el merge join rinde peor y es menos
predecible), pero cada índice se paga en **cada escritura** de la colección. Lo que no es
defendible es dejarlo sin decidir.

Si se retiran, hay que **relajar `_Indice.sirve`** en el centinela, que hoy trata «solo
igualdades» como si exigiera compuesto: es más estricto que Firestore, y con esa regla el
centinela exigiría reponer justo lo que se acaba de quitar.

Ojo con el orden de despliegue: retirar un índice es `firebase deploy --only
firestore:indexes` y **borra el índice de producción**. Si la decisión se toma, va al mismo
runbook que ya está pendiente.

---

## 4. Lote C — gap 9.1 · El tope del tablero acota documentos, no lecturas

`watchReparacionesActivas` es `whereIn` de 5 estados + `orderBy` + `limit(200)`. Firestore
ejecuta un `in` como **N subconsultas y aplica el límite a cada una** antes de fusionar:
hasta **1000 documentos leídos para devolver 200**, en cada `attach` del listener.

Sigue siendo estrictamente mejor que el stream sin techo de antes. Pero el tope no es el
que parece, y el riesgo real es creérselo.

**El cierre limpio:** denormalizar un booleano `abierto` en el ticket y consultar una
igualdad — `where('abierto','==',true).orderBy('fecha_actualizacion','desc').limit(200)` —
que lee exactamente 200. Es la misma máquina que `vinculo_activo`, ya construida y probada
en la tanda anterior, con **una diferencia que es todo el trabajo**: `vinculo_activo` lo
escriben solo los escritores server-side, pero **el estado del ticket lo transiciona
también el cliente**. Así que hay que decidir:

1. **Quién mantiene `abierto`.** Si lo escribe el cliente, las reglas tienen que atarlo al
   `estado` resultante — `request.resource.data`, no `resource.data`: mirar el documento
   VIEJO es el patrón exacto que destapó los cinco huecos de autorización de QA-01. Si lo
   escribe un trigger, el tablero va un tick por detrás de la acción del propio mecánico,
   y eso se nota.
2. **Los tres escritores server-side** (`onCotizacionAceptada`, `recibirVehiculoDelTicket`,
   el barrido de `onVehicleDelete`) tienen que escribirlo. Los vigila el centinela que
   cuenta accesos **por archivo** — cuidado, la escritura real vive en
   `src/vinculoTaller.js`, no en el cuerpo del `exports.`.
3. **Los tickets existentes no lo tienen**, y una igualdad sobre un campo ausente no
   devuelve nada: **pasada de backfill obligatoria antes de desplegar la app**, exactamente
   como la de `fecha_actualizacion` que ya está pendiente.

**Gates obligatorios de este lote:** `firestore-rules-reviewer` (toca `firestore.rules`) y
`functions-perf-reviewer` (toca `functions/` y `firestore.indexes.json`), los dos en
paralelo, después de implementar y antes de cerrar. Son gate, no opinión — y en la tanda
anterior el revisor encontró un punto ciego del propio centinela de índices.

---

## 5. Deuda de runbook que esta tanda hereda (y puede ampliar)

Nada de esto se ejecuta desde el repo, y **nada se ejecuta contra producción desde aquí**.

1. `node backfill_entregado.js --apply` — **antes** de desplegar la app web. No negociable:
   el tablero ordena por `fecha_actualizacion` y un `orderBy` excluye los documentos sin el
   campo. Su pasada 3 es además lo único que hace visibles al barrido de caducidad los
   vínculos rancios anteriores a este despliegue (gap 9.5).
2. `firebase deploy --only firestore:indexes` — antes que la app. Retira además
   permanentemente los cuatro índices huérfanos.
3. Ya ejecutado el 2026-09-10: `firebase functions:delete iniciarReparacionPorVehiculo`.
4. Pendientes de antes: definir `SOLICITUDES_LANDING_SALT` (sin ella la función se niega a
   arrancar, a propósito) y crear la política TTL de `solicitudes_landing_control`.

El lote A puede añadir una pasada por `ultimo_mensaje_ts`; el lote C añade seguro una por
`abierto`. Si se ejecutan varias, van **en la misma corrida** del backfill, no en tres.

---

## 6. Cómo se cierra la tanda

Lo mismo que la anterior, sin rebajas:

- **TDD real:** ver el test nuevo en rojo antes de implementar. No vale un rojo de
  compilación — tiene que fallar por la afirmación.
- **Afirmar lo que se escribió, no lo que se pintó.** Los tres falsos verdes de la tanda
  anterior salieron todos de afirmar sobre la capa equivocada.
- **Comprobar que el doble puede ver el defecto.** Dos dobles de la tanda anterior no
  podían: un `limit()` que era un no-op, y un `get()` que devolvía el documento vivo en vez
  de una copia inmutable.
- **Gates completos** antes de fusionar: `flutter analyze`, `flutter test` (salida entera a
  un archivo, **nunca por `tail`**), `functions`, `test_rules`, E2E de la app. La E2E de la
  landing solo si se toca `landing-web/` o `e2e/tests-landing/`.
- Evidencia en este mismo archivo, con su sección de gaps nuevos si los hay.
- Actualizar `CLAUDE.md`, `AGENTS.md` y la skill `ejecutar-plan-remediacion`.
