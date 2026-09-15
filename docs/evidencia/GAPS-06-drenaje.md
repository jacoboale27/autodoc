# GAPS-06 — segundo drenaje antes de FINAL-01

**Rama:** `fix/gaps-05` (continuación) · **Fecha:** 2026-09-14
**Alcance:** los 15 gaps que GAPS-05 dejó abiertos en su §5.

**Cerrados aquí: 5** (gaps 1, 3, 5, 6 y la mitad accionable del 4).
**Fuera por cuota de Codex: 2** (gaps 7 y 8), con su reconocimiento hecho y guardado.
**Siguen abiertos por decisión escrita: 8.**

---

## 1. Lo que más vale de esta tanda

### 1.1 El gate de revisión tumbó mi propio arreglo, y esta vez el defecto lo metí yo

GAPS-05 anotó del gap 5 que «las 499 invocaciones que pierden la carrera **descartan su
delta**, porque la rama de migración hace `return null`». Sonaba a defecto obvio y lo
«arreglé»: quien pierde ya no retorna, cae al camino incremental y aplica su delta.

**Era exactamente al revés, y el gate lo demostró con un escenario concreto.** Un trigger
de Firestore se dispara **después** del commit de la escritura que lo dispara, así que
cuando el ganador recuenta, la escritura del perdedor **ya está en la colección**. Sumar
el delta encima la cuenta dos veces. Dos reseñas de 5 y 3 estrellas daban **3 reseñas y 11
estrellas** para un taller que tiene 2 y 8.

Y no se autocura: con `suma_estrellas` ya definido nadie vuelve a recontar nunca, así que
el descuadre es permanente y silencioso. Peor que lo que venía a arreglar.

Lo que sí era real del gap 5 —y se queda arreglado— es el otro defecto, **que no estaba
anotado**: la siembra no era transaccional, así que las 500 invocaciones escribían
recuentos de instantes distintos y ganaba la última en llegar, que no es la más reciente.
Ahora siembra exactamente una. Más el escaneo paginado, que sí estaba anotado.

Queda una ventana de **subconteo**, más estrecha, anotada en el §4.

### 1.2 `/alertas` no tiene creador en ninguna parte, y eso reencuadra el gap más pesado

Al abrir el gap 1 para denormalizar el barrido, resultó que **nadie escribe documentos en
`/alertas`**: ni `lib/` ni `functions/`. `AlertModel.toMap()` no tiene un solo llamador.
Las alertas que ve el usuario son **sintéticas, calculadas en el cliente y nunca
persistidas** — de ahí los prefijos `soat_`, `task_` que las reglas ya documentaban.

Lo que el barrido lee en producción es **dato heredado** de una versión anterior de la app.

Eso no invalida el arreglo —el coste diario es real y permanente— pero cambia lo que
significa: **no es una cola que crece, es una que no se vacía.** El pin del `create` se
deja igualmente, porque las reglas ya lo anticipaban por escrito y un creador futuro que no
escribiera el campo moriría con `permission-denied` solo en producción.

### 1.3 Un marcador de posición que se vuelve real deja tests verdes por el motivo equivocado

`test_rules/alertas_allowlist.test.js` usaba `avisos_pendientes` para modelar «un campo de
servidor que todavía no existe», con el comentario «justo el que introduciría la tanda de
denormalización». Esta tanda lo introdujo.

Los tres tests **seguían en verde**, pero por otra regla —el pin a `true` del create y la
allowlist de mutables— en vez de por el `hasOnly` que dicen cubrir. Verde por el motivo
equivocado es la enfermedad que este repo lleva cinco tandas persiguiendo, y aquí se coló
por la puerta de un comentario que predecía el futuro correctamente. Repuntados a un campo
que de verdad no existe.

### 1.4 De los «cuatro streams sin cota» del panel del mecánico, son tres, y solo uno se acota

La anotación contaba cuatro. Son **tres**: el de servicios recientes ya llevaba `limit(5)`.

Y de esos tres, solo la **gráfica de tendencia** se puede acotar sin cambiar lo que
significa. Dibuja seis meses y siempre los dibujó, pero **descargaba la historia entera del
taller para tirar en memoria todo lo que cayera fuera de la ventana**: el bucle descarta lo
viejo con `ingresosPorMes.containsKey(key)` *después* de haberlo leído. Un taller con 5000
servicios pagaba 5000 lecturas, y otras tantas en cada reconexión del listener, para pintar
seis barras.

El test no puede afirmar sobre los valores de la gráfica: **salen iguales con cota y sin
ella**, que es justo lo que hacía invisible el defecto. Afirma sobre los documentos que
cruzan el cable. La ventana es la misma que ya usaba el bucle, así que no se retira ni una
barra, y el índice `servicios (id_taller ASC, fecha DESC)` que el filtro de rango necesita
**ya existe**: no hay paso de runbook.

Los otros dos siguen abiertos con razón, en el §4.

### 1.5 El backfill del gap 1 se ensayó gratis

Al añadir `where('avisos_pendientes','==',true)`, **once tests del barrido se pusieron
rojos de golpe** porque sus siembras no escribían el campo. Es literalmente lo que le
pasaría a producción sin correr el backfill: una igualdad sobre un campo ausente no
devuelve nada, así que la consulta diaria daría **cero documentos** y **todas las alertas
dejarían de avisar**, sin error, sin log y sin suite que lo vea.

Misma trampa que `abierto` en GAPS-02 y `estado` en H-01. Tercera vez.

### 1.6 Una bandera, no dos

El diseño que traía el reconocimiento proponía `avisos_pendientes.{por_vencer, vencida}`,
dos consultas y unión por id. No hace falta: el estado **terminal** es uno solo. Con
`ultimo_aviso === 'vencida'` no queda escalón por delante —`yaSeAviso` devuelve true para
los dos— y esa alerta no volverá a avisar nunca. `avisos_pendientes` es esa negación.

Las que están en `por_vencer` se siguen releyendo, y es correcto: les queda el escalón que
más importa. Se elimina la cola infinita, no la de trabajo.

---

## 2. Lo que el gate de reglas encontró detrás

### 2.1 Una alerta heredada no se podía completar (severidad media, defecto de usuario)

El guard `fecha_limite is timestamp` que GAPS-05 añadió mira `request.resource.data`, o sea
el documento **resultante**. En un `update({'estado':'Completada'})` sobre una alerta
heredada cuyo `fecha_limite` es una cadena ISO, el valor heredado sobrevive al merge, no es
timestamp, y la escritura moría con `permission-denied`.

O sea que **su dueño no podía cerrarla, solo borrarla** — mientras el barrido, que sí
parsea cadenas a propósito, le seguía mandando cada escalón. Cerrar el tipo hacía
ineditable justo la alerta que más molesta.

Arreglado condicionando el guard a que el campo **cambie**, que es el criterio de
`fotosBajoServicio` en `/resenias`. Verificado en rojo antes: revertir solo esa cláusula
deja 1 test rojo y 26 verdes.

### 2.2 `id_alerta` no estaba atado al id del documento en el `create`

El `update` ya lo sacaba de los mutables, porque reescribirlo a un prefijo sintético hace
que `completeAlert` se salte la escritura en silencio y la alerta quede pintada como
completada y `Pendiente` en el servidor. **Ese mismo estado se alcanzaba de nacimiento.**
Una línea.

### 2.3 Y el gate de functions confirmó lo que yo afirmaba sin poder probarlo

- La paginación del barrido **no se salta documentos** aunque ahora apague el campo por el
  que filtra: `startAfter(doc)` es un cursor por **valor** de `__name__`, no un
  desplazamiento, y lo que se apaga queda siempre por debajo del cursor.
- Dos igualdades + `orderBy('__name__')` **no necesitan índice compuesto**.
- Y revisó los siete handlers de notificación que había reescrito otro agente: **sin cambio
  de comportamiento observable en ninguno**, incluida la asimetría push/centro de los dos
  triggers de reserva y reparación. Es lo que hacía falta para aceptar ese trabajo.

---

## 3. Gates

| Gate | Resultado |
|---|---|
| `flutter analyze` | `No issues found!`, exit 0 |
| `flutter test` | **1278 / 1278**, exit 0 |
| Functions (Mocha) | **389 passing**, exit 0 |
| Reglas (Jest + emuladores) | **511 / 511** en 31 suites, exit 0 |

E2E no se relanzó: esta tanda no toca pantallas de flujo ni `e2e/`. La de la landing
tampoco, que no se toca `landing-web/`.

---

## 4. Lo que sigue abierto, con su razón

| # | Qué | Por qué no aquí |
|---|---|---|
| 1 | **Quince grupos de formularios sin defensa contra doble envío** (era el gap 7, «cinco») | **Se agotó la cuota de Codex a mitad.** El reconocimiento está hecho y **verificado uno por uno**: `docs/evidencia/anexos/GAPS-06-inventario-doble-envio.md`. Es el gap más barato de los que quedan y el que más superficie cubre |
| 2 | **Los literales sin traducir** (era el gap 8, «64 en 24 ficheros») | Misma razón. El barrido da **274 en 58 ficheros**, y la diferencia no está explicada — medirlo bien ES el primer trabajo de esa tanda. Inventario en `anexos/GAPS-06-inventario-literales.md`. Necesita además un ratchet que impida que vuelvan a crecer |
| 3 | **N+1 en los barridos** (GAPS-05 #2) | `db.getAll()` por página y `messaging.sendEach()`; el segundo obliga a rehacer el marcado por índice de resultado. El diseño está escrito en el reconocimiento de esta tanda |
| 4 | **Los dos KPI de por vida del panel del mecánico, y el historial** | Sigue en pie lo decidido: «Total Servicios» y «Vehículos Atendidos» no se pueden acotar sin cambiar lo que significan — necesitan contadores denormalizados. Y el historial no se puede acotar sin paginar, porque hoy filtra en memoria: un `limit` a secas escondería servicios viejos en silencio, que es peor que el coste |
| 5 | **La ventana de subconteo de `aggregateRatings`** | Nueva y bien delimitada: si la escritura del perdedor commitea después de que el ganador empezara su recuento, su delta se pierde. Cerrarla exige una marca de agua contra `context.timestamp`. Es estrictamente mejor que lo que había, que era sobrescritura obsoleta |
| 6 | **Replay de alerta por `delete` + `create` con el mismo id** | Lo levantó el gate. El propietario puede borrar su alerta terminal y recrearla, y renace sin contabilidad y con los avisos encendidos: N pushes al día, con operaciones que las reglas autorizan. **No tiene arreglo limpio dentro de las reglas.** El realista es pinear `fecha_limite` a futuro en el create, que es decisión de producto. Hoy no es alcanzable: no hay creador cliente |
| 7 | **Las alertas de fecha lejana, ilegibles y huérfanas no salen nunca de la cola** | También del gate, y **corrige una afirmación mía**: dije que lo que se sigue releyendo «dura como mucho `DIAS_DE_AVISO`». No es cierto para una alerta con `fecha_limite` en 2090, ni para una cuyo `fecha_limite` no se pueda parsear, ni para una cuyo vehículo ya no exista. Son estados terminales que conservan la bandera encendida |
| 8 | **`findReviewableServiceId` no tiene test que vea el ahorro** (GAPS-05 #10) | `FakeFirebaseFirestore` no cuenta lecturas. El gap 6 sí se cerró: lo que queda es medir el ahorro, que exige un seam contador |
| 9 | **Los cinco de decisión escrita** (GAPS-05 #9 a #13) | La guarda de `chat_screen` sin test directo, el barrido responsive a 390/414 (cierto por construcción), la cámara del escáner (no hay cámara en una suite), `MAX_CANJES` por pase, y los dos pasos de runbook. No son olvidos |
| 10 | **La limpieza de facturas huérfanas** (GAPS-05 #14) | Necesita un trigger con Admin SDK |
| 11 | **El rojo intermitente de `flutter test` y el emulador Java en Windows** | Sin dueño desde hace seis tandas. No apareció en esta: las dos corridas completas dieron 1278/1278 |

## 5. Runbook

Un paso nuevo, **bloqueante**, en `docs/RUNBOOK.md`: `node backfill_avisos_pendientes.js
--apply` **antes** de desplegar las funciones y **después** de `backfill_ultimo_aviso.js`.
Sin él, todas las alertas dejan de avisar en silencio. No hace falta desplegar índices.
