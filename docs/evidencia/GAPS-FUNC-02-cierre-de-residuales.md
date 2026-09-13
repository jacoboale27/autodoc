# Cierre de los residuales de FUNC-02

FUNC-02 cerró su tarea y dejó nueve gaps documentados en el §7 de
`FUNC-02-apertura-unica-de-tickets.md`. Esta rama (`fix/gaps-func02`, cortada de
`integracion/ola-1` en `8a188cc`) los drena.

**Los nueve están cerrados.** Dos resultaron ser peores de lo que decía la
anotación, y cerrarlos destapó seis defectos más de la misma familia que nadie
había mirado.

---

## 1. Estado de los nueve

| # | Gap | Cerrado con | Nota |
|---|---|---|---|
| 7.1 | La compuerta excluía `cancelado` pero no `entregado` | `estadosReparacionCerrados` en `ReparacionProvider.buscarReparacionActiva` | La anotación decía que tocaba "Mis Servicios". No lo toca: ver §3.1 |
| 7.2 | El vínculo no caduca mientras el ticket siga abierto | Función programada `caducarVinculosDeTalleresInactivos` | Decisión de producto del usuario: caduca el **acceso**, no el ticket |
| 7.3 | El dedup de tickets falla por volumen | Consulta en dos tramos (`estado not-in` + barrido de legados) | El arreglo obvio (`not-in` a secas) era una regresión: ver §2.3 |
| 7.4 | Consulta compuesta sin índice, que falla en silencio | Índice + tercer estado en la pantalla + guard en Finalizar | **Peor de lo anotado**: ver §2.1 |
| 7.5 | Índice muerto con el nombre mal capitalizado | Renombrado, no borrado | **No estaba muerto**: ver §2.2 |
| 7.6 | Stream del Kanban sin tope | `orderBy` + `limit` + aviso visible + pasada de backfill | El tope sin orden ni aviso habría sido peor que el gap |
| 7.7 | Doble lectura y carrera en la recepción | `runTransaction` + autorización inyectada | |
| 7.8 | Lecturas redundantes en la apertura del ticket | El ticket se devuelve en vez de releerse; resolución de taller en paralelo y con atajo | |
| 7.9 | La revocación del vínculo se traga sus errores | Marca en el ticket + reintento en la siguiente escritura | |
| 7.10 | Sin cobertura E2E nueva | Suite de la app relanzada: 32 pasan | La de la landing no aplica: no se toca |

---

## 2. Los que no eran lo que decían

### 2.1 El 7.4 no era un mensaje equivocado: era escribir datos distintos de los aprobados

La anotación decía que un `failed-precondition` mudo dejaba a la pantalla
diciendo «no hay cotización aceptada». Al abrir el código, la consecuencia real
es otra: `_hasApprovedQuote` en `false` no cambia un texto, **cambia la mitad
derecha de la pantalla**. Con cotización aprobada se pinta un banner con el
importe; sin ella, el formulario manual de materiales y mano de obra.

Así que un fallo de infraestructura hacía que el mecánico volviera a teclear a
mano el importe que el cliente ya había aceptado, y es ese importe tecleado el
que se guarda en `servicios` (`initiate_service_screen.dart`, rama
`!_hasApprovedQuote` de `_finalizarServicio`). La cotización, además, se quedaba
sin marcar como usada. Datos divergentes de los que el cliente aprobó, sin un
solo mensaje de error.

Cerrado en tres piezas, porque una sola no bastaba:

1. El índice `cotizaciones (id_vehiculo, estado, fecha DESC)`, que no existía.
2. Un **tercer estado** en la pantalla, `_errorCotizacion`: ni "hay" ni "no
   hay", sino "no se pudo saber", con su mensaje y un botón de reintento.
3. Un guard en `_handleFinalizeService`. Ocultar el formulario no basta: el
   botón de finalizar vive fuera de ese bloque y sigue en pantalla, y la
   validación de materiales tampoco lo detiene — sin `Form` montado,
   `_materialesFormKey.currentState` es `null` y el guard existente resuelve a
   `true`. Se habría guardado un `servicios` a cero.

### 2.2 El 7.5 no era un índice muerto: era el índice vivo mal escrito

`firestore.indexes.json` declaraba `Servicios` con **S mayúscula**. La anotación
lo dio por un índice huérfano pagando coste de escritura. Al cruzarlo con las
consultas reales resultó lo contrario: Firestore distingue mayúsculas en el
nombre de la colección, la colección real es `servicios`, y **dos consultas
vivas necesitaban exactamente ese índice** y no lo tenían:

- `vehicle_service.dart:300` — la tarjeta de "último taller visitado".
- `service_history_provider.dart:43` — el historial de servicios del vehículo,
  paginado.

No era coste de más: era el historial de servicios del propietario muriendo con
`failed-precondition` en producción. Se corrige el nombre.

### 2.3 El arreglo obvio del 7.3 era una regresión

El gap proponía `where('estado','not-in',ESTADOS_TICKET_CERRADO).limit(1)`, que
cierra la ventana por volumen y pasa de 20 lecturas a 1. Al escribir el test
apareció el otro lado: **Firestore indexa por campo, y un documento sin `estado`
no aparece en ninguna consulta que filtre por `estado`** — tampoco en un
`not-in`, por contraintuitivo que suene ("no está en la lista" no incluye "no
existe").

Los tickets anteriores a A4b no traen el campo y nacían en `recibido`, o sea
ABIERTOS. Con el `not-in` a secas pasaban de contar a ser invisibles, y el dedup
habría abierto tickets duplicados justo sobre los datos más viejos del sistema.
Cambiar un fallo por volumen por otro con los datos legados no es arreglarlo.

Queda en dos tramos: el `not-in` con `limit(1)` responde el caso normal en una
lectura, y solo si viene vacío corre el barrido acotado de antes, ya únicamente
para detectar tickets sin `estado`. Coste: 1 lectura cuando hay ticket abierto
(el caso que aborta la apertura) y 1 + N cuando no lo hay, contra las N de
siempre.

---

## 3. Lo que apareció al cerrarlos

### 3.1 La anotación del 7.1 era incorrecta sobre el alcance

Decía que estrechar la compuerta «toca la lista de Mis Servicios y los tickets
legados anteriores a A4b». No toca ninguna de las dos:

- **Mis Servicios** se pinta desde `watchReparacionesActivas`, cuyo `whereIn`
  sobre `estadosReparacion` ya dejaba fuera `entregado` y `cancelado`. Un ticket
  entregado nunca llegó a esa lista.
- **Los tickets legados** llegan sin `estado`, y `estadosReparacionCerrados` no
  contiene la cadena vacía: siguen contando como abiertos.

El único camino que alcanzaba un ticket `entregado` era
`abrirVehiculoComoMecanico` desde "Buscar vehículo" o el chat, y ahí el arreglo
es estrictamente una mejora: en vez de un error genérico, la ficha pública, que
es donde el mecánico puede pedir una cotización nueva.

### 3.2 Seis consultas más sin índice, y cuatro índices huérfanos

Cerrar el 7.4 y el 7.5 obligó a mirar `firestore.indexes.json` entero. El cruce
completo destapó, además de los dos ya citados:

| Consulta | Estado |
|---|---|
| `reservas (id_mecanico, fecha_hora_propuesta DESC)` | Faltaba. Es el `Stream` que alimenta la pantalla de reservas |
| `reservas (id_propietario, fecha_hora_propuesta DESC)` | Faltaba. Mismo `where`, campo elegido según el rol: son dos índices |
| `conversaciones (id_propietario, id_mecanico, id_vehiculo)` | Faltaba. `buscarConversacion` añade el tercer `where` cuando `ChatProvider` le pasa vehículo |
| `reparaciones (id_vehiculo, id_taller, estado)` | Nuevo, para el dedup del §2.3 |

Y cuatro índices declarados sin ninguna consulta que los use, verificados uno a
uno antes de retirarlos: `conversaciones` ×2 con `ultimo_mensaje_ts` (la bandeja
ordena **en memoria**, `chat_repository.dart:49`), `mensajes (id_remitente,
timestamp)` (sus dos consultas son una igualdad sola y una desigualdad sola) e
`historial_mantenimientos (id_taller, fecha)` (solo hay escrituras y un borrado
por `id_vehiculo`).

**Esto no puede volver a pasar en silencio.** El emulador de Firestore sirve
cualquier consulta sin mirar `firestore.indexes.json`, así que ni `flutter
test`, ni `test_rules/`, ni Playwright detectan una consulta sin índice: solo un
usuario real en producción. `test/firestore_indices_test.dart` mantiene el
inventario y comprueba tres cosas — cada consulta tiene índice, cada índice
tiene consulta, y el número de `.orderBy(` en `lib/` es el esperado. Ese tercer
test es el disparador: quien añada una consulta ordenada rompe el test y tiene
que declararla, que es justo el momento de preguntarse si necesita índice.

### 3.3 Todos los tests de `InitiateServiceScreen` corrían contra un Firestore roto

La pantalla usaba `FirebaseFirestore.instance` en sus cuatro consultas, y su
propio test lo documentaba como «no inyectable». Al inyectarlo, trece tests se
pusieron rojos de golpe: llevaban corriendo contra un `instance` sin Firebase
real, donde la consulta de la cotización **siempre fallaba**, y nadie lo sabía
porque el `.then` sin `catchError` se lo tragaba. El mismo defecto del 7.4,
manifestándose en la suite.

Ahora los seis puntos de montaje pasan un `FakeFirebaseFirestore` y la consulta
tiene cobertura real por primera vez.

### 3.4 Dos dobles de prueba que no podían ver el defecto que cubrían

- El doble de `aceptar_cotizacion.test.js` tenía `limit()` como **no-op** y no
  ordenaba: ningún test podía distinguir "el dedup mira todos los tickets" de
  "mira los primeros 20". El fallo por volumen era invisible por construcción.
- El doble de `vinculo_taller.test.js` devolvía el documento **vivo** desde
  `get()`, no una copia. Un snapshot de Firestore es inmutable; con el doble
  vivo, una escritura posterior se veía retroactivamente en un snapshot ya
  leído, y con eso ningún test podía distinguir "leí antes" de "leí después" —
  que es exactamente la carrera del 7.7. El primer test de esa carrera dio
  **falso verde** hasta arreglarlo.

Ambos dobles modelan ahora esas propiedades, y las cuatro afirmaciones nuevas se
vieron fallar antes de implementar.

---

## 4. Rojo antes, verde después

| Prueba | Rojo verificado | Contra |
|---|---|---|
| `flujo_apertura_unica_test.dart` · «entregada NO vuelve a abrir» | `Expected: null / Actual: 'Wfy1…'` | Compuerta con solo `cancelado` |
| `aceptar_cotizacion.test.js` · «VOLUMEN» | El dedup no ve el ticket abierto | `limit(20)` sin filtro |
| `aceptar_cotizacion.test.js` · «legado SIN estado» | Devolvía `false` con `not-in` a secas | Prueba de que el segundo tramo hace falta |
| `firestore_indices_test.dart` | 6 consultas sin índice, 6 índices sin consulta | `firestore.indexes.json` |
| `initiate_service_cotizacion_test.dart` ×3 | Formulario manual pintado; sin mensaje; sin reintento | `.then` sin `catchError` |
| ídem · «Finalizar se niega» | Sin el mensaje de rechazo — **y en su primera versión daba falso verde**, ver §5 | Sin guard |
| `vinculo_taller.test.js` · «no pierde una entrada de historial» | `['pendiente_recepcion','recibido']`, falta `en_revision` | `batch` en vez de transacción |
| `vinculo_taller.test.js` · autorización ×2 | La función no aceptaba `autorizar` | Doble lectura |
| `vinculo_taller.test.js` · revocación ×4 | Sin marca, sin reintento | `catch` que solo registraba |
| `vinculo_taller.test.js` · `vinculo_activo` ×3 | El campo no se escribía | Sin él no hay barrido posible |
| `sincronizar_reserva_al_cotizar.test.js` ×2 | 2 lecturas donde debía haber 0 | Resolución en serie sin atajo |
| `tablero_acotado_test.dart` ×3 | `maxTicketsTablero` y `tableroTruncado` no existían | Stream sin tope |
| `vehicle_search_mis_servicios_test.dart` ×2 | El aviso no se pintaba | Recorte silencioso |
| `caducar_vinculos.test.js` ×5 | El módulo no existía | Gap 7.2 |

Además, **el centinela de FUNC-02 disparó tres veces** y las tres eran ciertas:
la lectura que desapareció de `index.js` (7.7), la que se añadió en
`aceptarCotizacion.js` (7.3) y el archivo nuevo `caducarVinculos.js` (7.2). Cada
cambio del mapa va con su razón escrita al lado.

---

## 5. Una corrección de calidad de test que merece quedar escrita

El test «con la consulta rota, Finalizar se niega a guardar» **pasó en verde sin
el arreglo**. Afirmaba `find.textContaining('No se pudo comprobar')`, y ese
texto ya estaba en pantalla: es el banner de error. La aserción se cumplía igual
antes y después.

Reescrito para mirar **lo escrito y no lo pintado** (`servicios` vacío) más un
texto que solo existe en el rechazo. Y hubo un segundo fallo encadenado: el tap
sobre `FINALIZAR SERVICIO` caía fuera del viewport, así que `onPressed` no se
ejecutaba y el test habría "pasado" sin pulsar nada — hace falta
`ensureVisible` primero. Con las dos cosas corregidas se verificó el rojo
retirando el guard, y el verde al reponerlo.

---

## 6. Resultado de los gates

| Gate | Antes | Después |
|---|---|---|
| `flutter analyze` | limpio | `No issues found!` |
| `flutter test` | 1167 | **1180 / 1180** |
| `functions` (Mocha) | 170 | **197 passing** |
| `test_rules` (Jest + emuladores) | 426 | **426 / 426**, 24 suites |
| E2E de la app (Playwright) | 32 + 2 `fixme` | **32 pasan, 2 skipped**, exit 0 |
| Puertos al salir | — | 0 en `LISTENING` |

`firestore.rules` **no se ha tocado** en esta rama: el diff no incluye el
archivo. La suite de reglas se relanza igualmente como regresión, porque el
comportamiento alrededor de `/reparaciones` sí cambió.

**La E2E de la landing no se relanza y es deliberado**: esta rama no toca
`landing-web/` ni `e2e/tests-landing/`. Sus 20 casos siguen siendo los
verificados el 2026-09-09.

`functions` sube de 170 a 197: +11 pruebas nuevas de comportamiento y el resto
de los dobles que hubo que enseñar a fallar (§3.4).

---

## 7. Runbook — lo que no se puede hacer desde el repo

1. **`node backfill_entregado.js --apply` antes de desplegar la app web.** Ya
   era obligatorio por el `whereIn` sobre `estado` de la ronda 6; ahora también
   por el `orderBy('fecha_actualizacion')` del tablero, que excluye igual los
   documentos sin el campo. Sin él, los tickets anteriores a A4b desaparecen del
   Kanban en silencio.
2. **`firebase deploy --only firestore:indexes`.** Los siete índices nuevos
   tardan en construirse; despliégalos **antes** que la app, o las consultas que
   los necesitan fallan durante la ventana.
3. Ese mismo despliegue **borra** los cuatro índices huérfanos retirados. Es la
   parte irreversible del paso 2: si algún día se vuelve a necesitar uno, hay
   que reconstruirlo, y en una colección grande eso tarda.

---

## 8. El gate de revisión, y lo que corrigió

`functions-perf-reviewer` es gate obligatorio para cualquier cambio en
`functions/index.js` o `firestore.indexes.json`. Corrió sobre esta rama y
encontró cinco cosas ciertas. Tres de sus bloqueantes leían un estado
intermedio del árbol y ya no aplicaban al terminar; las otras dos eran de
fondo, y una apunta a mi propio trabajo:

1. **El centinela de índices era ciego al servidor.** Su disparador contaba
   `.orderBy(` **solo en `lib/`**, así que una consulta compuesta nueva en
   Cloud Functions no lo despertaba — y eso es exactamente lo que pasó: el
   barrido de caducidad nació con una igualdad más una desigualdad y sin índice
   declarado, y el centinela lo dejó pasar. Un centinela con un punto ciego en
   la mitad del sistema que vigila es peor que no tenerlo, porque da confianza.
   Añadido un cuarto test que cuenta los `.where(` de `functions/index.js` y
   `functions/src/`.
2. **El tramo 2 del dedup vendía más de lo que da.** Sigue siendo `limit(20)`
   sin `orderBy`, así que arrastra intacta la misma ventana por `__name__` que
   el tramo 1 elimina: un par vehículo+taller con más de 20 tickets cuyo legado
   ordene después sigue siendo invisible. No hay forma de arreglarlo —Firestore
   no consulta «campo ausente»—, y el cierre real es el backfill, que ya es
   prerrequisito duro. El comentario decía «fallback» como si cubriera el caso;
   ahora dice qué cubre y qué no, y cuándo se puede retirar.
3. **El barrido hacía hasta 400 escrituras en serie.** Dos por ticket, hasta
   200 tickets. Va por tandas de 20; ni de una en una ni las 400 a la vez, que
   agotaría el pool de conexiones.
4. **`actuaPorTaller` se releía en cada reintento de la transacción.** Hasta 5
   lecturas de `usuarios/{uid}` y otros tantos viajes de red **dentro** de la
   ventana de bloqueo sobre el ticket y el vehículo. Se cachea la promesa por
   invocación, conservando el cortocircuito (un taller que actúa por sí mismo
   no lee nada).
5. **Dos escrituras de más que ya se habían corregido** antes de que el
   revisor terminara: la marca `vinculo_activo: false` incondicional al cerrar,
   y las expectativas de test desfasadas.

---

## 9. Lo que queda abierto

Los nueve residuales de FUNC-02 están cerrados. Lo que sigue son gaps
**nuevos**, la mayoría destapados por el gate de revisión al mirar alrededor.

### 9.1 El tope del tablero acota documentos, no lecturas (MEDIO)

`watchReparacionesActivas` es `whereIn` de 5 estados + `orderBy` + `limit(200)`.
Firestore ejecuta un `in` como N subconsultas y **aplica el límite a cada una**
antes de fusionar: hasta **1000 documentos leídos** para devolver 200, en cada
`attach` del listener.

Sigue siendo estrictamente mejor que el stream sin tope de antes —que no tenía
techo ninguno— pero el tope no es el que parece, y conviene no creérselo. El
cierre limpio es denormalizar un booleano `abierto` en el ticket (lo escribirían
los mismos tres escritores server-side) y consultar una igualdad:
`where('abierto','==',true).orderBy('fecha_actualizacion','desc').limit(200)`,
que lee exactamente 200. Es la misma máquina que `vinculo_activo`, con la
diferencia de que el cliente también transiciona estados, así que habría que
decidir quién mantiene el campo y cómo lo protegen las reglas. No cabe aquí.

### 9.2 La bandeja de chat lee la colección entera y ordena en memoria (MEDIO)

`chat_repository.dart:37-49`: `where(id_mecanico|id_propietario)` sin `orderBy`
ni `limit`, y `list.sort(...)` por `ultimoMensajeTs` en el cliente. Un mecánico
con 800 conversaciones paga 800 lecturas en cada apertura del chat y en cada
reattach.

**Y esta rama lo consolida sin quererlo.** Los dos índices `conversaciones
(id_*, ultimo_mensaje_ts DESC)` que se retiran por huérfanos eran precisamente
los que servirían la versión correcta de esta consulta. Estaban huérfanos
porque el orden se hace en memoria, así que el borrado es coherente con el
código de hoy — pero el arreglo (poner el `orderBy` y un `limit`, quitar el
`sort`) tendría que reponerlos. Se retiran igualmente para no dejar índices
declarados «por si acaso», que es como se llegó al `Servicios` con mayúscula.

Antes de hacerlo hay que comprobar una cosa: si alguna conversación se crea sin
`ultimo_mensaje_ts`, el `orderBy` la haría desaparecer de la bandeja en
silencio — la misma trampa que el tablero acaba de pagar con una pasada de
backfill.

### 9.3 Dos streams más sin tope (BAJO)

`reserva_repository.dart:17-25` (todas las reservas históricas del usuario) y
`chat_repository.dart:55-63` (el hilo de mensajes entero). El de reservas es el
más barato de cerrar: ya tiene `orderBy` e índice declarado, solo le falta el
`limit` y el mismo aviso de truncado que se acaba de construir para el tablero.

### 9.4 Cuatro índices de solo igualdades podrían no hacer falta (BAJO)

Firestore resuelve las consultas de **solo igualdades** por *index merging*
sobre los índices de un campo, sin necesitar compuesto: es el caso de
`conversaciones (id_propietario, id_mecanico)`, `conversaciones (…, id_vehiculo)`,
`cotizaciones (id_vehiculo, id_taller, estado)` y `reparaciones (id_vehiculo,
id_taller)` — dos de ellos **añadidos** en esta rama. Conservarlos es
defendible (el merge join rinde peor y es menos predecible) pero cada uno se
paga en cada escritura. Si se decide retirarlos, hay que relajar también
`_Indice.sirve` en el centinela, que hoy trata «solo igualdades» como si
exigiera compuesto — es más estricto que Firestore.

### 9.5 El barrido de caducidad no ve los tickets anteriores a este cambio

`caducarVinculosInactivos` consulta por `vinculo_activo`, y ese campo lo
escriben los dos extremos a partir de ahora. Los tickets con vínculo vivo
abiertos **antes** de este despliegue no lo tienen y el barrido no los ve.

No es un hueco nuevo: son exactamente la población de vínculos rancios que
limpia la pasada 3 de `backfill_entregado.js`, en el mismo runbook. Si esa
pasada no corriera, esos vínculos no caducarían nunca.

### 9.6 La marca `vinculo_revocacion_pendiente` es frágil y nadie la consume

Se autorrepara con la siguiente escritura sobre el ticket, y esa escritura
puede no llegar nunca en un ticket ya cerrado. Además, si el cliente reescribe
el ticket con un modelo que no conoce el campo, la marca desaparece en silencio
y el vínculo colgado deja de ser consultable. Convierte un fallo invisible en
uno consultable, que era el objetivo; cerrarlo del todo es que el barrido de
caducidad la recoja. Encaja en OPS-01.

### 9.7 El tope del tablero no está paginado

Al llegar a `maxTicketsTablero` el aviso dice que faltan y qué hacer (cerrar los
que ya terminaron), pero no hay forma de ver los que quedan fuera. Con 200
tickets ABIERTOS simultáneos es un caso que no debería darse; si se diera,
paginar el Kanban es trabajo de UI con su propia evidencia.

### 9.8 `_MisServicios` filtra `cancelado` en memoria de forma ya redundante

El stream nunca puede entregar un `cancelado` (su `whereIn` no lo incluye), así
que `.where((r) => r.estado != 'cancelado')` es un cinturón sobre un tirante.
Se conserva a propósito y documentado; retirarlo es limpieza, no arreglo.

### 9.9 Sigue sin dueño lo de siempre

El rojo intermitente de `flutter test` (`1139 +1 -1`) que nunca se identificó, y
el emulador Java de Firestore muriéndose ~1 de cada 6 corridas en Windows.
