# AutoDoc — UI/UX Overhaul ("vuelta de rueda al diseño") — Plan Maestro

> **For agentic workers:** este documento es el **roadmap y la especificación por pantalla**. No se ejecuta directamente. Los planes ejecutables son los archivos hermanos `...-01-foundation.md`, `...-02-shell-navigation.md`, `...-03-shared-components.md`, y los planes por módulo (Fases 4–8) que se escriben justo antes de ejecutarse siguiendo el protocolo de §7.
>
> **REQUIRED SUB-SKILL para ejecutar cualquier fase:** `superpowers:subagent-driven-development` (recomendado) o `superpowers:executing-plans`.

**Goal:** Rediseñar la capa de presentación de AutoDoc (34 pantallas, 9 módulos) para que sea (a) totalmente responsiva con layouts que cambian de estructura —no solo de escala— entre móvil, tablet y desktop, (b) consistente con un design system tokenizado sin colores hardcodeados, (c) pulida en interacción y motion, y (d) accesible; todo sin cambiar la identidad de marca ni los flujos de negocio.

**Architecture:** Tres fases de base (tokens → shell/navegación → componentes compartidos) que se construyen primero y de las que dependen las cinco fases por módulo de pantallas. La responsividad pasa de un modelo de *escalado* (`Responsive.fontSize/padding/size`, que multiplica valores por ≤1.15) a un modelo de *window size classes* al estilo Material 3 (compact/medium/expanded/large), donde cada pantalla declara explícitamente qué layout usa en cada clase. Se elimina el segundo sistema de breakpoints (`responsive_framework`) que hoy convive y contradice al primero.

**Tech Stack:** Flutter 3.41.6 (Material 3), Provider, go_router 17, `flutter_animate`, `animations`, `shimmer`, `flutter_staggered_animations`. Tests con `flutter_test` (`WidgetTester`). Sin dependencias nuevas; se **elimina** una (`responsive_framework`).

---

## 1. Skills obligatorias (no negociable)

Este trabajo se ejecuta **con** las skills de diseño, no "inspirado" en ellas. Toda tarea que toque layout, color, tipografía, interacción o motion debe invocar las skills indicadas **antes** de escribir código, y dejar constancia en el mensaje de commit o en el reporte de la tarea.

| Skill | Invocación | Cuándo es obligatoria | Qué aporta aquí |
|---|---|---|---|
| `ui-ux-pro-max` (nextlevelbuilder/ui-ux-pro-max-skill) | `Skill(ui-ux-pro-max:ui-ux-pro-max)` + `scripts/search.py ... --stack flutter` | **Toda** tarea de layout, breakpoints, color, tipografía, formularios, navegación, gráficos | Reglas priorizadas 1→10 (accesibilidad > touch > performance > estilo > responsive), guidelines específicas de Flutter, y la *Pre-Delivery Checklist* canónica de `references/pro-rules.md` |
| `emil-design-eng` (emilkowalski/skills) | `Skill(emil-design-eng)` | **Toda** tarea de motion, press/hover feedback, transiciones, curvas y duraciones | Framework de decisión de animación (¿debe animar? → propósito → easing → duración), curvas custom, regla de exit-más-rápido-que-enter, stagger, reduced-motion |
| `apple-design` (emilkowalski/skills) | `Skill(apple-design)` | Tareas con gestos, sheets, drawers, drag/swipe, springs (chat, bottom sheets, kanban) | Motion físico e interrumpible, materiales translúcidos, tipografía óptica |
| `animate` (emilkowalski/skills) | `Skill(animate)` | Cuando una tarea **construye** una animación nueva desde cero | Orden de decisiones que determina si el motion se siente bien; escribe la implementación |
| `review-animations` (emilkowalski/skills) | `Skill(review-animations)` | En el *code review* de toda tarea que agregue o modifique motion | Revisión contra un listón alto; por defecto marca problemas, la aprobación se gana |
| `find-animation-opportunities` (emilkowalski/skills) | `Skill(find-animation-opportunities)` | Una vez por módulo, al **inicio** de cada fase 4–8 | Detecta qué en ese módulo debería animar y —igual de importante— qué no |
| `improve-animations` (emilkowalski/skills) | `Skill(improve-animations)` | Una vez, al cerrar la Fase 8, como auditoría global | Audit priorizado del motion de toda la app |
| `superpowers:test-driven-development` | `Skill(superpowers:test-driven-development)` | Toda tarea con código | Ciclo test-primero que estructura cada tarea de estos planes |
| `superpowers:requesting-code-review` | `Skill(superpowers:requesting-code-review)` | Al cerrar cada fase | Revisión antes de mergear |
| `graphify` | `Skill(graphify)` o `/graphify` | Al abrir cada fase por módulo, para mapear qué consume cada pantalla | Grafo de conocimiento del código (`graphify-out/graph.json`) |

**Resultado de `find-skills` (ejecutado 2026-08-10, modo offline):** las dos skills pedidas ya están instaladas y habilitadas — `ui-ux-pro-max@ui-ux-pro-max-skill` y la familia de emilkowalski en `~/.claude/skills/` (`emil-design-eng`, `animate`, `apple-design`, `review-animations`, `improve-animations`, `find-animation-opportunities`, `animation-vocabulary`, `pick-ui-library`, `prototype`). Marketplaces revisados: `easier-life-skills`, `claude-plugins-official`, `karpathy-skills`, `ui-ux-pro-max-skill`. Únicas adiciones con valor real para esta refactorización:

- **`site-audit`** (`easier-life-skills`) — *Relevancia: Media.* Audita una web por problemas de UX/accesibilidad/performance. AutoDoc compila a Flutter Web (`usePathUrlStrategy()` en [main.dart:68](../../../lib/main.dart#L68), `flutter_web_plugins` en pubspec) y hoy no hay ninguna auditoría automatizada de la build web. Útil como verificación de cierre de la Fase 8 contra el build desplegado. Instalar: `/plugin install easier-life-skills/site-audit`.
- **`code-audit`** (`easier-life-skills`) — *Relevancia: Media.* Encuentra código muerto. Esta refactorización va a dejar residuos garantizados (el bloque comentado de [app_scaffold.dart:29-34](../../../lib/core/widgets/app_scaffold.dart#L29-L34), helpers de `Responsive` que dejen de usarse tras la Fase 1, `responsive_framework` tras la Fase 2). Correr al cerrar la Fase 3 y de nuevo al cerrar la Fase 8.

No se recomienda nada más: el resto de los catálogos apunta a dominios que este repo no tiene (REST APIs, changelog público, pipelines de datos) o ya está cubierto por `superpowers`.

### 1.1 Cómo se usó `ui-ux-pro-max` para este plan, y qué se rechazó

Se ejecutó `search.py "vehicle maintenance service management dashboard automotive utility multi-role" --design-system -p AutoDoc --variance 4 --motion 4 --density 6`. **Se adopta** su capa estructural: la tabla de prioridades 1→10, la *Pre-Delivery Checklist* de `references/pro-rules.md`, las guidelines de stack Flutter (`LayoutBuilder` para layouts adaptativos, `PopScope` en vez de `WillPopScope`, `Expanded`/`Flexible` en vez de anchos fijos dentro de flex, evitar anidamiento profundo), y los breakpoints de verificación 375 / 768 / 1024 / 1440 px.

**Se rechaza explícitamente** su recomendación de paleta (`#16A34A` verde operacional + `#DC2626` rojo) y de tipografía (Fira Code / Fira Sans): AutoDoc tiene una identidad establecida —morado `#522C81` / teal `#81E6D9` en light, invertidos en dark, con Inter— que está bien resuelta en [app_colors.dart:112-146](../../../lib/core/theme/app_colors.dart#L112-L146). El match de la base de datos vino del *product type* "operations/IoT", no de la marca. Cambiar paleta y tipografía sería un rebrand, no "una vuelta de rueda al diseño". El estilo *Glassmorphism* que sugiere se adopta **solo** donde ya existe de facto (la top nav flotante con `alpha: 0.8` en [app_top_nav_bar.dart:28](../../../lib/core/widgets/app_top_nav_bar.dart#L28)), no como lenguaje global — su propia ficha lo marca como `Performance: ⚠ Good` y `Accessibility: ⚠ Ensure 4.5:1`, y AutoDoc corre en móviles de gama baja.

---

## 2. Global Constraints

Aplican a **todas** las tareas de **todas** las fases. Cada tarea hereda implícitamente esta sección.

- **Marca intacta.** No se modifican los valores de `AppPalette` ([app_colors.dart:112-146](../../../lib/core/theme/app_colors.dart#L112-L146)) salvo la única excepción justificada en la Fase 1 Task 4 (`lightTextSecondary`, que mide 4.42:1 y falla WCAG AA). No se cambia la familia tipográfica (Inter vía `google_fonts`).
- **Cero colores hardcodeados** en `lib/features/**` y `lib/core/widgets/**`. Prohibido `Colors.white`, `Colors.black87`, `Colors.white70`, `Colors.grey`, `Color(0xFF...)` literal. Siempre `context.appColors.<token>` o `Theme.of(context)`. Regla del proyecto: `CONVENTIONS.md` §2.1. **Única excepción permitida:** `Colors.transparent` y los `Colors.black.withValues(...)` dentro de `lib/core/theme/app_shadows.dart`, que son la definición de la sombra misma.
- **Un solo sistema de breakpoints.** Tras la Fase 1, la única fuente de verdad es `AppBreakpoints` / `WindowClass`. Prohibido `MediaQuery.of(context).size.width` crudo para decisiones de layout en `lib/features/**`, y prohibido `package:responsive_framework` (se desinstala en la Fase 2).
- **Layouts adaptativos, no escalados.** Cuando el cambio de tamaño implica reordenar, apilar/desapilar o cambiar el número de columnas, se usa `LayoutBuilder` + `WindowClass`. `Responsive.fontSize/padding/size` queda **solo** para ajuste fino de escala dentro de una misma estructura.
- **Sin scroll horizontal.** Ninguna pantalla puede producir overflow horizontal a 320 px de ancho. Los anchos fijos ≥200 px dentro de `Row`/`Flex` se sustituyen por `Expanded`/`Flexible` o por `ConstrainedBox(maxWidth:)`.
- **Touch targets ≥ 48×48 dp.** Todo elemento tappable. Si el icono es menor, se expande el área con `padding` o `SizedBox`, no con `hitSlop` (no existe en Flutter).
- **Contraste.** Texto de cuerpo ≥ 4.5:1, texto secundario y glifos grandes ≥ 3:1, **verificado en light y en dark por separado**. Nunca inferir dark desde light.
- **Motion tokenizado.** Toda curva y duración viene de `AppMotion` o `AppTransitions`. Prohibido `Curves.easeIn` para entradas (regla de `emil-design-eng`: `ease-in` retrasa el movimiento justo en el instante que el usuario mira). Prohibido `Duration` literal en widgets.
- **Reduced motion respetado.** Toda animación de posición/escala consulta `MediaQuery.disableAnimationsOf(context)` (directamente o vía el helper `AppMotion.reduced(context)`). Con reduced motion activo se conservan opacidad y color, se elimina el desplazamiento.
- **Semántica.** Todo control sin texto visible lleva `tooltip:` (si es `IconButton`) o va envuelto en `Semantics(label: ...)`. Toda imagen con significado lleva `semanticLabel`.
- **`dart format .` y `dart fix --apply` antes de cada commit** (`CONVENTIONS.md` §4). Los lints activos son `avoid_print`, `prefer_const_constructors`, `require_trailing_commas`.
- **`flutter analyze` sin issues nuevos** antes de cada commit.
- **No se toca la capa `data/` ni `providers/`.** Este trabajo es exclusivamente de presentación. Si una pantalla necesita un dato que el provider no expone, se documenta como bloqueo y se consulta — no se modifica el provider por cuenta propia.
- **Un commit por tarea.** Mensajes en formato `feat(scope):` / `fix(scope):` / `refactor(scope):`.

---

## 3. Window size classes (la decisión estructural del plan)

Hoy conviven **tres** sistemas incompatibles:

| Sistema | Dónde | Cortes |
|---|---|---|
| `Responsive` | [responsive.dart:12-14](../../../lib/core/utils/responsive.dart#L12-L14) | mobile < 600, tablet 600–1199, desktop ≥ 1200 |
| `responsive_framework` | [main.dart:356-361](../../../lib/main.dart#L356-L361) | MOBILE 0–450, TABLET 451–800, DESKTOP 801–1920, 4K ≥ 1921 |
| `MediaQuery...width < 700` | **8 ficheros** de `features/mechanic` (ver Fase 5 §0.1) | un único corte en 700 |
| `MediaQuery...width > 900 / > 600` | [admin_dashboard_screen.dart:221-222](../../../lib/features/admin/presentation/pages/admin_dashboard_screen.dart#L221-L222) | dos cortes propios, en 600 y 900 |

> **Corregido el 2026-08-12 al escribir la Fase 8.** Son **cuatro** sistemas, no tres. El cuarto vive en un solo fichero y se contradice consigo mismo: a **600 px exactos** `admin_dashboard_screen` dibuja sus métricas en **una** columna (`600 > 600` es falso) y sus gráficos en **dos** (`600 < 600` también es falso), dentro del mismo `build()`. Lo elimina la Fase 8 Task 8.
>
> **Corregido el 2026-08-11 al escribir la Fase 5.** El tercer sistema no estaba registrado aquí: es un `final isMobile = MediaQuery.of(context).size.width < 700` copiado literalmente en ocho de las diez pantallas del rol taller, y es el que gobierna toda su navegación. A 650 px `Responsive.isMobile` ya es `false` mientras esas pantallas siguen dibujando la UI de teléfono; a 700 px activan un sidebar de 280 dp que deja 420 px de contenido. Lo elimina la Fase 5 Task 1.

**Consecuencia verificable:** a 900 px de ancho, [garage_screen.dart:82](../../../lib/features/dashboard/presentation/pages/garage_screen.dart#L82) (`ResponsiveBreakpoints.of(context).largerThan(TABLET)` → `true`) se dibuja como desktop, mientras [main_scaffold.dart:17](../../../lib/core/widgets/main_scaffold.dart#L17) (`Responsive.isDesktop` → `false`) sigue pintando la bottom nav móvil. Lo mismo en `workshop_directory_screen`, `user_profile_screen` y `conversaciones_list_screen`. Es una contradicción real, no teórica.

**Decisión:** una sola escala, alineada a Material 3 window size classes, expresada como enum para que sea exhaustiva en `switch` y testeable:

| Clase | Ancho | Dispositivo típico | Navegación | Gutter | Columnas de contenido |
|---|---|---|---|---|---|
| `compact` | < 600 | teléfono vertical | bottom nav | 16 | 1 |
| `medium` | 600–839 | teléfono horizontal, tablet vertical | **navigation rail** (colapsado) | 24 | 2 |
| `expanded` | 840–1199 | tablet horizontal, laptop pequeño | navigation rail (extendido) | 32 | 2–3 |
| `large` | ≥ 1200 | desktop | top nav / sidebar | 40, contenido con `maxWidth: 1200` centrado | 3–4 |

El salto que hoy no existe y que arregla el grueso de la queja de responsividad es **`medium` + `expanded`**: la franja 600–1199 px hoy recibe la UI de teléfono con las fuentes un 10 % más grandes. Ahí es donde entra el `NavigationRail` y donde los grids pasan de 1 a 2–3 columnas.

---

## 4. Fases

Cada fase produce software funcionando y testeable por sí sola. Las fases 1–3 son **bloqueantes**: las fases 4–8 consumen sus tokens y componentes.

| Fase | Documento | Alcance | Dependencias |
|---|---|---|---|
| **1. Foundation** | `...-01-foundation.md` | `AppBreakpoints`/`WindowClass`, `AppMotion`, `AppShadows` hover, fix de contraste, `AppGrid`/`AppPageBody`, harness de tests responsivos | — |
| **2. Shell & Navegación** | `...-02-shell-navigation.md` | `MainScaffold` adaptativo con `NavigationRail`, `AppScaffold`, `AppTopNavBar`, `InstagramBottomNavBar`, sidebars, eliminación de `responsive_framework` | Fase 1 |
| **3. Componentes compartidos** | `...-03-shared-components.md` | `AppButton`, `AppCard`, `AppTextField`, `AppEmptyState`, `AppSkeleton*`, `AppSnackbar`, `AppStatusBadge`, `AnimatedCounter`, `NotificationBellButton`, `ResponsiveContainer` | Fases 1–2 |
| **4. Dashboard (propietario)** | `...-04-dashboard.md` | 9 pantallas de `features/dashboard` — **escrito**, 12 tareas | Fases 1–3 |
| **5. Mechanic (taller)** | `...-05-mechanic.md` | 10 pantallas de `features/mechanic` — **escrito**, 12 tareas | Fases 1–3 |
| **6. Chat & Reservas** | `...-06-chat.md` | 3 pantallas + 12 widgets de `features/chat` — **escrito**, 13 tareas | Fases 1–3 |
| **7. Auth, Onboarding, Profile, Splash** | `...-07-entry-profile.md` | 6 pantallas + 3 widgets de `auth` — **escrito**, 14 tareas | Fases 1–3 |
| **8. Admin** | `...-08-admin.md` | 6 pantallas + 9 widgets de `features/admin` — **escrito**, 12 tareas | Fases 1–3 |

Orden por tráfico real de usuario: dashboard y mechanic primero (son los dos roles principales), admin al final (menor tráfico, usuarios internos).

---

## 5. Inventario y contrato por pantalla (34 pantallas)

Métricas medidas sobre el árbol en `HEAD` (2026-08-10). **HC** = ocurrencias de `Colors.<literal>` hardcodeadas. **Resp** = llamadas a `Responsive.*`. Cada fila es el contrato que el plan de su fase debe cumplir.

### 5.1 Módulo `dashboard` — Fase 4

| Pantalla | LOC | HC | Resp | Diagnóstico medido | Contrato objetivo |
|---|---|---|---|---|---|
| [dashboard_screen.dart](../../../lib/features/dashboard/presentation/pages/dashboard_screen.dart) | 1072 | 7 | 30 | Sin `LayoutBuilder`. Ancho fijo `width: 150` en L898. FAB en `Positioned(bottom: 100)`. Es la home del rol propietario. | **Corregido tras leer el fichero (ver Fase 4 Task 6):** `compact`/`medium` columna única; `expanded`/`large` **2** columnas (izq. vehículo + semáforo, der. alertas + talleres). Los "3 columnas con resumen de gastos" del contrato original eran incorrectos: el resumen de gastos vive en `vehicle_profile`, y esta pantalla solo tiene 4 bloques. |
| [garage_screen.dart](../../../lib/features/dashboard/presentation/pages/garage_screen.dart) | 425 | 5 | 7 | **Usa `responsive_framework`** (L82). Único consumidor de `flutter_staggered_animations`. | Grid de vehículos vía `AppGrid`: 1 / 2 / 3 / 4 columnas. Migrar L82 a `WindowClass`. Conservar y tokenizar el stagger existente. |
| [vehicle_profile_screen.dart](../../../lib/features/dashboard/presentation/pages/vehicle_profile_screen.dart) | 1098 | 7 | 13 | `crossAxisCount: Responsive.isDesktop(context) ? 4 : 2` (L354) — salto binario, sin estado intermedio. Placa con `width: 140, height: 80` fijos (L324). | Galería vía `AppGrid` (2/3/4/5). `medium` y `expanded` dejan de recibir el layout de teléfono. Placa con `AspectRatio` en vez de tamaño fijo. Hero transition desde la tarjeta del garaje. |
| [service_history_screen.dart](../../../lib/features/dashboard/presentation/pages/service_history_screen.dart) | 826 | 11 | — | Anchos fijos `380` (L468) y `110` (L537). | `compact`: lista de tarjetas. `expanded`/`large`: tabla con columnas flexibles. Los `380`/`110` → `Flexible`. |
| [alerts_screen.dart](../../../lib/features/dashboard/presentation/pages/alerts_screen.dart) | 832 | 8 | 7 | 8 colores hardcodeados en una pantalla cuyo lenguaje **es** el color (severidad de alerta). | Semáforo de severidad desde `colors.error/warning/success`. Color nunca como único indicador: añadir icono por severidad (regla `ui-ux-pro-max` §10). |
| [workshop_directory_screen.dart](../../../lib/features/dashboard/presentation/pages/workshop_directory_screen.dart) | 1202 | 22 | 48 | El fichero con más `Responsive.*` **y** 22 colores hardcodeados. Usa `responsive_framework` (L310). Ancho fijo `240` (L830). Integra Google Maps. | `compact`: lista con mapa en sheet. `medium`+: split view lista/mapa 40/60. Migrar L310. Tokenizar los 22 colores. |
| [notifications_screen.dart](../../../lib/features/dashboard/presentation/pages/notifications_screen.dart) | 274 | — | **0** | Cero responsividad. | Ancho de lectura acotado (`maxWidth: 720`) en `expanded`/`large` — regla de *readable text measure*. Swipe-to-dismiss con dismissal por velocidad (`apple-design`). |
| [task_config_screen.dart](../../../lib/features/dashboard/presentation/pages/task_config_screen.dart) | 248 | — | 9 | Formulario. | Formulario a `maxWidth: 560` centrado en `medium`+. Validación inline, error junto al campo (`ui-ux-pro-max` §8). |
| [task_complete_screen.dart](../../../lib/features/dashboard/presentation/pages/task_complete_screen.dart) | 671 | 19 | 7 | 19 colores hardcodeados. Pantalla de confirmación → candidata legítima a "delight" (baja frecuencia, según el framework de `emil-design-eng`). | Tokenizar color. Animación de éxito permitida por ser de frecuencia rara; respeta reduced-motion. |

### 5.2 Módulo `mechanic` — Fase 5

| Pantalla | LOC | HC | Resp | Diagnóstico medido | Contrato objetivo |
|---|---|---|---|---|---|
| [initiate_service_screen.dart](../../../lib/features/mechanic/presentation/pages/initiate_service_screen.dart) | 1417 | 6 | 36 | **El fichero más grande de la app**, y el que más `GoogleFonts` tiene: **38**, no 6 (medido 2026-08-11). **No es un flujo multi-paso**: es un único `SingleChildScrollView > Column` con 8 secciones y un solo botón de envío. | **Corregido (ver Fase 5 Task 11):** convertirlo en stepper cambiaría el flujo de negocio, prohibido por §2. `compact`/`medium`: una columna a `maxFormWidth`. `expanded`/`large`: **dos columnas** — izq. recepción (vehículo, km, alertas, tareas), der. facturación (materiales, mano de obra, total, observaciones, factura, botón). |
| [mechanic_dashboard_screen.dart](../../../lib/features/mechanic/presentation/pages/mechanic_dashboard_screen.dart) | 843 | 3 | 25 | **Su `LayoutBuilder` está roto**, no es la referencia de lo que funciona: calcula `cardWidth = (maxWidth − 48)/3` pero el `SizedBox` va dentro del padding de `AppCard`, así que el ancho externo real es `cardWidth + 55` y **nunca caben 3 tarjetas**; dibuja 2 con 227 px muertos por fila. Además `Colors.white` sobre el degradado de `primary` da **1,47:1 en dark**. | **Corregido:** KPIs en `AppGrid` **1/2/3/3** (son 6 KPIs; con 4 columnas quedan dos huérfanos). Texto del degradado a `colors.onPrimary`. Alternativa textual para la gráfica de `fl_chart`. |
| [workshop_settings_screen.dart](../../../lib/features/mechanic/presentation/pages/workshop_settings_screen.dart) | 931 | 16 | 21 | 16 colores hardcodeados. Formulario largo. | Secciones colapsables en `compact`; dos columnas en `expanded`+. Tokenizar color. |
| [mechanic_reviews_screen.dart](../../../lib/features/mechanic/presentation/pages/mechanic_reviews_screen.dart) | 708 | — | 14 | — | Lista → grid 1/2/3. Estrellas con `semanticLabel` (hoy la calificación es solo visual). |
| [empleados_screen.dart](../../../lib/features/mechanic/presentation/pages/empleados_screen.dart) | 540 | — | 12 | Ancho fijo `420` (L105). | Grid de empleados 1/2/3. `420` → `ConstrainedBox(maxWidth: 420)`. |
| [vehicle_search_screen.dart](../../../lib/features/mechanic/presentation/pages/vehicle_search_screen.dart) | 466 | — | 19 | — | Campo de búsqueda a `maxWidth: 640`. Resultados en grid. Debounce de búsqueda (`ui-ux-pro-max` §3). |
| [catalogo_servicios_screen.dart](../../../lib/features/mechanic/presentation/pages/catalogo_servicios_screen.dart) | 383 | — | 6 | Ancho fijo `380` (L101). | Grid 1/2/3. `380` → `Flexible`. |
| [mechanic_service_history_screen.dart](../../../lib/features/mechanic/presentation/pages/mechanic_service_history_screen.dart) | 373 | — | — | Ancho fijo `380` (L238). Sin `Responsive`. | Mismo tratamiento tabla/lista que `service_history_screen`. |
| [mechanic_pending_screen.dart](../../../lib/features/mechanic/presentation/pages/mechanic_pending_screen.dart) | 270 | — | 6 | Ancho fijo `120` (L95). Pantalla de espera. | Estado vacío centrado con `maxWidth: 480`. |
| [reparaciones_kanban_screen.dart](../../../lib/features/mechanic/presentation/pages/reparaciones_kanban_screen.dart) | 153 | — | — | Kanban sin responsividad, y **desborda en vertical**: las columnas son `Column` dentro de un scroll horizontal, que da ancho ilimitado pero altura acotada. | `compact`/`medium`: tabs por estado con contador. `expanded`/`large`: columnas con `ListView` propio. **Sin drag**: el tablero avanza con botón y añadir arrastre sería una feature, no una refactorización (backlog). |

> **Métricas corregidas el 2026-08-11** tras leer los 10 ficheros completos. Los valores de `HC`, `Resp` y varias notas de esta tabla eran aproximados; la medición exacta está en la [Fase 5 §0](2026-08-10-ui-ux-overhaul-05-mechanic.md), junto con el hallazgo estructural que esta tabla no recogía: **el shell del rol taller está copiado en ocho de las diez pantallas**, con su propio breakpoint de 700 px y su barra superior reescrita seis veces. Correcciones puntuales además de las dos filas de arriba: `workshop_settings` tiene **7 `GoogleFonts.montserrat`** (la tercera familia tipográfica no está solo en `mechanic_sidebar`); `mechanic_service_history` **sí usa `Responsive`** (3 llamadas) y tiene 2 colores literales; `mechanic_reviews` tiene 1 (`Colors.red`).

### 5.3 Módulo `chat` — Fase 6

| Pantalla | LOC | HC | Resp | Diagnóstico medido | Contrato objetivo |
|---|---|---|---|---|---|
| [chat_screen.dart](../../../lib/features/chat/presentation/pages/chat_screen.dart) | 829 | **16** | **0** | Cero consultas de ancho. La burbuja **no tiene `maxWidth`**: a 1440 px una línea ocupa 1376 px. En oscuro el texto propio es blanco sobre `#81E6D9` = **1,47:1**. | `ChatBubble` con tope de `maxReadingWidth` (720) desde `expanded`; lista a 1200. **El master-detail no entra**: exige reestructurar el router (ver Fase 6 §18.1). |
| [conversaciones_list_screen.dart](../../../lib/features/chat/presentation/pages/conversaciones_list_screen.dart) | 210 | 3 | **0** | Usa `responsive_framework` (L62) pero cero `Responsive`. Es la **única** llamada al paquete en todo el módulo. | Migrar L62 a `AppBreakpoints.isAtLeastExpanded` (el corte pasa de 800 a 840). Lista a `maxReadingWidth`. Estado vacío accionable. |
| [reserva_detail_screen.dart](../../../lib/features/chat/presentation/pages/reserva_detail_screen.dart) | 505 | 9 | **0** | Cero responsividad. Los estados mezclan `Colors.green/red/blue` con `colors.warning` en una ternaria anidada; el chip da **2,16–2,64:1**. | `maxWidth: 720` centrado. `AppSeverity.forReservaEstado` + `AppStatusBadge`. Botones a `AppButton`. |
| **Cards de chat** (7 en `widgets/cards/`) | — | **89** | — | `cotizacion` 31 · `reserva` 26 · `review` 13 · `historial` 12 (muerta) · `imagen` 5 · `audio` 2 · `vehiculo` **0**. Anchos fijos 250/260/280/300: **desbordan a 320 px** y no crecen nunca. Cuatro pintan texto blanco sobre su propia tarjeta blanca: **1,00:1** cuando el mensaje es propio y el tema claro. | `ChatCardShell`: sin ancho fijo, cabecera con `Expanded`+ellipsis, y colores que **no** dependen de `isMe`. Ver Fase 6 §0.1. |

> **Corregido el 2026-08-12 al escribir la Fase 6.** Cuatro datos de esta tabla estaban mal medidos o desactualizados:
>
> 1. **Colores.** No son 73 en el módulo sino **133** (89 en `widgets/cards/`, 44 en el resto de la presentación). Es la densidad más alta de la app: uno cada 30 líneas.
> 2. **La tarjeta `historial` que describía esta tabla es código muerto.** Existen **dos** clases `HistorialChatCard`: la de `widgets/cards/` (ancho fijo 260, 12 colores literales, **que no importa nadie**) y la de `widgets/` (la que usa `chat_screen`, sin ancho fijo, con otro defecto: dibuja una burbuja dentro de la burbuja). Ver Fase 6 §0.5.
> 3. **El master-detail no es realizable como refactor de presentación.** `/chat_list` vive en el `ShellRoute` de propietario y `/chat/:id` es ruta de primer nivel; montarlas juntas es reestructurar el router y redefinir el deep link. Sustituido por columna de lectura acotada; el coste queda en Fase 6 §18.1.
> 4. **El módulo llegaba a la fase con un test en rojo.** `reserva_chat_card_test.dart` falla en `HEAD` por un desbordamiento de 118 px que el propio test intentaba silenciar con un filtro anclado a un número de línea que ya había cambiado. Ver Fase 6 §0.2.

### 5.4 Módulo `auth` / `onboarding` / `profile` / `splash` — Fase 7

| Pantalla | LOC | HC | Resp | Diagnóstico medido | Contrato objetivo |
|---|---|---|---|---|---|
| [auth_screen.dart](../../../lib/features/auth/presentation/pages/auth_screen.dart) | 789 | 3 | 8 | **La única pantalla con `Semantics`** (2 usos), pero ambas etiquetas empiezan por *“Botón”* sobre `button: true` —el lector las anuncia dos veces— y están en español literal. **Desborda 10,0 px a 320 px solo en `en`** (`“OR CONTINUE WITH”` mide 184 px y solo hay 208). `Checkbox` de **20×20**. `Image.network` desde `google.com`. | Arreglar la referencia antes de elevarla. `expanded`+: split branding/formulario. Tarjeta a `maxWidth: 400` — el `Responsive.size(context, 450)` interno es código muerto (medido: 400 a 1440 px). |
| [login_screen.dart](../../../lib/features/auth/presentation/screens/login_screen.dart) | **15** | — | — | **No es una pantalla**: devuelve `const AuthScreen(isLogin: true)`. Su comentario afirma envolver el layout en `SingleChildScrollView` y `ConstrainedBox` — no lo hace. Su test comprueba justo eso y pasa por construcción. | **Eliminar.** `/register` ya monta `AuthScreen` directo; la indirección no añade nada. Ver Fase 7 §0.5.3. |
| [user_profile_screen.dart](../../../lib/features/profile/presentation/pages/user_profile_screen.dart) | 920 | **53** | 33 | **El peor infractor de la app** (36 `Colors.*` + 17 `Color(0xFF…)`), y no por descuido: **bifurcó la paleta** copiando cinco valores de `AppPalette`. Editar en oscuro da **1,00:1** (texto blanco sobre relleno blanco); los 3 `Switch` dan **1,19:1**. **Por encima de 800 px no hay botón de editar**, así que el perfil es de solo lectura sin avisar. | Tokenizar los 53. La migración de `responsive_framework` la hace la **Fase 2 Task 1**. `expanded`+: sidebar de secciones + panel de contenido, y **devolver la edición** en todas las clases. |
| [profile_setup_screen.dart](../../../lib/features/profile/presentation/pages/profile_setup_screen.dart) | 842 | 6 | 25 | **No es multi-paso**: un solo formulario con un indicador que dice `'PASO 1 DE 1'` y la barra al 100 %. **Su `AppBar` desborda en TODO ancho de teléfono** (144+176 px a 320; 89+121 a 375; limpia solo desde 600). Tarjetas de rol sin semántica. El interruptor de notificaciones no persiste nada. | Formulario a `maxFormWidth`. **Quitar el indicador falso** (es parte de lo que provoca el desbordamiento). Rol como grupo de opción exclusiva. Frecuencia rara → se permite delight. |
| [about_screen.dart](../../../lib/features/profile/presentation/pages/about_screen.dart) | 167 | — | 1 | Pantalla estática, pero con el **peor contraste medido de la fase**: el copyright da **2,61:1** por aplicar `alpha: 0.7` sobre `textSecondary`. La tarjeta mide **1392 px a 1440**. `setState` tras `await` sin `mounted`. | `maxReadingWidth`. Quitar la opacidad, no bajarla. Buena primera tarea de pantalla. |
| [onboarding_screen.dart](../../../lib/features/onboarding/presentation/pages/onboarding_screen.dart) | 449 | — | **0** | **Lanza `BoxConstraints has non-normalized height` en cualquier teléfono girado** (alto < 500 px): su `ConstrainedBox` calcula `maxHeight: alto*0.4` con `minHeight: 200` fijo. Desborda 24 px a 320. Panel clavado en **280 px a cualquier ancho**. Las **3 diapositivas comparten una URL de relleno** de `lh3.googleusercontent.com`, sin `errorWidget`. `PageController` sin `dispose`. | Arreglar la aserción primero. Panel a `maxReadingWidth`. Ilustración local o de design system, con estado de error. Se ve una vez → delight justificado. |
| [splash_screen.dart](../../../lib/features/splash/presentation/pages/splash_screen.dart) | 376 | 1 | **0** | **La animación no retrasa el arranque: *es* el arranque.** `Future.delayed(3 s)` fijo antes de comprobar nada, más hasta 5 s de sondeo — peor caso **8 s**. La barra de progreso es un tween de 3 s que no mide ninguna carga. En oscuro `“Auto”` da **1,65:1** y `“Doc”` 7,00:1. Desborda 92 px en vertical a 800×400. `..repeat()` hace que `pumpAndSettle` se cuelgue. | Eliminar la espera fija (400 ms de suelo anti-parpadeo). Progreso indeterminado, no falso. Nombre en `onPrimary`. |

> **Corregido el 2026-08-12 al escribir la Fase 7.** Cinco datos de esta tabla estaban mal medidos o describían algo que el código no hace, y el hallazgo principal no estaba recogido:
>
> 1. **La ruta de entrada desborda en `HEAD`, en los anchos donde vive el 100 % de los usuarios móviles.** Cinco de las seis pantallas desbordan. `profile_setup_screen` —por la que el router **obliga** a pasar a todo usuario nuevo— produce **dos `RenderFlex` en todo ancho de teléfono** y solo está limpia desde 600 px. Medido a ocho anchos. Ver [Fase 7 §0.1 y §0.2](2026-08-10-ui-ux-overhaul-07-entry-profile.md).
> 2. **`user_profile_screen` tiene 53 colores literales, no 33** — el conteo omitía los 17 `Color(0xFF…)`. Y **copió cinco valores de `AppPalette`** en vez de leerlos, así que la corrección de contraste de la Fase 1 Task 4 no le llegaría. Su migración de `responsive_framework` pertenece a la **Fase 2 Task 1**, que ya la declara entre sus ficheros.
> 3. **`profile_setup_screen` no es multi-paso** y **`login_screen.dart` no es una pantalla** (15 líneas, con un comentario que describe algo que no hace).
> 4. **Faltaban tres widgets** del módulo `auth`: `auth_background_blobs`, `auth_bottom_nav` y `auth_logo_section` (170 líneas, dos defectos de accesibilidad, y tres enlaces legales que solo muestran un `SnackBar` de relleno).
> 5. **`auth_screen` desborda a 320 px solo en inglés.** El equipo desarrolla en español y ahí el margen es de 3,5 píxeles. Toda tarea de esta fase verifica en los dos idiomas.

### 5.5 Módulo `admin` — Fase 8

| Pantalla | LOC | HC | Resp | Diagnóstico medido | Contrato objetivo |
|---|---|---|---|---|---|
| [admin_dashboard_screen.dart](../../../lib/features/admin/presentation/pages/admin_dashboard_screen.dart) | 493 | 4 | 22 | **El cuarto sistema de breakpoints de la app** (`MediaQuery…width`, cortes en 600 y 900, L221-222) y **se contradice a sí mismo a 600 px** (ver §3). `Colors.white` sobre el degradado de `primary` da **1,47:1 en oscuro**; el subtítulo al 80 %, **1,31:1**. Accesos rápidos de ~42 dp. El `RefreshIndicator` no espera a las métricas. | **Corregido:** son **6** KPIs, así que `AppGrid` **1/2/3/3** — con 4 columnas quedan dos huérfanos (mismo error que el maestro cometió con `mechanic_dashboard`). Una sola escala para métricas y gráficos. Texto del degradado a `colors.onPrimary`. |
| [admin_talleres_screen.dart](../../../lib/features/admin/presentation/pages/admin_talleres_screen.dart) | 504 | — | 6 | **Corregido:** los tres `220` están dentro de un **`Wrap`**, así que no desbordan; su defecto es que tampoco crecen. Lo que **sí** desborda es `TallerAdminCard` (**125+146 px a 320**, 70+91 a 375). Abre **un `StreamBuilder` de Firestore por fila**. Programa `setState` desde `build()`. ~15 cadenas sin localizar. Tiene test propio. | Grid 1/1/2/3 (no tabla: no existe ninguna, ver Fase 8 §0.4.1). Filtros con `min/maxWidth`. Cachear el stream por id. No romper `filtrarTalleres`. |
| [admin_usuarios_screen.dart](../../../lib/features/admin/presentation/pages/admin_usuarios_screen.dart) | 575 | 3 | 8 | `ElevatedButton(backgroundColor: Colors.red)` en la confirmación destructiva. Lista de una columna a cualquier ancho. | Grid **1/1/2/2** (no tabla). Botón destructivo con un par de contraste **medido** — `lightError` es `#FC8181`, blanco encima no llega a 3:1. |
| [admin_logs_screen.dart](../../../lib/features/admin/presentation/pages/admin_logs_screen.dart) | 524 | **11** | 15 | **Corregido:** los 11 literales **son** el semáforo por tipo de log, con un mapeo que **discrepa del que usa el dashboard para los mismos logs**. Chips de filtro de ~20 dp. Solo 2 usos de `context.l10n` en 524 líneas. | `AppSeverity.forLogAccion` como **única** definición de «acción grave», compartida con el dashboard. Una columna: un log es una línea de texto, no una tarjeta. |
| [admin_resenias_screen.dart](../../../lib/features/admin/presentation/pages/admin_resenias_screen.dart) | 332 | 3 | 8 | **1 solo uso de `context.l10n` en 332 líneas** — la pantalla menos localizada del módulo. | Grid de moderación 1/1/2/2. |
| [admin_seed_screen.dart](../../../lib/features/admin/presentation/pages/admin_seed_screen.dart) | 60 | 2 | 4 | Herramienta interna, 60 LOC. **Es la única de las seis sin `drawer`**: una vez dentro no hay forma de volver. Y su enlace en el cajón se ofrece siempre aunque en release responda «acceso denegado». | Tokenizar, **darle cajón**, y ocultar su enlace con `kDebugMode`. Mínimo esfuerzo justificado. |

> **Corregido el 2026-08-12 al escribir la Fase 8.** Cuatro puntos de esta tabla no describían lo que hace el código, y el hallazgo estructural del módulo no estaba recogido:
>
> 1. **El color de estado está reimplementado cuatro veces, con cuatro mapeos incompatibles** (`taller_admin_card`, `admin_logs_screen`, `account_row` y `admin_dashboard_screen`). Los dos últimos ya discrepan entre sí sobre el mismo log: el dashboard lo clasifica con tokens y `admin_logs` con cuatro colores literales de Material, así que **la misma acción se ve de dos colores en dos pantallas de la misma consola**. 31 de los 54 literales del módulo son eso. Lo cierra `AppSeverity` en la Fase 8 Task 1.
> 2. **No hay ni una `DataTable` en todo el módulo.** Esta tabla pedía «tabla» para tres pantallas; las tres son ya `ListView`/`SliverList` de tarjetas. Construir una sería **UI nueva**, no una refactorización — el mismo error de encuadre que con el stepper de `initiate_service` (§5.2) y el master-detail del chat (§5.3). Sustituido por grids.
> 3. **`TallerAdminCard` desborda dos veces en todos los teléfonos** (125+146 px a 320; 70+91 a 375; limpia desde 600), y es la tarjeta con la que se aprueba o rechaza un taller. Esta tabla no la inventariaba: **faltaban los 9 widgets del módulo**, que suman 1.231 líneas y **30 de los 54 colores literales**.
> 4. **El módulo llega con 34 tests en verde**, el mejor cubierto de la app — provider, servicio, repositorio, los tres gráficos y la función pura `filtrarTalleres`. Ninguno cubre layout ni accesibilidad. Ninguna tarea puede romperlos.

### 5.6 Resumen agregado

- **34 pantallas**, 33 rutas en [app_router.dart](../../../lib/core/router/app_router.dart), 5 de ellas dentro del `ShellRoute` que monta `MainScaffold`.
- **6 pantallas con cero responsividad:** `chat_screen`, `conversaciones_list_screen`, `reserva_detail_screen`, `notifications_screen`, `onboarding_screen`, `splash_screen`.
- **Solo 2 ficheros usan `LayoutBuilder`** en toda la app (`mechanic_dashboard_screen`, `onboarding_screen`). Esta es la causa raíz de que "responsivo" hoy signifique "el mismo layout un 15 % más grande".
- **~270 colores hardcodeados** repartidos en 25+ ficheros, contra la regla explícita de `CONVENTIONS.md` §2.1.
- **3 usos de `Semantics` en toda la app** (2 en `auth_screen`, 1 en `main.dart`). La app es prácticamente inaccesible por lector de pantalla.
- **0 usos de reduced-motion.** Ninguna animación consulta la preferencia del sistema.
- **~20 anchos fijos ≥ 100 px** dentro de layouts flexibles.

---

## 6. Estrategia de verificación

Cada tarea de cada fase termina verde en esta escalera antes de commitear:

1. `flutter test <ruta del test de la tarea>` — el test específico.
2. `flutter test` — suite completa (hay ~50 ficheros de test; ninguna tarea puede romperlos).
3. `flutter analyze` — sin issues nuevos.
4. `dart format .` + `dart fix --apply`.

Y al cerrar cada **fase**:

5. **Matriz de anchos.** Cada pantalla tocada se verifica a **320, 375, 600, 768, 840, 1024, 1200, 1440 px** mediante el helper `pumpAtWidth` de la Fase 1 Task 6. Los cuatro anchos de la checklist de `ui-ux-pro-max` (375/768/1024/1440) son el mínimo; 320 y los tres cortes de clase se añaden porque son donde rompe.
6. **Matriz de tema.** Cada pantalla tocada se verifica en light **y** dark de forma independiente.
7. **Reduced motion.** Se corre la suite con `disableAnimations: true` inyectado y no debe fallar ni quedarse colgada.
8. **Pre-Delivery Checklist** de `ui-ux-pro-max` `references/pro-rules.md`, ítem por ítem.
9. **`review-animations`** sobre el diff de la fase, si tocó motion.
10. `superpowers:requesting-code-review` sobre la rama de la fase.

**Nota honesta sobre golden tests:** el repo no tiene infraestructura de golden/pixel tests y no se añade en este plan. La verificación de layout es de *comportamiento y geometría* (aserciones sobre `tester.getSize`, `find.byType`, ausencia de `RenderFlex overflow`), no de píxeles. La verificación puramente visual es manual, con `flutter run -d chrome` redimensionando la ventana.

---

## 7. Protocolo para escribir las Fases 4–8

Las fases 1–3 están escritas y son ejecutables ya. Las fases 4–8 se escriben **una a la vez, justo antes de ejecutarse**, y no antes. Razón: cada plan de módulo necesita el detalle real de pantallas de 800–1400 líneas que no se puede especificar honestamente sin leerlas; escribirlas ahora produciría exactamente los placeholders que `superpowers:writing-plans` prohíbe. El contrato de cada pantalla ya está fijado en §5 — lo que falta es el código concreto, y ese sale de leer el fichero.

Para escribir el plan de la fase N:

1. `Skill(graphify)` — consultar qué consume el módulo y qué lo consume a él.
2. `Skill(find-animation-opportunities)` sobre `lib/features/<modulo>/` — obtener la lista de qué debe animar y qué no, con valores.
3. `Skill(ui-ux-pro-max:ui-ux-pro-max)` + `search.py "<tipo de pantalla>" --stack flutter` para cada arquetipo del módulo (lista, formulario, detalle, tabla, kanban).
4. Leer **completo** cada fichero de pantalla del módulo.
5. `Skill(superpowers:writing-plans)` — una tarea por pantalla, cada una con: test que falla (código real), comando de ejecución con el fallo esperado, implementación mínima (código real), comando de verificación, commit. Cada tarea debe cumplir el contrato de §5 para esa pantalla.
6. Guardar como `docs/superpowers/plans/2026-08-10-ui-ux-overhaul-0N-<modulo>.md`.

**Plantilla de tarea por pantalla** (a instanciar con el contenido real de cada pantalla):

```markdown
### Task N: <pantalla> — layout adaptativo, tokens y motion

**Files:**
- Modify: `lib/features/<mod>/presentation/pages/<pantalla>.dart`
- Test: `test/features/<mod>/presentation/pages/<pantalla>_responsive_test.dart`

**Interfaces:**
- Consumes: `WindowClass`, `AppBreakpoints.of(context)`, `AppPageBody`, `AppGrid` (Fase 1);
  `AppButton`, `AppCard` (Fase 3).
- Produces: nada público nuevo (refactor interno de la pantalla).

- [ ] Step 1: invocar `ui-ux-pro-max` y `emil-design-eng`; anotar los valores que confirman o corrigen el contrato de §5.
- [ ] Step 2: escribir el test responsivo que falla (3 anchos: 375 / 840 / 1440) — código real.
- [ ] Step 3: correr y confirmar el fallo exacto.
- [ ] Step 4: implementar el layout por `WindowClass` — código real.
- [ ] Step 5: correr y confirmar verde.
- [ ] Step 6: escribir el test de "cero colores hardcodeados" para el fichero y hacerlo pasar.
- [ ] Step 7: `dart format .`, `flutter analyze`, `flutter test`, commit.
```

---

## 8. Criterio de éxito global

La refactorización está terminada cuando:

- Las 34 pantallas renderizan sin overflow ni scroll horizontal a **320, 375, 600, 768, 840, 1024, 1200 y 1440 px**, en light y en dark.
- Las pantallas con contenido tabular o en grid **cambian de estructura** —no solo de escala— al cruzar 600, 840 y 1200 px.
- `grep -rn "Colors\.\(white\|black\|grey\|blue\|red\|green\|orange\|purple\)" lib/features lib/core/widgets` devuelve **cero** resultados fuera de `Colors.transparent`.
- `grep -rn "responsive_framework" lib/ pubspec.yaml` devuelve **cero** resultados.
- `MediaQuery.of(context).size.width` no aparece en `lib/features/**` para decisiones de layout.
- Todo control tappable mide ≥ 48×48 dp y tiene feedback de press visible en ≤ 160 ms.
- Todo control sin texto visible tiene `tooltip` o `Semantics.label`.
- Contraste ≥ 4.5:1 (cuerpo) y ≥ 3:1 (secundario) verificado por test en ambos temas.
- Con reduced motion activo la app es plenamente usable y no ejecuta animaciones de desplazamiento.
- `flutter analyze` limpio y la suite completa en verde.
- La marca es reconociblemente la misma: un usuario debe decir *"se siente mejor hecha"*, no *"la cambiaron"*.
