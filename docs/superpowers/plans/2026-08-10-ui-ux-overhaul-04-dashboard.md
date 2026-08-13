# Fase 4 — Módulo Dashboard (9 pantallas del rol Propietario) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: `superpowers:subagent-driven-development` (recomendado) o `superpowers:executing-plans`.
>
> **REQUIRED DESIGN SKILLS.** Antes de la Task 1 invoca `Skill(ui-ux-pro-max:ui-ux-pro-max)`. Antes de cualquier tarea que toque motion (Tasks 5, 11) invoca `Skill(emil-design-eng)`. Al **inicio** de la fase corre una vez `Skill(find-animation-opportunities)` sobre `lib/features/dashboard/` y adjunta su salida al PR. Al **cierre**, `Skill(review-animations)` sobre el diff.
>
> **PRERREQUISITO:** Fases 1, 2 y 3 completas y mergeadas. Esta fase consume `AppBreakpoints`/`WindowClass`, `AppMotion`, `AppPageBody`, `AppGrid`, `AppButton`/`AppCard`/`AppEmptyState`/`AppTextField` ya pulidos, y el harness `pumpAtWidth`/`kAuditWidths`/`expectNoOverflow`.
>
> **CONTEXTO OBLIGATORIO:** `...-00-master.md` §2 (Global Constraints), §3 (window size classes) y §5.1 (contrato por pantalla de este módulo).

**Goal:** Que las 9 pantallas del rol Propietario cambien de estructura —no solo de escala— en 600 / 840 / 1200 px, dejen de re-derivar la paleta a mano, cumplan el mínimo de 48 dp y dejen de comunicar severidad únicamente con color.

**Architecture:** Se extraen primero dos primitivas compartidas que el módulo duplica cuatro y cinco veces respectivamente (`AppSeverity`, `AppSectionHeader`), y después se migra pantalla a pantalla. Las pantallas grandes (800–1200 líneas) se editan **quirúrgicamente** —bloques concretos anclados a línea— no se reescriben enteras: reescribir un fichero de 1200 líneas desde un plan es la vía más rápida a una regresión silenciosa.

**Tech Stack:** Flutter Material 3, Provider, go_router. Sin dependencias nuevas.

## Global Constraints

Heredadas de `...-00-master.md` §2. Las que muerden en esta fase, con su medición:

- **Cero `GoogleFonts.*` fuera de `app_text_styles.dart`.** El módulo lo viola **52 veces**: `dashboard_screen` 13, `alerts_screen` 12, `service_history_screen` 9, `vehicle_profile_screen` 8, `task_complete_screen` 14 (contando helpers), `garage_screen` 6, `task_config_screen` 6, `workshop_directory_screen` 8. Todas pasan a `AppTextStyles.*`.
- **Cero colores literales.** Medidos: `task_complete_screen` 19, `workshop_directory_screen` 22, `service_history_screen` 11, `alerts_screen` 8, `vehicle_profile_screen` 7, `dashboard_screen` 7, `garage_screen` 5, `notifications_screen` 1. Excepción: `Colors.transparent`.
- **Touch targets ≥ 48 dp.** Infracciones concretas: `alerts_screen._buildCompactActionButton` fija `minimumSize: Size(0, 40)` **y** `tapTargetSize: MaterialTapTargetSize.shrinkWrap`, que desactiva el relleno automático de Material; `alerts_screen._buildTabs` (~30 dp); `service_history_screen._buildFilterTab` (~34 dp); `alerts_screen._buildMileageChip` usa un `GestureDetector` sobre un `Icon` de 16 dp.
- **El color no puede ser el único indicador.** `alerts_screen` distingue crítico/preventivo/óptimo solo con color (barra de acento + punto de sección + texto). Se le añade icono por severidad vía `AppSeverity`.
- **Un solo sistema de breakpoints.** Ningún `MediaQuery.of(context).size` ni `MediaQuery.of(context).padding.top` manual para layout (`alerts_screen:90`, `task_complete_screen:116` lo hacen; se sustituyen por `SafeArea`).
- **No se toca `data/` ni `providers/`.** Si una pantalla necesita un dato que el provider no expone, se documenta como bloqueo.
- `dart format .`, `dart fix --apply`, `flutter analyze` limpio y suite completa verde antes de cada commit. Un commit por tarea.

**Tests existentes que NO se pueden romper:** `test/features/dashboard/notifications_screen_test.dart`, `test/features/dashboard/presentation/pages/dashboard_screen_vehicle_fetch_test.dart`, `test/features/dashboard/presentation/pages/service_history_screen_test.dart`, `test/features/dashboard/add_vehicle_form_test.dart`.

## File Structure

| Fichero | Responsabilidad | Estado |
|---|---|---|
| `lib/core/theme/app_severity.dart` | Severidad → color token + icono + etiqueta. Fuente única. | Crear (Task 1) |
| `lib/core/widgets/app_section_header.dart` | Encabezado de sección tokenizado. | Crear (Task 2) |
| `lib/features/dashboard/presentation/pages/task_config_screen.dart` | Formulario acotado, tokens. | Modificar (Task 3) |
| `.../notifications_screen.dart` | Ancho de lectura, tokens, semántica, swipe. | Modificar (Task 4) |
| `.../garage_screen.dart` | Lista → `AppGrid`, tokens, stagger tokenizado. | Modificar (Task 5) |
| `.../dashboard_screen.dart` | Layout de 1 / 2 columnas, tokens. | Modificar (Task 6) |
| `.../vehicle_profile_screen.dart` | Grid 2/3/4, gutter unificado, placa fluida. | Modificar (Task 7) |
| `.../alerts_screen.dart` | Severidad con icono, targets 48 dp, grid. | Modificar (Task 8) |
| `.../service_history_screen.dart` | Lista/tabla, diálogo fluido, date picker en dark. | Modificar (Task 9) |
| `.../task_complete_screen.dart` | Dejar de re-derivar la paleta; usar el design system. | Modificar (Task 10) |
| `.../workshop_directory_screen.dart` | Split lista/mapa, tokens (22), chips de marca. | Modificar (Task 11) |
| `lib/core/widgets/responsive_web_wrapper.dart` | **Código muerto** (0 consumidores). | Eliminar (Task 12) |

**Orden de las tareas:** primero las dos primitivas compartidas, luego las dos pantallas más pequeñas (`task_config` 248 LOC, `notifications` 274 LOC) para fijar el patrón sobre superficie chica, y solo después las grandes, terminando por `workshop_directory` (1202 LOC, la más compleja). Cada tarea es rechazable de forma independiente.

---

### Task 1: `AppSeverity` — fuente única de severidad

**Files:**
- Create: `lib/core/theme/app_severity.dart`
- Test: `test/core/theme/app_severity_test.dart`

**Interfaces:**
- Consumes: `AppColors` (`context.appColors`); `MaintenanceStatus` de `lib/core/models/maintenance_task_model.dart` (`enum MaintenanceStatus { optimal, preventive, critical }`).
- Produces: `class AppSeverityStyle { final Color color; final IconData icon; final String label; }` con constructor `const AppSeverityStyle({required this.color, required this.icon, required this.label})`; `AppSeverity.forStatus(MaintenanceStatus status, AppColors colors, {required String optimalLabel, required String preventiveLabel, required String criticalLabel}) -> AppSeverityStyle`; `AppSeverity.forExpiry(int daysRemaining, AppColors colors, {required String expiredLabel, required String soonLabel, required String okLabel}) -> AppSeverityStyle`. Consumido por Tasks 5, 6, 7, 8.

**Por qué existe (medido):** el mismo mapeo severidad → color se escribe **cuatro veces** en este módulo, con cuatro resultados distintos:

| Sitio | Crítico | Preventivo | Óptimo |
|---|---|---|---|
| [garage_screen.dart:209-222](../../../lib/features/dashboard/presentation/pages/garage_screen.dart#L209-L222) | `colors.error` | `colors.warning` | `colors.secondary` |
| [dashboard_screen.dart:430-446](../../../lib/features/dashboard/presentation/pages/dashboard_screen.dart#L430-L446) | `colors.error` | `colors.warning` | `colors.secondary` |
| [alerts_screen.dart:272-342](../../../lib/features/dashboard/presentation/pages/alerts_screen.dart#L272-L342) | **`Colors.red`** | **`Colors.amber[700]!`** | `primary` |
| [vehicle_profile_screen.dart:642-660](../../../lib/features/dashboard/presentation/pages/vehicle_profile_screen.dart#L642-L660) | `colors.error` | `colors.warning` | `colors.secondary` |

`alerts_screen` —la pantalla **cuyo trabajo es comunicar severidad**— es la única que usa colores de Material en vez de tokens de marca. Además, de las cuatro solo `dashboard_screen` acompaña el color con un icono distinto por estado; las otras tres dependen solo del color, lo que incumple la regla *"Color is not the only indicator"* de `ui-ux-pro-max` §Accessibility.

- [ ] **Step 1: Invocar la skill**

`Skill(ui-ux-pro-max:ui-ux-pro-max)` y luego:

```bash
python "C:/Users/User/.claude/plugins/cache/ui-ux-pro-max-skill/ui-ux-pro-max/2.13.0/.claude/skills/ui-ux-pro-max/scripts/search.py" "color not only indicator status semantic accessibility" --domain ux
```

Confirma la regla de §10 (*"Don't: Relying on color alone to convey meaning"*) y la de §Accessibility (*"Color is not the only indicator"*). Son la justificación de que `AppSeverityStyle` lleve **siempre** un `icon`, no solo un `color`.

- [ ] **Step 2: Escribir el test que falla**

```dart
// test/core/theme/app_severity_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/models/maintenance_task_model.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_severity.dart';

const _colors = AppColors(
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

AppSeverityStyle styleFor(MaintenanceStatus status) => AppSeverity.forStatus(
  status,
  _colors,
  optimalLabel: 'Óptimo',
  preventiveLabel: 'Revisión pronta',
  criticalLabel: 'Atención requerida',
);

void main() {
  group('forStatus', () {
    test('cada estado usa su token de marca, nunca un color de Material', () {
      expect(styleFor(MaintenanceStatus.critical).color, _colors.error);
      expect(styleFor(MaintenanceStatus.preventive).color, _colors.warning);
      expect(styleFor(MaintenanceStatus.optimal).color, _colors.secondary);
    });

    test('cada estado tiene un icono distinto: el color no es el único indicador', () {
      final icons = MaintenanceStatus.values
          .map((s) => styleFor(s).icon)
          .toSet();
      expect(
        icons.length,
        MaintenanceStatus.values.length,
        reason: 'dos estados comparten icono: se distinguirían solo por color',
      );
    });

    test('cada estado tiene una etiqueta no vacía', () {
      for (final status in MaintenanceStatus.values) {
        expect(styleFor(status).label, isNotEmpty, reason: '$status');
      }
    });

    test('los colores de los tres estados son distintos entre sí', () {
      final palette = MaintenanceStatus.values
          .map((s) => styleFor(s).color)
          .toSet();
      expect(palette.length, MaintenanceStatus.values.length);
    });
  });

  group('forExpiry', () {
    AppSeverityStyle expiry(int days) => AppSeverity.forExpiry(
      days,
      _colors,
      expiredLabel: 'Vencido',
      soonLabel: 'Vence pronto',
      okLabel: 'Vigente',
    );

    test('vencido usa error', () {
      expect(expiry(-1).color, _colors.error);
      expect(expiry(-100).color, _colors.error);
    });

    test('menos de 30 días usa warning', () {
      expect(expiry(0).color, _colors.warning);
      expect(expiry(29).color, _colors.warning);
    });

    test('30 días o más usa secondary', () {
      expect(expiry(30).color, _colors.secondary);
      expect(expiry(365).color, _colors.secondary);
    });

    test('los tres tramos tienen iconos distintos', () {
      final icons = {expiry(-1).icon, expiry(10).icon, expiry(90).icon};
      expect(icons.length, 3);
    });
  });
}
```

- [ ] **Step 3: Correr el test y confirmar que falla**

Run: `flutter test test/core/theme/app_severity_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'autodoc/core/theme/app_severity.dart'`.

- [ ] **Step 4: Escribir la implementación mínima**

```dart
// lib/core/theme/app_severity.dart
import 'package:flutter/material.dart';
import 'package:autodoc/core/models/maintenance_task_model.dart';
import 'package:autodoc/core/theme/app_colors.dart';

/// Estilo visual de un nivel de severidad: color, icono y etiqueta.
///
/// Siempre lleva icono. Comunicar severidad solo con color deja fuera a quien
/// no distingue rojo de ámbar, que es alrededor del 8 % de los hombres.
@immutable
class AppSeverityStyle {
  final Color color;
  final IconData icon;
  final String label;

  const AppSeverityStyle({
    required this.color,
    required this.icon,
    required this.label,
  });
}

/// Fuente única del mapeo severidad → estilo en AutoDoc.
///
/// Antes este mapeo estaba escrito cuatro veces en el módulo dashboard, y una
/// de las cuatro (`alerts_screen`, justo la pantalla dedicada a las alertas)
/// usaba `Colors.red` / `Colors.amber[700]` en vez de los tokens de marca.
class AppSeverity {
  AppSeverity._();

  /// Estilo para el estado de una tarea de mantenimiento.
  ///
  /// Las etiquetas se pasan desde fuera para que este fichero no dependa de
  /// `AppLocalizations` y siga siendo testeable sin montar un widget.
  static AppSeverityStyle forStatus(
    MaintenanceStatus status,
    AppColors colors, {
    required String optimalLabel,
    required String preventiveLabel,
    required String criticalLabel,
  }) {
    return switch (status) {
      MaintenanceStatus.critical => AppSeverityStyle(
        color: colors.error,
        icon: Icons.error_rounded,
        label: criticalLabel,
      ),
      MaintenanceStatus.preventive => AppSeverityStyle(
        color: colors.warning,
        icon: Icons.warning_rounded,
        label: preventiveLabel,
      ),
      MaintenanceStatus.optimal => AppSeverityStyle(
        color: colors.secondary,
        icon: Icons.check_circle_rounded,
        label: optimalLabel,
      ),
    };
  }

  /// Estilo para el vencimiento de un documento, según los días que faltan.
  ///
  /// Los tramos (vencido / < 30 días / resto) son los que ya usaba
  /// `vehicle_profile_screen`; aquí solo se centralizan.
  static AppSeverityStyle forExpiry(
    int daysRemaining,
    AppColors colors, {
    required String expiredLabel,
    required String soonLabel,
    required String okLabel,
  }) {
    if (daysRemaining < 0) {
      return AppSeverityStyle(
        color: colors.error,
        icon: Icons.error_outline,
        label: expiredLabel,
      );
    }
    if (daysRemaining < 30) {
      return AppSeverityStyle(
        color: colors.warning,
        icon: Icons.warning_amber_rounded,
        label: soonLabel,
      );
    }
    return AppSeverityStyle(
      color: colors.secondary,
      icon: Icons.verified_user_outlined,
      label: okLabel,
    );
  }
}
```

- [ ] **Step 5: Correr el test y confirmar que pasa**

Run: `flutter test test/core/theme/app_severity_test.dart`
Expected: PASS (8 tests)

- [ ] **Step 6: Verificar y commitear**

```bash
dart format . && flutter analyze && flutter test
git add lib/core/theme/app_severity.dart test/core/theme/app_severity_test.dart
git commit -m "feat(theme): add AppSeverity as single source of severity styling

El mapeo severidad -> color estaba escrito 4 veces en el modulo dashboard, y
alerts_screen (la pantalla de alertas) usaba Colors.red/Colors.amber[700] en
vez de los tokens de marca. Ademas 3 de las 4 copias comunicaban severidad solo
con color; AppSeverityStyle obliga a llevar icono."
```

---

### Task 2: `AppSectionHeader` — encabezado de sección compartido

**Files:**
- Create: `lib/core/widgets/app_section_header.dart`
- Test: `test/core/widgets/app_section_header_test.dart`

**Interfaces:**
- Consumes: `AppTextStyles`, `AppSpacing`; `context.appColors`.
- Produces: `AppSectionHeader({required String title, String? subtitle, Widget? trailing, bool uppercase = false})`. Consumido por Tasks 3, 6, 7, 8, 10.

**Por qué existe (medido):** el patrón "título de sección, opcionalmente con subtítulo o con acción a la derecha" aparece **cinco veces** en el módulo, cada una con su propio `GoogleFonts.inter(...)` y sus propios tamaños:

| Sitio | Estilo |
|---|---|
| [task_config_screen.dart:122-138](../../../lib/features/dashboard/presentation/pages/task_config_screen.dart#L122-L138) | `fontSize 11, w700, letterSpacing 1.2` + descripción `13` |
| [task_complete_screen.dart:271-284](../../../lib/features/dashboard/presentation/pages/task_complete_screen.dart#L271-L284) | idéntico al anterior, copiado |
| [alerts_screen.dart:413-442](../../../lib/features/dashboard/presentation/pages/alerts_screen.dart#L413-L442) | `fontSize 12, w700, letterSpacing 0.8` + punto de color + contador |
| [dashboard_screen.dart:807-829](../../../lib/features/dashboard/presentation/pages/dashboard_screen.dart#L807-L829) | `fontSize 18, bold` + "Ver todo" a la derecha |
| [vehicle_profile_screen.dart:589-596](../../../lib/features/dashboard/presentation/pages/vehicle_profile_screen.dart#L589-L596) | `fontSize 16, bold` |

Tres tamaños distintos (11 / 12 / 16 / 18) para la misma jerarquía. Se unifica en dos variantes: **normal** (`AppTextStyles.titleMedium`) y **uppercase** (`AppTextStyles.labelSmall` con tracking), que es la que usan `task_config` y `task_complete`.

- [ ] **Step 1: Escribir el test que falla**

```dart
// test/core/widgets/app_section_header_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/widgets/app_section_header.dart';

import '../../support/responsive_harness.dart';

void main() {
  testWidgets('muestra título y subtítulo', (tester) async {
    await pumpAtWidth(
      tester,
      const AppSectionHeader(
        title: 'Frecuencia de mantenimiento',
        subtitle: 'Ajusta cada cuántos kilómetros se realiza.',
      ),
      width: 375,
    );

    expect(find.text('Frecuencia de mantenimiento'), findsOneWidget);
    expect(find.text('Ajusta cada cuántos kilómetros se realiza.'), findsOneWidget);
  });

  testWidgets('la variante uppercase transforma el título', (tester) async {
    await pumpAtWidth(
      tester,
      const AppSectionHeader(title: 'Detalles del servicio', uppercase: true),
      width: 375,
    );

    expect(find.text('DETALLES DEL SERVICIO'), findsOneWidget);
  });

  testWidgets('renderiza el trailing a la derecha del título', (tester) async {
    await pumpAtWidth(
      tester,
      AppSectionHeader(
        title: 'Alertas activas',
        trailing: TextButton(onPressed: () {}, child: const Text('Ver todo')),
      ),
      width: 375,
    );

    final titleX = tester.getCenter(find.text('Alertas activas')).dx;
    final trailingX = tester.getCenter(find.text('Ver todo')).dx;
    expect(trailingX, greaterThan(titleX));
  });

  testWidgets('el título se anuncia como encabezado', (tester) async {
    await pumpAtWidth(
      tester,
      const AppSectionHeader(title: 'Alertas activas'),
      width: 375,
    );

    final semantics = tester.getSemantics(find.text('Alertas activas'));
    expect(
      semantics.hasFlag(SemanticsFlag.isHeader),
      isTrue,
      reason: 'sin flag de header, un lector de pantalla no puede saltar '
          'entre secciones',
    );
  });

  testWidgets('no desborda con un título largo en ningún ancho', (
    tester,
  ) async {
    await forEachAuditWidth(tester, (width) async {
      await pumpAtWidth(
        tester,
        AppSectionHeader(
          title: 'Documentación y alertas del vehículo registrado',
          trailing: TextButton(onPressed: () {}, child: const Text('Ver todo')),
        ),
        width: width,
      );
      expectNoOverflow(tester);
    });
  });
}
```

Añade `import 'package:flutter/semantics.dart';` si `SemanticsFlag` no resuelve desde `material.dart`.

- [ ] **Step 2: Correr el test y confirmar que falla**

Run: `flutter test test/core/widgets/app_section_header_test.dart`
Expected: FAIL — `Couldn't resolve the package 'autodoc/core/widgets/app_section_header.dart'`.

- [ ] **Step 3: Escribir la implementación mínima**

```dart
// lib/core/widgets/app_section_header.dart
import 'package:flutter/material.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';

/// Encabezado de una sección dentro de una pantalla.
///
/// Unifica cinco variantes ad hoc que usaban cuatro tamaños distintos (11 / 12
/// / 16 / 18) para la misma jerarquía, cada una con su propia llamada a
/// `GoogleFonts`.
class AppSectionHeader extends StatelessWidget {
  final String title;

  /// Línea de apoyo bajo el título.
  final String? subtitle;

  /// Acción alineada a la derecha del título (p.ej. "Ver todo").
  final Widget? trailing;

  /// Variante de etiqueta: título en mayúsculas, más pequeño y con tracking.
  /// Es el estilo de los bloques de formulario.
  final bool uppercase;

  const AppSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.uppercase = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final titleStyle = uppercase
        ? AppTextStyles.labelSmall.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: colors.textSecondary,
          )
        : AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  uppercase ? title.toUpperCase() : title,
                  style: titleStyle,
                ),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.sm),
              trailing!,
            ],
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle!,
            style: AppTextStyles.bodySmall.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}
```

- [ ] **Step 4: Correr el test y confirmar que pasa**

Run: `flutter test test/core/widgets/app_section_header_test.dart`
Expected: PASS (5 tests)

Si el test de `isHeader` falla porque el `Semantics` interno del `Text` no propaga el flag, envuelve el `Text` en `Semantics(header: true, container: true, child: ...)`.

- [ ] **Step 5: Verificar y commitear**

```bash
dart format . && flutter analyze && flutter test
git add lib/core/widgets/app_section_header.dart test/core/widgets/app_section_header_test.dart
git commit -m "feat(widgets): add AppSectionHeader to unify five ad-hoc section titles"
```

---

### Task 3: `task_config_screen` — formulario acotado y tokenizado

**Files:**
- Modify: `lib/features/dashboard/presentation/pages/task_config_screen.dart`
- Test: `test/features/dashboard/presentation/pages/task_config_screen_test.dart`

**Interfaces:**
- Consumes: `AppPageBody`, `AppBreakpoints.maxFormWidth` (Fase 1); `AppSectionHeader` (Task 2); `AppTextStyles`, `AppSpacing`, `AppRadius`.
- Produces: `TaskConfigScreen({required MaintenanceTask task})` — misma API.

**Problemas medidos:** 6 llamadas directas a `GoogleFonts.inter` ([L61, L100, L124, L134, L161, L200](../../../lib/features/dashboard/presentation/pages/task_config_screen.dart#L61)); el formulario se estira a todo el ancho en desktop (regla *readable measure* / *form width*); `Column > Expanded > SingleChildScrollView` ([L67-70](../../../lib/features/dashboard/presentation/pages/task_config_screen.dart#L67-L70)) donde el `Column` tiene un único hijo y no aporta nada; `width: 52, height: 52` y radios `14` / `10` literales; los `ActionChip` de preajuste no indican cuál está activo.

Es la pantalla más pequeña con formulario del módulo: fija el patrón que reutilizan las Tasks 10 y 11.

- [ ] **Step 1: Escribir el test que falla**

```dart
// test/features/dashboard/presentation/pages/task_config_screen_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/core/models/maintenance_task_model.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/features/dashboard/presentation/pages/task_config_screen.dart';
import 'package:autodoc/features/dashboard/presentation/providers/alert_provider.dart';

import '../../../../support/responsive_harness.dart';

MaintenanceTask _task() => MaintenanceTask(
  id: 't1',
  vehicleId: 'v1',
  nombre: 'Cambio de aceite',
  ultimoKm: 10000,
  fechaUltimoServicio: DateTime(2026, 1, 1),
  frecuenciaKm: 5000,
  frecuenciaMeses: 6,
);

Future<void> pumpScreen(WidgetTester tester, double width) async {
  await pumpAtWidth(
    tester,
    ChangeNotifierProvider<AlertProvider>(
      create: (_) => AlertProvider(),
      child: TaskConfigScreen(task: _task()),
    ),
    width: width,
  );
  await tester.pump();
}

void main() {
  test('no usa GoogleFonts directamente', () {
    final source = File(
      'lib/features/dashboard/presentation/pages/task_config_screen.dart',
    ).readAsStringSync();
    expect(
      source.contains('GoogleFonts.'),
      isFalse,
      reason: 'usa AppTextStyles; GoogleFonts solo vive en app_text_styles.dart',
    );
  });

  testWidgets('el formulario se acota en pantallas grandes', (tester) async {
    await pumpScreen(tester, 1440);

    final field = tester
        .getSize(find.byType(TextFormField).first)
        .width;
    expect(
      field,
      lessThanOrEqualTo(AppBreakpoints.maxFormWidth),
      reason: 'el campo mide ${field}px; un input de 1400px es inusable',
    );
  });

  testWidgets('en móvil el formulario ocupa el ancho menos el gutter', (
    tester,
  ) async {
    await pumpScreen(tester, 375);

    final field = tester.getSize(find.byType(TextFormField).first).width;
    expect(field, closeTo(375 - 16 * 2, 1.0));
  });

  testWidgets('no desborda en ningún ancho de auditoría', (tester) async {
    await forEachAuditWidth(tester, (width) async {
      await pumpScreen(tester, width);
      expectNoOverflow(tester);
    });
  });

  testWidgets('el preajuste aplicado queda marcado como seleccionado', (
    tester,
  ) async {
    await pumpScreen(tester, 375);

    await tester.tap(find.text('5,000 km / 6 m'));
    await tester.pump();

    final chip = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, '5,000 km / 6 m'),
    );
    expect(
      chip.selected,
      isTrue,
      reason: 'tras aplicar un preajuste el usuario no tiene forma de saber '
          'cuál está activo',
    );
  });

  testWidgets('renderiza en dark mode sin excepciones', (tester) async {
    await pumpAtWidth(
      tester,
      ChangeNotifierProvider<AlertProvider>(
        create: (_) => AlertProvider(),
        child: TaskConfigScreen(task: _task()),
      ),
      width: 375,
      brightness: Brightness.dark,
    );
    expectNoOverflow(tester);
  });
}
```

Si el constructor de `MaintenanceTask` difiere del de arriba, ajústalo al real leyendo `lib/core/models/maintenance_task_model.dart` — **no cambies las aserciones**.

- [ ] **Step 2: Correr el test y confirmar que falla**

Run: `flutter test test/features/dashboard/presentation/pages/task_config_screen_test.dart`
Expected: FAIL — el test de `GoogleFonts` encuentra 6 usos; el campo mide 1400 px a 1440; no existe ningún `FilterChip` (hoy son `ActionChip`, que no tienen estado seleccionado).

- [ ] **Step 3: Implementar los cambios**

3a. Sustituye los imports: borra `import 'package:google_fonts/google_fonts.dart';` y añade:

```dart
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/core/theme/app_radius.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/widgets/app_page_body.dart';
import 'package:autodoc/core/widgets/app_section_header.dart';
```

3b. Añade estado para el preajuste activo, al principio de `_TaskConfigScreenState`:

```dart
  /// Preajuste aplicado, si el usuario tocó alguno. Se limpia en cuanto edita
  /// un campo a mano: dejar el chip marcado con otro valor en el campo mentiría.
  ({int km, int months})? _activePreset;
```

3c. Sustituye el `title:` del `AppBar` ([L59-62](../../../lib/features/dashboard/presentation/pages/task_config_screen.dart#L59-L62)):

```dart
        title: Text(
          'Configurar Tarea',
          style: AppTextStyles.titleLarge.copyWith(
            fontWeight: FontWeight.bold,
            color: primary,
          ),
        ),
```

3d. Sustituye el `body:` completo ([L67-192](../../../lib/features/dashboard/presentation/pages/task_config_screen.dart#L67-L192)) — se elimina el `Column`/`Expanded` inútil y se envuelve en `AppPageBody`:

```dart
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: AppPageBody(
          maxWidth: AppBreakpoints.maxFormWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppCard(
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: Icon(
                        Icons.build_circle_outlined,
                        color: primary,
                        size: Responsive.iconSize(context, 28),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.base),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.task.nombre,
                            style: AppTextStyles.titleMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Último servicio: ${widget.task.ultimoKm} km',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: subTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),
              const AppSectionHeader(
                title: 'Frecuencia de mantenimiento',
                subtitle:
                    'Ajusta cada cuántos kilómetros y meses se debe realizar '
                    'este servicio.',
                uppercase: true,
              ),
              const SizedBox(height: AppSpacing.lg),

              AppTextField(
                label: 'Frecuencia en Kilómetros',
                controller: _kmController,
                keyboardType: TextInputType.number,
                prefixIcon: const Icon(Icons.speed),
                hintText: 'Ej. 5000',
                helperText: 'Debe ser mayor que 0.',
                isRequired: true,
                onChanged: (_) => _clearPreset(),
              ),
              const SizedBox(height: AppSpacing.base),
              AppTextField(
                label: 'Frecuencia en Meses',
                controller: _monthsController,
                keyboardType: TextInputType.number,
                prefixIcon: const Icon(Icons.calendar_month),
                hintText: 'Ej. 6',
                helperText: 'Debe ser mayor que 0.',
                isRequired: true,
                onChanged: (_) => _clearPreset(),
              ),

              const SizedBox(height: AppSpacing.xxl),
              const AppSectionHeader(
                title: 'Preajustes rápidos',
                uppercase: true,
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  _presetChip('3,000 km / 3 m', 3000, 3, primary),
                  _presetChip('5,000 km / 6 m', 5000, 6, primary),
                  _presetChip('10,000 km / 12 m', 10000, 12, primary),
                  _presetChip('20,000 km / 24 m', 20000, 24, primary),
                ],
              ),

              const SizedBox(height: AppSpacing.xxxl),
              AppButton(
                text: 'Guardar Configuración',
                semanticLabel:
                    'Guardar la configuración de frecuencia de esta tarea',
                onPressed: _isLoading ? null : _saveConfig,
                isLoading: _isLoading,
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
```

3e. Sustituye `_presetChip` completo ([L196-216](../../../lib/features/dashboard/presentation/pages/task_config_screen.dart#L196-L216)) por una versión con estado seleccionado:

```dart
  void _clearPreset() {
    if (_activePreset != null) setState(() => _activePreset = null);
  }

  Widget _presetChip(String label, int km, int months, Color primary) {
    final selected = _activePreset?.km == km && _activePreset?.months == months;

    return FilterChip(
      label: Text(label, style: AppTextStyles.labelMedium),
      selected: selected,
      showCheckmark: true,
      backgroundColor: primary.withValues(alpha: 0.08),
      selectedColor: primary.withValues(alpha: 0.2),
      labelStyle: AppTextStyles.labelMedium.copyWith(color: primary),
      side: BorderSide(
        color: primary.withValues(alpha: selected ? 0.6 : 0.2),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      onSelected: (_) {
        setState(() {
          _activePreset = (km: km, months: months);
          _kmController.text = km.toString();
          _monthsController.text = months.toString();
        });
      },
    );
  }
```

3f. Añade el import de `AppCard` si no está (`import 'package:autodoc/core/widgets/app_card.dart';` — ya está en L10).

- [ ] **Step 4: Correr el test y confirmar que pasa**

Run: `flutter test test/features/dashboard/presentation/pages/task_config_screen_test.dart`
Expected: PASS (6 tests)

- [ ] **Step 5: Verificar y commitear**

```bash
dart format . && flutter analyze && flutter test
git add lib/features/dashboard/presentation/pages/task_config_screen.dart test/features/dashboard/presentation/pages/task_config_screen_test.dart
git commit -m "feat(dashboard): make task_config responsive, tokenized and stateful presets

Acota el formulario a maxFormWidth (medía 1400px de ancho en desktop), sustituye
6 GoogleFonts directos por AppTextStyles, elimina un Column/Expanded que no
hacía nada, y cambia ActionChip por FilterChip para que se vea qué preajuste
está aplicado."
```

---

### Task 4: `notifications_screen` — ancho de lectura, tokens y semántica

**Files:**
- Modify: `lib/features/dashboard/presentation/pages/notifications_screen.dart`
- Test: `test/features/dashboard/presentation/pages/notifications_screen_responsive_test.dart`

**Interfaces:**
- Consumes: `AppPageBody`, `AppBreakpoints.maxReadingWidth` (Fase 1); `AppEmptyState` (Fase 3); `AppMotion` (Fase 1); `AppSpacing`, `AppRadius`.
- Produces: `NotificationsScreen()` y `normalizeDeepLink(AppNotification)` — **ambos sin cambios de firma**. `normalizeDeepLink` es público a propósito porque `test/features/dashboard/notifications_screen_test.dart` lo prueba directamente; no lo toques.

**Problemas medidos:** cero responsividad (la lista se estira a 1440 px); un color literal `const Color(0xFFFFB800)` ([L172](../../../lib/features/dashboard/presentation/pages/notifications_screen.dart#L172)) para el tipo `review`; estado vacío hecho a mano ([L83-103](../../../lib/features/dashboard/presentation/pages/notifications_screen.dart#L83-L103)) en vez de `AppEmptyState`; el `Divider` usa `indent: 72` mágico; ninguna `Semantics` en el tile, así que un lector de pantalla lee tres textos sueltos sin decir si la notificación está leída; y el `Dismissible` no anuncia la acción de borrado.

- [ ] **Step 1: Escribir el test que falla**

```dart
// test/features/dashboard/presentation/pages/notifications_screen_responsive_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/core/models/app_notification_model.dart';
import 'package:autodoc/core/providers/notification_center_provider.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/core/widgets/app_empty_state.dart';
import 'package:autodoc/features/dashboard/presentation/pages/notifications_screen.dart';
import 'package:autodoc/l10n/app_localizations.dart';

import '../../../../support/responsive_harness.dart';

/// Doble mínimo: extiende el provider real y solo fija la lista.
class _FakeNotifProvider extends NotificationCenterProvider {
  _FakeNotifProvider(this._items);
  final List<AppNotification> _items;

  @override
  List<AppNotification> get notifications => _items;
  @override
  bool get isLoading => false;
  @override
  bool get hasUnread => _items.any((n) => !n.leida);
  @override
  int get unreadCount => _items.where((n) => !n.leida).length;
}

AppNotification _notif(String id, {bool leida = false}) => AppNotification(
  id: id,
  titulo: 'Servicio completado en tu Toyota Corolla',
  body: 'El taller Mecánica Central registró un cambio de aceite.',
  tipo: 'review',
  timestamp: DateTime(2026, 8, 1),
  leida: leida,
);

Future<void> pumpScreen(
  WidgetTester tester,
  double width, {
  List<AppNotification>? items,
  Brightness brightness = Brightness.light,
}) async {
  await pumpAtWidth(
    tester,
    MultiProvider(
      providers: [
        ChangeNotifierProvider<NotificationCenterProvider>.value(
          value: _FakeNotifProvider(items ?? [_notif('n1')]),
        ),
        ChangeNotifierProvider<UserProfileProvider>(
          create: (_) => UserProfileProvider(),
        ),
      ],
      child: const NotificationsScreen(),
    ),
    width: width,
    brightness: brightness,
  );
  await tester.pump();
}

void main() {
  test('no tiene colores literales', () {
    final source = File(
      'lib/features/dashboard/presentation/pages/notifications_screen.dart',
    ).readAsStringSync();
    final offenders = <String>[];
    final lines = source.split('\n');
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].trimLeft().startsWith('//')) continue;
      if (lines[i].contains('Colors.transparent')) continue;
      if (RegExp(r'Color\(0x[0-9a-fA-F]{8}\)|Colors\.(white|black|grey)')
          .hasMatch(lines[i])) {
        offenders.add('${i + 1}: ${lines[i].trim()}');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  testWidgets('la lista se acota a la medida de lectura en desktop', (
    tester,
  ) async {
    await pumpScreen(tester, 1440);

    final tileWidth = tester
        .getSize(find.byType(Dismissible).first)
        .width;
    expect(
      tileWidth,
      lessThanOrEqualTo(AppBreakpoints.maxReadingWidth),
      reason: 'el tile mide ${tileWidth}px de ancho: ilegible',
    );
  });

  testWidgets('usa AppEmptyState cuando no hay notificaciones', (tester) async {
    await pumpScreen(tester, 375, items: []);
    expect(find.byType(AppEmptyState), findsOneWidget);
  });

  testWidgets('cada notificación se anuncia como una unidad', (tester) async {
    await pumpScreen(tester, 375);

    expect(
      find.bySemanticsLabel(
        RegExp('Servicio completado en tu Toyota Corolla'),
      ),
      findsWidgets,
    );
  });

  testWidgets('una notificación sin leer lo dice, no solo lo pinta', (
    tester,
  ) async {
    await pumpScreen(tester, 375, items: [_notif('n1')]);

    expect(
      find.bySemanticsLabel(RegExp('[Ss]in leer')),
      findsWidgets,
      reason: 'el estado "sin leer" solo se comunica con un punto de color',
    );
  });

  testWidgets('no desborda en ningún ancho de auditoría, en ambos temas', (
    tester,
  ) async {
    for (final brightness in Brightness.values) {
      await forEachAuditWidth(tester, (width) async {
        await pumpScreen(tester, width, brightness: brightness);
        expectNoOverflow(tester);
      });
    }
  });
}
```

Ajusta el constructor de `AppNotification` y el doble del provider a las firmas reales si difieren; **no** relajes las aserciones.

- [ ] **Step 2: Correr el test y confirmar que falla**

Run: `flutter test test/features/dashboard/presentation/pages/notifications_screen_responsive_test.dart`
Expected: FAIL — el color literal de L172 aparece; el tile mide 1440 px; no hay `AppEmptyState`; no hay semántica de "sin leer".

- [ ] **Step 3: Implementar los cambios**

3a. Añade imports:

```dart
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/widgets/app_empty_state.dart';
import 'package:autodoc/core/widgets/app_page_body.dart';
```

3b. Sustituye `_colorForType` ([L163-176](../../../lib/features/dashboard/presentation/pages/notifications_screen.dart#L163-L176)) para eliminar el literal:

```dart
  Color _colorForType(String tipo) {
    switch (tipo) {
      case 'alerta':
        return colors.warning;
      case 'chat':
        return colors.primary;
      case 'reserva':
        return colors.success;
      case 'review':
        // Antes: const Color(0xFFFFB800) — un dorado literal fuera de la
        // paleta. `warning` es el token ámbar de la marca y ya se usa para
        // "atención"; una reseña pendiente es exactamente eso.
        return colors.warning;
      default:
        return colors.textSecondary;
    }
  }
```

Como ahora `alerta` y `review` comparten color, el icono es lo que los distingue — y `_iconForType` ya devuelve `warning_amber_rounded` vs `star_outline_rounded`. Eso cumple *"el color no es el único indicador"*; documéntalo en el commit.

3c. Sustituye el estado vacío ([L83-103](../../../lib/features/dashboard/presentation/pages/notifications_screen.dart#L83-L103)):

```dart
    if (provider.notifications.isEmpty) {
      return AppEmptyState(
        icon: Icons.notifications_none_rounded,
        title: AppLocalizations.of(context)!.noNotifications,
        description: AppLocalizations.of(context)!.noNotifications,
      );
    }
```

Si existe una clave de descripción distinta en `app_localizations` (p.ej. `noNotificationsDesc`), úsala; si no, **no inventes una clave**: pasa la misma cadena y anota en el commit que falta una descripción específica en `lib/l10n/`. Añadir claves de l10n queda fuera del alcance de esta fase.

3d. Envuelve la lista en `AppPageBody` con ancho de lectura ([L105-131](../../../lib/features/dashboard/presentation/pages/notifications_screen.dart#L105-L131)):

```dart
    return AppPageBody(
      maxWidth: AppBreakpoints.maxReadingWidth,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        itemCount: provider.notifications.length,
        separatorBuilder: (_, index) => Divider(
          height: 1,
          color: colors.outline.withValues(alpha: 0.3),
          // 16 (gutter) + 44 (icono) + 12 (gap) = alineado con el texto.
          indent: AppSpacing.base + 44 + AppSpacing.md,
        ),
        itemBuilder: (context, index) {
          // ...sin cambios
        },
      ),
    );
```

3e. Da semántica al tile. En `_NotificationTile.build`, envuelve el `Dismissible` completo:

```dart
    final unreadSuffix = notification.leida ? '' : ', sin leer';

    return Semantics(
      container: true,
      button: true,
      label:
          '${notification.titulo}. ${notification.body}$unreadSuffix',
      onTapHint: 'abrir',
      child: Dismissible(
        key: Key(notification.id),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => onDismiss(),
        // ...resto sin cambios
      ),
    );
```

Y envuelve el contenido interno del `InkWell` en `ExcludeSemantics(...)` para que el lector no repita cada `Text` por separado tras haber leído la etiqueta compuesta.

3f. Sustituye los literales de spacing del tile (`16`, `12`, `24`, `8`, `4`, `6`) por `AppSpacing.*` y el `BorderRadius.circular(12)` por `AppRadius.md`.

- [ ] **Step 4: Correr el test y confirmar que pasa**

Run: `flutter test test/features/dashboard/presentation/pages/notifications_screen_responsive_test.dart`
Expected: PASS (6 tests)

- [ ] **Step 5: Confirmar que el test existente sigue verde**

Run: `flutter test test/features/dashboard/notifications_screen_test.dart`
Expected: PASS. Ese test cubre `normalizeDeepLink`, cuya firma no cambió.

- [ ] **Step 6: Verificar y commitear**

```bash
dart format . && flutter analyze && flutter test
git add lib/features/dashboard/presentation/pages/notifications_screen.dart test/features/dashboard/presentation/pages/notifications_screen_responsive_test.dart
git commit -m "feat(dashboard): constrain notifications to reading width, tokenize and label

La lista se estiraba a 1440px. Se acota a maxReadingWidth, se sustituye el
dorado literal 0xFFFFB800 por colors.warning (los tipos alerta y review siguen
distinguiéndose por icono), se usa AppEmptyState, y cada notificación se anuncia
como una unidad indicando si está sin leer — antes eso solo se comunicaba con un
punto de color de 8dp."
```

---

### Task 5: `garage_screen` — de lista a rejilla adaptativa

**Files:**
- Modify: `lib/features/dashboard/presentation/pages/garage_screen.dart`
- Test: `test/features/dashboard/presentation/pages/garage_screen_test.dart`

**Interfaces:**
- Consumes: `AppBreakpoints`/`WindowClass`, `AppGrid`, `AppPageBody`, `AppMotion` (Fase 1); `AppEmptyState`, `AppCard` (Fase 3); `AppSeverity` (Task 1).
- Produces: `GarageScreen()` — misma API.

**Problemas medidos:** `ListView.builder` ([L48](../../../lib/features/dashboard/presentation/pages/garage_screen.dart#L48)) → **siempre una columna**, incluso a 1440 px, donde cada tarjeta de vehículo mide 1400 px de ancho con una foto de 192 px de alto; 5 colores literales (`Colors.white` L129/L230/L285, `Colors.black` L234/L278, `Colors.amber` L274, `const Color(0xFF334155)` L256); 6 `GoogleFonts.inter`; el mapeo de severidad duplicado (L207-222); estado vacío a mano (L139-161); un botón "atrás" en una pantalla que es **pestaña del shell** (L101-105), donde no hay a dónde volver.

**Motion:** el stagger existente usa `duration: const Duration(milliseconds: 375)` por elemento ([L57](../../../lib/features/dashboard/presentation/pages/garage_screen.dart#L57)). Está por encima del límite de 300 ms y, en una rejilla de 3–4 columnas, escalonar por índice lineal produce una diagonal rara. Se baja a `AppMotion.sheetEnter` (300 ms) y se limita a `AppMotion.staggerMaxItems`.

- [ ] **Step 1: Invocar las skills de motion**

`Skill(emil-design-eng)` — verifica la tabla de frecuencia: el garaje se abre varias veces al día, así que el stagger cae en *"tens of times/day → remove or drastically reduce"*. Verifica también el rango de 30–80 ms entre elementos. Documenta en el commit la decisión final (mantenerlo reducido vs. eliminarlo); si la skill recomienda eliminarlo, elimínalo y ajusta el test correspondiente.

- [ ] **Step 2: Escribir el test que falla**

```dart
// test/features/dashboard/presentation/pages/garage_screen_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/core/providers/auth_session_provider.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/widgets/app_empty_state.dart';
import 'package:autodoc/core/widgets/app_grid.dart';
import 'package:autodoc/features/dashboard/presentation/pages/garage_screen.dart';
import 'package:autodoc/features/dashboard/presentation/providers/alert_provider.dart';
import 'package:autodoc/features/dashboard/presentation/providers/vehicle_provider.dart';

import '../../../../support/responsive_harness.dart';
import '../../../../support/vehicle_fixtures.dart';

Future<void> pumpScreen(
  WidgetTester tester,
  double width, {
  int vehicleCount = 4,
  Brightness brightness = Brightness.light,
}) async {
  await pumpAtWidth(
    tester,
    MultiProvider(
      providers: [
        ChangeNotifierProvider<VehicleProvider>.value(
          value: fakeVehicleProvider(count: vehicleCount),
        ),
        ChangeNotifierProvider<AlertProvider>(create: (_) => AlertProvider()),
        ChangeNotifierProvider<AuthSessionProvider>(
          create: (_) => AuthSessionProvider(),
        ),
        ChangeNotifierProvider<UserProfileProvider>(
          create: (_) => UserProfileProvider(),
        ),
      ],
      child: const GarageScreen(),
    ),
    width: width,
    brightness: brightness,
  );
  await tester.pump();
}

int renderedColumns(WidgetTester tester) {
  final grid = tester.widget<GridView>(find.byType(GridView).first);
  return (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
      .crossAxisCount;
}

void main() {
  test('no usa GoogleFonts ni colores literales', () {
    final source = File(
      'lib/features/dashboard/presentation/pages/garage_screen.dart',
    ).readAsStringSync();

    expect(source.contains('GoogleFonts.'), isFalse);

    final offenders = <String>[];
    final lines = source.split('\n');
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].trimLeft().startsWith('//')) continue;
      if (lines[i].contains('Colors.transparent')) continue;
      if (RegExp(
        r'Color\(0x[0-9a-fA-F]{8}\)|Colors\.(white|black|grey|amber|red|green)',
      ).hasMatch(lines[i])) {
        offenders.add('${i + 1}: ${lines[i].trim()}');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  testWidgets('usa AppGrid y cambia de columnas en cada corte', (tester) async {
    await pumpScreen(tester, 375);
    expect(find.byType(AppGrid), findsOneWidget);
    expect(renderedColumns(tester), 1);

    await pumpScreen(tester, 768);
    expect(renderedColumns(tester), 2);

    await pumpScreen(tester, 1024);
    expect(renderedColumns(tester), 3);

    await pumpScreen(tester, 1440);
    expect(renderedColumns(tester), 4);
  });

  testWidgets('sin vehículos muestra AppEmptyState con acción', (tester) async {
    await pumpScreen(tester, 375, vehicleCount: 0);

    expect(find.byType(AppEmptyState), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppEmptyState),
        matching: find.byType(TextButton).at(0),
      ),
      findsWidgets,
      reason: 'el estado vacío debe ofrecer añadir un vehículo, no solo '
          'informar de que no hay ninguno',
    );
  });

  testWidgets('la pestaña del shell no muestra botón de volver', (
    tester,
  ) async {
    await pumpScreen(tester, 375);

    expect(
      find.byIcon(Icons.arrow_back),
      findsNothing,
      reason: 'garage es una pestaña del ShellRoute: no hay a dónde volver',
    );
  });

  testWidgets('el badge de estado usa el icono de su severidad', (
    tester,
  ) async {
    await pumpScreen(tester, 375);
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.byIcon(Icons.check_circle_rounded),
      findsWidgets,
      reason: 'el estado óptimo se comunicaba solo con un punto de color',
    );
  });

  testWidgets('no desborda en ningún ancho de auditoría, en ambos temas', (
    tester,
  ) async {
    for (final brightness in Brightness.values) {
      await forEachAuditWidth(tester, (width) async {
        await pumpScreen(tester, width, brightness: brightness);
        expectNoOverflow(tester);
      });
    }
  });
}
```

- [ ] **Step 3: Crear el fixture compartido de vehículos**

`test/support/vehicle_fixtures.dart` — lo reutilizan las Tasks 5, 6 y 7:

```dart
// test/support/vehicle_fixtures.dart
import 'package:autodoc/core/models/vehicle_model.dart';
import 'package:autodoc/features/dashboard/presentation/providers/vehicle_provider.dart';

VehicleModel fakeVehicle(int index) => VehicleModel(
  idVehiculo: 'v$index',
  idPropietario: 'u1',
  placa: 'P00$index-123',
  marca: 'Toyota',
  modelo: 'Corolla',
  anio: 2019 + index,
  color: 'Blanco',
  kilometrajeActual: 50000 + index * 1000,
);

/// Provider de vehículos con datos fijos, sin tocar Firestore.
class FakeVehicleProvider extends VehicleProvider {
  FakeVehicleProvider(this._vehicles);
  final List<VehicleModel> _vehicles;

  @override
  List<VehicleModel> get vehicles => _vehicles;

  @override
  VehicleModel? get selectedVehicle =>
      _vehicles.isEmpty ? null : _vehicles.first;

  @override
  bool get isLoading => false;
}

FakeVehicleProvider fakeVehicleProvider({int count = 4}) =>
    FakeVehicleProvider(List.generate(count, fakeVehicle));
```

Ajusta el constructor de `VehicleModel` a los campos requeridos reales leyendo `lib/core/models/vehicle_model.dart`. Si `VehicleProvider` declara `vehicles`/`selectedVehicle`/`isLoading` como campos y no como getters virtuales, no podrás sobrescribirlos: en ese caso usa el provider real y llama a su setter/método de carga con datos falsos, o —si tampoco existe— **para aquí y documenta el bloqueo**: hacer testeable el provider es un cambio en `providers/`, fuera del alcance de esta fase (Global Constraints).

- [ ] **Step 4: Correr los tests y confirmar que fallan**

Run: `flutter test test/features/dashboard/presentation/pages/garage_screen_test.dart`
Expected: FAIL — no existe `AppGrid` en la pantalla (hay `ListView.builder`), hay 6 `GoogleFonts` y 5 colores literales, no hay `AppEmptyState`, y sí hay un `Icons.arrow_back`.

- [ ] **Step 5: Implementar los cambios**

5a. Imports: borra `google_fonts` y `responsive_framework` (este último ya debería haber desaparecido en la Fase 2 Task 1; si sigue, es que esa tarea quedó incompleta — arréglalo allí, no aquí). Añade:

```dart
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/core/theme/app_motion.dart';
import 'package:autodoc/core/theme/app_severity.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/widgets/app_empty_state.dart';
import 'package:autodoc/core/widgets/app_grid.dart';
import 'package:autodoc/core/widgets/app_page_body.dart';
```

5b. Sustituye el cuerpo de la lista ([L42-74](../../../lib/features/dashboard/presentation/pages/garage_screen.dart#L42-L74)):

```dart
            Expanded(
              child: vehicleProvider.isLoading
                  ? AppSkeletonLayouts.listCards(itemCount: 3, cardHeight: 140)
                  : vehicles.isEmpty
                  ? AppEmptyState(
                      icon: Icons.directions_car_outlined,
                      title: context.l10n.garageNoVehicles,
                      description: context.l10n.garageNoVehiclesDesc,
                      action: AppButton(
                        text: context.l10n.garageAddVehicle,
                        icon: const Icon(Icons.add),
                        onPressed: () =>
                            _showAddVehicleDialog(context, colors.primary),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.base,
                      ),
                      child: AppPageBody(
                        child: AnimationLimiter(
                          child: AppGrid(
                            compactColumns: 1,
                            mediumColumns: 2,
                            expandedColumns: 3,
                            largeColumns: 4,
                            childAspectRatio: 0.95,
                            children: [
                              for (var index = 0;
                                  index < vehicles.length;
                                  index++)
                                AnimationConfiguration.staggeredGrid(
                                  position: index,
                                  columnCount: 1,
                                  duration: AppMotion.transformDuration(
                                    context,
                                    AppMotion.sheetEnter,
                                  ),
                                  child: SlideAnimation(
                                    verticalOffset:
                                        AppMotion.reduced(context) ? 0 : 24,
                                    child: FadeInAnimation(
                                      child: _buildVehicleCard(
                                        context,
                                        vehicles[index],
                                        colors,
                                        vehicleProvider,
                                        currentUserId,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
```

Si `context.l10n.garageNoVehiclesDesc` o `garageAddVehicle` no existen en `lib/l10n/`, usa las claves reales que sí existan y anótalo; **no** inventes claves nuevas ni escribas cadenas literales en español cuando el resto del fichero usa `context.l10n`.

5c. Sustituye el header ([L81-137](../../../lib/features/dashboard/presentation/pages/garage_screen.dart#L81-L137)) — sin `responsive_framework`, sin botón de volver, sin `Colors.white`:

```dart
  Widget _buildHeader(BuildContext context, AppColors colors) {
    return AppPageBody(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.base),
        child: Row(
          children: [
            Expanded(
              child: Text(
                context.l10n.garageMyVehicles,
                style: AppTextStyles.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
            ),
            IconButton.filled(
              icon: const Icon(Icons.add),
              tooltip: context.l10n.garageAddVehicle,
              style: IconButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                minimumSize: const Size(48, 48),
              ),
              onPressed: () => _showAddVehicleDialog(context, colors.primary),
            ),
          ],
        ),
      ),
    );
  }
```

5d. Sustituye el badge de estado ([L199-265](../../../lib/features/dashboard/presentation/pages/garage_screen.dart#L199-L265)) para que use `AppSeverity` y lleve icono:

```dart
                    child: FutureBuilder<MaintenanceStatus>(
                      future: context
                          .read<AlertProvider>()
                          .getVehicleOverallStatus(vehicle),
                      builder: (context, snapshot) {
                        final severity = AppSeverity.forStatus(
                          snapshot.data ?? MaintenanceStatus.optimal,
                          colors,
                          optimalLabel: context.l10n.garageStatusOptimal,
                          preventiveLabel: context.l10n.garageStatusPreventive,
                          criticalLabel: context.l10n.garageStatusCritical,
                        );

                        return Semantics(
                          label: severity.label,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.xs + 2,
                            ),
                            decoration: BoxDecoration(
                              color: colors.surfaceContainer.withValues(
                                alpha: 0.92,
                              ),
                              borderRadius: BorderRadius.circular(
                                AppRadius.full,
                              ),
                              boxShadow: isDark
                                  ? AppShadows.darkSm
                                  : AppShadows.lightSm,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  severity.icon,
                                  color: severity.color,
                                  size: 14,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  severity.label.toUpperCase(),
                                  style: AppTextStyles.labelSmall.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colors.textPrimary,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
```

Declara `final isDark = Theme.of(context).brightness == Brightness.dark;` al inicio de `_buildVehicleCard` y añade el import de `app_shadows.dart` y `app_radius.dart`.

5e. Sustituye el badge de vehículo principal ([L267-289](../../../lib/features/dashboard/presentation/pages/garage_screen.dart#L267-L289)): `Colors.amber` → `colors.warning`, `Colors.white` → `colors.onPrimary`, `Colors.black` → usa `AppShadows`. Añádele `Semantics(label: context.l10n.garagePrimaryVehicle)`.

5f. Sustituye los 6 `GoogleFonts.inter(...)` restantes por `AppTextStyles.*` con el `copyWith` equivalente, y `SizedBox(height: Responsive.heroHeight(context, 192))` por `AspectRatio(aspectRatio: 16 / 10, child: ...)` — en una celda de rejilla la altura la debe fijar la proporción, no un valor absoluto que ignora el ancho de la columna.

- [ ] **Step 6: Correr los tests y confirmar que pasan**

Run: `flutter test test/features/dashboard/presentation/pages/garage_screen_test.dart`
Expected: PASS (6 tests)

- [ ] **Step 7: Verificar y commitear**

```bash
dart format . && flutter analyze && flutter test
```

Verificación visual: `flutter run -d chrome`, ir a `/garage` y redimensionar por 375 / 768 / 1024 / 1440. Deben verse 1, 2, 3 y 4 columnas. Comprobar en dark mode que el badge de estado ya no es un pill blanco fijo.

```bash
git add lib/features/dashboard/presentation/pages/garage_screen.dart test/support/vehicle_fixtures.dart test/features/dashboard/presentation/pages/garage_screen_test.dart
git commit -m "feat(dashboard): turn garage into an adaptive grid (1/2/3/4 columns)

Era un ListView de una sola columna a cualquier ancho: a 1440px cada tarjeta de
vehículo medía 1400px. Ahora usa AppGrid. Sustituye 5 colores literales (entre
ellos un pill blanco fijo que ignoraba el dark mode) y 6 GoogleFonts, usa
AppSeverity para que el estado lleve icono además de color, cambia el estado
vacío por AppEmptyState con acción, y quita el botón de volver de una pantalla
que es pestaña del shell. El stagger baja de 375ms a AppMotion.sheetEnter y
respeta reduced motion."
```

---

### Task 6: `dashboard_screen` — layout de una y dos columnas

**Files:**
- Modify: `lib/features/dashboard/presentation/pages/dashboard_screen.dart`
- Test: `test/features/dashboard/presentation/pages/dashboard_screen_layout_test.dart`

**Interfaces:**
- Consumes: `AppBreakpoints`/`WindowClass`, `AppPageBody` (Fase 1); `AppSeverity` (Task 1); `AppSectionHeader` (Task 2); `AppCard`, `AppButton` (Fase 3).
- Produces: `DashboardScreen()` — misma API.

**Corrección del contrato del master.** El master §5.1 propuso *"expanded/large: 3 columnas con el resumen de gastos fijo a la derecha"*. Tras leer el fichero eso es incorrecto por dos motivos: (a) el resumen de gastos (`ExpenseSummaryCard`) vive en `vehicle_profile_screen`, no aquí; (b) esta pantalla tiene solo cuatro bloques de contenido —tarjeta de vehículo, semáforo, alertas activas, talleres cercanos—, y repartirlos en tres columnas deja columnas de un solo elemento. **El contrato real es de dos columnas** a partir de `expanded`:

| `WindowClass` | Layout |
|---|---|
| `compact`, `medium` | una columna: vehículo → semáforo → alertas → talleres |
| `expanded`, `large` | dos columnas: izquierda (5/9) vehículo + semáforo; derecha (4/9) alertas + talleres |

**Otros problemas medidos:** 13 `GoogleFonts.inter`; `Colors.white` en tres sitios ([L235](../../../lib/features/dashboard/presentation/pages/dashboard_screen.dart#L235), [L254](../../../lib/features/dashboard/presentation/pages/dashboard_screen.dart#L254), [L651](../../../lib/features/dashboard/presentation/pages/dashboard_screen.dart#L651), [L693](../../../lib/features/dashboard/presentation/pages/dashboard_screen.dart#L693)) y `Colors.red` ([L391-392](../../../lib/features/dashboard/presentation/pages/dashboard_screen.dart#L391-L392)); un padding inferior mágico de `120` para librar la barra de navegación ([L92-99](../../../lib/features/dashboard/presentation/pages/dashboard_screen.dart#L92-L99)) que ya no aplica en `medium`/`expanded` tras la Fase 2; un FAB posicionado a mano en `bottom: 100` ([L160-171](../../../lib/features/dashboard/presentation/pages/dashboard_screen.dart#L160-L171)) en vez de usar `Scaffold.floatingActionButton`; un avatar de red con URL de placeholder externa hardcodeada ([L239](../../../lib/features/dashboard/presentation/pages/dashboard_screen.dart#L239)); las alertas activas en un `SingleChildScrollView` horizontal con tarjetas de `width: 150` fija ([L898](../../../lib/features/dashboard/presentation/pages/dashboard_screen.dart#L898)); dos bloques de comentarios muertos ([L173-177](../../../lib/features/dashboard/presentation/pages/dashboard_screen.dart#L173-L177)).

- [ ] **Step 1: Escribir el test que falla**

```dart
// test/features/dashboard/presentation/pages/dashboard_screen_layout_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/features/dashboard/presentation/pages/dashboard_screen.dart';
import 'package:autodoc/features/dashboard/presentation/providers/alert_provider.dart';
import 'package:autodoc/features/dashboard/presentation/providers/vehicle_provider.dart';

import '../../../../support/responsive_harness.dart';
import '../../../../support/vehicle_fixtures.dart';

Future<void> pumpScreen(
  WidgetTester tester,
  double width, {
  Brightness brightness = Brightness.light,
}) async {
  await pumpAtWidth(
    tester,
    MultiProvider(
      providers: [
        ChangeNotifierProvider<VehicleProvider>.value(
          value: fakeVehicleProvider(),
        ),
        ChangeNotifierProvider<AlertProvider>(create: (_) => AlertProvider()),
        ChangeNotifierProvider<UserProfileProvider>(
          create: (_) => UserProfileProvider(),
        ),
      ],
      child: const DashboardScreen(),
    ),
    width: width,
    brightness: brightness,
  );
  await tester.pump();
}

void main() {
  test('no usa GoogleFonts ni colores literales', () {
    final source = File(
      'lib/features/dashboard/presentation/pages/dashboard_screen.dart',
    ).readAsStringSync();

    expect(source.contains('GoogleFonts.'), isFalse);

    final offenders = <String>[];
    final lines = source.split('\n');
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].trimLeft().startsWith('//')) continue;
      if (lines[i].contains('Colors.transparent')) continue;
      if (RegExp(r'Color\(0x[0-9a-fA-F]{8}\)|Colors\.(white|black|grey|red)')
          .hasMatch(lines[i])) {
        offenders.add('${i + 1}: ${lines[i].trim()}');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('no queda ninguna URL externa hardcodeada', () {
    final source = File(
      'lib/features/dashboard/presentation/pages/dashboard_screen.dart',
    ).readAsStringSync();
    expect(
      source.contains('w3schools.com'),
      isFalse,
      reason: 'el avatar por defecto apunta a un dominio de terceros: '
          'falla sin red y filtra una petición a un host externo',
    );
  });

  testWidgets('compact y medium usan una sola columna', (tester) async {
    for (final width in [375.0, 768.0]) {
      await pumpScreen(tester, width);
      expect(
        find.byKey(const Key('dashboard-two-column')),
        findsNothing,
        reason: 'dos columnas a $width px',
      );
    }
  });

  testWidgets('expanded y large usan dos columnas', (tester) async {
    for (final width in [1024.0, 1440.0]) {
      await pumpScreen(tester, width);
      expect(
        find.byKey(const Key('dashboard-two-column')),
        findsOneWidget,
        reason: 'una sola columna a $width px',
      );
    }
  });

  testWidgets('el FAB lo gestiona el Scaffold, no un Positioned a mano', (
    tester,
  ) async {
    await pumpScreen(tester, 375);

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).last);
    expect(
      scaffold.floatingActionButton,
      isNotNull,
      reason: 'un FAB en Positioned(bottom: 100) se solapa con la barra de '
          'navegación en cuanto cambia su altura',
    );
  });

  testWidgets('no desborda en ningún ancho de auditoría, en ambos temas', (
    tester,
  ) async {
    for (final brightness in Brightness.values) {
      await forEachAuditWidth(tester, (width) async {
        await pumpScreen(tester, width, brightness: brightness);
        expectNoOverflow(tester);
      });
    }
  });
}
```

- [ ] **Step 2: Correr el test y confirmar que falla**

Run: `flutter test test/features/dashboard/presentation/pages/dashboard_screen_layout_test.dart`
Expected: FAIL — 13 `GoogleFonts`, 5 colores literales, la URL de w3schools, no existe la clave `dashboard-two-column`, y el FAB es un `Positioned`.

- [ ] **Step 3: Implementar los cambios**

3a. Imports: borra `google_fonts`. Añade `app_breakpoints.dart`, `app_severity.dart`, `app_spacing.dart`, `app_text_styles.dart`, `app_page_body.dart`, `app_section_header.dart`.

3b. Sustituye el `build` ([L77-182](../../../lib/features/dashboard/presentation/pages/dashboard_screen.dart#L77-L182)) por una versión que decide layout por `WindowClass`, usa el `Scaffold` para el FAB y elimina el padding mágico y los comentarios muertos:

```dart
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddVehicleDialog(context, primaryPurple),
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        tooltip: context.l10n.dashRegisterVehicle,
        shape: const CircleBorder(),
        child: Icon(Icons.add, size: Responsive.iconSize(context, 32)),
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [bgColorStart, bgColorEnd],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final windowClass = AppBreakpoints.fromWidth(
                constraints.maxWidth,
              );
              final twoColumn = windowClass.isAtLeastExpanded;

              final primaryBlocks = <Widget>[
                if (isLoading)
                  AppSkeletonLayouts.dashboard()
                else if (vehicle == null)
                  _buildEmptyVehicleState(
                    context,
                    primaryPurple,
                    isDark,
                    textColor,
                    subTextColor,
                  )
                else
                  _buildVehicleCard(
                    primaryPurple,
                    vehicle,
                    isDark,
                    textColor,
                    subTextColor,
                  ),
                if (vehicle != null) ...[
                  const SizedBox(height: AppSpacing.base),
                  _buildMaintenanceSemaphore(alertProvider, vehicle, colors),
                ],
              ];

              final secondaryBlocks = <Widget>[
                _buildActiveAlerts(
                  primaryPurple,
                  alertProvider,
                  isDark,
                  subTextColor,
                  colors,
                ),
                const SizedBox(height: AppSpacing.xxl),
                _buildNearbyServices(primaryPurple, isDark, subTextColor),
              ];

              return SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: AppSpacing.xxxl * 2),
                child: AppPageBody(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(context, isDark, textColor, subTextColor),
                      const SizedBox(height: AppSpacing.sm),
                      if (vehicle?.tallerPendienteConfirmacion != null) ...[
                        _buildTallerPendienteBanner(
                          context,
                          vehicleProvider,
                          vehicle!,
                          primaryPurple,
                          isDark,
                          textColor,
                          subTextColor,
                        ),
                        const SizedBox(height: AppSpacing.base),
                      ],
                      if (twoColumn)
                        Row(
                          key: const Key('dashboard-two-column'),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 5,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: primaryBlocks,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xxl),
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: secondaryBlocks,
                              ),
                            ),
                          ],
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ...primaryBlocks,
                            const SizedBox(height: AppSpacing.xxl),
                            ...secondaryBlocks,
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
```

**Importante:** al envolver todo en `AppPageBody`, cada bloque interno deja de necesitar su propio `Padding(horizontal: Responsive.padding(context, 24))`. Elimina esos paddings de `_buildHeader` (L194-195), `_buildTallerPendienteBanner` (L298-301), `_buildMaintenanceSemaphore` (L448-451), `_buildEmptyVehicleState` (L539-540), `_buildVehicleCard` (L594-595), `_buildActiveAlerts` (L803-806, L834, L846) y `_buildNearbyServices` (L939-940). De lo contrario el gutter se duplica.

3c. Sustituye el semáforo ([L427-446](../../../lib/features/dashboard/presentation/pages/dashboard_screen.dart#L427-L446)) por `AppSeverity`:

```dart
    final severity = AppSeverity.forStatus(
      worstStatus,
      colors,
      optimalLabel: context.l10n.dashMaintOptimal,
      preventiveLabel: context.l10n.dashMaintWarning,
      criticalLabel: context.l10n.dashMaintCritical,
    );
```

y usa `severity.color` / `severity.icon` / `severity.label` en lugar de las tres variables locales `semColor` / `semIcon` / `semLabel`.

3d. Elimina los colores literales:
- L235 y L254 (`Border.all(color: Colors.white, width: 2)` del avatar) → `colors.surface`.
- L239 (URL de w3schools) → sustituye el `DecorationImage` por un `CircleAvatar` con `backgroundImage` condicional y, sin foto, la inicial del nombre — el mismo patrón que ya usa `AppTopNavBar`.
- L391-392 (`Colors.red` del botón de rechazar) → `colors.error`.
- L651 (`Colors.white.withValues(alpha: 0.5)`) → `colors.surface.withValues(alpha: 0.5)`.
- L693 (`color: Colors.white` del icono del `AppButton`) → bórralo: `AppButton` ya aplica su `foregroundColor` al icono vía `IconTheme`.

3e. Sustituye los tres encabezados de sección (L807-829 y L944-962) por `AppSectionHeader` con `trailing`. Sustituye los 13 `GoogleFonts.inter` por `AppTextStyles.*`.

3f. En `_buildAlertCard` (L886-936) sustituye `SizedBox(width: 150)` por `ConstrainedBox(constraints: const BoxConstraints(minWidth: 150, maxWidth: 220))`, para que la tarjeta pueda crecer en la columna derecha de `expanded` sin quedarse en 150 px.

- [ ] **Step 4: Correr el test y confirmar que pasa**

Run: `flutter test test/features/dashboard/presentation/pages/dashboard_screen_layout_test.dart`
Expected: PASS (6 tests)

- [ ] **Step 5: Confirmar que el test existente sigue verde**

Run: `flutter test test/features/dashboard/presentation/pages/dashboard_screen_vehicle_fetch_test.dart`
Expected: PASS. Ese test cubre el `didChangeDependencies`, que no se toca.

- [ ] **Step 6: Verificar y commitear**

```bash
dart format . && flutter analyze && flutter test
```

Verificación visual: `/dashboard` a 375 / 768 / 1024 / 1440, light y dark. A partir de 840 px debe verse a dos columnas y el FAB no debe solaparse con el rail.

```bash
git add lib/features/dashboard/presentation/pages/dashboard_screen.dart test/features/dashboard/presentation/pages/dashboard_screen_layout_test.dart
git commit -m "feat(dashboard): two-column dashboard layout from the expanded breakpoint

Una sola columna a cualquier ancho, con un padding inferior mágico de 120px para
librar la barra de navegación y el FAB en Positioned(bottom: 100). Ahora el FAB
lo gestiona el Scaffold y el layout pasa a dos columnas en >=840px.

Sustituye 13 GoogleFonts y 5 colores literales, usa AppSeverity y
AppSectionHeader, y elimina la URL de avatar por defecto apuntando a
w3schools.com (fallaba sin red y filtraba una petición a un host de terceros)."
```

---

### Task 7: `vehicle_profile_screen` — gutter unificado y rejilla real

**Files:**
- Modify: `lib/features/dashboard/presentation/pages/vehicle_profile_screen.dart`
- Test: `test/features/dashboard/presentation/pages/vehicle_profile_screen_test.dart`

**Interfaces:**
- Consumes: `AppPageBody`, `AppGrid`, `AppBreakpoints` (Fase 1); `AppSeverity` (Task 1); `AppSectionHeader` (Task 2); `AppCard`, `AppTextField`, `AppButton` (Fase 3).
- Produces: `VehicleProfileScreen({required String vehiculoId, VehicleModel? vehiculoPrecargado})` — misma API.

**Problemas medidos:**
- **Cinco gutters distintos** en la misma pantalla: 16 ([L228](../../../lib/features/dashboard/presentation/pages/vehicle_profile_screen.dart#L228)), 20 ([L296](../../../lib/features/dashboard/presentation/pages/vehicle_profile_screen.dart#L296)), 24 ([L332](../../../lib/features/dashboard/presentation/pages/vehicle_profile_screen.dart#L332)), 20 ([L352](../../../lib/features/dashboard/presentation/pages/vehicle_profile_screen.dart#L352)), 24 ([L456](../../../lib/features/dashboard/presentation/pages/vehicle_profile_screen.dart#L456)), 20 ([L585](../../../lib/features/dashboard/presentation/pages/vehicle_profile_screen.dart#L585)), 20 ([L780](../../../lib/features/dashboard/presentation/pages/vehicle_profile_screen.dart#L780)). Las secciones no se alinean entre sí.
- `crossAxisCount: Responsive.isDesktop(context) ? 4 : 2` ([L354](../../../lib/features/dashboard/presentation/pages/vehicle_profile_screen.dart#L354)) — salto binario que deja `medium` y `expanded` con el layout de teléfono.
- `ElSalvadorLicensePlate(width: 140, height: 80)` ([L324](../../../lib/features/dashboard/presentation/pages/vehicle_profile_screen.dart#L324)) fijo dentro de un `Row` con `Expanded`: a 320 px, con marca+modelo largos, desborda.
- Hero de altura fija `220` ([L234](../../../lib/features/dashboard/presentation/pages/vehicle_profile_screen.dart#L234)).
- **`showDatePicker` fuerza `ColorScheme.light`** ([L750](../../../lib/features/dashboard/presentation/pages/vehicle_profile_screen.dart#L750)): el selector de fecha sale en claro incluso con la app en dark mode.
- `_buildStatusAlert` ([L674-732](../../../lib/features/dashboard/presentation/pages/vehicle_profile_screen.dart#L674-L732)) mete un `AppButton` de tamaño medio dentro de un `Row` con texto `Expanded`: a 320 px desborda.
- `Card` de Material directo ([L548](../../../lib/features/dashboard/presentation/pages/vehicle_profile_screen.dart#L548)) con `Colors.grey.shade50` en vez de `AppCard`; `TextField` crudo en el diálogo de nota ([L480](../../../lib/features/dashboard/presentation/pages/vehicle_profile_screen.dart#L480)) en vez de `AppTextField`.
- 8 `GoogleFonts.inter`; `Colors.red` ×2 (L209, L213), `Colors.white` ×2 (L276, L546), `Colors.black` (L258), `Colors.grey` (L627), `Colors.grey.shade50` (L552).

- [ ] **Step 1: Escribir el test que falla**

```dart
// test/features/dashboard/presentation/pages/vehicle_profile_screen_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/core/providers/auth_session_provider.dart';
import 'package:autodoc/core/widgets/app_card.dart';
import 'package:autodoc/core/widgets/app_grid.dart';
import 'package:autodoc/features/dashboard/presentation/pages/vehicle_profile_screen.dart';
import 'package:autodoc/features/dashboard/presentation/providers/vehicle_provider.dart';

import '../../../../support/responsive_harness.dart';
import '../../../../support/vehicle_fixtures.dart';

Future<void> pumpScreen(
  WidgetTester tester,
  double width, {
  Brightness brightness = Brightness.light,
}) async {
  await pumpAtWidth(
    tester,
    MultiProvider(
      providers: [
        ChangeNotifierProvider<VehicleProvider>.value(
          value: fakeVehicleProvider(),
        ),
        ChangeNotifierProvider<AuthSessionProvider>(
          create: (_) => AuthSessionProvider(),
        ),
      ],
      child: VehicleProfileScreen(
        vehiculoId: 'v0',
        vehiculoPrecargado: fakeVehicle(0),
      ),
    ),
    width: width,
    brightness: brightness,
  );
  await tester.pump();
}

void main() {
  test('no usa GoogleFonts ni colores literales', () {
    final source = File(
      'lib/features/dashboard/presentation/pages/vehicle_profile_screen.dart',
    ).readAsStringSync();

    expect(source.contains('GoogleFonts.'), isFalse);

    final offenders = <String>[];
    final lines = source.split('\n');
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].trimLeft().startsWith('//')) continue;
      if (lines[i].contains('Colors.transparent')) continue;
      if (RegExp(r'Color\(0x[0-9a-fA-F]{8}\)|Colors\.(white|black|grey|red)')
          .hasMatch(lines[i])) {
        offenders.add('${i + 1}: ${lines[i].trim()}');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('el selector de fecha no fuerza ColorScheme.light', () {
    final source = File(
      'lib/features/dashboard/presentation/pages/vehicle_profile_screen.dart',
    ).readAsStringSync();
    expect(
      source.contains('ColorScheme.light('),
      isFalse,
      reason: 'forzar ColorScheme.light hace que el date picker salga en claro '
          'con la app en dark mode',
    );
  });

  testWidgets('los detalles técnicos usan AppGrid con 2/2/3/4 columnas', (
    tester,
  ) async {
    for (final (width, expected) in [
      (375.0, 2),
      (768.0, 2),
      (1024.0, 3),
      (1440.0, 4),
    ]) {
      await pumpScreen(tester, width);

      final grid = tester.widget<GridView>(find.byType(GridView).first);
      final columns =
          (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
              .crossAxisCount;
      expect(columns, expected, reason: '$columns columnas a $width px');
    }

    expect(find.byType(AppGrid), findsWidgets);
  });

  test('ninguna sección pone su propio gutter horizontal', () {
    final source = File(
      'lib/features/dashboard/presentation/pages/vehicle_profile_screen.dart',
    ).readAsStringSync();

    final offenders = <String>[];
    final lines = source.split('\n');
    for (var i = 0; i < lines.length; i++) {
      if (RegExp(r'horizontal:\s*(\d|Responsive\.padding)')
          .hasMatch(lines[i])) {
        offenders.add('${i + 1}: ${lines[i].trim()}');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'el gutter lo pone AppPageBody una sola vez. La pantalla usaba '
          'cinco valores distintos (16/20/24), así que las secciones no se '
          'alineaban entre sí:\n${offenders.join('\n')}',
    );
  });

  testWidgets('las secciones comparten el mismo margen izquierdo', (
    tester,
  ) async {
    await pumpScreen(tester, 1440);

    final cardLefts = tester
        .widgetList<Widget>(find.byType(AppCard))
        .toList()
        .asMap()
        .keys
        .map((i) => tester.getTopLeft(find.byType(AppCard).at(i)).dx)
        .toSet();

    expect(
      cardLefts.length,
      lessThanOrEqualTo(2),
      reason: 'las tarjetas arrancan en ${cardLefts.length} márgenes distintos '
          '($cardLefts); como mucho debería haber dos (columna izquierda y '
          'celdas de la rejilla)',
    );
  });

  testWidgets('no desborda a 320px con marca y modelo largos', (tester) async {
    await pumpScreen(tester, 320);
    expectNoOverflow(tester);
  });

  testWidgets('no desborda en ningún ancho de auditoría, en ambos temas', (
    tester,
  ) async {
    for (final brightness in Brightness.values) {
      await forEachAuditWidth(tester, (width) async {
        await pumpScreen(tester, width, brightness: brightness);
        expectNoOverflow(tester);
      });
    }
  });
}
```

- [ ] **Step 2: Correr el test y confirmar que falla**

Run: `flutter test test/features/dashboard/presentation/pages/vehicle_profile_screen_test.dart`
Expected: FAIL — 8 `GoogleFonts`, 7 colores literales, `ColorScheme.light(`, el grid da 2/2/2/4 en vez de 2/2/3/4, y quedan `EdgeInsets.symmetric(horizontal: N)` literales.

- [ ] **Step 3: Implementar los cambios**

3a. Imports: borra `google_fonts`; añade `app_breakpoints.dart`, `app_grid.dart`, `app_page_body.dart`, `app_section_header.dart`, `app_severity.dart`, `app_spacing.dart`, `app_text_styles.dart`, `app_text_field.dart`.

3b. Unifica el gutter: en el `build` ([L112-131](../../../lib/features/dashboard/presentation/pages/vehicle_profile_screen.dart#L112-L131)) envuelve la `Column` de secciones en `AppPageBody`, y **elimina el `Padding` horizontal de cada uno de los siete métodos `_build*`**, dejando solo su espaciado vertical:

```dart
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxxl * 2),
              child: AppPageBody(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeroImage(vehicle, colors),
                    const SizedBox(height: AppSpacing.base),
                    _buildVehicleIdentity(vehicle, colors),
                    const SizedBox(height: AppSpacing.base),
                    _buildExpenseSummary(vehicle, colors),
                    const SizedBox(height: AppSpacing.base),
                    _buildTechnicalDetails(vehicle, colors),
                    const SizedBox(height: AppSpacing.xxl),
                    _buildNotesSection(vehicle, colors),
                    const SizedBox(height: AppSpacing.xxl),
                    VehicleGalleryWidget(
                      vehicleId: vehicle.idVehiculo,
                      colors: colors,
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    _buildDocumentationStatus(vehicle, colors),
                    const SizedBox(height: AppSpacing.xxl),
                    _buildQuickActions(vehicle, colors),
                  ],
                ),
              ),
            ),
          ),
```

3c. Sustituye el hero de altura fija ([L233-235](../../../lib/features/dashboard/presentation/pages/vehicle_profile_screen.dart#L233-L235)):

```dart
          child: AspectRatio(
            aspectRatio: 16 / 9,
```

3d. Sustituye el `GridView.count` de detalles técnicos ([L353-388](../../../lib/features/dashboard/presentation/pages/vehicle_profile_screen.dart#L353-L388)) por `AppGrid`:

```dart
      child: AppGrid(
        compactColumns: 2,
        mediumColumns: 2,
        expandedColumns: 3,
        largeColumns: 4,
        spacing: AppSpacing.base,
        childAspectRatio: 1.35,
        children: [
          // ...los mismos cuatro _buildDetailItem, sin cambios
        ],
      ),
```

3e. Haz fluida la matrícula ([L297-326](../../../lib/features/dashboard/presentation/pages/vehicle_profile_screen.dart#L297-L326)): envuelve `ElSalvadorLicensePlate` para que ceda espacio en pantallas estrechas:

```dart
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140, maxHeight: 80),
            child: AspectRatio(
              aspectRatio: 140 / 80,
              child: ElSalvadorLicensePlate(
                placa: vehicle.placa,
                width: 140,
                height: 80,
              ),
            ),
          ),
```

y cambia el `Row` a `Wrap(spacing: AppSpacing.base, runSpacing: AppSpacing.md, alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.end, ...)` para que a 320 px la matrícula baje de línea en vez de desbordar. Elimina el `Expanded` del bloque de texto, que dentro de un `Wrap` no es válido.

3f. Arregla el date picker ([L747-756](../../../lib/features/dashboard/presentation/pages/vehicle_profile_screen.dart#L747-L756)): **elimina el `builder:` completo**. El `ThemeData` de la app ya define el `colorScheme` correcto para cada modo; el `builder` solo estaba pisándolo con una versión clara fija.

3g. Sustituye el mapeo de vencimiento ([L638-660](../../../lib/features/dashboard/presentation/pages/vehicle_profile_screen.dart#L638-L660)) por `AppSeverity.forExpiry(difference, colors, expiredLabel: ..., soonLabel: ..., okLabel: ...)`, usando las claves l10n ya existentes (`vpExpiredOn`, `vpExpiresInDays`).

3h. Arregla el desbordamiento de `_buildStatusAlert` ([L720-728](../../../lib/features/dashboard/presentation/pages/vehicle_profile_screen.dart#L720-L728)): pasa el `AppButton` a `size: AppButtonSize.small` y envuélvelo en `Flexible`. Alternativamente, en `compact` muévelo a una segunda fila con `Wrap`.

3i. Sustituye `Card(...)` de la lista de notas ([L548-572](../../../lib/features/dashboard/presentation/pages/vehicle_profile_screen.dart#L548-L572)) por `AppCard`, elimina `Colors.grey.shade50` y `isDark(context)` si deja de usarse. Sustituye el `TextField` del diálogo ([L480-486](../../../lib/features/dashboard/presentation/pages/vehicle_profile_screen.dart#L480-L486)) por `AppTextField(label: 'Nota', maxLines: 3, hintText: ...)`.

3j. Sustituye los colores literales restantes: `Colors.red` (L209, L213) → `colors.error`; `Colors.white` (L276) → `colors.onSecondary`; `Colors.white` (L546, icono de borrar sobre `colors.error`) → `colors.onPrimary`; `Colors.black.withValues(alpha: 0.7)` del degradado (L258) → mantener el negro es correcto para un degradado sobre foto, pero muévelo a una constante local documentada o usa `AppShadows`-style: la opción aceptada es declarar en la propia pantalla `// Degradado de legibilidad sobre foto: no es un color de marca.` y usar `Colors.black.withValues(...)` con un `// ignore:` explícito **solo si** el ratchet lo marca; preferible: `colors.textPrimary.withValues(alpha: 0.7)` en light, que ya es casi negro. Elige la segunda y verifica el contraste del texto blanco encima. `Colors.grey` (L627) → `colors.textSecondary`.

3k. Sustituye los 8 `GoogleFonts.inter` por `AppTextStyles.*` y los tres títulos de sección por `AppSectionHeader`.

- [ ] **Step 4: Correr el test y confirmar que pasa**

Run: `flutter test test/features/dashboard/presentation/pages/vehicle_profile_screen_test.dart`
Expected: PASS (7 tests)

- [ ] **Step 5: Verificar y commitear**

```bash
dart format . && flutter analyze && flutter test
```

Verificación visual: `/vehicle_profile/<id>` a 320 / 768 / 1024 / 1440, light y dark. Todas las secciones deben alinearse en el mismo margen; el selector de fecha debe salir oscuro en dark mode.

```bash
git add lib/features/dashboard/presentation/pages/vehicle_profile_screen.dart test/features/dashboard/presentation/pages/vehicle_profile_screen_test.dart
git commit -m "feat(dashboard): unify vehicle_profile gutters and make its grid adaptive

La pantalla usaba cinco gutters distintos (16/20/24) así que las secciones no se
alineaban entre sí; ahora el gutter lo pone AppPageBody. El grid de detalles
pasa de 'isDesktop ? 4 : 2' a 2/2/3/4 vía AppGrid.

Arregla además el date picker, que forzaba ColorScheme.light y salía en claro
con la app en dark mode; hace fluida la matrícula (140x80 fijos desbordaban a
320px); y sustituye 8 GoogleFonts y 7 colores literales."
```

---

### Task 8: `alerts_screen` — severidad con icono y targets de 48 dp

**Files:**
- Modify: `lib/features/dashboard/presentation/pages/alerts_screen.dart`
- Test: `test/features/dashboard/presentation/pages/alerts_screen_test.dart`

**Interfaces:**
- Consumes: `AppSeverity` (Task 1); `AppSectionHeader` (Task 2); `AppPageBody`, `AppGrid`, `AppBreakpoints` (Fase 1); `AppEmptyState`, `AppButton`, `AppCard` (Fase 3).
- Produces: `AlertsScreen()` — misma API.

**Esta es la tarea de accesibilidad más importante del módulo.** Problemas medidos:

1. **Severidad solo por color.** `Colors.red` / `Colors.amber[700]!` / `primary` en [L272, L282, L308, L318, L328, L342](../../../lib/features/dashboard/presentation/pages/alerts_screen.dart#L272) — ni tokens de marca ni icono distintivo. La barra de acento izquierda ([L477-482](../../../lib/features/dashboard/presentation/pages/alerts_screen.dart#L477-L482)) y el punto de sección ([L418-422](../../../lib/features/dashboard/presentation/pages/alerts_screen.dart#L418-L422)) son puramente cromáticos, y el icono de la tarjeta es `Icons.build_circle_outlined` **para los tres estados** ([L500](../../../lib/features/dashboard/presentation/pages/alerts_screen.dart#L500)).
2. **Targets por debajo de 48 dp.** `_buildCompactActionButton` fija `minimumSize: const Size(0, 40)` **y** `tapTargetSize: MaterialTapTargetSize.shrinkWrap` ([L737-748](../../../lib/features/dashboard/presentation/pages/alerts_screen.dart#L737-L748)), que desactiva el relleno automático de Material a 48 dp. Las pestañas ([L151-175](../../../lib/features/dashboard/presentation/pages/alerts_screen.dart#L151-L175)) miden ~30 dp. El lápiz de editar kilometraje ([L404-407](../../../lib/features/dashboard/presentation/pages/alerts_screen.dart#L404-L407)) es un `GestureDetector` sobre un `Icon` de 16 dp.
3. `MediaQuery.of(context).padding.top + 8` manual ([L90](../../../lib/features/dashboard/presentation/pages/alerts_screen.dart#L90)) en vez de `SafeArea`.
4. `ListView` de una sola columna a cualquier ancho; `const SizedBox(height: 80)` mágico al final ([L367](../../../lib/features/dashboard/presentation/pages/alerts_screen.dart#L367)).
5. 12 `GoogleFonts.inter`; 8 colores literales.

- [ ] **Step 1: Invocar la skill**

`Skill(ui-ux-pro-max:ui-ux-pro-max)` — `references/pro-rules.md` §Interaction (*"Touch target minimum >=48x48dp, expand hit area when icon is smaller"*) y §Accessibility (*"Color is not the only indicator"*). Ambas son exactamente los dos fallos de esta pantalla.

- [ ] **Step 2: Escribir el test que falla**

```dart
// test/features/dashboard/presentation/pages/alerts_screen_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/features/dashboard/presentation/pages/alerts_screen.dart';
import 'package:autodoc/features/dashboard/presentation/providers/alert_provider.dart';
import 'package:autodoc/features/dashboard/presentation/providers/vehicle_provider.dart';

import '../../../../support/responsive_harness.dart';
import '../../../../support/vehicle_fixtures.dart';

Future<void> pumpScreen(
  WidgetTester tester,
  double width, {
  Brightness brightness = Brightness.light,
}) async {
  await pumpAtWidth(
    tester,
    MultiProvider(
      providers: [
        ChangeNotifierProvider<VehicleProvider>.value(
          value: fakeVehicleProvider(),
        ),
        ChangeNotifierProvider<AlertProvider>(create: (_) => AlertProvider()),
      ],
      child: const AlertsScreen(),
    ),
    width: width,
    brightness: brightness,
  );
  await tester.pump();
}

void main() {
  final source = File(
    'lib/features/dashboard/presentation/pages/alerts_screen.dart',
  ).readAsStringSync();

  test('no usa GoogleFonts ni colores de Material para la severidad', () {
    expect(source.contains('GoogleFonts.'), isFalse);

    for (final banned in ['Colors.red', 'Colors.amber', 'Colors.green']) {
      expect(
        source.contains(banned),
        isFalse,
        reason: '$banned: la severidad debe salir de AppSeverity, que usa los '
            'tokens de marca',
      );
    }
  });

  test('no desactiva el tamaño mínimo de target de Material', () {
    expect(
      source.contains('MaterialTapTargetSize.shrinkWrap'),
      isFalse,
      reason: 'shrinkWrap desactiva el relleno automático a 48dp',
    );
    expect(
      source.contains('Size(0, 40)'),
      isFalse,
      reason: '40dp está por debajo del mínimo de 48dp',
    );
  });

  testWidgets('todos los controles tappables miden al menos 48dp', (
    tester,
  ) async {
    await pumpScreen(tester, 375);

    for (final type in [
      find.byType(ElevatedButton),
      find.byType(OutlinedButton),
      find.byType(IconButton),
    ]) {
      for (var i = 0; i < tester.widgetList(type).length; i++) {
        final size = tester.getSize(type.at(i));
        expect(
          size.height,
          greaterThanOrEqualTo(48.0),
          reason: 'control $i mide ${size.height}dp de alto',
        );
        expect(size.width, greaterThanOrEqualTo(48.0));
      }
    }
  });

  testWidgets('las pestañas de filtro miden al menos 48dp', (tester) async {
    await pumpScreen(tester, 375);

    final tabs = find.byType(InkWell);
    expect(tabs, findsWidgets);
    for (var i = 0; i < 3; i++) {
      expect(tester.getSize(tabs.at(i)).height, greaterThanOrEqualTo(48.0));
    }
  });

  testWidgets('cada severidad se distingue por icono, no solo por color', (
    tester,
  ) async {
    await pumpScreen(tester, 375);

    // Los tres iconos de AppSeverity deben ser distintos entre sí; al menos
    // uno debe estar presente y ninguno puede ser el build_circle genérico
    // que antes se usaba para los tres estados.
    expect(
      find.byIcon(Icons.build_circle_outlined),
      findsNothing,
      reason: 'los tres estados compartían el mismo icono',
    );
  });

  testWidgets('la lista se reparte en columnas en pantallas anchas', (
    tester,
  ) async {
    await pumpScreen(tester, 1440);
    expect(find.byType(GridView), findsWidgets);
  });

  testWidgets('no desborda en ningún ancho de auditoría, en ambos temas', (
    tester,
  ) async {
    for (final brightness in Brightness.values) {
      await forEachAuditWidth(tester, (width) async {
        await pumpScreen(tester, width, brightness: brightness);
        expectNoOverflow(tester);
      });
    }
  });
}
```

- [ ] **Step 3: Correr el test y confirmar que falla**

Run: `flutter test test/features/dashboard/presentation/pages/alerts_screen_test.dart`
Expected: FAIL en los siete tests: hay `Colors.red`/`Colors.amber`, `shrinkWrap`, `Size(0, 40)`, tabs de ~30 dp, `Icons.build_circle_outlined` para los tres estados y ningún `GridView`.

- [ ] **Step 4: Implementar los cambios**

4a. Imports: borra `google_fonts`; añade `app_breakpoints.dart`, `app_grid.dart`, `app_page_body.dart`, `app_section_header.dart`, `app_severity.dart`, `app_spacing.dart`, `app_text_styles.dart`, `app_empty_state.dart`.

4b. Sustituye la cabecera ([L88-100](../../../lib/features/dashboard/presentation/pages/alerts_screen.dart#L88-L100)) para usar `SafeArea` en vez del padding manual:

```dart
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.only(
          left: AppSpacing.sm,
          right: AppSpacing.sm,
          top: AppSpacing.sm,
          bottom: AppSpacing.md,
        ),
        // ...resto igual, con Colors.white70/Colors.grey[700] -> colors.textSecondary
```

4c. Sustituye `_buildTabs` ([L129-179](../../../lib/features/dashboard/presentation/pages/alerts_screen.dart#L129-L179)) por pestañas con altura mínima e `InkWell` (que sí da ripple y semántica):

```dart
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xl),
            child: InkWell(
              onTap: () => setState(() => _selectedTab = i),
              child: Semantics(
                selected: isActive,
                button: true,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: isActive ? primary : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    tabs[i],
                    style: AppTextStyles.labelLarge.copyWith(
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                      color: isActive ? primary : subTextColor,
                    ),
                  ),
                ),
              ),
            ),
          );
```

4d. Sustituye `_buildCompactActionButton` ([L726-767](../../../lib/features/dashboard/presentation/pages/alerts_screen.dart#L726-L767)) por `AppButton`, que ya garantiza los 48 dp tras la Fase 3:

```dart
  Widget _buildCompactActionButton({
    required String label,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onPressed,
    bool outlined = false,
  }) {
    return AppButton(
      text: label,
      icon: Icon(icon),
      size: AppButtonSize.small,
      type: outlined ? AppButtonType.text : AppButtonType.primary,
      onPressed: onPressed,
    );
  }
```

Nota: `AppButton` no acepta un color de acento arbitrario; usa `colors.primary`. Eso es **correcto** — un botón de acción no debe teñirse del color de severidad, que ya está comunicado por el icono, la barra lateral y la etiqueta. Si el diseño exige distinguirlos, añade un parámetro `AppButtonType.danger` a `AppButton` en una tarea aparte; **no** lo improvises aquí.

4e. Sustituye el mapeo de severidad. En `_buildContent` ([L266-366](../../../lib/features/dashboard/presentation/pages/alerts_screen.dart#L266-L366)), en vez de pasar `Colors.red` / `Colors.amber[700]!` / `primary` a `_buildTaskCard` y `_buildSectionHeader`, calcula el estilo una vez por sección:

```dart
    final criticalStyle = AppSeverity.forStatus(
      MaintenanceStatus.critical,
      colors,
      optimalLabel: context.l10n.alertsSuggestions,
      preventiveLabel: context.l10n.alertsUpcomingExpirations,
      criticalLabel: context.l10n.alertsHighPriority,
    );
```

(y análogamente `preventiveStyle`, `optimalStyle`), y pasa `style` en vez de `accentColor`. Cambia la firma de `_buildTaskCard` y `_buildAlertCard` a recibir `AppSeverityStyle style`, y dentro:
- El icono de la tarjeta ([L500](../../../lib/features/dashboard/presentation/pages/alerts_screen.dart#L500)) pasa de `Icons.build_circle_outlined` fijo a `style.icon`.
- El color de acento pasa a `style.color`.
- Añade `Semantics(label: '${style.label}: ${task.nombre}')` alrededor de la tarjeta.

4f. Sustituye `_buildSectionHeader` ([L413-442](../../../lib/features/dashboard/presentation/pages/alerts_screen.dart#L413-L442)) por `AppSectionHeader` con el icono de severidad como parte del título:

```dart
  Widget _buildSectionHeader(AppSeverityStyle style, String? subtitle) {
    return Row(
      children: [
        Icon(style.icon, color: style.color, size: 18),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: AppSectionHeader(title: style.label, uppercase: true),
        ),
        if (subtitle != null)
          Text(
            subtitle,
            style: AppTextStyles.labelSmall.copyWith(
              color: colors.textSecondary,
            ),
          ),
      ],
    );
  }
```

4g. Sustituye el `ListView` ([L260-369](../../../lib/features/dashboard/presentation/pages/alerts_screen.dart#L260-L369)) por `AppPageBody` + secciones donde cada grupo de tarjetas va en un `AppGrid(compactColumns: 1, mediumColumns: 1, expandedColumns: 2, largeColumns: 2, childAspectRatio: 2.4)`. Una tarjeta de alerta es alta y estrecha; dos columnas es el máximo razonable antes de que el texto quede troceado. Elimina el `SizedBox(height: 80)` final: el `padding` inferior lo pone el `SingleChildScrollView`.

4h. Sustituye el estado "todo en orden" ([L231-258](../../../lib/features/dashboard/presentation/pages/alerts_screen.dart#L231-L258)) por `AppEmptyState` con `icon: Icons.verified_outlined`.

4i. Haz tappable el lápiz de kilometraje ([L404-407](../../../lib/features/dashboard/presentation/pages/alerts_screen.dart#L404-L407)):

```dart
          IconButton(
            icon: const Icon(Icons.edit, size: 16),
            color: primary,
            tooltip: context.l10n.alertsUpdateMileage,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: () => _showUpdateMileageDialog(context),
          ),
```

4j. Sustituye los 12 `GoogleFonts.inter` por `AppTextStyles.*`, y `Colors.grey`/`Colors.grey.withValues` (L437, L565) por `colors.textSecondary` / `colors.surfaceVariant`, `Colors.white` (L744) por el `onPrimary` que ya aplica `AppButton`.

- [ ] **Step 5: Correr el test y confirmar que pasa**

Run: `flutter test test/features/dashboard/presentation/pages/alerts_screen_test.dart`
Expected: PASS (7 tests)

- [ ] **Step 6: Verificar y commitear**

```bash
dart format . && flutter analyze && flutter test
```

Verificación manual obligatoria: activa el simulador de daltonismo del navegador (DevTools → Rendering → *Emulate vision deficiencies* → *Protanopia*) y comprueba que sigues pudiendo distinguir una alerta crítica de una preventiva. Antes de este cambio no se podía.

```bash
git add lib/features/dashboard/presentation/pages/alerts_screen.dart test/features/dashboard/presentation/pages/alerts_screen_test.dart
git commit -m "fix(a11y): make alert severity distinguishable without colour, fix tap targets

La pantalla de alertas comunicaba severidad SOLO con color (barra lateral, punto
de sección, texto) y usaba el mismo Icons.build_circle_outlined para los tres
estados. Ahora cada severidad sale de AppSeverity, con icono propio y tokens de
marca — antes usaba Colors.red y Colors.amber[700], los únicos colores de
Material del semáforo en toda la app.

Corrige además los targets: _buildCompactActionButton fijaba
minimumSize: Size(0, 40) Y tapTargetSize: shrinkWrap, que desactiva el relleno
automático de Material a 48dp; las pestañas medían ~30dp y el lápiz de
kilometraje era un GestureDetector sobre un icono de 16dp."
```

---

### Task 9: `service_history_screen` — lista y tabla, diálogo fluido

**Files:**
- Modify: `lib/features/dashboard/presentation/pages/service_history_screen.dart`
- Test: `test/features/dashboard/presentation/pages/service_history_responsive_test.dart`

**Interfaces:**
- Consumes: `AppPageBody`, `AppGrid`, `AppBreakpoints` (Fase 1); `AppSectionHeader` (Task 2); `AppCard`, `AppEmptyState` (Fase 3).
- Produces: `ServiceHistoryScreen({required String vehiculoId, FirebaseFirestore? firestore})` — misma API. **El parámetro `firestore` existe para el test actual; no lo quites.**

**Problemas medidos:** `SizedBox(width: 380)` dentro de un `AlertDialog` ([L468](../../../lib/features/dashboard/presentation/pages/service_history_screen.dart#L468)) — a 320 px el diálogo desborda; `SizedBox(width: 110)` en `_detalleRow` ([L537](../../../lib/features/dashboard/presentation/pages/service_history_screen.dart#L537)); **`showDateRangePicker` fuerza `ColorScheme.light`** ([L114](../../../lib/features/dashboard/presentation/pages/service_history_screen.dart#L114)), mismo bug de dark mode que la Task 7; `_buildFilterTab` mide ~34 dp ([L433-434](../../../lib/features/dashboard/presentation/pages/service_history_screen.dart#L433-L434)); lista de una sola columna; 9 `GoogleFonts.inter`; 11 colores literales, entre ellos `Colors.blueGrey` ×3 y `Colors.green` ×3 que no son de la paleta.

- [ ] **Step 1: Escribir el test que falla**

```dart
// test/features/dashboard/presentation/pages/service_history_responsive_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:autodoc/features/dashboard/presentation/pages/service_history_screen.dart';

import '../../../../support/responsive_harness.dart';

Future<void> pumpScreen(
  WidgetTester tester,
  double width, {
  Brightness brightness = Brightness.light,
}) async {
  final firestore = FakeFirebaseFirestore();
  await firestore.collection('servicios').add({
    'id_vehiculo': 'v0',
    'tipo_servicio': 'Cambio de aceite',
    'fecha': DateTime(2026, 6, 1),
    'costo': 45.0,
    'id_taller': 'Manual (Propietario)',
    'kilometraje_servicio': 51000,
  });

  await pumpAtWidth(
    tester,
    ServiceHistoryScreen(vehiculoId: 'v0', firestore: firestore),
    width: width,
    brightness: brightness,
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  final source = File(
    'lib/features/dashboard/presentation/pages/service_history_screen.dart',
  ).readAsStringSync();

  test('no usa GoogleFonts ni colores fuera de la paleta', () {
    expect(source.contains('GoogleFonts.'), isFalse);
    for (final banned in ['Colors.blueGrey', 'Colors.green', 'Colors.grey']) {
      expect(source.contains(banned), isFalse, reason: banned);
    }
  });

  test('el date range picker no fuerza ColorScheme.light', () {
    expect(
      source.contains('ColorScheme.light('),
      isFalse,
      reason: 'sale en claro con la app en dark mode',
    );
  });

  test('el diálogo de detalle no tiene un ancho fijo mayor que 320', () {
    expect(
      RegExp(r'SizedBox\(\s*width:\s*380').hasMatch(source),
      isFalse,
      reason: 'un AlertDialog de 380px desborda a 320px de pantalla',
    );
  });

  testWidgets('las pestañas de filtro miden al menos 48dp', (tester) async {
    await pumpScreen(tester, 375);

    final tabs = find.byType(InkWell);
    for (var i = 0; i < 3; i++) {
      expect(tester.getSize(tabs.at(i)).height, greaterThanOrEqualTo(48.0));
    }
  });

  testWidgets('la lista se reparte en columnas en pantallas anchas', (
    tester,
  ) async {
    await pumpScreen(tester, 1440);
    expect(find.byType(GridView), findsWidgets);
  });

  testWidgets('no desborda en ningún ancho de auditoría, en ambos temas', (
    tester,
  ) async {
    for (final brightness in Brightness.values) {
      await forEachAuditWidth(tester, (width) async {
        await pumpScreen(tester, width, brightness: brightness);
        expectNoOverflow(tester);
      });
    }
  });
}
```

- [ ] **Step 2: Correr el test y confirmar que falla**

Run: `flutter test test/features/dashboard/presentation/pages/service_history_responsive_test.dart`
Expected: FAIL — 9 `GoogleFonts`, `Colors.blueGrey`/`Colors.green`/`Colors.grey`, `ColorScheme.light(`, `SizedBox(width: 380`, tabs de ~34 dp y ningún `GridView`.

- [ ] **Step 3: Implementar los cambios**

3a. Imports: borra `google_fonts`; añade `app_breakpoints.dart`, `app_grid.dart`, `app_page_body.dart`, `app_section_header.dart`, `app_spacing.dart`, `app_text_styles.dart`, `app_empty_state.dart`, `app_radius.dart`.

3b. Elimina el `builder:` del `showDateRangePicker` ([L111-123](../../../lib/features/dashboard/presentation/pages/service_history_screen.dart#L111-L123)) por completo, igual que en la Task 7.

3c. Sustituye `_buildFilterTab` ([L428-460](../../../lib/features/dashboard/presentation/pages/service_history_screen.dart#L428-L460)) por una versión con `InkWell`, altura mínima 48 y semántica:

```dart
  Widget _buildFilterTab(String title, AppColors colors) {
    final isSelected = _filter == title;
    return Expanded(
      child: Semantics(
        selected: isSelected,
        button: true,
        child: InkWell(
          onTap: () => setState(() => _filter = title),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? colors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              title,
              style: AppTextStyles.labelLarge.copyWith(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? colors.onPrimary : colors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
```

Elimina el `BoxShadow(color: Colors.black12)` — la selección ya se distingue por relleno.

3d. Sustituye el diálogo de detalle ([L462-528](../../../lib/features/dashboard/presentation/pages/service_history_screen.dart#L462-L528)): quita `SizedBox(width: 380)` y usa `ConstrainedBox(constraints: const BoxConstraints(maxWidth: 380))` — `maxWidth` cede en pantallas estrechas, `width` no. En `_detalleRow` ([L536-545](../../../lib/features/dashboard/presentation/pages/service_history_screen.dart#L536-L545)) cambia `SizedBox(width: 110)` por `ConstrainedBox(constraints: const BoxConstraints(minWidth: 96, maxWidth: 130))` envuelto en `Flexible`.

3e. Sustituye el `ListView.builder` ([L292-302](../../../lib/features/dashboard/presentation/pages/service_history_screen.dart#L292-L302)) por `AppPageBody` + `AppGrid(compactColumns: 1, mediumColumns: 1, expandedColumns: 2, largeColumns: 2, childAspectRatio: 2.6)`. Una tarjeta de servicio es un bloque de texto denso; más de dos columnas trocea las descripciones.

3f. Sustituye `_buildStatistics` ([L314-397](../../../lib/features/dashboard/presentation/pages/service_history_screen.dart#L314-L397)) por `AppCard` (hoy es un `Container` con sombra propia) y `_buildEmptyState` ([L399-426](../../../lib/features/dashboard/presentation/pages/service_history_screen.dart#L399-L426)) por `AppEmptyState`.

3g. Sustituye los colores fuera de paleta: `Colors.blueGrey` (L639, L649, L659, chip "Propietario") → `colors.textSecondary`; `Colors.green` (L676, L685, L694, chip "Evidencia") → `colors.success`; `Colors.grey.shade600` (L542) → `colors.textSecondary`; `Colors.white` (L116, L454) → `colors.onPrimary`; `Colors.black12` (L441) → eliminado con 3c; `Colors.white` (L818, icono de cerrar sobre el visor de imagen) → `colors.onPrimary`.

3h. Sustituye los 9 `GoogleFonts.inter` por `AppTextStyles.*`.

- [ ] **Step 4: Correr los tests y confirmar que pasan**

Run: `flutter test test/features/dashboard/presentation/pages/service_history_responsive_test.dart`
Expected: PASS (6 tests)

- [ ] **Step 5: Confirmar que el test existente sigue verde**

Run: `flutter test test/features/dashboard/presentation/pages/service_history_screen_test.dart`
Expected: PASS. Si falla por un finder de texto que cambió de estilo pero no de contenido, es un falso positivo del test antiguo: ajústalo. Si falla por comportamiento, has roto algo — arréglalo.

- [ ] **Step 6: Verificar y commitear**

```bash
dart format . && flutter analyze && flutter test
git add lib/features/dashboard/presentation/pages/service_history_screen.dart test/features/dashboard/presentation/pages/service_history_responsive_test.dart
git commit -m "feat(dashboard): responsive service history, fluid dialog, dark-mode date picker

showDateRangePicker forzaba ColorScheme.light y salía en claro con la app en
dark. El diálogo de detalle fijaba SizedBox(width: 380) y desbordaba a 320px.
Las pestañas de filtro medían ~34dp. La lista era de una sola columna a
cualquier ancho.

Sustituye además 9 GoogleFonts y 11 colores literales, entre ellos Colors.blueGrey
y Colors.green, que no pertenecen a la paleta de AutoDoc."
```

---

### Task 10: `task_complete_screen` — dejar de re-derivar la paleta

**Files:**
- Modify: `lib/features/dashboard/presentation/pages/task_complete_screen.dart`
- Test: `test/features/dashboard/presentation/pages/task_complete_screen_test.dart`

**Interfaces:**
- Consumes: `AppPageBody`, `AppBreakpoints.maxFormWidth` (Fase 1); `AppSeverity` (Task 1); `AppSectionHeader` (Task 2); `AppCard`, `AppTextField`, `AppButton` (Fase 3); `AppScaffold`.
- Produces: `TaskCompleteScreen({required MaintenanceTask task, required int currentKm})` — misma API.

**Es el peor infractor del módulo y de la app.** No usa el design system: **re-deriva la paleta entera a mano** en las líneas [89-104](../../../lib/features/dashboard/presentation/pages/task_complete_screen.dart#L89-L104):

```dart
final primary = const Color(0xFF522C81);                              // = AppPalette.lightPrimary
final bgColor = isDark ? const Color(0xFF18141E) : const Color(0xFFF7F6F8);
final textColor = isDark ? Colors.white : const Color(0xFF0F172A);    // = lightTextPrimary
final subTextColor = isDark ? Colors.white60 : const Color(0xFF64748B); // = lightTextSecondary
final cardColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.7);
final borderColor = ...;
final statusColor = status == critical ? Colors.red : status == preventive ? Colors.amber[700]! : Colors.green;
```

Consecuencias reales: en dark mode el morado `#522C81` no se invierte a teal como en el resto de la app; y `#64748B` es precisamente el gris que la Fase 1 Task 4 corrigió por fallar WCAG AA — esta pantalla se quedaría con el valor viejo. Además: 14 `GoogleFonts.inter`, `Scaffold` en vez de `AppScaffold`, `TextField` crudo ×2 en vez de `AppTextField`, `ElevatedButton.icon` en vez de `AppButton`, `GestureDetector` sin feedback en los botones de foto, `MediaQuery.of(context).padding.top` manual, y dos `BackdropFilter` de blur 10 (coste real en móviles de gama baja, sobre un fondo que ya es opaco).

- [ ] **Step 1: Escribir el test que falla**

```dart
// test/features/dashboard/presentation/pages/task_complete_screen_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/core/models/maintenance_task_model.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/widgets/app_text_field.dart';
import 'package:autodoc/features/dashboard/presentation/pages/task_complete_screen.dart';
import 'package:autodoc/features/dashboard/presentation/providers/alert_provider.dart';

import '../../../../support/responsive_harness.dart';

MaintenanceTask _task() => MaintenanceTask(
  id: 't1',
  vehicleId: 'v1',
  nombre: 'Cambio de aceite',
  ultimoKm: 10000,
  fechaUltimoServicio: DateTime(2026, 1, 1),
  frecuenciaKm: 5000,
  frecuenciaMeses: 6,
);

Future<void> pumpScreen(
  WidgetTester tester,
  double width, {
  Brightness brightness = Brightness.light,
}) async {
  await pumpAtWidth(
    tester,
    ChangeNotifierProvider<AlertProvider>(
      create: (_) => AlertProvider(),
      child: TaskCompleteScreen(task: _task(), currentKm: 16000),
    ),
    width: width,
    brightness: brightness,
  );
  await tester.pump();
}

void main() {
  final source = File(
    'lib/features/dashboard/presentation/pages/task_complete_screen.dart',
  ).readAsStringSync();

  test('no re-deriva la paleta a mano', () {
    for (final literal in [
      '0xFF522C81',
      '0xFF0F172A',
      '0xFF64748B',
      '0xFFF7F6F8',
      '0xFF18141E',
    ]) {
      expect(
        source.contains(literal),
        isFalse,
        reason: '$literal duplica un valor de AppPalette; usa '
            'context.appColors',
      );
    }
  });

  test('no usa GoogleFonts ni colores de Material', () {
    expect(source.contains('GoogleFonts.'), isFalse);
    for (final banned in [
      'Colors.red',
      'Colors.green',
      'Colors.amber',
      'Colors.white',
      'Colors.grey',
      'Colors.black54',
    ]) {
      expect(source.contains(banned), isFalse, reason: banned);
    }
  });

  test('usa los componentes del design system', () {
    expect(source.contains('AppTextField'), isTrue);
    expect(source.contains('AppButton'), isTrue);
    expect(
      RegExp(r'\bTextField\(').hasMatch(source),
      isFalse,
      reason: 'TextField crudo en vez de AppTextField',
    );
    expect(
      source.contains('ElevatedButton'),
      isFalse,
      reason: 'ElevatedButton crudo en vez de AppButton',
    );
  });

  testWidgets('el primary sale del tema y se invierte en dark', (tester) async {
    late Color lightPrimary;
    late Color darkPrimary;

    await pumpAtWidth(
      tester,
      Builder(
        builder: (context) {
          lightPrimary = context.appColors.primary;
          return const SizedBox.shrink();
        },
      ),
      width: 375,
    );
    await pumpAtWidth(
      tester,
      Builder(
        builder: (context) {
          darkPrimary = context.appColors.primary;
          return const SizedBox.shrink();
        },
      ),
      width: 375,
      brightness: Brightness.dark,
    );

    expect(
      lightPrimary,
      isNot(darkPrimary),
      reason: 'la marca invierte primary entre temas; una pantalla que fija '
          '#522C81 se queda morada en dark',
    );
  });

  testWidgets('el formulario se acota en pantallas grandes', (tester) async {
    await pumpScreen(tester, 1440);

    final field = tester.getSize(find.byType(AppTextField).first).width;
    expect(field, lessThanOrEqualTo(AppBreakpoints.maxFormWidth));
  });

  testWidgets('no desborda en ningún ancho de auditoría, en ambos temas', (
    tester,
  ) async {
    for (final brightness in Brightness.values) {
      await forEachAuditWidth(tester, (width) async {
        await pumpScreen(tester, width, brightness: brightness);
        expectNoOverflow(tester);
      });
    }
  });
}
```

- [ ] **Step 2: Correr el test y confirmar que falla**

Run: `flutter test test/features/dashboard/presentation/pages/task_complete_screen_test.dart`
Expected: FAIL — los cinco literales de paleta están presentes, hay 14 `GoogleFonts` y seis familias de `Colors.*`, hay `TextField` y `ElevatedButton` crudos, y el formulario mide 1400 px a 1440.

- [ ] **Step 3: Implementar los cambios**

3a. Sustituye el bloque de derivación de paleta ([L87-104](../../../lib/features/dashboard/presentation/pages/task_complete_screen.dart#L87-L104)) por:

```dart
    final colors = context.appColors;
    final status = widget.task.getStatus(widget.currentKm);
    final severity = AppSeverity.forStatus(
      status,
      colors,
      optimalLabel: widget.task.getStatusLabel(widget.currentKm),
      preventiveLabel: widget.task.getStatusLabel(widget.currentKm),
      criticalLabel: widget.task.getStatusLabel(widget.currentKm),
    );
```

Y a partir de ahí usa `colors.primary`, `colors.textPrimary`, `colors.textSecondary`, `colors.surfaceContainer`, `colors.outline` y `severity.color` en lugar de las siete variables locales. Elimina `isDark` si deja de usarse.

3b. Sustituye el `Scaffold` + cabecera con `BackdropFilter` ([L106-148](../../../lib/features/dashboard/presentation/pages/task_complete_screen.dart#L106-L148)) por `AppScaffold` con un `AppBar` normal:

```dart
    return AppScaffold(
      appBar: AppBar(
        backgroundColor: colors.surfaceContainer,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          tooltip: 'Volver',
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Completar Servicio',
          style: AppTextStyles.titleLarge.copyWith(
            fontWeight: FontWeight.bold,
            color: colors.primary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: AppPageBody(
          maxWidth: AppBreakpoints.maxFormWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [ /* ...secciones... */ ],
          ),
        ),
      ),
    );
```

Esto elimina de paso el `MediaQuery.of(context).padding.top` manual (el `AppBar` respeta el safe area por sí solo) y los dos `BackdropFilter`, que difuminaban sobre un fondo opaco: coste de GPU sin efecto visible. Añade `import 'package:go_router/go_router.dart';` si `context.pop` no resuelve.

3c. Sustituye los dos `_buildInputCard` con `TextField` crudo ([L288-341](../../../lib/features/dashboard/presentation/pages/task_complete_screen.dart#L288-L341)) por `AppTextField`:

```dart
              AppTextField(
                label: 'Costo total',
                controller: _costController,
                keyboardType: TextInputType.number,
                prefixIcon: const Icon(Icons.attach_money),
                hintText: '0.00',
                helperText: 'Opcional.',
              ),
              const SizedBox(height: AppSpacing.base),
              AppTextField(
                label: 'Notas, taller o refacciones',
                controller: _notesController,
                maxLines: 3,
                prefixIcon: const Icon(Icons.note_alt_outlined),
                hintText: 'Ej: Se usó aceite sintético 5W-30...',
              ),
```

y **borra el helper `_buildInputCard` entero** ([L564-605](../../../lib/features/dashboard/presentation/pages/task_complete_screen.dart#L564-L605)): `AppTextField` ya aporta etiqueta, icono, relleno y borde.

3d. Sustituye los dos títulos de sección ([L271-284](../../../lib/features/dashboard/presentation/pages/task_complete_screen.dart#L271-L284) y [L344-357](../../../lib/features/dashboard/presentation/pages/task_complete_screen.dart#L344-L357)) por `AppSectionHeader(..., uppercase: true)`.

3e. Sustituye `_photoButton` ([L607-644](../../../lib/features/dashboard/presentation/pages/task_complete_screen.dart#L607-L644)): el `GestureDetector` sin feedback pasa a `AppCard` con `onTap`, que tras la Fase 3 ya trae press-scale, hover y semántica. Añade `semanticLabel` ('Adjuntar foto con la cámara' / '...desde la galería').

3f. Sustituye el `ElevatedButton.icon` de envío ([L480-515](../../../lib/features/dashboard/presentation/pages/task_complete_screen.dart#L480-L515)) por:

```dart
              AppButton(
                text: _isLoading ? 'Guardando...' : 'Confirmar y validar',
                icon: const Icon(Icons.check_circle),
                isLoading: _isLoading,
                onPressed: _receiptImage == null ? null : _submitCompletion,
                semanticLabel:
                    'Confirmar y validar el servicio con la evidencia adjunta',
              ),
```

3g. Sustituye la nota de requisito ([L516-528](../../../lib/features/dashboard/presentation/pages/task_complete_screen.dart#L516-L528)): `Colors.red.withValues(alpha: 0.7)` → `colors.error`, y añádele un icono `Icons.info_outline` para que no dependa solo del color.

3h. Sustituye los colores restantes del bloque de imagen adjunta ([L360-476](../../../lib/features/dashboard/presentation/pages/task_complete_screen.dart#L360-L476)): `Colors.green` → `colors.success`; `Colors.black54` del botón de quitar → `colors.textPrimary.withValues(alpha: 0.6)`; `Colors.white` de los iconos sobre ese fondo → `colors.surface`.

3i. Sustituye los 14 `GoogleFonts.inter` por `AppTextStyles.*` y los literales de spacing/radio por `AppSpacing.*` / `AppRadius.*`.

- [ ] **Step 4: Correr el test y confirmar que pasa**

Run: `flutter test test/features/dashboard/presentation/pages/task_complete_screen_test.dart`
Expected: PASS (6 tests)

- [ ] **Step 5: Verificar y commitear**

```bash
dart format . && flutter analyze && flutter test
```

Verificación visual obligatoria en **dark mode**: antes de este cambio la pantalla se veía morada sobre fondo oscuro (el resto de la app invierte a teal). Compara antes/después.

```bash
git add lib/features/dashboard/presentation/pages/task_complete_screen.dart test/features/dashboard/presentation/pages/task_complete_screen_test.dart
git commit -m "fix(dashboard): stop task_complete from re-deriving the whole palette by hand

La pantalla declaraba su propia paleta con literales (#522C81, #0F172A,
#64748B, #F7F6F8, #18141E) en vez de leer el tema. Dos consecuencias reales: en
dark mode el morado no se invertía a teal como en el resto de la app, y el gris
secundario se quedaba en el valor que la Fase 1 corrigió por fallar WCAG AA.

Pasa a AppScaffold, AppTextField, AppButton, AppCard, AppSectionHeader y
AppSeverity; elimina dos BackdropFilter que difuminaban sobre un fondo opaco y
el cálculo manual del safe area."
```

---

### Task 11: `workshop_directory_screen` — split lista/mapa y color de marca

**Files:**
- Modify: `lib/features/dashboard/presentation/pages/workshop_directory_screen.dart`
- Test: `test/features/dashboard/presentation/pages/workshop_directory_test.dart`

**Interfaces:**
- Consumes: `AppBreakpoints`/`WindowClass`, `AppGrid`, `AppPageBody` (Fase 1); `AppCard`, `AppTextField`, `AppEmptyState` (Fase 3).
- Produces: `WorkshopDirectoryScreen()` — misma API.

**Es la pantalla más grande (1202 LOC) y la que más colores literales acumula (22).** Problemas medidos:

- **Los chips de filtro usan `Colors.blue`** ([L606-607, L612, L631, L637](../../../lib/features/dashboard/presentation/pages/workshop_directory_screen.dart#L606)) — azul de Material en una app cuya marca es morado/teal. Es la desviación de marca más visible del módulo.
- **La paleta oscura re-derivada a mano:** `const Color(0xFF0F172A)` ([L395](../../../lib/features/dashboard/presentation/pages/workshop_directory_screen.dart#L395), [L608](../../../lib/features/dashboard/presentation/pages/workshop_directory_screen.dart#L608)) y `const Color(0xFF1E293B)` ([L493](../../../lib/features/dashboard/presentation/pages/workshop_directory_screen.dart#L493)) duplican `AppPalette.darkSurface` y `darkSurfaceVariant`.
- `Colors.white` ×7, `Colors.grey[200]!`/`[800]` ×4, `Colors.white54`, `Colors.amber`/`[100]`/`[700]` ×4, `Colors.black.withValues` ×3.
- `ListView.builder` ([L284](../../../lib/features/dashboard/presentation/pages/workshop_directory_screen.dart#L284)) de una sola columna a cualquier ancho.
- `width: 240` fijo en la tarjeta del mapa ([L830](../../../lib/features/dashboard/presentation/pages/workshop_directory_screen.dart#L830)).
- 8 `GoogleFonts.inter`.
- `responsive_framework` en [L310](../../../lib/features/dashboard/presentation/pages/workshop_directory_screen.dart#L310) (debería haber desaparecido en la Fase 2 Task 1; si sigue, arréglalo allí).

**Contrato de layout** (del master §5.1, confirmado tras leer el fichero):

| `WindowClass` | Layout |
|---|---|
| `compact`, `medium` | lista en 1 columna; el mapa se abre en una hoja modal |
| `expanded`, `large` | split persistente: lista a la izquierda (40 %), mapa a la derecha (60 %) |

- [ ] **Step 1: Invocar las skills**

`Skill(ui-ux-pro-max:ui-ux-pro-max)` — verifica §4 *Style Selection* (*"Match product type, Consistency"*): un azul de Material dentro de una identidad morado/teal es exactamente la inconsistencia que esa regla describe. `Skill(emil-design-eng)` para la transición lista↔mapa: es un cambio de estructura al cruzar un breakpoint, no una entrada — curva `AppMotion.easeInOut`.

- [ ] **Step 2: Escribir el test que falla**

```dart
// test/features/dashboard/presentation/pages/workshop_directory_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'lib/features/dashboard/presentation/pages/workshop_directory_screen.dart',
  ).readAsStringSync();

  test('no usa el azul de Material: la marca es morado/teal', () {
    expect(
      source.contains('Colors.blue'),
      isFalse,
      reason: 'los chips de filtro usan Colors.blue en una app morado/teal',
    );
  });

  test('no re-deriva la paleta oscura a mano', () {
    for (final literal in ['0xFF0F172A', '0xFF1E293B']) {
      expect(
        source.contains(literal),
        isFalse,
        reason: '$literal duplica AppPalette; usa context.appColors',
      );
    }
  });

  test('no usa GoogleFonts ni colores literales', () {
    expect(source.contains('GoogleFonts.'), isFalse);
    for (final banned in [
      'Colors.white',
      'Colors.grey',
      'Colors.amber',
      'Colors.black',
    ]) {
      expect(source.contains(banned), isFalse, reason: banned);
    }
  });

  test('no quedan anchos fijos grandes', () {
    expect(
      RegExp(r'width:\s*240\b').hasMatch(source),
      isFalse,
      reason: 'la tarjeta del mapa fija 240px de ancho',
    );
  });

  test('no importa responsive_framework', () {
    expect(source.contains('responsive_framework'), isFalse);
  });

  test('el split lista/mapa se decide por WindowClass', () {
    expect(
      source.contains('AppBreakpoints'),
      isTrue,
      reason: 'la decisión de split debe salir de la escala única',
    );
    expect(source.contains('isAtLeastExpanded'), isTrue);
  });
}
```

**Nota sobre el alcance del test:** esta pantalla monta `GoogleMap`, que no renderiza en `flutter_test` sin un mock de plataforma. Por eso las aserciones de esta tarea son **estructurales sobre el fuente**, no de widget. La verificación de layout es manual (Step 5) y queda anotada como deuda: montar un doble de `google_maps_flutter` es un trabajo propio que no cabe en esta fase. Declara esa limitación en el PR — no la escondas.

- [ ] **Step 3: Correr el test y confirmar que falla**

Run: `flutter test test/features/dashboard/presentation/pages/workshop_directory_test.dart`
Expected: FAIL en los seis tests.

- [ ] **Step 4: Implementar los cambios**

4a. Imports: borra `google_fonts` y `responsive_framework`; añade `app_breakpoints.dart`, `app_grid.dart`, `app_page_body.dart`, `app_spacing.dart`, `app_text_styles.dart`, `app_radius.dart`, `app_shadows.dart`.

4b. Sustituye el `isDesktop` de `_buildHeader` ([L310](../../../lib/features/dashboard/presentation/pages/workshop_directory_screen.dart#L310)) por `AppBreakpoints.of(context).isAtLeastExpanded`.

4c. **Chips de filtro** ([L588-650](../../../lib/features/dashboard/presentation/pages/workshop_directory_screen.dart#L588-L650)): sustituye los cinco `Colors.blue` por `colors.primary`, los fondos `const Color(0xFF0F172A)` / `Colors.white` por `colors.surfaceContainer`, y el borde `Colors.grey[200]!` / `Colors.white.withValues(alpha: 0.1)` por `colors.outline.withValues(alpha: isDark ? 0.2 : 0.4)`. Sustituye el `BoxShadow(color: Colors.black...)` por `AppShadows.lightSm`/`darkSm`.

4d. **Barra de búsqueda** ([L390-418](../../../lib/features/dashboard/presentation/pages/workshop_directory_screen.dart#L390-L418)): sustitúyela por `AppTextField` con `prefixIcon: const Icon(Icons.search)` y `hintText`, acotada a `maxWidth: 640`. Eso elimina de golpe los cuatro literales de esa función y le da la semántica de campo de la Fase 3.

4e. **Estrellas** ([L522](../../../lib/features/dashboard/presentation/pages/workshop_directory_screen.dart#L522), [L858-877](../../../lib/features/dashboard/presentation/pages/workshop_directory_screen.dart#L858-L877)): `Colors.amber` / `amber[100]` / `amber[700]` → `colors.warning` con `withValues(alpha:)` para el fondo. Añade `Semantics(label: '${calificacion} de 5 estrellas')` a cada bloque de calificación — hoy la nota es puramente visual.

4f. **Lista → rejilla** ([L284-306](../../../lib/features/dashboard/presentation/pages/workshop_directory_screen.dart#L284-L306)): envuelve en `AppPageBody` y sustituye por `AppGrid(compactColumns: 1, mediumColumns: 1, expandedColumns: 1, largeColumns: 2, childAspectRatio: 2.2)`. Nota: en `expanded` la lista ocupa solo el 40 % del ancho (es el panel izquierdo del split), así que ahí sigue siendo una columna; `AppGrid` decide por `constraints.maxWidth`, que en ese panel será ~400 px → `compact` → 1 columna. Es exactamente el motivo por el que `AppGrid` usa `LayoutBuilder` y no `MediaQuery`.

4g. **Split lista/mapa**: en el `build` ([L131-307](../../../lib/features/dashboard/presentation/pages/workshop_directory_screen.dart#L131-L307)), envuelve el contenido en `LayoutBuilder` y:

```dart
              final windowClass = AppBreakpoints.fromWidth(constraints.maxWidth);
              if (windowClass.isAtLeastExpanded) {
                return Row(
                  children: [
                    Expanded(flex: 4, child: listPanel),
                    const VerticalDivider(width: 1),
                    Expanded(flex: 6, child: mapPanel),
                  ],
                );
              }
              return listPanel; // el mapa se abre en hoja modal
```

Extrae `listPanel` y `mapPanel` como variables locales a partir del contenido actual. **No cambies la lógica de filtrado ni las llamadas al servicio**; esto es solo reorganización de layout.

4h. **Tarjeta del mapa** ([L808-920](../../../lib/features/dashboard/presentation/pages/workshop_directory_screen.dart#L808-L920)): `width: 240` → `ConstrainedBox(constraints: const BoxConstraints(minWidth: 200, maxWidth: 280))`.

4i. Sustituye los 8 `GoogleFonts.inter` por `AppTextStyles.*` y los literales de spacing/radio por tokens.

- [ ] **Step 5: Correr los tests y verificar a mano**

Run: `flutter test test/features/dashboard/presentation/pages/workshop_directory_test.dart`
Expected: PASS (6 tests)

Verificación manual **obligatoria** (los tests de esta tarea son estructurales; el layout no está cubierto):

```bash
flutter run -d chrome
```

Ir a `/workshop_directory` y comprobar en 375 / 768 / 1024 / 1440, light y dark:
1. Los chips de filtro son morados (light) / teal (dark), no azules.
2. A partir de 840 px hay split lista/mapa; por debajo, solo lista.
3. El mapa carga y los marcadores responden.
4. No hay scroll horizontal a 320 px.

Adjunta capturas de los cuatro anchos al PR.

- [ ] **Step 6: Commit**

```bash
dart format . && flutter analyze && flutter test
git add lib/features/dashboard/presentation/pages/workshop_directory_screen.dart test/features/dashboard/presentation/pages/workshop_directory_test.dart
git commit -m "feat(dashboard): split workshop directory into list+map and fix its palette

Los chips de filtro usaban Colors.blue dentro de una identidad morado/teal, y la
pantalla re-derivaba la paleta oscura a mano (#0F172A, #1E293B). 22 colores
literales en total, los mas de todo el modulo.

Anade split persistente lista/mapa a partir de expanded (>=840px); por debajo el
mapa sigue en hoja modal. Sustituye la barra de busqueda por AppTextField y anade
semantica a las calificaciones, que antes eran solo visuales.

Limitacion declarada: las aserciones de esta tarea son estructurales sobre el
fuente porque GoogleMap no renderiza en flutter_test sin un mock de plataforma.
El layout se verifico a mano en 375/768/1024/1440 (capturas en el PR)."
```

---

### Task 12: Limpieza y ratchet

**Files:**
- Delete: `lib/core/widgets/responsive_web_wrapper.dart`
- Modify: `test/core/theme/no_hardcoded_colors_test.dart`

- [ ] **Step 1: Confirmar que `ResponsiveContainer` está muerto y borrarlo**

```bash
grep -rn "ResponsiveContainer\|responsive_web_wrapper" lib test
```

Expected: solo su propia declaración en `lib/core/widgets/responsive_web_wrapper.dart`. **Cero consumidores** — quedó obsoleto al llegar `AppPageBody` en la Fase 1, y ya antes no lo usaba nadie.

Si el `grep` devuelve algún consumidor, migra ese punto a `AppPageBody` antes de borrar.

```bash
git rm lib/core/widgets/responsive_web_wrapper.dart
```

- [ ] **Step 2: Añadir las rutas de esta fase al ratchet**

En `test/core/theme/no_hardcoded_colors_test.dart`:

```dart
  // ── Fase 4 (módulo dashboard) ──
  'lib/core/theme/app_severity.dart',
  'lib/core/widgets/app_section_header.dart',
  'lib/features/dashboard/presentation/pages',
```

- [ ] **Step 3: Correr y confirmar que pasa**

Run: `flutter test test/core/theme/no_hardcoded_colors_test.dart`
Expected: PASS. Si falla, quedan literales en alguna de las 9 pantallas — arréglalos; **no quites la ruta de la lista**.

Nota: `lib/features/dashboard/presentation/widgets/` **no** entra todavía. Sus ficheros (`add_vehicle_form` 13 literales, `share_vehicle_sheet` 9, `license_plate_widget` 5, `expense_summary_card`, `vehicle_gallery_widget`) no se tocan en esta fase y siguen sucios. Añádelo como tarea explícita al backlog del PR; **no** lo silencies.

- [ ] **Step 4: Verificación final y commit**

```bash
dart format . && flutter analyze && flutter test
git add test/core/theme/no_hardcoded_colors_test.dart
git commit -m "chore(dashboard): drop dead ResponsiveContainer, extend colour ratchet to phase 4"
```

---

## Verificación de cierre de fase

- [ ] `flutter test` — suite completa verde, incluidos los cuatro tests preexistentes del módulo.
- [ ] `flutter analyze` — sin errores.
- [ ] `dart format .` sin cambios pendientes.
- [ ] `grep -rn "GoogleFonts\." lib/features/dashboard/presentation/pages` → vacío.
- [ ] `grep -rn "ColorScheme.light(" lib/features/dashboard` → vacío (los dos date pickers arreglados).
- [ ] **Matriz de anchos y temas.** `flutter run -d chrome`, recorrer las 9 pantallas en 320 / 375 / 600 / 768 / 840 / 1024 / 1200 / 1440, en light y dark. Ninguna con scroll horizontal.
- [ ] **Daltonismo.** Con *Emulate vision deficiencies → Protanopia* en DevTools, comprobar que en `alerts_screen`, `garage_screen` y `vehicle_profile_screen` se sigue distinguiendo crítico de preventivo. Este es el criterio que la Task 1 y la Task 8 existen para cumplir.
- [ ] **Reduced motion.** Con la preferencia activa, `garage_screen` no debe escalonar la entrada y las tarjetas no deben encogerse al pulsar; todo debe seguir siendo usable.
- [ ] **Lector de pantalla.** Con el *Semantics Debugger*, recorrer `notifications_screen` y `alerts_screen`: cada notificación debe anunciarse como una unidad indicando si está sin leer, y cada alerta debe anunciar su severidad.
- [ ] Pre-Delivery Checklist de `ui-ux-pro-max` `references/pro-rules.md` completa.
- [ ] `Skill(review-animations)` sobre el diff de la fase.
- [ ] `Skill(superpowers:requesting-code-review)`.

**Criterio de éxito de la Fase 4:**

- Las 9 pantallas cambian de estructura en al menos uno de los cortes 600 / 840 / 1200: rejilla adaptativa (`garage`, `vehicle_profile`, `alerts`, `service_history`), dos columnas (`dashboard`), split lista/mapa (`workshop_directory`) o ancho acotado (`notifications`, `task_config`, `task_complete`).
- Cero `GoogleFonts` directos y cero colores literales en `presentation/pages` del módulo, protegido por el ratchet.
- La severidad se comunica con icono además de color en las cuatro pantallas que la muestran, desde una única fuente (`AppSeverity`).
- Ningún control tappable baja de 48 dp; en particular desaparecen `MaterialTapTargetSize.shrinkWrap` y `Size(0, 40)` de `alerts_screen`.
- Los dos selectores de fecha respetan el dark mode.
- `task_complete_screen` deja de tener su propia paleta y se invierte correctamente en dark, como el resto de la app.
- **Deuda declarada, no escondida:** `lib/features/dashboard/presentation/widgets/` (5 ficheros, ~40 colores literales) queda fuera de esta fase y entra al backlog; y `workshop_directory_screen` se verifica a mano porque `GoogleMap` no renderiza en `flutter_test`.
