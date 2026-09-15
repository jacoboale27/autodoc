# GAPS-07 — el doble envío en formularios, cerrado

**Rama:** `fix/gaps-07a` · **Fecha:** 2026-09-15
**Alcance:** el gap 1 del §4 de `GAPS-06-drenaje.md` — los quince grupos vulnerables del
anexo `anexos/GAPS-06-inventario-doble-envio.md`.

**Cerrados: 15 de 15.** Uno de los dieciséis controles se queda sin test, con su razón.
**Un veredicto del anexo resultó falso.**

---

## 1. Lo que más vale de esta tanda

### 1.1 Los dos mecanismos no son alternativas: hacen falta los dos

`onPressed: null` (o `AppButton(isLoading: true)`, que sí bloquea taps) **solo surte efecto en
el frame siguiente**. Dos taps en el MISMO frame pasan los dos. Medido, no supuesto: en
alertas, notificaciones y revocar acceso, lo que atrapó el segundo tap fue el guard de
reentrada, no la deshabilitación.

Y al revés: el guard solo no basta donde el segundo envío llega **segundos** después, tras
recorrer otra vez un flujo largo. Por eso todos llevan las dos capas.

### 1.2 El defecto casi nunca es «dos taps en el mismo botón»

De los quince grupos, **ocho** tienen su envío detrás de un diálogo de confirmación o de uno
o más *pickers*. El diálogo **se cierra al confirmar**, así que el doble envío no viene de
machacar el botón: viene de **reabrir el diálogo y volver a confirmar** mientras la primera
escritura sigue en vuelo. Eso cambia dónde va la protección y cómo se prueba — los tests
afirman que el diálogo **no se reabre**, que es más fuerte que un contador en uno.

El caso extremo es la cita nueva del chat: **cuatro pasos** (hoja de adjuntos, selector de
vehículo, fecha, hora). Ahí la bandera se enciende justo antes de la primera escritura y **no**
al abrir la hoja: si cubriera los *pickers*, cancelar uno dejaría la entrada muerta para
siempre.

### 1.3 Las banderas por id, no globales

En seis sitios la protección es un `Set` de ids y no un `bool`. Revocar el acceso de un taller
no tiene por qué bloquear la fila de otro; reportar una reseña no bloquea responderla. Y en dos
casos (`catalogo`, `empleados`) el flag del provider **ya existía y no gobernaba el botón de la
fila** — que es exactamente el defecto que el anexo describía.

### 1.4 Añadir una bandera destapó dos streams creados dentro de `build`

Esto es lo más transferible de la tanda. Un `setState` reconstruye, y **un stream construido en
`build` se recrea y se re-suscribe**:

- `VehicleGalleryWidget`: al pasarlo a `StatefulWidget` hubo que memoizar el stream de fotos en
  `initState`, o la propia bandera habría re-suscrito la galería en cada subida.
- `MechanicReviewsScreen`: el stream de reseñas se creaba en `build`, así que **cualquier**
  `setState` devolvía el `StreamBuilder` a `waiting` y la lista entera desaparecía. **Ya pasaba
  al cambiar el orden**, antes de esta tanda; las banderas solo lo hicieron visible porque
  provocan más rebuilds. El test lo encontró: las tarjetas dejaban de existir a mitad del caso.

Y un tercero de la misma familia: el resumen de gastos del perfil de vehículo creaba un
`Future` **nuevo en cada build**, así que cada `setState` relanzaba la consulta.

**Un arreglo de doble envío que no mire los streams y futures del `build` cambia un defecto por
otro peor.**

### 1.5 Un veredicto del anexo era falso

La fila 10 marcaba VULNERABLE «aceptar invitación» (`share_vehicle_sheet.dart:28`). **No lo es.**
El botón hace `Navigator.pop` inmediato y el segundo tap no se lleva la ruta de debajo. El test
escrito para demostrarlo **pasa sin arreglo alguno**, así que queda como centinela de regresión y
no como prueba de un arreglo. Van seis rondas seguidas en que una anotación de gap no aguanta la
comprobación: **la anotación sirve para no perder el gap, no como diagnóstico.**

### 1.6 `isLoading` envenena `pumpAndSettle`

`AppButton(isLoading: true)` pinta un spinner que **no deja de animar**, así que `pumpAndSettle`
no termina nunca en ningún test de ese widget. En la fila de talleres se quedó solo el
`onPressed: null`. Donde sí se usa `isLoading` (kilometraje del perfil), el test aprovecha el
efecto secundario: **que el rótulo «Guardar» desaparezca es la prueba** de que el botón dejó de
aceptar taps.

### 1.7 Una reversión que falla en silencio miente igual que un verde por el motivo equivocado

Al comprobar el rojo-antes del guard de la nota nueva, la reversión **no se aplicó** —el
formateo había cambiado el texto que buscaba— y el test pasó, lo que parecía decir que ese guard
no hacía falta. Revertido de verdad: `Expected 1 / Actual 2`. **Del rojo-antes hay que verificar
que de verdad revirtió algo.**

---

## 2. De dónde salió el trabajo, y qué costó

El encargo se delegó a Codex (dos *builders* en worktrees separados y un worker de solo
lectura). **Los tres murieron con la cuota agotada**, y el `-o` nunca se escribió: los informes
se perdieron. Lo que quedó en los worktrees:

- Builder A: **6 ficheros de test, cero implementación.**
- Builder B: 5 ficheros de test y **dos ficheros de `lib/` con seams de prueba, ninguna
  protección**.
- Worker de literales: **nada**.

Los once tests **compilaban y fallaban los diecisiete casos con `Expected 1 / Actual 2`**, así
que el reconocimiento valió: el defecto quedó reproducido. Pero **ninguno estaba verificado** y
hubo que corregir casi todos: dos ficheros no compilaban, y los *finders* fallaban por rótulos
inventados, por locale (`'Aceptar'` lo pone `GlobalMaterialLocalizations`), por buscar texto
donde había tooltip, y por dar por hecho que el diálogo se reabre.

**Lección de reparto:** delegar el *reconocimiento* a otra bolsa de cuota rinde; delegar la
*implementación* con TDD no, si la cuota puede cortarse a mitad — deja tests sin verificar, que
es deuda disfrazada de trabajo hecho.

---

## 3. Los quince grupos

| # | Dónde | Mecanismo | Test | Rojo-antes |
|---:|---|---|---|---|
| 1 | `auth_screen` Google y recuperar contraseña | flag + `isLoading`; el segundo en `StatefulBuilder` | `doble_envio_a_auth_test.dart` | sí |
| 2 | `chat_screen` cita nueva | flag antes de la 1.ª escritura + `onTap: null` | `doble_envio_a_reserva_test.dart` | sí |
| 3 | `chat_screen` enviar, adjuntos, editar | tres flags | `doble_envio_a_chat_test.dart` | sí |
| 4 | `reserva_detail_screen` reprogramar | solo guard: median dos pickers | `doble_envio_a_reprogramar_test.dart` | sí |
| 5 | `cotizacion_chat_card` aceptar/rechazar | flag en el State | `doble_envio_a_cards_test.dart` | sí |
| 6 | `reserva_chat_card` ×4 | Stateless → Stateful | `doble_envio_a_cards_test.dart` | sí |
| 7 | `alerts_screen` kilometraje | `StatefulBuilder` | `doble_envio_a_alerts_test.dart` | sí |
| 8 | `notifications_screen` marcar todo | Stateless → Stateful | `doble_envio_a_notifications_test.dart` | sí |
| 9 | `vehicle_profile_screen` km, fechas, nota | 2 `StatefulBuilder` + Set por fecha | `doble_envio_b_vehicle_profile_test.dart` | sí |
| 10 | `share_vehicle_sheet` retirar usuario | Set de uids | `doble_envio_b_dashboard_widgets_test.dart` | sí |
| 10b | `share_vehicle_sheet` aceptar invitación | — | centinela | **no: el cargo era falso** |
| 11 | `vehicle_gallery_widget` subir foto | Stateless → Stateful + stream memoizado | `doble_envio_b_dashboard_widgets_test.dart` | sí |
| 12 | `talleres_con_acceso_card` retirar acceso | Set de uids | `doble_envio_b_talleres_test.dart` | sí |
| 13 | `catalogo_servicios_screen` eliminar | Set de idItem | `doble_envio_b_catalogo_test.dart` | sí |
| 14 | `empleados_screen` desactivar | Set de idEmpleado | `doble_envio_b_empleados_test.dart` | sí |
| 15 | `mechanic_reviews_screen` reportar | Set por reseña y tipo | `doble_envio_reviews_test.dart` | sí |
| 15b | `mechanic_reviews_screen` publicar respuesta | mismo `_enCurso` | **sin test** (§5) | — |

## 4. Gates

| Gate | Resultado |
|---|---|
| `flutter analyze` | `No issues found!`, exit 0 |
| `flutter test` | **1301 / 1301**, exit 0 (base 1278: +23) |
| Functions (Mocha) | no se relanzó: **cero cambios en `functions/`** |
| Reglas (Jest) | no se relanzó: **cero cambios en `firestore.rules` / `storage.rules`** |
| E2E | no se relanzó: no toca `e2e/` ni `landing-web/` |

Los 28 ficheros del diff están todos bajo `lib/` y `test/`.

## 5. Gaps que deja esta tanda

| # | Qué | Por qué |
|---:|---|---|
| 1 | **El diálogo de respuesta a una reseña desborda ~99 000 px** al abrirse en un test de widget, y las excepciones se encadenan por todo su subárbol (incluido el `RawGestureDetector`), así que su botón no se puede tocar. Causa: `AlertDialog` envuelve el contenido en `IntrinsicWidth` y el `SizedBox(width: double.maxFinite)` de `AppDialogContent` vuelve absurdo el ancho intrínseco | **Probablemente sea un defecto de producción**, no solo de test. No se arregla aquí porque `AppDialogContent` lo usan muchos diálogos y cambiarlo a ciegas al final de una tanda es justo el atajo que este plan prohíbe. Es el único de los 16 controles sin test |
| 2 | **No hay centinela que impida que vuelvan a aparecer botones sin protección** | Un `onPressed` que escribe sin bandera compila, analiza limpio y pasa cualquier test. Detectarlo exige cruzar los callbacks que llaman a un provider o servicio con la presencia de una bandera — caro y con falsos positivos. Queda como diseño pendiente, igual que el ratchet de literales |
| 3 | **Los literales sin traducir** (gap 2 del §4 de GAPS-06) | **Sin empezar.** El worker de solo lectura que tenía que remedir los 274 murió con la cuota y no dejó nada. Sigue siendo el primer trabajo de la próxima tanda, y sigue sin medición fiable |
| 4 | Los gaps 3 a 11 del §4 de `GAPS-06-drenaje.md` | Intactos: el N+1 de los barridos, los KPI de por vida, la ventana de subconteo de `aggregateRatings`, el replay de alertas, las alertas que no salen de la cola, etc. |
