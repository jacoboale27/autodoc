# Design System Refresh (Fase 0) — Design Spec

**Status:** Approved by user (jacoboguirola@gmail.com), 2026-08-10.

## Contexto

AutoDoc es una app Flutter (Clean Architecture + Provider) con ~36 pantallas repartidas en 9 módulos (`admin`, `auth`, `chat`, `dashboard`, `mechanic`, `onboarding`, `profile`, `reviews`, `splash`). El usuario pidió "una vuelta de rueda al diseño" de toda la app usando las skills `ui-ux-pro-max` y las guías de `emil-kowalski` (polish/motion). Dado el tamaño (36 pantallas), este trabajo se decompone en sub-proyectos:

- **Fase 0 (este spec):** refresh de la base de design system (`lib/core/theme/` + `lib/core/widgets/`).
- **Fases 1..N (fuera de alcance de este spec):** un plan por módulo de pantallas (dashboard, mechanic, admin, auth/onboarding/profile, chat, reviews), que consumirán la base ya refinada. Se especifican en sesiones posteriores.

## Alcance de la Fase 0

**Tipo de cambio:** pulido visual/motion — se mantiene la UX y los flujos actuales, y se mantiene la identidad de marca (morado `#522C81` claro / teal `#81E6D9`, y sus inversos en dark mode). No se tocan pantallas (`lib/features/**`), solo `lib/core/theme/` y `lib/core/widgets/`.

**Ya existe y NO se rediseña desde cero:** `AppColors` (ThemeExtension), `AppSpacing`, `AppRadius`, `AppTextStyles` (Google Fonts Inter, escala Material3 completa), `AppTheme` (light/dark ThemeData). Estos tokens están bien resueltos y quedan intactos salvo lo indicado abajo.

### Gaps identificados (motivación del refresh)

Revisando `lib/core/theme/*.dart` y `lib/core/widgets/*.dart`:

1. `AppTransitions` (`lib/core/theme/app_transitions.dart`) solo define 3 duraciones y 3 curvas básicas (`easeInOut`, `decelerate`, `easeIn`). No hay curva "spring"/emphasized ni constantes de escala para press-feedback — necesarias para que botones/cards se sientan físicos (principio central de emil-kowalski: el motion debe responder al toque, no solo decorar).
2. `AppButton` (`lib/core/widgets/app_button.dart:173-193`) fija `elevation: 0` en el `ElevatedButton.styleFrom`, lo cual anula el `shadowColor` que se configura en la misma llamada — la sombra nunca se renderiza. Tampoco hay press-scale ni estado hover (la app corre también en web/desktop vía Flutter web).
3. `AppCard` (`lib/core/widgets/app_card.dart`) usa `InkWell` para el ripple pero no tiene hover lift ni press-scale cuando `onTap` está presente.
4. `AppShadows` (`lib/core/theme/app_shadows.dart`) solo define elevación "resting" (sm/md/lg light+dark). No hay variante para estado hover.
5. Componentes restantes (`AppSkeleton`, `AppSnackbar`, `AppStatusBadge`, `AppBottomNavBar`, `AppTopNavBar`, `NotificationBellButton`, `AnimatedCounter`, `AppEmptyState`) usan curvas/duraciones ad hoc en vez de una fuente única (p.ej. `AppSkeleton` usa el shimmer por defecto del paquete `shimmer`, `AnimatedCounter` usa `Curves.easeOut` hardcodeado).

## Diseño

### Tokens nuevos/extendidos

**`AppMotion`** (nuevo archivo, `lib/core/theme/app_motion.dart`): centraliza el lenguaje de movimiento.
- Reutiliza las duraciones de `AppTransitions` (no se duplican) y añade:
  - `spring` — un `Curve` tipo overshoot/emphasized (`Curves.easeOutBack` o equivalente) para entradas que deben sentirse "vivas" (p.ej. aparición de un snackbar, un contador).
  - `pressedScale` (`double`, ej. `0.96`) y `pressDuration` (`Duration`, ej. `100ms`) — constantes para el press-feedback de superficies tappables.
  - `hoverScale` (`double`, ej. `1.02`) y `hoverDuration` — para el lift en hover (solo tiene efecto visible en web/desktop; en touch no pasa nada porque no hay evento hover).

**`AppShadows`**: se agregan `lightHover` y `darkHover` (entre `md` y `lg` en intensidad), para el lift en hover de `AppCard`/`AppButton`.

**`AppColors`**: se agregan **getters derivados** en la propia clase (no campos nuevos en la `ThemeExtension`, para no tocar `copyWith`/`lerp` ni las instancias light/dark):
- `Color get hoverOverlay => primary.withValues(alpha: 0.06)`
- `Color get pressedOverlay => primary.withValues(alpha: 0.12)`

Esto evita expandir el esquema de la ThemeExtension (que requeriría actualizar `copyWith`, `lerp` y las dos instancias light/dark) para algo que es puramente derivado del color `primary` ya existente.

### Componentes

**`AppButton`:** 
- Arreglar el shadow roto: envolver el contenido en un `AnimatedContainer`/`DecoratedBox` con `AppShadows` real en vez de depender de `ElevatedButton.elevation`.
- Envolver en `GestureDetector` (`onTapDown`/`onTapUp`/`onTapCancel`) + `AnimatedScale` usando `AppMotion.pressedScale`/`pressDuration`, sin romper el `onPressed`/haptic actual.
- Envolver en `MouseRegion` para aplicar hover lift (`AppMotion.hoverScale` + `AppShadows.lightHover`/`darkHover`) solo cuando `kIsWeb || Platform desktop` — usar `Theme.of(context).platform` o simplemente aplicar siempre el `MouseRegion` (no tiene costo en touch, simplemente no dispara `onEnter`).

**`AppCard`:**
- Si `onTap != null`: mismo patrón de press-scale (`AppMotion`) y hover lift (`AppShadows` hover variant) que `AppButton`. Si `onTap == null`, sin cambios de comportamiento interactivo (sigue siendo una superficie estática).

**`AppTextField`:** revisado — Flutter's `InputDecorator` ya anima internamente la transición de color/grosor del borde al enfocar (comportamiento nativo de Material, ~200ms). No hay gap real aquí; se descarta del alcance (evita duplicar una animación que el framework ya resuelve).

**`AnimatedCounter`:** es el único componente restante con una curva propia hardcodeada (`Curves.easeOut` en `lib/core/widgets/animated_counter.dart:36,48`, fuera de cualquier token). Se reemplaza por `AppTransitions.defaultCurve` para que no haya una segunda fuente de verdad de curvas.

**Resto de componentes** (`AppSkeleton`, `AppSnackbar`, `AppStatusBadge`, `AppBottomNavBar`, `AppTopNavBar`, `NotificationBellButton`, `AppEmptyState`): revisados — no tienen curvas/duraciones propias que consolidar (son estáticos o delegan su animación a un paquete externo como `shimmer`, o al mecanismo nativo de `SnackBar`/`NavigationBar`). Quedan **fuera de alcance** de la Fase 0; no se les agrega motion nuevo porque no hay un gap concreto que lo justifique (YAGNI) — cualquier necesidad real de motion ahí se evaluará en las fases por módulo, en el contexto de la pantalla que los usa.

### Fuera de alcance (explícito)

- No se tocan `lib/features/**` (pantallas).
- No se cambia la paleta de colores ni la tipografía.
- No se tocan `AppSpacing`, `AppRadius`, `AppTextStyles`, `AppTheme` (estructura general del `ThemeData`) más allá de lo ya descrito.
- No se agregan golden tests de pixel (no hay infraestructura para eso en el repo); se usan widget tests de comportamiento.

## Testing

No existen golden tests en el repo (`test/` solo tiene `widget_test.dart` genérico). Para cada componente modificado con nueva interacción (press-scale, hover, foco animado), TDD con widget tests de **comportamiento**, no de píxeles:

- `AppButton`: test que hace `tester.startGesture` (tapDown) y verifica que el `AnimatedScale` alcanza `AppMotion.pressedScale`; al soltar (tapUp) vuelve a `1.0`.
- `AppCard` (con `onTap`): mismo patrón; y un test que confirma que sin `onTap` no existe `AnimatedScale` (sigue siendo estático).
- `AnimatedCounter`: test que verifica que la `CurvedAnimation` usa `AppTransitions.defaultCurve`.

Verificación final de la fase:
1. `flutter analyze` sin warnings nuevos.
2. `dart format .` (regla del proyecto, `CONVENTIONS.md` §4).
3. Todos los tests existentes + los nuevos pasan.
4. Corrida manual con `flutter run -d chrome` sobre `dashboard_screen` y `user_profile_screen` (alto uso de `AppButton`/`AppCard`) para confirmar que no hay regresión visual — captura de pantalla antes/después.

## Criterio de éxito

- `AppMotion` existe y es la única fuente de curvas/duraciones de interacción para los widgets de `lib/core/widgets/`.
- `AppButton` y `AppCard` responden visualmente a press (scale) y, en web/desktop, a hover (lift).
- El shadow de `AppButton` se renderiza correctamente (bug fix).
- Cero regresiones: todos los tests pasan, `flutter analyze` limpio, las 36 pantallas (que consumen estos widgets) siguen compilando y renderizando sin cambios de layout no intencionados.
- La marca (colores, tipografía) es visualmente idéntica a antes — un usuario no debería notar "rediseño", sino "se siente más pulido".

## Roadmap posterior (no parte de este plan)

Fases 1..N — un plan de implementación por módulo de pantallas, reutilizando `AppMotion`/`AppShadows` hover/`AppColors` overlays ya construidos aquí. Orden sugerido (a confirmar con el usuario cuando se brainstorm cada fase): `dashboard` (más usado) → `mechanic` → `profile`/`auth`/`onboarding` → `chat` → `admin`/`reviews` (menor tráfico).
