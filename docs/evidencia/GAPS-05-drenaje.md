# GAPS-05 — drenaje de gaps antes de FINAL-01

**Rama:** `fix/gaps-05` · **Fecha:** 2026-09-14
**Alcance:** los gaps abiertos de cuatro fuentes a la vez — §7 de `INNO-01-pase-de-historial.md`,
§6 de `H-01-hardening.md`, §7 de `GAPS-04-drenaje.md` y los hallazgos abiertos del §4 de
`AUDITORIA_CREA_J_2026_FINAL.md`. Deduplicados dan **~25 gaps reales**, no 31: varios estaban
contados dos veces entre documentos.

**Cerrados aquí: 14.** El resto queda en el §5, cada uno con su razón.

---

## 1. Lo que más vale de esta tanda

**Los dos P1 de la auditoría estaban mal descritos, y comprobarlo ERA el trabajo.** Es la cuarta
ronda seguida en que pasa, así que ya no es anécdota: **la anotación sirve para no perder el gap,
nunca como diagnóstico.**

- **`/reservas.id_taller` libre** — cierto, pero la anotación no decía lo que decide cómo
  arreglarlo: el único creador de `lib/` (`chat_screen.dart:346`) escribe **siempre** el mismo
  valor que `id_mecanico`. El `idTallerEfectivo` —el que sí distingue empleado de taller— es de
  las **cotizaciones**, que son otra colección. Atarlo a `id_mecanico` fija lo que la app ya hace;
  atarlo a `id_taller_efectivo`, que era la lectura natural del enunciado, habría roto el flujo
  entero.
- **Facturas de Storage «sin exigir ticket abierto»** — el cargo describe el significado que
  `talleres_vinculados` tenía **antes de la ronda 5**. Hoy el vínculo **es** posesión del coche:
  `vinculoTaller.js` lo otorga al recibir el vehículo y lo revoca al cerrarse el ticket, y son sus
  dos únicos escritores. O sea que «estar vinculado» ya significa «tiene el coche ahora mismo»,
  que es exactamente el «trabajo vigente» que el cargo pedía. La única ventana en que se separan
  es una revocación fallida, y desde GAPS-04 el barrido reintenta esos tickets **primero** y sin
  el filtro de 30 días: dura una corrida diaria.

  **Pero al lado había un agujero de verdad**, y ese sí se cerró: `allow write` cubre create,
  update **y** delete. El bloque denegaba borrar una factura a todo el que no fuera admin —«son el
  rastro documental del producto»— y a la vez dejaba **sobrescribirla** a cualquiera con vínculo.
  Sobrescribir una factura es borrarla con pasos extra.

## 2. Dos cosas que ninguna suite del repo podía ver

### 2.1 `env.clearStorage()` no limpia nada, y lo hace en silencio

Medido: se sube un objeto, se llama a `clearStorage()` y el objeto sigue ahí. El endpoint REST del
emulador (`DELETE /emulator/v1/projects/{p}/buckets/{b}/objects`) responde **501**.

**Por qué nadie lo había notado:** todas las reglas de Storage permitían sobrescribir, así que
subir encima de lo que dejó el test anterior daba exactamente el mismo verde que subirlo en
limpio. Apareció en cuanto la regla de facturas empezó a mirar `resource == null`: **tres tests
que llevaban tiempo pasando resultaron ser dependientes del orden**. Hay ahora `limpiarStorage()`
en `test_rules/helpers.js`, que borra listando —lo único que el emulador implementa—.

### 2.2 La condición correcta para «subir vs reemplazar» no es el verbo

Storage clasifica una **resubida** sobre la misma ruta como `create`, no como `update` (`update`
queda para `updateMetadata()`). Medido con el emulador: con `allow create` a secas, los dos casos
de sobrescritura **seguían pasando**. El guard que funciona es `resource == null`, y por eso la
regla lo usa en vez de apoyarse en la partición de verbos.

Esto contradice la documentación de Firebase, que define `update` como «sobrescribir un archivo
existente». La regla queda escrita para ser correcta bajo **las dos** semánticas.

## 3. El gate de revisión encontró cinco cosas más, y una era un defecto de cliente

Cuarta ronda consecutiva en que el revisor ve lo que los tests propios no.

1. **La confirmación de citas estaba invertida.** `ReservaModel` resuelve
   `idProponente ?? idPropietario` y `chat_screen.dart` **no lo pasaba**. Cuando proponía el
   **mecánico**, la cita nacía con el uid del propietario en `id_proponente`. Y de ese campo
   depende toda la máquina de transiciones: confirmar exige `uid != id_proponente`, o sea «no
   puedes aceptar tu propia propuesta». Resultado: **el propietario no podía confirmar la cita que
   le proponían, y el mecánico sí podía confirmar la suya.**
   Se arregló **el cliente primero** y se pineó la regla después; al revés se rompe la mitad del
   flujo.
2. **`hasAll` cerraba una de las TRES formas de auto-silenciar una alerta.** Las otras dos: el
   **valor** de `estado` (nacer `'Completada'` es tan invisible para
   `where('estado','==','Pendiente')` como nacer sin el campo) y **`fecha_limite`**, que sí es
   mutable y tiene su propio filtro dentro del barrido (`leerFechaLimite` → `resumen.ilegibles`).
   `null` se sigue admitiendo a propósito: `AlertModel.toMap()` lo escribe, y una alerta sin fecha
   es silenciosa **por diseño**.
3. **Mi propio cambio abría un modo de fallo nuevo.** Con nombres `<epoch-ms>` predecibles y la
   sobrescritura ya denegada, un taller vinculado podía sembrar archivos de 1 byte en rutas de
   milisegundos **futuros** y dejarlas inutilizables para siempre, porque solo un admin puede
   tocarlas. Cerrado con 64 bits de azar en el nombre (`Random.secure()`), que de paso convierte
   la colisión en el mismo milisegundo —que antes era una sobrescritura silenciosa y ahora sería
   un fallo duro— en algo que no puede ocurrir.
4. **`/reservas` tenía más identidad libre:** `estado` (nacer `'confirmada'` se salta el `update`
   entero y mete la cita en el barrido de recordatorios sin que nadie haya aceptado) y
   `fecha_hora_propuesta` sin tipo (`fromMap` hace `as Timestamp` **sin `?`**: un string revienta
   el parseo para los dos participantes).
5. **La limpieza de facturas huérfanas de `alert_provider` no puede funcionar** —el `delete` es
   solo de admin— y tampoco funcionaba antes. Queda **anotada en el código**, no fingida: el
   arreglo real es un trigger con Admin SDK, hermano de `borrarFotosAlEliminarResenia`.

## 4. Gaps cerrados

| # | Gap | Origen | Cómo se cerró |
|---|---|---|---|
| 1 | `/reservas.id_taller` libre | Auditoría P1 / H-01 #7 | Atado a `id_mecanico` en el `create` |
| 2 | Facturas sobrescribibles | Auditoría P1 / H-01 #8 | `resource == null` + nombre con 64 bits de azar |
| 3 | `/alertas` create sin campos ni tipos | GAPS-04 #14 | `hasOnly` + `hasAll` + `estado == 'Pendiente'`; `fecha_limite` tipada en el update |
| 4 | `esTallerAprobado(uid)` engañosa | H-01 #9 | Pierde el parámetro: la llamada tramposa ya no se puede escribir |
| 5 | Confirmación de citas invertida | Gate de revisión | `idProponente` explícito + pineado en la regla |
| 6 | `/reservas` estado y fecha libres | Gate de revisión | Pineados en el `create` |
| 7 | `clearStorage()` no limpia | Descubierto aquí | `limpiarStorage()` en helpers |
| 8 | El chat pierde el texto si falla el envío | Auditoría P2 / H-01 | El provider devuelve si llegó; la pantalla devuelve el texto y avisa |
| 9 | Pase no revocable al salir de la pantalla | INNO-01 #1 | Se reutiliza el pase vivo: volver a la pantalla vuelve a poner el botón |
| 10 | `crearPaseHistorial` sin límite por usuario | INNO-01 #2 | Idem: no nace un documento por visita |
| 11 | El lector no ve cuánto le queda al pase | INNO-01 #5 | Se pinta la hora de caducidad |
| 12 | `catch (_)` que miente sobre qué falló | H-01 #3-bis | Cada acción pasa su mensaje; la excepción se registra |
| 13 | Literal sin traducir en chat | H-01 #4 | Barrido (76 en 28 ficheros) + 12 localizados |
| 14 | «Un único creador de reservas» sin centinela | H-01 #10 | `test/reservas_creador_unico_test.dart` |

**Sobre el 9 y el 10:** los cierra el mismo cambio. La consulta que busca el pase vivo es de
**igualdades puras** a propósito —sin `orderBy` y sin rango—: Firestore sirve eso con los índices
automáticos, así que no añade ningún compuesto que desplegar. El vencimiento y el cupo se filtran
en código, y un pase revocado, caducado o agotado **no** se reutiliza: devolverlo sería peor que
no reutilizar nada, porque la pantalla pintaría un QR que solo puede fallar. Tampoco se renueva
`expira_en`, que convertiría reabrir la pantalla en una forma de extender el pase para siempre.

**Sobre el 13:** el gap pedía barrer antes de arreglar uno solo, y el barrido es el resultado:
**76 literales en 28 ficheros**, repartidos por mechanic (10), dashboard (6), admin (6), chat (3),
profile (2) y core/widgets (1) — o sea **no** es un problema del panel de administración. Se
localizaron los 12 de chat y core (nueve eran el mismo diálogo repetido en tres sitios). Los 64
restantes son una tanda propia, ahora medida. Y no es teórico: la E2E de INNO-01 dejó dicho que
**la app se renderiza en inglés** cuando el navegador lo está, así que esos 64 literales los ve
hoy un usuario inglés.

## 5. Gaps que siguen abiertos, con su razón

| # | Qué | Por qué no aquí |
|---|---|---|
| 1 | **`alertasVencidas` relee cada día todo lo ya avisado** (GAPS-04 #1, #4, #11) | Denormalizar `avisos_pendientes` + backfill + regla + runbook + los dos revisores. GAPS-04 ya lo dimensionó como tanda propia y lo sigue siendo; el diseño está escrito ahí |
| 2 | **N+1 en los barridos** (GAPS-04 #2) | `db.getAll()` por página y `messaging.sendEach()`; el segundo obliga a rehacer el marcado por índice de resultado |
| 3 | **Los siete triggers de notificación sin test** (GAPS-04 #3) | Ninguno tiene la lógica separada del acceso a Firestore; extraerlos es una tanda del tamaño de OPS-01 |
| 4 | **Cuatro streams sin cota en el panel del mecánico** (GAPS-04 #13, auditoría P2) | **Decidido no tocarlo, y la razón importa:** acotar el gráfico de 6 meses por fecha es correcto, pero los dos KPI de por vida («Total Servicios», «Vehículos Atendidos») no se pueden acotar sin cambiar lo que significan, y compartir un solo stream entre los dos `StreamBuilder` **no se puede medir** — `FakeFirebaseFirestore` no cuenta lecturas (es el gap 10 de GAPS-04). Un arreglo cuyo beneficio no se puede verificar es justo lo que este repo penaliza. Necesita contadores denormalizados |
| 5 | **`aggregateRatings` escanea sin cota** (GAPS-04 #12) | Acotar el escaneo y serializar la migración perezosa; merece su propia evidencia |
| 6 | **`findReviewableServiceId` devuelve el más reciente del primer chunk** (GAPS-04 #15) | Preexistente, solo se nota con más de 30 vehículos por propietario |
| 7 | **Cinco formularios sin defensa contra doble envío** (H-01 #1) | El inventario es de un worker y **solo uno se verificó a mano**. La lección de cinco tandas dice que hay que verificar los cinco antes de diseñar el arreglo, y eso es el trabajo, no el arreglo |
| 8 | **Los 64 literales sin traducir que quedan** (H-01 #4) | Medidos aquí. Son 24 ficheros; el arreglo es mecánico pero necesita un ratchet que impida que vuelvan a crecer |
| 9 | **La guarda de `chat_screen` sin test directo** (H-01 #2) | Alcanzarla exige atravesar `VehiculoPicker` + dos pickers de fecha/hora. La consecuencia visible sí está cubierta |
| 10 | **Barrido responsive sobre pantallas reales a 390/414** (H-01 #3) | 390 y 414 caen en la misma `WindowClass` que 375, así que añadirlos sería cierto por construcción |
| 11 | **La cámara del escáner no la ejerce nada** (INNO-01 #4) | Estructural: no hay cámara en una suite. Mitigado porque la decisión vive fuera del callback |
| 12 | **`MAX_CANJES` es por pase, no por persona** (INNO-01 #3) | Decisión escrita, no olvido |
| 13 | **TTL de `tokens_historial` y `APP_CHECK_ENFORCEMENT=enforce`** (INNO-01 #6, GAPS-04 #5) | Pasos de runbook; el repo prohíbe desplegar durante QA |
| 14 | **Limpieza de facturas huérfanas** | Nueva de esta tanda: necesita un trigger con Admin SDK. Anotada en el código |
| 15 | **El rojo intermitente de `flutter test` y el emulador Java que muere en Windows** | Sin dueño desde hace cinco tandas; no aparecieron en esta |

## 6. Gates

| Gate | Resultado |
|---|---|
| `flutter analyze` | `No issues found!`, exit 0 |
| `flutter test` | **1274 / 1274**, exit 0 |
| Functions (Mocha) | **302 passing**, exit 0 |
| Reglas (Jest + emuladores) | **501 / 501** en 31 suites, exit 0 |
| E2E de la app (Playwright, `--workers=1`) | **41 / 41**, exit 0 |
| Puertos al salir | 0 en `LISTENING` |

La E2E de la landing no se relanzó: esta tanda no toca `landing-web/`.
