# Observaciones de colaboradores — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recomendado) o `superpowers:executing-plans` para ejecutar este plan tarea por tarea. Los pasos usan checkbox (`- [ ]`).

**Goal:** Convertir el backlog de QA de chele moskar y chele alonzo en cambios verificables, corrigiendo antes las tres observaciones cuya premisa es falsa y los cuatro diagnósticos técnicos que apuntan al archivo equivocado.

**Architecture:** El backlog trata cuatro subsistemas casi independientes. El orden real de dependencia **no** es el que propone el PDF: la pieza que destraba todo no es "el estado de la reserva", es **quién crea el ticket de `reparaciones` y cuándo**. Hoy lo crea el mecánico al pulsar "recibir vehículo"; el backlog pide implícitamente que lo cree la aceptación de la cotización. Esa única decisión resuelve A3, A4a, A4b y B2 de golpe, y hasta que se tome, cualquier parche a esos cuatro se contradice entre sí.

**Tech Stack:** Flutter 3.x / Dart 3.11, Provider, Firebase (Firestore, Storage, Cloud Functions v2), `go_router`, tests con `flutter_test` + `@firebase/rules-unit-testing` (`test_rules/`).

**Spec:** `observaciones generales (autodoc).pdf` (raíz del repo) — backlog QA, bloques A–D. Este plan lo discute y lo corrige; no lo obedece.

---

## Global Constraints

- Toda validación de permisos que se implemente en la UI **debe** tener su contraparte en `firestore.rules` o en un callable. La UI no es una frontera de seguridad.
- `keyboardType` **no restringe la entrada en Flutter Web** ni impide pegar desde el portapapeles en ninguna plataforma. Toda restricción numérica va con `inputFormatters` + validador, siguiendo el patrón ya documentado en `lib/features/mechanic/presentation/pages/catalogo_servicios_screen.dart:22`.
- El proyecto apunta a **producción**. Cualquier cambio de esquema Firestore necesita migración o lectura tolerante (`data['campo'] ?? valorPorDefecto`) para documentos ya existentes.
- Prohibido introducir un segundo componente para un flujo que ya tiene uno (la causa raíz de B1). Si hay dos, se refactoriza a uno compartido antes de tocar funcionalidad.
- Todo test nuevo debe fallar antes de la implementación y pasar después. Ver el precedente del proyecto en `CLAUDE.md`: una rama inalcanzable en producción con un test verde no cuenta como verificada.
- Commits frecuentes, uno por tarea, en español, con prefijo convencional (`fix(chat):`, `feat(reservas):`).

---

## Sección 0 — Auditoría crítica del backlog

**No acepto el backlog tal como está escrito.** Trece observaciones, y el resultado de contrastarlas contra el código:

| # | Veredicto | Resumen |
|---|---|---|
| A1 | **Premisa falsa — no implementar** | Pide romper un invariante correcto y deliberado |
| A2 | Bug real, **diagnóstico equivocado** | No falta `StreamBuilder`; el dato está congelado en el mensaje |
| A3 | Bug real, **alcance mal medido** | La ruta ni siquiera conoce la reserva |
| A4a | Bug real, **causa hipotética equivocada** | No hay campo "origen"; no hay lista alguna |
| A4b | **Contradice a A3/B2** | Ambos no pueden ser ciertos con el modelo actual |
| B1 | Confirmado, con matiz | Dos implementaciones, sí; pero la del chat es la buena |
| B2 | Confirmado | Duplicado funcional de A3 |
| B3 | Bug real, **fix propuesto insuficiente** | Ya está el `keyboardType` que piden, y no sirve |
| C1 | Bug real, **diagnóstico equivocado** | No es una URL rota: no hay foto en el código |
| C2 | **Probablemente no reproducible como se describe** | Y no comparte causa con A2 |
| C3 | Confirmado (feature nueva) | Con un riesgo de privacidad que el backlog no menciona |
| C4 | Confirmado, **sobredimensionado** | 5 acciones, 3 de ellas casi gratis, 2 caras |
| C5 | Confirmado, **diagnóstico correcto** | El único de la lista |
| C6 | Confirmado | Ver también la trampa de `pickImage` de S1 |
| D1 | Confirmado, **ya medio construido** | Falta la pantalla, no los datos |

Detalle de los que hay que discutir antes de tocar código.

### A1 — «Solo el mecánico debe poder aceptar/rechazar la reserva». Rechazado.

Esta observación pide **reintroducir un bug que ya se arregló**, y está catalogada como "Crítica (bug de permisos)". No lo es.

La evidencia:

- `lib/core/utils/reserva_acciones.dart` implementa el invariante **«quien propone la fecha vigente no la resuelve»**, con la lógica pura separada y testeada.
- `firestore.rules:766-770` lo refuerza del lado servidor: `request.auth.uid != resource.data.get('id_proponente', ...)` para pasar a `confirmada`/`rechazada`.
- El commit `ad0bc14 feat(reservas): datos geograficos completos y invariante de quien-propone-no-resuelve` es exactamente este trabajo.
- `firestore.rules:722-731` documenta el porqué: **el mecánico también propone fechas** desde el chat (`chat_screen.dart`, `_mostrarSelectorFecha`). Restringir `create` a solo el propietario «rompe la mitad del flujo», dice el comentario, y ya se intentó una vez.

Si el mecánico propone la cita, **el cliente tiene que ser quien la acepta**. Implementar A1 literalmente dejaría al mecánico aceptando su propia propuesta — que es precisamente el bug que A1 dice querer evitar, sólo que con los roles cambiados. La regla correcta no es por rol, es por proponente, y ya está.

Lo que probablemente vieron los colaboradores: entraron como cliente a una reserva **que propuso el mecánico** y vieron los botones aceptar/rechazar. Eso es el comportamiento correcto. La observación es un falso positivo de QA nacido de no distinguir quién originó la propuesta.

**Acción:** no cambiar la lógica. Tarea 1 = cerrar el malentendido en la UI (etiquetar visiblemente quién propuso) + un test de reglas que deje el invariante blindado por escrito, para que esta discusión no se repita en la siguiente ronda de QA.

### A2 — El estado no se refleja en tiempo real. Bug real, hipótesis equivocada.

El PDF dice: «probablemente el widget usa `.get()`/`FutureBuilder` en vez de `.snapshots()`/`StreamBuilder`». Es falso:

- `reserva_repository.dart:12-20` → `streamReservasUsuario` usa `.snapshots()`.
- `reserva_provider.dart:15,49` → `StreamSubscription` + `.listen`. Ya es tiempo real.

La causa real está en `reserva_chat_card.dart:175`:

```dart
final String estado = metadata['estado'] ?? 'pendiente';
```

`metadata` son los `datos_adicionales` **del documento del mensaje**, escritos una sola vez cuando se envió la reserva por chat. El documento de `reservas` cambia de estado; el mensaje no. No hay listener que arreglar — hay una **copia desnormalizada obsoleta**. Ningún `StreamBuilder` sobre la colección de mensajes va a actualizar ese campo, porque el campo nunca se reescribe.

Hay dos salidas, y la elección importa:

- **(a) Que la tarjeta lea la reserva viva** por `metadata['id_reserva']`. Correcto, sin migración, sin escrituras extra. Coste: una suscripción por tarjeta de reserva visible.
- **(b) Que `actualizarEstadoReserva` reescriba también el mensaje.** Más rápido de pintar, pero duplica la fuente de verdad, necesita ampliar las reglas de `update` sobre `mensajes` y deja obsoletos todos los mensajes ya existentes.

**Recomiendo (a).** El coste de suscripciones es acotado (las tarjetas visibles en pantalla), y (b) es exactamente el tipo de desnormalización que causó este bug.

### A3 / B2 — Se puede recibir el vehículo sin reserva aceptada. Real, y más grande de lo que dice el PDF.

Confirmado en `vehicle_search_screen.dart:75` y `:100`: ambos navegan a `context.go('/initiate_service/${vehicle.idVehiculo}')` sin consultar nada.

Pero el PDF subestima el alcance. Dice «probablemente sólo verifica que el vehículo existe». No verifica ni eso: **la ruta es `/initiate_service/:vehiculoId` y no lleva id de reserva** (`app_router.dart:598`). No hay un `if` que corregir. Hay que decidir cuál es la relación que autoriza, consultarla, y propagarla — porque `buscarVehiculoPorPlaca` deliberadamente **no devuelve `id_propietario`** (ver el comentario en `reparacion_repository.dart:16-24`), así que el cliente ni siquiera tiene el dato para armar la consulta por sí solo. Esto se resuelve del lado servidor o no se resuelve.

A3 y B2 son **la misma tarea** descrita dos veces (B2 es A3 restringido a "iniciar servicio" desde buscar vehículo). Se implementan juntas.

### A4b — Contradice a A3/B2. Hay que elegir.

- **A3/B2 dicen:** sin reserva aceptada, el mecánico no ve nada más que placa, nombre, kilometraje e imágenes. Nada de recibir, cotizar ni iniciar servicio.
- **B2 dice:** primero cotizar, después (si se acepta) iniciar servicio.
- **A4b dice:** al aceptar la cotización, el vehículo aparece «instantáneamente» en reparaciones pendientes.

Con el modelo actual esas tres no pueden cumplirse a la vez. `reparaciones` sólo se crea desde `iniciarReparacion` / el callable `iniciarReparacionPorVehiculo`, es decir **cuando el mecánico recibe el vehículo** — y A3 acaba de prohibirle recibirlo. Y encima B2 exige cotizar antes, pero A3 prohíbe cotizar sin reserva aceptada, con lo que la cotización queda encerrada entre dos puertas.

Además, si aceptar la cotización creara el ticket, sería **el cliente** quien escribe en `reparaciones`, y hoy esa colección sólo la escribe el taller o el callable.

La resolución limpia, y la que propongo:

> **La aceptación de la cotización es el evento que crea el ticket de `reparaciones`, en estado `pendiente_recepcion`. "Recibir vehículo" deja de crear nada y pasa a ser la transición `pendiente_recepcion → recibido`.**

Con eso: A4b se cumple (el ticket existe en el instante de aceptar), A3 se cumple (sin ticket, el mecánico sólo ve info pública), B2 se cumple (el único camino al ticket pasa por la cotización), y A4a se cumple sin trabajo extra (la lista sale de `reparaciones`, que no sabe de dónde vino nadie). El ticket lo crea un callable disparado por la aceptación, no el cliente escribiendo directo.

Coste honesto: toca `estadosReparacion`, el kanban, `firestore.rules` de `reparaciones`, y `test_rules/reparaciones.test.js`. Es la tarea más cara del plan. También es la única que hace que las otras tres dejen de pelearse.

### A4a — Causa hipotética equivocada.

El PDF conjetura «probablemente la consulta filtra por un campo que sólo se llena cuando el flujo pasa por mis vehículos (ej. un campo *origen*)». No existe tal campo. `grep` de `origen` sobre `lib/` no devuelve nada relevante, y `watchReparacionesActivas` (`reparacion_repository.dart`) filtra sólo por `id_taller`.

Lo que hay es más simple: **`vehicle_search_screen.dart` no tiene ninguna lista de "mis servicios"** (411 líneas: buscador, búsquedas recientes, tarjeta de asistente). No hay consulta rota; hay pantalla incompleta. Y "los carros aparecen si se buscan desde mis vehículos" es, casi seguro, el historial de **búsquedas recientes** confundido con una lista de servicios activos.

Con la decisión de A4b tomada, A4a se reduce a *pintar* `watchReparacionesActivas(idTaller)` en esa pantalla. Barato — pero sólo después de A4b.

### B1 — Confirmado, con un matiz que cambia la dirección del refactor.

Son dos, sí: `lib/features/chat/presentation/widgets/cotizacion_picker.dart` y `lib/features/mechanic/presentation/pages/initiate_service_screen.dart`. Pero el PDF dice «un mismo componente reutilizado» sin decir cuál sobrevive, y no son intercambiables: `initiate_service_screen.dart` supera las 1100 líneas y mezcla cotización con recepción de vehículo, materiales y finalización. `cotizacion_picker.dart` está acotada al formulario.

**Dirección del refactor: extraer el formulario de `cotizacion_picker` a un widget compartido y hacer que `initiate_service_screen` lo consuma** — no al revés. Y B3 se resuelve dentro de esa extracción, en un solo sitio, en vez de parchear dos.

### B3 — El fix que proponen ya está puesto y no funciona.

El PDF recomienda `TextInputType.number` / `numberWithOptions(decimal: true)`. Eso ya está en `initiate_service_screen.dart:594`. Y aun así entran letras, porque:

- En **Flutter Web** `keyboardType` es prácticamente decorativo: no hay teclado virtual que restringir y el `<input>` acepta lo que sea.
- En móvil no impide pegar desde el portapapeles — cosa que el propio PDF nota en «A revisar», sin conectar que por eso su propia recomendación principal es insuficiente.

`grep inputFormatters` sobre `initiate_service_screen.dart` → **cero resultados**. Ese es el fix, con el patrón anclado ya documentado en `catalogo_servicios_screen.dart:22` (usar `FilteringTextInputFormatter.allow` con patrón anclado; el no anclado borra todo el campo).

Severidad: el PDF dice «Baja-media». Discrepo — es **alta**. `CotizacionModel.fromMap` hace `map['mano_de_obra']?.toDouble()`; un string en ese campo revienta el parseo de la cotización entera para ambas partes, no "corrompe cálculos de totales".

### C1 — No es una foto que no carga. Es una foto que no existe.

El PDF pide revisar «si la URL se guarda correctamente y si el widget maneja el error». Ninguna de las dos:

```dart
// conversaciones_list_screen.dart:144
leading: CircleAvatar(
  radius: 28,
  backgroundColor: colors.primary.withValues(alpha: 0.2),
  child: Icon(Icons.person, color: colors.primary),   // hardcodeado
),
```

Idéntico en `chat_screen.dart:391`. **Nunca se intenta cargar una imagen.** Y `ConversacionModel` no tiene ningún campo de foto (`id`, `idPropietario`, `idMecanico`, `nombrePropietario`, `nombreMecanico`, `idTaller`, `idVehiculo`, `ultimoMensaje`, …). El placeholder que el PDF pide "en vez de dejar el espacio vacío" es literalmente lo único que hay hoy.

Esto no es "Media / bug de carga": es una feature no implementada que además necesita decidir **de dónde sale la URL**. `chat_screen.dart:403` ya hace un `FutureBuilder` por `receptorId` para el nombre; ampliarlo a la foto es el camino barato. En la lista de conversaciones, en cambio, un `FutureBuilder` por fila es una lectura por conversación en cada rebuild — ahí conviene denormalizar la URL en el documento de conversación, o cachear el perfil.

### C2 — Sospechoso. Verificar antes de "arreglar".

El PDF afirma que comparte causa con A2 («falta de listener en vivo»). No puede: A2 no es un problema de listener. Y `ChatProvider` ya trae stream de mensajes (`test/features/chat/presentation/chat_provider_test.dart` existe y lo cubre).

Además, `ConversacionModel` tiene `noLeidosPropietario`/`noLeidosMecanico` — contadores por conversación — y **ningún campo de estado por mensaje** (enviado/entregado/leído). Si no hay ese campo, no hay tres checks que actualizar; hay como mucho uno derivado del contador.

Antes de escribir una línea, hay que reproducirlo: ¿es que el check no cambia, o es que el modelo de checks que los QA creen ver (los tres de WhatsApp) no existe? Son dos trabajos de tamaño muy distinto. Esta es la única entrada del plan que empieza con `superpowers:systematic-debugging` en vez de con un test.

### C4 — Confirmado pero sobredimensionado. Partirlo.

«Editar, borrar, copiar, responder, reenviar» se lee como una lista homogénea. No lo es:

- **Copiar** — trivial, `Clipboard.setData`, sin backend.
- **Borrar** — barato; las reglas ya permiten `delete` a los participantes (`firestore.rules:708-713`). Decidir: ¿para ambos o sólo para el emisor?
- **Editar** — necesita ampliar las reglas de `update` sobre `mensajes` para acotar qué campos son editables, más flag `editado`. Y hay que decidir si un mensaje de tipo reserva/cotización es editable (**no debe serlo**: editar el texto de una cotización ya aceptada es un agujero de negocio, y el PDF no lo contempla).
- **Responder** — campo nuevo `respuesta_a` + render de la cita.
- **Reenviar** — selector de conversación destino + revalidación de permisos en destino.

Se implementa como tres tareas separadas por coste. Copiar/borrar entregan valor visible el primer día; reenviar puede quedar fuera de esta ronda sin que nadie lo note.

### C5 — El único diagnóstico del PDF que es correcto.

`chat_screen.dart:178` hace `_controller.clear()` y no hay **ni un solo `FocusNode`** en el archivo (`grep FocusNode` → cero). El PDF acierta de lleno. Barato, alto impacto, y es lo primero que se debe hacer del bloque C.

### D1 — Confirmado, y a mitad de camino.

`workshop_directory_screen.dart` ya resuelve logo de galería, calificación, reseñas, especialidad y municipio (`:963-990`), y tiene `context.push('/chat/$chatId')`. Lo que falta es la **pantalla de perfil público del taller** y su ruta; los datos y el patrón de URL de galería (`GaleriaTaller.urlDe`) ya existen y son reutilizables. El PDF lo marca «funcionalidad nueva» — es más bien "pantalla que falta sobre datos que ya están".

Una advertencia que el PDF no hace: pide mostrar **«lista de empleados del taller»** en una vista pública para clientes. `empleados` tiene sus propias reglas (`test_rules/empleados.test.js`) y es información de personas. Antes de exponerla hay que definir qué campos son públicos (nombre y especialidad, sí; teléfono, DUI o correo, no) y reflejarlo en las reglas. No se expone la colección entera.

### Observación del Inge — «notificaciones de mensajes en pantalla»

Es una línea sin especificar y son al menos tres cosas distintas: badge en la pestaña de chat, snackbar/banner in-app con la app abierta, y push con la app cerrada. El repo ya tiene bootstrap de push (`test/main_push_bootstrap_test.dart`). **Fuera de este plan** hasta que se aclare cuál de las tres se pide; queda anotado al final.

---

## Orden de ejecución (y por qué no es el del PDF)

El PDF ordena A → B → C → D con «A destraba lo demás». Sólo es cierto a medias: A1 no destraba nada (no existe) y A2 pertenece al bloque de chat, no al de reservas. El orden real por dependencia y por valor entregado:

1. **Tareas 1–3 (baratas, sin dependencias):** C5 foco, B3 formatters, A1 aclaración + test de blindaje. Valor visible en el primer día.
2. **Tarea 4 (decisión de arquitectura):** ticket creado al aceptar la cotización. Destraba A3, A4a, A4b y B2.
3. **Tareas 5–7:** gating de A3/B2, lista de A4a, refactor de cotización B1.
4. **Tareas 8–12:** bloque C (A2 incluido aquí, que es donde le toca) y D1.

---

## Tarea 1: C5 — El campo de texto conserva el foco tras enviar

**Files:**
- Modify: `lib/features/chat/presentation/pages/chat_screen.dart:51,167-178,596,626`
- Test: `test/features/chat/presentation/pages/chat_screen_focus_test.dart` (crear)

**Interfaces:**
- Produces: `_ChatScreenState._inputFocusNode` (privado; el test lo observa a través del `TextField`, no del estado).

- [ ] **Step 1: Escribir el test que falla**

```dart
// test/features/chat/presentation/pages/chat_screen_focus_test.dart
testWidgets('el campo de texto conserva el foco despues de enviar', (tester) async {
  await tester.pumpWidget(await construirChatScreenDePrueba(tester));
  final campo = find.byKey(const Key('chat_input_field'));

  await tester.tap(campo);
  await tester.pumpAndSettle();
  await tester.enterText(campo, 'hola');
  await tester.testTextInput.receiveAction(TextInputAction.send);
  await tester.pumpAndSettle();

  final widget = tester.widget<TextField>(campo);
  expect(widget.controller!.text, isEmpty, reason: 'el texto se limpia');
  expect(widget.focusNode!.hasFocus, isTrue, reason: 'pero el foco se conserva');
});
```

- [ ] **Step 2: Correr el test y verificar que falla**

Run: `flutter test test/features/chat/presentation/pages/chat_screen_focus_test.dart`
Expected: FAIL — `widget.focusNode` es `null` (hoy no se pasa ninguno).

- [ ] **Step 3: Implementar**

En `_ChatScreenState`, junto a `_controller` (línea 51):

```dart
final FocusNode _inputFocusNode = FocusNode();
```

En `dispose()`, junto al `_controller.dispose()` existente:

```dart
_inputFocusNode.dispose();
```

En `_enviarMensaje`, justo después de `_controller.clear();` (línea 178):

```dart
// Limpiar el texto no debe costar el foco: sin esto el teclado se cierra en
// movil y hay que volver a tocar la barra entre mensaje y mensaje.
_inputFocusNode.requestFocus();
```

Y en el `TextField` del compositor (alrededor de la línea 596), añadir:

```dart
key: const Key('chat_input_field'),
focusNode: _inputFocusNode,
textInputAction: TextInputAction.send,
```

- [ ] **Step 4: Correr el test y verificar que pasa**

Run: `flutter test test/features/chat/presentation/pages/chat_screen_focus_test.dart`
Expected: PASS

- [ ] **Step 5: Verificar en web (el PDF menciona «todos los dispositivos»)**

Run: `flutter build web --dart-define-from-file=app.env && flutter run -d chrome`
Enviar tres mensajes seguidos con Enter sin tocar la barra. Los tres deben salir.
(Ver memoria del proyecto: Playwright exige `flutter build web`, no `flutter run`.)

- [ ] **Step 6: Commit**

```bash
git add test/features/chat/presentation/pages/chat_screen_focus_test.dart lib/features/chat/presentation/pages/chat_screen.dart
git commit -m "fix(chat): conservar el foco del compositor tras enviar (C5)"
```

---

## Tarea 2: B3 — «Mano de obra» rechaza texto de verdad

**Files:**
- Modify: `lib/features/mechanic/presentation/pages/initiate_service_screen.dart:585-600,1140-1150`
- Create: `lib/core/utils/input_formatters.dart`
- Test: `test/core/utils/input_formatters_test.dart` (crear)

**Interfaces:**
- Produces: `montoInputFormatters` — `List<TextInputFormatter>`, para todo campo de dinero de la app.

- [ ] **Step 1: Escribir el test que falla**

```dart
// test/core/utils/input_formatters_test.dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/utils/input_formatters.dart';

TextEditingValue _aplicar(String viejo, String nuevo) {
  var valor = TextEditingValue(text: nuevo, selection: TextSelection.collapsed(offset: nuevo.length));
  for (final f in montoInputFormatters) {
    valor = f.formatEditUpdate(
      TextEditingValue(text: viejo, selection: TextSelection.collapsed(offset: viejo.length)),
      valor,
    );
  }
  return valor;
}

void main() {
  test('acepta enteros y decimales', () {
    expect(_aplicar('12', '12.5').text, '12.5');
    expect(_aplicar('', '80').text, '80');
  });

  test('rechaza letras sin borrar lo ya escrito', () {
    // El patron anclado importa: con uno no anclado, escribir una letra
    // vaciaba el campo entero (ver catalogo_servicios_screen.dart:22).
    expect(_aplicar('12.5', '12.5a').text, '12.5');
  });

  test('rechaza texto pegado desde el portapapeles', () {
    expect(_aplicar('', 'cincuenta dolares').text, '');
  });

  test('rechaza un segundo punto decimal', () {
    expect(_aplicar('12.5', '12.5.3').text, '12.5');
  });
}
```

- [ ] **Step 2: Correr y verificar que falla**

Run: `flutter test test/core/utils/input_formatters_test.dart`
Expected: FAIL — `input_formatters.dart` no existe.

- [ ] **Step 3: Implementar**

```dart
// lib/core/utils/input_formatters.dart
import 'package:flutter/services.dart';

/// Formatters para campos de dinero (mano de obra, materiales, total).
///
/// `keyboardType` NO basta: en Flutter Web es decorativo (no hay teclado
/// virtual que restringir) y en movil no impide pegar del portapapeles.
/// El patron va anclado con `^...$` a proposito — uno sin anclar hace que
/// `FilteringTextInputFormatter.allow` filtre caracter a caracter y borre
/// el campo entero al primer caracter invalido.
final List<TextInputFormatter> montoInputFormatters = <TextInputFormatter>[
  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$')),
];
```

- [ ] **Step 4: Correr y verificar que pasa**

Run: `flutter test test/core/utils/input_formatters_test.dart`
Expected: PASS

- [ ] **Step 5: Aplicarlo en los campos de dinero**

En `initiate_service_screen.dart`, en `_BoxedField` añadir el parámetro `inputFormatters` y pasarlo al `TextField` interno. Después, en el campo «Mano de obra» (línea ~590) y en el de costo total (línea ~1146):

```dart
_BoxedField(
  icon: Icons.build_circle_outlined,
  label: 'Mano de obra',
  controller: _manoDeObraController,
  keyboardType: const TextInputType.numberWithOptions(decimal: true),
  inputFormatters: montoInputFormatters,
),
```

Repetir en `cotizacion_picker.dart:348,363,386`.

- [ ] **Step 6: Correr la suite y verificar en web**

Run: `flutter test && flutter analyze`
Expected: PASS, sin nuevos warnings.
En Chrome: teclear letras en «Mano de obra» y pegar `cincuenta` — ninguna de las dos debe entrar.

- [ ] **Step 7: Commit**

```bash
git add lib/core/utils/input_formatters.dart test/core/utils/input_formatters_test.dart lib/features/mechanic/presentation/pages/initiate_service_screen.dart lib/features/chat/presentation/widgets/cotizacion_picker.dart
git commit -m "fix(cotizacion): restringir campos de monto con inputFormatters, no solo keyboardType (B3)"
```

---

## Tarea 3: A1 — Blindar el invariante y hacerlo legible en pantalla

No se cambia la lógica de permisos. Se cierra el malentendido que generó la observación y se deja el invariante protegido por test contra futuros "arreglos".

**Files:**
- Modify: `lib/features/chat/presentation/widgets/cards/reserva_chat_card.dart:196-250`
- Test: `test_rules/reservas.test.js` (crear), `test/core/utils/reserva_acciones_test.dart` (ampliar si existe; crear si no)

- [ ] **Step 1: Test de reglas que fija el invariante en ambas direcciones**

```javascript
// test_rules/reservas.test.js
const { conCliente, conMecanico, crearReserva } = require('./helpers');

describe('reservas: quien propone no resuelve', () => {
  it('el mecanico NO puede confirmar la reserva que el mismo propuso', async () => {
    await crearReserva({ id_proponente: 'mec1', id_mecanico: 'mec1', id_propietario: 'cli1', estado: 'pendiente' });
    await assertFails(conMecanico('mec1').doc('reservas/r1').update({ estado: 'confirmada' }));
  });

  it('el cliente SI puede confirmar la reserva que propuso el mecanico', async () => {
    // Este caso es el que QA reporto como bug (A1). Es el comportamiento correcto:
    // si el mecanico propone la fecha, el cliente es quien la resuelve.
    await crearReserva({ id_proponente: 'mec1', id_mecanico: 'mec1', id_propietario: 'cli1', estado: 'pendiente' });
    await assertSucceeds(conCliente('cli1').doc('reservas/r1').update({ estado: 'confirmada' }));
  });

  it('el cliente NO puede confirmar la reserva que el mismo propuso', async () => {
    await crearReserva({ id_proponente: 'cli1', id_mecanico: 'mec1', id_propietario: 'cli1', estado: 'pendiente' });
    await assertFails(conCliente('cli1').doc('reservas/r1').update({ estado: 'confirmada' }));
  });

  it('un tercero no puede tocar la reserva', async () => {
    await crearReserva({ id_proponente: 'cli1', id_mecanico: 'mec1', id_propietario: 'cli1', estado: 'pendiente' });
    await assertFails(conCliente('otro').doc('reservas/r1').update({ estado: 'confirmada' }));
  });
});
```

- [ ] **Step 2: Correr y confirmar que los cuatro pasan ya**

Run: `/test rules` (o `cd test_rules && npm test -- reservas.test.js`)
Expected: **PASS los cuatro.** Si alguno falla, el invariante sí está roto y este plan cambia: se abre una tarea de corrección antes de seguir. Si pasan los cuatro, queda demostrado que A1 es un falso positivo y el test es la prueba escrita.

- [ ] **Step 3: Hacer visible quién propuso, en la tarjeta**

En `reserva_chat_card.dart`, dentro del `Column` del `child`, antes del bloque `if (acciones.tieneAcciones)`:

```dart
// QA reporto como bug de permisos (A1) el ver los botones aceptar/rechazar
// siendo cliente. No lo es: el mecanico tambien propone fechas y entonces
// resuelve el cliente. Se hace explicito para que no vuelva a leerse mal.
if (estado == 'pendiente') ...[
  const SizedBox(height: 8),
  Text(
    isMe ? 'Propusiste esta fecha — espera respuesta'
         : 'Te propusieron esta fecha',
    style: AppTextStyles.bodySmall.copyWith(color: colors.textSecondary),
  ),
],
```

- [ ] **Step 4: Test de widget de la etiqueta**

```dart
testWidgets('la tarjeta dice quien propuso la fecha', (tester) async {
  await tester.pumpWidget(construirTarjetaReserva(isMe: false, estado: 'pendiente'));
  expect(find.text('Te propusieron esta fecha'), findsOneWidget);
  expect(find.text('Aceptar'), findsOneWidget); // correcto, no es un bug

  await tester.pumpWidget(construirTarjetaReserva(isMe: true, estado: 'pendiente'));
  expect(find.text('Propusiste esta fecha — espera respuesta'), findsOneWidget);
  expect(find.text('Aceptar'), findsNothing);
});
```

Run: `flutter test test/features/chat/presentation/widgets/reserva_chat_card_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add test_rules/reservas.test.js lib/features/chat/presentation/widgets/cards/reserva_chat_card.dart test/features/chat/presentation/widgets/reserva_chat_card_test.dart
git commit -m "test(reservas): blindar invariante quien-propone-no-resuelve y etiquetarlo en la UI (A1)"
```

---

## Tarea 4: A4b — La aceptación de la cotización crea el ticket de reparación

**La tarea central del plan.** Cambia quién crea `reparaciones` y cuándo. Léase la Sección 0 → A4b antes de empezar.

**Files:**
- Modify: `lib/core/models/reparacion_model.dart` (añadir `pendiente_recepcion` al inicio de `estadosReparacion`)
- Modify: `functions/index.js` (nuevo trigger/callable)
- Modify: `firestore.rules` (bloque `reparaciones`)
- Modify: `lib/features/mechanic/presentation/pages/reparaciones_kanban_screen.dart` (columna nueva)
- Modify: `lib/features/mechanic/data/repositories/reparacion_repository.dart` (`iniciarReparacion` deja de crear; `recibirVehiculo` transiciona)
- Test: `test_rules/reparaciones.test.js` (ampliar), `functions/test/aceptar_cotizacion.test.js` (crear), `test/features/mechanic/reparacion_repository_test.dart`

**Interfaces:**
- Consumes: `CotizacionModel.estado` (`aceptada`), reglas de `cotizaciones` (`firestore.rules:790+`, sólo `estado` escribible tras crear).
- Produces:
  - `estadosReparacion` = `['pendiente_recepcion', 'recibido', ..., 'listo_para_entrega']`
  - Cloud Function `onCotizacionAceptada` (trigger `onDocumentUpdated` sobre `cotizaciones/{id}`) → crea `reparaciones/{id}` con `estado: 'pendiente_recepcion'`, `id_cotizacion`, `id_vehiculo`, `id_taller`, `id_propietario`.
  - `ReparacionRepository.recibirVehiculo({required String idReparacion})` → `Future<void>`, transiciona `pendiente_recepcion → recibido`.

- [ ] **Step 1: Test de la function que falla**

```javascript
// functions/test/aceptar_cotizacion.test.js
describe('onCotizacionAceptada', () => {
  it('crea el ticket de reparacion en pendiente_recepcion', async () => {
    await db.doc('cotizaciones/c1').set({
      id_mecanico: 'mec1', id_propietario: 'cli1', id_vehiculo: 'v1',
      id_taller: 't1', estado: 'pendiente',
    });
    await db.doc('cotizaciones/c1').update({ estado: 'aceptada' });
    await esperarTrigger();

    const snap = await db.collection('reparaciones').where('id_cotizacion', '==', 'c1').get();
    expect(snap.size).toBe(1);
    expect(snap.docs[0].data().estado).toBe('pendiente_recepcion');
  });

  it('no duplica el ticket si la cotizacion se reescribe a aceptada', async () => {
    // El trigger debe ser idempotente: onDocumentUpdated se reintenta.
    await db.doc('cotizaciones/c1').update({ estado: 'aceptada' });
    await esperarTrigger();
    const snap = await db.collection('reparaciones').where('id_cotizacion', '==', 'c1').get();
    expect(snap.size).toBe(1);
  });

  it('no crea nada si la cotizacion pasa a rechazada', async () => {
    await db.doc('cotizaciones/c2').set({ estado: 'pendiente', id_vehiculo: 'v2', id_taller: 't1' });
    await db.doc('cotizaciones/c2').update({ estado: 'rechazada' });
    await esperarTrigger();
    const snap = await db.collection('reparaciones').where('id_cotizacion', '==', 'c2').get();
    expect(snap.empty).toBe(true);
  });
});
```

- [ ] **Step 2: Correr contra el emulador y verificar que falla**

Run: `firebase emulators:exec --only firestore,functions "cd functions && npm test -- aceptar_cotizacion"`
Expected: FAIL — la function no existe.

- [ ] **Step 3: Implementar el trigger**

```javascript
// functions/index.js
exports.onCotizacionAceptada = onDocumentUpdated('cotizaciones/{cotizacionId}', async (event) => {
  const antes = event.data.before.data();
  const despues = event.data.after.data();
  if (antes.estado === 'aceptada' || despues.estado !== 'aceptada') return;

  const db = getFirestore();
  // Idempotencia: el id del ticket se deriva del id de la cotizacion, asi un
  // reintento del trigger escribe el mismo documento en vez de duplicarlo.
  const ref = db.collection('reparaciones').doc(`cot_${event.params.cotizacionId}`);
  const ahora = FieldValue.serverTimestamp();
  await ref.set({
    id_reparacion: ref.id,
    id_cotizacion: event.params.cotizacionId,
    id_vehiculo: despues.id_vehiculo,
    id_taller: despues.id_taller,
    id_propietario: despues.id_propietario,
    placa: despues.placa ?? '',
    estado: 'pendiente_recepcion',
    historial_estados: [{ estado: 'pendiente_recepcion', timestamp: new Date() }],
    fecha_creacion: ahora,
    fecha_actualizacion: ahora,
  }, { merge: true });
});
```

- [ ] **Step 4: Correr y verificar que pasan los tres**

Run: `firebase emulators:exec --only firestore,functions "cd functions && npm test -- aceptar_cotizacion"`
Expected: PASS

- [ ] **Step 5: Añadir el estado nuevo al principio del pipeline**

```dart
// lib/core/models/reparacion_model.dart
const estadosReparacion = <String>[
  'pendiente_recepcion',   // creado al aceptarse la cotizacion, el vehiculo aun no llega
  'recibido',
  // ... el resto tal como esta hoy, sin reordenar
];
```

Y en `reparaciones_kanban_screen.dart`, en `etiquetasEstado`:

```dart
'pendiente_recepcion': 'Por recibir',
```

El kanban itera `estadosReparacion` para las columnas, así que la columna aparece sola. Verificar que la lógica de «no retroceder» de `cambiarEstado` sigue siendo correcta con el índice desplazado.

- [ ] **Step 6: Sustituir la creación por una transición en el repositorio**

```dart
/// El ticket ya existe cuando el cliente acepta la cotizacion (trigger
/// `onCotizacionAceptada`). "Recibir vehiculo" ya no crea nada: solo mueve
/// el ticket de 'pendiente_recepcion' a 'recibido'. Sin esto, el mecanico
/// podia abrir un ticket sin que nadie hubiera aceptado nada (A3/B2).
Future<void> recibirVehiculo({required String idReparacion}) {
  return cambiarEstado(idReparacion: idReparacion, nuevoEstado: 'recibido');
}
```

Marcar `iniciarReparacion` y `iniciarOReutilizarPorVehiculo` como `@Deprecated('El ticket lo crea onCotizacionAceptada')` y quitar sus llamadas desde `InitiateServiceScreen`. **No borrarlas todavía** — hay tickets en producción creados por esa vía.

- [ ] **Step 7: Cerrar la creación desde cliente en las reglas**

```
// firestore.rules, bloque reparaciones
// Ya nadie crea reparaciones desde el cliente: el unico creador es el
// trigger onCotizacionAceptada (Admin SDK, que se salta las reglas).
allow create: if false;
```

Ampliar `test_rules/reparaciones.test.js`:

```javascript
it('ni el mecanico ni el cliente pueden crear un ticket a mano', async () => {
  await assertFails(conMecanico('mec1').collection('reparaciones').add({ id_taller: 't1' }));
  await assertFails(conCliente('cli1').collection('reparaciones').add({ id_taller: 't1' }));
});

it('el mecanico del taller si puede mover el estado del ticket', async () => {
  await sembrarReparacion({ id: 'r1', id_taller: 't1', estado: 'pendiente_recepcion' });
  await assertSucceeds(conMecanico('mec1', { taller: 't1' }).doc('reparaciones/r1').update({ estado: 'recibido' }));
});
```

- [ ] **Step 8: Correr toda la suite**

Run: `/test all`
Expected: PASS. Los tests que asumían que `InitiateServiceScreen` crea el ticket van a fallar — **actualizarlos, no relajarlos**: el comportamiento cambió a propósito.

- [ ] **Step 9: Commit**

```bash
git add functions/ firestore.rules test_rules/reparaciones.test.js lib/core/models/reparacion_model.dart lib/features/mechanic/
git commit -m "feat(reparaciones): el ticket nace al aceptarse la cotizacion, no al recibir el vehiculo (A4b)"
```

- [ ] **Step 10: Nota de despliegue**

Este cambio requiere desplegar functions **y** reglas juntos. Usar la skill `firebase-deploy-check` antes. Los tickets antiguos no tienen `id_cotizacion`; el kanban debe tolerar su ausencia.

---

## Tarea 5: A3 / B2 — Sin ticket aceptado, sólo información pública

Depende de la Tarea 4.

**Files:**
- Modify: `lib/features/mechanic/presentation/pages/vehicle_search_screen.dart:75,100`
- Modify: `lib/core/router/app_router.dart:598-606`
- Modify: `lib/features/mechanic/presentation/pages/initiate_service_screen.dart`
- Create: `lib/features/mechanic/presentation/pages/vehicle_public_view_screen.dart`
- Test: `test/features/mechanic/presentation/pages/vehicle_gating_test.dart`

**Interfaces:**
- Consumes: `ReparacionRepository.buscarReparacionActiva`, `estadosReparacion`.
- Produces: `VehiclePublicViewScreen` — recibe `VehicleModel`, pinta **sólo** nombre, placa, kilometraje e imágenes; sin acciones.

- [ ] **Step 1: Tests que fallan, uno por punto de entrada**

```dart
testWidgets('sin reparacion aceptada, buscar vehiculo lleva a la vista publica', (tester) async {
  await tester.pumpWidget(construirBuscarVehiculo(reparacionExistente: null));
  await buscarPlaca(tester, 'P123456');
  await tester.pumpAndSettle();

  expect(find.byType(VehiclePublicViewScreen), findsOneWidget);
  expect(find.text('P123456'), findsOneWidget);
  expect(find.text('Recibir vehículo'), findsNothing);
  expect(find.text('Iniciar servicio'), findsNothing);
  expect(find.text('Historial'), findsNothing);
});

testWidgets('con reparacion en pendiente_recepcion, se desbloquea recibir', (tester) async {
  await tester.pumpWidget(construirBuscarVehiculo(
    reparacionExistente: reparacionFake(estado: 'pendiente_recepcion'),
  ));
  await buscarPlaca(tester, 'P123456');
  await tester.pumpAndSettle();

  expect(find.byType(InitiateServiceScreen), findsOneWidget);
  expect(find.text('Recibir vehículo'), findsOneWidget);
});

testWidgets('el gating es identico llegando desde el chat', (tester) async {
  // Misma fuente de verdad en ambas entradas: lo exige el PDF y es lo unico
  // que evita que este bug reaparezca por un solo lado.
  await tester.pumpWidget(construirChatConTarjetaVehiculo(reparacionExistente: null));
  await tester.tap(find.text('Ver vehículo'));
  await tester.pumpAndSettle();
  expect(find.byType(VehiclePublicViewScreen), findsOneWidget);
});
```

- [ ] **Step 2: Correr y verificar que fallan**

Run: `flutter test test/features/mechanic/presentation/pages/vehicle_gating_test.dart`
Expected: FAIL — `VehiclePublicViewScreen` no existe y hoy ambas entradas van directo a `InitiateServiceScreen`.

- [ ] **Step 3: Crear la vista pública**

`VehiclePublicViewScreen`: `AppCard` con la galería del vehículo, nombre, placa, kilometraje, y un aviso — «Necesitas una cotización aceptada por el propietario para trabajar en este vehículo». Ninguna acción, ningún botón de navegación hacia el servicio.

- [ ] **Step 4: Un solo punto de decisión, compartido**

```dart
// lib/features/mechanic/presentation/navegacion_vehiculo.dart
/// Unico lugar que decide a donde lleva tocar un vehiculo siendo mecanico.
/// Buscar-vehiculo y el chat lo llaman igual: si cada entrada decide por su
/// cuenta, una de las dos se queda atras (fue exactamente lo que paso).
Future<void> abrirVehiculoComoMecanico(
  BuildContext context,
  VehicleModel vehiculo,
  String idTaller,
) async {
  final idReparacion = await context.read<ReparacionRepository>()
      .buscarReparacionActiva(idVehiculo: vehiculo.idVehiculo, idTaller: idTaller);

  if (!context.mounted) return;
  if (idReparacion == null) {
    context.go('/vehiculo_publico/${vehiculo.idVehiculo}', extra: vehiculo);
  } else {
    context.go('/initiate_service/$idReparacion', extra: vehiculo);
  }
}
```

Reemplazar las dos llamadas de `vehicle_search_screen.dart:75,100` y la equivalente del chat por esta función. **Cambiar la ruta `/initiate_service/:vehiculoId` a `/initiate_service/:reparacionId`** — la pantalla ya no puede operar sobre un vehículo suelto (`app_router.dart:598`).

- [ ] **Step 5: Correr y verificar que pasan**

Run: `flutter test test/features/mechanic/`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/features/mechanic/ lib/core/router/app_router.dart test/features/mechanic/
git commit -m "feat(mecanico): gating de vehiculo por reparacion aceptada en ambas entradas (A3/B2)"
```

---

## Tarea 6: A4a — Lista de «Mis servicios» en Buscar Vehículo

Depende de las Tareas 4 y 5. Barata una vez que `reparaciones` es la única fuente de verdad.

**Files:**
- Modify: `lib/features/mechanic/presentation/pages/vehicle_search_screen.dart` (sección nueva bajo `_RecentSearches`)
- Test: `test/features/mechanic/presentation/pages/vehicle_search_mis_servicios_test.dart`

- [ ] **Step 1: Test que falla**

```dart
testWidgets('mis servicios lista las reparaciones del taller sin importar el origen', (tester) async {
  // La conjetura del PDF (un campo "origen" que filtra) no existe: la unica
  // condicion es id_taller. Este test lo fija.
  await tester.pumpWidget(construirBuscarVehiculo(reparaciones: [
    reparacionFake(placa: 'P111111', estado: 'pendiente_recepcion'),
    reparacionFake(placa: 'P222222', estado: 'recibido'),
  ]));
  await tester.pumpAndSettle();

  expect(find.text('P111111'), findsOneWidget);
  expect(find.text('P222222'), findsOneWidget);
});
```

- [ ] **Step 2: Correr y verificar que falla**

Run: `flutter test test/features/mechanic/presentation/pages/vehicle_search_mis_servicios_test.dart`
Expected: FAIL — no se pinta ninguna lista.

- [ ] **Step 3: Implementar**

Añadir a `VehicleSearchScreen` una sección `_MisServicios` que consuma `context.watch<ReparacionProvider>().reparaciones` (ya es un stream en vivo; no hace falta nada nuevo en la capa de datos) y navegue con `abrirVehiculoComoMecanico`.

- [ ] **Step 4: Correr y verificar que pasa**

Run: `flutter test test/features/mechanic/`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/mechanic/presentation/pages/vehicle_search_screen.dart test/features/mechanic/
git commit -m "feat(mecanico): listar mis servicios activos en buscar vehiculo (A4a)"
```

---

## Tarea 7: B1 — Un solo formulario de cotización

**Files:**
- Create: `lib/features/chat/presentation/widgets/cotizacion_form.dart`
- Modify: `lib/features/chat/presentation/widgets/cotizacion_picker.dart`
- Modify: `lib/features/mechanic/presentation/pages/initiate_service_screen.dart`
- Test: `test/features/chat/presentation/widgets/cotizacion_form_test.dart`

**Interfaces:**
- Produces: `CotizacionForm` — `StatefulWidget` con `onSubmit(CotizacionModel)`; encapsula materiales, mano de obra (con `montoInputFormatters` de la Tarea 2), total y validación.

- [ ] **Step 1: Test de paridad entre las dos entradas**

```dart
testWidgets('el mismo formulario aparece en chat y en initiate_service', (tester) async {
  for (final construir in [construirCotizacionDesdeChat, construirCotizacionDesdeBuscarVehiculo]) {
    await tester.pumpWidget(await construir(tester));
    await tester.pumpAndSettle();

    expect(find.byType(CotizacionForm), findsOneWidget);
    expect(find.byKey(const Key('cotizacion_mano_de_obra')), findsOneWidget);
    expect(find.byKey(const Key('cotizacion_materiales')), findsOneWidget);
    expect(find.byKey(const Key('cotizacion_total')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('cotizacion_mano_de_obra')), 'abc');
    await tester.pump();
    expect(tester.widget<TextField>(find.byKey(const Key('cotizacion_mano_de_obra'))).controller!.text, isEmpty);
  }
});
```

- [ ] **Step 2: Correr y verificar que falla**

Run: `flutter test test/features/chat/presentation/widgets/cotizacion_form_test.dart`
Expected: FAIL — `CotizacionForm` no existe.

- [ ] **Step 3: Extraer el formulario de `cotizacion_picker.dart` a `cotizacion_form.dart`**

Sale de `cotizacion_picker`, no de `initiate_service_screen`: `cotizacion_picker` está acotada al formulario, mientras que `initiate_service_screen` supera las 1100 líneas mezclando cotización, recepción, materiales y finalización.

- [ ] **Step 4: Consumirlo desde ambos lados**

`cotizacion_picker` lo envuelve en su bottom sheet; `initiate_service_screen` reemplaza su bloque de campos por `CotizacionForm`, borrando los controllers duplicados.

- [ ] **Step 5: Correr y verificar que pasa**

Run: `flutter test && flutter analyze`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/features/chat/presentation/widgets/ lib/features/mechanic/presentation/pages/initiate_service_screen.dart test/features/chat/
git commit -m "refactor(cotizacion): un solo formulario compartido entre chat y buscar vehiculo (B1)"
```

---

## Tarea 8: A2 — La tarjeta de reserva lee la reserva viva

**Files:**
- Modify: `lib/features/chat/presentation/widgets/cards/reserva_chat_card.dart:170-200`
- Test: `test/features/chat/presentation/widgets/reserva_chat_card_estado_test.dart`

- [ ] **Step 1: Test que falla**

```dart
testWidgets('la tarjeta refleja el estado del documento de reserva, no el del mensaje', (tester) async {
  // El mensaje quedo congelado en 'pendiente' cuando se envio. La reserva ya
  // es 'confirmada'. Esta discrepancia ES el bug A2 — no falta un listener,
  // sobra una copia desnormalizada.
  final fake = FakeFirebaseFirestore();
  await fake.doc('reservas/r1').set({'estado': 'confirmada', 'id_proponente': 'cli1'});

  await tester.pumpWidget(construirTarjeta(
    firestore: fake,
    metadata: {'id_reserva': 'r1', 'estado': 'pendiente', 'fecha': '2026-09-10', 'hora': '10:00'},
  ));
  await tester.pumpAndSettle();

  expect(find.text('Confirmada'), findsOneWidget);
  expect(find.text('Pendiente'), findsNothing);
});

testWidgets('sin id_reserva cae al estado del mensaje sin romperse', (tester) async {
  // Los mensajes de reserva ya existentes en produccion pueden no traerlo.
  await tester.pumpWidget(construirTarjeta(metadata: {'estado': 'pendiente', 'fecha': '2026-09-10'}));
  await tester.pumpAndSettle();
  expect(find.text('Pendiente'), findsOneWidget);
});
```

- [ ] **Step 2: Correr y verificar que falla**

Run: `flutter test test/features/chat/presentation/widgets/reserva_chat_card_estado_test.dart`
Expected: FAIL — el primero muestra «Pendiente»; hoy lee `metadata['estado']`.

- [ ] **Step 3: Implementar**

Envolver el cuerpo de la tarjeta en un `StreamBuilder` sobre `reservas/{id}` cuando `metadata['id_reserva']` existe:

```dart
// `metadata` es una copia congelada al enviarse el mensaje: la reserva cambia
// de estado y el mensaje no. Se lee el documento vivo y `metadata` queda solo
// como respaldo para los mensajes antiguos sin id_reserva.
final estadoVivo = snapshot.data?.data()?['estado'] as String?;
final estado = estadoVivo ?? metadata['estado'] ?? 'pendiente';
final idProponente = snapshot.data?.data()?['id_proponente'] as String?
    ?? (isMe ? currentUserId : '__contraparte__');
```

Nótese que esto además mejora la Tarea 3: con la reserva viva ya se dispone del `id_proponente` real, y desaparece el `'__contraparte__'` sintético.

- [ ] **Step 4: Correr y verificar que pasan los dos**

Run: `flutter test test/features/chat/`
Expected: PASS

- [ ] **Step 5: Verificar con dos dispositivos (lo que pide el PDF)**

Aceptar desde un dispositivo, comprobar que el otro cambia sin recargar.

- [ ] **Step 6: Commit**

```bash
git add lib/features/chat/presentation/widgets/cards/reserva_chat_card.dart test/features/chat/
git commit -m "fix(chat): la tarjeta de reserva lee el documento vivo, no la copia del mensaje (A2)"
```

---

## Tarea 9: C1 — Fotos de perfil en el chat

**Files:**
- Modify: `lib/features/chat/data/models/conversacion_model.dart` (campos `fotoPropietario`, `fotoMecanico`)
- Modify: `functions/index.js` (rellenar la foto al crear la conversación)
- Modify: `lib/features/chat/presentation/pages/conversaciones_list_screen.dart:144`
- Modify: `lib/features/chat/presentation/pages/chat_screen.dart:391`
- Create: `lib/core/widgets/app_user_avatar.dart`
- Test: `test/core/widgets/app_user_avatar_test.dart`

**Interfaces:**
- Produces: `AppUserAvatar({String? urlFoto, required String nombre, double radius})` — `CachedNetworkImage` con inicial del nombre como fallback e icono como último recurso.

- [ ] **Step 1: Test que falla**

```dart
testWidgets('pinta la foto cuando hay url', (tester) async {
  await tester.pumpWidget(envolver(const AppUserAvatar(urlFoto: 'https://x/f.jpg', nombre: 'Ana')));
  expect(find.byType(CachedNetworkImage), findsOneWidget);
});

testWidgets('cae a la inicial del nombre sin url', (tester) async {
  await tester.pumpWidget(envolver(const AppUserAvatar(urlFoto: null, nombre: 'Ana')));
  expect(find.text('A'), findsOneWidget);
  expect(find.byType(CachedNetworkImage), findsNothing);
});

testWidgets('cae al icono si el nombre viene vacio', (tester) async {
  await tester.pumpWidget(envolver(const AppUserAvatar(urlFoto: null, nombre: '')));
  expect(find.byIcon(Icons.person), findsOneWidget);
});
```

- [ ] **Step 2: Correr y verificar que falla**

Run: `flutter test test/core/widgets/app_user_avatar_test.dart`
Expected: FAIL — el widget no existe.

- [ ] **Step 3: Implementar `AppUserAvatar`** siguiendo el patrón de `CachedNetworkImage` + `errorWidget` ya usado en `workshop_directory_screen.dart:1005`.

- [ ] **Step 4: Decidir de dónde sale la URL, por pantalla**

- **`chat_screen.dart:391`** — ya hay un `FutureBuilder` por `receptorId` para el nombre (`_futureNombreReceptor`). Ampliarlo a `_futurePerfilReceptor` y devolver nombre + foto en la misma lectura. Coste cero adicional.
- **`conversaciones_list_screen.dart:144`** — aquí **no** usar `FutureBuilder`: sería una lectura por fila en cada rebuild. Denormalizar `foto_propietario`/`foto_mecanico` en el documento de conversación, escritos por la function que la crea, con lectura tolerante (`data['foto_mecanico'] as String?`) para las conversaciones ya existentes.

- [ ] **Step 5: Correr toda la suite**

Run: `flutter test`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/core/widgets/app_user_avatar.dart lib/features/chat/ functions/ test/
git commit -m "feat(chat): mostrar foto de perfil en lista y conversacion con fallback (C1)"
```

---

## Tarea 10: C3 — Ver el perfil del otro desde el chat

**Files:**
- Create: `lib/features/profile/presentation/pages/public_profile_screen.dart`
- Modify: `lib/core/router/app_router.dart` (ruta `/perfil_publico/:userId`)
- Modify: `lib/features/chat/presentation/pages/chat_screen.dart` (avatar y nombre tocables)
- Modify: `firestore.rules` (lectura acotada de `usuarios` entre participantes de una conversación)
- Test: `test/features/profile/public_profile_screen_test.dart`, `test_rules/perfil_publico.test.js`

**Decisión que el PDF no plantea:** «mostrar la información pública correspondiente según sea cliente o mecánico» no define qué es público. Se fija aquí:

- **Mecánico visto por un cliente:** nombre, foto, taller, especialidad, calificación, reseñas.
- **Cliente visto por un mecánico:** nombre, foto, municipio. **Nunca** teléfono, DUI, correo ni la lista de vehículos.

- [ ] **Step 1: Test de reglas que falla — la parte que importa**

```javascript
it('un mecanico no puede leer el telefono ni el DUI del cliente', async () => {
  const doc = await conMecanico('mec1').doc('usuarios/cli1').get();
  expect(doc.data().telefono).toBeUndefined();
  expect(doc.data().dui).toBeUndefined();
});

it('un usuario cualquiera sin conversacion no lee el perfil ajeno', async () => {
  await assertFails(conCliente('extrano').doc('usuarios/cli1').get());
});
```

Si el modelo actual de `usuarios` no permite proyectar campos, la lectura pública va por un **callable** (`obtenerPerfilPublico`) que devuelve sólo el subconjunto acordado — igual que hace `buscarVehiculoPorPlaca` para no exponer `id_propietario`.

- [ ] **Step 2: Correr y verificar el estado real**

Run: `/test rules`
Documentar cuál de los dos caminos (reglas o callable) aplica antes de implementar.

- [ ] **Step 3: Implementar la pantalla y la ruta**, con `AppUserAvatar` de la Tarea 9.

- [ ] **Step 4: Hacer tocables el avatar y el nombre** en `chat_screen.dart` (envolver el `Row` del `title` en `InkWell` → `context.push('/perfil_publico/$receptorId')`).

- [ ] **Step 5: Correr toda la suite**

Run: `/test all`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/features/profile/ lib/core/router/app_router.dart lib/features/chat/presentation/pages/chat_screen.dart firestore.rules test_rules/ test/
git commit -m "feat(chat): perfil publico del contacto desde el chat, con campos acotados por rol (C3)"
```

---

## Tarea 11: C4 — Menú contextual de mensaje, en tres entregas

Se parte por coste real, no por la lista homogénea del PDF.

### 11a — Copiar y borrar (barato, alto valor)

- [ ] **Step 1: Test que falla**

```dart
testWidgets('mantener presionado un mensaje propio abre el menu', (tester) async {
  await tester.pumpWidget(construirChatConMensajes([mensajeFake(texto: 'hola', esMio: true)]));
  await tester.longPress(find.text('hola'));
  await tester.pumpAndSettle();
  expect(find.text('Copiar'), findsOneWidget);
  expect(find.text('Borrar'), findsOneWidget);
});

testWidgets('sobre un mensaje ajeno solo se ofrece copiar', (tester) async {
  await tester.pumpWidget(construirChatConMensajes([mensajeFake(texto: 'hola', esMio: false)]));
  await tester.longPress(find.text('hola'));
  await tester.pumpAndSettle();
  expect(find.text('Copiar'), findsOneWidget);
  expect(find.text('Borrar'), findsNothing);
});
```

- [ ] **Step 2:** Run `flutter test test/features/chat/` → FAIL.
- [ ] **Step 3:** Implementar `onLongPress` en `ChatBubble` → `showModalBottomSheet` con `Clipboard.setData` y borrado (`firestore.rules:708-713` ya permite `delete` a los participantes).
- [ ] **Step 4:** Run `flutter test` → PASS.
- [ ] **Step 5:** `git commit -m "feat(chat): copiar y borrar mensaje desde menu contextual (C4a)"`

### 11b — Editar (requiere reglas)

- [ ] **Step 1: Test de reglas que falla**

```javascript
it('el emisor puede editar solo el texto y la marca de editado', async () => {
  await assertSucceeds(conCliente('cli1').doc('conversaciones/c1/mensajes/m1')
    .update({ texto: 'corregido', editado: true }));
});

it('nadie puede reescribir el emisor ni el tipo de un mensaje', async () => {
  await assertFails(conCliente('cli1').doc('conversaciones/c1/mensajes/m1')
    .update({ id_emisor: 'otro' }));
  await assertFails(conCliente('cli1').doc('conversaciones/c1/mensajes/m1')
    .update({ tipo: 'cotizacion' }));
});

it('no se puede editar un mensaje de reserva o cotizacion', async () => {
  // El PDF no lo contempla: editar el texto de una cotizacion ya aceptada
  // cambiaria lo que el cliente creyo aceptar.
  await assertFails(conMecanico('mec1').doc('conversaciones/c1/mensajes/cot1')
    .update({ texto: 'otro precio' }));
});
```

- [ ] **Step 2:** Run `/test rules` → FAIL (las reglas actuales permiten `update` sin acotar campos).
- [ ] **Step 3:** Acotar `update` sobre `mensajes` con `hasOnly(['texto', 'editado'])` y `resource.data.tipo == 'texto'`.
- [ ] **Step 4:** Implementar edición en la UI, con la marca «editado» junto a la hora.
- [ ] **Step 5:** Run `/test all` → PASS.
- [ ] **Step 6:** `git commit -m "feat(chat): editar mensajes de texto propios, con reglas acotadas (C4b)"`

### 11c — Responder y reenviar (opcional en esta ronda)

Campo `respuesta_a` + render de la cita; selector de conversación destino con revalidación de permisos. **Si el tiempo aprieta, esta subtarea se corta sin afectar a las demás.** Ninguna otra observación depende de ella.

---

## Tarea 12: C6 — Previsualizar antes de enviar adjunto

**Files:**
- Modify: `lib/features/chat/presentation/pages/chat_screen.dart:860`
- Create: `lib/features/chat/presentation/widgets/adjunto_preview_sheet.dart`
- Test: `test/features/chat/presentation/widgets/adjunto_preview_test.dart`

**Trampa heredada (ver `CLAUDE.md`, S1):** `chat_screen.dart:860` usa `ImagePicker().pickImage(source: source)`, que **no selecciona PDF**. El PDF de QA dice «previsualización del archivo (imagen, PDF, etc.)» — con el picker actual la rama de PDF es inalcanzable. Si se quiere PDF, hay que pasar a `file_picker` (ya está en `pubspec.yaml`, sin usar). Un test que inyecte un `XFile` de PDF pasaría en verde sobre un camino que nadie puede ejercer: **no cuenta como verificado**.

- [ ] **Step 1: Test que falla**

```dart
testWidgets('seleccionar una imagen abre la previsualizacion, no la envia', (tester) async {
  final chat = ChatProviderFake();
  await tester.pumpWidget(construirChat(chatProvider: chat, pickerFake: PickerFake(imagen: xfileFake())));
  await tester.tap(find.byIcon(Icons.attach_file));
  await tester.pumpAndSettle();

  expect(find.byType(AdjuntoPreviewSheet), findsOneWidget);
  expect(chat.mensajesEnviados, isEmpty, reason: 'no se envia hasta confirmar');

  await tester.tap(find.text('Enviar'));
  await tester.pumpAndSettle();
  expect(chat.mensajesEnviados, hasLength(1));
});

testWidgets('cancelar la previsualizacion no envia nada', (tester) async {
  final chat = ChatProviderFake();
  await tester.pumpWidget(construirChat(chatProvider: chat, pickerFake: PickerFake(imagen: xfileFake())));
  await tester.tap(find.byIcon(Icons.attach_file));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Cancelar'));
  await tester.pumpAndSettle();
  expect(chat.mensajesEnviados, isEmpty);
});
```

- [ ] **Step 2:** Run `flutter test test/features/chat/presentation/widgets/adjunto_preview_test.dart` → FAIL: hoy se envía directo.
- [ ] **Step 3:** Implementar `AdjuntoPreviewSheet` (imagen a pantalla, nombre y peso del archivo, botones Cancelar / Cambiar / Enviar) e interponerla entre el picker y `enviarImagen`.
- [ ] **Step 4:** Run `flutter test` → PASS.
- [ ] **Step 5: Verificación manual obligatoria** — en un dispositivo real, adjuntar imagen desde galería y desde cámara. Si en esta tarea se añade `file_picker` para PDF, adjuntar un PDF real. El test solo no basta.
- [ ] **Step 6:** `git commit -m "feat(chat): previsualizar adjunto antes de enviarlo (C6)"`

---

## Tarea 13: D1 — Perfil público del taller

**Files:**
- Create: `lib/features/dashboard/presentation/pages/workshop_profile_screen.dart`
- Modify: `lib/features/dashboard/presentation/pages/workshop_directory_screen.dart` (acción «Ver perfil» en `_buildWorkshopCard`)
- Modify: `lib/core/router/app_router.dart` (ruta `/taller/:tallerId`)
- Modify: `firestore.rules` (proyección pública de `empleados`)
- Test: `test/features/dashboard/workshop_profile_test.dart`, `test_rules/empleados.test.js` (ampliar)

Las cinco secciones que pide el PDF, con su fuente ya existente:

| Sección | Fuente | Estado |
|---|---|---|
| Galería | `GaleriaTaller.urlDe` (`workshop_directory_screen.dart:973`) | Ya existe |
| Info pública | doc de `talleres` (`nombre_completo`, `especialidad`, `ubicacion_municipio`, calificación) | Ya se lee |
| Ubicación | `ubicacion_*` + Google Maps | Datos completos desde `ad0bc14` |
| Catálogo | `CatalogoProvider` / `catalogo_servicios_screen.dart` | Existe, sin vista de cliente |
| Empleados | `EmpleadoProvider` | **Requiere decidir campos públicos** |

- [ ] **Step 1: Test de reglas de empleados que falla**

```javascript
it('un cliente ve nombre y especialidad del empleado, nada mas', async () => {
  const snap = await conCliente('cli1').collection('empleados').where('id_taller', '==', 't1').get();
  const emp = snap.docs[0].data();
  expect(emp.nombre).toBeDefined();
  expect(emp.especialidad).toBeDefined();
  expect(emp.telefono).toBeUndefined();
  expect(emp.dui).toBeUndefined();
  expect(emp.salario).toBeUndefined();
});
```

- [ ] **Step 2:** Run `/test rules` → FAIL o revela que hoy la colección entera es legible. Documentar cuál de los dos.
- [ ] **Step 3:** Si no se pueden proyectar campos desde reglas, exponer los empleados públicos por callable `obtenerEmpleadosPublicos(idTaller)`, o denormalizar un array `empleados_publicos` en el doc del taller.
- [ ] **Step 4:** Test de widget de las cinco secciones:

```dart
testWidgets('el perfil del taller muestra las cinco secciones', (tester) async {
  await tester.pumpWidget(construirPerfilTaller(tallerFake()));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('taller_galeria')), findsOneWidget);
  expect(find.byKey(const Key('taller_info')), findsOneWidget);
  expect(find.byKey(const Key('taller_mapa')), findsOneWidget);
  expect(find.byKey(const Key('taller_catalogo')), findsOneWidget);
  expect(find.byKey(const Key('taller_empleados')), findsOneWidget);
});
```

- [ ] **Step 5:** Implementar la pantalla, la ruta y el botón «Ver perfil» en la tarjeta del directorio.
- [ ] **Step 6:** Run `/test all` → PASS.
- [ ] **Step 7:** `git commit -m "feat(taller): perfil publico con galeria, ubicacion, catalogo y empleados (D1)"`

---

## Fuera de alcance de este plan

- **C2 — checks de mensaje.** Antes de tocar código: reproducir y determinar si existe un campo de estado por mensaje o sólo los contadores `noLeidos*` de `ConversacionModel`. Empezar con `superpowers:systematic-debugging`, no con una tarea. Se convierte en su propio plan según lo que se encuentre.
- **C4c — responder y reenviar.** Se puede cortar sin afectar nada más.
- **«Notificaciones de mensajes en pantalla» (Inge).** Son tres features distintas bajo una línea. Hay que preguntar cuál se pide.
- **S1 — subida de PDF del taller.** Sigue siendo la prioridad declarada en `CLAUDE.md` y **no la desplaza este plan**. Si se toma la Tarea 12 (C6), coordinar: ambas tocan la selección de archivos y `file_picker`.

---

## Self-review — cobertura del backlog

| Obs. | Tarea | Nota |
|---|---|---|
| A1 | 3 | Rechazada como bug; blindada con tests y aclarada en la UI |
| A2 | 8 | Causa real distinta a la del PDF |
| A3 | 5 | Junto con B2 |
| A4a | 6 | Depende de la 4 |
| A4b | 4 | Decisión de arquitectura del plan |
| B1 | 7 | Dirección del refactor fijada |
| B2 | 5 | Duplicado de A3 |
| B3 | 2 | Severidad elevada respecto al PDF |
| C1 | 9 | Feature nueva, no bug de carga |
| C2 | — | Fuera de alcance: reproducir primero |
| C3 | 10 | Con campos públicos acotados |
| C4 | 11a/11b/11c | Partida por coste; 11c opcional |
| C5 | 1 | Diagnóstico del PDF correcto |
| C6 | 12 | Con la advertencia de `pickImage` |
| D1 | 13 | Datos ya existentes |
| Inge | — | Fuera de alcance: sin especificar |
