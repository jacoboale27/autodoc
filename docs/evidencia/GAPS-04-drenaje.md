# GAPS-04 — drenaje de los gaps abiertos antes de H-01

Rama `fix/gaps-04`, cortada de `integracion/ola-1` (`1810620`). No es una tarea del plan:
es el drenaje de los gaps que dejaron abiertos UX-03/UX-04, SEC-04/OPS-01, GAPS-02 y
GAPS-FUNC-02. Se hace **antes** de H-01 por la regla del 2026-09-10: un gap documentado no
está cerrado.

Cerrados: **cinco**. Diferidos con razón escrita: el resto (§4).

---

## 0. Lo que encontró el reconocimiento, y por qué importa antes de leer nada más

Se inventariaron los gaps de las cinco evidencias y se verificó cada candidato contra el
código. **Dos de los descubrimientos no estaban en ninguna lista:**

**a) Hay gaps que se «remitieron a OPS-01» y OPS-01 cerró sin recogerlos.** Remitir un gap a
una tarea futura se sentía como cerrarlo; no lo es. Los dos que se perdieron por ahí son los
dos de más valor de esta tanda: el vínculo que no caduca (§2) y las fotos huérfanas (§3).
**Remitir no es una forma de cerrar.** Si un gap se manda a una tarea, esa tarea tiene que
recogerlo explícitamente en su evidencia o volver a quedar anotado.

**b) Dos descripciones de gap eran inexactas, y la de más peso lo era en la dirección
tranquilizadora.** Ya pasó en la ronda anterior (un «índice muerto» que era el índice vivo
mal escrito). Aquí:

- El gap 9.6 decía que **nadie** recoge `vinculo_revocacion_pendiente`. Falso, y peor de lo
  que suena: el barrido de caducidad sí acaba viéndolo —porque el ticket conserva
  `vinculo_activo: true`— pero **sólo cuando pasan los 30 días de inactividad**, y ese reloj
  arranca en el cierre. O sea que un fallo de revocación regala **un mes de acceso a la ficha
  de un coche ya devuelto**. La descripción original habría llevado a construir maquinaria
  nueva; lo que hacía falta era una consulta más.
- El gap 7.4 decía que `workshop_service.dart:33/:47` «lee hasta 2×50 para devolver 50». La
  consulta tiene **dos** valores en el `whereIn`, un solo `limit` y su índice compuesto ya
  declarado: la magnitud es BAJA y no justifica tocarla. (Un worker de Codex la declaró
  directamente *incorrecta* citando la documentación de Firestore; eso **contradice** el
  hallazgo ya verificado del gap 9.1 sobre `whereIn` + `limit`, así que no se compra su
  razonamiento — sólo la conclusión de severidad, que se sostiene por las dos vías.)

---

## 1. `/alertas` — de denylist a allowlist

**El gap:** el acotado de campos de servidor era `!keys().hasAny(['ultimo_aviso',
'fecha_ultimo_aviso'])`. Una denylist enumera lo prohibido: cubre los campos que existían el
día que se escribió y deja nacer **escribible por el cliente** cualquier campo de servidor
posterior.

No es hipotético. El hallazgo de la ronda de SEC-04 —se podía **crear** una alerta ya
silenciada, con `ultimo_aviso: 'vencida'`, y el propio candado del update lo volvía
irreversible— llegó exactamente por ese hueco. Y la denormalización de `avisos_pendientes`
que queda pendiente (§4) añadiría el tercer campo de servidor, que con la denylist nacería
escribible.

**Lo que cambió el reconocimiento:** la allowlist podía ser **más estrecha** de lo que
proponía el gap. La app **nunca crea** una alerta desde `lib/` —no hay un solo
`collection('alertas').add/set`— y el único update que hace es `{'estado': 'Completada'}`
(`alert_provider.dart:304`).

**El contrato ahora:** dos funciones en `firestore.rules`, `camposDeAlerta()` y
`camposMutablesDeAlerta()`, espejo de `AlertModel.toMap()`. El create usa `hasOnly` sobre
`keys()`; el update, sobre `affectedKeys()`. `id_vehiculo` sigue siendo inmutable por estar
fuera de la segunda lista, y `ultimo_aviso`/`fecha_ultimo_aviso` quedan fuera **por no estar
dentro**, que es justo la propiedad que la denylist no tenía.

**De paso, un dato de test caducado.** Las suites de reglas sembraban alertas con `tipo`, un
campo que **no existe en el dominio**: ni en `toMap()`, ni en `fromMap()`, ni en el barrido
de Functions (que lee `tipo_alerta`). Nada lo notó nunca porque la denylist no miraba los
campos desconocidos. Corregido en las dos suites.

**Cobertura:** `test_rules/alertas_allowlist.test.js`, 7 casos. Tres rojos vistos antes de
implementar (create con campo desconocido, update con campo desconocido, y lo mismo como
admin), y cuatro de control que impiden pasarse de frenada: crear con los campos del modelo,
marcar completada, y los dos que la denylist ya cubría y no pueden reabrirse.

---

## 2. El vínculo que tardaba 30 días en caducar (gap 9.6)

**El gap, corregido:** cuando `revocarVinculoAlCerrar` falla, deja
`vinculo_revocacion_pendiente: true` en el ticket y el vínculo **vivo**. La evidencia decía
que nadie recoge esa marca. En realidad el barrido sí acaba viéndola, vía `vinculo_activo`,
pero con el filtro `fecha_actualizacion < corte` puesto: **a los 30 días del cierre**. Un mes
de lectura sobre la ficha, la galería, las alertas y el historial de un coche ya devuelto.

**El arreglo:** `caducarVinculosInactivos` hace ahora una segunda consulta,
`vinculo_revocacion_pendiente == true`, **sin cota de tiempo** — la marca significa «había
que revocar esto YA». Los resultados de las dos se deduplican por id antes de procesarse, así
que un ticket rancio *y* marcado no se cuenta dos veces. Y al conseguir revocar se limpia la
marca en la misma escritura: dejarla puesta con el vínculo ya revocado la convierte en
mentira, y la marca existe precisamente para poder preguntar cuántos vínculos quedaron
colgando.

Es **una sola igualdad**, así que la sirve el índice automático y no añade compuesto.

**Cobertura:** tres casos nuevos en `functions/test/caducar_vinculos.test.js`. Dos rojos
vistos antes de implementar; el tercero (no contar dos veces) pasaba ya y se conserva como
red de seguridad de la dedup.

**Una aserción mía miraba al doble, no al código.** El primer intento afirmaba que
`talleres_vinculados` quedaba vacío. El doble en memoria no ejecuta las transformaciones de
Firestore, así que guardaba el `arrayRemove` sin aplicar: la aserción probaba el doble. Se
cambió por lo que sí es observable — que la revocación se intentó contra el vehículo.

---

## 3. Las fotos que sobrevivían a su reseña (residual de FUNC-01)

**El gap:** FUNC-01 dejó la **edición** consistente y anotó que **nadie borra las fotos al
ELIMINAR una reseña**. Se remitió a OPS-01; OPS-01 cerró sin recogerlo. Verificado: no existe
ningún trigger `onDelete` sobre `resenias`, y `aggregateRatings` es un `onWrite` que sí se
dispara al borrar pero sólo recalcula la media.

**Son dos caminos, y el segundo no estaba anotado:** el autor borra su reseña, **y** se borra
la cuenta — `deleteUserData` (`functions/index.js:1066`) barre las reseñas del usuario en
lotes de 500 sin pasar por la app. No es sólo coste de almacenamiento: son fotos del coche de
alguien que pidió que se borraran, y el objeto sigue siendo descargable por su URL.

**El arreglo:** trigger `borrarFotosAlEliminarResenia` (`onDelete` sobre `resenias/{id}`),
con la lógica en `functions/src/fotosDeResenia.js` para poder probarla sin firebase-functions.
Un trigger cubre los dos caminos por construcción, y además es el único que tiene permiso: en
el borrado de cuenta ya no hay autor que firme.

**Dos decisiones que no eran obvias:**

- **Por URL exacta, no por prefijo.** `storage.rules` obliga a que las fotos vivan bajo
  `resenia_fotos/{idServicio}/`, así que borrar el prefijo parece natural. Pero el id del
  documento se deriva de usuario + servicio (`ReviewService._reviewDocId`): dos reseñas pueden
  compartir prefijo, y el borrado se llevaría las fotos de la otra.
- **La ruta se valida aquí también.** `fotos` lo escribe el cliente. Las reglas lo acotan con
  `fotosBajoServicio`, pero este trigger corre con Admin SDK y las reglas no lo alcanzan; y
  las reseñas anteriores a FUNC-01 pudieron guardar URLs que ese filtro no habría dejado pasar.
  Sin el candado, escribir una cadena en un documento se convertiría en un borrado arbitrario
  de cualquier objeto del bucket.

Va **aparte** de `aggregateRatings` a propósito: mezclarlos ataría el recálculo de la
calificación al éxito de un borrado en Storage.

**Cobertura:** `functions/test/fotos_de_resenia.test.js`, 8 casos, rojos antes de existir el
módulo. El objeto ya borrado se trata como el caso **normal**, no el excepcional: la edición
de FUNC-01 ya limpia huérfanos, así que una foto quitada antes no está.

---

## 4. La rama muerta de reservas (gap 7.2) y la consulta sin tope (gap 7.4)

**Retirada completa de `streamReservasUsuario`.** Verificado: `inicializarReservasUsuario`,
`reservas`, `reservasTruncadas`, `maxReservasHistorial` y el propio stream tenían **cero
consumidores en `lib/`**. Los sostenían tres tests — el patrón exacto de FUNC-02. La tanda
anterior lo acotó («correcto y barato»), pero acotar bien un camino que nadie recorre no lo
vuelve útil.

Se fueron con él sus **dos** índices de producción (`id_mecanico`/`id_propietario` +
`fecha_hora_propuesta`). El strand de `session_reset_test` que probaba «clear() cancela la
suscripción, no sólo vacía la lista» se repuntó a `ChatProvider`, que sí tiene stream; la
propiedad la siguen probando chat, notificaciones y reparaciones.

**El tercer índice de `reservas` casi se va también, y lo paró el centinela.** Al retirar los
otros dos se borró de un plumazo — pero lo usa el recordatorio diario de citas, que es del
**servidor** (`functions/src/recordatoriosReserva.js:86`). Lección: vaciar `lib/` de consultas
a una colección no significa que la colección se haya quedado sin consultas.

**`findReviewableServiceId` acotada.** Leía `servicios` con un `whereIn` de hasta 30 vehículos
**sin `limit`**, ordenaba en memoria y devolvía como mucho un id — o sea, todo el historial
del propietario, de todos los talleres, para responder una pregunta sobre uno. Ahora filtra
por `id_taller` en el servidor, ordena por `fecha` en el servidor y acota a 50. Índice nuevo:
`servicios (id_vehiculo, id_taller, fecha DESC)`.

**Honestidad sobre el TDD de este punto:** el ahorro **no lo puede ver ningún test** —
`FakeFirebaseFirestore` no cuenta lecturas. Lo que sí fue a rojo antes de implementar es
`test/firestore_indices_test.dart`, que es el mecanismo que este proyecto ya tiene para exactamente
esto. La función **no tenía ni un test**, así que se escribió primero su cobertura de
caracterización (5 casos) para fijar el comportamiento antes de tocarlo. Que no haya un rojo
directo sobre el coste es un hueco real de esta tanda, no una formalidad cumplida.

---

## 5. Gates

| Gate | Resultado |
|---|---|
| `flutter analyze` | `No issues found!` |
| `flutter test` | **1221 / 1221**, exit 0 |
| `functions` (Mocha) | **276 passing**, exit 0 |
| `test_rules` (Jest + emuladores) | **454 / 454**, 26 suites, exit 0 |
| Puertos al salir | 0 en `LISTENING` |

Los dos revisores obligatorios (`firestore-rules-reviewer`, `functions-perf-reviewer`) se
pasaron sobre el árbol completo antes de cerrar — ver §7.

**Los tres centinelas del repo dispararon, y los tres tenían razón:**

1. El de índices, al bajar el `orderBy` al servidor (contador 16 → 17) y otra vez al retirar
   el stream muerto (17 → 16).
2. El de índices otra vez, en su comprobación de huérfanos, al borrarse el índice de
   `reservas` que usa el servidor. **Ese paró un defecto real.**
3. El de FUNC-02, que cuenta accesos server-side a `/reparaciones` por archivo, al añadirse la
   segunda consulta del barrido. Es una lectura más sobre el mismo camino: no abre puerta
   nueva.

---

## 5 bis. La ronda de revisión — y el peor hallazgo era mío, repitiendo un gap conocido

Los dos revisores corrieron sobre el árbol completo. El de reglas dio el cambio de `/alertas`
por **estrictamente más restrictivo**, sin regresión ni bypass, verificándolo contra los
emuladores y no contra los dobles falsos. Pero entre los dos encontraron **siete cosas que
los tests propios no veían**, y la primera duele:

**1. Mi `limit(50)` era el gap 9.1 otra vez.** En un `whereIn` el `limit` se aplica a **cada
subconsulta** antes de mezclar: con un chunk de 30 vehículos son hasta **1500 documentos
leídos para devolver un id**, no 50. Este proyecto ya había documentado ese comportamiento
—es literalmente el gap 9.1, sobre el tablero— y aun así la constante y su docstring decían
«50». Corregido con una cota que además es mucho mejor: el bucle sólo busca el **primero no
reseñado** y los reseñados ya están en memoria, así que basta pedir `reseñadas + 1`. En el
caso normal eso es `limit(1)`, o sea 30 lecturas en el peor caso en vez de 1500.

**2. `id_alerta` quedó mutable, y tiene consecuencia real.** La app lo usa como **destino**
de la escritura al completar la alerta (`alert_provider.dart:296-307`), y hay un `startsWith`
de prefijos sintéticos que hace que ese write se salte en silencio. Reescribiéndolo a
`soat_loquesea`, la alerta se pinta completada en la UI y sigue `Pendiente` en el servidor,
avisando por push para siempre. No cruza el límite de usuario —es integridad, no IDOR— y
cerrarlo cuesta cero, porque ningún flujo actualiza el campo.

**3. El comentario de la regla prometía un test que no existía.** Decía «si el modelo gana un
campo, este `hasOnly` tiene que ganarlo también, **y el test lo obliga**». No lo obligaba: la
suite de `test_rules/` escribe su propio inventario en JS y se queda atrás igual de callada.
Y es justo el modo de fallo propio de una allowlist: un campo nuevo del modelo se denegaría
**sólo en producción**, porque los emuladores obedecen la regla igual de bien que Firestore.
De ahí sale `test/alertas_campos_test.dart`, que cruza las dos listas en las dos direcciones.

**4. El presupuesto del barrido se había duplicado en silencio.** Las dos consultas llevaban
`limit(200)` cada una, así que tras la dedup podían salir **400 tickets** — el doble de lo que
`TOPE_POR_CORRIDA` dice acotar, y cada uno cuesta dos escrituras que además despiertan a los
`onUpdate` de la misma colección. Ahora se **reparte**: los marcados van primero y se llevan
lo que necesiten (son los urgentes), y los rancios se quedan con el resto.

**5. `rutaDeFotoDeResenia` no validaba el bucket.** El módulo se toma el trabajo de razonar en
su cabecera sobre «escribir una cadena no puede volverse un borrado arbitrario» y luego dejaba
`[^/]+` sin capturar: una URL a **otro** proyecto con path `resenia_fotos/...` se traducía en
un borrado dentro del nuestro. Capturado y comparado con `bucket.name`.

**6. El tope de 3 fotos es del cliente, no del servidor.** `fotosBajoServicio` lo impone sólo
**desde FUNC-01**; una reseña anterior pudo guardar un array arbitrario, y el bucle es en
serie dentro de una función con 60 s. Acotado con `MAX_FOTOS_POR_BORRADO`.

**7. Ruido en el centinela de índices:** una entrada duplicada (la de `reservas` que ya había
puesto OPS-01) y un puntero de línea desfasado. Los orígenes son lo que hace útil al centinela
cuando falla.

Los siete están corregidos y cubiertos. Es la tercera tanda seguida en la que los gates
encuentran defectos que las suites propias no veían: **no son opinión**.

---

## 6. Runbook — lo que esta tanda añade

1. `firebase deploy --only firestore:indexes` **antes** que la app. Esta corrida **crea uno**
   (`servicios (id_vehiculo, id_taller, fecha DESC)`) y **retira dos** (los de `reservas` por
   rol). El índice nuevo va antes que la app: sin él, `findReviewableServiceId` muere con
   `failed-precondition` y la ficha del taller deja de ofrecer reseñar.
2. `firebase deploy --only firestore:rules` — la allowlist de `/alertas` rechaza cualquier
   campo fuera del modelo. Una app vieja que escribiera un campo no listado empezaría a
   recibir `permission-denied`; hoy ninguna lo hace.
3. `firebase deploy --only functions` incluye el trigger nuevo
   `borrarFotosAlEliminarResenia`.
4. Pendientes heredados, sin cambios: `SOLICITUDES_LANDING_SALT`, la política TTL de
   `solicitudes_landing_control`, y las cuatro pasadas de `backfill_entregado.js --apply`
   antes de desplegar la app web.

---

## 7. Gaps que quedan abiertos, con su razón

Decisión del usuario del 2026-09-13 sobre el alcance de esta tanda: cerrar los cinco
verificados y llevar lo demás anotado a H-01.

| # | Qué | Por qué se deja |
|---|---|---|
| 1 | **`alertasVencidas` relee cada día todo lo ya avisado.** Verificado y cierto: lee las N alertas `Pendiente` sin filtro de fecha ni de `ultimo_aviso`; el `limit(500)` sólo pagina, `startAfter` recorre el resto. Una alerta vencida que nadie cierre consume una lectura diaria para siempre. | Cerrarlo bien es denormalizar `avisos_pendientes` + backfill + regla + paso de runbook + los dos revisores: el tamaño del lote C de la tanda anterior. **Tanda propia, decidida así explícitamente.** El campo, quién lo escribe y el backfill exacto ya están diseñados en el reconocimiento de esta tanda. |
| 2 | **Los barridos siguen haciendo N+1**: una lectura por vehículo y por usuario, `messaging.send()` por destinatario, secuencial. | `timeoutSeconds: 540` quitó el riesgo inmediato. Agruparlo son dos cambios (`db.getAll()` por página y `messaging.sendEach()`) y el segundo obliga a rehacer el marcado por índice de resultado. |
| 3 | **Los siete triggers de notificación siguen sin test.** OPS-01 los nombra en su enunciado y cubrió las cuatro programadas y el respaldo, no los `onCreate`/`onUpdate` que mandan push. | Ninguno tiene la lógica separada del acceso a Firestore; extraerlos es una tanda del tamaño de OPS-01. Quedan inventariados con ruta y línea en el reconocimiento de OPS-01. |
| 4 | **`checkAlertsDaily` no vuelve a avisar** si el usuario aleja la fecha límite y luego la vuelve a acercar: el escalón anotado no se limpia. Verificado cierto (`alertasVencidas.js:212-217`). | Alcanzable pero raro. Limpiarlo bien exige comparar contra la fecha además del escalón, y encaja en la misma tanda que el gap 1. |
| 5 | **El paso 2 de la verificación de App Check es manual**, y nadie ha comprobado cómo trata el cliente Flutter un `failed-precondition` donde antes recibía `unauthenticated`. | Con `enforce` puesto la suite E2E entera fallaría: el emulador no emite tokens. Va con la puesta en marcha de `enforce`, en su runbook. |
| 6 | **El reintento de Cloud Scheduler no está configurado**, y **el recordatorio de reserva no escribe en el centro de notificaciones** (sólo push), al revés que el de alertas. | El primero es seguro en alertas y no en reservas hasta que haya marca por reserva. El segundo cambia lo que ve el usuario y merece criterio de producto. |
| 7 | **`workshop_service.dart:33/:47`** — `whereIn` de dos valores + `orderBy` + `limit(50)`. | Severidad BAJA por las dos lecturas posibles del comportamiento de `whereIn` + `limit`, y su índice compuesto ya está declarado. La descripción del gap 7.4 era inexacta; queda corregida aquí. |
| 8 | **El tope del tablero no está paginado** (9.7), **`_MisServicios` filtra `cancelado` en memoria de forma redundante** (9.8), **`errorDatosNoEncontrado` no existe** (UX-04 #5), **`FeaturesGrid` anima la opacidad bajo movimiento reducido** (UX-03 #4). | Los cuatro son decisiones ya escritas, no olvidos. Se verificaron y se sostienen. |
| 9 | **Sin dueño, otra vez:** el rojo intermitente de `flutter test` que nunca se identificó, y el emulador Java de Firestore muriéndose ~1 de cada 6 corridas en Windows. | No apareció en esta tanda (`flutter test` dio 1219/1219 en las dos corridas completas). Sigue sin evidencia para afirmar ni descartar nada. |
| 10 | **El ahorro de `findReviewableServiceId` no tiene test que lo vea.** | `FakeFirebaseFirestore` no cuenta lecturas; hacerlo visible exige un seam contador sobre Firestore. Anotado como hueco de esta tanda, no como formalidad. |
| 11 | **Un ticket marcado cuya revocación falle siempre se reprocesa a diario, y puede dejar sin barrer a los demás.** La consulta de marcados no tiene `orderBy`, así que `limit` recorta por `__name__`: con más de 200 marcados a la vez, los de id alto podrían no barrerse nunca. Es el mismo razonamiento de inanición que el módulo usa para justificar filtrar por `vinculo_activo`, aplicado al otro lado. | El coste del zombi es 1 lectura + 1 escritura fallida al día, acotado; y >200 marcados simultáneos significa que la revocación está fallando a escala, que es una alarma mayor. El arreglo está diseñado: escribir `vinculo_revocacion_pendiente_desde` junto a la marca y ordenar por él — lo que **sí exige índice compuesto**, al contrario de la consulta actual. Va con la tanda del gap 1. |
| 12 | **`aggregateRatings` escanea todas las reseñas del taller en su rama de migración perezosa** (`functions/index.js:1215`, `.get()` sin `limit`). En un borrado de cuenta son 500 invocaciones concurrentes: si el taller aún no tiene `suma_estrellas`, todas ven `undefined` a la vez y cada una hace el escaneo completo. | Preexistente y no de esta rama, pero el trigger nuevo vuelve a poner ese camino bajo el foco. Cerrarlo es acotar el escaneo y serializar la migración; merece su propia evidencia. |
| 13 | **El panel del mecánico abre tres `snapshots()` sobre `servicios where id_taller` sin `limit`**, más otro en su historial. Un taller con 5000 servicios paga cuatro streams completos al abrir. | Es exactamente el patrón que el lote A de GAPS-02 cerró para chat y reservas, sin cerrar para el panel del mecánico. Tanda propia, del mismo tamaño que aquel lote. |
| 14 | **El `create` de `/alertas` no exige campos ni tipos.** `hasOnly` admite cualquier subconjunto: se puede crear una alerta sin `estado`, o borrarlo con `FieldValue.delete()`, y eso la saca del barrido para siempre. | Sólo afecta a los documentos del propio atacante (auto-silenciarse), y completar el patrón `/reservas` exige `hasAll` más validación de tipos. Ojo: `fecha_limite` convive hoy como Timestamp y como cadena, así que atar el tipo sin backfill rompería datos heredados. |
| 15 | **`findReviewableServiceId` devuelve el más reciente del primer chunk que tenga alguno, no el más reciente global**, y recorre los chunks en serie. | Preexistente, no regresión. Sólo se nota con más de 30 vehículos por propietario. |
