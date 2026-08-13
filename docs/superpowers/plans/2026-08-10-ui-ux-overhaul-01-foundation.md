# Fase 1 — Foundation (tokens, breakpoints, motion, harness) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: usa `superpowers:subagent-driven-development` (recomendado) o `superpowers:executing-plans` para ejecutar este plan tarea por tarea. Los pasos usan checkbox (`- [ ]`).
>
> **REQUIRED DESIGN SKILLS:** antes de las Tasks 2, 3 y 5 invoca `Skill(emil-design-eng)` y `Skill(ui-ux-pro-max:ui-ux-pro-max)`. Antes de la Task 1 y 5 corre además:
> `python "C:/Users/User/.claude/plugins/cache/ui-ux-pro-max-skill/ui-ux-pro-max/2.13.0/.claude/skills/ui-ux-pro-max/scripts/search.py" "responsive layout breakpoints adaptive navigation" --stack flutter`
> Los valores concretos de abajo (`pressedScale = 0.97`, curvas `Cubic(...)`, breakpoints 600/840/1200) ya vienen de esas skills; el trabajo del ejecutor es **verificarlos contra la skill**, no re-derivarlos desde cero. Si alguna skill sugiere un valor mejor fundamentado, cámbialo y anota el porqué en el commit.
>
> **CONTEXTO OBLIGATORIO:** lee `docs/superpowers/plans/2026-08-10-ui-ux-overhaul-00-master.md` §2 (Global Constraints) y §3 (window size classes) antes de empezar. Todas sus restricciones aplican a cada tarea de este plan.

**Goal:** Construir la base tokenizada de la que dependen las 7 fases restantes: una única escala de breakpoints (`WindowClass`), un lenguaje de motion (`AppMotion`), las variantes de sombra que faltan, el arreglo del único fallo de contraste WCAG medido, dos primitivas de layout adaptativo (`AppPageBody`, `AppGrid`) y el harness de tests responsivos que verificará las 34 pantallas.

**Architecture:** Todo son ficheros nuevos en `lib/core/theme/` y `lib/core/widgets/` más helpers de test en `test/support/`. La única modificación a código existente es un cambio de una constante de color (`AppPalette.lightTextSecondary`) y la reimplementación de `Responsive.isMobile/isTablet/isDesktop` para que deleguen en `AppBreakpoints` — sin cambiar sus cortes, de modo que **ninguna pantalla cambia de comportamiento en esta fase**. Es una fase puramente aditiva: al terminar, la app se ve igual salvo un gris secundario ligeramente más oscuro en light mode.

**Tech Stack:** Flutter 3.41.6 (Material 3), Dart SDK ^3.11.4 (switch expressions disponibles). Sin dependencias nuevas.

## Global Constraints

Heredadas de `...-00-master.md` §2. Las que muerden en esta fase concretamente:

- No se modifican valores de `AppPalette` **salvo** `lightTextSecondary` en la Task 4, que mide 4.42:1 contra `lightSurface` y falla WCAG AA 4.5:1.
- No se cambia la familia tipográfica (Inter vía `google_fonts`).
- No se toca ninguna pantalla de `lib/features/**` en esta fase.
- `dart format .` y `dart fix --apply` antes de cada commit; `flutter analyze` sin issues nuevos.
- Lints activos: `avoid_print`, `prefer_const_constructors`, `require_trailing_commas`.
- Un commit por tarea, formato `feat(scope):` / `fix(scope):` / `refactor(scope):`.

## File Structure

| Fichero | Responsabilidad | Estado |
|---|---|---|
| `lib/core/theme/app_breakpoints.dart` | `WindowClass` + cortes + gutters + anchos máximos. Única fuente de verdad de tamaño de ventana. | Crear (Task 1) |
| `lib/core/theme/app_motion.dart` | Curvas, duraciones, escalas de press/hover, stagger, helpers de reduced-motion. | Crear (Task 2) |
| `lib/core/theme/app_shadows.dart` | Añadir `lightHover` / `darkHover`. | Modificar (Task 3) |
| `lib/core/theme/app_colors.dart` | Arreglar `lightTextSecondary`; añadir getters `hoverOverlay` / `pressedOverlay`. | Modificar (Task 4) |
| `lib/core/widgets/app_page_body.dart` | Gutter + ancho máximo de contenido por `WindowClass`. | Crear (Task 5) |
| `lib/core/widgets/app_grid.dart` | Grid con nº de columnas por `WindowClass`. | Crear (Task 5) |
| `lib/core/utils/responsive.dart` | Delegar `isMobile/isTablet/isDesktop` en `AppBreakpoints`; deprecar. | Modificar (Task 6) |
| `test/support/contrast.dart` | Cálculo de ratio de contraste WCAG 2.1 con compositing de alfa. | Crear (Task 4) |
| `test/support/responsive_harness.dart` | `pumpAtWidth`, `kAuditWidths`, `expectNoOverflow`. | Crear (Task 7) |
| `test/core/theme/no_hardcoded_colors_test.dart` | Guardia anti-regresión de colores literales, con allowlist creciente por fase. | Crear (Task 8) |

Cada fichero tiene una responsabilidad y se puede sostener entero en contexto. `AppBreakpoints` y `AppMotion` van en `theme/` (son tokens, no utilidades) para que su import sea el mismo que el del resto del design system.

---

### Task 1: `AppBreakpoints` y `WindowClass`

**Files:**
- Create: `lib/core/theme/app_breakpoints.dart`
- Test: `test/core/theme/app_breakpoints_test.dart`

**Interfaces:**
- Consumes: nada.
- Produces: `enum WindowClass { compact, medium, expanded, large }`; `AppBreakpoints.fromWidth(double) -> WindowClass`; `AppBreakpoints.of(BuildContext) -> WindowClass`; `AppBreakpoints.gutter(WindowClass) -> double`; constantes `AppBreakpoints.medium/expanded/large` (`double`), `AppBreakpoints.maxContentWidth/maxReadingWidth/maxFormWidth` (`double`); extensión `WindowClassX` con `isCompact`, `isAtLeastMedium`, `isAtLeastExpanded`, `isLarge` (`bool`). Consumido por Tasks 5, 6, 7 y por **todas** las fases posteriores.

- [ ] **Step 1: Invocar las skills de diseño**

Ejecuta `Skill(ui-ux-pro-max:ui-ux-pro-max)` y luego:

```bash
python "C:/Users/User/.claude/plugins/cache/ui-ux-pro-max-skill/ui-ux-pro-max/2.13.0/.claude/skills/ui-ux-pro-max/scripts/search.py" "responsive layout breakpoints adaptive navigation" --stack flutter
```

Confirma dos cosas antes de codear: (a) su guideline "Use LayoutBuilder for responsive — Do: LayoutBuilder for adaptive layouts / Don't: Fixed sizes for responsive", que es por qué `AppBreakpoints.fromWidth` toma un `double` (para poder alimentarlo desde `constraints.maxWidth`, no solo desde `MediaQuery`); (b) los anchos de verificación 375/768/1024/1440 de su Pre-Delivery Checklist, que caen respectivamente en `compact`/`medium`/`expanded`/`large` con los cortes de abajo — es decir, los cuatro anchos que la skill exige verificar ejercitan las cuatro clases, una cada uno.

- [ ] **Step 2: Escribir el test que falla**

```dart
// test/core/theme/app_breakpoints_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';

void main() {
  group('AppBreakpoints.fromWidth', () {
    test('mapea cada frontera a su window class', () {
      expect(AppBreakpoints.fromWidth(320), WindowClass.compact);
      expect(AppBreakpoints.fromWidth(375), WindowClass.compact);
      expect(AppBreakpoints.fromWidth(599.9), WindowClass.compact);
      expect(AppBreakpoints.fromWidth(600), WindowClass.medium);
      expect(AppBreakpoints.fromWidth(768), WindowClass.medium);
      expect(AppBreakpoints.fromWidth(839.9), WindowClass.medium);
      expect(AppBreakpoints.fromWidth(840), WindowClass.expanded);
      expect(AppBreakpoints.fromWidth(1024), WindowClass.expanded);
      expect(AppBreakpoints.fromWidth(1199.9), WindowClass.expanded);
      expect(AppBreakpoints.fromWidth(1200), WindowClass.large);
      expect(AppBreakpoints.fromWidth(1440), WindowClass.large);
    });

    test('los 4 anchos de la checklist de ui-ux-pro-max cubren las 4 clases', () {
      final classes = [375.0, 768.0, 1024.0, 1440.0]
          .map(AppBreakpoints.fromWidth)
          .toList();
      expect(classes, WindowClass.values);
    });
  });

  group('AppBreakpoints.gutter', () {
    test('crece monotónicamente con la clase de ventana', () {
      final gutters = WindowClass.values.map(AppBreakpoints.gutter).toList();
      expect(gutters, [16.0, 24.0, 32.0, 40.0]);
      for (var i = 1; i < gutters.length; i++) {
        expect(gutters[i], greaterThan(gutters[i - 1]));
      }
    });
  });

  group('WindowClassX', () {
    test('los helpers de umbral son inclusivos hacia arriba', () {
      expect(WindowClass.compact.isCompact, isTrue);
      expect(WindowClass.medium.isCompact, isFalse);

      expect(WindowClass.compact.isAtLeastMedium, isFalse);
      expect(WindowClass.medium.isAtLeastMedium, isTrue);
      expect(WindowClass.expanded.isAtLeastMedium, isTrue);
      expect(WindowClass.large.isAtLeastMedium, isTrue);

      expect(WindowClass.medium.isAtLeastExpanded, isFalse);
      expect(WindowClass.expanded.isAtLeastExpanded, isTrue);
      expect(WindowClass.large.isAtLeastExpanded, isTrue);

      expect(WindowClass.expanded.isLarge, isFalse);
      expect(WindowClass.large.isLarge, isTrue);
    });
  });

  group('AppBreakpoints.of', () {
    testWidgets('lee el ancho del MediaQuery ambiente', (tester) async {
      late WindowClass observed;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(900, 600)),
          child: Builder(
            builder: (context) {
              observed = AppBreakpoints.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(observed, WindowClass.expanded);
    });
  });
}
```

- [ ] **Step 3: Correr el test y confirmar que falla**

Run: `flutter test test/core/theme/app_breakpoints_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'autodoc/core/theme/app_breakpoints.dart'` (el fichero no existe).

- [ ] **Step 4: Escribir la implementación mínima**

```dart
// lib/core/theme/app_breakpoints.dart
import 'package:flutter/widgets.dart';

/// Clase de ventana según el ancho disponible, alineada a las window size
/// classes de Material 3.
///
/// Es la **única** fuente de verdad de tamaño en AutoDoc. Antes convivían dos
/// escalas contradictorias (`Responsive` con corte en 1200 y
/// `responsive_framework` con corte en 800), lo que hacía que a 900px una
/// pantalla se dibujara como desktop mientras el shell seguía en modo móvil.
enum WindowClass {
  /// < 600 — teléfono en vertical. Navegación inferior, 1 columna.
  compact,

  /// 600–839 — teléfono en horizontal o tablet en vertical. Rail colapsado.
  medium,

  /// 840–1199 — tablet en horizontal o laptop pequeño. Rail extendido.
  expanded,

  /// >= 1200 — desktop. Top nav o sidebar, contenido acotado y centrado.
  large,
}

class AppBreakpoints {
  AppBreakpoints._();

  // ── Cortes (ancho lógico en dp) ──
  static const double medium = 600;
  static const double expanded = 840;
  static const double large = 1200;

  // ── Anchos máximos de contenido ──

  /// Ancho máximo del contenido general en pantallas grandes.
  static const double maxContentWidth = 1200;

  /// Ancho máximo para texto corrido (regla de "readable text measure":
  /// un párrafo de borde a borde en una tablet es ilegible).
  static const double maxReadingWidth = 720;

  /// Ancho máximo para formularios centrados.
  static const double maxFormWidth = 560;

  /// Clase de ventana para un ancho dado.
  ///
  /// Toma un `double` en vez de un `BuildContext` para poder alimentarse desde
  /// `LayoutBuilder`: dentro de un split view el ancho del panel no es el de la
  /// pantalla, y decidir con `MediaQuery` daría el layout equivocado.
  static WindowClass fromWidth(double width) {
    if (width >= large) return WindowClass.large;
    if (width >= expanded) return WindowClass.expanded;
    if (width >= medium) return WindowClass.medium;
    return WindowClass.compact;
  }

  /// Clase de ventana del `MediaQuery` ambiente.
  ///
  /// Úsalo solo para decisiones a nivel de pantalla completa (shell,
  /// navegación). Para contenido dentro de un panel usa
  /// `LayoutBuilder` + [fromWidth].
  static WindowClass of(BuildContext context) =>
      fromWidth(MediaQuery.sizeOf(context).width);

  /// Padding horizontal del contenido para cada clase de ventana.
  static double gutter(WindowClass windowClass) => switch (windowClass) {
    WindowClass.compact => 16,
    WindowClass.medium => 24,
    WindowClass.expanded => 32,
    WindowClass.large => 40,
  };
}

extension WindowClassX on WindowClass {
  bool get isCompact => this == WindowClass.compact;
  bool get isLarge => this == WindowClass.large;
  bool get isAtLeastMedium => index >= WindowClass.medium.index;
  bool get isAtLeastExpanded => index >= WindowClass.expanded.index;
}
```

- [ ] **Step 5: Correr el test y confirmar que pasa**

Run: `flutter test test/core/theme/app_breakpoints_test.dart`
Expected: PASS (5 tests)

- [ ] **Step 6: Verificar que no se rompió nada**

Run: `dart format . && flutter analyze && flutter test`
Expected: `analyze` sin issues nuevos; suite completa en verde.

- [ ] **Step 7: Commit**

```bash
git add lib/core/theme/app_breakpoints.dart test/core/theme/app_breakpoints_test.dart
git commit -m "feat(theme): add WindowClass breakpoint scale as single source of truth"
```

---

### Task 2: `AppMotion` — curvas, duraciones y reduced motion

**Files:**
- Create: `lib/core/theme/app_motion.dart`
- Test: `test/core/theme/app_motion_test.dart`

**Interfaces:**
- Consumes: nada.
- Produces: `AppMotion.easeOut` / `easeInOut` / `drawer` (`Curve`); `AppMotion.press` / `hover` / `tooltip` / `dropdown` / `sheetEnter` / `sheetExit` (`Duration`); `AppMotion.pressedScale` / `hoverScale` (`double`); `AppMotion.staggerStep` (`Duration`), `AppMotion.staggerMaxItems` (`int`); `AppMotion.reduced(BuildContext) -> bool`; `AppMotion.transformDuration(BuildContext, Duration) -> Duration`; `AppMotion.pressScaleFor(BuildContext) -> double`; `AppMotion.hoverScaleFor(BuildContext) -> double`. Consumido por la Fase 2 (transiciones del shell), la Fase 3 (`AppButton`, `AppCard`) y todas las fases de pantallas.

- [ ] **Step 1: Invocar la skill de motion**

Ejecuta `Skill(emil-design-eng)`. Los valores de abajo salen literalmente de su framework de decisión; verifícalos contra la skill antes de escribirlos:

- Curvas custom en vez de las built-in: `--ease-out: cubic-bezier(0.23, 1, 0.32, 1)`, `--ease-in-out: cubic-bezier(0.77, 0, 0.175, 1)`, `--ease-drawer: cubic-bezier(0.32, 0.72, 0, 1)`. Motivo: *"The built-in CSS easings are too weak. They lack the punch that makes animations feel intentional."* En Flutter el equivalente de `cubic-bezier(a,b,c,d)` es `Cubic(a,b,c,d)`.
- Duraciones: button press 100–160 ms, tooltips/popovers 125–200 ms, dropdowns 150–250 ms, modales/drawers 200–500 ms, y regla dura *"UI animations should stay under 300ms"*.
- `scale(0.97)` en `:active` para todo elemento presionable; el rango aceptable es 0.95–0.98.
- *"Make exit faster than enter"* → `sheetExit` (200 ms) < `sheetEnter` (300 ms).
- Stagger de 30–80 ms entre elementos.
- **Nunca `ease-in` para UI**: *"It starts slow, which makes the interface feel sluggish"*. Por eso no existe ninguna constante `easeIn` en `AppMotion` — `AppTransitions.accelerate` (`Curves.easeIn`) queda como legado y no se usa en código nuevo.

**Adaptación explícita a Flutter (documentar en el commit):** la skill exige envolver los estados de hover en `@media (hover: hover) and (pointer: fine)` porque en CSS el `:hover` se queda "pegado" tras un tap en táctil. En Flutter ese problema no existe: `MouseRegion` solo emite `onEnter`/`onExit` ante un puntero real, así que no hace falta la guarda. Se aplica el *espíritu* de la regla (el hover nunca puede ser la única forma de descubrir una acción), no su mecánica.

- [ ] **Step 2: Escribir el test que falla**

```dart
// test/core/theme/app_motion_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/theme/app_motion.dart';

void main() {
  group('curvas', () {
    test('easeOut arranca rápido: se siente inmediato al input', () {
      // A un 10% del tiempo ya recorrió más de un 30% del camino.
      expect(AppMotion.easeOut.transform(0.1), greaterThan(0.3));
      expect(AppMotion.easeOut.transform(1.0), closeTo(1.0, 0.001));
    });

    test('easeInOut arranca lento: es para movimiento ya visible en pantalla', () {
      expect(AppMotion.easeInOut.transform(0.1), lessThan(0.1));
      expect(AppMotion.easeInOut.transform(1.0), closeTo(1.0, 0.001));
    });

    test('drawer arranca rápido y desacelera largo', () {
      expect(AppMotion.drawer.transform(0.1), greaterThan(0.1));
      expect(AppMotion.drawer.transform(1.0), closeTo(1.0, 0.001));
    });
  });

  group('duraciones', () {
    test('toda micro-interacción se mantiene bajo 300ms', () {
      for (final duration in [
        AppMotion.press,
        AppMotion.hover,
        AppMotion.tooltip,
        AppMotion.dropdown,
      ]) {
        expect(duration.inMilliseconds, lessThan(300));
      }
    });

    test('la salida es más rápida que la entrada', () {
      expect(
        AppMotion.sheetExit.inMilliseconds,
        lessThan(AppMotion.sheetEnter.inMilliseconds),
      );
    });

    test('el paso de stagger está en el rango 30-80ms', () {
      expect(AppMotion.staggerStep.inMilliseconds, inInclusiveRange(30, 80));
    });
  });

  group('escalas de interacción', () {
    test('pressedScale es un encogimiento sutil (0.95-0.98)', () {
      expect(AppMotion.pressedScale, inInclusiveRange(0.95, 0.98));
    });

    test('hoverScale es un lift sutil', () {
      expect(AppMotion.hoverScale, greaterThan(1.0));
      expect(AppMotion.hoverScale, lessThan(1.05));
    });
  });

  group('reduced motion', () {
    Future<void> pumpWith(
      WidgetTester tester,
      bool disableAnimations,
      void Function(BuildContext) probe,
    ) async {
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: Builder(
            builder: (context) {
              probe(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    }

    testWidgets('sin reduced motion los valores pasan intactos', (tester) async {
      late bool reduced;
      late Duration duration;
      late double scale;

      await pumpWith(tester, false, (context) {
        reduced = AppMotion.reduced(context);
        duration = AppMotion.transformDuration(context, AppMotion.press);
        scale = AppMotion.pressScaleFor(context);
      });

      expect(reduced, isFalse);
      expect(duration, AppMotion.press);
      expect(scale, AppMotion.pressedScale);
    });

    testWidgets('con reduced motion se anula el movimiento', (tester) async {
      late bool reduced;
      late Duration duration;
      late double pressScale;
      late double hoverScale;

      await pumpWith(tester, true, (context) {
        reduced = AppMotion.reduced(context);
        duration = AppMotion.transformDuration(context, AppMotion.press);
        pressScale = AppMotion.pressScaleFor(context);
        hoverScale = AppMotion.hoverScaleFor(context);
      });

      expect(reduced, isTrue);
      expect(duration, Duration.zero);
      expect(pressScale, 1.0);
      expect(hoverScale, 1.0);
    });
  });
}
```

- [ ] **Step 3: Correr el test y confirmar que falla**

Run: `flutter test test/core/theme/app_motion_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'autodoc/core/theme/app_motion.dart'`.

- [ ] **Step 4: Escribir la implementación mínima**

```dart
// lib/core/theme/app_motion.dart
import 'package:flutter/widgets.dart';

/// Lenguaje de movimiento de AutoDoc: fuente única de curvas, duraciones y
/// escalas de interacción.
///
/// Las curvas son variantes "fuertes" de las estándar. Las built-in de Flutter
/// (`Curves.easeOut`, `Curves.easeInOut`) son demasiado suaves y hacen que el
/// movimiento se lea como accidental en vez de intencional.
///
/// No existe ninguna constante `easeIn`: una curva que arranca lenta retrasa el
/// movimiento justo en el instante en que el usuario está mirando, y hace que
/// la interfaz se sienta lenta aunque dure lo mismo.
///
/// Las duraciones "generales" de transición de página siguen viviendo en
/// [AppTransitions]; aquí vive todo lo que responde a una interacción.
class AppMotion {
  AppMotion._();

  // ── Curvas ──

  /// Entradas y respuestas directas a input. Arranca rápido.
  static const Curve easeOut = Cubic(0.23, 1, 0.32, 1);

  /// Movimiento o morph de un elemento ya visible en pantalla.
  static const Curve easeInOut = Cubic(0.77, 0, 0.175, 1);

  /// Sheets y drawers. Curva de Ionic; da la sensación de iOS.
  static const Curve drawer = Cubic(0.32, 0.72, 0, 1);

  // ── Duraciones ──

  static const Duration press = Duration(milliseconds: 160);
  static const Duration hover = Duration(milliseconds: 150);
  static const Duration tooltip = Duration(milliseconds: 150);
  static const Duration dropdown = Duration(milliseconds: 200);
  static const Duration sheetEnter = Duration(milliseconds: 300);

  /// Siempre más corta que [sheetEnter]: al cerrar, el usuario ya decidió;
  /// esperar la animación es fricción pura.
  static const Duration sheetExit = Duration(milliseconds: 200);

  // ── Escalas de interacción ──

  /// Encogimiento al presionar. Confirma que la interfaz "oyó" el toque.
  static const double pressedScale = 0.97;

  /// Lift al pasar el puntero (solo se dispara con puntero real).
  static const double hoverScale = 1.02;

  // ── Stagger ──

  /// Retardo entre elementos consecutivos al entrar una lista.
  static const Duration staggerStep = Duration(milliseconds: 50);

  /// Tope de elementos escalonados: más allá, el último tarda tanto en
  /// aparecer que la lista se siente lenta.
  static const int staggerMaxItems = 8;

  // ── Reduced motion ──

  /// `true` cuando el sistema pide reducir el movimiento.
  static bool reduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);

  /// Duración para animaciones de **transformación** (posición, escala).
  ///
  /// Con reduced motion activo devuelve [Duration.zero]. Las transiciones de
  /// opacidad y color NO deben pasar por aquí: reducir el movimiento significa
  /// menos desplazamiento, no ausencia total de transición — un cambio de
  /// estado instantáneo y sin cross-fade se lee como un glitch.
  static Duration transformDuration(BuildContext context, Duration value) =>
      reduced(context) ? Duration.zero : value;

  /// Escala de press efectiva: 1.0 (sin movimiento) con reduced motion.
  static double pressScaleFor(BuildContext context) =>
      reduced(context) ? 1.0 : pressedScale;

  /// Escala de hover efectiva: 1.0 (sin movimiento) con reduced motion.
  static double hoverScaleFor(BuildContext context) =>
      reduced(context) ? 1.0 : hoverScale;
}
```

- [ ] **Step 5: Correr el test y confirmar que pasa**

Run: `flutter test test/core/theme/app_motion_test.dart`
Expected: PASS (10 tests)

- [ ] **Step 6: Verificar que no se rompió nada**

Run: `dart format . && flutter analyze && flutter test`
Expected: verde.

- [ ] **Step 7: Commit**

```bash
git add lib/core/theme/app_motion.dart test/core/theme/app_motion_test.dart
git commit -m "feat(theme): add AppMotion tokens (custom curves, durations, reduced-motion helpers)"
```

---

### Task 3: `AppShadows` — variantes de hover

**Files:**
- Modify: `lib/core/theme/app_shadows.dart`
- Test: `test/core/theme/app_shadows_test.dart`

**Interfaces:**
- Consumes: nada.
- Produces: `AppShadows.lightHover` (`List<BoxShadow>`), `AppShadows.darkHover` (`List<BoxShadow>`). Consumido por la Fase 3 (`AppButton`, `AppCard`).

**Contexto:** hoy `AppShadows` solo define elevación en reposo (`sm`/`md`/`lg` × light/dark, ver [app_shadows.dart](../../../lib/core/theme/app_shadows.dart)). No hay ninguna variante para el estado hover, así que la Fase 3 no tendría a qué elevar una tarjeta cuando el puntero entra. `hover` se coloca entre `md` (blur 10, dy 4) y `lg` (blur 20, dy 10).

- [ ] **Step 1: Escribir el test que falla**

```dart
// test/core/theme/app_shadows_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/theme/app_shadows.dart';

void main() {
  test('lightHover cae entre lightMd y lightLg en intensidad', () {
    final hover = AppShadows.lightHover.first;
    final md = AppShadows.lightMd.first;
    final lg = AppShadows.lightLg.first;

    expect(hover.blurRadius, greaterThan(md.blurRadius));
    expect(hover.blurRadius, lessThan(lg.blurRadius));
    expect(hover.offset.dy, greaterThan(md.offset.dy));
    expect(hover.offset.dy, lessThan(lg.offset.dy));
    expect(hover.color.a, greaterThan(md.color.a));
    expect(hover.color.a, lessThan(lg.color.a));
  });

  test('darkHover cae entre darkMd y darkLg en intensidad', () {
    final hover = AppShadows.darkHover.first;
    final md = AppShadows.darkMd.first;
    final lg = AppShadows.darkLg.first;

    expect(hover.blurRadius, greaterThan(md.blurRadius));
    expect(hover.blurRadius, lessThan(lg.blurRadius));
    expect(hover.offset.dy, greaterThan(md.offset.dy));
    expect(hover.offset.dy, lessThan(lg.offset.dy));
  });
}
```

- [ ] **Step 2: Correr el test y confirmar que falla**

Run: `flutter test test/core/theme/app_shadows_test.dart`
Expected: FAIL — `The getter 'lightHover' isn't defined for the class 'AppShadows'`.

- [ ] **Step 3: Escribir la implementación mínima**

En `lib/core/theme/app_shadows.dart`, inserta `lightHover` justo después de `lightMd` y `darkHover` justo después de `darkMd`:

```dart
  /// Elevación en hover para superficies tappables (puntero real).
  /// Entre [lightMd] y [lightLg].
  static List<BoxShadow> lightHover = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.10),
      blurRadius: 14,
      offset: const Offset(0, 6),
    ),
  ];
```

```dart
  /// Elevación en hover para superficies tappables (puntero real).
  /// Entre [darkMd] y [darkLg].
  static List<BoxShadow> darkHover = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.35),
      blurRadius: 14,
      offset: const Offset(0, 6),
    ),
  ];
```

- [ ] **Step 4: Correr el test y confirmar que pasa**

Run: `flutter test test/core/theme/app_shadows_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: Verificar y commitear**

```bash
dart format . && flutter analyze && flutter test
git add lib/core/theme/app_shadows.dart test/core/theme/app_shadows_test.dart
git commit -m "feat(theme): add AppShadows hover elevation variants"
```

---

### Task 4: Contraste WCAG — arreglar `lightTextSecondary` y añadir overlays

**Files:**
- Create: `test/support/contrast.dart`
- Modify: `lib/core/theme/app_colors.dart`
- Test: `test/core/theme/app_colors_contrast_test.dart`

**Interfaces:**
- Consumes: nada.
- Produces: `contrastRatio(Color, Color) -> double`, `relativeLuminance(Color) -> double`, `composite(Color, Color) -> Color` (en `test/support/contrast.dart`, solo tests); getters `AppColors.hoverOverlay` y `AppColors.pressedOverlay` (`Color`). Consumido por la Fase 3 y por los tests de contraste de todas las fases.

**Hallazgo medido (esta es la única excepción a "no tocar la paleta"):**

| Par | Ratio | AA (4.5:1) |
|---|---|---|
| `lightTextSecondary` `#64748B` sobre `lightSurface` `#F7F6F8` | **4.42:1** | ❌ falla |
| `lightTextSecondary` `#64748B` sobre `lightSurfaceContainer` `#EEEDF0` | **4.08:1** | ❌ falla |
| `lightTextPrimary` `#0F172A` sobre `lightSurface` | 16.9:1 | ✅ |
| `darkTextSecondary` `white60` sobre `darkSurface` `#0F172A` | 7.13:1 | ✅ |
| `darkTextSecondary` `white60` sobre `darkSurfaceContainer` `#141E36` | 6.73:1 | ✅ |

Solo el gris secundario de light mode falla, y falla en las dos superficies. Se sustituye `#64748B` por **`#5B6B80`** — misma familia de tono (slate azulado, la marca se lee idéntica), un escalón más oscuro: **5.05:1** sobre `lightSurface` y **4.67:1** sobre `lightSurfaceContainer`. Dark mode no se toca.

Los getters `hoverOverlay`/`pressedOverlay` se añaden como **getters derivados de `primary`**, no como campos nuevos de la `ThemeExtension`: añadir campos obligaría a tocar `copyWith`, `lerp` y las dos instancias light/dark en `app_theme.dart` para algo que es puramente derivado.

- [ ] **Step 1: Crear el helper de contraste**

```dart
// test/support/contrast.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Compone [foreground] (posiblemente translúcido) sobre [background],
/// devolviendo el color opaco resultante.
///
/// Necesario porque tokens como `Colors.white60` tienen alfa 0.6: medir su
/// contraste sin componer primero da un resultado falso.
Color composite(Color foreground, Color background) {
  final alpha = foreground.a;
  return Color.from(
    alpha: 1.0,
    red: foreground.r * alpha + background.r * (1 - alpha),
    green: foreground.g * alpha + background.g * (1 - alpha),
    blue: foreground.b * alpha + background.b * (1 - alpha),
  );
}

double _linearize(double channel) => channel <= 0.03928
    ? channel / 12.92
    : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();

/// Luminancia relativa según WCAG 2.1.
double relativeLuminance(Color color) =>
    0.2126 * _linearize(color.r) +
    0.7152 * _linearize(color.g) +
    0.0722 * _linearize(color.b);

/// Ratio de contraste WCAG 2.1 entre [foreground] y [background].
///
/// Si [foreground] es translúcido se compone sobre [background] primero.
/// Devuelve un valor entre 1.0 (idénticos) y 21.0 (negro sobre blanco).
double contrastRatio(Color foreground, Color background) {
  final fg = relativeLuminance(composite(foreground, background));
  final bg = relativeLuminance(background);
  final lighter = math.max(fg, bg);
  final darker = math.min(fg, bg);
  return (lighter + 0.05) / (darker + 0.05);
}
```

- [ ] **Step 2: Escribir el test que falla**

```dart
// test/core/theme/app_colors_contrast_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/theme/app_colors.dart';

import '../../support/contrast.dart';

const double kAaBody = 4.5;
const double kAaLarge = 3.0;

void main() {
  group('el helper de contraste está calibrado', () {
    test('negro sobre blanco da 21:1 y un color contra sí mismo da 1:1', () {
      expect(contrastRatio(Colors.black, Colors.white), closeTo(21.0, 0.01));
      expect(contrastRatio(Colors.white, Colors.white), closeTo(1.0, 0.001));
    });
  });

  group('light mode', () {
    test('el texto primario pasa AA en ambas superficies', () {
      expect(
        contrastRatio(AppPalette.lightTextPrimary, AppPalette.lightSurface),
        greaterThanOrEqualTo(kAaBody),
      );
      expect(
        contrastRatio(
          AppPalette.lightTextPrimary,
          AppPalette.lightSurfaceContainer,
        ),
        greaterThanOrEqualTo(kAaBody),
      );
    });

    test('el texto secundario pasa AA en ambas superficies', () {
      expect(
        contrastRatio(AppPalette.lightTextSecondary, AppPalette.lightSurface),
        greaterThanOrEqualTo(kAaBody),
      );
      expect(
        contrastRatio(
          AppPalette.lightTextSecondary,
          AppPalette.lightSurfaceContainer,
        ),
        greaterThanOrEqualTo(kAaBody),
      );
    });

    test('onPrimary sobre primary pasa AA', () {
      expect(
        contrastRatio(AppPalette.lightOnPrimary, AppPalette.lightPrimary),
        greaterThanOrEqualTo(kAaBody),
      );
    });

    test('el outline es visible sobre la superficie (3:1 de glifo grande)', () {
      expect(
        contrastRatio(AppPalette.lightOutline, AppPalette.lightSurface),
        greaterThanOrEqualTo(1.3),
      );
    });
  });

  group('dark mode', () {
    test('el texto primario pasa AA en ambas superficies', () {
      expect(
        contrastRatio(AppPalette.darkTextPrimary, AppPalette.darkSurface),
        greaterThanOrEqualTo(kAaBody),
      );
      expect(
        contrastRatio(
          AppPalette.darkTextPrimary,
          AppPalette.darkSurfaceContainer,
        ),
        greaterThanOrEqualTo(kAaBody),
      );
    });

    test('el texto secundario pasa AA en ambas superficies', () {
      expect(
        contrastRatio(AppPalette.darkTextSecondary, AppPalette.darkSurface),
        greaterThanOrEqualTo(kAaBody),
      );
      expect(
        contrastRatio(
          AppPalette.darkTextSecondary,
          AppPalette.darkSurfaceContainer,
        ),
        greaterThanOrEqualTo(kAaBody),
      );
    });

    test('onPrimary sobre primary pasa AA', () {
      expect(
        contrastRatio(AppPalette.darkOnPrimary, AppPalette.darkPrimary),
        greaterThanOrEqualTo(kAaBody),
      );
    });
  });

  group('colores semánticos de estado', () {
    test('error, warning y success son distinguibles como glifo grande', () {
      for (final pair in [
        (AppPalette.lightError, AppPalette.lightSurface),
        (AppPalette.lightWarning, AppPalette.lightSurface),
        (AppPalette.lightSuccess, AppPalette.lightSurface),
        (AppPalette.darkError, AppPalette.darkSurface),
        (AppPalette.darkWarning, AppPalette.darkSurface),
        (AppPalette.darkSuccess, AppPalette.darkSurface),
      ]) {
        expect(
          contrastRatio(pair.$1, pair.$2),
          greaterThanOrEqualTo(kAaLarge),
          reason: 'el par ${pair.$1} sobre ${pair.$2} no llega a 3:1',
        );
      }
    });
  });

  group('overlays derivados', () {
    const colors = AppColors(
      primary: AppPalette.lightPrimary,
      secondary: AppPalette.lightSecondary,
      surface: AppPalette.lightSurface,
      surfaceContainer: AppPalette.lightSurfaceContainer,
      error: AppPalette.lightError,
      warning: AppPalette.lightWarning,
      success: AppPalette.lightSuccess,
      textPrimary: AppPalette.lightTextPrimary,
      textSecondary: AppPalette.lightTextSecondary,
      onPrimary: AppPalette.lightOnPrimary,
      onSecondary: AppPalette.lightOnSecondary,
      surfaceVariant: AppPalette.lightSurfaceVariant,
      outline: AppPalette.lightOutline,
      shimmerBase: AppPalette.lightShimmerBase,
      shimmerHighlight: AppPalette.lightShimmerHighlight,
    );

    test('derivan de primary y el de press es más fuerte que el de hover', () {
      expect(colors.hoverOverlay.a, closeTo(0.06, 0.001));
      expect(colors.pressedOverlay.a, closeTo(0.12, 0.001));
      expect(colors.pressedOverlay.a, greaterThan(colors.hoverOverlay.a));
      expect(colors.hoverOverlay.r, colors.primary.r);
      expect(colors.hoverOverlay.g, colors.primary.g);
      expect(colors.hoverOverlay.b, colors.primary.b);
    });
  });
}
```

- [ ] **Step 3: Correr el test y confirmar que falla**

Run: `flutter test test/core/theme/app_colors_contrast_test.dart`
Expected: FAIL con **dos** clases de error:
1. `The getter 'hoverOverlay' isn't defined for the class 'AppColors'` (error de compilación).
2. Tras añadir los getters, el test `el texto secundario pasa AA en ambas superficies` (light) falla con `Expected: a value greater than or equal to <4.5> / Actual: <4.418...>`.

Confirma **los dos** fallos antes de pasar al Step 4 — el segundo es el que justifica tocar la paleta.

- [ ] **Step 4: Escribir la implementación mínima**

4a. En `lib/core/theme/app_colors.dart`, sustituye la constante de `AppPalette`:

```dart
  // Antes: static const Color lightTextSecondary = Color(0xFF64748B);
  // 4.42:1 sobre lightSurface y 4.08:1 sobre lightSurfaceContainer — falla
  // WCAG AA. Un escalón más oscuro en la misma familia de tono: 5.05:1 y
  // 4.67:1 respectivamente.
  static const Color lightTextSecondary = Color(0xFF5B6B80);
```

4b. En la misma clase `AppColors`, añade los getters justo antes de la llave de cierre de la clase (después del `lerp`):

```dart
  /// Overlay derivado de [primary] para estado hover (puntero real).
  Color get hoverOverlay => primary.withValues(alpha: 0.06);

  /// Overlay derivado de [primary] para estado de press.
  Color get pressedOverlay => primary.withValues(alpha: 0.12);
```

- [ ] **Step 5: Correr el test y confirmar que pasa**

Run: `flutter test test/core/theme/app_colors_contrast_test.dart`
Expected: PASS (10 tests)

- [ ] **Step 6: Verificar que no se rompió ningún test de tema existente**

Run: `flutter test test/core/theme/`
Expected: verde, incluido el `theme_constants_test.dart` preexistente. Si ese test afirma el valor literal `0xFF64748B`, actualízalo al nuevo valor **y** añade en él un comentario apuntando a este plan; no lo borres.

Run: `dart format . && flutter analyze && flutter test`
Expected: verde.

- [ ] **Step 7: Commit**

```bash
git add lib/core/theme/app_colors.dart test/support/contrast.dart test/core/theme/app_colors_contrast_test.dart test/core/theme/theme_constants_test.dart
git commit -m "fix(theme): raise lightTextSecondary to WCAG AA and add interaction overlays

lightTextSecondary (#64748B) medía 4.42:1 sobre lightSurface y 4.08:1 sobre
lightSurfaceContainer, por debajo del 4.5:1 de WCAG AA para texto de cuerpo.
Sustituido por #5B6B80 (5.05:1 y 4.67:1). Dark mode ya cumplía y no se toca.

Añade test/support/contrast.dart, que mide el ratio real componiendo el alfa,
para que cualquier futuro cambio de paleta falle en CI si rompe AA."
```

---

### Task 5: Primitivas de layout adaptativo — `AppPageBody` y `AppGrid`

**Files:**
- Create: `lib/core/widgets/app_page_body.dart`
- Create: `lib/core/widgets/app_grid.dart`
- Test: `test/core/widgets/app_page_body_test.dart`
- Test: `test/core/widgets/app_grid_test.dart`

**Interfaces:**
- Consumes: `WindowClass`, `AppBreakpoints.fromWidth`, `AppBreakpoints.gutter`, `AppBreakpoints.maxContentWidth` (Task 1); `AppSpacing.base` (ya existe).
- Produces: `AppPageBody({required Widget child, double maxWidth = AppBreakpoints.maxContentWidth})`; `AppGrid({required List<Widget> children, int compactColumns = 1, int mediumColumns = 2, int expandedColumns = 3, int largeColumns = 4, double spacing = AppSpacing.base, double childAspectRatio = 1.0})` con método público `int columnsFor(WindowClass)`. Consumido por las Fases 2, 4, 5, 6, 7 y 8.

**Por qué estas dos y no más (YAGNI):** del inventario del plan maestro, los dos patrones que se repiten en las 34 pantallas son (a) "el contenido necesita gutter por clase y no debe estirarse de borde a borde en desktop" y (b) "esta rejilla debe tener N columnas según el ancho". Todo lo demás es específico de su pantalla y se resuelve con `LayoutBuilder` + `switch (windowClass)` allí mismo.

**Decisión de diseño clave:** ambos usan `LayoutBuilder` (`constraints.maxWidth`), **no** `MediaQuery`. En la Fase 2 el shell mete un `NavigationRail` a la izquierda; a partir de ahí el ancho disponible para el contenido ya no es el de la pantalla. Un `AppGrid` que decidiera por `MediaQuery` pondría 4 columnas en un panel de 900 px porque la ventana mide 1300. Esto es exactamente la guideline "Use LayoutBuilder for responsive → Respond to constraints" de `ui-ux-pro-max --stack flutter`.

- [ ] **Step 1: Invocar las skills de diseño**

`Skill(ui-ux-pro-max:ui-ux-pro-max)`. Verifica en `references/pro-rules.md` §Layout & Spacing: *"Adaptive gutters by breakpoint — Do: Increase horizontal insets on larger widths"*, *"Readable text measure — Don't: Full-width long text that hurts readability"*, y *"Consistent content width — Keep predictable content width per device class"*. Esas tres reglas son literalmente lo que `AppPageBody` implementa.

- [ ] **Step 2: Escribir los tests que fallan**

```dart
// test/core/widgets/app_page_body_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/core/widgets/app_page_body.dart';

void main() {
  Future<Size> pumpAndMeasure(
    WidgetTester tester,
    double width, {
    double maxWidth = AppBreakpoints.maxContentWidth,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: width,
            child: AppPageBody(
              maxWidth: maxWidth,
              child: Container(key: const Key('content')),
            ),
          ),
        ),
      ),
    );
    return tester.getSize(find.byKey(const Key('content')));
  }

  testWidgets('aplica el gutter de cada window class', (tester) async {
    // compact (375): gutter 16 a cada lado.
    expect((await pumpAndMeasure(tester, 375)).width, 375 - 16 * 2);
    // medium (768): gutter 24.
    expect((await pumpAndMeasure(tester, 768)).width, 768 - 24 * 2);
    // expanded (1024): gutter 32.
    expect((await pumpAndMeasure(tester, 1024)).width, 1024 - 32 * 2);
  });

  testWidgets('acota el contenido a maxWidth en pantallas grandes', (
    tester,
  ) async {
    // large (1600): se acota a maxContentWidth (1200) y luego gutter 40.
    final size = await pumpAndMeasure(tester, 1600);
    expect(size.width, AppBreakpoints.maxContentWidth - 40 * 2);
  });

  testWidgets('respeta un maxWidth de lectura más estrecho', (tester) async {
    final size = await pumpAndMeasure(
      tester,
      1440,
      maxWidth: AppBreakpoints.maxReadingWidth,
    );
    expect(size.width, AppBreakpoints.maxReadingWidth - 40 * 2);
  });

  testWidgets('decide por las constraints, no por el MediaQuery', (
    tester,
  ) async {
    // Ventana grande (1400) pero panel estrecho (500): debe usar el gutter
    // compact (16), no el large (40).
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              SizedBox(
                width: 500,
                child: AppPageBody(child: Container(key: const Key('panel'))),
              ),
              const Expanded(child: SizedBox()),
            ],
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byKey(const Key('panel'))).width, 500 - 16 * 2);
  });
}
```

```dart
// test/core/widgets/app_grid_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/core/widgets/app_grid.dart';

void main() {
  test('columnsFor devuelve la columna declarada para cada window class', () {
    const grid = AppGrid(
      children: [],
      compactColumns: 1,
      mediumColumns: 2,
      expandedColumns: 3,
      largeColumns: 4,
    );

    expect(grid.columnsFor(WindowClass.compact), 1);
    expect(grid.columnsFor(WindowClass.medium), 2);
    expect(grid.columnsFor(WindowClass.expanded), 3);
    expect(grid.columnsFor(WindowClass.large), 4);
  });

  Future<int> renderedColumns(WidgetTester tester, double width) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: width,
            child: AppGrid(
              children: List.generate(
                8,
                (i) => Container(key: ValueKey('cell$i')),
              ),
            ),
          ),
        ),
      ),
    );
    final delegate =
        tester.widget<GridView>(find.byType(GridView)).gridDelegate
            as SliverGridDelegateWithFixedCrossAxisCount;
    return delegate.crossAxisCount;
  }

  testWidgets('cambia el número de columnas al cruzar cada corte', (
    tester,
  ) async {
    expect(await renderedColumns(tester, 375), 1);
    expect(await renderedColumns(tester, 768), 2);
    expect(await renderedColumns(tester, 1024), 3);
    expect(await renderedColumns(tester, 1440), 4);
  });

  testWidgets('no desborda a 320px con 8 celdas', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: SingleChildScrollView(
              child: AppGrid(
                children: List.generate(8, (i) => Text('celda $i')),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 3: Correr los tests y confirmar que fallan**

Run: `flutter test test/core/widgets/app_page_body_test.dart test/core/widgets/app_grid_test.dart`
Expected: FAIL — `Couldn't resolve the package 'autodoc/core/widgets/app_page_body.dart'` y `.../app_grid.dart`.

- [ ] **Step 4: Escribir las implementaciones mínimas**

```dart
// lib/core/widgets/app_page_body.dart
import 'package:flutter/widgets.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';

/// Envuelve el contenido de una pantalla con el gutter horizontal de su
/// [WindowClass] y lo acota a un ancho máximo, centrado.
///
/// Resuelve tres reglas de una vez: gutters adaptativos por breakpoint, ancho
/// de contenido predecible por clase de dispositivo, y medida de lectura
/// legible (un párrafo de borde a borde en una tablet es ilegible).
///
/// Decide por `constraints.maxWidth`, no por `MediaQuery`: dentro de un split
/// view el ancho del panel no es el de la ventana.
class AppPageBody extends StatelessWidget {
  final Widget child;

  /// Ancho máximo del contenido. Usa [AppBreakpoints.maxReadingWidth] para
  /// texto corrido y [AppBreakpoints.maxFormWidth] para formularios.
  final double maxWidth;

  const AppPageBody({
    super.key,
    required this.child,
    this.maxWidth = AppBreakpoints.maxContentWidth,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gutter = AppBreakpoints.gutter(
          AppBreakpoints.fromWidth(constraints.maxWidth),
        );

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: gutter),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
```

```dart
// lib/core/widgets/app_grid.dart
import 'package:flutter/material.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/core/theme/app_spacing.dart';

/// Rejilla cuyo número de columnas se declara por [WindowClass].
///
/// Sustituye al patrón `crossAxisCount: isDesktop ? 4 : 2`, que salta de golpe
/// y deja sin tratamiento propio toda la franja 600–1199 px.
///
/// Decide por `constraints.maxWidth`, no por `MediaQuery`: en un panel de
/// 900 px dentro de una ventana de 1300 px deben salir las columnas de 900.
class AppGrid extends StatelessWidget {
  final List<Widget> children;
  final int compactColumns;
  final int mediumColumns;
  final int expandedColumns;
  final int largeColumns;
  final double spacing;
  final double childAspectRatio;

  const AppGrid({
    super.key,
    required this.children,
    this.compactColumns = 1,
    this.mediumColumns = 2,
    this.expandedColumns = 3,
    this.largeColumns = 4,
    this.spacing = AppSpacing.base,
    this.childAspectRatio = 1.0,
  });

  /// Columnas declaradas para [windowClass]. Público para poder testearlo sin
  /// montar el widget, y para que una pantalla pueda consultarlo al calcular
  /// alturas.
  int columnsFor(WindowClass windowClass) => switch (windowClass) {
    WindowClass.compact => compactColumns,
    WindowClass.medium => mediumColumns,
    WindowClass.expanded => expandedColumns,
    WindowClass.large => largeColumns,
  };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.count(
          crossAxisCount: columnsFor(
            AppBreakpoints.fromWidth(constraints.maxWidth),
          ),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          childAspectRatio: childAspectRatio,
          children: children,
        );
      },
    );
  }
}
```

- [ ] **Step 5: Correr los tests y confirmar que pasan**

Run: `flutter test test/core/widgets/app_page_body_test.dart test/core/widgets/app_grid_test.dart`
Expected: PASS (8 tests)

- [ ] **Step 6: Verificar y commitear**

```bash
dart format . && flutter analyze && flutter test
git add lib/core/widgets/app_page_body.dart lib/core/widgets/app_grid.dart test/core/widgets/app_page_body_test.dart test/core/widgets/app_grid_test.dart
git commit -m "feat(widgets): add AppPageBody and AppGrid adaptive layout primitives"
```

---

### Task 6: Reimplementar `Responsive` sobre `AppBreakpoints`

**Files:**
- Modify: `lib/core/utils/responsive.dart`
- Test: `test/core/utils/responsive_test.dart`

**Interfaces:**
- Consumes: `AppBreakpoints`, `WindowClass` (Task 1).
- Produces: la misma API pública de `Responsive` que ya existía (`isMobile`, `isTablet`, `isDesktop`, `fontSize`, `padding`, `iconSize`, `size`, `spacing`, `gridColumns`, `horizontalPadding`, `horizontalEdgeInsets`, `heroHeight`, `scaleFactor`), sin cambios de comportamiento. `isMobile`/`isTablet`/`isDesktop`/`gridColumns`/`horizontalPadding` quedan marcados `@Deprecated`.

**Por qué esta tarea existe:** hay **393 llamadas a `Responsive.*` repartidas en 30 ficheros**. Migrarlas todas ahora sería un cambio masivo y arriesgado en una fase que debe ser puramente aditiva. En su lugar, `Responsive` pasa a ser una **fachada** sobre `AppBreakpoints`: los cortes ya coinciden exactamente (`isMobile` < 600 = `compact`, `isTablet` 600–1199 = `medium`+`expanded`, `isDesktop` ≥ 1200 = `large`), así que la delegación es de comportamiento idéntico y verificable. A partir de aquí hay una sola fuente de verdad aunque haya dos APIs, y las fases 4–8 van sustituyendo llamadas pantalla por pantalla guiadas por el `@Deprecated`.

Los escaladores (`fontSize`, `padding`, `size`, `spacing`, `iconSize`, `heroHeight`) **no** se deprecan: siguen siendo válidos para ajuste fino de escala dentro de una misma estructura de layout. Lo que se depreca es usar `Responsive` para **decidir estructura**.

- [ ] **Step 1: Escribir el test que falla**

```dart
// test/core/utils/responsive_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/core/utils/responsive.dart';

void main() {
  Future<T> probeAt<T>(
    WidgetTester tester,
    double width,
    T Function(BuildContext) read,
  ) async {
    late T value;
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: Size(width, 900)),
        child: Builder(
          builder: (context) {
            value = read(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return value;
  }

  group('los predicados legacy coinciden exactamente con WindowClass', () {
    testWidgets('en los 8 anchos de auditoría', (tester) async {
      for (final width in [320.0, 375.0, 600.0, 768.0, 840.0, 1024.0, 1200.0, 1440.0]) {
        final expected = AppBreakpoints.fromWidth(width);

        final isMobile = await probeAt(tester, width, Responsive.isMobile);
        final isTablet = await probeAt(tester, width, Responsive.isTablet);
        final isDesktop = await probeAt(tester, width, Responsive.isDesktop);

        expect(isMobile, expected == WindowClass.compact, reason: 'isMobile @$width');
        expect(
          isTablet,
          expected == WindowClass.medium || expected == WindowClass.expanded,
          reason: 'isTablet @$width',
        );
        expect(isDesktop, expected == WindowClass.large, reason: 'isDesktop @$width');

        // Exactamente uno de los tres es verdadero: no hay huecos ni solapes.
        expect(
          [isMobile, isTablet, isDesktop].where((v) => v).length,
          1,
          reason: 'clases no exhaustivas/exclusivas @$width',
        );
      }
    });
  });

  group('los escaladores no cambian de comportamiento', () {
    testWidgets('fontSize devuelve la base en compact y como mucho x1.15', (
      tester,
    ) async {
      expect(await probeAt(tester, 375, (c) => Responsive.fontSize(c, 16)), 16.0);
      final atDesktop = await probeAt(
        tester,
        1440,
        (c) => Responsive.fontSize(c, 16),
      );
      expect(atDesktop, greaterThan(16.0));
      expect(atDesktop, lessThanOrEqualTo(16 * 1.15));
    });
  });
}
```

- [ ] **Step 2: Correr el test y confirmar que falla**

Run: `flutter test test/core/utils/responsive_test.dart`
Expected: FAIL — el test **compila y falla** en el import de `app_breakpoints.dart` solo si la Task 1 no está hecha. Si la Task 1 está hecha, este test **pasa en verde desde el principio** porque los cortes actuales ya coinciden. Eso es correcto y deseado: es un test de caracterización que blinda el comportamiento *antes* de refactorizar. Confírmalo en verde, y luego el Step 3 debe mantenerlo en verde.

- [ ] **Step 3: Refactorizar `Responsive` para delegar**

Sustituye el bloque de detección de dispositivo de `lib/core/utils/responsive.dart` (líneas 11–25) por:

```dart
  // ── Breakpoints ──
  //
  // Conservados solo por compatibilidad con las llamadas existentes. La fuente
  // de verdad es AppBreakpoints; estos valores se derivan de allí para que no
  // puedan divergir.
  static const double mobile = AppBreakpoints.medium;
  static const double tablet = AppBreakpoints.expanded;
  static const double desktop = AppBreakpoints.large;

  // ── Detección de dispositivo (legacy) ──

  @Deprecated(
    'Usa AppBreakpoints.of(context) == WindowClass.compact, o mejor '
    'LayoutBuilder + AppBreakpoints.fromWidth(constraints.maxWidth). '
    'Ver docs/superpowers/plans/2026-08-10-ui-ux-overhaul-00-master.md §3.',
  )
  static bool isMobile(BuildContext context) =>
      AppBreakpoints.of(context) == WindowClass.compact;

  @Deprecated(
    'Usa AppBreakpoints.of(context).isAtLeastMedium y .isAtLeastExpanded para '
    'distinguir las dos clases que este predicado mezcla. '
    'Ver docs/superpowers/plans/2026-08-10-ui-ux-overhaul-00-master.md §3.',
  )
  static bool isTablet(BuildContext context) {
    final windowClass = AppBreakpoints.of(context);
    return windowClass == WindowClass.medium ||
        windowClass == WindowClass.expanded;
  }

  @Deprecated(
    'Usa AppBreakpoints.of(context).isLarge. '
    'Ver docs/superpowers/plans/2026-08-10-ui-ux-overhaul-00-master.md §3.',
  )
  static bool isDesktop(BuildContext context) =>
      AppBreakpoints.of(context) == WindowClass.large;
```

Añade el import al principio del fichero:

```dart
import 'package:autodoc/core/theme/app_breakpoints.dart';
```

Y marca también los dos helpers estructurales:

```dart
  @Deprecated('Usa AppGrid, que declara columnas por WindowClass.')
  static int gridColumns(BuildContext context) { /* cuerpo sin cambios */ }

  @Deprecated('Usa AppPageBody, que aplica el gutter de AppBreakpoints.')
  static double horizontalPadding(BuildContext context) { /* cuerpo sin cambios */ }
```

- [ ] **Step 4: Correr el test y confirmar que sigue verde**

Run: `flutter test test/core/utils/responsive_test.dart`
Expected: PASS (2 tests). Si falla, la delegación cambió el comportamiento — arréglalo, no ajustes el test.

- [ ] **Step 5: Confirmar que los `@Deprecated` no rompen el analyze**

Run: `flutter analyze`
Expected: aparecen warnings `deprecated_member_use` en las ~30 pantallas que llaman a `isMobile`/`isTablet`/`isDesktop`/`gridColumns`/`horizontalPadding`. **Eso es intencional**: son exactamente el backlog de las fases 4–8. No los silencies con `// ignore:`. Anota el conteo en el mensaje de commit:

```bash
flutter analyze 2>&1 | grep -c "deprecated_member_use"
```

Si tu configuración de CI trata los warnings como error, y solo en ese caso, añade a `analysis_options.yaml`:

```yaml
analyzer:
  errors:
    deprecated_member_use: info
```

- [ ] **Step 6: Verificar la suite completa y commitear**

```bash
dart format . && flutter test
git add lib/core/utils/responsive.dart test/core/utils/responsive_test.dart
git commit -m "refactor(responsive): delegate Responsive predicates to AppBreakpoints and deprecate them

Los cortes coinciden exactamente (compact<600, medium+expanded 600-1199,
large>=1200), así que el comportamiento no cambia — hay un test de
caracterización sobre los 8 anchos de auditoría que lo blinda.

Los warnings de deprecated que aparecen en flutter analyze son el backlog de
migración de las fases 4-8, no ruido."
```

---

### Task 7: Harness de tests responsivos

**Files:**
- Create: `test/support/responsive_harness.dart`
- Test: `test/support/responsive_harness_test.dart`

**Interfaces:**
- Consumes: `AppTheme.light`, `AppTheme.dark` (ya existen).
- Produces: `const List<double> kAuditWidths`; `Future<void> pumpAtWidth(WidgetTester, Widget, {required double width, double height, Brightness brightness, bool disableAnimations})`; `void expectNoOverflow(WidgetTester)`; `Future<void> forEachAuditWidth(WidgetTester, Widget, Future<void> Function(double width))`. Consumido por **todas** las tareas de pantalla de las fases 2, 4, 5, 6, 7 y 8.

**Por qué es una tarea propia:** sin este harness, cada una de las ~34 tareas de pantalla reinventaría el montaje de viewport, y lo haría de forma sutilmente distinta (el error clásico es poner `MediaQuery` *fuera* de `MaterialApp`, donde queda sobreescrito por el que `MaterialApp` crea a partir de la `View`). Centralizarlo hace que la verificación de la matriz de anchos sea una línea por pantalla.

- [ ] **Step 1: Escribir el test que falla**

```dart
// test/support/responsive_harness_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';

import 'responsive_harness.dart';

void main() {
  test('kAuditWidths cubre las 4 window classes y los cortes exactos', () {
    expect(kAuditWidths, [320, 375, 600, 768, 840, 1024, 1200, 1440]);

    final covered = kAuditWidths.map(AppBreakpoints.fromWidth).toSet();
    expect(covered, WindowClass.values.toSet());

    // Los tres cortes exactos están presentes: son donde rompe.
    expect(kAuditWidths, containsAll([600.0, 840.0, 1200.0]));
  });

  testWidgets('pumpAtWidth fija el ancho lógico del viewport', (tester) async {
    for (final width in kAuditWidths) {
      late double observed;
      await pumpAtWidth(
        tester,
        Builder(
          builder: (context) {
            observed = MediaQuery.sizeOf(context).width;
            return const SizedBox.shrink();
          },
        ),
        width: width,
      );
      expect(observed, width, reason: 'ancho observado != solicitado @$width');
    }
  });

  testWidgets('pumpAtWidth aplica el brightness pedido', (tester) async {
    late Brightness observed;
    await pumpAtWidth(
      tester,
      Builder(
        builder: (context) {
          observed = Theme.of(context).brightness;
          return const SizedBox.shrink();
        },
      ),
      width: 375,
      brightness: Brightness.dark,
    );
    expect(observed, Brightness.dark);
  });

  testWidgets('pumpAtWidth propaga disableAnimations al MediaQuery', (
    tester,
  ) async {
    late bool observed;
    await pumpAtWidth(
      tester,
      Builder(
        builder: (context) {
          observed = MediaQuery.disableAnimationsOf(context);
          return const SizedBox.shrink();
        },
      ),
      width: 375,
      disableAnimations: true,
    );
    expect(observed, isTrue);
  });

  testWidgets('expectNoOverflow detecta un RenderFlex overflow real', (
    tester,
  ) async {
    await pumpAtWidth(
      tester,
      const Row(children: [SizedBox(width: 900), SizedBox(width: 900)]),
      width: 375,
    );

    // Hay overflow: la excepción existe. La consumimos para no ensuciar el test.
    expect(tester.takeException(), isNotNull);
  });

  testWidgets('expectNoOverflow pasa cuando no hay overflow', (tester) async {
    await pumpAtWidth(tester, const SizedBox(width: 100), width: 375);
    expectNoOverflow(tester);
  });
}
```

- [ ] **Step 2: Correr el test y confirmar que falla**

Run: `flutter test test/support/responsive_harness_test.dart`
Expected: FAIL — `Error: Couldn't resolve 'responsive_harness.dart'`.

- [ ] **Step 3: Escribir la implementación mínima**

```dart
// test/support/responsive_harness.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/theme/app_theme.dart';

/// Anchos obligatorios de verificación del plan de refactorización UI/UX.
///
/// Los cuatro de la Pre-Delivery Checklist de ui-ux-pro-max (375/768/1024/1440)
/// más 320 (el teléfono más pequeño en uso) y los tres cortes exactos de
/// [WindowClass] (600/840/1200), que es donde el layout realmente rompe.
const List<double> kAuditWidths = [320, 375, 600, 768, 840, 1024, 1200, 1440];

/// Monta [child] dentro de un `MaterialApp` con el tema de AutoDoc y un
/// viewport de [width] × [height] píxeles lógicos.
///
/// Fija el tamaño en `tester.view` (no envolviendo en un `MediaQuery` externo,
/// que `MaterialApp` sobreescribiría al construir el suyo desde la `View`), y
/// usa el `builder` de `MaterialApp` para inyectar [disableAnimations].
Future<void> pumpAtWidth(
  WidgetTester tester,
  Widget child, {
  required double width,
  double height = 900,
  Brightness brightness = Brightness.light,
  bool disableAnimations = false,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(width, height);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
      debugShowCheckedModeBanner: false,
      builder: (context, inner) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(disableAnimations: disableAnimations),
        child: inner!,
      ),
      home: Scaffold(body: child),
    ),
  );
}

/// Falla si el frame actual produjo un overflow de layout.
void expectNoOverflow(WidgetTester tester) {
  final exception = tester.takeException();
  expect(
    exception,
    isNull,
    reason: 'el layout desbordó: $exception',
  );
}

/// Monta [build] a cada ancho de [kAuditWidths] y ejecuta [verify].
///
/// Uso típico en una tarea de pantalla:
/// ```dart
/// await forEachAuditWidth(tester, (width) async {
///   await pumpAtWidth(tester, const MiPantalla(), width: width);
///   expectNoOverflow(tester);
/// });
/// ```
Future<void> forEachAuditWidth(
  WidgetTester tester,
  Future<void> Function(double width) verify,
) async {
  for (final width in kAuditWidths) {
    await verify(width);
  }
}
```

Ajusta la firma de `forEachAuditWidth` en el test si difiere: la versión canónica es la de aquí (`WidgetTester` + callback de ancho), sin parámetro `Widget`.

- [ ] **Step 4: Correr el test y confirmar que pasa**

Run: `flutter test test/support/responsive_harness_test.dart`
Expected: PASS (6 tests)

- [ ] **Step 5: Verificar y commitear**

```bash
dart format . && flutter analyze && flutter test
git add test/support/responsive_harness.dart test/support/responsive_harness_test.dart
git commit -m "test(support): add responsive audit harness (pumpAtWidth, kAuditWidths)"
```

---

### Task 8: Guardia anti-regresión de colores hardcodeados

**Files:**
- Create: `test/core/theme/no_hardcoded_colors_test.dart`

**Interfaces:**
- Consumes: nada (lee el árbol de fuentes con `dart:io`).
- Produces: `const List<String> kTokenizedPaths` — la lista de rutas ya limpias. **Cada fase posterior añade sus rutas aquí como último paso.**

**Cómo funciona (y por qué es un ratchet y no un big-bang):** hay ~270 colores hardcodeados en el repo. Un test que los prohíba todos de golpe estaría rojo durante las 7 fases siguientes, y un test rojo permanente se ignora y deja de servir. En su lugar el test solo mira las rutas de `kTokenizedPaths`, que empieza conteniendo únicamente lo que la Fase 1 dejó limpio y **crece** al cerrar cada fase. Efecto: nada que ya se limpió puede volver a ensuciarse.

- [ ] **Step 1: Escribir el test**

Este es el caso raro donde el test se escribe ya en verde: su valor es impedir regresiones futuras, no forzar una implementación ahora. Confirma que pasa **y** que detecta una violación introducida a mano (Step 2).

```dart
// test/core/theme/no_hardcoded_colors_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Rutas cuya tokenización ya está terminada y no puede regresionar.
///
/// **Cada fase del plan de refactorización UI/UX añade aquí sus rutas como
/// último paso**, tras dejarlas sin colores literales. Ver
/// `docs/superpowers/plans/2026-08-10-ui-ux-overhaul-00-master.md` §2.
const List<String> kTokenizedPaths = [
  'lib/core/theme',
  'lib/core/widgets/app_page_body.dart',
  'lib/core/widgets/app_grid.dart',
];

/// Ficheros exentos, con su motivo. `app_shadows.dart` define las sombras
/// mismas: `Colors.black` ahí *es* el token.
const Map<String, String> kExemptFiles = {
  'lib/core/theme/app_shadows.dart': 'define las sombras; el negro es el token',
  'lib/core/theme/app_colors.dart': 'define la paleta; los literales son la fuente',
  'lib/core/theme/app_theme.dart': 'mapea la paleta al ThemeData de Material',
};

final RegExp _hardcodedColor = RegExp(
  // El `\d*` tras `white`/`black` es imprescindible: sin él, en
  // `Colors.white70` el carácter siguiente a `white` es un dígito, no hay
  // frontera de palabra, la alternativa falla y la línea pasa el test. Así
  // escapaban las 13 constantes de opacidad de Flutter (`white10 white12
  // white24 white30 white38 white54 white70`, `black12 black26 black38
  // black45 black54 black87`) — justo las que usan `main_scaffold.dart` y
  // `mechanic_sidebar.dart`, que entran al ratchet en la Fase 2.
  r'Colors\.(white|black)\d*\b'
  r'|Colors\.(grey|gray|blue|red|green|orange|purple|yellow|pink|teal|indigo'
  r'|amber|cyan|lime|brown)\b'
  r'|Color\(0x[0-9a-fA-F]{8}\)',
);

Iterable<File> _dartFilesUnder(String path) sync* {
  final entity = FileSystemEntity.typeSync(path);
  if (entity == FileSystemEntityType.file) {
    yield File(path);
    return;
  }
  yield* Directory(path)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));
}

void main() {
  test('las rutas ya tokenizadas no contienen colores literales', () {
    final violations = <String>[];

    for (final path in kTokenizedPaths) {
      for (final file in _dartFilesUnder(path)) {
        final normalized = file.path.replaceAll(r'\', '/');
        if (kExemptFiles.keys.any(normalized.endsWith)) continue;

        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (line.trimLeft().startsWith('//')) continue;
          if (line.contains('Colors.transparent')) continue;
          if (_hardcodedColor.hasMatch(line)) {
            violations.add('$normalized:${i + 1}  ${line.trim()}');
          }
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Color literal en ruta ya tokenizada. Usa context.appColors.<token> '
          'o Theme.of(context). Ver CONVENTIONS.md §2.1.\n'
          '${violations.join('\n')}',
    );
  });

  test('la regex detecta las formas que debe detectar', () {
    for (final sample in [
      'color: Colors.white,',
      'color: Colors.black87,',
      'border: Border.all(color: Colors.grey),',
      'color: const Color(0xFF522C81),',
    ]) {
      expect(_hardcodedColor.hasMatch(sample), isTrue, reason: sample);
    }

    for (final sample in [
      'color: Colors.transparent,',
      'color: colors.primary,',
      'color: Theme.of(context).colorScheme.surface,',
    ]) {
      expect(
        _hardcodedColor.hasMatch(sample) &&
            !sample.contains('Colors.transparent'),
        isFalse,
        reason: sample,
      );
    }
  });
}
```

- [ ] **Step 2: Correr el test y confirmar que pasa, y luego que sabe fallar**

Run: `flutter test test/core/theme/no_hardcoded_colors_test.dart`
Expected: PASS (2 tests).

Ahora comprueba que la guardia funciona de verdad: añade temporalmente a `lib/core/widgets/app_grid.dart` la línea `// ignore: unused_local_variable` seguida de `const _probe = Colors.white;` dentro de `build`, y vuelve a correr.
Expected: FAIL, listando `lib/core/widgets/app_grid.dart:<línea>`.
**Revierte esa línea** antes de continuar.

- [ ] **Step 3: Verificar y commitear**

```bash
dart format . && flutter analyze && flutter test
git add test/core/theme/no_hardcoded_colors_test.dart
git commit -m "test(theme): add hardcoded-color ratchet guard for tokenized paths"
```

---

## Verificación de cierre de fase

- [ ] `flutter test` — suite completa verde.
- [ ] `flutter analyze` — sin errores; los únicos warnings nuevos son los `deprecated_member_use` de la Task 6 (anota el conteo).
- [ ] `dart format .` sin cambios pendientes.
- [ ] La app arranca y se ve igual que antes: `flutter run -d chrome`, comprobar `dashboard_screen` y `user_profile_screen` en light y dark. El único cambio visual esperado es que el texto secundario en light mode se ve un punto más oscuro.
- [ ] Correr la Pre-Delivery Checklist de `ui-ux-pro-max` (`references/pro-rules.md`) sobre lo entregado — las secciones aplicables son *Light/Dark Mode Contrast* y *Layout & Spacing*.
- [ ] `Skill(superpowers:requesting-code-review)` sobre el diff completo de la fase.

**Criterio de éxito de la Fase 1:**

- Existe una única fuente de verdad de tamaño de ventana (`AppBreakpoints`), con `Responsive` delegando en ella y un test de caracterización que lo blinda en 8 anchos.
- Existe una única fuente de verdad de motion (`AppMotion`), con curvas custom, exit más rápido que enter y helpers de reduced-motion testeados.
- Los cinco pares de color texto/superficie de la app pasan WCAG AA en light **y** dark, verificado por test con compositing de alfa real.
- `AppPageBody` y `AppGrid` deciden por `constraints`, no por `MediaQuery` — verificado con un test de panel estrecho dentro de ventana ancha.
- Cualquier pantalla puede verificarse en los 8 anchos de auditoría con dos líneas.
- Ninguna ruta ya tokenizada puede volver a introducir un color literal sin que CI falle.
- **Cero cambios de comportamiento en `lib/features/**`.**
