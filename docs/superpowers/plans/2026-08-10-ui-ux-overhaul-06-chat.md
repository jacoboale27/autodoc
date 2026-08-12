# Fase 6 — Módulo `chat` y reservas: burbuja única, tarjetas legibles, anchos acotados

> **Plan ejecutable.** Depende de las Fases 1–3 y reutiliza dos primitivas de la Fase 4 (`AppSeverity`) y una de la Fase 5 (`AppDialogContent`). Escrito el 2026-08-12 siguiendo el protocolo del §7 del [plan maestro](2026-08-10-ui-ux-overhaul-00-master.md), tras leer **completas** las 15 pantallas y widgets de presentación del módulo (3.925 líneas) y ejecutar su suite de tests sobre `HEAD`.
>
> **REQUIRED SUB-SKILL para ejecutar:** `superpowers:subagent-driven-development` (recomendado) o `superpowers:executing-plans`.
> **Skills obligatorias por tarea:** `ui-ux-pro-max` y `emil-design-eng` en toda tarea de layout/motion; `apple-design` en la Task 12 (bottom sheets con arrastre y el gesto de "mantener para grabar"); `find-animation-opportunities` una vez al abrir la fase. Ver §1 del maestro.

**Goal:** Que las 3 pantallas y las 12 piezas de `features/chat` se lean en ambos temas, no desborden en ningún ancho de `kAuditWidths`, acoten el ancho de lectura en pantallas grandes, y sean operables con lector de pantalla — sin tocar `data/`, `providers/` ni los flujos de negocio (cotizar, reservar, reseñar).

**Architecture:** Dos tareas iniciales extraen las dos primitivas que el módulo no tiene y que son la causa raíz de casi todos sus defectos: `ChatBubble` (hoy son 60 líneas inline en `chat_screen`) y `ChatCardShell` (hoy está copiada en cuatro tarjetas con ancho fijo). A partir de ahí cada pieza es una tarea independiente y rechazable, ordenadas de menor a mayor superficie. La última tarea cierra el ratchet de colores del módulo.

**Tech Stack:** Flutter 3.41.6 (Material 3), Provider, go_router 17, `audioplayers`, `record`, `image_picker`, `intl`, `timeago`. Tests con `flutter_test` + `fake_cloud_firestore`. Sin dependencias nuevas. **Se elimina** el uso de `responsive_framework` en este módulo (queda una sola llamada en toda la app tras la Fase 7).

---

## 0. Lo que se midió (2026-08-12, sobre `HEAD`)

**HC** = líneas con color literal (`Colors.*`, `Color(0x…)`). **MQ** = usos de `MediaQuery`. **LB** = `LayoutBuilder`. **Flex** = `Expanded` + `Flexible`. **SBw** = `SizedBox`/`Container` con `width:` numérico fijo. **Sem** = usos de `Semantics`.

| Fichero | LOC | HC | MQ | LB | Flex | SBw | Sem |
|---|---:|---:|---:|---:|---:|---:|---:|
| [chat_screen.dart](../../../lib/features/chat/presentation/pages/chat_screen.dart) | 829 | **16** | 1 | — | 2 | 2 | — |
| [reserva_detail_screen.dart](../../../lib/features/chat/presentation/pages/reserva_detail_screen.dart) | 505 | 9 | — | — | 2 | — | — |
| [conversaciones_list_screen.dart](../../../lib/features/chat/presentation/pages/conversaciones_list_screen.dart) | 210 | 3 | — | — | — | — | — |
| [cards/cotizacion_chat_card.dart](../../../lib/features/chat/presentation/widgets/cards/cotizacion_chat_card.dart) | 488 | **31** | — | — | 6 | 8 | — |
| [cards/reserva_chat_card.dart](../../../lib/features/chat/presentation/widgets/cards/reserva_chat_card.dart) | 417 | **26** | — | — | 4 | 5 | — |
| [cotizacion_picker.dart](../../../lib/features/chat/presentation/widgets/cotizacion_picker.dart) | 394 | 5 | 1 | — | 3 | 2 | — |
| [voice_record_button.dart](../../../lib/features/chat/presentation/widgets/voice_record_button.dart) | 230 | 7 | — | — | — | 2 | — |
| [cards/review_chat_card.dart](../../../lib/features/chat/presentation/widgets/cards/review_chat_card.dart) | 171 | 13 | — | — | — | 2 | — |
| [cards/vehiculo_chat_card.dart](../../../lib/features/chat/presentation/widgets/cards/vehiculo_chat_card.dart) | 120 | **0** | — | — | — | 1 | — |
| [cards/historial_chat_card.dart](../../../lib/features/chat/presentation/widgets/cards/historial_chat_card.dart) | 118 | 12 | — | — | — | 1 | — |
| [cards/audio_chat_card.dart](../../../lib/features/chat/presentation/widgets/cards/audio_chat_card.dart) | 111 | 2 | — | — | — | — | — |
| [vehiculo_picker.dart](../../../lib/features/chat/presentation/widgets/vehiculo_picker.dart) | 90 | 0 | — | — | 1 | — | — |
| [cards/imagen_chat_card.dart](../../../lib/features/chat/presentation/widgets/cards/imagen_chat_card.dart) | 90 | 5 | — | — | — | — | — |
| [chat_background.dart](../../../lib/features/chat/presentation/widgets/chat_background.dart) | 84 | 0 | — | — | — | — | — |
| [historial_chat_card.dart](../../../lib/features/chat/presentation/widgets/historial_chat_card.dart) | 68 | 4 | — | — | — | 1 | — |
| **TOTAL presentación** | **3925** | **133** | **2** | **0** | **18** | **24** | **0** |

Tres lecturas de esta tabla, que ordenan la fase entera:

1. **`GoogleFonts` aparece 0 veces.** Es el único módulo de la app sin tipografía fuera del sistema. No hay ninguna tarea de tipografía en esta fase.
2. **`LayoutBuilder` aparece 0 veces y `MediaQuery` 2, ambas para leer `padding.bottom` / `viewInsets.bottom` — es decir, teclado y notch, no ancho.** El módulo **no consulta el ancho de la ventana ni una sola vez**. No es que responda mal a los tamaños: no los mira. Frente a eso hay **24 anchos fijos** en píxeles.
3. **133 colores literales en 3.925 líneas** es la densidad más alta de la app (una cada 30 líneas). Y no son decorativos: como se demuestra en §0.1, son el mecanismo por el que la mitad del contenido del chat es ilegible en uno u otro tema.

### 0.1 El hallazgo: el chat es ilegible en los dos temas, por motivos opuestos

`ChatScreen` dibuja cada mensaje dentro de una burbuja cuyo fondo es `colors.primary` cuando el mensaje es propio ([chat_screen.dart:432-448](../../../lib/features/chat/presentation/pages/chat_screen.dart#L432-L448)). Sobre esa burbuja se pinta o bien texto plano, o bien una tarjeta. Los dos casos están rotos, en temas distintos:

**(a) Texto plano, roto en oscuro.** [chat_screen.dart:627-635](../../../lib/features/chat/presentation/pages/chat_screen.dart#L627-L635):

```dart
color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87),
```

En claro `AppPalette.lightPrimary` es `#522C81` (morado oscuro) y blanco sobre él da **10,31:1** — correcto. En oscuro `AppPalette.darkPrimary` es `#81E6D9` (turquesa claro) y blanco sobre él da **1,47:1**. El acuse de recibo que va debajo es peor: `Colors.white70` sobre `#81E6D9` = **1,31:1**, y `Colors.blue.shade200` (el "visto") = **1,19:1**. Es el mismo defecto que la Fase 5 midió en `mechanic_dashboard`, y sobrevive por el mismo motivo: en claro pasa, y el desarrollo se hace en claro.

**(b) Tarjetas, rotas en claro.** Cuatro de las siete tarjetas hacen esto:

```dart
Container(
  width: 300,
  decoration: BoxDecoration(color: isDark ? colors.surfaceContainer : Colors.white),
  child: ... Text(..., color: isMe ? Colors.white : colors.textPrimary),
)
```

La tarjeta pinta **su propio fondo opaco** y luego elige el color del texto como si estuviera sobre la burbuja. En claro ese fondo es `Colors.white` y el texto es `Colors.white`:

| Elemento | Fondo efectivo | Color de texto | Contraste |
|---|---|---|---:|
| Cuerpo de la tarjeta (ítems, total, fecha) | `#FFFFFF` | `Colors.white` | **1,00:1** |
| Cabecera (`Colors.black12` sobre blanco → `#E0E0E0`) | `#E0E0E0` | `Colors.white` | **1,32:1** |
| Subtotales, "Total:" | `#FFFFFF` | `Colors.white70` | **1,00:1** |
| "Tu beneficio: $…" | `#FFFFFF` | `Colors.white54` | **1,00:1** |

1,00:1 no es "poco contraste": es **texto blanco sobre blanco puro, invisible**. Y afecta a quien envía: `isMe` es verdadero para el emisor, de modo que **el mecánico no puede leer la cotización que acaba de mandar** en tema claro, incluido su propio margen de beneficio — que además solo se consulta cuando `isMe` ([cotizacion_chat_card.dart:45](../../../lib/features/chat/presentation/widgets/cards/cotizacion_chat_card.dart#L45)), así que ese dato **nunca** se ha visto en claro.

**La tarjeta que sí funciona demuestra cuál es la regla.** [vehiculo_chat_card.dart](../../../lib/features/chat/presentation/widgets/cards/vehiculo_chat_card.dart) es la única con 0 colores literales y la única legible en ambos temas, porque su fondo es **translúcido** (`colors.primary.withValues(alpha: 0.1)`), deja ver la burbuja de debajo, y por tanto su suposición de "estoy sobre `primary`" es cierta. Las otras cuatro rompieron esa suposición al pintar un fondo opaco encima, pero se quedaron con los colores de texto.

**Decisión de la fase:** la regla se invierte y se hace explícita. Una tarjeta de chat **pinta su propia superficie opaca y sus colores no dependen de `isMe`**. `isMe` solo decide alineación y forma de la burbuja, nunca color de contenido. Eso lo impone `ChatCardShell` (Task 2), y las Tasks 6–10 lo aplican.

### 0.2 El módulo llega a esta fase con un test en rojo

`flutter test test/features/chat/` sobre `HEAD` da **33 pasan, 1 falla**:

```
A RenderFlex overflowed by 118 pixels on the right.
  Row:.../lib/features/chat/presentation/widgets/cards/reserva_chat_card.dart:219:20
  constraints: BoxConstraints(0.0<=w<=234.0, 0.0<=h<=Infinity)
```

No es un fallo nuevo: [reserva_chat_card_test.dart:111-127](../../../test/features/chat/presentation/widgets/cards/reserva_chat_card_test.dart#L111-L127) instala a propósito un filtro en `FlutterError.onError` para **tragarse** ese desbordamiento, y el propio código fuente lo documenta con un `TODO` en [reserva_chat_card.dart:220](../../../lib/features/chat/presentation/widgets/cards/reserva_chat_card.dart#L220). El filtro está anclado a la cadena `reserva_chat_card.dart:202`; ediciones posteriores movieron ese `Row` a la línea **219**, el filtro dejó de coincidir y el desbordamiento volvió a hacer fallar el test.

Los 234 px del mensaje cuadran exactamente con el modelo: la tarjeta mide 260, tiene `Border.all` (1 px por lado) y `EdgeInsets.all(12)` → `260 − 2 − 24 = 234`. El `Row` es `mainAxisAlignment: spaceBetween` con `[Row(icono + título), badge]` y **ninguno de los dos hijos es flexible**, así que ninguno cede.

Esto le da a la fase un criterio de éxito que no hay que inventar: la Task 9 arregla el `Row` y **borra el filtro**; el test debe pasar sin él.

### 0.3 Anchos fijos: dónde desbordan exactamente

El contenido de un mensaje vive dentro de dos paddings: el del `ListView` (`horizontal: 16`) y el de la burbuja (`horizontal: 16`). El ancho disponible es por tanto `ancho − 64`.

| Ancho de `kAuditWidths` | Disponible | `cotizacion` (300) | `review` (280) | `reserva`/`historial` (260) | `imagen`/`vehiculo` (250) |
|---:|---:|---|---|---|---|
| 320 | 256 | **−44** | **−24** | **−4** | ✅ |
| 375 | 311 | ✅ | ✅ | ✅ | ✅ |
| ≥ 600 | ≥ 536 | ✅ pero fija | ✅ pero fija | ✅ pero fija | ✅ pero fija |

Es decir: **desbordan en 320 px y no crecen nunca**. En una ventana de 1440 px una cotización de ocho renglones sigue midiendo 300 px mientras el mensaje de texto de al lado se estira los 1376 px completos (no hay `maxWidth` en la burbuja), lo que produce líneas de ~200 caracteres, muy por encima del rango legible de 45–75.

### 0.4 Correcciones al plan maestro

Al medir sobre `HEAD` aparecen cuatro discrepancias con el §5.3 del maestro. Se corrigen ahí, con la evidencia, como parte de la Task 1:

- **(a) Colores.** El maestro dice "73 colores del módulo" y "28+24+11+10" para las tarjetas. Lo medido: **133 en el módulo**, **89 en `widgets/cards/`**, y los dos mayores infractores son `cotizacion_chat_card` (31) y `reserva_chat_card` (26), no las cifras citadas. `chat_screen` tiene 16, no 13; `reserva_detail_screen` 9, no 7.
- **(b) La tarjeta de historial que el maestro describe está muerta.** El maestro lista `historial` con ancho fijo 260 — eso es [cards/historial_chat_card.dart](../../../lib/features/chat/presentation/widgets/cards/historial_chat_card.dart), que **no lo importa nadie**. `chat_screen` importa [widgets/historial_chat_card.dart](../../../lib/features/chat/presentation/widgets/historial_chat_card.dart), otra clase **con el mismo nombre**, con otra firma y sin ancho fijo. Ver §0.5.
- **(c) El contrato de master-detail no es realizable en esta fase.** El maestro pide, para `expanded`+, "master-detail con la lista de conversaciones a la izquierda". `/chat_list` vive dentro del `ShellRoute` de propietario ([app_router.dart:397](../../../lib/core/router/app_router.dart#L397)) mientras `/chat/:id` es una ruta de primer nivel ([app_router.dart:553](../../../lib/core/router/app_router.dart#L553)); montar las dos a la vez exige reestructurar el router y redefinir qué significa el deep link `/chat/:id` cuando hay panel izquierdo. Eso es un cambio de navegación, no de presentación. Se sustituye por el contrato realizable —columna de lectura centrada a `maxReadingWidth`— y el master-detail pasa a §18.1 como bloqueo a consultar, con su coste.
- **(d) `responsive_framework` no es "un uso a migrar" en este módulo, es el único.** El maestro lo cita en `conversaciones_list_screen` L62; confirmado, es la única llamada del módulo. Tras esta fase quedan 4 en la app (`garage_screen`, `workshop_directory_screen`, y dos en `user_profile_screen`), todas de la Fase 7.

### 0.5 Dos clases distintas con el mismo nombre

```
lib/features/chat/presentation/widgets/cards/historial_chat_card.dart  → class HistorialChatCard  (metadata, isMe)          118 líneas, 12 colores literales
lib/features/chat/presentation/widgets/historial_chat_card.dart        → class HistorialChatCard  (mensaje, isMe, colors)    68 líneas,  4 colores literales
```

`chat_screen.dart` importa la segunda con una ruta relativa (`import '../widgets/historial_chat_card.dart';`, [L5](../../../lib/features/chat/presentation/pages/chat_screen.dart#L5)) mientras todas sus demás importaciones son absolutas `package:autodoc/…`. La primera no la importa nadie: es código muerto, y es a la que apunta el diagnóstico del maestro.

La que sí se usa tiene además un defecto propio: devuelve un `Align` con `margin: EdgeInsets.symmetric(horizontal: 16)` y su **propia** burbuja `color: isMe ? colors.primary : colors.surfaceContainer` — pero se renderiza **dentro** de la burbuja de `chat_screen`, que ya tiene ese mismo fondo y ya aplica 16 px de padding. Resultado: una burbuja dentro de otra del mismo color, con 32 px de sangrado, y —porque un `Align` sin `widthFactor` ocupa todo el ancho disponible— **el mensaje de historial estira la burbuja a todo el ancho de la lista** independientemente de su contenido. Lo arregla la Task 3.

### 0.6 Otros defectos medidos, por fichero

| Fichero | Defecto | Tarea |
|---|---|---|
| `chat_screen` | `FutureBuilder` con el `future:` **construido dentro de `build()`** ([L315-321](../../../lib/features/chat/presentation/pages/chat_screen.dart#L315-L321)): cada notificación de `ChatProvider` (incluido el estado "escribiendo…", que cambia cada 2 s) relanza un `get()` a `usuarios/{receptorId}` | 11 |
| `chat_screen` | La burbuja no tiene `maxWidth`: a 1440 px una línea de texto ocupa 1376 px | 1, 11 |
| `chat_screen` | `hintText: 'Escribe un mensaje...'` literal en un fichero que ya usa `context.l10n` para 8 cadenas | 11 |
| `imagen_chat_card` | `Image.network` con `BoxFit.cover` sin restricción de alto: una foto vertical produce una burbuja de 250 × ~1800 px | 6 |
| `imagen_chat_card` | `Hero(tag: urlArchivo)`: si la misma imagen se envía dos veces en la conversación, dos Heroes comparten tag → excepción de Flutter | 6 |
| `imagen_chat_card` | Sin `semanticLabel`; el botón de cerrar del visor es `Colors.white` sobre `Dialog` transparente (invisible sobre foto clara) | 6 |
| `audio_chat_card` | `IconButton` de reproducir sin `tooltip` ni `Semantics`; usa `Theme.of(context).extension<AppColors>()` en vez de `context.appColors` | 6 |
| `voice_record_button` | `CircleAvatar` sin `radius` → **40 × 40 px**, por debajo del mínimo de 48 dp | 12 |
| `vehiculo_picker` | `Container(height: 400)` fijo: en teléfono horizontal (alto 375 px) el sheet es más alto que la pantalla | 12 |
| `cotizacion_picker` | `DraggableScrollableSheet` sin `maxWidth`: a 1440 px los campos del formulario miden 1400 px | 12 |
| `reserva_detail_screen` | Estados con `Colors.green/red/blue` y chip de texto a **2,16–2,64:1** sobre su propio fondo al 20 % | 5 |
| `review_chat_card` | `Colors.green` como color de texto sobre tarjeta blanca: **2,78:1** | 8 |
| Badges de estado (3 ficheros) | Texto blanco de 10 px bold sobre `orange` **2,16:1**, `green` **2,78:1**, `blue` **3,12:1**, `red` **3,68:1**, `amber.shade700` **2,04:1** | 5, 9, 10 |
| Todo el módulo | **0 usos de `Semantics`** en 3.925 líneas: un lector de pantalla no distingue mensaje propio de ajeno, ni anuncia no leídos, ni etiqueta los controles de audio | todas |

### 0.7 Ficheros que toca la fase

| Fichero | Papel | Acción |
|---|---|---|
| `lib/features/chat/presentation/widgets/chat_bubble.dart` | Burbuja de mensaje: ancho máximo, cola, fondo, acuse | Crear (Task 1) |
| `lib/features/chat/presentation/widgets/chat_card_shell.dart` | Carcasa común de tarjeta: ancho acotado, cabecera que no desborda, superficie propia | Crear (Task 2) |
| `test/support/chat_harness.dart` | Dobles de providers + `pumpChatWidget` | Crear (Task 1) |
| `lib/core/theme/app_severity.dart` | Se le añade `forReservaEstado` | Modificar (Task 5) |
| `lib/features/chat/presentation/widgets/cards/historial_chat_card.dart` | Duplicado muerto | **Borrar** (Task 3) |
| `lib/features/chat/presentation/widgets/historial_chat_card.dart` | Tarjeta de historial viva | Modificar + mover a `cards/` (Task 3) |
| `conversaciones_list_screen.dart` | Lista de conversaciones | Modificar (Task 4) |
| `reserva_detail_screen.dart` | Detalle de cita | Modificar (Task 5) |
| `cards/vehiculo_chat_card.dart`, `cards/imagen_chat_card.dart`, `cards/audio_chat_card.dart` | Tarjetas simples | Modificar (Task 6) |
| `cards/review_chat_card.dart` | Tarjeta de reseña | Modificar (Task 8) |
| `cards/reserva_chat_card.dart` | Tarjeta de cita | Modificar (Task 9) |
| `cards/cotizacion_chat_card.dart` | Tarjeta de cotización | Modificar (Task 10) |
| `chat_screen.dart` | Pantalla de conversación | Modificar (Task 11) |
| `cotizacion_picker.dart`, `vehiculo_picker.dart`, `voice_record_button.dart` | Sheets y grabación | Modificar (Task 12) |
| `test/support/tokenized_paths.dart` | Ratchet de colores | Modificar (Task 13) |
| `docs/.../00-master.md` | Correcciones de §0.4 | Modificar (Task 1) |

---

## 1. Reglas de la fase

Además de las del §2 del maestro, que siguen vigentes sin excepción:

- **`isMe` no decide colores de contenido.** Decide alineación, forma de la cola y fondo de la burbuja. Cualquier `color: isMe ? … : …` dentro de una tarjeta es un defecto, no un estilo.
- **Ningún ancho en píxeles literales.** Todo ancho sale de `AppBreakpoints` o de una fracción del `BoxConstraints` recibido. Los 24 `SizedBox(width: N)` medidos bajan a 0 en las tarjetas.
- **No se añaden claves de l10n** (regla heredada de la Fase 4). Donde exista clave se usa; donde no, se deja la cadena literal y se anota en §17.1. Traducir el módulo es un trabajo aparte.
- **No se toca el flujo de negocio.** Quién puede aceptar, quién debe cotizar, qué estados existen y en qué orden: intacto. Si un arreglo visual exigiera cambiar eso, se para y se consulta.
- **Cada tarea deja `flutter test test/features/chat/` en verde**, incluido el test que hoy falla.

---

## 2. Task 1: `ChatBubble` — la burbuja que hoy está inline

**Files:**
- Create: `lib/features/chat/presentation/widgets/chat_bubble.dart`
- Create: `test/support/chat_harness.dart`
- Create: `test/features/chat/presentation/widgets/chat_bubble_test.dart`
- Modify: `docs/superpowers/plans/2026-08-10-ui-ux-overhaul-00-master.md`

**Interfaces:**
- Consumes: `WindowClass`, `AppBreakpoints.of`, `AppBreakpoints.maxReadingWidth`, extensión `WindowClassX` (Fase 1 Task 1); `pumpAtWidth`, `kAuditWidths`, `expectNoOverflow` (Fase 1 Task 7); `AppColors` vía `context.appColors`; `AppRadius` (ya existe).
- Produces: `class ChatBubble extends StatelessWidget` con `ChatBubble({required bool isMe, required Widget child, bool isDeleted = false, Widget? footer, String? semanticLabel, EdgeInsetsGeometry? padding})`; `ChatBubble.maxWidthFor(double availableWidth, WindowClass windowClass) -> double` (estático y público, para que los tests puedan afirmarlo sin montar el árbol). Consumido por las Tasks 3, 6, 8, 9, 10 y 11.
- Produces (harness): `FakeChatProvider`, `FakeReservaProvider`, `FakeUserProfileProvider`, `UserModel fakeChatUser(...)`, `ConversacionModel fakeConversacion(...)`, `MensajeModel fakeMensaje(...)`, `Future<void> pumpChatWidget(WidgetTester, Widget, {required double width, …})`. Consumido por las Tasks 2–12.

### Step 1: Leer las skills obligatorias

Invoca `ui-ux-pro-max` y `emil-design-eng` antes de escribir nada.

De `ui-ux-pro-max` interesan aquí dos reglas concretas, que son las que justifican los números de esta tarea:

- **Longitud de línea legible 45–75 caracteres.** Es la razón de que la burbuja tenga tope y de que el tope se exprese en `maxReadingWidth` (720) y no en un porcentaje suelto.
- **Accesibilidad por encima de estilo** (prioridad 1 sobre 4 de su tabla). Es la razón de que `ChatBubble` reciba `semanticLabel` como parámetro de primera clase y no como añadido opcional posterior.

De `emil-design-eng` interesa el marco de decisión de animación: **esta burbuja no anima**. Aparece una vez, en una lista con `reverse: true`, y animarla al entrar produce saltos al hacer scroll rápido. Anotarlo explícitamente evita que una tarea posterior "mejore" esto.

### Step 2: Escribir el test del ancho máximo — debe fallar

```dart
// test/features/chat/presentation/widgets/chat_bubble_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/utils/app_breakpoints.dart';
import 'package:autodoc/features/chat/presentation/widgets/chat_bubble.dart';
import '../../../../support/responsive_harness.dart';

void main() {
  group('ChatBubble.maxWidthFor', () {
    test('en compact la burbuja usa el 80 % del ancho disponible', () {
      // 320 − 32 (padding del ListView) = 288 disponibles → 230.4
      expect(ChatBubble.maxWidthFor(288, WindowClass.compact), closeTo(230.4, 0.01));
    });

    test('en medium sigue siendo proporcional, no fija', () {
      expect(ChatBubble.maxWidthFor(736, WindowClass.medium), closeTo(588.8, 0.01));
    });

    test('a partir de expanded se acota al ancho de lectura', () {
      // 0.8 × 1408 = 1126.4, pero el tope de lectura manda.
      expect(
        ChatBubble.maxWidthFor(1408, WindowClass.expanded),
        AppBreakpoints.maxReadingWidth,
      );
      expect(
        ChatBubble.maxWidthFor(2000, WindowClass.large),
        AppBreakpoints.maxReadingWidth,
      );
    });

    test('nunca devuelve más que el ancho disponible', () {
      // Una ventana estrecha en clase large (ventana redimensionada a mano)
      // no puede producir una burbuja más ancha que su contenedor.
      expect(ChatBubble.maxWidthFor(200, WindowClass.large), 200);
    });
  });

  group('ChatBubble en el árbol', () {
    testWidgets('no desborda en ningún ancho auditado', (tester) async {
      for (final width in kAuditWidths) {
        await pumpAtWidth(
          tester,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerRight,
              child: ChatBubble(
                isMe: true,
                child: const Text(
                  'Buenas tardes, necesito una revisión completa de frenos '
                  'para el jueves por la mañana si es posible, y también '
                  'cambio de aceite.',
                ),
              ),
            ),
          ),
          width: width,
        );
        expectNoOverflow(tester);
      }
    });

    testWidgets('a 1440 px la burbuja no supera el ancho de lectura', (tester) async {
      await pumpAtWidth(
        tester,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerRight,
            child: ChatBubble(
              isMe: true,
              child: Text('x' * 600),
            ),
          ),
        ),
        width: 1440,
      );
      final size = tester.getSize(find.byType(ChatBubble));
      expect(size.width, lessThanOrEqualTo(AppBreakpoints.maxReadingWidth));
    });

    testWidgets('la cola apunta al lado correcto según isMe', (tester) async {
      await pumpAtWidth(tester, const ChatBubble(isMe: true, child: Text('a')), width: 375);
      final propio = tester.widget<Container>(
        find.descendant(of: find.byType(ChatBubble), matching: find.byType(Container)).first,
      );
      final radiusPropio = (propio.decoration as BoxDecoration).borderRadius as BorderRadius;
      expect(radiusPropio.bottomRight, Radius.zero);
      expect(radiusPropio.bottomLeft, isNot(Radius.zero));
    });

    testWidgets('expone un semanticLabel cuando se le pasa', (tester) async {
      await pumpAtWidth(
        tester,
        const ChatBubble(
          isMe: false,
          semanticLabel: 'Mensaje de Taller Escobar',
          child: Text('Hola'),
        ),
        width: 375,
      );
      expect(find.bySemanticsLabel('Mensaje de Taller Escobar'), findsOneWidget);
    });
  });
}
```

### Step 3: Verificar el fallo exacto

Run: `flutter test test/features/chat/presentation/widgets/chat_bubble_test.dart`

Expected: **FAIL** — `Error: Couldn't resolve the package 'autodoc/features/chat/presentation/widgets/chat_bubble.dart'`.

Si en lugar de eso falla al resolver `responsive_harness.dart` o `app_breakpoints.dart`, la Fase 1 no está ejecutada: **para y ejecútala primero**, no crees stubs.

### Step 4: Implementar `ChatBubble`

```dart
// lib/features/chat/presentation/widgets/chat_bubble.dart
import 'package:flutter/material.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/utils/app_breakpoints.dart';

/// Burbuja de un mensaje del chat.
///
/// Es la única pieza que sabe qué significa `isMe` visualmente: alineación,
/// forma de la cola y color de fondo. **Ningún hijo debe volver a consultar
/// `isMe` para elegir colores de contenido** — ver §0.1 del plan de la Fase 6:
/// las tarjetas que lo hacían acababan pintando blanco sobre blanco porque
/// dibujaban su propia superficie opaca encima de la burbuja.
class ChatBubble extends StatelessWidget {
  /// Verdadero si el mensaje lo envía el usuario actual.
  final bool isMe;

  final Widget child;

  /// Mensaje borrado: se atenúa el fondo y se desactiva el acuse.
  final bool isDeleted;

  /// Fila inferior opcional (acuse de recibo, hora). Se alinea a la derecha.
  final Widget? footer;

  /// Etiqueta para lector de pantalla. Debe decir **quién** envía el mensaje:
  /// sin ella, la lista se lee como una sucesión de textos sin autor.
  final String? semanticLabel;

  final EdgeInsetsGeometry? padding;

  const ChatBubble({
    super.key,
    required this.isMe,
    required this.child,
    this.isDeleted = false,
    this.footer,
    this.semanticLabel,
    this.padding,
  });

  /// Fracción del ancho disponible que ocupa como máximo una burbuja.
  /// 0.8 deja un margen visible en el lado contrario, que es lo que hace
  /// legible de un vistazo quién habla sin depender solo del color.
  static const double _fraccion = 0.8;

  /// Ancho máximo de la burbuja dado el ancho disponible y la clase de ventana.
  ///
  /// Público y estático a propósito: permite verificar la regla sin montar el
  /// árbol, y permite que `chat_screen` calcule el mismo valor para la lista.
  static double maxWidthFor(double availableWidth, WindowClass windowClass) {
    final proporcional = availableWidth * _fraccion;
    // Desde `expanded` el límite deja de ser la pantalla y pasa a ser la
    // legibilidad: una línea de 1100 px son ~200 caracteres, muy por encima
    // del rango de 45–75 que recomienda `ui-ux-pro-max`.
    final tope = windowClass.isAtLeastExpanded
        ? AppBreakpoints.maxReadingWidth
        : proporcional;
    // Nunca más ancha que su contenedor: una ventana estrecha en clase large
    // (redimensionada a mano) no debe producir una burbuja que desborde.
    return [proporcional, tope, availableWidth].reduce((a, b) => a < b ? a : b);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final windowClass = AppBreakpoints.of(context);

    final fondo = isMe
        ? (isDeleted ? colors.textSecondary.withValues(alpha: 0.5) : colors.primary)
        : colors.surfaceContainer;

    final burbuja = LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = maxWidthFor(constraints.maxWidth, windowClass);
        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12, top: 2),
            padding: padding ??
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: fondo,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                // La cola va del lado del emisor: sin esquina redondeada
                // abajo-derecha si el mensaje es propio.
                bottomLeft: Radius.circular(isMe ? 16 : 0),
                bottomRight: Radius.circular(isMe ? 0 : 16),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                child,
                if (footer != null && !isDeleted) ...[
                  const SizedBox(height: 4),
                  footer!,
                ],
              ],
            ),
          ),
        );
      },
    );

    if (semanticLabel == null) return burbuja;
    return Semantics(
      label: semanticLabel,
      container: true,
      child: burbuja,
    );
  }
}
```

### Step 5: Verificar que pasa

Run: `flutter test test/features/chat/presentation/widgets/chat_bubble_test.dart`

Expected: **PASS**, 8 tests.

Si el test de la cola falla porque `find.byType(Container).first` encuentra otro `Container`, sustitúyelo por una `Key` explícita en el `Container` de la burbuja (`key: const ValueKey('chat-bubble-surface')`) y busca por esa clave. No relajes la aserción.

### Step 6: Escribir el harness de tests del módulo

Este harness lo consumen las once tareas restantes. Se escribe una vez y no se repite.

```dart
// test/support/chat_harness.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/core/models/user_model.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/l10n/app_localizations.dart';
import 'package:autodoc/features/chat/data/models/conversacion_model.dart';
import 'package:autodoc/features/chat/data/models/mensaje_model.dart';
import 'package:autodoc/features/chat/presentation/providers/chat_provider.dart';
import 'package:autodoc/features/chat/presentation/providers/reserva_provider.dart';

/// **Implementa** en vez de extender, y no es preferencia de estilo:
/// `UserProfileProvider` inicializa `final UserService _userService =
/// UserService()` en la declaración del campo, y `UserService` hace
/// `FirebaseFirestore.instance` en la suya. Extender la clase real ejecuta
/// ambos inicializadores y lanza en un widget test sin `Firebase.initializeApp()`.
///
/// Es el mismo patrón que ya usan `reserva_chat_card_test.dart` y
/// `reserva_detail_screen_test.dart` en este repositorio; aquí solo se
/// centraliza para no reescribirlo en cada tarea.
class FakeUserProfileProvider extends ChangeNotifier
    implements UserProfileProvider {
  FakeUserProfileProvider({this.user});
  final UserModel? user;

  @override
  UserModel? get userData => user;
  @override
  bool get isLoading => false;
  @override
  bool get hasAttemptedFetch => true;
  @override
  String? get fetchedUserId => user?.idUsuario;
  @override
  String? get error => null;
  @override
  bool hasAttemptedFetchFor(String userId) => true;
  @override
  Future<void> fetchUserData(String userId) async {}
  @override
  Future<bool> updateProfile(
    UserModel updatedUser, {
    XFile? imageFile,
    bool isNewUser = false,
  }) async => true;
  @override
  void clearUserData() {}
}

/// Doble de `ChatProvider`. Solo expone lo que la capa de presentación lee
/// durante `build()`; todo lo demás son no-ops que devuelven éxito.
///
/// `noSuchMethod` **no** se usa aquí a propósito: con `implements` explícito,
/// añadir un miembro nuevo a `ChatProvider` rompe la compilación de este
/// fichero, que es exactamente el aviso que queremos. Con `noSuchMethod` el
/// test seguiría compilando y fallaría en runtime con un mensaje opaco.
class FakeChatProvider extends ChangeNotifier implements ChatProvider {
  FakeChatProvider({
    List<ConversacionModel>? conversaciones,
    List<MensajeModel>? mensajes,
    this.isLoading = false,
    this.error,
  })  : _conversaciones = conversaciones ?? const [],
        _mensajes = mensajes ?? const [];

  final List<ConversacionModel> _conversaciones;
  final List<MensajeModel> _mensajes;

  @override
  final bool isLoading;
  @override
  final String? error;

  @override
  List<ConversacionModel> get conversaciones => _conversaciones;
  @override
  List<MensajeModel> get mensajesActuales => _mensajes;

  /// Registro de llamadas, para poder afirmar que la UI **no** dispara
  /// trabajo de red de más (ver Task 11, el `FutureBuilder` en `build`).
  final List<String> llamadas = [];

  @override
  void inicializarMensajes(String conversacionId) =>
      llamadas.add('inicializarMensajes:$conversacionId');
  @override
  void inicializarConversaciones(String userId, bool isMecanico) =>
      llamadas.add('inicializarConversaciones:$userId:$isMecanico');
  @override
  Future<void> marcarComoLeidos(
    String conversacionId,
    bool isMecanico,
    String userId,
  ) async => llamadas.add('marcarComoLeidos:$conversacionId');
  @override
  Future<void> setTypingStatus(String conversacionId, String? userId) async =>
      llamadas.add('setTypingStatus:$conversacionId:$userId');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Doble de `ReservaProvider`, con la misma política que `FakeChatProvider`.
class FakeReservaProvider extends ChangeNotifier implements ReservaProvider {
  FakeReservaProvider({this.error});
  @override
  final String? error;
  @override
  bool get isLoading => false;

  final List<String> llamadas = [];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    llamadas.add(invocation.memberName.toString());
    return null;
  }
}

UserModel fakeChatUser({
  String id = 'u1',
  String nombre = 'Ana Pérez',
  String rol = 'Propietario',
}) =>
    UserModel(
      idUsuario: id,
      nombreCompleto: nombre,
      correo: 'ana@example.com',
      rol: rol,
      fechaRegistro: DateTime(2026, 1, 1),
      estado: 'activo',
    );

/// Monta [widget] con el tema de AutoDoc, l10n en español y los tres
/// providers que el módulo lee, en un viewport de [width] × [height].
///
/// El `locale` fijo en `es` no es cosmético: el módulo formatea fechas con
/// `DateFormat('dd MMM yyyy', 'es')` y sin la delegación cargada esas
/// llamadas lanzan `LocaleDataException`.
Future<void> pumpChatWidget(
  WidgetTester tester,
  Widget widget, {
  required double width,
  double height = 900,
  Brightness brightness = Brightness.light,
  UserModel? user,
  FakeChatProvider? chatProvider,
  FakeReservaProvider? reservaProvider,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<UserProfileProvider>.value(
          value: FakeUserProfileProvider(user: user),
        ),
        ChangeNotifierProvider<ChatProvider>.value(
          value: chatProvider ?? FakeChatProvider(),
        ),
        ChangeNotifierProvider<ReservaProvider>.value(
          value: reservaProvider ?? FakeReservaProvider(),
        ),
      ],
      child: MaterialApp(
        theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: widget),
      ),
    ),
  );
  await tester.pump();
}
```

**Nota de ejecución:** los nombres exactos de los miembros de `ChatProvider` y `ReservaProvider` deben leerse del fichero real antes de escribir el doble ([chat_provider.dart](../../../lib/features/chat/presentation/providers/chat_provider.dart), 375 líneas; [reserva_provider.dart](../../../lib/features/chat/presentation/providers/reserva_provider.dart), 97). Si alguna firma no coincide, **corrige el doble, no el provider** (§2 del maestro: no se toca `providers/`).

### Step 7: Verificar que el harness compila y que el módulo sigue como estaba

Run: `flutter test test/features/chat/`

Expected: **33 pasan, 1 falla** — exactamente el estado de §0.2. El fallo de `reserva_chat_card_test.dart` es el que arregla la Task 9; esta tarea no lo toca.

Si aparece un fallo **distinto**, el harness ha roto algo: arréglalo antes de seguir.

### Step 8: Corregir el maestro

Aplica en `docs/superpowers/plans/2026-08-10-ui-ux-overhaul-00-master.md` las cuatro correcciones de §0.4:

8a. En la tabla de §5.3, sustituye las cifras de colores por las medidas: `chat_screen` 16, `reserva_detail_screen` 9, `conversaciones_list_screen` 3, y la fila de tarjetas por `cotizacion 31 · reserva 26 · review 13 · historial(muerta) 12 · imagen 5 · audio 2 · vehiculo 0 = 89 en cards/, 133 en el módulo`.

8b. En la fila de tarjetas, sustituye "**Todas con ancho fijo**" por el desglose de §0.3, indicando que el desbordamiento real es **a 320 px** y que a partir de 375 px el defecto no es desbordar sino no crecer.

8c. Reescribe el contrato de `chat_screen`: el master-detail se sustituye por "columna de lectura centrada a `maxReadingWidth` (720) desde `expanded`", con nota que remita al §18.1 de la Fase 6 para el coste del master-detail.

8d. Añade bajo la tabla de §5.3 esta nota:

> **Corregido el 2026-08-12 al escribir la Fase 6.** La tarjeta `historial` que esta tabla describía (ancho fijo 260, 12 colores literales) es `widgets/cards/historial_chat_card.dart`, que **no la importa nadie**. La que `chat_screen` usa es otra clase con el mismo nombre en `widgets/historial_chat_card.dart`, sin ancho fijo y con otro defecto (burbuja dentro de burbuja). Ver Fase 6 §0.5. Las cifras de color de esta tabla estaban además por debajo de lo real: 133 en el módulo, no 73.

### Step 9: Commit

```
feat(chat): extraer ChatBubble y el harness de tests del módulo

ChatBubble concentra lo único que depende de `isMe` (alineación, cola y
fondo) y acota el ancho de la burbuja: 80 % del disponible hasta `medium`,
y `maxReadingWidth` (720) desde `expanded`. Hoy la burbuja no tiene tope y
a 1440 px una línea de texto ocupa 1376 px, ~200 caracteres por línea.

Añade `test/support/chat_harness.dart` con los dobles de los tres
providers que la presentación lee. Los dobles usan `implements` y no
`extends` porque `UserProfileProvider` inicializa un `UserService` que toca
`FirebaseFirestore.instance` en la declaración del campo.

Corrige cuatro datos del plan maestro §5.3 medidos sobre HEAD: 133 colores
literales en el módulo (no 73), la tarjeta de historial descrita ahí es
código muerto, y el contrato de master-detail no es realizable sin
reestructurar el router (pasa a bloqueo a consultar).
```

---

## 3. Task 2: `ChatCardShell` — la carcasa copiada en cuatro tarjetas

**Files:**
- Create: `lib/features/chat/presentation/widgets/chat_card_shell.dart`
- Create: `test/features/chat/presentation/widgets/chat_card_shell_test.dart`

**Interfaces:**
- Consumes: `AppBreakpoints`, `WindowClass` (Fase 1 Task 1); `ChatBubble.maxWidthFor` (Task 1); `AppStatusBadge`, `AppStatusType` (ya existe en `lib/core/widgets/app_status_badge.dart`); `AppTextStyles`, `AppColors`, `AppRadius`, `AppSpacing`.
- Produces: `class ChatCardShell extends StatelessWidget` con `ChatCardShell({required IconData icon, required String title, required Widget child, Widget? trailing, String? semanticLabel})`. Consumido por las Tasks 3, 8, 9 y 10.

### Step 1: Confirmar que la carcasa está copiada cuatro veces

Antes de extraer, verifica que lo que se extrae existe. Estas cuatro comparten estructura idéntica:

| Fichero | Ancho | Cabecera | Icono | Título |
|---|---:|---|---|---|
| [cotizacion_chat_card.dart:214-284](../../../lib/features/chat/presentation/widgets/cards/cotizacion_chat_card.dart#L214-L284) | 300 | `Colors.black12` / `grey.shade100` | `request_quote` | 'Cotización de Servicio' |
| [reserva_chat_card.dart:194-260](../../../lib/features/chat/presentation/widgets/cards/reserva_chat_card.dart#L194-L260) | 260 | idéntica | `event` | 'Reserva de Cita' |
| [review_chat_card.dart:72-114](../../../lib/features/chat/presentation/widgets/cards/review_chat_card.dart#L72-L114) | 280 | idéntica | `star` | 'Servicio Finalizado' |
| [cards/historial_chat_card.dart:31-73](../../../lib/features/chat/presentation/widgets/cards/historial_chat_card.dart#L31-L73) | 260 | idéntica | `history` | 'Historial Adjunto' (muerta) |

Y **solo una** de las cuatro hace flexible su cabecera: `cotizacion` envuelve el bloque icono+título en `Expanded` y el `Text` en `Flexible` con `overflow: TextOverflow.ellipsis` ([L241-261](../../../lib/features/chat/presentation/widgets/cards/cotizacion_chat_card.dart#L241-L261)). Las otras tres no, y por eso `reserva_chat_card` desborda 118 px (§0.2). La carcasa adopta el patrón de `cotizacion` para las cuatro.

### Step 2: Escribir el test — debe fallar

```dart
// test/features/chat/presentation/widgets/chat_card_shell_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/widgets/app_status_badge.dart';
import 'package:autodoc/features/chat/presentation/widgets/chat_bubble.dart';
import 'package:autodoc/features/chat/presentation/widgets/chat_card_shell.dart';
import '../../../../support/responsive_harness.dart';
import '../../../../support/contrast.dart';

Widget _shellEnBurbuja({required bool isMe, String? titulo}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: ChatBubble(
          isMe: isMe,
          child: ChatCardShell(
            icon: Icons.event,
            title: titulo ?? 'Reserva de Cita',
            trailing: const AppStatusBadge(
              text: 'Cotización Enviada',
              type: AppStatusType.info,
            ),
            child: const Text('contenido'),
          ),
        ),
      ),
    );

void main() {
  testWidgets('la cabecera no desborda con título y badge largos en 320 px',
      (tester) async {
    await pumpAtWidth(
      tester,
      _shellEnBurbuja(
        isMe: false,
        titulo: 'Cotización de Servicio de Mantenimiento Preventivo',
      ),
      width: 320,
    );
    expectNoOverflow(tester);
  });

  testWidgets('no desborda en ningún ancho auditado, propia y ajena',
      (tester) async {
    for (final width in kAuditWidths) {
      for (final isMe in [true, false]) {
        await pumpAtWidth(tester, _shellEnBurbuja(isMe: isMe), width: width);
        expectNoOverflow(tester);
      }
    }
  });

  testWidgets('el título es legible sobre la cabecera en claro, sea propia o no',
      (tester) async {
    // Ésta es la regresión de §0.1(b): la cabecera pintaba `Colors.white`
    // sobre `Colors.black12` compuesto sobre blanco (#E0E0E0) → 1,32:1.
    for (final isMe in [true, false]) {
      await pumpAtWidth(
        tester,
        _shellEnBurbuja(isMe: isMe),
        width: 375,
        brightness: Brightness.light,
      );
      final texto = tester.widget<Text>(find.text('Reserva de Cita'));
      final colorTexto = texto.style!.color!;
      final context = tester.element(find.byType(ChatCardShell));
      final colors = context.appColors;
      expect(
        contrastRatio(colorTexto, colors.surface),
        greaterThanOrEqualTo(4.5),
        reason: 'El título de la tarjeta debe cumplir AA sobre su propia '
            'superficie, independientemente de isMe (isMe=$isMe).',
      );
    }
  });

  testWidgets('el color del contenido no cambia con isMe', (tester) async {
    Color colorDelTitulo(WidgetTester t) =>
        t.widget<Text>(find.text('Reserva de Cita')).style!.color!;

    await pumpAtWidth(tester, _shellEnBurbuja(isMe: false), width: 375);
    final ajeno = colorDelTitulo(tester);
    await pumpAtWidth(tester, _shellEnBurbuja(isMe: true), width: 375);
    final propio = colorDelTitulo(tester);

    expect(propio, ajeno,
        reason: 'Regla de la fase: isMe decide burbuja, nunca contenido.');
  });

  testWidgets('crece con el espacio disponible en vez de quedarse fija',
      (tester) async {
    await pumpAtWidth(tester, _shellEnBurbuja(isMe: false), width: 375);
    final estrecha = tester.getSize(find.byType(ChatCardShell)).width;
    await pumpAtWidth(tester, _shellEnBurbuja(isMe: false), width: 768);
    final ancha = tester.getSize(find.byType(ChatCardShell)).width;
    expect(ancha, greaterThan(estrecha),
        reason: 'Las tarjetas tenían ancho fijo (260/280/300) y no crecían.');
  });
}
```

### Step 3: Verificar el fallo exacto

Run: `flutter test test/features/chat/presentation/widgets/chat_card_shell_test.dart`

Expected: **FAIL** — `Error: Couldn't resolve the package 'autodoc/features/chat/presentation/widgets/chat_card_shell.dart'`.

### Step 4: Implementar `ChatCardShell`

```dart
// lib/features/chat/presentation/widgets/chat_card_shell.dart
import 'package:flutter/material.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';

/// Carcasa común de las tarjetas enriquecidas del chat (cotización, reserva,
/// reseña, historial).
///
/// Dos decisiones que la separan de lo que había:
///
/// 1. **No tiene ancho fijo.** Las cuatro tarjetas usaban 260/280/300 px
///    literales, que desbordan a 320 px de ventana y no crecen nunca. Aquí el
///    ancho lo pone la burbuja (`ChatBubble` ya lo acota).
/// 2. **Sus colores no dependen de `isMe`.** La tarjeta pinta su propia
///    superficie opaca, así que el contenido va sobre *esa* superficie, no
///    sobre la burbuja. Mezclar las dos cosas es lo que producía texto blanco
///    sobre blanco puro (1,00:1) en tema claro — ver §0.1 del plan.
class ChatCardShell extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  /// Normalmente un `AppStatusBadge`. Se encoge antes que el título.
  final Widget? trailing;

  final String? semanticLabel;

  const ChatCardShell({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final tarjeta = Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outline.withValues(alpha: 0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colors.surfaceContainer,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: colors.primary),
                const SizedBox(width: 8),
                // `Expanded` + `ellipsis` es lo que impide el desbordamiento
                // de 118 px que hoy tiene `reserva_chat_card`: sin un hijo
                // flexible, un `Row` con `spaceBetween` no cede nunca.
                Expanded(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 6),
                  Flexible(child: trailing!),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: DefaultTextStyle.merge(
              style: TextStyle(color: colors.textPrimary),
              child: child,
            ),
          ),
        ],
      ),
    );

    if (semanticLabel == null) return tarjeta;
    return Semantics(label: semanticLabel, container: true, child: tarjeta);
  }
}
```

### Step 5: Verificar que pasa

Run: `flutter test test/features/chat/presentation/widgets/chat_card_shell_test.dart`

Expected: **PASS**, 5 tests.

Si el test de contraste falla porque `colors.textPrimary` sobre `colors.surface` no llega a 4,5:1, **el defecto está en la paleta, no aquí**: para y repórtalo (§2 del maestro prohíbe compensar localmente tocando `AppPalette`). Con los valores actuales (`lightTextPrimary #0F172A` sobre `lightSurface #F7F6F8`) el ratio es holgado.

### Step 6: Comprobar que `AppStatusBadge` sustituye a los badges de colores crudos

Los tres ficheros con badge usan `Colors.orange/green/red/blue` con texto blanco de 10 px bold, que da entre **2,04:1 y 3,68:1** (§0.6). `AppStatusBadge` ya resuelve esto correctamente: pinta el texto en el color de estado y el fondo en ese color al 15 %, lo que sube el contraste en vez de bajarlo.

Escribe la tabla de correspondencia que usarán las Tasks 5, 9 y 10, y déjala en el doc-comment de `ChatCardShell` para que no se reinvente tres veces:

```dart
/// Correspondencia de estados → `AppStatusType`, común a reserva y cotización:
///
/// | estado        | AppStatusType | dónde                        |
/// |---------------|---------------|------------------------------|
/// | `pendiente`   | `warning`     | reserva, cotización          |
/// | `confirmada`  | `success`     | reserva                      |
/// | `aceptada`    | `success`     | cotización ("En Proceso")    |
/// | `rechazada`   | `error`       | reserva, cotización          |
/// | `cotizada`    | `info`        | reserva                      |
/// | `finalizada`  | `info`        | cotización                   |
```

### Step 7: Commit

```
feat(chat): extraer ChatCardShell, la carcasa copiada en cuatro tarjetas

Cotización, reserva, reseña e historial repiten la misma estructura
(Container de ancho fijo → cabecera coloreada con icono+título+badge →
cuerpo con padding 12). ChatCardShell la unifica con dos cambios de
comportamiento:

- Sin ancho fijo: los 260/280/300 px literales desbordan a 320 px de
  ventana y no crecen nunca. Ahora el ancho lo pone ChatBubble.
- Sin dependencia de `isMe` para el color: la tarjeta pinta su propia
  superficie, así que el contenido va sobre esa superficie. Mezclar las dos
  cosas producía texto blanco sobre blanco puro (1,00:1) en tema claro.

La cabecera usa Expanded + ellipsis (el patrón que solo cotizacion_chat_card
tenía), que es lo que elimina el desbordamiento de 118 px de reserva.
```

---

## 4. Task 3: eliminar el `HistorialChatCard` duplicado y arreglar el vivo

**Files:**
- Delete: `lib/features/chat/presentation/widgets/cards/historial_chat_card.dart`
- Delete: `lib/features/chat/presentation/widgets/historial_chat_card.dart`
- Create: `lib/features/chat/presentation/widgets/cards/historial_chat_card.dart` (reescrito, ruta del muerto, firma del vivo)
- Modify: `lib/features/chat/presentation/pages/chat_screen.dart` (solo la importación y la llamada)
- Create: `test/features/chat/presentation/widgets/cards/historial_chat_card_test.dart`

**Interfaces:**
- Consumes: `ChatCardShell` (Task 2); `MensajeModel` (ya existe); `pumpChatWidget` (Task 1); `AppButton`, `AppButtonType` (Fase 3 Task 1).
- Produces: `class HistorialChatCard extends StatelessWidget` con `HistorialChatCard({required MensajeModel mensaje})` — **una sola clase con ese nombre en todo el proyecto**, sin los parámetros `isMe` ni `colors`. Consumido por `chat_screen` (Task 11).

### Step 1: Confirmar que el duplicado está muerto antes de borrarlo

No borres por lo que dice §0.5: compruébalo.

```bash
grep -rn "HistorialChatCard\|historial_chat_card" lib/ test/ --include=*.dart
```

Expected: exactamente seis coincidencias — la importación relativa y la llamada en `chat_screen.dart` (L5 y L624), y la declaración de clase + constructor en cada uno de los dos ficheros. **Ninguna referencia a `cards/historial_chat_card.dart` desde fuera de sí mismo.**

Si aparece cualquier otro consumidor, para: el análisis de §0.5 es incorrecto y hay que rehacerlo antes de borrar nada.

### Step 2: Escribir el test — debe fallar

El test fija las dos correcciones: una sola clase, y sin doble burbuja.

```dart
// test/features/chat/presentation/widgets/cards/historial_chat_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/features/chat/data/models/mensaje_model.dart';
import 'package:autodoc/features/chat/presentation/widgets/chat_bubble.dart';
import 'package:autodoc/features/chat/presentation/widgets/chat_card_shell.dart';
import 'package:autodoc/features/chat/presentation/widgets/cards/historial_chat_card.dart';
import '../../../../../support/chat_harness.dart';
import '../../../../../support/responsive_harness.dart';

MensajeModel _mensaje() => MensajeModel(
      id: 'm1',
      idRemitente: 'u1',
      idReceptor: 'u2',
      contenido: 'veh-123',
      tipo: 'historial',
      timestamp: DateTime(2026, 8, 1),
      estado: 'enviado',
    );

Widget _enBurbuja({required bool isMe}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: ChatBubble(
          isMe: isMe,
          child: HistorialChatCard(mensaje: _mensaje()),
        ),
      ),
    );

void main() {
  testWidgets('no dibuja una segunda burbuja dentro de la burbuja',
      (tester) async {
    await pumpChatWidget(tester, _enBurbuja(isMe: true), width: 375);
    // El defecto original: la tarjeta devolvía su propio Align + Container
    // con `color: isMe ? colors.primary : ...`, dentro de la burbuja que ya
    // tiene ese mismo color. Ahora la superficie la pone ChatCardShell.
    expect(find.byType(ChatBubble), findsOneWidget);
    expect(find.byType(ChatCardShell), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(HistorialChatCard),
        matching: find.byType(Align),
      ),
      findsNothing,
      reason: 'Un Align sin widthFactor dentro de la burbuja la estiraba a '
          'todo el ancho de la lista, independientemente del contenido.',
    );
  });

  testWidgets('la burbuja se ajusta al contenido, no al ancho de la lista',
      (tester) async {
    await pumpChatWidget(tester, _enBurbuja(isMe: true), width: 1024);
    final anchoBurbuja = tester.getSize(find.byType(ChatBubble)).width;
    // 1024 − 32 de padding = 992 disponibles. Antes, el Align lo ocupaba todo.
    expect(anchoBurbuja, lessThan(992 * 0.9),
        reason: 'La burbuja de historial ocupaba todo el ancho disponible.');
  });

  testWidgets('no desborda en ningún ancho auditado', (tester) async {
    for (final width in kAuditWidths) {
      await pumpChatWidget(tester, _enBurbuja(isMe: false), width: width);
      expectNoOverflow(tester);
    }
  });

  testWidgets('el botón de ver historial navega a la ruta del vehículo',
      (tester) async {
    // Protege el único comportamiento de negocio de esta tarjeta: el id del
    // vehículo viaja en `mensaje.contenido`, no en metadata.
    await pumpChatWidget(tester, _enBurbuja(isMe: false), width: 375);
    expect(find.text('Ver Historial Completo'), findsOneWidget);
  });
}
```

### Step 3: Verificar el fallo exacto

Run: `flutter test test/features/chat/presentation/widgets/cards/historial_chat_card_test.dart`

Expected: **FAIL** de compilación — `Error: No named parameter with the name 'mensaje'`, sobre el `HistorialChatCard` de `cards/`, que hoy recibe `metadata` e `isMe`. Ése es el fallo correcto: demuestra que las dos clases existen y que la importación por ruta `cards/` resuelve a la muerta.

### Step 4: Borrar los dos ficheros y escribir el nuevo

4a. `git rm lib/features/chat/presentation/widgets/cards/historial_chat_card.dart`

4b. `git rm lib/features/chat/presentation/widgets/historial_chat_card.dart`

4c. Crear en la ruta canónica (`cards/`, junto a las otras seis tarjetas):

```dart
// lib/features/chat/presentation/widgets/cards/historial_chat_card.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:autodoc/core/utils/l10n_extension.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/features/chat/data/models/mensaje_model.dart';
import 'package:autodoc/features/chat/presentation/widgets/chat_card_shell.dart';

/// Tarjeta de "historial de vehículo compartido".
///
/// Hasta la Fase 6 existían **dos** clases con este nombre: una en
/// `widgets/` (la que usaba `chat_screen`) y otra en `widgets/cards/` (código
/// muerto que nadie importaba). Ésta las sustituye a las dos.
///
/// Ya no recibe `isMe` ni `colors`: la superficie y los colores los pone
/// `ChatCardShell`, y la burbuja la pone `ChatBubble`. La versión anterior
/// dibujaba su propio `Align` + `Container` coloreado **dentro** de la
/// burbuja, lo que producía una burbuja dentro de otra del mismo color y
/// estiraba el mensaje a todo el ancho de la lista.
class HistorialChatCard extends StatelessWidget {
  final MensajeModel mensaje;

  const HistorialChatCard({super.key, required this.mensaje});

  @override
  Widget build(BuildContext context) {
    return ChatCardShell(
      icon: Icons.history_edu,
      title: 'Historial de Vehículo Compartido',
      semanticLabel: 'Historial de vehículo compartido',
      child: SizedBox(
        width: double.infinity,
        child: AppButton(
          text: context.l10n.chatViewFullHistory,
          type: AppButtonType.secondary,
          onPressed: () =>
              context.push('/dashboard/history/${mensaje.contenido}'),
        ),
      ),
    );
  }
}
```

### Step 5: Actualizar `chat_screen`

5a. Sustituye la importación relativa de [chat_screen.dart:5](../../../lib/features/chat/presentation/pages/chat_screen.dart#L5) por una absoluta, coherente con las otras 30 del fichero:

```dart
import 'package:autodoc/features/chat/presentation/widgets/cards/historial_chat_card.dart';
```

5b. Sustituye la llamada de [L624](../../../lib/features/chat/presentation/pages/chat_screen.dart#L624):

```dart
      case 'historial':
        return HistorialChatCard(mensaje: msg);
```

5c. `_buildMessageContent` deja de necesitar `colors` **por este caso**, pero lo siguen usando otros. No cambies la firma aquí: se limpia en la Task 11.

### Step 6: Verificar que pasa

Run: `flutter test test/features/chat/presentation/widgets/cards/historial_chat_card_test.dart`

Expected: **PASS**, 4 tests.

Run: `flutter analyze`

Expected: sin issues nuevos. En particular, ninguna importación sin usar en `chat_screen.dart` (la relativa desapareció).

### Step 7: Commit

```
refactor(chat): unificar las dos clases HistorialChatCard

Existían dos clases con el mismo nombre: widgets/historial_chat_card.dart
(la que usaba chat_screen, importada con ruta relativa) y
widgets/cards/historial_chat_card.dart (118 líneas y 12 colores literales
que no importaba nadie). Se borran las dos y queda una en `cards/`.

La versión viva tenía además un defecto propio: devolvía un Align con su
propio Container coloreado, renderizado dentro de la burbuja de chat_screen
que ya tiene ese color y ese padding. Resultado: burbuja dentro de burbuja
con 32 px de sangrado, y un Align sin widthFactor que estiraba el mensaje a
todo el ancho de la lista. Ahora usa ChatCardShell.
```

---

## 5. Task 4: `conversaciones_list_screen` — quitar `responsive_framework`

**Files:**
- Modify: `lib/features/chat/presentation/pages/conversaciones_list_screen.dart`
- Create: `test/features/chat/presentation/pages/conversaciones_list_screen_test.dart`

**Interfaces:**
- Consumes: `AppBreakpoints`, `WindowClass`, `WindowClassX` (Fase 1 Task 1); `AppPageBody` (Fase 1 Task 5); `AppEmptyState` (Fase 3 Task 7); `AppButton` (Fase 3 Task 1); `pumpChatWidget`, `FakeChatProvider`, `fakeChatUser` (Task 1); `isMechanicRole` (ya existe).
- Produces: nada nuevo. Elimina la última llamada a `responsive_framework` del módulo.

### Step 1: Leer las skills obligatorias

`ui-ux-pro-max` y `emil-design-eng`. Las dos reglas que gobiernan esta pantalla son **objetivos táctiles ≥ 48 dp** y **estado vacío accionable**: el estado vacío actual ([L183-208](../../../lib/features/chat/presentation/pages/conversaciones_list_screen.dart#L183-L208)) dice "Contacta a un taller para iniciar un chat" pero no ofrece ningún camino para hacerlo. `AppEmptyState` acepta un `action`.

### Step 2: Escribir el test — debe fallar

```dart
// test/features/chat/presentation/pages/conversaciones_list_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/widgets/app_empty_state.dart';
import 'package:autodoc/features/chat/data/models/conversacion_model.dart';
import 'package:autodoc/features/chat/presentation/pages/conversaciones_list_screen.dart';
import '../../../../support/chat_harness.dart';
import '../../../../support/responsive_harness.dart';

ConversacionModel _conv({int noLeidos = 0, String nombre = 'Taller Escobar'}) =>
    ConversacionModel(
      id: 'c1',
      idPropietario: 'u1',
      idMecanico: 'm1',
      nombrePropietario: 'Ana Pérez',
      nombreMecanico: nombre,
      ultimoMensaje: 'Le confirmo la cita para el jueves a las 10.',
      ultimoMensajeTs: DateTime(2026, 8, 11),
      noLeidosPropietario: noLeidos,
      noLeidosMecanico: 0,
    );

void main() {
  testWidgets('no usa responsive_framework en ningún ancho', (tester) async {
    // Verificación estructural: `ResponsiveBreakpoints.of(context)` lanza si
    // no hay un `ResponsiveBreakpoints.builder` por encima. `pumpChatWidget`
    // no lo monta, así que si la pantalla sigue llamándolo, este test explota.
    for (final width in kAuditWidths) {
      await pumpChatWidget(
        tester,
        const ConversacionesListScreen(),
        width: width,
        chatProvider: FakeChatProvider(conversaciones: [_conv()]),
        user: fakeChatUser(),
      );
      expectNoOverflow(tester);
    }
  });

  testWidgets('usa AppEmptyState cuando no hay conversaciones', (tester) async {
    await pumpChatWidget(
      tester,
      const ConversacionesListScreen(),
      width: 375,
      chatProvider: FakeChatProvider(conversaciones: const []),
      user: fakeChatUser(),
    );
    expect(find.byType(AppEmptyState), findsOneWidget);
  });

  testWidgets('el contador de no leídos se anuncia al lector de pantalla',
      (tester) async {
    await pumpChatWidget(
      tester,
      const ConversacionesListScreen(),
      width: 375,
      chatProvider: FakeChatProvider(conversaciones: [_conv(noLeidos: 3)]),
      user: fakeChatUser(),
    );
    // Hoy el badge es un Container con un Text '3' y ninguna semántica: un
    // lector de pantalla lee "3" suelto, sin decir de qué.
    expect(find.bySemanticsLabel('3 mensajes sin leer'), findsOneWidget);
  });

  testWidgets('acota el ancho de la lista en pantallas grandes',
      (tester) async {
    await pumpChatWidget(
      tester,
      const ConversacionesListScreen(),
      width: 1440,
      chatProvider: FakeChatProvider(conversaciones: [_conv()]),
      user: fakeChatUser(),
    );
    final ancho = tester.getSize(find.byType(ListView)).width;
    expect(ancho, lessThanOrEqualTo(720),
        reason: 'Una fila de conversación de 1440 px deja el nombre a la '
            'izquierda y la hora a 1400 px de distancia.');
  });

  testWidgets('cada fila tiene al menos 48 dp de alto táctil', (tester) async {
    await pumpChatWidget(
      tester,
      const ConversacionesListScreen(),
      width: 375,
      chatProvider: FakeChatProvider(conversaciones: [_conv()]),
      user: fakeChatUser(),
    );
    final alto = tester.getSize(find.byType(ListTile).first).height;
    expect(alto, greaterThanOrEqualTo(48));
  });
}
```

### Step 3: Verificar el fallo exacto

Run: `flutter test test/features/chat/presentation/pages/conversaciones_list_screen_test.dart`

Expected: **FAIL** en el primer test, con `No ResponsiveBreakpointsData found` (o el `assert` equivalente del paquete) lanzado desde [conversaciones_list_screen.dart:62](../../../lib/features/chat/presentation/pages/conversaciones_list_screen.dart#L62).

Ése es exactamente el fallo que se busca: prueba que la dependencia existe y que el harness estándar del proyecto no la satisface.

### Step 4: Migrar el `AppBar`

Sustituye la importación de `responsive_framework` por la de `app_breakpoints`, y [L62-73](../../../lib/features/chat/presentation/pages/conversaciones_list_screen.dart#L62-L73) por:

```dart
    final windowClass = AppBreakpoints.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // Desde `expanded` el shell ya aporta su propia barra superior
      // (Fase 2), así que un AppBar aquí sería el segundo título de la
      // pantalla. El corte pasa de 800 px (responsive_framework TABLET) a
      // 840 px (AppBreakpoints.expanded), que es el del resto de la app.
      appBar: windowClass.isAtLeastExpanded
          ? null
          : AppBar(
              title: Text(
                'Mensajes',
                style: AppTextStyles.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
```

**Nota sobre `Colors.transparent`:** se mantiene. Es un valor de "sin fondo", no un color de marca, y el regex del ratchet de la Fase 1 cubre `Colors.<nombre-de-color>` y `Color(0x…)`, no `transparent`. En cambio el `backgroundColor` del `Scaffold` sí cambia: `isDark ? colors.surfaceContainer : colors.surface` es exactamente lo que ya calcula `Theme.of(context).scaffoldBackgroundColor`, así que la condición desaparece junto con la variable `isDark`.

### Step 5: Acotar el ancho y sustituir el estado vacío

5a. Envuelve el `body` en `AppPageBody(maxWidth: AppBreakpoints.maxReadingWidth, child: …)`.

5b. Sustituye la rama de lista vacía por:

```dart
          : chatProvider.conversaciones.isEmpty
          ? AppEmptyState(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'No tienes mensajes aún',
              description: 'Contacta a un taller para iniciar un chat.',
              // El estado vacío decía qué hacer pero no ofrecía cómo.
              // Solo para propietario: /workshop_directory no le corresponde
              // al rol taller y acabaría en una redirección del router.
              action: isMecanico ? null : const _BuscarTallerButton(),
            )
```

y añade al final del fichero:

```dart
/// Extraído a widget propio para poder construirse `const`: `context.push`
/// necesita un `BuildContext` que el sitio de la llamada no tiene sin un
/// `Builder` intermedio.
class _BuscarTallerButton extends StatelessWidget {
  const _BuscarTallerButton();

  @override
  Widget build(BuildContext context) => AppButton(
        text: 'Buscar taller',
        icon: const Icon(Icons.search),
        onPressed: () => context.push('/workshop_directory'),
      );
}
```

**Verificación obligatoria antes de escribir esto:** confirma que `/workshop_directory` está registrada y es alcanzable para el rol propietario ([app_router.dart:380](../../../lib/core/router/app_router.dart#L380)). Un botón que acaba en una redirección es peor que no tener botón.

5c. Elimina `_buildEmptyState` y el parámetro `isDark` que ya no usa nadie.

### Step 6: Semántica del contador de no leídos

Sustituye el badge de [L158-174](../../../lib/features/chat/presentation/pages/conversaciones_list_screen.dart#L158-L174):

```dart
                      if (noLeidos > 0)
                        Semantics(
                          label: '$noLeidos mensajes sin leer',
                          child: Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(minWidth: 24),
                            decoration: BoxDecoration(
                              color: colors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              noLeidos.toString(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: colors.onPrimary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
```

Dos cambios además de la semántica:

- `Colors.white` → `colors.onPrimary`. En oscuro `primary` es `#81E6D9` y blanco sobre él da **1,47:1**: el contador de no leídos es hoy ilegible en tema oscuro.
- `minWidth: 24` porque con `shape: circle` y `padding: 6`, un contador de dos cifras deforma el círculo en un óvalo.

Sustituye también el `Divider` de [L86-89](../../../lib/features/chat/presentation/pages/conversaciones_list_screen.dart#L86-L89): `isDark ? Colors.white12 : Colors.black12` → `colors.outline.withValues(alpha: 0.4)`.

`AppColors.onPrimary` existe ([app_colors.dart:13](../../../lib/core/theme/app_colors.dart#L13), `lightOnPrimary` blanco / `darkOnPrimary #0F172A`) y da 10,31:1 y 12,12:1 sobre `primary`. Verificado el 2026-08-12.

### Step 7: Verificar que pasa

Run: `flutter test test/features/chat/presentation/pages/conversaciones_list_screen_test.dart`

Expected: **PASS**, 5 tests.

Run: `flutter test test/features/chat/` — Expected: los nuevos en verde, y sigue fallando **solo** `reserva_chat_card_test.dart` (Task 9).

### Step 8: Commit

```
refactor(chat): migrar conversaciones_list_screen fuera de responsive_framework

Era la única llamada a responsive_framework del módulo (largerThan(TABLET),
corte en 800 px). Pasa a AppBreakpoints.isAtLeastExpanded (840 px), el
mismo corte que usa el shell de la Fase 2 — hoy, entre 801 y 839 px, la
pantalla se dibuja como escritorio mientras el shell sigue en móvil.

Además:
- La lista se acota a maxReadingWidth (720). A 1440 px el nombre quedaba a
  la izquierda y la hora a 1400 px de distancia.
- El estado vacío pasa a AppEmptyState con una acción real: decía "contacta
  a un taller" sin ofrecer ningún camino para hacerlo.
- El contador de no leídos usa colors.onPrimary y anuncia "N mensajes sin
  leer". En oscuro era blanco sobre #81E6D9 = 1,47:1, ilegible.
```

---

## 6. Task 5: `reserva_detail_screen` — severidad tokenizada y ancho de lectura

**Files:**
- Modify: `lib/core/theme/app_severity.dart`
- Modify: `lib/features/chat/presentation/pages/reserva_detail_screen.dart`
- Modify: `test/core/theme/app_severity_test.dart`
- Create: `test/features/chat/presentation/pages/reserva_detail_screen_responsive_test.dart`
- Modify: `test/features/chat/presentation/pages/reserva_detail_screen_test.dart` (una aserción)

**Interfaces:**
- Consumes: `AppSeverity`, `AppSeverityStyle` (Fase 4 Task 1); `AppPageBody`, `AppBreakpoints` (Fase 1); `AppButton`, `AppCard`, `AppEmptyState` (Fase 3); `AppStatusBadge`, `AppStatusType` (existente); `FakeFirebaseFirestore` (ya en uso en el test de esta pantalla).
- Produces: `AppSeverity.forReservaEstado(String estado, AppColors colors, {required String pendienteLabel, required String confirmadaLabel, required String rechazadaLabel, required String cotizadaLabel}) -> AppSeverityStyle`. Consumido por las Tasks 9 y 10.

### Step 1: Escribir el test de `forReservaEstado` — debe fallar

Añade a `test/core/theme/app_severity_test.dart`:

```dart
  group('AppSeverity.forReservaEstado', () {
    AppSeverityStyle estilo(String estado) => AppSeverity.forReservaEstado(
          estado,
          AppTheme.light.extension<AppColors>()!,
          pendienteLabel: 'Pendiente',
          confirmadaLabel: 'Confirmada',
          rechazadaLabel: 'Rechazada',
          cotizadaLabel: 'Cotización Enviada',
        );

    test('mapea los cuatro estados conocidos a color, icono y etiqueta', () {
      final colors = AppTheme.light.extension<AppColors>()!;
      expect(estilo('confirmada').color, colors.success);
      expect(estilo('rechazada').color, colors.error);
      expect(estilo('cotizada').color, colors.primary);
      expect(estilo('pendiente').color, colors.warning);
    });

    test('cada estado tiene un icono distinto: el color no es el único canal',
        () {
      final iconos = ['pendiente', 'confirmada', 'rechazada', 'cotizada']
          .map((e) => estilo(e).icon)
          .toSet();
      expect(iconos.length, 4);
    });

    test('un estado desconocido cae en pendiente y no lanza', () {
      // El campo `estado` viene de Firestore como String libre; un valor
      // nuevo introducido por una Cloud Function no debe romper la pantalla.
      expect(estilo('estado_futuro_desconocido').label, 'Pendiente');
    });
  });
```

Run: `flutter test test/core/theme/app_severity_test.dart`

Expected: **FAIL** — `Error: The method 'forReservaEstado' isn't defined for the class 'AppSeverity'`.

### Step 2: Implementar `forReservaEstado`

Añade a `lib/core/theme/app_severity.dart`:

```dart
  /// Severidad de una reserva o cotización a partir de su `estado` de
  /// Firestore.
  ///
  /// A diferencia de [forStatus] y [forExpiry], que reciben enums, aquí el
  /// argumento es un `String` porque eso es lo que hay en el documento
  /// (`reservas/{id}.estado`) y esta fase no toca `data/`. El `default` no es
  /// defensivo por costumbre: una Cloud Function puede introducir un estado
  /// nuevo, y la pantalla debe seguir renderizando algo legible.
  static AppSeverityStyle forReservaEstado(
    String estado,
    AppColors colors, {
    required String pendienteLabel,
    required String confirmadaLabel,
    required String rechazadaLabel,
    required String cotizadaLabel,
  }) =>
      switch (estado) {
        'confirmada' || 'aceptada' => AppSeverityStyle(
            color: colors.success,
            icon: Icons.check_circle_rounded,
            label: confirmadaLabel,
          ),
        'rechazada' => AppSeverityStyle(
            color: colors.error,
            icon: Icons.cancel_rounded,
            label: rechazadaLabel,
          ),
        'cotizada' || 'finalizada' => AppSeverityStyle(
            color: colors.primary,
            icon: Icons.request_quote_rounded,
            label: cotizadaLabel,
          ),
        _ => AppSeverityStyle(
            color: colors.warning,
            icon: Icons.schedule_rounded,
            label: pendienteLabel,
          ),
      };
```

Run: `flutter test test/core/theme/app_severity_test.dart` → **PASS**.

### Step 3: Escribir el test responsivo de la pantalla — debe fallar

```dart
// test/features/chat/presentation/pages/reserva_detail_screen_responsive_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:autodoc/core/constants/firestore_collections.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/widgets/app_status_badge.dart';
import 'package:autodoc/features/chat/presentation/pages/reserva_detail_screen.dart';
import '../../../../support/chat_harness.dart';
import '../../../../support/responsive_harness.dart';

Future<FakeFirebaseFirestore> _conReserva({String estado = 'pendiente'}) async {
  final db = FakeFirebaseFirestore();
  await db.collection(FirestoreCollections.reservas).doc('r1').set({
    'id_conversacion': 'c1',
    'id_propietario': 'u1',
    'id_mecanico': 'm1',
    'id_vehiculo': 'v1',
    'id_taller': 'm1',
    'fecha_hora_propuesta': DateTime(2026, 8, 20, 10, 30),
    'tipo_servicio': 'Cambio de aceite y filtros',
    'estado': estado,
    'fecha_creacion': DateTime(2026, 8, 11),
  });
  return db;
}

void main() {
  testWidgets('no desborda en ningún ancho auditado', (tester) async {
    final db = await _conReserva();
    for (final width in kAuditWidths) {
      await pumpChatWidget(
        tester,
        ReservaDetailScreen(reservaId: 'r1', firestore: db),
        width: width,
        user: fakeChatUser(),
      );
      await tester.pumpAndSettle();
      expectNoOverflow(tester);
    }
  });

  testWidgets('acota el contenido a 720 px en pantallas grandes',
      (tester) async {
    final db = await _conReserva();
    await pumpChatWidget(
      tester,
      ReservaDetailScreen(reservaId: 'r1', firestore: db),
      width: 1440,
      user: fakeChatUser(),
    );
    await tester.pumpAndSettle();
    final ancho = tester.getSize(find.byType(SingleChildScrollView)).width;
    expect(ancho, lessThanOrEqualTo(720));
  });

  testWidgets('el estado usa AppStatusBadge, no un chip de color crudo',
      (tester) async {
    for (final estado in ['pendiente', 'confirmada', 'rechazada', 'cotizada']) {
      final db = await _conReserva(estado: estado);
      await pumpChatWidget(
        tester,
        ReservaDetailScreen(reservaId: 'r1', firestore: db),
        width: 375,
        user: fakeChatUser(),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AppStatusBadge), findsOneWidget,
          reason: 'estado=$estado');
    }
  });

  testWidgets('los tres botones de acción son AppButton', (tester) async {
    final db = await _conReserva();
    await pumpChatWidget(
      tester,
      ReservaDetailScreen(reservaId: 'r1', firestore: db),
      width: 375,
      user: fakeChatUser(),
    );
    await tester.pumpAndSettle();
    // Aceptar cita / Reprogramar / Rechazar
    expect(find.byType(AppButton), findsNWidgets(3));
    expect(find.byType(ElevatedButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
  });
}
```

Run: `flutter test test/features/chat/presentation/pages/reserva_detail_screen_responsive_test.dart`

Expected: **FAIL** en el segundo test — el `SingleChildScrollView` mide 1440, no ≤ 720.

### Step 4: Acotar el ancho

Envuelve el `SingleChildScrollView` de [L271](../../../lib/features/chat/presentation/pages/reserva_detail_screen.dart#L271) en `AppPageBody(maxWidth: AppBreakpoints.maxReadingWidth, child: …)`.

**El orden importa:** `AppPageBody` va **dentro** del `builder` del `StreamBuilder` y **fuera** del `SingleChildScrollView`. Si envolviera al `StreamBuilder` entero también quedarían acotados el indicador de carga y el estado vacío —lo cual es correcto—, pero entonces se reconstruiría en cada snapshot. Dentro del builder y fuera del scroll es lo correcto en ambos ejes.

### Step 5: Sustituir el chip de estado

5a. Elimina el bloque `estadoColor` / `estadoTexto` de [L254-267](../../../lib/features/chat/presentation/pages/reserva_detail_screen.dart#L254-L267), que hoy mezcla `Colors.green`, `Colors.red`, `Colors.blue` y `colors.warning` en la misma expresión ternaria anidada.

5b. Sustituye por:

```dart
          final severidad = AppSeverity.forReservaEstado(
            reserva.estado,
            colors,
            pendienteLabel: 'Pendiente de Confirmación',
            confirmadaLabel: 'Confirmada',
            rechazadaLabel: 'Rechazada',
            cotizadaLabel: 'Cotización Enviada',
          );
```

5c. Sustituye el `Container` del chip ([L291-308](../../../lib/features/chat/presentation/pages/reserva_detail_screen.dart#L291-L308)) por:

```dart
                                AppStatusBadge(
                                  text: severidad.label,
                                  icon: severidad.icon,
                                  type: _statusTypeDe(reserva.estado),
                                ),
```

y añade el mapeo privado al final del `State`, siguiendo la tabla del doc-comment de `ChatCardShell` (Task 2 Step 6):

```dart
  AppStatusType _statusTypeDe(String estado) => switch (estado) {
        'confirmada' => AppStatusType.success,
        'rechazada' => AppStatusType.error,
        'cotizada' => AppStatusType.info,
        _ => AppStatusType.warning,
      };
```

El chip anterior pintaba el texto en el color de estado sobre **ese mismo color al 20 %**: 2,16:1 (verde), 2,64:1 (rojo), 2,37:1 (azul). `AppStatusBadge` usa 15 % de fondo con el color pleno en el texto más un borde, lo que sube el ratio, y el `icon` añade el segundo canal que exige la regla de "el color no es el único indicador".

### Step 6: Migrar botones, tarjeta y estado vacío

6a. Los tres `SizedBox(width: double.infinity, height: 50)` con `ElevatedButton.icon` / `OutlinedButton.icon` / `TextButton` de [L419-495](../../../lib/features/chat/presentation/pages/reserva_detail_screen.dart#L419-L495) pasan a `AppButton` con `type` `primary` / `secondary` / `text`. El `height: 50` desaparece: `AppButton` fija su altura por `AppButtonSize`.

Esto elimina de paso los dos `foregroundColor: Colors.white` sobre `colors.primary`, que en oscuro daban **1,47:1**.

6b. La tarjeta contenedora de [L276-284](../../../lib/features/chat/presentation/pages/reserva_detail_screen.dart#L276-L284) (`isDark ? Colors.white12 : Colors.grey.shade100`, borde `Colors.white24 / Colors.black12`) pasa a `AppCard`.

6c. El estado vacío `'No se encontró esta cita.'` pasa a:

```dart
            return const AppEmptyState(
              icon: Icons.event_busy_rounded,
              title: 'No se encontró esta cita',
              description: 'Puede que se haya cancelado o eliminado.',
            );
```

**Aviso:** [reserva_detail_screen_test.dart:73](../../../test/features/chat/presentation/pages/reserva_detail_screen_test.dart#L73) afirma `find.text('No se encontró esta cita.')` — con punto final. Actualiza esa aserción a `find.byType(AppEmptyState)`, que es más robusta y sigue cubriendo exactamente lo que ese test protege. **No borres ese test:** cubre un bug real ya corregido (C-03, pantalla en blanco al abrir un enlace directo sin `extra`).

### Step 7: Verificar

Run: `flutter test test/features/chat/ test/core/theme/app_severity_test.dart`

Expected: los nuevos en verde, `reserva_detail_screen_test.dart` en verde con la aserción actualizada, y sigue fallando **solo** `reserva_chat_card_test.dart`.

### Step 8: Commit

```
refactor(chat): tokenizar reserva_detail_screen y acotar su ancho

- El contenido se acota a maxReadingWidth (720). A 1440 px la tarjeta medía
  1392 px con dos columnas de fecha/hora flotando en el vacío.
- Los estados dejan de mezclar Colors.green/red/blue con colors.warning en
  la misma expresión: pasan por AppSeverity.forReservaEstado (nuevo) y se
  pintan con AppStatusBadge. El chip anterior ponía el texto sobre su
  propio color al 20 %: entre 2,16:1 y 2,64:1.
- Los tres botones pasan a AppButton, lo que elimina dos
  `foregroundColor: Colors.white` sobre colors.primary (1,47:1 en oscuro).

AppSeverity.forReservaEstado acepta String y no un enum porque el estado
viene de Firestore como texto libre; ante un valor desconocido cae en
`pendiente` en vez de lanzar.
```

---

## 7. Task 6: `vehiculo_chat_card` y `audio_chat_card` — las dos más limpias

Se hacen juntas porque comparten diagnóstico: son las **dos únicas piezas del módulo que ya asumen correctamente** que están dentro de una burbuja de `colors.primary` (una con fondo translúcido, la otra sin fondo propio). Lo que les falta no es color, es semántica y contraste en oscuro.

**Files:**
- Modify: `lib/features/chat/presentation/widgets/cards/vehiculo_chat_card.dart`
- Modify: `lib/features/chat/presentation/widgets/cards/audio_chat_card.dart`
- Create: `test/features/chat/presentation/widgets/cards/vehiculo_chat_card_test.dart`
- Modify: `test/features/chat/presentation/widgets/cards/audio_chat_card_test.dart`

**Interfaces:**
- Consumes: `ChatBubble` (Task 1); `pumpChatWidget` (Task 1); `contrastRatio` (Fase 1 Task 6); `context.appColors`.
- Produces: nada nuevo. `AudioChatCard` **mantiene** su firma actual (`urlArchivo`, `duracionSegundos`, `isMe`) porque `isMe` aquí sí decide color de contenido legítimamente — es la única pieza sin superficie propia. Se documenta esa excepción en el código.

### Step 1: Escribir los tests — deben fallar

```dart
// test/features/chat/presentation/widgets/cards/vehiculo_chat_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/features/chat/presentation/widgets/chat_bubble.dart';
import 'package:autodoc/features/chat/presentation/widgets/cards/vehiculo_chat_card.dart';
import '../../../../../support/chat_harness.dart';
import '../../../../../support/responsive_harness.dart';

const _meta = {
  'marca': 'Toyota',
  'modelo': 'Hilux 4x4 Doble Cabina',
  'anio': 2019,
  'placa': 'ABC-1234',
};

Widget _enBurbuja({bool isMe = true}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: ChatBubble(
          isMe: isMe,
          child: const VehiculoChatCard(metadata: _meta, isMe: isMe),
        ),
      ),
    );

void main() {
  testWidgets('no desborda en ningún ancho auditado, en ambos temas',
      (tester) async {
    for (final width in kAuditWidths) {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        await pumpChatWidget(
          tester,
          _enBurbuja(),
          width: width,
          brightness: brightness,
        );
        expectNoOverflow(tester);
      }
    }
  });

  testWidgets('la placa no se trunca cuando el modelo es largo',
      (tester) async {
    // El Row de año + placa es `spaceBetween` sin hijos flexibles: con un
    // modelo largo a 320 px, uno de los dos desaparecía.
    await pumpChatWidget(tester, _enBurbuja(), width: 320);
    expect(find.text('ABC-1234'), findsOneWidget);
    expectNoOverflow(tester);
  });

  testWidgets('anuncia el vehículo al lector de pantalla', (tester) async {
    await pumpChatWidget(tester, _enBurbuja(), width: 375);
    expect(
      find.bySemanticsLabel('Vehículo compartido: Toyota Hilux 4x4 Doble '
          'Cabina, año 2019, placa ABC-1234'),
      findsOneWidget,
    );
  });

  testWidgets('metadata incompleta no rompe la tarjeta', (tester) async {
    // `metadata` es un Map<String, dynamic> que viene de Firestore: puede
    // llegar sin claves si el mensaje se creó con una versión anterior.
    await pumpChatWidget(
      tester,
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ChatBubble(
          isMe: true,
          child: const VehiculoChatCard(metadata: {}, isMe: true),
        ),
      ),
      width: 375,
    );
    expect(tester.takeException(), isNull);
  });
}
```

Para `audio_chat_card_test.dart`, **añade** a lo que ya existe (no lo reescribas: cubre el bug de `play()` vs `resume()` de `audioplayers` v6, que sigue vigente):

```dart
  testWidgets('el botón de reproducción tiene etiqueta accesible',
      (tester) async {
    await pumpChatWidget(
      tester,
      const ChatBubble(
        isMe: true,
        child: AudioChatCard(
          urlArchivo: 'https://example.com/a.m4a',
          duracionSegundos: 65,
          isMe: true,
        ),
      ),
      width: 375,
    );
    expect(find.bySemanticsLabel('Reproducir nota de voz, 1:05'), findsOneWidget);
  });

  testWidgets('el contenido es legible sobre la burbuja en tema oscuro',
      (tester) async {
    // Regresión de §0.1(a): `contentColor = isMe ? Colors.white : ...`
    // sobre colors.primary, que en oscuro es #81E6D9 → 1,47:1.
    await pumpChatWidget(
      tester,
      const ChatBubble(
        isMe: true,
        child: AudioChatCard(
          urlArchivo: 'https://example.com/a.m4a',
          duracionSegundos: 65,
          isMe: true,
        ),
      ),
      width: 375,
      brightness: Brightness.dark,
    );
    final context = tester.element(find.byType(AudioChatCard));
    final colors = context.appColors;
    final duracion = tester.widget<Text>(find.text('1:05'));
    expect(
      contrastRatio(duracion.style!.color!, colors.primary),
      greaterThanOrEqualTo(4.5),
    );
  });

  testWidgets('el botón cumple el mínimo de 48 dp', (tester) async {
    await pumpChatWidget(
      tester,
      const ChatBubble(
        isMe: true,
        child: AudioChatCard(
          urlArchivo: 'https://example.com/a.m4a',
          duracionSegundos: 5,
          isMe: true,
        ),
      ),
      width: 375,
    );
    final size = tester.getSize(find.byType(IconButton));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });
```

### Step 2: Verificar los fallos exactos

Run: `flutter test test/features/chat/presentation/widgets/cards/`

Expected, tres fallos concretos:

1. `vehiculo_chat_card_test.dart` — `Expected: exactly one matching candidate / Actual: _bySemanticsLabel:<…> / Which: means none were found`. No hay ningún `Semantics` en el módulo.
2. `audio_chat_card_test.dart`, test de etiqueta — el mismo fallo.
3. `audio_chat_card_test.dart`, test de contraste — un valor cercano a **1,47** frente al mínimo de 4,5.

Si el test de 48 dp ya pasa, déjalo: `IconButton` respeta el mínimo por defecto y es correcto que lo verifique.

### Step 3: `vehiculo_chat_card` — hacer flexible el `Row` y añadir semántica

3a. La tarjeta ya no fija ancho: sustituye `Container(width: 250, …)` por el mismo `Container` sin `width`. **No** se migra a `ChatCardShell`: esta tarjeta tiene fondo translúcido a propósito (deja ver la burbuja) y ése es el comportamiento correcto documentado en §0.1. Migrarla a la carcasa opaca sería una regresión visual.

3b. El `Row` de año + placa ([L78-111](../../../lib/features/chat/presentation/widgets/cards/vehiculo_chat_card.dart#L78-L111)) es `spaceBetween` sin hijos flexibles. Envuelve el `Text` del año en `Expanded` y el chip de placa en `Flexible`, con `overflow: TextOverflow.ellipsis` en el año.

3c. Envuelve el `Container` raíz en `Semantics`:

```dart
    final descripcion =
        'Vehículo compartido: $marca $modelo, año $anio, placa $placa';

    return Semantics(
      label: descripcion,
      container: true,
      child: ExcludeSemantics(child: Container(...)),
    );
```

`ExcludeSemantics` en el hijo evita que el lector lea primero la frase completa y después cada fragmento suelto ("Vehículo Compartido", "Toyota Hilux", "Año: 2019", "ABC-1234").

3d. El `Text` del modelo necesita `maxLines: 2, overflow: TextOverflow.ellipsis`: un modelo largo a 320 px produce tres líneas y descuadra la tarjeta.

### Step 4: `audio_chat_card` — semántica, contraste y token

4a. Sustituye `Theme.of(context).extension<AppColors>()` por `context.appColors`, que es la forma usada en el resto del módulo y no devuelve nullable.

4b. Sustituye el cálculo del color de contenido:

```dart
    final colors = context.appColors;
    // Excepción consciente a la regla de §1 ("isMe no decide colores"): esta
    // tarjeta es la única sin superficie propia — se dibuja directamente
    // sobre la burbuja, igual que un mensaje de texto. Por eso sí debe
    // consultar isMe, y por eso usa onPrimary y no Colors.white: en tema
    // oscuro primary es #81E6D9 y el blanco sobre él da 1,47:1.
    final contentColor = widget.isMe ? colors.onPrimary : colors.textPrimary;
```

4c. Envuelve el `IconButton` en semántica útil:

```dart
          Semantics(
            label: _reproduciendo
                ? 'Pausar nota de voz, $_duracionFormateada'
                : 'Reproducir nota de voz, $_duracionFormateada',
            button: true,
            child: ExcludeSemantics(
              child: IconButton(
                icon: Icon(
                  _reproduciendo ? Icons.pause : Icons.play_arrow,
                  color: contentColor,
                ),
                onPressed: _isToggling ? null : _toggle,
              ),
            ),
          ),
```

4d. El `SnackBar` de error (`'No se pudo reproducir la nota de voz'`) pasa a `AppSnackbar.show(context, …, type: SnackbarType.error)`.

**Fuera de alcance, con motivo:** `AudioChatCard` no tiene barra de progreso ni permite buscar dentro del audio. Añadirlo requiere suscribirse a `onPositionChanged` y mantener estado de duración real (la que llega en `duracionSegundos` es la que midió el emisor, no la del fichero). Es una funcionalidad nueva, no un refactor. Ver §17.

### Step 5: Verificar que pasa

Run: `flutter test test/features/chat/presentation/widgets/cards/`

Expected: **PASS**, todos.

El test de contraste debe pasar con holgura: `AppPalette.darkOnPrimary` es `#0F172A` sobre `darkPrimary #81E6D9` = **12,12:1** (y en claro, `lightOnPrimary` blanco sobre `#522C81` = **10,31:1**). Ambos verificados el 2026-08-12. Si falla, la paleta ha cambiado desde que se escribió este plan: para y vuelve a medir antes de tocar nada.

### Step 6: Commit

```
fix(chat): accesibilidad y contraste en las tarjetas de vehículo y audio

Son las dos únicas piezas del módulo que ya asumían correctamente estar
dentro de una burbuja de colors.primary, así que aquí no había que
reestructurar color: faltaba semántica y faltaba el token correcto.

- vehiculo_chat_card: se quita el ancho fijo de 250 px, el Row de año+placa
  pasa a tener hijos flexibles (a 320 px con un modelo largo, uno de los dos
  desaparecía) y la tarjeta se anuncia como una sola frase en vez de cuatro
  fragmentos sueltos.
- audio_chat_card: Colors.white → colors.onPrimary (en oscuro el blanco
  sobre #81E6D9 da 1,47:1), el botón de reproducción anuncia estado y
  duración, y se usa context.appColors en vez de la extensión nullable.
```

---

## 8. Task 7: `imagen_chat_card` — alto sin acotar, Heroes duplicados y un visor sin salida visible

**Files:**
- Modify: `lib/features/chat/presentation/widgets/cards/imagen_chat_card.dart`
- Create: `test/features/chat/presentation/widgets/cards/imagen_chat_card_test.dart`

**Interfaces:**
- Consumes: `ChatBubble` (Task 1); `AppBreakpoints` (Fase 1); `pumpChatWidget` (Task 1).
- Produces: `ImagenChatCard({required String urlArchivo, required bool isMe, required String mensajeId})` — **añade `mensajeId`**, obligatorio, para desambiguar el `Hero`. Consumido por `chat_screen` (Task 11).

### Step 1: Los tres defectos, con su mecanismo

**(a) Alto sin acotar.** [L18-33](../../../lib/features/chat/presentation/widgets/cards/imagen_chat_card.dart#L18-L33) es `Container(width: 250)` con `Image.network(fit: BoxFit.cover)` y **ninguna restricción de alto**. `BoxFit.cover` dentro de una caja de ancho fijo y alto libre resuelve el alto por la relación de aspecto intrínseca: una foto vertical de 3000 × 4000 px produce una burbuja de 250 × 333 px razonable, pero una captura de pantalla alargada (p. ej. 1080 × 7000, algo que la gente manda) produce 250 × 1620. El mensaje ocupa más de una pantalla y el resto de la conversación queda fuera.

**(b) `Hero` con tag colisionable.** `Hero(tag: urlArchivo)`. Si el usuario reenvía la misma imagen, o si el emisor y el receptor mandan la misma URL, hay dos `Hero` con el mismo tag en el mismo árbol y Flutter lanza:

```
There are multiple heroes that share the same tag within a subtree.
```

No es hipotético en un chat: "reenviar la foto de la avería" es exactamente lo que la gente hace.

**(c) El visor no tiene salida visible.** `Dialog(backgroundColor: Colors.transparent)` con un `IconButton(Icons.close, color: Colors.white)` encima de la imagen. Sobre una foto clara —un motor con flash, un documento— la X blanca es invisible, y como el `Dialog` es transparente, tampoco hay borde que la delimite.

### Step 2: Escribir el test — debe fallar

```dart
// test/features/chat/presentation/widgets/cards/imagen_chat_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/features/chat/presentation/widgets/chat_bubble.dart';
import 'package:autodoc/features/chat/presentation/widgets/cards/imagen_chat_card.dart';
import '../../../../../support/chat_harness.dart';
import '../../../../../support/responsive_harness.dart';

void main() {
  testWidgets('dos mensajes con la misma URL no colisionan en el Hero',
      (tester) async {
    // Reenviar una foto es normal en un chat. Con `tag: urlArchivo` esto
    // lanza "There are multiple heroes that share the same tag".
    await pumpChatWidget(
      tester,
      const Column(
        children: [
          ImagenChatCard(
            urlArchivo: 'https://example.com/averia.jpg',
            isMe: true,
            mensajeId: 'm1',
          ),
          ImagenChatCard(
            urlArchivo: 'https://example.com/averia.jpg',
            isMe: false,
            mensajeId: 'm2',
          ),
        ],
      ),
      width: 375,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('el alto de la imagen está acotado', (tester) async {
    await pumpChatWidget(
      tester,
      const ChatBubble(
        isMe: true,
        child: ImagenChatCard(
          urlArchivo: 'https://example.com/larga.jpg',
          isMe: true,
          mensajeId: 'm1',
        ),
      ),
      width: 375,
      height: 800,
    );
    final alto = tester.getSize(find.byType(ImagenChatCard)).height;
    expect(alto, lessThanOrEqualTo(360),
        reason: 'Una captura alargada producía una burbuja de más de una '
            'pantalla de alto y expulsaba el resto de la conversación.');
  });

  testWidgets('la imagen tiene etiqueta accesible', (tester) async {
    await pumpChatWidget(
      tester,
      const ImagenChatCard(
        urlArchivo: 'https://example.com/a.jpg',
        isMe: false,
        mensajeId: 'm1',
      ),
      width: 375,
    );
    expect(find.bySemanticsLabel('Imagen adjunta. Toca para ampliar.'),
        findsOneWidget);
  });

  testWidgets('no desborda en ningún ancho auditado', (tester) async {
    for (final width in kAuditWidths) {
      await pumpChatWidget(
        tester,
        const ChatBubble(
          isMe: true,
          child: ImagenChatCard(
            urlArchivo: 'https://example.com/a.jpg',
            isMe: true,
            mensajeId: 'm1',
          ),
        ),
        width: width,
      );
      expectNoOverflow(tester);
    }
  });
}
```

**Nota sobre `Image.network` en tests:** `flutter_test` no hace peticiones de red; `Image.network` resuelve a un error y dispara el `errorBuilder`. Eso es suficiente para lo que estos tests miden (tags de Hero, restricciones de caja, semántica), pero **no** verifica el aspecto real de una imagen cargada. La comprobación visual del recorte queda en la verificación manual de §15.

### Step 3: Verificar el fallo exacto

Run: `flutter test test/features/chat/presentation/widgets/cards/imagen_chat_card_test.dart`

Expected: **FAIL** de compilación primero — `Error: No named parameter with the name 'mensajeId'`. Tras añadir el parámetro, los tests de alto y semántica deben fallar por su propio motivo, no por compilación. Verifícalos por separado.

### Step 4: Reescribir la tarjeta

```dart
// lib/features/chat/presentation/widgets/cards/imagen_chat_card.dart
import 'package:flutter/material.dart';
import 'package:autodoc/core/theme/app_colors.dart';

/// Imagen adjunta en el chat.
///
/// Tres decisiones frente a la versión anterior:
///
/// 1. **El alto está acotado.** Antes era `Container(width: 250)` sin
///    restricción de alto y `BoxFit.cover`, así que una captura alargada
///    producía una burbuja de más de una pantalla.
/// 2. **El tag del Hero incluye [mensajeId].** Con `tag: urlArchivo`, dos
///    mensajes con la misma imagen (reenviarla es normal) lanzaban
///    "There are multiple heroes that share the same tag".
/// 3. **El botón de cerrar del visor tiene fondo propio.** Antes era una X
///    blanca sobre un `Dialog` transparente: invisible sobre foto clara.
class ImagenChatCard extends StatelessWidget {
  final String urlArchivo;
  final bool isMe;

  /// Identificador del mensaje. Necesario para que el `Hero` sea único
  /// aunque la misma URL aparezca varias veces en la conversación.
  final String mensajeId;

  const ImagenChatCard({
    super.key,
    required this.urlArchivo,
    required this.isMe,
    required this.mensajeId,
  });

  /// Relación de aspecto máxima permitida (alto / ancho). 1.4 deja pasar el
  /// retrato 3:4 (1.33) sin recortar y acota la captura alargada.
  static const double _maxAspectRatio = 1.4;

  String get _heroTag => 'chat-imagen-$mensajeId-$urlArchivo';

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Semantics(
      label: 'Imagen adjunta. Toca para ampliar.',
      button: true,
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // El ancho lo pone la burbuja; el alto se deriva de él, nunca de
            // la relación de aspecto intrínseca de la imagen.
            final ancho = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : 250.0;
            return GestureDetector(
              onTap: () => _showImageDialog(context),
              child: Container(
                margin: const EdgeInsets.only(top: 8),
                constraints: BoxConstraints(
                  maxHeight: ancho * _maxAspectRatio,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Hero(
                    tag: _heroTag,
                    child: Image.network(
                      urlArchivo,
                      fit: BoxFit.cover,
                      width: ancho,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 150,
                        color: colors.surfaceContainer,
                        child: Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          height: 150,
                          color: colors.surfaceContainer,
                          child: Center(
                            child: CircularProgressIndicator(
                              value: progress.expectedTotalBytes != null
                                  ? progress.cumulativeBytesLoaded /
                                      progress.expectedTotalBytes!
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showImageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: InteractiveViewer(
                child: Hero(
                  tag: _heroTag,
                  child: Image.network(urlArchivo, fit: BoxFit.contain),
                ),
              ),
            ),
            // Fondo propio: una X blanca sobre un Dialog transparente
            // desaparece encima de cualquier foto clara.
            Padding(
              padding: const EdgeInsets.all(8),
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 24),
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

**Sobre los dos `Colors` que quedan** (`Colors.transparent` en el `Dialog` y `Colors.black54` / `Colors.white` en el botón de cerrar): son deliberados y se documentan como excepción en la Task 13. Un visor de imagen a pantalla completa es un contexto de fondo desconocido —la foto del usuario—, no una superficie del tema; el par negro-al-54 % + blanco garantiza el contraste sea cual sea la imagen, y seguir el tema aquí lo empeoraría. La excepción se declara en el ratchet, no se esconde.

### Step 5: Verificar que pasa

Run: `flutter test test/features/chat/presentation/widgets/cards/imagen_chat_card_test.dart`

Expected: **PASS**, 4 tests.

### Step 6: Commit

```
fix(chat): acotar el alto de las imágenes y desambiguar sus Heroes

Tres defectos con consecuencia observable:

- Container(width: 250) con BoxFit.cover y sin restricción de alto: el alto
  salía de la relación de aspecto intrínseca, así que una captura alargada
  producía una burbuja de más de una pantalla y expulsaba el resto de la
  conversación. Ahora el alto se deriva del ancho (máx. 1.4×).
- Hero(tag: urlArchivo): reenviar la misma imagen ponía dos Heroes con el
  mismo tag en el árbol y Flutter lanzaba. El tag incluye ahora el
  mensajeId, que ImagenChatCard recibe como parámetro obligatorio.
- El botón de cerrar del visor era una X blanca sobre un Dialog
  transparente: invisible sobre foto clara. Ahora tiene fondo circular.

Se añade semanticLabel: la imagen no se anunciaba de ninguna forma.
```

---

## 9. Task 8: `review_chat_card`

**Files:**
- Modify: `lib/features/chat/presentation/widgets/cards/review_chat_card.dart`
- Create: `test/features/chat/presentation/widgets/cards/review_chat_card_test.dart`

**Interfaces:**
- Consumes: `ChatCardShell` (Task 2); `ChatBubble` (Task 1); `AppButton` (Fase 3); `pumpChatWidget`, `FakeChatProvider` (Task 1); `contrastRatio` (Fase 1 Task 6).
- Produces: nada nuevo. La firma pública no cambia.

### Step 1: Escribir el test — debe fallar

```dart
// test/features/chat/presentation/widgets/cards/review_chat_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/features/chat/presentation/widgets/chat_bubble.dart';
import 'package:autodoc/features/chat/presentation/widgets/chat_card_shell.dart';
import 'package:autodoc/features/chat/presentation/widgets/cards/review_chat_card.dart';
import '../../../../../support/chat_harness.dart';
import '../../../../../support/contrast.dart';
import '../../../../../support/responsive_harness.dart';

Widget _card({required bool isMe, String estado = 'pendiente'}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: ChatBubble(
          isMe: isMe,
          child: ReviewChatCard(
            metadata: {'estado': estado, 'tallerNombre': 'Taller Escobar'},
            isMe: isMe,
            tallerId: 't1',
            mensajeId: 'm1',
            conversacionId: 'c1',
          ),
        ),
      ),
    );

void main() {
  testWidgets('el texto es legible cuando el mensaje es propio y el tema claro',
      (tester) async {
    // Regresión de §0.1(b): con isMe=true el cuerpo se pintaba Colors.white
    // sobre una tarjeta Colors.white → 1,00:1, invisible.
    await pumpChatWidget(tester, _card(isMe: true), width: 375);
    final context = tester.element(find.byType(ChatCardShell));
    final colors = context.appColors;
    final cuerpo = tester.widget<Text>(
      find.textContaining('Por favor califica'),
    );
    final color = cuerpo.style?.color ??
        DefaultTextStyle.of(
          tester.element(find.textContaining('Por favor califica')),
        ).style.color!;
    expect(contrastRatio(color, colors.surface), greaterThanOrEqualTo(4.5));
  });

  testWidgets('el aviso de reseña enviada usa el token de éxito, no Colors.green',
      (tester) async {
    await pumpChatWidget(tester, _card(isMe: false, estado: 'completada'),
        width: 375);
    final context = tester.element(find.byType(ChatCardShell));
    final colors = context.appColors;
    final icono = tester.widget<Icon>(find.byIcon(Icons.check_circle));
    expect(icono.color, colors.success);
    // Colors.green sobre tarjeta blanca daba 2,78:1.
    expect(contrastRatio(icono.color!, colors.surface),
        greaterThanOrEqualTo(3.0));
  });

  testWidgets('usa AppButton y ChatCardShell', (tester) async {
    await pumpChatWidget(tester, _card(isMe: false), width: 375);
    expect(find.byType(ChatCardShell), findsOneWidget);
    expect(find.byType(AppButton), findsOneWidget);
    expect(find.byType(ElevatedButton), findsNothing);
  });

  testWidgets('no desborda en ningún ancho auditado, en ambos temas',
      (tester) async {
    for (final width in kAuditWidths) {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        await pumpChatWidget(tester, _card(isMe: false),
            width: width, brightness: brightness);
        expectNoOverflow(tester);
      }
    }
  });

  testWidgets('crece con el ancho disponible', (tester) async {
    await pumpChatWidget(tester, _card(isMe: false), width: 375);
    final estrecha = tester.getSize(find.byType(ChatCardShell)).width;
    await pumpChatWidget(tester, _card(isMe: false), width: 768);
    expect(tester.getSize(find.byType(ChatCardShell)).width,
        greaterThan(estrecha),
        reason: 'La tarjeta tenía width: 280 fijo.');
  });
}
```

### Step 2: Verificar el fallo exacto

Run: `flutter test test/features/chat/presentation/widgets/cards/review_chat_card_test.dart`

Expected: **FAIL** en el primer test con un ratio de **1.0** (blanco sobre blanco), y en el tercero con `Expected: exactly one matching candidate` para `ChatCardShell`.

Anota el 1.0 en el registro de ejecución: es la prueba directa de §0.1(b) sobre esta tarjeta concreta.

### Step 3: Migrar a `ChatCardShell`

Sustituye [L72-114](../../../lib/features/chat/presentation/widgets/cards/review_chat_card.dart#L72-L114) (el `Container` de ancho fijo, su cabecera y su `Padding`) por:

```dart
    return ChatCardShell(
      icon: Icons.star,
      title: 'Servicio Finalizado',
      semanticLabel: 'Servicio finalizado, pendiente de calificar',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Por favor califica el servicio que has recibido para ayudar a '
            'otros usuarios.',
          ),
          ...
        ],
      ),
    );
```

El `Text` del cuerpo pierde su `style` explícito: `ChatCardShell` ya envuelve el hijo en un `DefaultTextStyle.merge` con `colors.textPrimary`. Eso es lo que arregla el 1,00:1 y lo que impide que vuelva.

El `semanticLabel` debe reflejar el estado real: si `estado == 'completada'`, usa `'Servicio finalizado, reseña enviada'`.

### Step 4: Tokenizar el aviso de reseña enviada

Sustituye [L146-161](../../../lib/features/chat/presentation/widgets/cards/review_chat_card.dart#L146-L161):

```dart
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: colors.success, size: 16),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          context.l10n.chatReviewThanks,
                          style: TextStyle(
                            color: colors.success,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
```

**Atención, aquí hay un dato medido que cambia el diseño de la solución.** `Colors.green` sobre tarjeta blanca daba 2,78:1, pero `AppPalette.lightSuccess` (`#48BB78`) sobre `lightSurface` (`#F7F6F8`) da **2,25:1** — todavía peor. Cambiar un color literal por el token **no** arregla el contraste en tema claro: en oscuro el mismo token da 7,36:1, así que el problema es solo del tema claro y es de la paleta, no de esta tarjeta.

Por eso el reparto es éste, y el test de arriba está escrito en consecuencia:

- **El texto** (`chatReviewThanks`) va en `colors.textPrimary` → 16,57:1. Es quien porta el mensaje.
- **El icono** va en `colors.success` → es un refuerzo cromático, no el único canal, y como tal no está sujeto al umbral de 4,5:1.

Sustituye por tanto la aserción del segundo test:

```dart
    expect(icono.color, colors.success);
    final texto = tester.widget<Text>(find.text('¡Gracias por tu reseña!'));
    expect(
      contrastRatio(texto.style!.color!, colors.surface),
      greaterThanOrEqualTo(4.5),
      reason: 'lightSuccess (#48BB78) sobre lightSurface da 2,25:1: el color '
          'no puede ser quien porte el mensaje en tema claro.',
    );
```

**No escribas el test con un umbral de 3,0 sobre el icono: fallaría.** Y el `lightSuccess` a 2,25:1 se reporta en §18.4 — es un defecto de paleta que afecta a toda la app, no solo a esta tarjeta.

### Step 5: Migrar el botón

`ElevatedButton` con `backgroundColor: colors.primary, foregroundColor: Colors.white` → `AppButton(text: context.l10n.chatRateService, onPressed: () => _onRatePressed(context))`. Elimina el `SizedBox(width: double.infinity)` externo si `AppButton` ya expande; si no, consérvalo.

### Step 6: Verificar que pasa

Run: `flutter test test/features/chat/presentation/widgets/cards/review_chat_card_test.dart`

Expected: **PASS**, 5 tests.

### Step 7: Commit

```
fix(chat): review_chat_card legible y sin ancho fijo

Con isMe=true en tema claro, el cuerpo de la tarjeta se pintaba
Colors.white sobre una tarjeta Colors.white: contraste 1,00:1, texto
invisible. La migración a ChatCardShell elimina la causa (el color del
contenido ya no depende de isMe) en vez de parchear cada Text.

Además: el aviso de "reseña enviada" pasa de Colors.green (2,78:1 sobre
tarjeta blanca) a colors.success con icono, el botón pasa a AppButton, y
desaparece el width: 280 fijo, que desbordaba a 320 px de ventana.
```

---

## 10. Task 9: `reserva_chat_card` — y borrar el filtro que tapa el desbordamiento

Ésta es la tarea que devuelve la suite del módulo a verde. Es también la única con un test que ya existe, ya falla y ya documenta el defecto.

**Files:**
- Modify: `lib/features/chat/presentation/widgets/cards/reserva_chat_card.dart`
- Modify: `test/features/chat/presentation/widgets/cards/reserva_chat_card_test.dart`

**Interfaces:**
- Consumes: `ChatCardShell` (Task 2); `ChatBubble` (Task 1); `AppSeverity.forReservaEstado` (Task 5); `AppStatusBadge`, `AppStatusType` (existente); `AppButton` (Fase 3); `pumpChatWidget` (Task 1).
- Produces: nada nuevo. La firma pública no cambia.

### Step 1: Reproducir el fallo antes de tocar nada

Run: `flutter test test/features/chat/presentation/widgets/cards/reserva_chat_card_test.dart`

Expected: **FAIL**, exactamente:

```
A RenderFlex overflowed by 118 pixels on the right.
  Row:.../reserva_chat_card.dart:219:20
  constraints: BoxConstraints(0.0<=w<=234.0, 0.0<=h<=Infinity)
```

Confirma el modelo de §0.2 antes de seguir: `260 (ancho fijo) − 2 (Border.all) − 24 (EdgeInsets.all(12)) = 234`. Si el número no cuadra, el fichero ha cambiado desde que se escribió este plan: vuelve a medir.

### Step 2: Endurecer el test antes de arreglar

**No borres todavía el filtro de `FlutterError.onError`.** Primero añade los tests nuevos, que deben fallar por su propio motivo:

```dart
  testWidgets('la cabecera no desborda con el estado de etiqueta más larga',
      (tester) async {
    // 'Cotización Enviada' es la etiqueta más larga de los cuatro estados.
    await pumpChatWidget(
      tester,
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ChatBubble(
          isMe: false,
          child: const ReservaChatCard(
            metadata: {
              'id_reserva': 'r1',
              'estado': 'cotizada',
              'fecha': '2026-08-20T10:00:00.000',
              'hora': '10:00 AM',
            },
            isMe: false,
            mensajeId: 'm1',
            conversacionId: 'c1',
          ),
        ),
      ),
      width: 320,
    );
    expectNoOverflow(tester);
  });

  testWidgets('no desborda en ningún ancho auditado, en ambos temas y roles',
      (tester) async {
    for (final width in kAuditWidths) {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        for (final rol in ['Propietario', 'Mecanico']) {
          await pumpChatWidget(
            tester,
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ChatBubble(
                isMe: false,
                child: const ReservaChatCard(
                  metadata: {
                    'id_reserva': 'r1',
                    'estado': 'pendiente',
                    'fecha': '2026-08-20T10:00:00.000',
                    'hora': '10:00 AM',
                  },
                  isMe: false,
                  mensajeId: 'm1',
                  conversacionId: 'c1',
                ),
              ),
            ),
            width: width,
            brightness: brightness,
            user: fakeChatUser(rol: rol),
          );
          expectNoOverflow(tester);
        }
      }
    }
  });

  testWidgets('el contenido es legible cuando el mensaje es propio',
      (tester) async {
    await pumpChatWidget(
      tester,
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ChatBubble(
          isMe: true,
          child: const ReservaChatCard(
            metadata: {
              'id_reserva': 'r1',
              'estado': 'confirmada',
              'fecha': '2026-08-20T10:00:00.000',
              'hora': '10:00 AM',
            },
            isMe: true,
            mensajeId: 'm1',
            conversacionId: 'c1',
          ),
        ),
      ),
      width: 375,
    );
    final context = tester.element(find.byType(ChatCardShell));
    final colors = context.appColors;
    final fecha = tester.widget<Text>(find.text('20 ago 2026'));
    final color = fecha.style?.color ??
        DefaultTextStyle.of(tester.element(find.text('20 ago 2026'))).style.color!;
    expect(contrastRatio(color, colors.surface), greaterThanOrEqualTo(4.5),
        reason: 'Con isMe=true la fecha se pintaba blanca sobre tarjeta '
            'blanca: 1,00:1.');
  });

  testWidgets('el estado se pinta con AppStatusBadge', (tester) async {
    await pumpChatWidget(
      tester,
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ChatBubble(
          isMe: false,
          child: const ReservaChatCard(
            metadata: {'id_reserva': 'r1', 'estado': 'rechazada'},
            isMe: false,
            mensajeId: 'm1',
            conversacionId: 'c1',
          ),
        ),
      ),
      width: 375,
    );
    final badge = tester.widget<AppStatusBadge>(find.byType(AppStatusBadge));
    expect(badge.type, AppStatusType.error);
  });
```

Run: los cuatro nuevos deben fallar. El primero y el segundo por desbordamiento (el filtro solo tapa el `Row` de la línea 219 y solo en el test original, que tiene su propio `FlutterError.onError`); el tercero con ratio 1.0; el cuarto por `AppStatusBadge` inexistente.

### Step 3: Migrar a `ChatCardShell`

3a. Sustituye el `Container(width: 260, …)` y toda su cabecera ([L194-260](../../../lib/features/chat/presentation/widgets/cards/reserva_chat_card.dart#L194-L260)) por:

```dart
    final severidad = AppSeverity.forReservaEstado(
      estado,
      colors,
      pendienteLabel: 'Pendiente',
      confirmadaLabel: 'Confirmada',
      rechazadaLabel: 'Rechazada',
      cotizadaLabel: 'Cotización Enviada',
    );

    return ChatCardShell(
      icon: Icons.event,
      title: 'Reserva de Cita',
      semanticLabel: 'Reserva de cita, ${severidad.label}',
      trailing: AppStatusBadge(
        text: severidad.label,
        icon: severidad.icon,
        type: _statusTypeDe(estado),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [ ... ],
      ),
    );
```

3b. Elimina el bloque `badgeColor` / `badgeText` de [L181-192](../../../lib/features/chat/presentation/widgets/cards/reserva_chat_card.dart#L181-L192): lo sustituye entero `AppSeverity.forReservaEstado`.

3c. Añade el mismo `_statusTypeDe` privado de la Task 5 Step 5c. **Sí, es la tercera copia** (aquí, en `reserva_detail_screen` y luego en `cotizacion_chat_card`). Tres copias de un `switch` de cuatro ramas es aceptable; extraerlo a un helper compartido exigiría decidir dónde vive un mapeo que depende de dos vocabularios de estado distintos (reserva y cotización comparten tres valores pero no los cuatro). Se anota en §17 como deuda menor consciente, no se resuelve a medias.

3d. En el cuerpo, elimina **todos** los `color: isMe ? Colors.white : …` y `isMe ? Colors.white70 : colors.textSecondary`. Los que eran `textPrimary` se quedan sin `color` (lo hereda el `DefaultTextStyle` de la carcasa); los que eran `textSecondary` pasan a `color: colors.textSecondary` sin ternario.

Son 12 sustituciones. Hazlas una a una y comprueba tras cada bloque que el fichero sigue compilando: es la parte de la tarea donde es más fácil dejar un ternario a medias.

### Step 4: Migrar los cuatro botones

Los `OutlinedButton` / `ElevatedButton` de [L318-408](../../../lib/features/chat/presentation/widgets/cards/reserva_chat_card.dart#L318-L408) pasan a `AppButton`:

| Botón | Antes | Después |
|---|---|---|
| Rechazar (mecánico y propietario) | `OutlinedButton` con `Colors.red` | `AppButton(type: AppButtonType.danger)` o `secondary` con `colors.error` |
| Cotizar y Aceptar | `ElevatedButton` + `Colors.white` sobre primary | `AppButton(type: AppButtonType.primary)` |
| Aceptar (propietario) | `OutlinedButton` con `colors.primary` | `AppButton(type: AppButtonType.secondary)` |
| Ver detalle | `OutlinedButton` con `isMe ? Colors.white : colors.primary` | `AppButton(type: AppButtonType.text)` |

**Verifica primero qué valores acepta `AppButtonType`** en `lib/core/widgets/app_button.dart`. Si no existe un tipo `danger`, usa `secondary` y anótalo en §17: un botón destructivo sin variante propia es una carencia real del sistema, pero inventarla aquí sería ampliar el alcance de la Fase 3 desde la Fase 6.

Los `minimumSize: Size.zero` desaparecen: existían para que los botones cupieran en 260 px. Sin ancho fijo ya no hacen falta, y quitarlos devuelve los objetivos táctiles a su mínimo.

### Step 5: Borrar el filtro del test original — el criterio de éxito

Elimina de `reserva_chat_card_test.dart` el bloque completo [L104-127](../../../test/features/chat/presentation/widgets/cards/reserva_chat_card_test.dart#L104-L127): el comentario de tres párrafos, `final originalOnError = FlutterError.onError;`, la asignación del filtro y el `addTearDown`.

Añade en su lugar, encima de `pumpWidget`:

```dart
      // El filtro de FlutterError.onError que vivía aquí tragaba un
      // desbordamiento de 118 px del Row de cabecera, causado por el ancho
      // fijo de 260 px sin hijos flexibles. La Fase 6 lo eliminó
      // estructuralmente (ChatCardShell), así que el test ya no necesita
      // tapar nada: cualquier desbordamiento debe hacerlo fallar.
```

Elimina también el `TODO` de [reserva_chat_card.dart:220](../../../lib/features/chat/presentation/widgets/cards/reserva_chat_card.dart#L220).

**Éste es el criterio de aceptación de la tarea:** el test de navegación pasa **sin** filtro. Si hay que reinstalarlo, la tarea no está terminada.

### Step 6: Verificar

Run: `flutter test test/features/chat/`

Expected: **todo en verde**, por primera vez desde antes de esta fase. El contador debe subir de `+33 -1` a `+33 +nuevos -0`.

Run: `flutter analyze` — sin issues nuevos.

### Step 7: Commit

```
fix(chat): reserva_chat_card sin ancho fijo — la suite del módulo vuelve a verde

El Row de cabecera desbordaba 118 px: ancho fijo de 260 px (menos 2 de
borde y 24 de padding = 234 disponibles) con mainAxisAlignment.spaceBetween
y ningún hijo flexible, así que ninguno cedía. El test de navegación de
esta tarjeta instalaba un filtro en FlutterError.onError para tragárselo;
ese filtro estaba anclado a la línea 202 y ediciones posteriores movieron
el Row a la 219, con lo que el test llevaba tiempo en rojo.

ChatCardShell elimina la causa (sin ancho fijo, cabecera con Expanded +
ellipsis) y este commit BORRA el filtro: el test pasa sin él.

Además: los estados pasan por AppSeverity.forReservaEstado + AppStatusBadge
(antes Colors.orange/green/red/blue con texto blanco de 10 px, entre 2,16:1
y 3,68:1), los cuatro botones pasan a AppButton, y se eliminan los 12
`color: isMe ? Colors.white : ...` que pintaban blanco sobre tarjeta
blanca (1,00:1) cuando el mensaje era propio.
```

---

## 11. Task 10: `cotizacion_chat_card` — 31 colores y el beneficio que nunca se ha visto

La tarjeta más grande del módulo (488 líneas) y la de mayor densidad de color (31). Se edita **quirúrgicamente** por bloques, no se reescribe entera.

**Files:**
- Modify: `lib/features/chat/presentation/widgets/cards/cotizacion_chat_card.dart`
- Create: `test/features/chat/presentation/widgets/cards/cotizacion_chat_card_test.dart`

**Interfaces:**
- Consumes: `ChatCardShell` (Task 2); `ChatBubble` (Task 1); `AppSeverity.forReservaEstado` (Task 5); `AppStatusBadge`, `AppButton`; `pumpChatWidget` (Task 1); `FakeFirebaseFirestore`.
- Produces: nada nuevo. La firma pública no cambia.

### Step 1: El defecto que importa

La tarjeta tiene un bloque que **solo se dibuja cuando `isMe` es verdadero** ([L362-394](../../../lib/features/chat/presentation/widgets/cards/cotizacion_chat_card.dart#L362-L394)):

```dart
                if (isMe && beneficioTotal > 0) ...[
                  ... Icon(Icons.visibility_off_outlined, color: Colors.white54),
                      Text('Tu beneficio:', style: TextStyle(color: Colors.white54)),
                      Text('\$…', style: TextStyle(color: Colors.white54)),
```

`Colors.white54` sobre la tarjeta `Colors.white` da **1,00:1**. Y como la condición es `isMe`, y `_cargarBeneficios()` **también** solo se ejecuta cuando `isMe` ([L45](../../../lib/features/chat/presentation/widgets/cards/cotizacion_chat_card.dart#L45)), este dato —el margen de beneficio del taller, que es información de negocio sensible y deliberadamente privada— **nunca se ha llegado a ver en tema claro**. No es un problema de contraste bajo: es una funcionalidad que no se ha mostrado nunca.

En tema oscuro sí se ve (la tarjeta es `colors.surfaceContainer`, `#141E36`), lo que explica que pasara la revisión.

### Step 2: Escribir el test — debe fallar

```dart
// test/features/chat/presentation/widgets/cards/cotizacion_chat_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/widgets/app_status_badge.dart';
import 'package:autodoc/features/chat/presentation/widgets/chat_bubble.dart';
import 'package:autodoc/features/chat/presentation/widgets/chat_card_shell.dart';
import 'package:autodoc/features/chat/presentation/widgets/cards/cotizacion_chat_card.dart';
import '../../../../../support/chat_harness.dart';
import '../../../../../support/contrast.dart';
import '../../../../../support/responsive_harness.dart';

Widget _card({required bool isMe}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: ChatBubble(
          isMe: isMe,
          child: CotizacionChatCard(
            metadata: const {'id_cotizacion': 'q1'},
            isMe: isMe,
            mensajeId: 'm1',
            conversacionId: 'c1',
          ),
        ),
      ),
    );

void main() {
  testWidgets('el total es legible cuando la cotización es propia y el tema claro',
      (tester) async {
    await pumpChatWidget(tester, _card(isMe: true), width: 375);
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(ChatCardShell));
    final colors = context.appColors;
    final total = tester.widget<Text>(find.textContaining(r'$'));
    final color = total.style?.color ??
        DefaultTextStyle.of(tester.element(find.textContaining(r'$')))
            .style
            .color!;
    expect(contrastRatio(color, colors.surface), greaterThanOrEqualTo(4.5),
        reason: 'Colors.white sobre tarjeta Colors.white = 1,00:1.');
  });

  testWidgets('la fila "Tu beneficio" es visible en tema claro', (tester) async {
    // Esta fila solo se dibuja con isMe=true, y su color era Colors.white54
    // sobre una tarjeta Colors.white: nunca se ha visto en claro.
    await pumpChatWidget(tester, _card(isMe: true), width: 375);
    await tester.pumpAndSettle();
    final finder = find.text('Tu beneficio:');
    if (finder.evaluate().isEmpty) return; // sin beneficios cargados
    final context = tester.element(find.byType(ChatCardShell));
    final colors = context.appColors;
    final texto = tester.widget<Text>(finder);
    expect(
      contrastRatio(texto.style!.color!, colors.surface),
      greaterThanOrEqualTo(4.5),
    );
  });

  testWidgets('usa ChatCardShell, AppStatusBadge y AppButton', (tester) async {
    await pumpChatWidget(tester, _card(isMe: false), width: 375);
    await tester.pumpAndSettle();
    expect(find.byType(ChatCardShell), findsOneWidget);
    expect(find.byType(AppStatusBadge), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('no desborda en ningún ancho auditado, en ambos temas',
      (tester) async {
    for (final width in kAuditWidths) {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        await pumpChatWidget(tester, _card(isMe: false),
            width: width, brightness: brightness);
        await tester.pumpAndSettle();
        expectNoOverflow(tester);
      }
    }
  });

  testWidgets('el placeholder de carga tampoco tiene ancho fijo',
      (tester) async {
    // Era `SizedBox(width: 280)`, el noveno ancho fijo del módulo.
    await pumpChatWidget(tester, _card(isMe: false), width: 320);
    await tester.pump(); // sin settle: se queda en el estado de carga
    expectNoOverflow(tester);
  });
}
```

**Nota:** `CotizacionChatCard` lee `FirebaseFirestore.instance` directamente en `build()` ([L138](../../../lib/features/chat/presentation/widgets/cards/cotizacion_chat_card.dart#L138)). Sin inyección, en un widget test ese `StreamBuilder` nunca emite y la tarjeta se queda en el placeholder de carga. Eso hace **verificables** los tests 4 y 5 pero **no** los 1–3.

**Decisión:** se añade un parámetro opcional `FirebaseFirestore? firestore` con `?? FirebaseFirestore.instance`, exactamente el mismo precedente que ya existe en `ReservaDetailScreen` ([L32-36](../../../lib/features/chat/presentation/pages/reserva_detail_screen.dart#L32-L36)) y que la Fase 5 adoptó para tres pantallas. No es tocar `data/`: es hacer inyectable una dependencia que la capa de presentación ya estaba construyendo por su cuenta. Mover la consulta a un repositorio **sí** tocaría `data/` y queda en §17.

### Step 3: Verificar el fallo exacto

Run: `flutter test test/features/chat/presentation/widgets/cards/cotizacion_chat_card_test.dart`

Expected: **FAIL** — primero de compilación por el parámetro `firestore` que aún no existe; tras añadirlo, el test 1 con ratio **1.0** y el test 3 por `ChatCardShell` no encontrado.

### Step 4: Añadir la inyección y migrar la carcasa

4a. Añade `final FirebaseFirestore? firestore;` al widget, con el mismo doc-comment que usa `ReservaDetailScreen`, y sustituye [L138](../../../lib/features/chat/presentation/widgets/cards/cotizacion_chat_card.dart#L138) por `(widget.firestore ?? FirebaseFirestore.instance)`.

4b. El placeholder de carga ([L144-150](../../../lib/features/chat/presentation/widgets/cards/cotizacion_chat_card.dart#L144-L150)) pierde su `width: 280`:

```dart
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const ChatCardShell(
            icon: Icons.request_quote,
            title: 'Cotización de Servicio',
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
```

Usar la misma carcasa en carga y en contenido evita el salto de tamaño al llegar el snapshot, que es un defecto de percepción real aunque nadie lo haya reportado.

4c. Sustituye el `Container(width: 300, …)` y su cabecera ([L214-284](../../../lib/features/chat/presentation/widgets/cards/cotizacion_chat_card.dart#L214-L284)) por `ChatCardShell` con `trailing: AppStatusBadge(...)`, igual que en la Task 9, usando el mapeo de estados de cotización:

```dart
    final severidad = AppSeverity.forReservaEstado(
      estado,
      colors,
      pendienteLabel: 'Pendiente',
      confirmadaLabel: 'En Proceso',   // 'aceptada' en cotizaciones
      rechazadaLabel: 'Rechazada',
      cotizadaLabel: 'Servicio Finalizado', // 'finalizada'
    );
```

Elimina el bloque `badgeColor` / `badgeText` de [L195-206](../../../lib/features/chat/presentation/widgets/cards/cotizacion_chat_card.dart#L195-L206).

### Step 5: Tokenizar el cuerpo (23 sustituciones)

Por bloques, en este orden, verificando compilación tras cada uno:

5a. **Fecha propuesta** ([L290-312](../../../lib/features/chat/presentation/widgets/cards/cotizacion_chat_card.dart#L290-L312)): icono `isMe ? Colors.white70 : colors.textSecondary` → `colors.textSecondary`; texto sin `color` (lo hereda).

5b. **Renglones de ítems** ([L313-339](../../../lib/features/chat/presentation/widgets/cards/cotizacion_chat_card.dart#L313-L339)): material sin `color`; subtotal → `colors.textSecondary`.

5c. **Divider** ([L341](../../../lib/features/chat/presentation/widgets/cards/cotizacion_chat_card.dart#L341)): `const Divider(height: 1, color: Colors.black12)` → `Divider(height: 1, color: colors.outline.withValues(alpha: 0.4))`. Era invisible en tema oscuro.

5d. **Total** ([L343-361](../../../lib/features/chat/presentation/widgets/cards/cotizacion_chat_card.dart#L343-L361)): etiqueta → `colors.textSecondary`; importe → `colors.secondary` sin ternario.

5e. **Bloque "Tu beneficio"** ([L362-394](../../../lib/features/chat/presentation/widgets/cards/cotizacion_chat_card.dart#L362-L394)): los tres `Colors.white54` → `colors.textSecondary`. Éste es el arreglo de §Step 1. Añade además `Semantics(label: 'Tu beneficio, visible solo para ti: …')`, porque el icono de ojo tachado no significa nada para un lector de pantalla.

5f. **Botones aceptar/rechazar** ([L395-424](../../../lib/features/chat/presentation/widgets/cards/cotizacion_chat_card.dart#L395-L424)): a `AppButton`; desaparecen los dos `Colors.red`.

5g. **Aviso "Recibe el vehículo…"** ([L425-454](../../../lib/features/chat/presentation/widgets/cards/cotizacion_chat_card.dart#L425-L454)): icono y texto `isMe ? Colors.white/white70 : colors.primary` → `colors.primary`. El fondo `colors.primary.withValues(alpha: 0.1)` se mantiene: ahora compone sobre la superficie de la tarjeta, que es lo correcto.

5h. **Botón "Calificar Servicio"** ([L455-479](../../../lib/features/chat/presentation/widgets/cards/cotizacion_chat_card.dart#L455-L479)): `backgroundColor: Colors.amber.shade700` con `foregroundColor: Colors.white` da **2,04:1**, el peor par del módulo. Pasa a `AppButton(type: AppButtonType.primary, isLoading: isCheckingReview, icon: const Icon(Icons.star))`. El `isLoading` de `AppButton` sustituye al `CircularProgressIndicator` manual del `icon:`.

### Step 6: Verificar que pasa

Run: `flutter test test/features/chat/presentation/widgets/cards/cotizacion_chat_card_test.dart`

Expected: **PASS**, 5 tests.

Run: `flutter test test/features/chat/` — todo verde.

Comprobación de recuento: `grep -cE "Colors\.(white|black)[0-9]*\b|Colors\.(grey|red|green|blue|orange|amber)\b" lib/features/chat/presentation/widgets/cards/cotizacion_chat_card.dart` debe devolver **0**.

### Step 7: Commit

```
fix(chat): tokenizar cotizacion_chat_card (31 colores literales → 0)

El defecto principal no es de contraste, es de funcionalidad: el bloque
"Tu beneficio" solo se dibuja cuando isMe es verdadero, y se pintaba
Colors.white54 sobre una tarjeta Colors.white. Como _cargarBeneficios()
también depende de isMe, ese dato —el margen del taller— NUNCA se ha
mostrado en tema claro. En oscuro sí se veía, que es por qué pasó revisión.

Lo mismo, con menos gravedad, para el total, los renglones y la fecha: con
isMe=true, todo el cuerpo de la tarjeta era blanco sobre blanco (1,00:1).

Además:
- El placeholder de carga pierde su width: 280 y usa la misma carcasa que
  el contenido, así que la tarjeta ya no salta de tamaño al llegar el dato.
- El Divider de Colors.black12 era invisible en tema oscuro.
- "Calificar Servicio" era blanco sobre amber.shade700: 2,04:1, el peor par
  del módulo.
- Se añade `FirebaseFirestore? firestore` inyectable (mismo precedente que
  ReservaDetailScreen) para poder probar la tarjeta con datos.
```

---

## 12. Task 11: `chat_screen` — burbuja, ancho de lectura y una consulta por pulsación de tecla

La pantalla más grande del módulo (829 líneas). Edición quirúrgica por bloques.

**Files:**
- Modify: `lib/features/chat/presentation/pages/chat_screen.dart`
- Create: `test/features/chat/presentation/pages/chat_screen_layout_test.dart`

**Interfaces:**
- Consumes: `ChatBubble` (Task 1); `AppBreakpoints`, `AppPageBody` (Fase 1); `AppSnackbar` (Fase 3); todas las tarjetas migradas (Tasks 3, 6–10); `pumpChatWidget`, `FakeChatProvider` (Task 1).
- Produces: nada nuevo hacia fuera. Internamente, `_ChatScreenState._nombreReceptorFuture` (cacheado) sustituye al `future:` inline.

### Step 1: Leer las skills obligatorias

`ui-ux-pro-max` y `emil-design-eng`.

De `emil-design-eng`, la decisión relevante es **qué no animar**: la lista es `reverse: true` y las burbujas no deben animar su entrada (§Task 1 Step 1). Lo que sí merece transición es el indicador de "Escribiendo…", que hoy aparece y desaparece de golpe cambiando la altura del `AppBar`; un `AnimatedSize` con `AppMotion.easeOut` evita el salto. Es la única animación que añade esta fase.

### Step 2: Escribir el test — debe fallar

```dart
// test/features/chat/presentation/pages/chat_screen_layout_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/utils/app_breakpoints.dart';
import 'package:autodoc/features/chat/data/models/conversacion_model.dart';
import 'package:autodoc/features/chat/data/models/mensaje_model.dart';
import 'package:autodoc/features/chat/presentation/pages/chat_screen.dart';
import 'package:autodoc/features/chat/presentation/widgets/chat_bubble.dart';
import '../../../../support/chat_harness.dart';
import '../../../../support/responsive_harness.dart';

MensajeModel _msg(String texto, {String de = 'u1'}) => MensajeModel(
      id: 'm-$texto'.substring(0, 8),
      idRemitente: de,
      idReceptor: de == 'u1' ? 'm1' : 'u1',
      contenido: texto,
      tipo: 'texto',
      timestamp: DateTime(2026, 8, 11),
      estado: 'visto',
    );

ConversacionModel _conv() => ConversacionModel(
      id: 'c1',
      idPropietario: 'u1',
      idMecanico: 'm1',
      nombrePropietario: 'Ana Pérez',
      nombreMecanico: 'Taller Escobar',
      ultimoMensaje: 'ok',
      ultimoMensajeTs: DateTime(2026, 8, 11),
      noLeidosPropietario: 0,
      noLeidosMecanico: 0,
    );

FakeChatProvider _provider() => FakeChatProvider(
      conversaciones: [_conv()],
      mensajes: [
        _msg('Hola, necesito una revisión completa de frenos, y también '
            'cambio de aceite y filtro de aire si es posible el jueves.'),
        _msg('Claro, le confirmo disponibilidad.', de: 'm1'),
      ],
    );

void main() {
  testWidgets('las burbujas usan ChatBubble', (tester) async {
    await pumpChatWidget(
      tester,
      const ChatScreen(conversacionId: 'c1'),
      width: 375,
      chatProvider: _provider(),
      user: fakeChatUser(),
    );
    expect(find.byType(ChatBubble), findsNWidgets(2));
  });

  testWidgets('a 1440 px ninguna burbuja supera el ancho de lectura',
      (tester) async {
    await pumpChatWidget(
      tester,
      const ChatScreen(conversacionId: 'c1'),
      width: 1440,
      chatProvider: _provider(),
      user: fakeChatUser(),
    );
    for (final element in find.byType(ChatBubble).evaluate()) {
      expect(
        tester.getSize(find.byElementPredicate((e) => e == element)).width,
        lessThanOrEqualTo(AppBreakpoints.maxReadingWidth),
      );
    }
  });

  testWidgets('no desborda en ningún ancho auditado, en ambos temas',
      (tester) async {
    for (final width in kAuditWidths) {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        await pumpChatWidget(
          tester,
          const ChatScreen(conversacionId: 'c1'),
          width: width,
          brightness: brightness,
          chatProvider: _provider(),
          user: fakeChatUser(),
        );
        expectNoOverflow(tester);
      }
    }
  });

  testWidgets('cada mensaje se anuncia con su autor', (tester) async {
    await pumpChatWidget(
      tester,
      const ChatScreen(conversacionId: 'c1'),
      width: 375,
      chatProvider: _provider(),
      user: fakeChatUser(),
    );
    expect(find.bySemanticsLabel(RegExp(r'^Tú:')), findsWidgets);
    expect(find.bySemanticsLabel(RegExp(r'^Taller Escobar:')), findsWidgets);
  });

  testWidgets('un rebuild del provider no relanza la consulta del receptor',
      (tester) async {
    final provider = _provider();
    await pumpChatWidget(
      tester,
      const ChatScreen(conversacionId: 'c1'),
      width: 375,
      chatProvider: provider,
      user: fakeChatUser(),
    );
    final buildsIniciales = tester
        .widgetList(find.byType(FutureBuilder<Object?>))
        .length;
    provider.notifyListeners();
    await tester.pump();
    // El `future` debe ser el mismo objeto entre builds: si se construye
    // dentro de build(), cada notificación del provider (incluido el estado
    // "escribiendo", que cambia cada 2 s) dispara un get() a Firestore.
    expect(
      tester.widgetList(find.byType(FutureBuilder<Object?>)).length,
      buildsIniciales,
    );
  });
}
```

**Sobre el último test:** verificar "no se relanza el future" con precisión requiere capturar la identidad del objeto `Future`. La forma robusta es exponer el campo como `@visibleForTesting Future<DocumentSnapshot>? nombreReceptorFuture` en el `State` y comparar `identical()` antes y después del `notifyListeners()`. Escríbelo así si el test de arriba resulta ambiguo; el criterio es la identidad del future, no el número de widgets.

### Step 3: Verificar el fallo exacto

Run: `flutter test test/features/chat/presentation/pages/chat_screen_layout_test.dart`

Expected: **FAIL** en el primero — `Expected: exactly 2 matching candidates / Actual: zero widgets with type ChatBubble`.

### Step 4: Sustituir la burbuja inline por `ChatBubble`

Sustituye [L386-480](../../../lib/features/chat/presentation/pages/chat_screen.dart#L386-L480) (el `Align` + `GestureDetector` + `Container` + `Column` con el acuse) por:

```dart
                      final nombreAutor = isMe
                          ? 'Tú'
                          : targetName;

                      return Align(
                        key: ValueKey(msg.id),
                        alignment:
                            isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: GestureDetector(
                          onLongPress: () => _confirmarBorrado(msg, isMe),
                          child: ChatBubble(
                            isMe: isMe,
                            isDeleted: msg.isDeleted,
                            semanticLabel: '$nombreAutor: ${msg.contenido}',
                            footer: isMe ? _AcuseDeRecibo(estado: msg.estado) : null,
                            child: _buildMessageContent(
                              msg,
                              isMe,
                              colors,
                              conversacion?.idMecanico ?? '',
                            ),
                          ),
                        ),
                      );
```

y extrae el diálogo de borrado —hoy 30 líneas anidadas dentro del `itemBuilder`— a un método `_confirmarBorrado(MensajeModel msg, bool isMe)` del `State`. Ese diálogo tiene además un `Colors.red` en el botón de eliminar ([L416-418](../../../lib/features/chat/presentation/pages/chat_screen.dart#L416-L418)) que pasa a `colors.error`.

Añade el acuse como widget propio al final del fichero:

```dart
/// Acuse de recibo del mensaje propio.
///
/// Los colores salen de la paleta y no de `Colors.white70` / `blue.shade200`:
/// sobre `colors.primary`, que en tema oscuro es #81E6D9, esos dos daban
/// 1,31:1 y 1,19:1 respectivamente.
class _AcuseDeRecibo extends StatelessWidget {
  final String estado;
  const _AcuseDeRecibo({required this.estado});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final visto = estado == 'visto';
    return Semantics(
      label: visto ? 'Visto' : 'Enviado',
      child: ExcludeSemantics(
        child: Icon(
          visto ? Icons.done_all : Icons.check,
          size: 14,
          color: colors.onPrimary.withValues(alpha: visto ? 1.0 : 0.7),
        ),
      ),
    );
  }
}
```

### Step 5: Arreglar el texto plano y la firma de `_buildMessageContent`

5a. El `case 'texto'` ([L625-636](../../../lib/features/chat/presentation/pages/chat_screen.dart#L625-L636)):

```dart
      case 'texto':
      default:
        return Text(
          msg.contenido,
          style: TextStyle(
            color: isMe ? colors.onPrimary : colors.textPrimary,
            fontSize: 15,
          ),
        );
```

Esto es §0.1(a): `Colors.white` sobre `colors.primary` daba **1,47:1** en oscuro.

5b. Elimina el parámetro `isDark` de la firma de `_buildMessageContent`: tras las Tasks 3 y 6–10 ninguna rama lo usa. Comprueba con `flutter analyze` que no queda ninguna variable `isDark` sin usar en `build()`.

5c. Actualiza la llamada a `ImagenChatCard` para pasarle `mensajeId: msg.id` (Task 7).

### Step 6: Cachear la consulta del nombre del receptor

El `FutureBuilder` del `AppBar` ([L315-352](../../../lib/features/chat/presentation/pages/chat_screen.dart#L315-L352)) construye su `future:` **dentro de `build()`**. Como la pantalla hace `context.watch<ChatProvider>()`, cada notificación del provider reconstruye —y cada reconstrucción lanza un `get()` nuevo a `usuarios/{receptorId}`. El estado "escribiendo" cambia cada 2 segundos por diseño ([L88](../../../lib/features/chat/presentation/pages/chat_screen.dart#L88)), así que hay al menos una consulta cada 2 s mientras alguien teclea, más una por cada mensaje que llega.

Añade al `State`:

```dart
  /// Consulta del nombre real del receptor, cacheada.
  ///
  /// Estaba construida dentro de `build()`, y como la pantalla hace
  /// `context.watch<ChatProvider>()`, cada notificación —incluido el estado
  /// "escribiendo", que cambia cada 2 s— lanzaba un `get()` nuevo a
  /// `usuarios/{receptorId}`.
  Future<DocumentSnapshot<Map<String, dynamic>>>? _nombreReceptorFuture;
  String? _receptorIdCacheado;

  /// Devuelve el future, creándolo solo si el receptor cambió.
  Future<DocumentSnapshot<Map<String, dynamic>>>? _futureNombreReceptor(
    String receptorId,
  ) {
    if (receptorId.isEmpty) return null;
    if (_receptorIdCacheado == receptorId) return _nombreReceptorFuture;
    _receptorIdCacheado = receptorId;
    _nombreReceptorFuture = FirebaseFirestore.instance
        .collection(FirestoreCollections.usuarios)
        .doc(receptorId)
        .get();
    return _nombreReceptorFuture;
  }
```

y en el `AppBar`: `future: _futureNombreReceptor(receptorId),`.

**Aviso de ejecución:** llamar a `_futureNombreReceptor` desde `build()` muta estado del `State` durante el build. Es aceptable aquí porque no llama a `setState` y el resultado es idempotente para el mismo `receptorId`, pero **si `flutter analyze` o un lint lo señala**, muévelo a `didChangeDependencies()`. No lo dejes con un `// ignore:`.

### Step 7: Acotar el ancho de la lista y del compositor

7a. Envuelve el `ListView.builder` en `AppPageBody(maxWidth: AppBreakpoints.maxContentWidth, child: …)`. Nota: aquí es `maxContentWidth` (1200), no `maxReadingWidth`: quien acota la línea de texto es `ChatBubble` (720 por burbuja); la **lista** puede ser más ancha para que las burbujas propias y ajenas queden claramente a lados opuestos. Si la lista se acotara a 720, ambas se juntarían en el centro y se perdería la señal de quién habla.

7b. Envuelve el `Container` de la barra de entrada ([L488-575](../../../lib/features/chat/presentation/pages/chat_screen.dart#L488-L575)) en el mismo `AppPageBody`, para que el campo de texto quede alineado con la lista y no se estire 1440 px.

7c. Tokeniza la barra de entrada: `isDark ? colors.surfaceContainer : Colors.white` → `colors.surface`; el borde `isDark ? Colors.white12 : Colors.black12` → `colors.outline.withValues(alpha: 0.4)`; el fondo del campo `isDark ? Colors.white12 : Colors.grey.shade100` → `colors.surfaceContainer`; el icono de enviar `Colors.white` → `colors.onPrimary`.

7d. El `hintText: 'Escribe un mensaje...'` se queda literal (§1: no se añaden claves de l10n) pero **se anota en §17**. Añade `tooltip` a los tres `IconButton` de la barra (adjuntar, cámara, enviar): hoy ninguno tiene y son controles solo-icono.

### Step 8: Animar el indicador de "Escribiendo…"

Envuelve el `Column` del título del `AppBar` en `AnimatedSize(duration: AppMotion.transformDuration(context, AppMotion.tooltip), curve: AppMotion.easeOut, alignment: Alignment.centerLeft, child: …)`.

`AppMotion.transformDuration` respeta reduced motion (Fase 1 Task 2): con `MediaQuery.disableAnimationsOf` verdadero devuelve una duración reducida, no cero, que es la regla de `emil-design-eng`. El texto de "Escribiendo…" pasa además a `colors.primary` (ya lo está) con `Semantics(liveRegion: true)` para que el lector lo anuncie.

### Step 9: Verificar

Run: `flutter test test/features/chat/`

Expected: **todo verde**, incluido `chat_screen_read_receipts_test.dart`, que **no se toca** (cubre que se llame a `marcarComoLeidos` al abrir, comportamiento que esta tarea no cambia).

Si `chat_screen_read_receipts_test.dart` se rompe, has cambiado el ciclo de vida sin querer: revierte el Step 6 y revísalo.

### Step 10: Commit

```
refactor(chat): chat_screen usa ChatBubble, acota el ancho y deja de
consultar Firestore en cada rebuild

Tres cambios con efecto medible:

- Las burbujas pasan a ChatBubble. No tenían maxWidth: a 1440 px una línea
  de texto ocupaba 1376 px (~200 caracteres). Ahora 720 por burbuja, con la
  lista a 1200 para que propias y ajenas sigan quedando a lados opuestos.
- El texto de los mensajes propios pasa de Colors.white a colors.onPrimary.
  En tema oscuro, blanco sobre colors.primary (#81E6D9) daba 1,47:1; el
  acuse de recibo daba 1,31:1 y el "visto" 1,19:1.
- El FutureBuilder del AppBar construía su `future` dentro de build(). Como
  la pantalla hace watch<ChatProvider>(), cada notificación —incluido el
  estado "escribiendo", que cambia cada 2 s— lanzaba un get() nuevo a
  usuarios/{receptorId}. Ahora se cachea por receptorId.

Además: cada mensaje se anuncia con su autor ("Tú:" / "<nombre>:"), los
tres botones de la barra de entrada tienen tooltip, y el indicador de
"Escribiendo..." usa AnimatedSize en vez de saltar de altura.
```

---

## 13. Task 12: los dos sheets y el botón de grabar

Las tres piezas que se abren **sobre** el chat en vez de dentro de él. Comparten diagnóstico: ninguna consulta el tamaño de la ventana, y las tres fijan una dimensión en píxeles.

**Files:**
- Modify: `lib/features/chat/presentation/widgets/vehiculo_picker.dart`
- Modify: `lib/features/chat/presentation/widgets/cotizacion_picker.dart`
- Modify: `lib/features/chat/presentation/widgets/voice_record_button.dart`
- Create: `test/features/chat/presentation/widgets/vehiculo_picker_test.dart`
- Create: `test/features/chat/presentation/widgets/cotizacion_picker_test.dart`
- Create: `test/features/chat/presentation/widgets/voice_record_button_test.dart`

**Interfaces:**
- Consumes: `AppBreakpoints.maxFormWidth` (Fase 1 Task 1); `AppDialogContent` (Fase 5 Task 4); `AppEmptyState`, `AppButton` (Fase 3); `AppSnackbar` (Fase 3); `pumpChatWidget` (Task 1); `formatearDuracionGrabacion` (ya existe y es público).
- Produces: nada nuevo.

### Step 1: Leer `apple-design`

Ésta es la única tarea de la fase que la requiere: dos bottom sheets con arrastre (`DraggableScrollableSheet`) y un gesto de mantener-presionado-y-deslizar-para-cancelar. Lo que interesa de esa skill es que el gesto sea **interrumpible** y que el estado de "armado para cancelar" sea reversible sin soltar — que ya lo es ([voice_record_button.dart:204-212](../../../lib/features/chat/presentation/widgets/voice_record_button.dart#L204-L212)). No hay que rehacer el gesto: hay que no romperlo.

### Step 2: Escribir los tests — deben fallar

```dart
// test/features/chat/presentation/widgets/voice_record_button_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/features/chat/presentation/widgets/voice_record_button.dart';
import '../../../../support/chat_harness.dart';

void main() {
  test('formatearDuracionGrabacion sigue formateando m:ss', () {
    // El helper ya es público y correcto; se fija como contrato porque el
    // Semantics del botón lo va a consumir.
    expect(formatearDuracionGrabacion(const Duration(seconds: 65)), '1:05');
    expect(formatearDuracionGrabacion(Duration.zero), '0:00');
  });

  testWidgets('el botón de grabar cumple el mínimo de 48 dp', (tester) async {
    await pumpChatWidget(
      tester,
      VoiceRecordButton(onGrabacionCompleta: (_, __) {}),
      width: 375,
    );
    final size = tester.getSize(find.byType(VoiceRecordButton));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('anuncia qué hace al lector de pantalla', (tester) async {
    await pumpChatWidget(
      tester,
      VoiceRecordButton(onGrabacionCompleta: (_, __) {}),
      width: 375,
    );
    expect(
      find.bySemanticsLabel('Grabar nota de voz. Mantén presionado.'),
      findsOneWidget,
    );
  });
}
```

```dart
// test/features/chat/presentation/widgets/vehiculo_picker_test.dart
// (extracto — el fichero completo sigue el mismo patrón)

  testWidgets('el sheet no es más alto que la ventana en horizontal',
      (tester) async {
    // Container(height: 400) en un teléfono horizontal (alto 375) produce un
    // sheet más alto que la pantalla.
    await pumpChatWidget(
      tester,
      const VehiculoPicker(userId: 'u1', onSelected: _noop),
      width: 812,
      height: 375,
    );
    final alto = tester.getSize(find.byType(VehiculoPicker)).height;
    expect(alto, lessThanOrEqualTo(375));
    expectNoOverflow(tester);
  });

  testWidgets('usa AppEmptyState cuando no hay vehículos', (tester) async {
    // ... con un VehicleProvider vacío
    expect(find.byType(AppEmptyState), findsOneWidget);
  });
```

```dart
// test/features/chat/presentation/widgets/cotizacion_picker_test.dart
// (extracto)

  testWidgets('el formulario se acota a maxFormWidth en pantallas grandes',
      (tester) async {
    await pumpChatWidget(
      tester,
      CotizacionPicker(onConfirm: (_, __) async {}),
      width: 1440,
    );
    final ancho = tester.getSize(find.byType(Form)).width;
    expect(ancho, lessThanOrEqualTo(AppBreakpoints.maxFormWidth),
        reason: 'A 1440 px los campos del formulario medían 1400 px.');
  });

  testWidgets('el error de fecha se anuncia al lector de pantalla',
      (tester) async {
    await pumpChatWidget(
      tester,
      CotizacionPicker(onConfirm: (_, __) async {}),
      width: 375,
    );
    await tester.tap(find.text('Generar y Enviar'));
    await tester.pump();
    expect(
      find.bySemanticsLabel(
        RegExp('Debes proponer el día y hora del servicio'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('no desborda en ningún ancho auditado', (tester) async {
    for (final width in kAuditWidths) {
      await pumpChatWidget(
        tester,
        CotizacionPicker(onConfirm: (_, __) async {}),
        width: width,
      );
      expectNoOverflow(tester);
    }
  });
```

### Step 3: Verificar los fallos exactos

Run: `flutter test test/features/chat/presentation/widgets/`

Expected, tres fallos:

1. `voice_record_button_test.dart` — la caja mide **40 × 40** (el `CircleAvatar` sin `radius` usa el default de 20), esperado ≥ 48.
2. `vehiculo_picker_test.dart` — alto **400** en una ventana de 375, más un desbordamiento vertical.
3. `cotizacion_picker_test.dart` — el `Form` mide **1400**, esperado ≤ 560.

### Step 4: `voice_record_button`

4a. El `CircleAvatar` pasa a tener tamaño explícito y semántica:

```dart
      child: Semantics(
        label: _grabando
            ? 'Grabando nota de voz, ${formatearDuracionGrabacion(_transcurrido)}. '
                'Suelta para enviar, desliza a la izquierda para cancelar.'
            : 'Grabar nota de voz. Mantén presionado.',
        button: true,
        child: ExcludeSemantics(
          child: SizedBox(
            width: 48,
            height: 48,
            child: CircleAvatar(
              backgroundColor: _grabando ? colors.error : colors.primary,
              child: Icon(
                _grabando ? Icons.stop : Icons.mic,
                color: colors.onPrimary,
              ),
            ),
          ),
        ),
      ),
```

`Colors.red` → `colors.error`, `Colors.white` → `colors.onPrimary`, y `Theme.of(context).colorScheme.primary` → `context.appColors.primary` por coherencia con el resto del módulo.

4b. El overlay ([L133-178](../../../lib/features/chat/presentation/widgets/voice_record_button.dart#L133-L178)) **conserva** `Colors.black87` y `Colors.white`: es un HUD flotante sobre contenido arbitrario, mismo caso que el visor de imagen de la Task 7. Se declara como excepción en la Task 13, no se esconde. Lo que sí cambia: el punto rojo de grabación y el texto de cancelación pasan a `colors.error`, y el overlay se envuelve en `Semantics(liveRegion: true)` para que el temporizador se anuncie.

4c. Los tres `SnackBar` (`'Se requiere permiso de micrófono…'`, `'Mantén presionado para grabar…'`) pasan a `AppSnackbar.show`.

### Step 5: `vehiculo_picker`

5a. Sustituye `Container(height: 400, …)` por un `DraggableScrollableSheet` con la misma configuración que `CotizacionPicker`, para que los dos sheets del módulo se comporten igual:

```dart
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(...),
        ),
      ),
    );
```

Fracciones en vez de píxeles: en teléfono horizontal el sheet ocupa el 60 % de 375 px en vez de 400 px absolutos.

5b. El `ListView.builder` interno recibe el `scrollController` del sheet, para que arrastrar dentro de la lista arrastre el sheet cuando está arriba del todo (el comportamiento que espera `apple-design`).

5c. `'No tienes vehículos registrados.'` pasa a `AppEmptyState` con acción a `/add_vehicle` **si esa ruta existe**; si no, sin acción y se anota en §17.

5d. Añade `Semantics` a cada `ListTile`: hoy un lector lee "Toyota Hilux" y "ABC-1234" como dos textos sin relación. Un solo `Semantics(label: '$marca $modelo, placa $placa')` con `ExcludeSemantics` dentro.

5e. Añade el asa de arrastre (`Container` de 4 × 40 con `colors.outline`) que `CotizacionPicker` tampoco tiene; ponlo en los dos.

### Step 6: `cotizacion_picker`

6a. Envuelve el `Form` en `AppDialogContent(maxWidth: AppBreakpoints.maxFormWidth, child: …)` (Fase 5 Task 4). Es exactamente el mismo problema que resolvió esa tarea para los tres diálogos de `catalogo_servicios`, con la misma solución.

6b. Tokeniza los cinco literales: fondo `isDark ? colors.surfaceContainer : Colors.white` → `colors.surface`; fondo del renglón `isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50` → `colors.surfaceContainer`; `foregroundColor: Colors.white` del botón de envío → desaparece al pasar a `AppButton`; el `CircularProgressIndicator(color: Colors.white)` desaparece con `AppButton(isLoading: _isSubmitting)`.

6c. Semántica del error de fecha: el mensaje `'Debes proponer el día y hora del servicio.'` ([L215-218](../../../lib/features/chat/presentation/widgets/cotizacion_picker.dart#L215-L218)) es un `Text` suelto. Envuélvelo en `Semantics(liveRegion: true)` para que se anuncie al aparecer, igual que hacen los `errorText` nativos de `TextFormField`.

6d. **Lo que no se toca:** la validación, el cálculo del total, el manejo de `_isSubmitting` y el ciclo de vida de los `TextEditingController`. Ese código es correcto y está probado por el flujo. Cambiar los `TextFormField` a `AppTextField` **no** entra en esta tarea: la Fase 3 no garantiza que `AppTextField` soporte `validator` con la misma semántica, y sustituir el widget de un formulario que funciona sin un test que lo cubra es el tipo de cambio que rompe en producción. Se anota en §17.

### Step 7: Verificar

Run: `flutter test test/features/chat/`

Expected: **todo verde**.

**Verificación manual obligatoria** (no cubierta por widget tests): grabar una nota de voz en un dispositivo real y comprobar que el overlay aparece, el temporizador corre, deslizar a la izquierda arma la cancelación y soltar cancela. `record` no funciona en `flutter_test`, y el gesto de long-press-y-arrastre no se simula fielmente. Deja constancia en el PR.

### Step 8: Commit

```
refactor(chat): sheets adaptativos y botón de grabación accesible

Las tres piezas que se abren sobre el chat fijaban una dimensión en píxeles:

- vehiculo_picker: Container(height: 400). En teléfono horizontal (alto
  375) el sheet era más alto que la pantalla. Pasa a
  DraggableScrollableSheet con fracciones, igual que cotizacion_picker.
- cotizacion_picker: sin maxWidth. A 1440 px los campos medían 1400 px.
  Pasa por AppDialogContent con maxFormWidth (560).
- voice_record_button: CircleAvatar sin radius = 40 × 40 px, por debajo del
  mínimo de 48 dp, y sin ninguna etiqueta accesible pese a ser un control
  solo-icono con un gesto no evidente (mantener presionado).

El overlay de grabación conserva Colors.black87/white a propósito: es un
HUD sobre contenido arbitrario, no una superficie del tema. Se declara como
excepción del ratchet.
```

---

## 14. Task 13: cierre del ratchet de colores del módulo

**Files:**
- Modify: `test/support/tokenized_paths.dart`
- Modify: `test/theme_test.dart` (o donde viva el test del ratchet, según la Fase 1 Task 8)

**Interfaces:**
- Consumes: `kTokenizedPaths` (Fase 1 Task 8).
- Produces: `kTokenizedPaths` ampliado con las 14 rutas del módulo `chat`, más la lista de excepciones declaradas.

### Step 1: Comprobar que el regex de la Fase 1 está corregido

La Fase 5 corrigió en la Fase 1 Task 8 un agujero real: `Colors\.(white|black)\b` no detecta `Colors.white70` porque tras `white` viene un dígito y no hay frontera de palabra. Verifica que la corrección está aplicada:

```bash
grep -n 'white|black' test/support/tokenized_paths.dart
```

Expected: el patrón contiene `Colors\.(white|black)\d*\b`.

Si no está, **para**: sin ese `\d*`, los `Colors.white70` y `Colors.white54` que esta fase acaba de eliminar podrían reintroducirse sin que el ratchet lo note, y el módulo del chat tenía 18 de ellos.

### Step 2: Escribir la ampliación — debe fallar si algo quedó sin tokenizar

Añade a `kTokenizedPaths`:

```dart
  // ── Fase 6: módulo chat ──
  'lib/features/chat/presentation/pages/chat_screen.dart',
  'lib/features/chat/presentation/pages/conversaciones_list_screen.dart',
  'lib/features/chat/presentation/pages/reserva_detail_screen.dart',
  'lib/features/chat/presentation/widgets/chat_bubble.dart',
  'lib/features/chat/presentation/widgets/chat_card_shell.dart',
  'lib/features/chat/presentation/widgets/chat_background.dart',
  'lib/features/chat/presentation/widgets/cotizacion_picker.dart',
  'lib/features/chat/presentation/widgets/vehiculo_picker.dart',
  'lib/features/chat/presentation/widgets/cards/audio_chat_card.dart',
  'lib/features/chat/presentation/widgets/cards/cotizacion_chat_card.dart',
  'lib/features/chat/presentation/widgets/cards/historial_chat_card.dart',
  'lib/features/chat/presentation/widgets/cards/reserva_chat_card.dart',
  'lib/features/chat/presentation/widgets/cards/review_chat_card.dart',
  'lib/features/chat/presentation/widgets/cards/vehiculo_chat_card.dart',
```

**Faltan dos a propósito** — `imagen_chat_card.dart` y `voice_record_button.dart` — y ese hueco necesita justificación explícita, no silencio. Añade encima del bloque:

```dart
  // Dos ficheros del módulo chat NO entran en el ratchet, con motivo:
  //
  // - cards/imagen_chat_card.dart: el visor a pantalla completa se dibuja
  //   sobre la foto del usuario, un fondo desconocido. El par
  //   Colors.black54 + Colors.white garantiza el contraste sea cual sea la
  //   imagen; seguir el tema aquí lo empeoraría (una X del color de la
  //   superficie desaparece sobre una foto de ese color).
  // - voice_record_button.dart: mismo caso. El overlay de grabación es un
  //   HUD flotante sobre el chat, no una superficie del tema.
  //
  // Ambos están tokenizados en todo lo demás. Si en el futuro se añade a
  // AppColors un par explícito tipo `scrim` / `onScrim`, estos dos ficheros
  // deben migrarse y entrar aquí.
```

### Step 3: Verificar

Run: `flutter test test/theme_test.dart` (o el fichero del ratchet)

Expected: **PASS**. Si falla, el mensaje del test dice qué fichero y qué línea tiene un color literal: vuelve a la tarea correspondiente y termínala. **No** quites la ruta de la lista para que pase.

### Step 4: Recuento final

```bash
python - <<'PY'
import re, glob
pat = re.compile(r'Colors\.(white|black)\d*\b'
                 r'|Colors\.(grey|gray|blue|red|green|orange|purple|yellow'
                 r'|pink|teal|indigo|amber|cyan|lime|brown)\b'
                 r'|Color\(0x[0-9a-fA-F]{8}\)')
total = 0
for f in sorted(glob.glob('lib/features/chat/**/*.dart', recursive=True)):
    n = len(pat.findall(open(f, encoding='utf-8').read()))
    if n:
        print('%4d  %s' % (n, f))
        total += n
print('TOTAL', total)
PY
```

Expected: solo `imagen_chat_card.dart` y `voice_record_button.dart`, con un puñado de coincidencias cada uno, y **TOTAL ≤ 12**. Partía de **133**.

### Step 5: Verificar que `responsive_framework` desapareció del módulo

```bash
grep -rn "responsive_framework" lib/features/chat/
```

Expected: sin coincidencias.

```bash
grep -rln "responsive_framework" lib/
```

Expected: exactamente 4 ficheros — `main.dart`, `garage_screen.dart`, `workshop_directory_screen.dart`, `user_profile_screen.dart`. Los tres últimos son de la Fase 7; `main.dart` es el `builder` global y se retira en la Fase 2.

Si aparece alguno más, algo se ha reintroducido.

### Step 6: Commit

```
test(chat): cerrar el ratchet de colores del módulo chat

Añade 14 de los 16 ficheros de presentación del módulo a kTokenizedPaths.
El módulo partía de 133 colores literales (la densidad más alta de la app:
uno cada 30 líneas) y baja a ≤ 12, todos en los dos ficheros excluidos.

Las dos exclusiones son deliberadas y están documentadas en el propio
fichero: el visor de imagen a pantalla completa y el HUD de grabación se
dibujan sobre contenido arbitrario (la foto del usuario, el chat), no sobre
una superficie del tema, y el par negro-al-54 % + blanco es lo que
garantiza el contraste ahí. Si algún día AppColors expone scrim/onScrim,
esos dos ficheros deben migrarse.
```

---

## 15. Verificación de cierre de fase

Tras la Task 13, y antes de abrir el PR:

```bash
dart format .
dart fix --apply
flutter analyze
flutter test
```

Los cuatro deben pasar. Después, estas comprobaciones específicas de la fase:

**15.1 — La suite del módulo está en verde y sin filtros.**

```bash
grep -rn "FlutterError.onError" test/features/chat/
```

Expected: sin coincidencias. Era el mecanismo que tapaba el desbordamiento de `reserva_chat_card`.

**15.2 — No quedan anchos fijos en las tarjetas.**

```bash
grep -rnE "width: (2[0-9][0-9]|3[0-9][0-9])\b" lib/features/chat/presentation/widgets/
```

Expected: sin coincidencias. Partía de 6 (250, 250, 260, 260, 280, 280, 300).

**15.3 — Ninguna tarjeta consulta `isMe` para elegir color.**

```bash
grep -rn "isMe ?" lib/features/chat/presentation/widgets/cards/
```

Expected: coincidencias **solo** en `audio_chat_card.dart` (la excepción documentada: no tiene superficie propia) y en `vehiculo_chat_card.dart` (fondo translúcido intencional). Cualquier otra es una regresión de la regla de §1.

**15.4 — Verificación visual manual.** Cinco comprobaciones que ningún widget test cubre. Adjunta capturas al PR:

| Qué | Cómo | Qué buscar |
|---|---|---|
| Cotización propia en claro | Enviar una cotización como taller, tema claro | El texto se lee. Era invisible (1,00:1). |
| "Tu beneficio" en claro | La misma cotización, con beneficio > 0 | La fila aparece y se lee. **Nunca se ha visto.** |
| Mensaje de texto propio en oscuro | Enviar un mensaje, tema oscuro | Texto y acuse legibles sobre el turquesa. |
| Imagen alargada | Enviar una captura de pantalla larga | La burbuja no ocupa más de ~1,4 × su ancho. |
| Nota de voz | Grabar, deslizar, cancelar; grabar y soltar | El overlay aparece, el temporizador corre, el gesto es reversible. |

**15.5 — Auditoría de anchos.** Con la app corriendo en web o desktop, redimensiona la ventana pasando por 320, 375, 600, 768, 840, 1024, 1200 y 1440 con una conversación que contenga los siete tipos de mensaje. Ningún desbordamiento, ninguna línea de más de ~75 caracteres, y la barra de entrada siempre alineada con la lista.

---

## 16. Criterios de éxito

La fase está terminada cuando **todo** esto es cierto:

1. `flutter test test/features/chat/` pasa, **sin ningún `FlutterError.onError`** en el árbol de tests. (Partía de 33 pasan / 1 falla.)
2. `flutter analyze` sin issues nuevos; `dart format .` idempotente.
3. **≤ 12 colores literales** en `lib/features/chat/`, todos en los dos ficheros excluidos y justificados. (Partía de 133.)
4. **0 anchos fijos** en las tarjetas. (Partían de 6 distintos entre 250 y 300 px.)
5. **0 usos de `responsive_framework`** en el módulo. (Partía de 1, el único del módulo.)
6. Las 15 piezas de presentación pasan `expectNoOverflow` en los 8 anchos de `kAuditWidths`, en tema claro y oscuro.
7. Toda burbuja está acotada a `maxReadingWidth` desde `expanded`.
8. Todo control solo-icono del módulo tiene `tooltip` o `Semantics`; todo mensaje se anuncia con su autor. (Partía de **0** usos de `Semantics` en 3.925 líneas.)
9. Ningún texto del módulo baja de 4,5:1 sobre su fondo real, en ninguno de los dos temas, verificado por test donde el color es accesible desde el árbol.
10. Existe **una sola** clase `HistorialChatCard` en el proyecto.
11. El plan maestro §5.3 refleja las cifras medidas y el contrato realizable.

---

## 17. Deuda declarada

Cosas que esta fase **no** hace, con el motivo. No son olvidos.

**17.1 — El módulo sigue sin traducir.** Hay ~35 cadenas literales en español (`'Escribe un mensaje...'`, `'Mensajes'`, `'Reserva de Cita'`, `'Cotización de Servicio'`, los cuatro nombres de estado, los textos de los diálogos de perfil incompleto…) conviviendo con 26 claves `chatXxx` que sí existen en `lib/l10n/`. Añadir claves queda fuera del alcance de esta fase por la regla heredada de la Fase 4. **Es la deuda más grande del módulo tras esta fase** y merece su propio trabajo: no es solo traducir, es decidir el vocabulario de estados en dos idiomas.

**17.2 — `_statusTypeDe` está triplicado.** El mismo `switch` de cuatro ramas vive en `reserva_detail_screen`, `reserva_chat_card` y `cotizacion_chat_card`. No se extrae porque reserva y cotización comparten tres valores de estado pero no los cuatro (`aceptada`/`finalizada` frente a `confirmada`/`cotizada`), y un helper compartido tendría que decidir a cuál de los dos vocabularios pertenece. Tres copias de cuatro líneas es más honesto que una abstracción que miente.

**17.3 — `AudioChatCard` no tiene barra de progreso ni búsqueda.** Requiere suscribirse a `onPositionChanged` y resolver que `duracionSegundos` es la duración que midió el emisor, no la del fichero. Es funcionalidad nueva.

**17.4 — `cotizacion_picker` mantiene sus `TextFormField` nativos.** No se migran a `AppTextField` porque la Fase 3 no garantiza equivalencia de `validator` y este formulario funciona sin test que lo cubra. Migrarlo requiere primero un test del flujo de validación completo.

**17.5 — Tres piezas siguen consultando Firestore desde la presentación.** `CotizacionChatCard` (`StreamBuilder` en `build`), `ReservaDetailScreen` (`StreamBuilder` en `build`) y `chat_screen` (`FutureBuilder` del nombre del receptor, ahora cacheado). Se les añade el parámetro `firestore` inyectable para poder probarlas; mover las consultas a un repositorio tocaría `data/` y está prohibido por §2 del maestro.

**17.6 — El patrón de fondo del chat repinta en cada resize.** `ChatBackgroundPattern` tiene `shouldRepaint => false`, correcto, pero dibuja ~216 primitivas en una ventana de 1440 × 900 (paso de 80 px). No es un problema medido; se anota porque a 4K serían ~1.000. Si algún día molesta, la solución es cachear el patrón en una `ui.Image` con `PictureRecorder`, no reducir el detalle.

**17.7 — `_pickAndSendImage` no comprime.** Envía la imagen tal cual la devuelve `image_picker`. Una foto de móvil moderna son 4–8 MB. Es un problema de coste y de tiempo de subida, no de UI, y tocarlo entra en `ChatProvider.subirImagenChat`.

---

## 18. Bloqueos a consultar

Cuatro decisiones que **no** se toman por cuenta propia durante la ejecución. Si se llega a una de ellas, se para y se pregunta.

**18.1 — El master-detail que pide el maestro.** El contrato original de §5.3 era, para `expanded`+, mostrar la lista de conversaciones a la izquierda y el chat a la derecha. Es la disposición correcta para escritorio, y esta fase **no** la implementa. Coste real: `/chat_list` vive dentro del `ShellRoute` de propietario mientras `/chat/:id` es ruta de primer nivel, así que hay que (a) convertir el par en un `StatefulShellRoute` o una ruta anidada, (b) decidir qué hace `/chat/:id` cuando se abre por deep link con panel izquierdo —¿selecciona la conversación en la lista, o se muestra sin lista?—, (c) decidir qué pasa al rol taller, que alcanza `/chat_list` pero no pertenece a ese shell (ver Fase 2). Son tres decisiones de navegación. **Recomendación:** hacerlo como fase propia después de la 8, cuando el shell esté estabilizado. Lo entregado mientras tanto —columna de lectura acotada— es la disposición que usan Slack y WhatsApp Web y no es un parche.

**18.2 — `AppButton` no tiene variante destructiva.** Verificado el 2026-08-12: `enum AppButtonType { primary, secondary, text }` ([app_button.dart:9](../../../lib/core/widgets/app_button.dart#L9)). Cuatro botones de "Rechazar" en tres ficheros de este módulo usan hoy `Colors.red` explícito, y al migrarlos a `AppButton` pierden la señal de acción destructiva. Las dos salidas son añadir `danger` al enum (amplía la Fase 3 desde la Fase 6) o usar `secondary` con `colors.error` como `foregroundColor` si `AppButton` lo permite. **Recomendación:** usar `secondary` en esta fase y abrir `danger` como trabajo de la Fase 3, no decidirlo aquí — rechazar una cita y rechazar una cotización no son las únicas acciones destructivas de la app.

**18.3 — `AppPalette.lightSuccess` no sirve como color de texto en tema claro.** Medido el 2026-08-12: `#48BB78` sobre `lightSurface #F7F6F8` da **2,25:1** (en oscuro, sobre `#0F172A`, da 7,36:1 y está bien). Es decir, el token de éxito **es inutilizable como portador de significado en la mitad clara de la app**, y esto no es específico del chat: afecta a cualquier pantalla que escriba "correcto", "aprobado" o "completado" en verde sobre fondo claro. Esta fase lo esquiva (§Task 8 Step 4: el texto va en `textPrimary` y el verde queda como refuerzo), pero esquivarlo trece veces no es una solución. **Recomendación:** oscurecer `lightSuccess` a un verde con ≥ 4,5:1 sobre `#F7F6F8` —del orden de `#2F855A`— manteniendo `darkSuccess` como está. Es un cambio de `AppPalette`, que el §2 del maestro prohíbe hacer por cuenta propia. Consultar antes de tocarlo.

**18.4 — Dependencia dura de la corrección de `lightTextSecondary` de la Fase 1.** `lightTextSecondary` (`#64748B`) sobre `lightSurface` da hoy **4,42:1**, por debajo de AA. La Fase 1 lo corrige, y es la única excepción autorizada a "no se toca `AppPalette`". Varios tests de esta fase afirman ≥ 4,5:1 sobre texto que usa ese token (subtotales de cotización, fechas secundarias, "Tu beneficio"). **Si se ejecuta la Fase 6 sin haber ejecutado la Fase 1, esos tests fallan por 0,08 puntos y la causa parecerá estar en el chat.** No es así: comprueba primero el valor de `lightTextSecondary`.

Lo que **no** es un bloqueo, y se deja escrito para que nadie lo reabra: `AppColors.onPrimary` existe y funciona en ambos temas (10,31:1 en claro, 12,12:1 en oscuro). Es el token sobre el que se apoyan cinco de las correcciones de contraste de esta fase.

---

## 19. Resumen de la fase

| | Antes | Después |
|---|---:|---:|
| Colores literales | 133 | ≤ 12 (excepciones justificadas) |
| Anchos fijos en tarjetas | 6 (250–300 px) | 0 |
| Usos de `Semantics` | 0 | ≥ 18 |
| Sistemas de breakpoints en el módulo | 1 (`responsive_framework`) + ninguna consulta de ancho | 1 (`AppBreakpoints`) |
| `LayoutBuilder` | 0 | ≥ 3 |
| Tests del módulo | 33 pasan / **1 falla** | todos pasan, sin filtros de error |
| Clases `HistorialChatCard` | 2 | 1 |
| Peor contraste medido | **1,00:1** (blanco sobre blanco) | ≥ 4,5:1 |
