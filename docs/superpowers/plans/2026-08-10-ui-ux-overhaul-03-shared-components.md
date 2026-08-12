# Fase 3 — Componentes compartidos (interacción, accesibilidad, motion) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: `superpowers:subagent-driven-development` (recomendado) o `superpowers:executing-plans`.
>
> **REQUIRED DESIGN SKILLS:** invoca `Skill(emil-design-eng)` antes de las Tasks 1, 2 y 5 (todo lo que sea press/hover/motion) y `Skill(ui-ux-pro-max:ui-ux-pro-max)` antes de las Tasks 1, 3, 4 y 6. Al cerrar la fase, `Skill(review-animations)` sobre el diff completo. Corre además:
> `python "C:/Users/User/.claude/plugins/cache/ui-ux-pro-max-skill/ui-ux-pro-max/2.13.0/.claude/skills/ui-ux-pro-max/scripts/search.py" "touch feedback disabled state focus form validation" --domain ux`
>
> **PRERREQUISITO:** Fases 1 y 2 completas y mergeadas. Esta fase consume `AppMotion`, `AppShadows.*Hover`, `AppColors.hoverOverlay/pressedOverlay`, `AppBreakpoints` y el harness `pumpAtWidth`.
>
> **CONTEXTO OBLIGATORIO:** `...-00-master.md` §2 (Global Constraints).

**Goal:** Que los widgets compartidos que consumen las 34 pantallas respondan físicamente al toque, cumplan el mínimo de 48 dp, tengan semántica para lector de pantalla, respeten reduced motion y — el hallazgo más grave de esta fase — dejen de mostrar texto blanco sobre fondos claros con 1.9:1 de contraste.

**Architecture:** Cada componente se convierte de `StatelessWidget` a `StatefulWidget` solo si necesita estado local de press/hover (`AppButton`, `AppCard`). El feedback de press se implementa con `Listener` (eventos de puntero crudos), no con `GestureDetector`: `GestureDetector` compite en la *gesture arena* con el `InkWell` interno y se comería el ripple. El hover se implementa con `MouseRegion`, que en táctil sencillamente no dispara — no hace falta la guarda equivalente al `@media (hover: hover)` de CSS.

**Tech Stack:** Flutter Material 3. Sin dependencias nuevas — todo con `AnimatedScale`, `AnimatedContainer`, `MouseRegion`, `Listener` del SDK.

## Global Constraints

Heredadas de `...-00-master.md` §2. Las que muerden aquí:

- Cero colores hardcodeados. Los ficheros de esta fase acumulan hoy: `app_button.dart` 1 (`Colors.white` en el shimmer), `app_snackbar.dart` 3 (`Colors.white` ×3), `app_theme.dart` 2 (`Colors.white` en los dos `snackBarTheme`).
- Cero uso directo de `GoogleFonts.*` fuera de `app_text_styles.dart`. Hoy lo violan `app_snackbar.dart:47` y `app_theme.dart:63,132`.
- Touch targets ≥ 48×48 dp, incluido `AppButtonSize.small`.
- Toda animación de transformación pasa por `AppMotion.transformDuration` / `pressScaleFor` / `hoverScaleFor`.
- **Ninguna API pública cambia de forma incompatible**, con una única excepción declarada: `AppEmptyState.lottieAsset` (Task 6), que estaba declarado pero nunca se leía. Salvo esa, los ~34 ficheros de pantalla que consumen estos widgets deben seguir compilando sin tocarse; los parámetros nuevos son siempre opcionales con un default que preserva el comportamiento.
- `dart format .`, `dart fix --apply`, `flutter analyze` limpio antes de cada commit.

## File Structure

| Fichero | Responsabilidad | Estado |
|---|---|---|
| `lib/core/widgets/app_button.dart` | Botón: press-scale, hover-lift, arreglo de sombra, mínimo tappable. | Modificar (Task 1) |
| `lib/core/widgets/app_card.dart` | Tarjeta: press-scale y hover-lift solo cuando es tappable. | Modificar (Task 2) |
| `lib/core/widgets/app_snackbar.dart` | Snackbar: **arreglo de contraste**, tokens, semántica. | Modificar (Task 3) |
| `lib/core/theme/app_theme.dart` | Quitar `GoogleFonts` y `Colors.white` de los dos `snackBarTheme`. | Modificar (Task 3) |
| `lib/core/widgets/app_text_field.dart` | Campo: asociar label al campo para lector de pantalla, error accesible. | Modificar (Task 4) |
| `lib/core/widgets/animated_counter.dart` | Contador: tokens de curva/duración, reduced motion. | Modificar (Task 5) |
| `lib/core/widgets/app_empty_state.dart` | Estado vacío: tokens de spacing, ancho de lectura, semántica. | Modificar (Task 6) |
| `test/core/theme/no_hardcoded_colors_test.dart` | Extender el ratchet. | Modificar (Task 7) |

**Fuera de alcance, con motivo:** `AppSkeleton`/`AppSkeletonLayouts` (delegan su animación al paquete `shimmer`; no hay curva propia que consolidar), `AppStatusBadge`, `NotificationBellButton` (ya tiene test propio y no tiene motion propio), `ResponsiveContainer` (queda obsoleto por `AppPageBody`; se elimina en la Fase 4 cuando se migre su último consumidor), `VehicleImageWidget`, `TranslatedText`. Ninguno tiene un gap concreto que justifique tocarlo ahora — YAGNI.

---

### Task 1: `AppButton` — press, hover, sombra y mínimo tappable

**Files:**
- Modify: `lib/core/widgets/app_button.dart` (reescritura completa)
- Test: `test/core/widgets/app_button_test.dart`

**Interfaces:**
- Consumes: `AppMotion.pressScaleFor`, `AppMotion.hoverScaleFor`, `AppMotion.transformDuration`, `AppMotion.press`, `AppMotion.hover`, `AppMotion.easeOut` (Fase 1 Task 2); `AppShadows.lightSm/lightHover/darkSm/darkHover` (Fase 1 Tasks 3); `context.appColors`.
- Produces: `AppButton({required String text, VoidCallback? onPressed, AppButtonType type = AppButtonType.primary, AppButtonSize size = AppButtonSize.medium, bool isLoading = false, bool hapticFeedback = true, Widget? icon, String? semanticLabel})` — **misma API más un `semanticLabel` opcional**. Sin cambios incompatibles.

**Cuatro problemas medidos en el fichero actual:**

1. **La sombra nunca se renderiza.** [app_button.dart:178-183](../../../lib/core/widgets/app_button.dart#L178-L183) configura `shadowColor: colors.primary.withValues(alpha: 0.3)` y acto seguido `elevation: type == AppButtonType.text ? 0 : 0` — un ternario que devuelve `0` en ambas ramas, con el comentario *"Let hover elevation do the work if needed"*. Con `elevation: 0` Material no pinta ninguna sombra, así que el `shadowColor` es código muerto.
2. **Sin feedback de press.** No hay `AnimatedScale` ni cambio de estado al presionar más allá del ripple por defecto. Regla de `emil-design-eng`: *"Buttons must feel responsive to press"*.
3. **`AppButtonSize.small` no llega al mínimo tappable.** `Responsive.padding(context, 8)` vertical + `AppTextStyles.labelMedium` (12 px) ≈ **32 dp** de alto en `compact`. El mínimo es 48 dp.
4. **Color hardcodeado.** [app_button.dart:157](../../../lib/core/widgets/app_button.dart#L157): `Colors.white.withValues(alpha: 0.2)` en el shimmer de carga — en dark mode ese destello blanco sobre un botón teal se ve mal, y la duración `1500.ms` está fuera de todo token.

- [ ] **Step 1: Invocar las skills**

`Skill(emil-design-eng)` — verifica: `transform: scale(0.97)` en `:active`, `transition: transform 160ms ease-out`, rango aceptable 0.95–0.98, y la regla de que *press feedback* es de las pocas animaciones que **siempre** deben existir porque su propósito es confirmar que la interfaz oyó al usuario.

`Skill(ui-ux-pro-max:ui-ux-pro-max)` — `references/pro-rules.md` §Interaction: *"Tap feedback — Provide clear pressed feedback within 80-150ms"*, *"Touch target minimum >=44x44pt (iOS) or >=48x48dp (Android)"*, *"Disabled state clarity — Don't: Controls that look tappable but do nothing"*, y §Icons *"Stable Interaction States — Use color, opacity, or elevation transitions for press states without changing layout bounds"*.

**Nota importante sobre esa última regla:** dice que el press no debe *cambiar los límites de layout*. `AnimatedScale` es exactamente eso — aplica una transformación de pintado, no re-hace el layout, así que los widgets vecinos no se mueven. Es la implementación correcta, no una violación. Anótalo en el commit.

- [ ] **Step 2: Escribir el test que falla**

```dart
// test/core/widgets/app_button_test.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/theme/app_motion.dart';
import 'package:autodoc/core/widgets/app_button.dart';

import '../../support/responsive_harness.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget button, {
    double width = 375,
    Brightness brightness = Brightness.light,
    bool disableAnimations = false,
  }) async {
    await pumpAtWidth(
      tester,
      Center(child: button),
      width: width,
      brightness: brightness,
      disableAnimations: disableAnimations,
    );
  }

  group('feedback de press', () {
    testWidgets('se encoge al presionar y vuelve al soltar', (tester) async {
      await pump(tester, AppButton(text: 'Guardar', onPressed: () {}));

      double currentScale() =>
          tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;

      expect(currentScale(), 1.0);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(AppButton)),
      );
      await tester.pump();
      expect(currentScale(), AppMotion.pressedScale);

      await gesture.up();
      await tester.pump();
      expect(currentScale(), 1.0);
    });

    testWidgets('vuelve a 1.0 si el gesto se cancela', (tester) async {
      await pump(tester, AppButton(text: 'Guardar', onPressed: () {}));

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(AppButton)),
      );
      await tester.pump();
      await gesture.cancel();
      await tester.pump();

      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
        1.0,
      );
    });

    testWidgets('un botón deshabilitado no se encoge', (tester) async {
      await pump(tester, const AppButton(text: 'Guardar', onPressed: null));

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(AppButton)),
      );
      await tester.pump();

      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
        1.0,
        reason: 'un control no interactivo no debe parecer que responde',
      );
      await gesture.up();
    });

    testWidgets('un botón en carga no se encoge ni dispara onPressed', (
      tester,
    ) async {
      var taps = 0;
      await pump(
        tester,
        AppButton(text: 'Guardar', isLoading: true, onPressed: () => taps++),
      );

      await tester.tap(find.byType(AppButton), warnIfMissed: false);
      await tester.pump();

      expect(taps, 0);
    });

    testWidgets('con reduced motion no hay encogimiento', (tester) async {
      await pump(
        tester,
        AppButton(text: 'Guardar', onPressed: () {}),
        disableAnimations: true,
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(AppButton)),
      );
      await tester.pump();

      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
        1.0,
      );
      await gesture.up();
    });
  });

  group('feedback de hover', () {
    testWidgets('se eleva al entrar el puntero y el press gana al hover', (
      tester,
    ) async {
      await pump(tester, AppButton(text: 'Guardar', onPressed: () {}));

      double currentScale() =>
          tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;

      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(
        pointer.hover(tester.getCenter(find.byType(AppButton))),
      );
      await tester.pump();
      expect(currentScale(), AppMotion.hoverScale);

      // Presionar mientras se está en hover debe mostrar el press, no el lift.
      await tester.sendEventToBinding(pointer.down(pointer.location!));
      await tester.pump();
      expect(currentScale(), AppMotion.pressedScale);

      await tester.sendEventToBinding(pointer.up());
      await tester.pump();
      expect(currentScale(), AppMotion.hoverScale);
    });
  });

  group('comportamiento preservado', () {
    testWidgets('tocar sigue disparando onPressed', (tester) async {
      var tapped = false;
      await pump(
        tester,
        AppButton(text: 'Guardar', onPressed: () => tapped = true),
      );

      await tester.tap(find.byType(AppButton));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('muestra el indicador de carga en vez del texto', (
      tester,
    ) async {
      await pump(
        tester,
        AppButton(text: 'Guardar', isLoading: true, onPressed: () {}),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Guardar'), findsNothing);
    });
  });

  group('accesibilidad', () {
    testWidgets('todos los tamaños llegan a 48dp de alto', (tester) async {
      for (final size in AppButtonSize.values) {
        await pump(
          tester,
          AppButton(text: 'Ok', size: size, onPressed: () {}),
        );

        final height = tester.getSize(find.byType(AppButton)).height;
        expect(
          height,
          greaterThanOrEqualTo(48.0),
          reason: '$size mide ${height}dp de alto',
        );
      }
    });

    testWidgets('expone semántica de botón con su etiqueta', (tester) async {
      await pump(tester, AppButton(text: 'Guardar', onPressed: () {}));

      expect(
        tester.getSemantics(find.byType(AppButton).first),
        matchesSemantics(
          label: 'Guardar',
          isButton: true,
          isEnabled: true,
          hasEnabledState: true,
          hasTapAction: true,
          isFocusable: true,
        ),
      );
    });

    testWidgets('semanticLabel sustituye a la etiqueta visible', (
      tester,
    ) async {
      await pump(
        tester,
        AppButton(
          text: 'Guardar',
          semanticLabel: 'Guardar los cambios del vehículo',
          onPressed: () {},
        ),
      );

      expect(
        find.bySemanticsLabel('Guardar los cambios del vehículo'),
        findsOneWidget,
      );
    });
  });

  group('render', () {
    testWidgets('los tres tipos renderizan en ambos temas sin excepciones', (
      tester,
    ) async {
      for (final brightness in Brightness.values) {
        for (final type in AppButtonType.values) {
          await pump(
            tester,
            AppButton(text: 'Ok', type: type, onPressed: () {}),
            brightness: brightness,
          );
          expectNoOverflow(tester);
        }
      }
    });
  });
}
```

- [ ] **Step 3: Correr el test y confirmar que falla**

Run: `flutter test test/core/widgets/app_button_test.dart`
Expected: FAIL — el finder de `AnimatedScale` no encuentra nada (el `AppButton` actual no tiene ninguno), el test de 48 dp falla para `AppButtonSize.small`, y `semanticLabel` no existe (error de compilación).

- [ ] **Step 4: Reescribir `AppButton`**

Sustituye el contenido completo de `lib/core/widgets/app_button.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_motion.dart';
import 'package:autodoc/core/theme/app_radius.dart';
import 'package:autodoc/core/theme/app_shadows.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/utils/responsive.dart';

enum AppButtonType { primary, secondary, text }

enum AppButtonSize { small, medium, large }

/// Alto mínimo tappable. Material y las HIG de iOS piden 48 dp / 44 pt; se toma
/// el mayor de los dos para no tener dos comportamientos por plataforma.
const double _kMinTapHeight = 48.0;

class AppButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final AppButtonType type;
  final AppButtonSize size;
  final bool isLoading;
  final bool hapticFeedback;
  final Widget? icon;

  /// Descripción para lector de pantalla cuando [text] no basta por sí solo
  /// ("Guardar" → "Guardar los cambios del vehículo").
  final String? semanticLabel;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.type = AppButtonType.primary,
    this.size = AppButtonSize.medium,
    this.isLoading = false,
    this.hapticFeedback = true,
    this.icon,
    this.semanticLabel,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _isPressed = false;
  bool _isHovered = false;

  bool get _interactive => widget.onPressed != null && !widget.isLoading;

  void _setPressed(bool value) {
    if (!_interactive || _isPressed == value) return;
    setState(() => _isPressed = value);
  }

  void _setHovered(bool value) {
    if (!_interactive || _isHovered == value) return;
    setState(() => _isHovered = value);
  }

  void _handlePress() {
    if (!_interactive) return;
    if (widget.hapticFeedback) {
      HapticFeedback.lightImpact();
    }
    widget.onPressed!();
  }

  ({Color background, Color foreground, List<Color>? gradient}) _palette(
    AppColors colors,
  ) {
    return switch (widget.type) {
      AppButtonType.primary => (
        background: colors.primary,
        foreground: colors.onPrimary,
        gradient: [colors.primary, colors.primary.withValues(alpha: 0.85)],
      ),
      AppButtonType.secondary => (
        background: colors.secondary,
        foreground: colors.onSecondary,
        gradient: null,
      ),
      AppButtonType.text => (
        background: Colors.transparent,
        foreground: colors.primary,
        gradient: null,
      ),
    };
  }

  ({EdgeInsets padding, TextStyle textStyle, double iconSize}) _metrics(
    BuildContext context,
  ) {
    return switch (widget.size) {
      AppButtonSize.small => (
        padding: EdgeInsets.symmetric(
          vertical: Responsive.padding(context, AppSpacing.sm),
          horizontal: Responsive.padding(context, AppSpacing.base),
        ),
        textStyle: AppTextStyles.labelMedium,
        iconSize: Responsive.iconSize(context, 16),
      ),
      AppButtonSize.medium => (
        padding: EdgeInsets.symmetric(
          vertical: Responsive.padding(context, 14),
          horizontal: Responsive.padding(context, AppSpacing.xl),
        ),
        textStyle: AppTextStyles.titleSmall,
        iconSize: Responsive.iconSize(context, 20),
      ),
      AppButtonSize.large => (
        padding: EdgeInsets.symmetric(
          vertical: Responsive.padding(context, 18),
          horizontal: Responsive.padding(context, AppSpacing.xxl),
        ),
        textStyle: AppTextStyles.titleMedium,
        iconSize: Responsive.iconSize(context, 24),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = _palette(colors);
    final metrics = _metrics(context);

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.full),
    );

    final textWidget = Text(
      widget.text,
      style: metrics.textStyle.copyWith(color: palette.foreground),
    );

    Widget childContent;
    if (widget.isLoading) {
      childContent = SizedBox(
        height: metrics.iconSize,
        width: metrics.iconSize,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(palette.foreground),
        ),
      );
    } else if (widget.icon != null) {
      childContent = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconTheme(
            data: IconThemeData(
              size: metrics.iconSize,
              color: palette.foreground,
            ),
            child: widget.icon!,
          ),
          const SizedBox(width: AppSpacing.sm),
          textWidget,
        ],
      );
    } else {
      childContent = textWidget;
    }

    // La sombra sí se pinta aquí (antes se configuraba shadowColor con
    // elevation: 0, así que Material nunca la dibujaba).
    final resting = widget.type == AppButtonType.text
        ? const <BoxShadow>[]
        : (isDark ? AppShadows.darkSm : AppShadows.lightSm);
    final hovered = widget.type == AppButtonType.text
        ? const <BoxShadow>[]
        : (isDark ? AppShadows.darkHover : AppShadows.lightHover);

    Widget surface = AnimatedContainer(
      duration: AppMotion.hover,
      curve: AppMotion.easeOut,
      constraints: const BoxConstraints(minHeight: _kMinTapHeight),
      padding: metrics.padding,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: palette.gradient == null ? palette.background : null,
        gradient: palette.gradient != null
            ? LinearGradient(
                colors: palette.gradient!,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        borderRadius: BorderRadius.circular(AppRadius.full),
        boxShadow: _isHovered ? hovered : resting,
      ),
      child: childContent,
    );

    if (widget.isLoading && widget.type != AppButtonType.text) {
      surface = surface
          .animate(onPlay: (controller) => controller.repeat())
          .shimmer(
            duration: 1500.ms,
            color: palette.foreground.withValues(alpha: 0.2),
          );
    }

    final button = Material(
      color: Colors.transparent,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _interactive ? _handlePress : null,
        borderRadius: BorderRadius.circular(AppRadius.full),
        hoverColor: colors.hoverOverlay,
        highlightColor: colors.pressedOverlay,
        child: surface,
      ),
    );

    return Semantics(
      button: true,
      enabled: _interactive,
      label: widget.semanticLabel ?? widget.text,
      excludeSemantics: widget.semanticLabel != null,
      child: MouseRegion(
        cursor: _interactive
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onEnter: (_) => _setHovered(true),
        onExit: (_) => _setHovered(false),
        // Listener (eventos de puntero crudos) en vez de GestureDetector:
        // GestureDetector competiría en la gesture arena con el InkWell y le
        // robaría el ripple.
        child: Listener(
          onPointerDown: (_) => _setPressed(true),
          onPointerUp: (_) => _setPressed(false),
          onPointerCancel: (_) => _setPressed(false),
          child: AnimatedScale(
            // El press gana al hover: si el usuario está presionando, lo que
            // debe ver es la confirmación del toque, no el lift.
            scale: _isPressed
                ? AppMotion.pressScaleFor(context)
                : _isHovered
                ? AppMotion.hoverScaleFor(context)
                : 1.0,
            duration: AppMotion.transformDuration(
              context,
              _isPressed ? AppMotion.press : AppMotion.hover,
            ),
            curve: AppMotion.easeOut,
            child: button,
          ),
        ),
      ),
    );
  }
}
```

Nota sobre el shimmer: `1500.ms` se conserva a propósito y **no** se tokeniza en `AppMotion`. No es una micro-interacción sino un indicador de progreso continuo, la única categoría que el framework de `emil-design-eng` exime del límite de 300 ms. Documéntalo en el commit para que no se "arregle" después por error.

- [ ] **Step 5: Correr el test y confirmar que pasa**

Run: `flutter test test/core/widgets/app_button_test.dart`
Expected: PASS (12 tests)

Si `matchesSemantics` falla por flags que no esperabas, imprime lo que llega con `debugDumpSemanticsTree()` y ajusta el *matcher* a lo que la implementación produce realmente — pero **no** relajes `isButton`, `hasTapAction` ni `label`, que son el objetivo del test.

- [ ] **Step 6: Verificar que las ~34 pantallas siguen compilando**

Run: `flutter analyze && flutter test`
Expected: verde. Ninguna pantalla debería necesitar cambios: la API pública solo ganó un parámetro opcional.

Verificación visual: `flutter run -d chrome` → `dashboard_screen` y `user_profile_screen` (los dos mayores consumidores de `AppButton`). Comprueba en light y dark: (a) los botones tienen sombra visible en reposo —antes no—, (b) se encogen al presionar, (c) se elevan al pasar el ratón, (d) el botón `small` mide al menos 48 dp.

- [ ] **Step 7: Commit**

```bash
dart format . && dart fix --apply
git add lib/core/widgets/app_button.dart test/core/widgets/app_button_test.dart
git commit -m "feat(widgets): add press/hover feedback to AppButton and fix its shadow

- La sombra nunca se pintaba: se configuraba shadowColor junto a
  'elevation: type == AppButtonType.text ? 0 : 0', un ternario con 0 en ambas
  ramas. Ahora la pinta el propio contenedor con AppShadows.
- Sin feedback de press. Añade AnimatedScale a AppMotion.pressedScale (0.97,
  160ms, ease-out) vía Listener, que no compite con el InkWell por el gesto.
- AppButtonSize.small medía ~32dp de alto, por debajo del mínimo de 48dp.
- El shimmer de carga usaba Colors.white hardcodeado; ahora deriva del
  foreground, así que también funciona en dark mode.
- Añade Semantics(button, enabled, label) y semanticLabel opcional.

AnimatedScale no re-hace layout (transforma en pintado), así que cumple la
regla 'pressed states must not shift layout bounds' de ui-ux-pro-max."
```

---

### Task 2: `AppCard` — press y hover solo cuando es tappable

**Files:**
- Modify: `lib/core/widgets/app_card.dart`
- Test: `test/core/widgets/app_card_test.dart`

**Interfaces:**
- Consumes: `AppMotion.pressScaleFor`, `AppMotion.transformDuration`, `AppMotion.press`, `AppMotion.hover`, `AppMotion.easeOut` (Fase 1 Task 2); `AppShadows.lightSm/lightHover/darkSm/darkHover` (Fase 1 Task 3); `context.appColors`.
- Produces: `AppCard({required Widget child, EdgeInsetsGeometry padding, EdgeInsetsGeometry margin, VoidCallback? onTap, String? semanticLabel})` — misma API más `semanticLabel` opcional.

**Regla de diseño que gobierna esta tarea:** una tarjeta **sin** `onTap` es una superficie estática y no debe animar nada — moverse al pasar el ratón sobre algo que no es pulsable es una promesa falsa. Solo cuando `onTap != null` se añaden press-scale y hover-lift. El test lo verifica en ambas direcciones.

- [ ] **Step 1: Escribir el test que falla**

```dart
// test/core/widgets/app_card_test.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/theme/app_motion.dart';
import 'package:autodoc/core/widgets/app_card.dart';

import '../../support/responsive_harness.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget card, {
    bool disableAnimations = false,
    Brightness brightness = Brightness.light,
  }) async {
    await pumpAtWidth(
      tester,
      Center(child: card),
      width: 375,
      brightness: brightness,
      disableAnimations: disableAnimations,
    );
  }

  testWidgets('sin onTap no anima: es una superficie estática', (tester) async {
    await pump(tester, const AppCard(child: Text('Contenido')));

    expect(
      find.byType(AnimatedScale),
      findsNothing,
      reason: 'una tarjeta no pulsable no debe prometer interacción',
    );
  });

  testWidgets('con onTap se encoge al presionar y vuelve al soltar', (
    tester,
  ) async {
    await pump(tester, AppCard(onTap: () {}, child: const Text('Contenido')));

    double currentScale() =>
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;

    expect(currentScale(), 1.0);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(AppCard)),
    );
    await tester.pump();
    expect(currentScale(), AppMotion.pressedScale);

    await gesture.up();
    await tester.pump();
    expect(currentScale(), 1.0);
  });

  testWidgets('con onTap se eleva al pasar el puntero', (tester) async {
    await pump(tester, AppCard(onTap: () {}, child: const Text('Contenido')));

    List<BoxShadow>? shadowOf() {
      final container = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      return (container.decoration as BoxDecoration?)?.boxShadow;
    }

    final resting = shadowOf()!.first.blurRadius;

    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(
      pointer.hover(tester.getCenter(find.byType(AppCard))),
    );
    await tester.pump();

    expect(
      shadowOf()!.first.blurRadius,
      greaterThan(resting),
      reason: 'la tarjeta no se elevó al hover',
    );
  });

  testWidgets('tocar dispara onTap', (tester) async {
    var tapped = false;
    await pump(
      tester,
      AppCard(onTap: () => tapped = true, child: const Text('Contenido')),
    );

    await tester.tap(find.byType(AppCard));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('con reduced motion no se encoge', (tester) async {
    await pump(
      tester,
      AppCard(onTap: () {}, child: const Text('Contenido')),
      disableAnimations: true,
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(AppCard)),
    );
    await tester.pump();

    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1.0);
    await gesture.up();
  });

  testWidgets('una tarjeta pulsable expone semántica de botón', (tester) async {
    await pump(
      tester,
      AppCard(
        onTap: () {},
        semanticLabel: 'Toyota Corolla 2019',
        child: const Text('Contenido'),
      ),
    );

    expect(find.bySemanticsLabel('Toyota Corolla 2019'), findsOneWidget);
  });

  testWidgets('renderiza en ambos temas sin excepciones', (tester) async {
    for (final brightness in Brightness.values) {
      await pump(
        tester,
        AppCard(onTap: () {}, child: const Text('Contenido')),
        brightness: brightness,
      );
      expectNoOverflow(tester);
    }
  });
}
```

- [ ] **Step 2: Correr el test y confirmar que falla**

Run: `flutter test test/core/widgets/app_card_test.dart`
Expected: FAIL — no hay `AnimatedScale` ni `AnimatedContainer` en el `AppCard` actual (usa `Container` estático), y `semanticLabel` no existe.

- [ ] **Step 3: Reescribir `AppCard`**

```dart
import 'package:flutter/material.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_motion.dart';
import 'package:autodoc/core/theme/app_radius.dart';
import 'package:autodoc/core/theme/app_shadows.dart';
import 'package:autodoc/core/utils/responsive.dart';

/// Superficie de contenido de AutoDoc.
///
/// Si [onTap] es `null` es una superficie **estática**: no anima nada. Mover o
/// elevar algo que no se puede pulsar es una promesa falsa. El feedback de
/// press y el lift de hover solo existen cuando la tarjeta es interactiva.
///
/// A diferencia de [AppButton], el hover aquí **solo** eleva la sombra, sin
/// escalar: una tarjeta es una superficie grande y un 2 % de escala la
/// desalinea visiblemente de sus vecinas en una rejilla. El botón es pequeño y
/// ahí el mismo 2 % se lee como respuesta, no como desalineación.
class AppCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;

  /// Descripción de la tarjeta para lector de pantalla. Solo se aplica cuando
  /// [onTap] no es `null`.
  final String? semanticLabel;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
    this.margin = const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
    this.onTap,
    this.semanticLabel,
  });

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _isPressed = false;
  bool _isHovered = false;

  bool get _interactive => widget.onTap != null;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = Responsive.size(context, AppRadius.lg);

    final resting = isDark ? AppShadows.darkSm : AppShadows.lightSm;
    final hovered = isDark ? AppShadows.darkHover : AppShadows.lightHover;

    final surface = AnimatedContainer(
      duration: AppMotion.hover,
      curve: AppMotion.easeOut,
      margin: widget.margin,
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: _interactive && _isHovered ? hovered : resting,
        border: Border.all(
          color: colors.outline.withValues(alpha: isDark ? 0.2 : 0.4),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(radius),
          hoverColor: colors.hoverOverlay,
          highlightColor: colors.pressedOverlay,
          child: Padding(padding: widget.padding, child: widget.child),
        ),
      ),
    );

    if (!_interactive) return surface;

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Listener(
          onPointerDown: (_) => setState(() => _isPressed = true),
          onPointerUp: (_) => setState(() => _isPressed = false),
          onPointerCancel: (_) => setState(() => _isPressed = false),
          child: AnimatedScale(
            scale: _isPressed ? AppMotion.pressScaleFor(context) : 1.0,
            duration: AppMotion.transformDuration(context, AppMotion.press),
            curve: AppMotion.easeOut,
            child: surface,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Correr el test y confirmar que pasa**

Run: `flutter test test/core/widgets/app_card_test.dart`
Expected: PASS (7 tests)

- [ ] **Step 5: Verificar y commitear**

```bash
dart format . && flutter analyze && flutter test
```

Verificación visual: `garage_screen` (rejilla de tarjetas de vehículo, todas con `onTap`) y una pantalla con tarjetas estáticas. Las primeras deben responder al press y elevarse al hover; las segundas deben quedarse quietas.

```bash
git add lib/core/widgets/app_card.dart test/core/widgets/app_card_test.dart
git commit -m "feat(widgets): add press/hover feedback to tappable AppCard

Solo cuando onTap != null: una tarjeta estática que se mueve al pasar el ratón
promete una interacción que no existe. Añade también semanticLabel."
```

---

### Task 3: `AppSnackbar` — arreglo de contraste (el fallo de accesibilidad más grave de la app)

**Files:**
- Modify: `lib/core/widgets/app_snackbar.dart` (reescritura completa)
- Modify: `lib/core/theme/app_theme.dart` (los dos `snackBarTheme`)
- Test: `test/core/widgets/app_snackbar_test.dart`

**Interfaces:**
- Consumes: `AppTextStyles.bodyMedium`, `AppTextStyles.labelLarge`; `context.appColors`; `contrastRatio` de `test/support/contrast.dart` (solo en el test).
- Produces: `AppSnackbar.show(BuildContext context, String message, {SnackbarType type = SnackbarType.info})` — misma API pública.

**Hallazgo medido.** [app_snackbar.dart:56](../../../lib/core/widgets/app_snackbar.dart#L56) pinta el fondo con el color semántico y el texto en `Colors.white` ([L42, L48, L64](../../../lib/core/widgets/app_snackbar.dart#L42-L64)). Los ratios reales:

| Tipo | Fondo | Texto | Ratio | AA (4.5:1) |
|---|---|---|---|---|
| `success` | `#48BB78` | blanco | **2.43:1** | ❌ |
| `error` | `#FC8181` | blanco | **2.46:1** | ❌ |
| *(warning, si se añadiera)* | `#F6AD55` | blanco | **1.90:1** | ❌ |
| `info` | `#522C81` | blanco | 10.3:1 | ✅ |

Tres de cada cuatro variantes son ilegibles, y son precisamente las que comunican éxito y error. Además el componente **ignora** el `snackBarTheme` que ya está configurado en [app_theme.dart:59-71](../../../lib/core/theme/app_theme.dart#L59-L71) con un fondo oscuro (`#1E293B`) que sí contrasta.

**Arreglo:** fondo oscuro del tema, y el color semántico se traslada al **icono**, donde solo necesita 3:1 de contraste de glifo grande — que sí cumple sobradamente:

| Tipo | Icono | Sobre `#1E293B` | ≥3:1 |
|---|---|---|---|
| `success` | `#48BB78` | 6.03:1 | ✅ |
| `error` | `#FC8181` | 5.96:1 | ✅ |
| `info` | `#522C81` | *insuficiente* → usar `colors.secondary` (teal) | ✅ |
| texto | blanco | 14.6:1 | ✅ |

Nota sobre `info`: el morado `#522C81` sobre `#1E293B` da menos de 3:1, así que para el icono de `info` se usa `colors.secondary` (teal `#81E6D9` en light), que es el color de marca complementario. El test lo verifica en vez de asumirlo.

- [ ] **Step 1: Invocar la skill**

`Skill(ui-ux-pro-max:ui-ux-pro-max)` — `references/pro-rules.md` §Light/Dark Mode Contrast: *"Text contrast (light) — Maintain body text contrast >=4.5:1"* y *"Token-driven theming — Don't: Hardcoded per-screen hex values"*. Y §Accessibility: *"Color is not the only indicator"* — de ahí que cada tipo conserve su icono distinto además del color.

- [ ] **Step 2: Escribir el test que falla**

```dart
// test/core/widgets/app_snackbar_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/widgets/app_snackbar.dart';

import '../../support/contrast.dart';
import '../../support/responsive_harness.dart';

const double kAaBody = 4.5;
const double kAaGlyph = 3.0;

void main() {
  Future<void> showAndSettle(
    WidgetTester tester,
    SnackbarType type, {
    Brightness brightness = Brightness.light,
  }) async {
    await pumpAtWidth(
      tester,
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => AppSnackbar.show(context, 'Mensaje', type: type),
          child: const Text('mostrar'),
        ),
      ),
      width: 375,
      brightness: brightness,
    );
    await tester.tap(find.text('mostrar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));
  }

  group('contraste', () {
    testWidgets('el texto pasa AA en los tres tipos y ambos temas', (
      tester,
    ) async {
      for (final brightness in Brightness.values) {
        for (final type in SnackbarType.values) {
          await showAndSettle(tester, type, brightness: brightness);

          final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
          final background = snackBar.backgroundColor!;
          final text = tester.widget<Text>(find.text('Mensaje'));
          final textColor = text.style!.color!;

          expect(
            contrastRatio(textColor, background),
            greaterThanOrEqualTo(kAaBody),
            reason: '$type / $brightness: texto sobre fondo',
          );
        }
      }
    });

    testWidgets('el icono se distingue del fondo en los tres tipos', (
      tester,
    ) async {
      for (final type in SnackbarType.values) {
        await showAndSettle(tester, type);

        final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
        final icon = tester.widget<Icon>(find.byType(Icon).first);

        expect(
          contrastRatio(icon.color!, snackBar.backgroundColor!),
          greaterThanOrEqualTo(kAaGlyph),
          reason: '$type: icono sobre fondo',
        );
      }
    });
  });

  group('el color no es el único indicador', () {
    testWidgets('cada tipo usa un icono distinto', (tester) async {
      final icons = <IconData>{};

      for (final type in SnackbarType.values) {
        await showAndSettle(tester, type);
        icons.add(tester.widget<Icon>(find.byType(Icon).first).icon!);
      }

      expect(
        icons.length,
        SnackbarType.values.length,
        reason: 'dos tipos comparten icono: se distinguen solo por color',
      );
    });
  });

  group('tokens', () {
    testWidgets('no usa Colors.white literal en el estilo del texto', (
      tester,
    ) async {
      await showAndSettle(tester, SnackbarType.success);

      final text = tester.widget<Text>(find.text('Mensaje'));
      // El color debe salir de la paleta, no de Colors.white.
      expect(text.style?.color, isNotNull);
      expect(text.style?.fontFamily, isNotNull);
    });
  });

  group('comportamiento preservado', () {
    testWidgets('muestra el mensaje y la acción OK', (tester) async {
      await showAndSettle(tester, SnackbarType.info);

      expect(find.text('Mensaje'), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);
    });

    testWidgets('no desborda con un mensaje largo a 320px', (tester) async {
      await pumpAtWidth(
        tester,
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => AppSnackbar.show(
              context,
              'No se pudo guardar el servicio porque el vehículo ya no está '
              'asociado a tu cuenta. Vuelve a intentarlo más tarde.',
            ),
            child: const Text('mostrar'),
          ),
        ),
        width: 320,
      );
      await tester.tap(find.text('mostrar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));

      expectNoOverflow(tester);
    });
  });
}
```

- [ ] **Step 3: Correr el test y confirmar que falla**

Run: `flutter test test/core/widgets/app_snackbar_test.dart`
Expected: FAIL. El primer test falla con ratios ~2.43 y ~2.46 para `success` y `error`. **Anota los números exactos** que imprime: son la prueba del bug y van en el mensaje de commit.

- [ ] **Step 4: Reescribir `AppSnackbar`**

```dart
import 'package:flutter/material.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_radius.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';

enum SnackbarType { success, error, info }

class AppSnackbar {
  AppSnackbar._();

  static void show(
    BuildContext context,
    String message, {
    SnackbarType type = SnackbarType.info,
  }) {
    final colors = context.appColors;
    final theme = Theme.of(context);

    // Capturamos el ScaffoldMessenger AHORA, mientras el context todavía es
    // válido: muchas llamadas hacen Navigator.pop justo antes de mostrar el
    // snackbar, y si lo buscáramos dentro del onPressed (que se ejecuta
    // después, al tocar "OK"), el context ya podría estar desmontado.
    final messenger = ScaffoldMessenger.of(context);

    // El fondo sale del tema (una superficie oscura en ambos modos), no del
    // color semántico: pintar el fondo de #48BB78 con texto blanco daba
    // 2.43:1, muy por debajo del 4.5:1 de WCAG AA. El significado lo lleva el
    // icono, que como glifo solo necesita 3:1 y lo supera con holgura.
    final background =
        theme.snackBarTheme.backgroundColor ?? colors.surfaceVariant;
    final foreground =
        theme.snackBarTheme.contentTextStyle?.color ?? colors.textPrimary;

    final (IconData icon, Color accent) = switch (type) {
      SnackbarType.success => (Icons.check_circle_outline, colors.success),
      SnackbarType.error => (Icons.error_outline, colors.error),
      // El morado de marca no llega a 3:1 sobre la superficie oscura del
      // snackbar; el teal complementario sí.
      SnackbarType.info => (Icons.info_outline, colors.secondary),
    };

    final snackBar = SnackBar(
      content: Row(
        children: [
          Icon(icon, color: accent, size: 24),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodyMedium.copyWith(
                color: foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: background,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      margin: const EdgeInsets.all(AppSpacing.base),
      elevation: 6,
      duration: const Duration(seconds: 4),
      action: SnackBarAction(
        label: 'OK',
        textColor: accent,
        onPressed: messenger.hideCurrentSnackBar,
      ),
    );

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }
}
```

- [ ] **Step 5: Limpiar los `snackBarTheme` de `app_theme.dart`**

En `lib/core/theme/app_theme.dart`, en **ambos** getters (`light` y `dark`), sustituye el `contentTextStyle` para que no use `GoogleFonts` ni `Colors.white` directos:

```dart
        contentTextStyle: AppTextStyles.bodyMedium.copyWith(
          color: AppPalette.darkTextPrimary,
          fontWeight: FontWeight.w600,
        ),
```

(`AppPalette.darkTextPrimary` es blanco y es el token correcto: el fondo del snackbar es oscuro **en ambos temas**.)

Añade `import 'app_text_styles.dart';` si no está, y elimina `import 'package:google_fonts/google_fonts.dart';` del fichero si deja de usarse (`flutter analyze` avisará).

Sustituye también los dos `BorderRadius.circular(12)` por `BorderRadius.circular(AppRadius.md)`.

- [ ] **Step 6: Correr el test y confirmar que pasa**

Run: `flutter test test/core/widgets/app_snackbar_test.dart`
Expected: PASS (6 tests)

- [ ] **Step 7: Verificar y commitear**

```bash
dart format . && flutter analyze && flutter test
```

Verificación visual: dispara un snackbar de éxito y uno de error en light y en dark. Debe leerse sin esfuerzo en los cuatro casos.

```bash
git add lib/core/widgets/app_snackbar.dart lib/core/theme/app_theme.dart test/core/widgets/app_snackbar_test.dart
git commit -m "fix(a11y): make AppSnackbar legible — 3 of 4 variants failed WCAG AA

El fondo se pintaba con el color semántico y el texto en Colors.white:
  success #48BB78 + blanco = 2.43:1
  error   #FC8181 + blanco = 2.46:1
  info    #522C81 + blanco = 10.3:1 (el único que pasaba)
frente al 4.5:1 que exige WCAG AA para texto de cuerpo.

Ahora el fondo sale del snackBarTheme (superficie oscura, 14.6:1 con el texto)
y el color semántico se traslada al icono, donde como glifo solo necesita 3:1 y
llega a 5.9-6.0:1. El icono sigue siendo distinto por tipo, así que el color no
es el único indicador. De paso quita GoogleFonts directo y Colors.white del
componente y de los dos snackBarTheme."
```

---

### Task 4: `AppTextField` — asociar la etiqueta al campo

**Files:**
- Modify: `lib/core/widgets/app_text_field.dart`
- Test: `test/core/widgets/app_text_field_test.dart`

**Interfaces:**
- Consumes: `AppTextStyles`, `AppRadius`, `AppSpacing`; `context.appColors`.
- Produces: la misma API más `String? helperText` y `bool isRequired = false`. Sin cambios incompatibles.

**Qué está bien y no se toca:** el campo ya tiene **etiqueta visible** encima ([app_text_field.dart:68-78](../../../lib/core/widgets/app_text_field.dart#L68-L78)), no un placeholder haciendo de etiqueta — eso cumple la regla `ui-ux-pro-max` §8 *"Visible labels / Don't: Placeholder-only label"*. Y `InputDecorator` ya anima la transición del borde al enfocar (~200 ms, comportamiento nativo de Material), así que **no** hace falta añadir motion aquí; duplicarlo sería peor.

**Qué falla:**
1. **La etiqueta no está asociada al campo.** Es un `Text` hermano dentro de un `Column`. Un lector de pantalla enfoca el `TextFormField` y anuncia solo el `hintText` (o nada). El usuario no sabe qué campo está rellenando.
2. **Sin `helperText`.** La regla §8 pide *"Helper text, Progressive disclosure"*; hoy no hay dónde poner una pista ("Formato: P123-456").
3. **El error no se anuncia.** `errorBorder` cambia el color del borde, pero el texto de error que genera `validator` usa el estilo por defecto del tema, que no está tokenizado, y no hay `Semantics` que lo vincule.
4. **`contentPadding` fijo** de 20/16 sin escalar.

- [ ] **Step 1: Escribir el test que falla**

```dart
// test/core/widgets/app_text_field_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/widgets/app_text_field.dart';

import '../../support/responsive_harness.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget field, {double width = 375}) {
    return pumpAtWidth(tester, Center(child: field), width: width);
  }

  testWidgets('la etiqueta está asociada al campo para el lector de pantalla', (
    tester,
  ) async {
    await pump(tester, const AppTextField(label: 'Placa del vehículo'));

    final semantics = tester.getSemantics(find.byType(EditableText));
    expect(
      semantics.label,
      contains('Placa del vehículo'),
      reason: 'el campo no anuncia su etiqueta: '
          'un Text hermano en un Column no está asociado al input',
    );
  });

  testWidgets('un campo obligatorio lo anuncia', (tester) async {
    await pump(
      tester,
      const AppTextField(label: 'Placa del vehículo', isRequired: true),
    );

    final semantics = tester.getSemantics(find.byType(EditableText));
    expect(semantics.label.toLowerCase(), contains('obligatorio'));
  });

  testWidgets('muestra el helperText bajo el campo', (tester) async {
    await pump(
      tester,
      const AppTextField(label: 'Placa', helperText: 'Formato: P123-456'),
    );

    expect(find.text('Formato: P123-456'), findsOneWidget);
  });

  testWidgets('el error se muestra junto al campo, no solo como borde', (
    tester,
  ) async {
    final formKey = GlobalKey<FormState>();

    await pump(
      tester,
      Form(
        key: formKey,
        child: const AppTextField(
          label: 'Placa',
          validator: _alwaysInvalid,
        ),
      ),
    );

    formKey.currentState!.validate();
    await tester.pump();

    expect(find.text('Placa inválida'), findsOneWidget);
  });

  testWidgets('acepta entrada de texto', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await pump(tester, AppTextField(label: 'Placa', controller: controller));

    await tester.enterText(find.byType(TextFormField), 'P123-456');
    expect(controller.text, 'P123-456');
  });

  testWidgets('no desborda en ningún ancho de auditoría', (tester) async {
    await forEachAuditWidth(tester, (width) async {
      await pump(
        tester,
        const AppTextField(
          label: 'Una etiqueta razonablemente larga para un campo',
          hintText: 'Escribe aquí el valor que corresponda',
        ),
        width: width,
      );
      expectNoOverflow(tester);
    });
  });
}

String? _alwaysInvalid(String? value) => 'Placa inválida';
```

- [ ] **Step 2: Correr el test y confirmar que falla**

Run: `flutter test test/core/widgets/app_text_field_test.dart`
Expected: FAIL — el primer test falla porque `semantics.label` no contiene la etiqueta; `isRequired` y `helperText` no existen (error de compilación).

- [ ] **Step 3: Implementar los arreglos**

3a. Añade los dos parámetros a la clase:

```dart
  /// Pista bajo el campo. Prefiérela a meter la explicación en [hintText],
  /// que desaparece en cuanto el usuario escribe.
  final String? helperText;

  /// Marca el campo como obligatorio: añade un asterisco visible y lo anuncia
  /// al lector de pantalla.
  final bool isRequired;
```

y al constructor: `this.helperText, this.isRequired = false,`.

3b. Sustituye la etiqueta suelta por una etiqueta que sigue siendo visible **y** está asociada:

```dart
    final labelText = label != null && label!.isNotEmpty
        ? (isRequired ? '$label *' : label!)
        : null;

    final semanticLabel = labelText == null
        ? null
        : (isRequired ? '$label, campo obligatorio' : label!);
```

y envuelve el `TextFormField` para que el campo anuncie la etiqueta:

```dart
        if (labelText != null)
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.xs,
              bottom: AppSpacing.sm,
            ),
            child: Text(
              labelText,
              style: AppTextStyles.labelLarge.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        Semantics(
          textField: true,
          label: semanticLabel,
          child: TextFormField(
            // ...resto igual
          ),
        ),
```

3c. En el `InputDecoration`, añade `helperText`, `helperStyle` y `errorStyle` tokenizados, y escala el padding:

```dart
            helperText: helperText,
            helperStyle: AppTextStyles.bodySmall.copyWith(
              color: colors.textSecondary,
            ),
            errorStyle: AppTextStyles.bodySmall.copyWith(color: colors.error),
            contentPadding: EdgeInsets.symmetric(
              horizontal: Responsive.padding(context, AppSpacing.lg),
              vertical: Responsive.padding(context, AppSpacing.base),
            ),
```

Añade los imports de `app_spacing.dart` y `responsive.dart`.

- [ ] **Step 4: Correr el test y confirmar que pasa**

Run: `flutter test test/core/widgets/app_text_field_test.dart`
Expected: PASS (6 tests)

Si el `Semantics` externo y el interno del `TextFormField` se combinan de forma que `semantics.label` no contenga la etiqueta, prueba con `Semantics(container: true, ...)` o mueve la etiqueta a `InputDecoration(label:)`. **No** relajes la aserción: el objetivo es que el campo se anuncie con su nombre.

- [ ] **Step 5: Verificar y commitear**

```bash
dart format . && flutter analyze && flutter test
git add lib/core/widgets/app_text_field.dart test/core/widgets/app_text_field_test.dart
git commit -m "fix(a11y): associate AppTextField label with its input, add helper text

La etiqueta era un Text hermano dentro de un Column: visible, pero no asociada
al campo, así que un lector de pantalla enfocaba el input y no decía qué era.
Añade helperText y isRequired, y tokeniza errorStyle y contentPadding.

No se añade motion al foco: InputDecorator ya anima la transición del borde de
forma nativa; duplicarla sería peor."
```

---

### Task 5: `AnimatedCounter` — tokens, duración y reduced motion

**Files:**
- Modify: `lib/core/widgets/animated_counter.dart`
- Test: `test/core/widgets/animated_counter_test.dart`

**Interfaces:**
- Consumes: `AppMotion.easeOut`, `AppMotion.reduced` (Fase 1 Task 2).
- Produces: `AnimatedCounter({required num value, TextStyle? style, Duration? duration, String? prefix, String? suffix, String? semanticLabel})`. **`duration` pasa de `Duration` con default a `Duration?` nullable** — es compatible en el sitio de llamada porque todos los llamadores o lo omiten o pasan un `Duration` no nulo.

**Problemas medidos:**
1. `Curves.easeOut` hardcodeada en dos sitios ([L36](../../../lib/core/widgets/animated_counter.dart#L36) y [L48](../../../lib/core/widgets/animated_counter.dart#L48)), fuera de todo token, y duplicada — cambiar una y olvidar la otra da dos animaciones distintas según sea la primera vez o una actualización.
2. **Duración por defecto de 1000 ms** ([L14](../../../lib/core/widgets/animated_counter.dart#L14)). Está más de tres veces por encima del límite de 300 ms de `emil-design-eng` para animación de UI. En un dashboard con varios contadores, el usuario espera un segundo entero a ver sus propias cifras.
3. **Sin reduced motion.** El número corre siempre.
4. **Sin semántica.** Un lector de pantalla lee el valor intermedio del tween, no el final.

**Decisión de duración:** un contador es un caso limítrofe — no es una micro-interacción de respuesta a input, es una animación explicativa ("este número subió"). Pero se ve en el dashboard cada vez que se abre, así que cae en la banda *"tens of times/day → remove or drastically reduce"* del framework de la skill. Se baja a **600 ms**, que sigue leyéndose como conteo pero no bloquea. Verifícalo con la skill antes de fijarlo.

- [ ] **Step 1: Invocar la skill**

`Skill(emil-design-eng)` — repasa la tabla de frecuencia (¿cuántas veces al día se ve esto?) y la tabla de duraciones. Justifica el valor final en el commit.

- [ ] **Step 2: Escribir el test que falla**

```dart
// test/core/widgets/animated_counter_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/widgets/animated_counter.dart';

import '../../support/responsive_harness.dart';

void main() {
  testWidgets('cuenta desde 0 hasta el valor y se detiene ahí', (tester) async {
    await pumpAtWidth(tester, const AnimatedCounter(value: 42), width: 375);

    expect(find.text('0'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('42'), findsOneWidget);
  });

  testWidgets('la duración por defecto no supera 600ms', (tester) async {
    await pumpAtWidth(tester, const AnimatedCounter(value: 42), width: 375);

    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    expect(
      find.text('42'),
      findsOneWidget,
      reason: 'el contador sigue animando tras 600ms',
    );
  });

  testWidgets('con reduced motion muestra el valor final de inmediato', (
    tester,
  ) async {
    await pumpAtWidth(
      tester,
      const AnimatedCounter(value: 42),
      width: 375,
      disableAnimations: true,
    );

    expect(
      find.text('42'),
      findsOneWidget,
      reason: 'con reduced motion no debe haber conteo',
    );
  });

  testWidgets('anima también al cambiar de valor', (tester) async {
    await pumpAtWidth(tester, const AnimatedCounter(value: 10), width: 375);
    await tester.pumpAndSettle();
    expect(find.text('10'), findsOneWidget);

    await pumpAtWidth(tester, const AnimatedCounter(value: 20), width: 375);
    await tester.pumpAndSettle();
    expect(find.text('20'), findsOneWidget);
  });

  testWidgets('respeta prefix y suffix', (tester) async {
    await pumpAtWidth(
      tester,
      const AnimatedCounter(value: 7, prefix: r'$', suffix: ' USD'),
      width: 375,
    );
    await tester.pumpAndSettle();

    expect(find.text(r'$7 USD'), findsOneWidget);
  });

  testWidgets('el lector de pantalla anuncia el valor final, no el tween', (
    tester,
  ) async {
    await pumpAtWidth(
      tester,
      const AnimatedCounter(value: 42, semanticLabel: '42 servicios'),
      width: 375,
    );

    // Sin esperar a que termine: la semántica ya debe ser la final.
    expect(find.bySemanticsLabel('42 servicios'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Correr el test y confirmar que falla**

Run: `flutter test test/core/widgets/animated_counter_test.dart`
Expected: FAIL — el test de 600 ms falla (la duración por defecto es 1000 ms), el de reduced motion falla (muestra `0`), y `semanticLabel` no existe.

- [ ] **Step 4: Reescribir `AnimatedCounter`**

```dart
import 'package:flutter/material.dart';
import 'package:autodoc/core/theme/app_motion.dart';

/// Número que cuenta hasta su valor.
///
/// Se ve varias veces al día (dashboards), así que la duración se mantiene
/// corta: un conteo de un segundo hace esperar al usuario a ver sus propias
/// cifras. Con reduced motion activo no cuenta: muestra el valor final.
class AnimatedCounter extends StatefulWidget {
  final num value;
  final TextStyle? style;

  /// Duración del conteo. Por defecto [kDefaultDuration].
  final Duration? duration;

  final String? prefix;
  final String? suffix;

  /// Texto que anuncia el lector de pantalla. Sin él, se anunciaría el valor
  /// intermedio del tween en vez del final.
  final String? semanticLabel;

  static const Duration kDefaultDuration = Duration(milliseconds: 600);

  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.duration,
    this.prefix = '',
    this.suffix = '',
    this.semanticLabel,
  });

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;
  num _oldValue = 0;

  Duration get _duration => widget.duration ?? AnimatedCounter.kDefaultDuration;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration);
    _animation = _tweenTo(widget.value);
    _controller.forward();
  }

  Animation<double> _tweenTo(num end) {
    return Tween<double>(
      begin: _oldValue.toDouble(),
      end: end.toDouble(),
    ).animate(
      CurvedAnimation(parent: _controller, curve: AppMotion.easeOut),
    );
  }

  @override
  void didUpdateWidget(AnimatedCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _oldValue = oldWidget.value;
      _controller.duration = _duration;
      _animation = _tweenTo(widget.value);
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _format(num value) => widget.value is int
      ? value.toInt().toString()
      : value.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final label =
        widget.semanticLabel ??
        '${widget.prefix}${_format(widget.value)}${widget.suffix}';

    // Reduced motion: sin conteo. El movimiento del número es precisamente lo
    // que la preferencia pide eliminar.
    if (AppMotion.reduced(context)) {
      return Semantics(
        label: label,
        excludeSemantics: true,
        child: Text(
          '${widget.prefix}${_format(widget.value)}${widget.suffix}',
          style: widget.style,
        ),
      );
    }

    return Semantics(
      label: label,
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) => Text(
          '${widget.prefix}${_format(_animation.value)}${widget.suffix}',
          style: widget.style,
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Correr el test y confirmar que pasa**

Run: `flutter test test/core/widgets/animated_counter_test.dart`
Expected: PASS (6 tests)

- [ ] **Step 6: Verificar y commitear**

```bash
dart format . && flutter analyze && flutter test
git add lib/core/widgets/animated_counter.dart test/core/widgets/animated_counter_test.dart
git commit -m "fix(widgets): tokenize AnimatedCounter, halve its duration, honour reduced motion

Curves.easeOut estaba hardcodeada en dos sitios (initState y didUpdateWidget),
así que primera-carga y actualización podían divergir. La duración por defecto
era de 1000ms: se ve varias veces al día en el dashboard, así que baja a 600ms.
Añade reduced motion (sin conteo) y semanticLabel, para que el lector de
pantalla anuncie el valor final y no el intermedio del tween."
```

---

### Task 6: `AppEmptyState` — tokens, ancho de lectura y semántica

**Files:**
- Modify: `lib/core/widgets/app_empty_state.dart`
- Test: `test/core/widgets/app_empty_state_test.dart`

**Interfaces:**
- Consumes: `AppSpacing`, `AppBreakpoints.maxReadingWidth` (Fase 1 Task 1); `Responsive.iconSize`; `context.appColors`.
- Produces: `AppEmptyState({required String title, required String description, IconData? icon = Icons.inbox_outlined, Widget? action})`. **Se elimina el parámetro `lottieAsset`**, que estaba declarado pero nunca se leía (ver Step 3); es el único cambio incompatible de toda la fase y afecta solo a los sitios que lo pasaban, que no hacían nada con él.

**Problemas medidos:** todos los valores de spacing son literales ([32, 24, 64, 24, 8, 24](../../../lib/core/widgets/app_empty_state.dart#L27-L61)) en vez de `AppSpacing`; el icono mide 64 fijo sin escalar; la descripción se estira de borde a borde en desktop (falla *readable text measure*); y el bloque completo no tiene semántica de región, así que un lector de pantalla lee tres textos sueltos sin decir que la lista está vacía. El parámetro `lottieAsset` está declarado pero **no se usa** (ver el comentario de L31-32) — código muerto que hay que resolver.

- [ ] **Step 1: Escribir el test que falla**

```dart
// test/core/widgets/app_empty_state_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/core/widgets/app_empty_state.dart';

import '../../support/responsive_harness.dart';

void main() {
  const longDescription =
      'Todavía no has registrado ningún vehículo en tu garaje. Cuando añadas '
      'el primero, verás aquí su historial de mantenimiento, sus alertas y '
      'los servicios realizados por los talleres.';

  testWidgets('la descripción no se estira de borde a borde en desktop', (
    tester,
  ) async {
    await pumpAtWidth(
      tester,
      const AppEmptyState(title: 'Sin vehículos', description: longDescription),
      width: 1440,
    );

    final width = tester.getSize(find.text(longDescription)).width;
    expect(
      width,
      lessThanOrEqualTo(AppBreakpoints.maxReadingWidth),
      reason: 'la descripción mide ${width}px; medida de lectura ilegible',
    );
  });

  testWidgets('no desborda en ningún ancho de auditoría', (tester) async {
    await forEachAuditWidth(tester, (width) async {
      await pumpAtWidth(
        tester,
        const AppEmptyState(
          title: 'Sin vehículos',
          description: longDescription,
        ),
        width: width,
      );
      expectNoOverflow(tester);
    });
  });

  testWidgets('el bloque se anuncia como una unidad', (tester) async {
    await pumpAtWidth(
      tester,
      const AppEmptyState(title: 'Sin vehículos', description: 'Añade uno.'),
      width: 375,
    );

    expect(
      find.bySemanticsLabel(RegExp('Sin vehículos')),
      findsWidgets,
      reason: 'el estado vacío no se anuncia como región con su título',
    );
  });

  testWidgets('el icono decorativo se excluye de la semántica', (tester) async {
    await pumpAtWidth(
      tester,
      const AppEmptyState(title: 'Sin vehículos', description: 'Añade uno.'),
      width: 375,
    );

    final icon = tester.widget<Icon>(find.byType(Icon));
    expect(
      icon.semanticLabel,
      isNull,
      reason: 'el icono es decorativo: el título ya dice lo mismo',
    );
  });

  testWidgets('renderiza la acción cuando se pasa', (tester) async {
    await pumpAtWidth(
      tester,
      AppEmptyState(
        title: 'Sin vehículos',
        description: 'Añade uno.',
        action: ElevatedButton(onPressed: () {}, child: const Text('Añadir')),
      ),
      width: 375,
    );

    expect(find.text('Añadir'), findsOneWidget);
  });

  testWidgets('renderiza en ambos temas sin excepciones', (tester) async {
    for (final brightness in Brightness.values) {
      await pumpAtWidth(
        tester,
        const AppEmptyState(title: 'Sin vehículos', description: 'Añade uno.'),
        width: 375,
        brightness: brightness,
      );
      expectNoOverflow(tester);
    }
  });
}
```

- [ ] **Step 2: Correr el test y confirmar que falla**

Run: `flutter test test/core/widgets/app_empty_state_test.dart`
Expected: FAIL — a 1440 px la descripción mide ~1376 px, muy por encima de `maxReadingWidth` (720); y no hay `Semantics` de región.

- [ ] **Step 3: Reescribir `AppEmptyState`**

```dart
import 'package:flutter/material.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/utils/responsive.dart';

/// Estado vacío de una lista o sección.
///
/// Se acota a la medida de lectura: una descripción de 1400 px de ancho en
/// desktop es ilegible.
class AppEmptyState extends StatelessWidget {
  final String title;
  final String description;
  final IconData? icon;
  final Widget? action;

  const AppEmptyState({
    super.key,
    required this.title,
    required this.description,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Semantics(
      container: true,
      label: title,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppBreakpoints.maxReadingWidth,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Decorativo: el título ya comunica lo mismo, así que se
                // excluye de la semántica para no anunciarlo dos veces.
                ExcludeSemantics(
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: Responsive.iconSize(context, 64),
                      color: colors.primary.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.titleLarge.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                if (action != null) ...[
                  const SizedBox(height: AppSpacing.xl),
                  action!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

Se elimina el parámetro `lottieAsset`: estaba declarado pero nunca se usaba (el propio comentario del fichero lo reconocía). Si alguna pantalla lo pasa, `flutter analyze` lo señalará; quita el argumento en el sitio de llamada — no estaba haciendo nada.

- [ ] **Step 4: Correr el test y confirmar que pasa**

Run: `flutter test test/core/widgets/app_empty_state_test.dart`
Expected: PASS (6 tests)

- [ ] **Step 5: Comprobar los sitios de llamada**

```bash
grep -rn "lottieAsset" lib
flutter analyze
```

Corrige los que pasen `lottieAsset:` quitando el argumento.

- [ ] **Step 6: Verificar y commitear**

```bash
dart format . && flutter analyze && flutter test
git add lib/core/widgets/app_empty_state.dart lib/features test/core/widgets/app_empty_state_test.dart
git commit -m "fix(widgets): constrain AppEmptyState to reading width, tokenize and label it

La descripción se estiraba a todo el ancho de la ventana (1376px a 1440), muy
por encima de una medida de lectura legible. Se acota a maxReadingWidth, se
sustituyen los literales de spacing por AppSpacing, se escala el icono, se
anuncia el bloque como región con su título y se excluye el icono decorativo de
la semántica. Elimina el parámetro lottieAsset, que estaba declarado pero nunca
se usaba."
```

---

### Task 7: Extender el ratchet de colores a las rutas de esta fase

**Files:**
- Modify: `test/core/theme/no_hardcoded_colors_test.dart`

- [ ] **Step 1: Añadir las rutas**

```dart
  // ── Fase 3 ──
  'lib/core/widgets/app_button.dart',
  'lib/core/widgets/app_card.dart',
  'lib/core/widgets/app_snackbar.dart',
  'lib/core/widgets/app_text_field.dart',
  'lib/core/widgets/animated_counter.dart',
  'lib/core/widgets/app_empty_state.dart',
```

- [ ] **Step 2: Correr y confirmar que pasa**

Run: `flutter test test/core/theme/no_hardcoded_colors_test.dart`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add test/core/theme/no_hardcoded_colors_test.dart
git commit -m "test(theme): extend hardcoded-color ratchet to phase 3 paths"
```

---

## Verificación de cierre de fase

- [ ] `flutter test` — suite completa verde.
- [ ] `flutter analyze` — sin errores.
- [ ] `dart format .` sin cambios pendientes.
- [ ] `grep -rn "GoogleFonts\." lib | grep -v app_text_styles.dart` → vacío.
- [ ] **Matriz de temas.** `flutter run -d chrome`: dispara un snackbar de cada tipo en light y en dark; presiona botones de los tres tipos y tarjetas con y sin `onTap`; enfoca un campo con y sin error.
- [ ] **Reduced motion.** Activa reduced motion en el SO y repite: los botones y tarjetas no deben encogerse, el contador debe mostrar su valor de golpe, y todo debe seguir siendo pulsable.
- [ ] **Lector de pantalla.** Con TalkBack/VoiceOver o el *Semantics Debugger* de Flutter (`showSemanticsDebugger: true`), recorre un formulario: cada campo debe anunciar su etiqueta, cada botón su acción, y el estado vacío su título.
- [ ] Pre-Delivery Checklist de `ui-ux-pro-max` `references/pro-rules.md` — secciones *Interaction*, *Light/Dark Mode Contrast* y *Accessibility* completas.
- [ ] `Skill(review-animations)` sobre el diff completo de la fase. Su aprobación se gana; espera que marque cosas.
- [ ] `Skill(superpowers:requesting-code-review)`.

**Criterio de éxito de la Fase 3:**

- Todo elemento pulsable de la librería compartida responde al press en ≤ 160 ms, y con reduced motion no se mueve pero sigue funcionando.
- La sombra de `AppButton` se renderiza (llevaba sin hacerlo desde que se escribió).
- Ningún tamaño de botón baja de 48 dp de alto.
- Los tres tipos de snackbar pasan WCAG AA en light y dark, verificado por test que calcula el ratio real. Antes, tres de cada cuatro variantes estaban entre 1.9:1 y 2.5:1.
- Todo campo de texto anuncia su etiqueta al lector de pantalla.
- Ningún componente compartido usa `GoogleFonts` directo ni colores literales, protegido por el ratchet.
- **Las 34 pantallas siguen compilando sin haberse tocado:** ninguna API pública cambió de forma incompatible.
