# FUNC-02 — Retirar caminos obsoletos de reparación

**Plan:** `docs/superpowers/plans/2026-09-06-remediation-master-plan-crea-j-10-10.md` §7 (P2).
**Rama:** `fix/func02`, cortada de `integracion/ola-1` (`ea30158`).
**Fecha:** 2026-09-10.
**Evidence IDs:** `EVID-FUNC-030..034`.

---

## 1. Inventario de consumidores: los cuatro métodos estaban muertos

Primer punto de la checklist del plan. Barrido de `lib/`, `test/`, `e2e/` y `functions/`:

| Método | Consumidores en `lib/` | Otros |
|---|---|---|
| `ReparacionProvider.iniciar` | **0** | solo la sobrecarga del doble de test |
| `ReparacionProvider.iniciarOReutilizar` | **0** | un test suyo propio |
| `ReparacionProvider.iniciarOReutilizarPorVehiculo` | **0** | solo el doble de test |
| `ReparacionProvider.recibirVehiculo` | **0** | solo el doble de test |
| `ReparacionRepository.iniciarReparacion` | solo los `iniciar*` de arriba | **19 tests, como siembra** |
| `ReparacionRepository.iniciarOReutilizarPorVehiculo` | solo el `iniciarOReutilizarPorVehiculo` de arriba | — |

El flujo real ya estaba entero sobre la otra API: `navegacion_vehiculo.dart:40`
(`buscarReparacionActiva`, que decide si se abre la pantalla) y cinco llamadas a
`recibirVehiculoPorId` en `initiate_service_screen.dart`,
`reparaciones_kanban_screen.dart` y `vehicle_search_screen.dart`.

Lo que sostenía vivo a `iniciarReparacion` no era la app: **eran sus tests**. Esa es la
forma exacta de dejar código muerto dentro del binario, y es lo que este trabajo corta.

## 2. Lo que el inventario destapó: el camino obsoleto seguía abierto en el servidor

El enunciado del plan habla de rutas `@Deprecated` del cliente. La parte que importaba
estaba debajo: el callable **`iniciarReparacionPorVehiculo`**.

Su único llamador era `ReparacionRepository.iniciarOReutilizarPorVehiculo`, que a su vez no
tenía ninguno — es decir, **código inalcanzable desde la app pero desplegado y invocable
por cualquier mecánico autenticado**. Lo que hacía, vía `crearOReutilizarTicketReparacion`:

- abría el ticket de `reparaciones` **directamente en `estado: 'recibido'`**, saltándose la
  recepción física entera, que es justo la transición que A3/B2 hizo explícita; y
- añadía el taller a **`vehiculos.talleres_vinculados`** en el mismo lote.

Su única compuerta era «existe una cotización en estado `'aceptada'` para este
vehículo+taller». **Una cotización se queda en `'aceptada'` para siempre**: no se cierra al
terminar la visita. Así que con una visita **ya entregada** —cuyo vínculo
`revocarVinculoAlCerrarTicket` acababa de revocar— la compuerta seguía satisfecha, y un
mecánico del taller podía reabrir un ticket, darlo por recibido y **recuperar el acceso a
la ficha del coche sin que el propietario interviniese**. Deshacía el modelo de
consentimiento taller-vehículo por la puerta de atrás.

`firestore.rules` no lo tapaba y no podía taparlo: `allow create: if false` sobre
`/reparaciones` **no alcanza a los callables**, que corren con Admin SDK.

### Reproducción (rojo, antes de tocar nada)

Ejecutando el helper real extraído de `functions/index.js` contra un Firestore en memoria
sembrado con un ticket `entregado` y el vehículo sin vínculos:

```
resultado: { idReparacion: 'NUEVO', creado: true, placa: 'ABC123', propietarioId: 'owner' }
escrituras:
  set reparaciones/NUEVO  -> { ..., "estado": "recibido",
                               "historial_estados": [{ "estado": "recibido", ... }] }
  update vehiculos/v1     -> { "talleres_vinculados": { "arrayUnion": "t1" } }

*** BYPASS: abrio el ticket directamente en "recibido", saltandose la recepcion fisica
```

## 3. Cambios

| Archivo | Qué |
|---|---|
| `functions/index.js` | Fuera `exports.iniciarReparacionPorVehiculo` y `crearOReutilizarTicketReparacion` |
| `functions/src/iniciarReparacionPorVehiculo.js` | **Borrado** (y su test) |
| `lib/.../reparacion_provider.dart` | Fuera `iniciar`, `iniciarOReutilizar`, `iniciarOReutilizarPorVehiculo`, `recibirVehiculo` |
| `lib/.../reparacion_repository.dart` | Fuera `iniciarReparacion` y `iniciarOReutilizarPorVehiculo` |
| `firestore.rules` | Solo comentarios: el bloque de `/reparaciones` decía que el hueco del callable existía; ahora dice quién escribe y que la regla no protege a nadie que use Admin SDK |
| `test/support/sembrar_reparacion.dart` | **Nuevo**: la siembra que sostenía a `iniciarReparacion`, mudada a donde no compila dentro de la app |
| `test/support/fake_functions.dart` | **Nuevo**: doble de `FirebaseFunctions` que afirma *qué* callable se llamó y con qué |
| `test/features/mechanic/flujo_apertura_unica_test.dart` | **Nuevo**: regresión del único flujo oficial (5 casos) |
| `functions/test/apertura_unica_ticket.test.js` | **Nuevo**: centinela de que no reaparezca una segunda puerta (4 casos) |
| `test/support/mechanic_harness.dart` | Retirado el contador `llamadasIniciar`, que ya no podía subir |

## 4. Resultados

| Gate | Antes | Después |
|---|---|---|
| `flutter analyze` | limpio | **`No issues found!`** |
| `flutter test` | 1164 | **1167 / 1167**, exit 0 |
| `test_rules` (`npm test`) | 426 en 24 suites | **426 / 426**, 24 suites, exit 0 |
| `functions` (Mocha) | 173 | **170**, exit 0 |
| Puertos al salir | — | 0 en `LISTENING` |

Los 170 de Functions son 173 − 7 (el archivo de test del módulo borrado) + 4 (el centinela
nuevo). Que la cifra **baje** es parte del resultado: se retiró código y su cobertura.

**Rojo comprobado antes del verde**, contra `integracion/ola-1`:

| Afirmación | Antes |
|---|---|
| no existe el callable de apertura manual | `true` (existía) |
| no existe el helper `crearOReutilizarTicketReparacion` | `true` (existía) |
| ningún ticket nace en `'recibido'` | `true` (nacía) |
| `index.js` toca `/reparaciones` en 3 puntos | eran **5** |

Y el bypass del §2 se reprodujo con salida real antes de borrar nada.

## 5. Nota sobre la calidad de los tests

Dos correcciones que merecen constar, porque las dos son la enfermedad que este repo ya
tiene documentada — un test que pasa por el motivo equivocado:

1. **El centinela pasaba por casualidad.** La primera versión buscaba
   `collection('reparaciones')` **dentro del cuerpo de cada `exports.`**. Pero la escritura
   de `recibirVehiculoDelTicket` no está en `index.js`: está en `src/vinculoTaller.js:124`.
   El test pasaba solo porque el callable además *lee* el ticket inline para autorizar. Un
   callable nuevo que delegara en un helper de `src/` —el patrón de todo el módulo— no se
   habría visto. Ahora cuenta los accesos **por archivo** y exige el mapa exacto conocido;
   es un tripwire, y se declara como tal en el propio test.
2. **Un contador que ya no podía subir.** `mechanic_harness.dart` tenía
   `llamadasIniciar`, y dos tests afirmaban que valía `0`. Con los métodos borrados no hay
   forma de incrementarlo: la afirmación había dejado de discriminar nada. Se retiró, y en
   su lugar el test de «sin cotización aceptada» afirma ahora `llamadasRecibir == 1` — que
   el intento **sí** se hizo y el rechazo vino del servidor, no de una pantalla que no
   llamara a nada y pintara el error por su cuenta.

## 6. Runbook — **el borrado del código NO retira el endpoint desplegado**

Mientras `iniciarReparacionPorVehiculo` siga existiendo en el proyecto de Firebase, sigue
siendo invocable y el replay del §2 sigue disponible en producción. Un
`firebase deploy --only functions:<otra>` **no lo purga**. Hace falta, explícitamente:

```
firebase functions:delete iniciarReparacionPorVehiculo
```

o un deploy completo de funciones, que pregunta por las eliminadas. Va en el mismo cajón
que `SOLICITUDES_LANDING_SALT` y la política TTL de UX-01: sin este paso, la tarea está
cerrada en el repositorio y abierta en producción.

---

## 7. Gaps que se dejan ABIERTOS, con su razón

Ninguno de estos se toca aquí: o cambian comportamiento con riesgo de regresión propio, o
son de otro workstream. Todos están verificados a mano, no solo reportados.

### 7.1 La compuerta de la pantalla excluye `cancelado` pero no `entregado` (BAJO, UX)

`ReparacionProvider.buscarReparacionActiva` rechaza un ticket `cancelado` y **nada más**,
mientras que `estadosReparacionCerrados` incluye `cancelado` **y** `entregado`. La
compuerta y la definición de «cerrado» del repositorio no coinciden, así que un ticket ya
entregado sigue abriendo la pantalla de servicio completa.

**Verificado que NO es explotable**, y falla por el lado correcto: con el ticket entregado
el vínculo ya fue revocado, `firestore.rules:551` deniega la lectura del vehículo,
`initiate_service_screen.dart:227-231` solo trata como recuperable el caso
`pendiente_recepcion`, y sin `_vehiculo` el formulario no se construye. Además
`firestore.rules:1523` hace inmutable un ticket cerrado y `vinculoTaller.js:137-147`
rechaza recibir un `entregado`.

El defecto real es un **callejón sin salida**: el mecánico toca un coche que atendió y
aterriza en un error genérico. Es exactamente la clase de fallo de **UX-02**, y el arreglo
es de una línea (`estadosReparacionCerrados.contains(...)` en vez de `== 'cancelado'`),
pero toca la lista de Mis Servicios y los tickets legados anteriores a A4b, así que merece
su propia evidencia. **Fijado con un test que declara el comportamiento actual y avisa a
quien lo cambie** (`flujo_apertura_unica_test.dart`, caso «asimetria conocida»).

### 7.2 El vínculo no caduca mientras el ticket siga abierto (MEDIO, diseño) → OPS-01

El vínculo sigue a la posesión del coche, pero **nadie caduca la posesión**. Un taller que
simplemente nunca mueva el ticket a `entregado` conserva `talleres_vinculados` —y con él la
ficha, la galería, las alertas y el historial— indefinidamente, y
`recibirTicketYVincular` se lo **reafirma** en cada llamada mientras el ticket siga abierto
(`vinculoTaller.js:158-183`). El cierre depende por completo de la buena voluntad del
taller. Candidato natural a **OPS-01**, junto al trigger `onDelete` de fotos que FUNC-01
dejó anotado.

### 7.3 El dedup de tickets puede fallar por volumen (MEDIO, corrección) → FUNC/DATA

`existeTicketAbiertoParaVehiculo` (`functions/src/aceptarCotizacion.js:247-256`) trae hasta
20 documentos **sin filtro de estado y sin `orderBy`** (el orden es por ID) y filtra en
memoria. Un cliente recurrente con más de 20 tickets cerrados en el mismo taller puede
tener su ticket **abierto fuera de esos 20**: el dedup no lo ve y se abre un segundo ticket
paralelo — el «Hallazgo 2» reapareciendo por la puerta de atrás, solo que con volumen.

Arreglo concreto: mover el filtro a la consulta con
`where('estado','not-in',ESTADOS_TICKET_CERRADO).limit(1)` e índice nuevo
`reparaciones (id_vehiculo ASC, id_taller ASC, estado ASC)` — `not-in` cuenta como
desigualdad y obliga a que `estado` sea el último campo, lo cual encaja. Pasa de leer 20
documentos a leer 1 **y** cierra la ventana. No se hace aquí porque añade un índice y
cambia el creador oficial de tickets, que es lo único que esta tarea no debe desestabilizar.

### 7.4 Consulta compuesta sin índice declarado, que falla en silencio (MEDIO) → OPS-01

`initiate_service_screen.dart:269-275` consulta `cotizaciones` con
`where(id_vehiculo) + where(estado) + orderBy(fecha DESC) + limit(1)`. El único índice de
`cotizaciones` en `firestore.indexes.json` es `(id_vehiculo, id_taller, estado)`, que **no
sirve un `orderBy fecha`**. En producción eso es `failed-precondition` salvo que exista un
índice creado a mano en la consola y sin versionar. Y la consulta está en un `.then(...)`
**sin `catchError`**: el fallo es mudo, `_hasApprovedQuote` se queda en `false` y la
pantalla dice «no hay cotización aceptada» — un mensaje que manda a buscar el problema
donde no está. Verificado leyendo el índice y la consulta.

### 7.5 Índice muerto, con el nombre mal capitalizado (BAJO) → OPS-01

`firestore.indexes.json:88` declara `Servicios` con **S mayúscula** (`id_vehiculo`,
`fecha DESC`). No hay ni una consulta sobre `Servicios` en `lib/` ni en `functions/`: la
colección real es `servicios`. Verificado con barrido. Es un índice pagando coste de
escritura que nadie lee nunca. Borrable, pero borrar índices es una operación de despliegue
y va con el resto del runbook.

### 7.6 Stream del Kanban sin tope (BAJO) → OPS-01

`reparacion_repository.dart:237-241` (`watchReparacionesActivas`) hace
`where(id_taller) + whereIn(estado)` **sin `limit`** sobre una colección que crece un
ticket por visita. Un taller con muchos tickets activos paga el conjunto entero en cada
attach del listener. Sugerido: `orderBy('fecha_actualizacion','desc').limit(N)` con
paginación, e índice `reparaciones (id_taller, estado, fecha_actualizacion DESC)`.

### 7.7 Doble lectura y carrera en la recepción (BAJO) → OPS-01

`recibirVehiculoDelTicket` lee `reparaciones/{id}` en `index.js:859` para autorizar con
`actuaPorTaller`, y `recibirTicketYVincular` **lo vuelve a leer** en `vinculoTaller.js:124`.
Además del read de más, abre una ventana TOCTOU: entre las dos lecturas el `id_taller` o el
`estado` pueden cambiar y se autoriza sobre el snapshot viejo. Y el `batch` de
`vinculoTaller.js:157-192` no es condicional respecto de la lectura que decidió su
contenido, así que dos «Recibir» concurrentes pueden ambos leer `pendiente_recepcion` y
escribir **dos** entradas `recibido` en `historial_estados` (el array se reconstruye en
memoria, no con `arrayUnion`). Lo correcto es una `runTransaction`. El batching en sí —
ticket y vínculo en una sola escritura atómica — está bien hecho y es el punto del diseño.

### 7.8 Lecturas redundantes en la apertura del ticket (BAJO, coste) → OPS-01

- `abrirTicketDeReparacion` ya tiene el ticket en memoria (`aceptarCotizacion.js:381-393`)
  pero devuelve solo el id, y `notificarTicketAbierto` **relee el documento recién escrito**
  (`index.js:792`). El `if (!snap.exists) return` no aporta: acaba de crearse.
- Dos triggers `onUpdate` sobre `cotizaciones/{id}` se despiertan con el mismo evento y
  releen el mismo `usuarios/{id_taller}` **tres veces** en total; dos de ellas en serie y
  sin necesidad (`sincronizarReservaAlCotizar.js:58-59`, que admite `Promise.all`).

### 7.9 La revocación del vínculo se traga sus errores (BAJO, consistencia)

`revocarVinculoAlCerrarTicket` (`index.js:915-925`) captura y registra sin relanzar. Si la
revocación falla, el vínculo sobrevive al `entregado`: la pantalla carga entera y el
mecánico puede registrar un `servicios`. **No es escalación de privilegios** —
`tallerConoceElVehiculo` (`firestore.rules:145-149`) se lo permite igualmente vía
`talleres_conocidos`, que es append-only por diseño— pero el `cambiarEstado` posterior sí
sería denegado por `firestore.rules:1523`, dejando un servicio registrado sin transición de
ticket. Inconsistencia de datos, no de permisos.

### 7.10 Sin cobertura E2E nueva

FUNC-02 solo retira código; el flujo que queda ya estaba cubierto por las suites de
Playwright existentes, que no se relanzaron porque nada de lo que tocan cambió. Las cifras
de E2E que se arrastran en `CLAUDE.md` son las verificadas el 2026-09-09.
