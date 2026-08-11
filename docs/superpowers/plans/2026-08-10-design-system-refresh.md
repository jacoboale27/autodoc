# Design System Refresh (Fase 0) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Pulir el lenguaje de interacción (press/hover) y motion de los widgets compartidos de AutoDoc (`lib/core/theme/`, `lib/core/widgets/`) sin cambiar marca, layout ni flujos, dejando una base lista para que las fases posteriores (una por módulo de pantallas) la consuman.

**Architecture:** Se añade un token nuevo (`AppMotion`) que centraliza curvas/escala de press-hover, se extiende `AppShadows` con variantes de hover, y se agregan getters derivados a `AppColors`. `AppButton` y `AppCard` pasan de `StatelessWidget` a `StatefulWidget` para trackear estado de press/hover local y animarlo con `AnimatedScale` + `MouseRegion` (hover) + `Listener` (press, eventos de puntero crudo — no compite en el gesture arena con el `InkWell` interno), manteniendo `InkWell`/`Material` para ripple, tap real, foco y accesibilidad. `AnimatedCounter` deja de usar una curva hardcodeada.

**Tech Stack:** Flutter (Material 3), sin dependencias nuevas — todo con `AnimatedScale`, `MouseRegion`, `GestureDetector` del SDK. Tests con `flutter_test` (`WidgetTester`).

## Global Constraints

- No modificar `lib/features/**` (pantallas) — spec: "Fuera de alcance (explícito)".
- No cambiar la paleta de colores (`AppPalette.light*`/`dark*`) ni `AppTextStyles`.
- No agregar campos nuevos a la `ThemeExtension` `AppColors` (evitar tocar `copyWith`/`lerp`) — usar getters derivados en su lugar.
- No agregar golden tests de píxel — usar widget tests de comportamiento.
- Ejecutar `dart format .` antes de cada commit (regla del proyecto, `CONVENTIONS.md` §4).
- Todo widget nuevo/modificado debe seguir usando `Theme.of(context)`/`context.appColors` — nunca colores hardcodeados (`CONVENTIONS.md` §2.1).

---

### Task 1: `AppMotion` tokens

**Files:**
- Create: `lib/core/theme/app_motion.dart`
- Test: `test/core/theme/app_motion_test.dart`

**Interfaces:**
- Produces: `AppMotion.spring` (`Curve`), `AppMotion.pressedScale` (`double`, `0.96`), `AppMotion.pressDuration` (`Duration`, `100ms`), `AppMotion.hoverScale` (`double`, `1.02`), `AppMotion.hoverDuration` (`Duration`, `150ms`). Consumido por Task 4, 5.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/theme/app_motion_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/theme/app_motion.dart';

void main() {
  test('AppMotion press constants describe a subtle, quick shrink', () {
    expect(AppMotion.pressedScale, lessThan(1.0));
    expect(AppMotion.pressedScale, greaterThan(0.9));
    expect(AppMotion.pressDuration, const Duration(milliseconds: 100));
  });

  test('AppMotion hover constants describe a subtle, quick lift', () {
    expect(AppMotion.hoverScale, greaterThan(1.0));
    expect(AppMotion.hoverScale, lessThan(1.1));
    expect(AppMotion.hoverDuration, const Duration(milliseconds: 150));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/theme/app_motion_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'autodoc/core/theme/app_motion.dart'` (file doesn't exist yet).

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/core/theme/app_motion.dart
import 'package:flutter/animation.dart';

/// Curvas y constantes de interacción (press/hover) compartidas por los
/// widgets tappable de lib/core/widgets/. Las duraciones "generales" de
/// transición de página/estado siguen viviendo en AppTransitions.
class AppMotion {
  static const Curve spring = Curves.easeOutBack;

  static const double pressedScale = 0.96;
  static const Duration pressDuration = Duration(milliseconds: 100);

  static const double hoverScale = 1.02;
  static const Duration hoverDuration = Duration(milliseconds: 150);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/theme/app_motion_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/core/theme/app_motion.dart test/core/theme/app_motion_test.dart
git commit -m "feat(theme): add AppMotion press/hover tokens"
```

---

### Task 2: `AppShadows` hover variants

**Files:**
- Modify: `lib/core/theme/app_shadows.dart`
- Test: `test/core/theme/app_shadows_test.dart`

**Interfaces:**
- Consumes: none.
- Produces: `AppShadows.lightHover` (`List<BoxShadow>`), `AppShadows.darkHover` (`List<BoxShadow>`). Consumido por Task 4, 5.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/theme/app_shadows_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/theme/app_shadows.dart';

void main() {
  test('lightHover sits between lightMd and lightLg in intensity', () {
    final hover = AppShadows.lightHover.first;
    final md = AppShadows.lightMd.first;
    final lg = AppShadows.lightLg.first;

    expect(hover.blurRadius, greaterThan(md.blurRadius));
    expect(hover.blurRadius, lessThan(lg.blurRadius));
    expect(hover.offset.dy, greaterThan(md.offset.dy));
    expect(hover.offset.dy, lessThan(lg.offset.dy));
  });

  test('darkHover sits between darkMd and darkLg in intensity', () {
    final hover = AppShadows.darkHover.first;
    final md = AppShadows.darkMd.first;
    final lg = AppShadows.darkLg.first;

    expect(hover.blurRadius, greaterThan(md.blurRadius));
    expect(hover.blurRadius, lessThan(lg.blurRadius));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/theme/app_shadows_test.dart`
Expected: FAIL — `The getter 'lightHover' isn't defined for the class 'AppShadows'`.

- [ ] **Step 3: Write minimal implementation**

Add to `lib/core/theme/app_shadows.dart`, after `lightMd` (before `lightLg`):

```dart
  static List<BoxShadow> lightHover = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.10),
      blurRadius: 14,
      offset: const Offset(0, 6),
    ),
  ];
```

And after `darkMd` (before `darkLg`):

```dart
  static List<BoxShadow> darkHover = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.35),
      blurRadius: 14,
      offset: const Offset(0, 6),
    ),
  ];
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/theme/app_shadows_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/core/theme/app_shadows.dart test/core/theme/app_shadows_test.dart
git commit -m "feat(theme): add AppShadows hover elevation variants"
```

---

### Task 3: `AppColors` overlay getters

**Files:**
- Modify: `lib/core/theme/app_colors.dart`
- Test: `test/core/theme/app_colors_overlay_test.dart`

**Interfaces:**
- Consumes: none.
- Produces: `AppColors.hoverOverlay` (`Color` getter), `AppColors.pressedOverlay` (`Color` getter). Not consumed by later tasks in this plan (available for future module phases), but must exist per spec.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/theme/app_colors_overlay_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/theme/app_colors.dart';

void main() {
  const colors = AppColors(
    primary: Color(0xFF522C81),
    secondary: Color(0xFF81E6D9),
    surface: Color(0xFFF7F6F8),
    surfaceContainer: Color(0xFFEEEDF0),
    error: Color(0xFFFC8181),
    warning: Color(0xFFF6AD55),
    success: Color(0xFF48BB78),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF64748B),
    onPrimary: Colors.white,
    onSecondary: Color(0xFF0F172A),
    surfaceVariant: Color(0xFFE2E8F0),
    outline: Color(0xFFCBD5E1),
    shimmerBase: Color(0xFFE2E8F0),
    shimmerHighlight: Color(0xFFF1F5F9),
  );

  test('hoverOverlay and pressedOverlay are derived from primary', () {
    expect(colors.hoverOverlay.a, closeTo(0.06, 0.001));
    expect(colors.pressedOverlay.a, closeTo(0.12, 0.001));
    expect(colors.pressedOverlay.a, greaterThan(colors.hoverOverlay.a));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/theme/app_colors_overlay_test.dart`
Expected: FAIL — `The getter 'hoverOverlay' isn't defined for the class 'AppColors'`.

- [ ] **Step 3: Write minimal implementation**

In `lib/core/theme/app_colors.dart`, add getters to the `AppColors` class, right after the `lerp` override closes (before the class's closing `}`):

```dart
  /// Overlay derivado de [primary] para estados de hover (web/desktop).
  Color get hoverOverlay => primary.withValues(alpha: 0.06);

  /// Overlay derivado de [primary] para estados de press.
  Color get pressedOverlay => primary.withValues(alpha: 0.12);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/theme/app_colors_overlay_test.dart`
Expected: PASS (1 test)

- [ ] **Step 5: Commit**

```bash
git add lib/core/theme/app_colors.dart test/core/theme/app_colors_overlay_test.dart
git commit -m "feat(theme): add AppColors hover/pressed overlay getters"
```

---

### Task 4: `AppButton` press-scale, hover lift, shadow fix

**Files:**
- Modify: `lib/core/widgets/app_button.dart`
- Test: `test/core/widgets/app_button_test.dart`

**Interfaces:**
- Consumes: `AppMotion.pressedScale`, `AppMotion.pressDuration`, `AppMotion.hoverScale`, `AppMotion.hoverDuration` (Task 1); `AppShadows.lightHover`/`darkHover`/`lightSm`/`darkSm` (Task 2, `lightSm`/`darkSm` already existed).
- Produces: same public API as before (`AppButton({text, onPressed, type, size, isLoading, hapticFeedback, icon})`) — no breaking changes for the ~36 screens that use it.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/widgets/app_button_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/core/theme/app_motion.dart';
import 'package:autodoc/core/widgets/app_button.dart';

void main() {
  Widget wrap(Widget child) =>
      MaterialApp(theme: AppTheme.light, home: Scaffold(body: Center(child: child)));

  testWidgets('AppButton scales down on tapDown and back up on release', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(AppButton(text: 'Guardar', onPressed: () {})),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(AppButton)),
    );
    await tester.pump();

    var scaleWidget = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(scaleWidget.scale, AppMotion.pressedScale);

    await gesture.up();
    await tester.pump();

    scaleWidget = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(scaleWidget.scale, 1.0);
  });

  testWidgets('tapping AppButton still triggers onPressed', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      wrap(AppButton(text: 'Guardar', onPressed: () => tapped = true)),
    );

    await tester.tap(find.byType(AppButton));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/widgets/app_button_test.dart`
Expected: FAIL — `AnimatedScale` finder returns nothing (current `AppButton` has no `AnimatedScale`).

- [ ] **Step 3: Write minimal implementation**

Replace the full contents of `lib/core/widgets/app_button.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/theme/app_radius.dart';
import 'package:autodoc/core/theme/app_shadows.dart';
import 'package:autodoc/core/theme/app_motion.dart';
import 'package:autodoc/core/utils/responsive.dart';

enum AppButtonType { primary, secondary, text }

enum AppButtonSize { small, medium, large }

class AppButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final AppButtonType type;
  final AppButtonSize size;
  final bool isLoading;
  final bool hapticFeedback;
  final Widget? icon;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.type = AppButtonType.primary,
    this.size = AppButtonSize.medium,
    this.isLoading = false,
    this.hapticFeedback = true,
    this.icon,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _isPressed = false;
  bool _isHovered = false;

  bool get _interactive => widget.onPressed != null && !widget.isLoading;

  void _handlePress() {
    if (!_interactive) return;
    if (widget.hapticFeedback) {
      HapticFeedback.lightImpact();
    }
    widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color backgroundColor;
    Color foregroundColor;
    List<Color>? gradientColors;

    switch (widget.type) {
      case AppButtonType.primary:
        backgroundColor = colors.primary;
        foregroundColor = colors.onPrimary;
        gradientColors = [
          colors.primary,
          colors.primary.withValues(alpha: 0.85),
        ];
        break;
      case AppButtonType.secondary:
        backgroundColor = colors.secondary;
        foregroundColor = colors.onSecondary;
        break;
      case AppButtonType.text:
        backgroundColor = Colors.transparent;
        foregroundColor = colors.primary;
        break;
    }

    EdgeInsets btnPadding;
    TextStyle textStyle;
    double btnIconSize;

    switch (widget.size) {
      case AppButtonSize.small:
        btnPadding = EdgeInsets.symmetric(
          vertical: Responsive.padding(context, 8),
          horizontal: Responsive.padding(context, 16),
        );
        textStyle = AppTextStyles.labelMedium;
        btnIconSize = Responsive.iconSize(context, 16);
        break;
      case AppButtonSize.medium:
        btnPadding = EdgeInsets.symmetric(
          vertical: Responsive.padding(context, 14),
          horizontal: Responsive.padding(context, 24),
        );
        textStyle = AppTextStyles.titleSmall;
        btnIconSize = Responsive.iconSize(context, 20);
        break;
      case AppButtonSize.large:
        btnPadding = EdgeInsets.symmetric(
          vertical: Responsive.padding(context, 18),
          horizontal: Responsive.padding(context, 32),
        );
        textStyle = AppTextStyles.titleMedium;
        btnIconSize = Responsive.iconSize(context, 24);
        break;
    }

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.full),
    );

    final textWidget = Text(
      widget.text,
      style: textStyle.copyWith(color: foregroundColor),
    );

    Widget childContent;
    if (widget.isLoading) {
      childContent = SizedBox(
        height: btnIconSize,
        width: btnIconSize,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
        ),
      );
    } else if (widget.icon != null) {
      childContent = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconTheme(
            data: IconThemeData(size: btnIconSize, color: foregroundColor),
            child: widget.icon!,
          ),
          const SizedBox(width: 8),
          textWidget,
        ],
      );
    } else {
      childContent = textWidget;
    }

    Widget buttonContent = Padding(
      padding: btnPadding,
      child: childContent,
    );

    if (widget.isLoading && widget.type != AppButtonType.text) {
      buttonContent = buttonContent
          .animate(onPlay: (c) => c.repeat())
          .shimmer(
            duration: 1500.ms,
            color: Colors.white.withValues(alpha: 0.2),
          );
    }

    final restShadow = isDark ? AppShadows.darkSm : AppShadows.lightSm;
    final hoverShadow = isDark ? AppShadows.darkHover : AppShadows.lightHover;
    final showsShadow = widget.type != AppButtonType.text;

    Widget surface = Ink(
      decoration: BoxDecoration(
        color: gradientColors == null ? backgroundColor : null,
        gradient: gradientColors != null
            ? LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        borderRadius: BorderRadius.circular(AppRadius.full),
        boxShadow: !showsShadow
            ? null
            : (_isHovered ? hoverShadow : restShadow),
      ),
      child: buttonContent,
    );

    surface = Material(
      color: Colors.transparent,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _interactive ? _handlePress : null,
        customBorder: shape,
        child: surface,
      ),
    );

    return MouseRegion(
      onEnter: _interactive ? (_) => setState(() => _isHovered = true) : null,
      onExit: _interactive ? (_) => setState(() => _isHovered = false) : null,
      cursor: _interactive ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: Listener(
        onPointerDown: _interactive
            ? (_) => setState(() => _isPressed = true)
            : null,
        onPointerUp: _interactive
            ? (_) => setState(() => _isPressed = false)
            : null,
        onPointerCancel: _interactive
            ? (_) => setState(() => _isPressed = false)
            : null,
        child: AnimatedScale(
          scale: _isPressed ? AppMotion.pressedScale : 1.0,
          duration: AppMotion.pressDuration,
          curve: Curves.easeOut,
          child: surface,
        ),
      ),
    );
  }
}
```

`Listener` se usa (en vez de un segundo `GestureDetector`) porque sus callbacks de puntero crudo se disparan siempre, sin competir en el "gesture arena" contra el `TapGestureRecognizer` interno de `InkWell` — así el feedback visual de press nunca bloquea el `onTap` real.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/widgets/app_button_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: Run the full widget test suite to check for regressions**

Run: `flutter test`
Expected: PASS — no test elsewhere constructs `AppButton` and expects the old `ElevatedButton`/`TextButton` internals directly. If any test does `find.byType(ElevatedButton)` inside an `AppButton` tree, fix that test's finder to `find.byType(AppButton)` or `find.byType(InkWell)`.

- [ ] **Step 6: Commit**

```bash
git add lib/core/widgets/app_button.dart test/core/widgets/app_button_test.dart
git commit -m "fix(widgets): AppButton press-scale, hover lift, and fix broken shadow"
```

---

### Task 5: `AppCard` press-scale and hover lift when tappable

**Files:**
- Modify: `lib/core/widgets/app_card.dart`
- Test: `test/core/widgets/app_card_test.dart`

**Interfaces:**
- Consumes: `AppMotion.pressedScale`, `AppMotion.pressDuration` (Task 1); `AppShadows.lightHover`/`darkHover` (Task 2).
- Produces: same public API (`AppCard({child, padding, margin, onTap})`).

- [ ] **Step 1: Write the failing test**

```dart
// test/core/widgets/app_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/core/theme/app_motion.dart';
import 'package:autodoc/core/widgets/app_card.dart';

void main() {
  Widget wrap(Widget child) =>
      MaterialApp(theme: AppTheme.light, home: Scaffold(body: Center(child: child)));

  testWidgets('AppCard scales down on tapDown when onTap is set', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(AppCard(onTap: () {}, child: const Text('contenido'))),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(AppCard)),
    );
    await tester.pump();

    var scaleWidget = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(scaleWidget.scale, AppMotion.pressedScale);

    await gesture.up();
    await tester.pump();

    scaleWidget = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(scaleWidget.scale, 1.0);
  });

  testWidgets('AppCard has no AnimatedScale when onTap is null', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const AppCard(child: Text('contenido'))));

    expect(find.byType(AnimatedScale), findsNothing);
  });

  testWidgets('tapping a tappable AppCard still triggers onTap', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      wrap(AppCard(onTap: () => tapped = true, child: const Text('contenido'))),
    );

    await tester.tap(find.byType(AppCard));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/widgets/app_card_test.dart`
Expected: FAIL — no `AnimatedScale` in the current `AppCard`.

- [ ] **Step 3: Write minimal implementation**

Replace the full contents of `lib/core/widgets/app_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_radius.dart';
import 'package:autodoc/core/theme/app_shadows.dart';
import 'package:autodoc/core/theme/app_motion.dart';
import 'package:autodoc/core/utils/responsive.dart';

class AppCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
    this.margin = const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
    this.onTap,
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
    final rSize = Responsive.size(context, AppRadius.lg);

    final restShadow = isDark ? AppShadows.darkSm : AppShadows.lightSm;
    final hoverShadow = isDark ? AppShadows.darkHover : AppShadows.lightHover;

    final card = Container(
      margin: widget.margin,
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(rSize),
        boxShadow: _interactive && _isHovered ? hoverShadow : restShadow,
        border: Border.all(
          color: colors.outline.withValues(alpha: isDark ? 0.2 : 0.4),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(rSize),
          child: Padding(padding: widget.padding, child: widget.child),
        ),
      ),
    );

    if (!_interactive) {
      return card;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: Listener(
        onPointerDown: (_) => setState(() => _isPressed = true),
        onPointerUp: (_) => setState(() => _isPressed = false),
        onPointerCancel: (_) => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? AppMotion.pressedScale : 1.0,
          duration: AppMotion.pressDuration,
          curve: Curves.easeOut,
          child: card,
        ),
      ),
    );
  }
}
```

Igual que en `AppButton` (Task 4), se usa `Listener` en vez de un segundo `GestureDetector` para no competir con el `TapGestureRecognizer` interno del `InkWell` por el "gesture arena".

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/widgets/app_card_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: Run the full widget test suite to check for regressions**

Run: `flutter test`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/core/widgets/app_card.dart test/core/widgets/app_card_test.dart
git commit -m "feat(widgets): AppCard press-scale and hover lift when tappable"
```

---

### Task 6: `AnimatedCounter` uses `AppTransitions.defaultCurve` instead of a hardcoded curve

**Files:**
- Modify: `lib/core/widgets/animated_counter.dart`
- Test: `test/core/widgets/animated_counter_test.dart`

**Interfaces:**
- Consumes: `AppTransitions.defaultCurve` (already existed in `lib/core/theme/app_transitions.dart`).
- Produces: same public API (`AnimatedCounter({value, style, duration, prefix, suffix})`).

- [ ] **Step 1: Write the failing test**

```dart
// test/core/widgets/animated_counter_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/theme/app_transitions.dart';
import 'package:autodoc/core/widgets/animated_counter.dart';

void main() {
  testWidgets('AnimatedCounter drives its animation with AppTransitions.defaultCurve', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AnimatedCounter(value: 10))),
    );

    final animatedBuilder = tester.widget<AnimatedBuilder>(
      find.byType(AnimatedBuilder),
    );
    final animation = animatedBuilder.animation as CurvedAnimation;

    expect(animation.curve, AppTransitions.defaultCurve);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/widgets/animated_counter_test.dart`
Expected: FAIL — `animation.curve` is `Curves.easeOut`, not `AppTransitions.defaultCurve` (`Curves.easeInOut`), so the equality check fails.

- [ ] **Step 3: Write minimal implementation**

In `lib/core/widgets/animated_counter.dart`, add the import and replace both occurrences of `Curves.easeOut`:

```dart
import 'package:flutter/material.dart';
import 'package:autodoc/core/theme/app_transitions.dart';
```

```dart
    _animation = Tween<double>(
      begin: _oldValue.toDouble(),
      end: widget.value.toDouble(),
    ).animate(
      CurvedAnimation(parent: _controller, curve: AppTransitions.defaultCurve),
    );
```

(apply this replacement in both `initState` and `didUpdateWidget`).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/widgets/animated_counter_test.dart`
Expected: PASS (1 test)

- [ ] **Step 5: Commit**

```bash
git add lib/core/widgets/animated_counter.dart test/core/widgets/animated_counter_test.dart
git commit -m "refactor(widgets): AnimatedCounter uses AppTransitions.defaultCurve"
```

---

### Task 7: Full verification pass

**Files:** none created/modified — this task only runs checks.

**Interfaces:**
- Consumes: all of the above.
- Produces: nothing consumed by later tasks (this is the last task of Fase 0).

- [ ] **Step 1: Run static analysis**

Run: `flutter analyze`
Expected: no new warnings/errors compared to the pre-Fase-0 baseline. If `flutter analyze` reports pre-existing issues unrelated to `app_motion.dart`/`app_shadows.dart`/`app_colors.dart`/`app_button.dart`/`app_card.dart`/`animated_counter.dart`, ignore them (out of scope) — only fix issues in files this plan touched.

- [ ] **Step 2: Format**

Run: `dart format .`
Expected: exits 0. If it reformats any file from this plan, stage the reformatted version.

- [ ] **Step 3: Run the full test suite**

Run: `flutter test`
Expected: PASS, including all tests added in Tasks 1–6 and every pre-existing test (no regression).

- [ ] **Step 4: Manual visual check on Chrome**

Run: `flutter run -d chrome`

Navigate to a screen that renders `AppButton`+`AppCard` heavily, e.g. `dashboard_screen.dart` (via the app's normal auth/dashboard flow) and `user_profile_screen.dart`. Confirm:
- Buttons show a visible shadow (previously invisible — Task 4 bug fix).
- Hovering a button/card with the mouse (desktop Chrome) shows a subtle lift (shadow gets slightly stronger).
- Clicking and holding a button/card shows a subtle shrink (scale ~0.96) that releases on mouse-up.
- No layout shift, no color/typography change versus before this plan.

Stop the run once confirmed (`q` in the terminal running `flutter run`).

- [ ] **Step 5: Commit any formatting-only changes surfaced in Step 2**

```bash
git add -A
git status
```

If `dart format .` changed anything beyond what was already committed in Tasks 1–6, commit it:

```bash
git commit -m "chore: dart format after design-system-refresh Fase 0"
```

If there is nothing to commit, skip this step.

---

## Self-Review Notes (already applied above)

- Spec coverage: `AppMotion` (Task 1), `AppShadows` hover (Task 2), `AppColors` overlays (Task 3), `AppButton` fix+press+hover (Task 4), `AppCard` press+hover (Task 5), `AnimatedCounter` curve (Task 6), verification (Task 7) — every item in the spec's "Diseño" and "Testing" sections maps to a task. Items explicitly marked out-of-scope in the spec (`AppTextField`, `AppSkeleton`, `AppSnackbar`, `AppStatusBadge`, `AppBottomNavBar`, `AppTopNavBar`, `NotificationBellButton`, `AppEmptyState`, `lib/features/**`, color palette, typography) have no task — correct, per spec.
- Type consistency: `AppMotion.pressedScale`/`pressDuration`/`hoverScale`/`hoverDuration` (Task 1) are used with the same names in Task 4/5. `AppShadows.lightHover`/`darkHover` (Task 2) used with the same names in Task 4/5. `AppColors.hoverOverlay`/`pressedOverlay` (Task 3) are defined but intentionally unused within this plan (available for future phases per spec).
