# Fase 2 — Shell y navegación adaptativa — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: `superpowers:subagent-driven-development` (recomendado) o `superpowers:executing-plans`.
>
> **REQUIRED DESIGN SKILLS:** invoca `Skill(ui-ux-pro-max:ui-ux-pro-max)` antes de las Tasks 2, 3, 4 y 5, y `Skill(emil-design-eng)` antes de cualquier paso que toque motion (Tasks 2, 4, 6). Corre además:
> `python "C:/Users/User/.claude/plugins/cache/ui-ux-pro-max-skill/ui-ux-pro-max/2.13.0/.claude/skills/ui-ux-pro-max/scripts/search.py" "navigation hierarchy bottom nav rail back behavior" --domain ux`
> La sección §9 de su tabla de prioridades (*Navigation Patterns, impacto HIGH*) es el criterio de esta fase: *predictable back, bottom nav ≤5, deep linking*; anti-patrones *overloaded nav, broken back behavior*.
>
> **PRERREQUISITO:** la Fase 1 debe estar completa y mergeada. Esta fase consume `AppBreakpoints`, `WindowClass`, `AppMotion`, `AppPageBody` y el harness `pumpAtWidth`.
>
> **CONTEXTO OBLIGATORIO:** `...-00-master.md` §2 (Global Constraints) y §3 (window size classes).

**Goal:** Que el shell de la app cambie de **estructura** de navegación —no solo de escala— al cruzar cada corte de `WindowClass`, eliminando de paso el segundo sistema de breakpoints (`responsive_framework`) que hoy contradice al primero.

**Architecture:** Se extrae la lista de destinos de navegación a un único módulo (`AppNavDestinations`) que consumen las tres presentaciones —bottom bar, `NavigationRail` y top bar— para que no puedan divergir. `MainScaffold` pasa a elegir presentación por `WindowClass` en vez de por el booleano `isDesktop`, cubriendo por primera vez la franja 600–1199 px con un rail. Los cinco puntos que usan `responsive_framework` migran a `AppBreakpoints` y el paquete se desinstala.

**Tech Stack:** Flutter Material 3 (`NavigationBar`, `NavigationRail`, `NavigationDrawer`), go_router 17 (`ShellRoute`). Sin dependencias nuevas; se **elimina** `responsive_framework: ^1.5.1`.

## Global Constraints

Heredadas de `...-00-master.md` §2. Las que muerden aquí:

- Cero colores hardcodeados en los ficheros tocados. `main_scaffold.dart` tiene hoy 5 (`Colors.white`, `Colors.white12`, `Colors.black12`, `Colors.white70`, `Colors.black87`), `app_top_nav_bar.dart` tiene 2, `mechanic_sidebar.dart` tiene 3.
- Touch targets ≥ 48×48 dp en **todos** los destinos de navegación.
- Todo destino sin texto visible lleva `tooltip` o `Semantics.label`.
- Los cortes de navegación son solo los de `WindowClass`. Prohibido introducir un cuarto umbral ad hoc.
- No se altera ninguna ruta de `app_router.dart` ni el comportamiento de `context.go`/`context.push` existente. Esta fase cambia **cómo se presenta** la navegación, no a dónde lleva.
- `dart format .`, `dart fix --apply`, `flutter analyze` limpio antes de cada commit.

## File Structure

| Fichero | Responsabilidad | Estado |
|---|---|---|
| `lib/core/widgets/navigation/app_nav_destination.dart` | Modelo y lista canónica de destinos + resolución de índice desde la ruta. Fuente única. | Crear (Task 2) |
| `lib/core/widgets/navigation/app_bottom_nav.dart` | Presentación `compact`: `NavigationBar` de Material 3. | Crear (Task 3) |
| `lib/core/widgets/navigation/app_nav_rail.dart` | Presentación `medium`/`expanded`: `NavigationRail` colapsado/extendido. | Crear (Task 4) |
| `lib/core/widgets/main_scaffold.dart` | Elegir presentación por `WindowClass` y por rol. Se le extrae la nav bar embebida. | Modificar (Task 5) |
| `lib/core/widgets/app_top_nav_bar.dart` | Presentación `large` del rol propietario. Tokenizar y hacerla resistente a overflow. | Modificar (Task 6) |
| `lib/features/mechanic/presentation/widgets/mechanic_sidebar.dart` | Sidebar del rol taller. Tokenizar, quitar la tercera familia tipográfica. | Modificar (Task 7) |
| `lib/core/widgets/app_scaffold.dart` | Limpiar código muerto y aplicar gutter adaptativo. | Modificar (Task 8) |
| `lib/core/widgets/app_bottom_nav_bar.dart` | **Componente duplicado y muerto** — ver Task 3. | Eliminar (Task 3) |

**Hallazgo que motiva la Task 3:** existen **dos** barras inferiores. [`AppBottomNavBar`](../../../lib/core/widgets/app_bottom_nav_bar.dart) (4 destinos: Inicio/Garaje/Talleres/Perfil) no la referencia nadie; la que se renderiza es `InstagramBottomNavBar`, declarada dentro de [main_scaffold.dart:48-129](../../../lib/core/widgets/main_scaffold.dart#L48-L129) con 5 destinos. Son dos verdades distintas sobre cuál es la navegación principal de la app.

---

### Task 1: Eliminar `responsive_framework`

**Files:**
- Modify: `lib/main.dart:8,354-362`
- Modify: `lib/features/dashboard/presentation/pages/garage_screen.dart:17,82`
- Modify: `lib/features/dashboard/presentation/pages/workshop_directory_screen.dart:15,310`
- Modify: `lib/features/profile/presentation/pages/user_profile_screen.dart:2,119,180`
- Modify: `lib/features/chat/presentation/pages/conversaciones_list_screen.dart:3,62`
- Modify: `pubspec.yaml:72`
- Test: `test/core/theme/single_breakpoint_source_test.dart`

**Interfaces:**
- Consumes: `AppBreakpoints`, `WindowClass`, `WindowClassX.isAtLeastExpanded` (Fase 1 Task 1).
- Produces: nada público nuevo. Deja el árbol con una sola escala de breakpoints.

**El bug concreto que esto arregla:** a 900 px, `ResponsiveBreakpoints.of(context).largerThan(TABLET)` devuelve `true` (su `DESKTOP` empieza en 801), así que `garage_screen` se dibuja como desktop; pero `Responsive.isDesktop(context)` devuelve `false` (su `desktop` empieza en 1200), así que `MainScaffold` sigue pintando la bottom nav de móvil. La pantalla y su shell discrepan sobre en qué dispositivo están.

**Cambio de comportamiento que hay que declarar:** `largerThan(TABLET)` es "> 800". El equivalente más cercano en la nueva escala es `isAtLeastExpanded` ("≥ 840"). En la franja **801–839 px** estas cinco pantallas pasarán de tratarse como desktop a tratarse como `medium`. Es correcto —a 820 px de ancho una tabla de desktop no cabe— pero es un cambio real y debe verificarse a mano en esos anchos.

- [ ] **Step 1: Escribir el test que falla**

```dart
// test/core/theme/single_breakpoint_source_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ningún fichero de lib/ importa responsive_framework', () {
    final offenders = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => f.readAsStringSync().contains('responsive_framework'))
        .map((f) => f.path.replaceAll(r'\', '/'))
        .toList();

    expect(
      offenders,
      isEmpty,
      reason:
          'responsive_framework introduce una segunda escala de breakpoints '
          '(DESKTOP >= 801) que contradice a AppBreakpoints (large >= 1200). '
          'Migra a AppBreakpoints. Ver el plan maestro §3.\n'
          '${offenders.join('\n')}',
    );
  });

  test('responsive_framework no está en pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec.contains('responsive_framework'), isFalse);
  });

  test('lib/features no decide layout con MediaQuery crudo', () {
    final offenders = <String>[];

    for (final file in Directory('lib/features')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains('MediaQuery.of(context).size.width') ||
            lines[i].contains('MediaQuery.sizeOf(context).width')) {
          offenders.add(
            '${file.path.replaceAll(r'\', '/')}:${i + 1}  ${lines[i].trim()}',
          );
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Usa AppBreakpoints.of(context) o LayoutBuilder + '
          'AppBreakpoints.fromWidth(constraints.maxWidth).\n'
          '${offenders.join('\n')}',
    );
  });
}
```

- [ ] **Step 2: Correr el test y confirmar que falla**

Run: `flutter test test/core/theme/single_breakpoint_source_test.dart`
Expected: FAIL en los tres tests. El primero lista 5 ficheros, el segundo encuentra la dependencia, el tercero lista ~10 ficheros con `MediaQuery` crudo.

- [ ] **Step 3: Migrar los 5 puntos de uso**

3a. `lib/main.dart` — borra el import de la línea 8 y sustituye el `builder:` de las líneas 354–362 por:

```dart
      // Sin builder: los breakpoints los define AppBreakpoints y los consume
      // cada pantalla vía LayoutBuilder. Un wrapper global de breakpoints
      // creaba una segunda escala que contradecía a la primera.
```

Es decir, elimina el parámetro `builder:` completo del `MaterialApp.router`.

3b. `lib/features/dashboard/presentation/pages/garage_screen.dart` — borra el import de la línea 17, añade `import 'package:autodoc/core/theme/app_breakpoints.dart';`, y en la línea 82:

```dart
    // Antes: final isDesktop = ResponsiveBreakpoints.of(context).largerThan(TABLET);
    final isDesktop = AppBreakpoints.of(context).isAtLeastExpanded;
```

3c. `lib/features/dashboard/presentation/pages/workshop_directory_screen.dart` — mismo cambio: borra el import de la línea 15, añade el de `app_breakpoints.dart`, y en la línea 310:

```dart
    final isDesktop = AppBreakpoints.of(context).isAtLeastExpanded;
```

3d. `lib/features/profile/presentation/pages/user_profile_screen.dart` — borra el import de la línea 2, añade el de `app_breakpoints.dart`, y sustituye las dos condiciones (líneas 119 y 180):

```dart
        appBar: AppBreakpoints.of(context).isAtLeastExpanded
```

```dart
              if (!AppBreakpoints.of(context).isAtLeastExpanded)
```

3e. `lib/features/chat/presentation/pages/conversaciones_list_screen.dart` — borra el import de la línea 3, añade el de `app_breakpoints.dart`, y en la línea 62:

```dart
      appBar: AppBreakpoints.of(context).isAtLeastExpanded
```

3f. `pubspec.yaml` — borra la línea `responsive_framework: ^1.5.1` (línea 72).

Luego: `flutter pub get`

- [ ] **Step 4: Corregir los `MediaQuery` crudos de `lib/features/`**

El tercer test aún falla. Los 10 puntos son: `onboarding_screen`, `workshop_settings_screen`, `vehicle_search_screen`, `reparaciones_kanban_screen`, `mechanic_service_history_screen`, `mechanic_reviews_screen`, `mechanic_dashboard_screen`, `empleados_screen`, `catalogo_servicios_screen`, `admin_dashboard_screen`.

Localízalos con:

```bash
grep -rn "MediaQuery.of(context).size.width\|MediaQuery.sizeOf(context).width" lib/features
```

Para cada uno, aplica **una** de estas dos sustituciones según lo que haga la línea:

- Si compara contra un umbral para elegir layout → `AppBreakpoints.of(context)` + `switch`/`isAtLeast*`.
- Si calcula una fracción del ancho para dimensionar algo → envolver en `LayoutBuilder` y usar `constraints.maxWidth`.

Si algún caso no encaja en ninguna de las dos y requiere rediseñar la pantalla, **no lo fuerces aquí**: es trabajo de la fase de ese módulo. En ese caso, añade la ruta del fichero a una lista `kPendingMediaQueryMigration` en el test, con un comentario apuntando a la fase que lo resolverá, y ajusta el test para saltar esas rutas. Documenta la lista en el commit. Esa lista debe quedar vacía al terminar la Fase 8.

- [ ] **Step 5: Correr el test y confirmar que pasa**

Run: `flutter test test/core/theme/single_breakpoint_source_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 6: Verificar en el rango afectado**

Run: `flutter test && flutter analyze`
Expected: verde.

Verificación manual obligatoria (es donde está el cambio de comportamiento):

```bash
flutter run -d chrome
```

Redimensiona la ventana a **810 px** y comprueba `garage`, `workshop_directory`, `user_profile` y `chat_list`: deben mostrarse ahora con el layout compacto/medium, no con el de desktop, y el shell debe coincidir con ellas. Toma captura antes/después.

- [ ] **Step 7: Commit**

```bash
dart format . && dart fix --apply
git add lib/main.dart lib/features pubspec.yaml pubspec.lock test/core/theme/single_breakpoint_source_test.dart
git commit -m "refactor(responsive): drop responsive_framework in favour of AppBreakpoints

Convivían dos escalas de breakpoints contradictorias: responsive_framework
(DESKTOP >= 801) y Responsive/AppBreakpoints (large >= 1200). A 900px una
pantalla se dibujaba como desktop mientras el shell seguía en modo móvil.

Los 5 usos de largerThan(TABLET) pasan a isAtLeastExpanded (>= 840). En la
franja 801-839px esas pantallas ahora se tratan como medium, verificado a mano
a 810px."
```

---

### Task 2: `AppNavDestinations` — fuente única de destinos

**Files:**
- Create: `lib/core/widgets/navigation/app_nav_destination.dart`
- Test: `test/core/widgets/navigation/app_nav_destination_test.dart`

**Interfaces:**
- Consumes: nada.
- Produces: `class AppNavDestination { final String route; final IconData icon; final IconData selectedIcon; final String label; final String semanticLabel; }` (constructor `const AppNavDestination({required this.route, required this.icon, required this.selectedIcon, required this.label, required this.semanticLabel})`); `AppNavDestinations.owner` (`List<AppNavDestination>`); `AppNavDestinations.indexForLocation(String location, {List<AppNavDestination> destinations = AppNavDestinations.owner}) -> int`. Consumido por Tasks 3, 4, 5 y 6.

**Por qué:** hoy la misma navegación está declarada tres veces con tres verdades distintas — `InstagramBottomNavBar` ([main_scaffold.dart:83-122](../../../lib/core/widgets/main_scaffold.dart#L83-L122)) tiene 5 destinos, `AppBottomNavBar` tiene 4 y en otro orden, y `AppTopNavBar` ([app_top_nav_bar.dart:74-97](../../../lib/core/widgets/app_top_nav_bar.dart#L74-L97)) tiene 4 sin *Perfil* (vive aparte, a la derecha). Añadir un destino obliga hoy a tocar tres ficheros y es fácil olvidarse de uno.

La lista canónica se toma de la que **realmente se renderiza** (`InstagramBottomNavBar`), en su orden actual, para no cambiar el índice de ninguna pestaña: `/dashboard`, `/garage`, `/chat_list`, `/workshop_directory`, `/user_profile`. Son 5, justo en el límite de la regla *bottom nav ≤ 5* de `ui-ux-pro-max` §9.

- [ ] **Step 1: Invocar la skill de UX de navegación**

`Skill(ui-ux-pro-max:ui-ux-pro-max)` y luego:

```bash
python "C:/Users/User/.claude/plugins/cache/ui-ux-pro-max-skill/ui-ux-pro-max/2.13.0/.claude/skills/ui-ux-pro-max/scripts/search.py" "navigation hierarchy bottom nav rail back behavior deep linking" --domain ux
```

Confirma la regla `bottom-nav-limit` (≤ 5 destinos) y `nav-hierarchy`. Anota en el commit que la lista queda **exactamente en 5** y que cualquier destino futuro exige mover uno a un menú secundario, no añadir un sexto.

- [ ] **Step 2: Escribir el test que falla**

```dart
// test/core/widgets/navigation/app_nav_destination_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/widgets/navigation/app_nav_destination.dart';

void main() {
  group('AppNavDestinations.owner', () {
    test('respeta el límite de 5 destinos de una bottom nav', () {
      expect(AppNavDestinations.owner.length, lessThanOrEqualTo(5));
    });

    test('conserva el orden actual de pestañas', () {
      expect(
        AppNavDestinations.owner.map((d) => d.route).toList(),
        ['/dashboard', '/garage', '/chat_list', '/workshop_directory', '/user_profile'],
      );
    });

    test('todo destino tiene label y semanticLabel no vacíos', () {
      for (final destination in AppNavDestinations.owner) {
        expect(destination.label, isNotEmpty, reason: destination.route);
        expect(destination.semanticLabel, isNotEmpty, reason: destination.route);
      }
    });

    test('el icono seleccionado difiere del de reposo', () {
      for (final destination in AppNavDestinations.owner) {
        expect(
          destination.selectedIcon,
          isNot(destination.icon),
          reason: '${destination.route}: el estado activo no se distingue',
        );
      }
    });
  });

  group('indexForLocation', () {
    test('resuelve cada ruta exacta a su índice', () {
      for (var i = 0; i < AppNavDestinations.owner.length; i++) {
        expect(
          AppNavDestinations.indexForLocation(AppNavDestinations.owner[i].route),
          i,
        );
      }
    });

    test('resuelve sub-rutas al destino padre', () {
      expect(AppNavDestinations.indexForLocation('/garage/123'), 1);
      expect(AppNavDestinations.indexForLocation('/chat_list?filter=abiertas'), 2);
    });

    test('una ruta desconocida cae al primer destino', () {
      expect(AppNavDestinations.indexForLocation('/ruta_inexistente'), 0);
      expect(AppNavDestinations.indexForLocation(''), 0);
    });

    test('no confunde prefijos parciales de otra ruta', () {
      // '/user_profile_setup' no debe resolverse a '/user_profile'.
      expect(AppNavDestinations.indexForLocation('/user_profile_setup'), 0);
    });
  });
}
```

- [ ] **Step 3: Correr el test y confirmar que falla**

Run: `flutter test test/core/widgets/navigation/app_nav_destination_test.dart`
Expected: FAIL — `Couldn't resolve the package 'autodoc/core/widgets/navigation/app_nav_destination.dart'`.

- [ ] **Step 4: Escribir la implementación mínima**

```dart
// lib/core/widgets/navigation/app_nav_destination.dart
import 'package:flutter/material.dart';

/// Un destino de la navegación principal.
///
/// Lo consumen las tres presentaciones (bottom bar en `compact`, rail en
/// `medium`/`expanded`, top bar en `large`) para que no puedan divergir.
@immutable
class AppNavDestination {
  /// Ruta de go_router a la que navega.
  final String route;

  /// Icono en reposo (outline).
  final IconData icon;

  /// Icono activo (filled). Debe diferir de [icon]: el estado activo no puede
  /// depender solo del color.
  final IconData selectedIcon;

  /// Texto visible.
  final String label;

  /// Descripción para lector de pantalla. Más explícita que [label], que está
  /// optimizado para caber.
  final String semanticLabel;

  const AppNavDestination({
    required this.route,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.semanticLabel,
  });
}

class AppNavDestinations {
  AppNavDestinations._();

  /// Navegación principal del rol Propietario.
  ///
  /// Exactamente 5 destinos: es el máximo de una bottom nav. Añadir un sexto
  /// exige mover otro a un menú secundario, no ampliar la lista.
  static const List<AppNavDestination> owner = [
    AppNavDestination(
      route: '/dashboard',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_filled,
      label: 'Inicio',
      semanticLabel: 'Inicio, resumen de tus vehículos',
    ),
    AppNavDestination(
      route: '/garage',
      icon: Icons.directions_car_outlined,
      selectedIcon: Icons.directions_car,
      label: 'Garaje',
      semanticLabel: 'Garaje, tus vehículos registrados',
    ),
    AppNavDestination(
      route: '/chat_list',
      icon: Icons.chat_bubble_outline_rounded,
      selectedIcon: Icons.chat_bubble_rounded,
      label: 'Chat',
      semanticLabel: 'Chat, conversaciones con talleres',
    ),
    AppNavDestination(
      route: '/workshop_directory',
      icon: Icons.build_circle_outlined,
      selectedIcon: Icons.build_circle,
      label: 'Talleres',
      semanticLabel: 'Talleres, directorio de talleres',
    ),
    AppNavDestination(
      route: '/user_profile',
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      label: 'Perfil',
      semanticLabel: 'Perfil, tu cuenta y ajustes',
    ),
  ];

  /// Índice del destino que corresponde a [location].
  ///
  /// Acepta sub-rutas (`/garage/123` → Garaje) sin confundir prefijos parciales
  /// (`/user_profile_setup` **no** es `/user_profile`). Una ruta desconocida
  /// cae al primer destino.
  static int indexForLocation(
    String location, {
    List<AppNavDestination> destinations = owner,
  }) {
    final path = location.split('?').first;

    for (var i = 0; i < destinations.length; i++) {
      final route = destinations[i].route;
      if (path == route || path.startsWith('$route/')) return i;
    }
    return 0;
  }
}
```

- [ ] **Step 5: Correr el test y confirmar que pasa**

Run: `flutter test test/core/widgets/navigation/app_nav_destination_test.dart`
Expected: PASS (8 tests)

- [ ] **Step 6: Verificar y commitear**

```bash
dart format . && flutter analyze && flutter test
git add lib/core/widgets/navigation/app_nav_destination.dart test/core/widgets/navigation/app_nav_destination_test.dart
git commit -m "feat(navigation): add AppNavDestinations as single source of nav destinations"
```

---

### Task 3: `AppBottomNav` — presentación `compact`

**Files:**
- Create: `lib/core/widgets/navigation/app_bottom_nav.dart`
- Delete: `lib/core/widgets/app_bottom_nav_bar.dart`
- Test: `test/core/widgets/navigation/app_bottom_nav_test.dart`

**Interfaces:**
- Consumes: `AppNavDestination`, `AppNavDestinations` (Task 2); `AppMotion.press`, `AppMotion.easeOut` (Fase 1 Task 2); `context.appColors`.
- Produces: `AppBottomNav({List<AppNavDestination> destinations = AppNavDestinations.owner, required int currentIndex, required ValueChanged<int> onDestinationSelected})`. Consumido por la Task 5.

**Qué arregla respecto a `InstagramBottomNavBar`:**
- 5 colores hardcodeados (`Colors.white` L69, `Colors.white12`/`Colors.black12` L72, `Colors.transparent` L161, `Colors.white70`/`Colors.black87` L168) → tokens.
- Área tappable: hoy es `padding: EdgeInsets.all(12)` + icono de 26 = 50 dp, pero el `GestureDetector` la envuelve sin garantía de mínimo. Se fija ≥ 48 dp explícitamente.
- Sin etiqueta accesible: hoy son iconos pelados dentro de un `GestureDetector`, invisibles para un lector de pantalla.
- Sin etiqueta visible: un icono de "taller" sin texto no es autoexplicativo. Material 3 `NavigationBar` las muestra.
- Duración hardcodeada `Duration(milliseconds: 200)` en L154 → `AppMotion`.

- [ ] **Step 1: Escribir el test que falla**

```dart
// test/core/widgets/navigation/app_bottom_nav_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/widgets/navigation/app_bottom_nav.dart';
import 'package:autodoc/core/widgets/navigation/app_nav_destination.dart';

import '../../../support/responsive_harness.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    int currentIndex = 0,
    ValueChanged<int>? onSelected,
    Brightness brightness = Brightness.light,
  }) async {
    await pumpAtWidth(
      tester,
      Align(
        alignment: Alignment.bottomCenter,
        child: AppBottomNav(
          currentIndex: currentIndex,
          onDestinationSelected: onSelected ?? (_) {},
        ),
      ),
      width: 375,
      brightness: brightness,
    );
  }

  testWidgets('renderiza un destino por entrada de AppNavDestinations', (
    tester,
  ) async {
    await pump(tester);

    for (final destination in AppNavDestinations.owner) {
      expect(
        find.text(destination.label),
        findsOneWidget,
        reason: 'falta la etiqueta visible de ${destination.route}',
      );
    }
  });

  testWidgets('cada destino tiene un área tappable de al menos 48dp', (
    tester,
  ) async {
    await pump(tester);

    final destinations = find.byType(NavigationDestination);
    expect(destinations, findsNWidgets(AppNavDestinations.owner.length));

    for (var i = 0; i < AppNavDestinations.owner.length; i++) {
      final size = tester.getSize(destinations.at(i));
      expect(
        size.height,
        greaterThanOrEqualTo(48.0),
        reason: 'destino $i mide ${size.height}dp de alto',
      );
    }
  });

  testWidgets('notifica el índice tocado', (tester) async {
    int? selected;
    await pump(tester, onSelected: (index) => selected = index);

    await tester.tap(find.text('Garaje'));
    await tester.pumpAndSettle();

    expect(selected, 1);
  });

  testWidgets('el destino activo usa el icono filled, no solo color', (
    tester,
  ) async {
    await pump(tester, currentIndex: 1);

    expect(find.byIcon(AppNavDestinations.owner[1].selectedIcon), findsOneWidget);
    expect(find.byIcon(AppNavDestinations.owner[1].icon), findsNothing);
  });

  testWidgets('no desborda a 320px', (tester) async {
    await pumpAtWidth(
      tester,
      Align(
        alignment: Alignment.bottomCenter,
        child: AppBottomNav(currentIndex: 0, onDestinationSelected: (_) {}),
      ),
      width: 320,
    );
    expectNoOverflow(tester);
  });

  testWidgets('renderiza en dark mode sin excepciones', (tester) async {
    await pump(tester, brightness: Brightness.dark);
    expectNoOverflow(tester);
  });
}
```

- [ ] **Step 2: Correr el test y confirmar que falla**

Run: `flutter test test/core/widgets/navigation/app_bottom_nav_test.dart`
Expected: FAIL — `Couldn't resolve the package 'autodoc/core/widgets/navigation/app_bottom_nav.dart'`.

- [ ] **Step 3: Escribir la implementación mínima**

```dart
// lib/core/widgets/navigation/app_bottom_nav.dart
import 'package:flutter/material.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/widgets/navigation/app_nav_destination.dart';

/// Navegación principal en `WindowClass.compact`.
///
/// Usa el `NavigationBar` de Material 3 en vez de una `Row` de `GestureDetector`
/// hecha a mano: trae gratis las etiquetas visibles, el indicador de selección,
/// el ripple, el tamaño mínimo de destino y la semántica de accesibilidad.
class AppBottomNav extends StatelessWidget {
  final List<AppNavDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  const AppBottomNav({
    super.key,
    this.destinations = AppNavDestinations.owner,
    required this.currentIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onDestinationSelected,
      backgroundColor: colors.surfaceContainer,
      indicatorColor: colors.primary.withValues(alpha: 0.15),
      surfaceTintColor: Colors.transparent,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: [
        for (final destination in destinations)
          NavigationDestination(
            icon: Icon(destination.icon, color: colors.textSecondary),
            selectedIcon: Icon(destination.selectedIcon, color: colors.primary),
            label: destination.label,
            tooltip: destination.semanticLabel,
          ),
      ],
    );
  }
}

/// Tema de la barra inferior. Se aplica en `AppTheme` para no repetir estilos
/// en cada instancia.
NavigationBarThemeData appBottomNavTheme(AppColors colors) {
  return NavigationBarThemeData(
    height: 72,
    labelTextStyle: WidgetStateProperty.resolveWith((states) {
      final selected = states.contains(WidgetState.selected);
      return AppTextStyles.labelSmall.copyWith(
        color: selected ? colors.primary : colors.textSecondary,
        fontWeight: selected ? FontWeight.bold : FontWeight.w500,
      );
    }),
  );
}
```

Nota: `NavigationBar` de Material 3 ya garantiza destinos de ≥ 48 dp y aplica su propia animación de indicador (~200 ms con la curva de Material), así que no hace falta `AnimatedContainer` manual. Esto es una aplicación directa de la guideline *"Semantic native controls — Prefer native interactive primitives"* de `ui-ux-pro-max` `references/pro-rules.md`.

- [ ] **Step 4: Registrar el tema y borrar el componente muerto**

4a. En `lib/core/theme/app_theme.dart`, dentro de `ThemeData` de `light` y de `dark`, añade tras `cardTheme:`:

```dart
      navigationBarTheme: appBottomNavTheme(
        const AppColors(
          // ...las mismas 15 constantes que ya se pasan al ThemeExtension
          // de abajo; extráelas a una variable local `appColors` y reúsala en
          // ambos sitios para no duplicarlas.
        ),
      ),
```

Refactoriza cada getter para declarar primero `const appColors = AppColors(...)` y usarlo tanto en `navigationBarTheme` como en `extensions:`. Así el bloque de 15 campos aparece una sola vez por tema.

4b. Borra el componente duplicado y muerto:

```bash
git rm lib/core/widgets/app_bottom_nav_bar.dart
grep -rn "AppBottomNavBar" lib test
```

El `grep` debe devolver vacío. Si devuelve algo, migra ese punto a `AppBottomNav` antes de continuar.

- [ ] **Step 5: Correr el test y confirmar que pasa**

Run: `flutter test test/core/widgets/navigation/app_bottom_nav_test.dart`
Expected: PASS (6 tests)

- [ ] **Step 6: Verificar y commitear**

```bash
dart format . && flutter analyze && flutter test
git add lib/core/widgets/navigation/app_bottom_nav.dart lib/core/theme/app_theme.dart test/core/widgets/navigation/app_bottom_nav_test.dart
git rm lib/core/widgets/app_bottom_nav_bar.dart
git commit -m "feat(navigation): add AppBottomNav on Material 3 NavigationBar

Sustituye la Row de GestureDetector hecha a mano (5 colores hardcodeados, sin
etiquetas visibles, sin semántica) por el primitivo nativo. Elimina
AppBottomNavBar, un segundo componente de barra inferior con 4 destinos en otro
orden que no referenciaba nadie."
```

---

### Task 4: `AppNavRail` — presentación `medium` y `expanded`

**Files:**
- Create: `lib/core/widgets/navigation/app_nav_rail.dart`
- Test: `test/core/widgets/navigation/app_nav_rail_test.dart`

**Interfaces:**
- Consumes: `AppNavDestination`, `AppNavDestinations` (Task 2); `WindowClass` (Fase 1 Task 1); `context.appColors`.
- Produces: `AppNavRail({List<AppNavDestination> destinations = AppNavDestinations.owner, required int currentIndex, required ValueChanged<int> onDestinationSelected, required bool extended})`. Consumido por la Task 5.

**Este es el componente que arregla el grueso de la queja de responsividad.** Hoy la franja 600–1199 px recibe la UI de teléfono con las fuentes un 10–15 % más grandes: una tablet en horizontal muestra una barra inferior de 5 iconos a lo ancho de 1000 px, con 900 px de espacio muerto en el centro. El rail mueve la navegación al lateral y devuelve ese ancho al contenido.

- [ ] **Step 1: Invocar las skills**

`Skill(ui-ux-pro-max:ui-ux-pro-max)` — verifica en `references/pro-rules.md` §Layout & Spacing la regla *"Adaptive gutters by breakpoint — Don't: Same narrow gutter on all device sizes/orientations"*, que es exactamente el fallo que este componente corrige.

`Skill(emil-design-eng)` — el rail cambia entre colapsado y extendido al cruzar 840 px. Ese cambio es un **movimiento en pantalla de un elemento ya visible**, no una entrada: la curva correcta es `AppMotion.easeInOut`, no `easeOut`. Verifícalo contra el árbol de decisión de easing de la skill antes de escribirlo.

- [ ] **Step 2: Escribir el test que falla**

```dart
// test/core/widgets/navigation/app_nav_rail_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/widgets/navigation/app_nav_destination.dart';
import 'package:autodoc/core/widgets/navigation/app_nav_rail.dart';

import '../../../support/responsive_harness.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required double width,
    required bool extended,
    int currentIndex = 0,
    ValueChanged<int>? onSelected,
    Brightness brightness = Brightness.light,
  }) async {
    await pumpAtWidth(
      tester,
      Row(
        children: [
          AppNavRail(
            currentIndex: currentIndex,
            extended: extended,
            onDestinationSelected: onSelected ?? (_) {},
          ),
          const Expanded(child: SizedBox()),
        ],
      ),
      width: width,
      brightness: brightness,
    );
  }

  testWidgets('colapsado muestra iconos sin etiquetas visibles', (tester) async {
    await pump(tester, width: 768, extended: false);

    expect(find.byType(NavigationRail), findsOneWidget);
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isFalse);
    expect(rail.destinations.length, AppNavDestinations.owner.length);
  });

  testWidgets('extendido muestra las etiquetas', (tester) async {
    await pump(tester, width: 1024, extended: true);

    for (final destination in AppNavDestinations.owner) {
      expect(find.text(destination.label), findsOneWidget);
    }
  });

  testWidgets('colapsado ocupa menos ancho que extendido', (tester) async {
    await pump(tester, width: 1024, extended: false);
    final collapsed = tester.getSize(find.byType(NavigationRail)).width;

    await pump(tester, width: 1024, extended: true);
    final expanded = tester.getSize(find.byType(NavigationRail)).width;

    expect(collapsed, lessThan(expanded));
    expect(collapsed, greaterThanOrEqualTo(72.0)); // mínimo tappable + holgura
  });

  testWidgets('notifica el índice seleccionado', (tester) async {
    int? selected;
    await pump(
      tester,
      width: 1024,
      extended: true,
      onSelected: (index) => selected = index,
    );

    await tester.tap(find.text('Talleres'));
    await tester.pumpAndSettle();

    expect(selected, 3);
  });

  testWidgets('cada destino tiene semántica aunque esté colapsado', (
    tester,
  ) async {
    await pump(tester, width: 768, extended: false);

    for (final destination in AppNavDestinations.owner) {
      expect(
        find.bySemanticsLabel(RegExp(RegExp.escape(destination.label))),
        findsWidgets,
        reason: 'sin semántica: ${destination.route}',
      );
    }
  });

  testWidgets('el destino activo usa el icono filled', (tester) async {
    await pump(tester, width: 1024, extended: true, currentIndex: 2);
    expect(find.byIcon(AppNavDestinations.owner[2].selectedIcon), findsOneWidget);
  });

  testWidgets('renderiza en dark mode sin excepciones', (tester) async {
    await pump(tester, width: 1024, extended: true, brightness: Brightness.dark);
    expectNoOverflow(tester);
  });
}
```

- [ ] **Step 3: Correr el test y confirmar que falla**

Run: `flutter test test/core/widgets/navigation/app_nav_rail_test.dart`
Expected: FAIL — `Couldn't resolve the package 'autodoc/core/widgets/navigation/app_nav_rail.dart'`.

- [ ] **Step 4: Escribir la implementación mínima**

```dart
// lib/core/widgets/navigation/app_nav_rail.dart
import 'package:flutter/material.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/widgets/navigation/app_nav_destination.dart';

/// Navegación principal en `WindowClass.medium` y `WindowClass.expanded`.
///
/// Cubre la franja 600–1199 px, que hasta ahora recibía la barra inferior de
/// teléfono estirada a lo ancho de una tablet. Mover la navegación al lateral
/// devuelve ese ancho al contenido.
///
/// [extended] lo decide el shell: `false` en `medium` (solo iconos, ~80 dp),
/// `true` en `expanded` (icono + etiqueta, ~200 dp).
class AppNavRail extends StatelessWidget {
  final List<AppNavDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool extended;

  const AppNavRail({
    super.key,
    this.destinations = AppNavDestinations.owner,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.extended,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return NavigationRail(
      selectedIndex: currentIndex,
      onDestinationSelected: onDestinationSelected,
      extended: extended,
      backgroundColor: colors.surfaceContainer,
      indicatorColor: colors.primary.withValues(alpha: 0.15),
      // Colapsado no hay etiqueta visible, así que el tooltip de cada destino
      // es la única forma de saber a dónde lleva: obligatorio, no opcional.
      labelType: extended
          ? NavigationRailLabelType.none
          : NavigationRailLabelType.all,
      minWidth: 72,
      minExtendedWidth: 200,
      selectedIconTheme: IconThemeData(color: colors.primary),
      unselectedIconTheme: IconThemeData(color: colors.textSecondary),
      selectedLabelTextStyle: AppTextStyles.labelMedium.copyWith(
        color: colors.primary,
        fontWeight: FontWeight.bold,
      ),
      unselectedLabelTextStyle: AppTextStyles.labelMedium.copyWith(
        color: colors.textSecondary,
      ),
      destinations: [
        for (final destination in destinations)
          NavigationRailDestination(
            icon: Tooltip(
              message: destination.semanticLabel,
              child: Icon(destination.icon),
            ),
            selectedIcon: Tooltip(
              message: destination.semanticLabel,
              child: Icon(destination.selectedIcon),
            ),
            label: Text(destination.label),
          ),
      ],
    );
  }
}
```

- [ ] **Step 5: Correr el test y confirmar que pasa**

Run: `flutter test test/core/widgets/navigation/app_nav_rail_test.dart`
Expected: PASS (7 tests)

- [ ] **Step 6: Verificar y commitear**

```bash
dart format . && flutter analyze && flutter test
git add lib/core/widgets/navigation/app_nav_rail.dart test/core/widgets/navigation/app_nav_rail_test.dart
git commit -m "feat(navigation): add AppNavRail for medium/expanded window classes"
```

---

### Task 5: `MainScaffold` adaptativo

**Files:**
- Modify: `lib/core/widgets/main_scaffold.dart` (reescritura completa)
- Test: `test/core/widgets/main_scaffold_adaptive_test.dart`

**Interfaces:**
- Consumes: `AppBreakpoints`, `WindowClass`, `WindowClassX` (Fase 1 Task 1); `AppNavDestinations` (Task 2); `AppBottomNav` (Task 3); `AppNavRail` (Task 4); `AppTopNavBar` (existente); `MechanicSidebar` (existente); `UserProfileProvider` (existente).
- Produces: `MainScaffold({required Widget child})` — misma API pública, no hay que tocar `app_router.dart`.

**Matriz de decisión que implementa:**

| `WindowClass` | Rol Propietario | Rol Mecánico |
|---|---|---|
| `compact` | `AppBottomNav` | `AppBar` + `Drawer(MechanicSidebar)` |
| `medium` | `AppNavRail(extended: false)` | `AppBar` + `Drawer(MechanicSidebar)` |
| `expanded` | `AppNavRail(extended: true)` | `MechanicSidebar` fijo |
| `large` | `AppTopNavBar` | `MechanicSidebar` fijo |

El rol mecánico mantiene el drawer hasta `expanded` porque su sidebar mide 280 dp fijos ([mechanic_sidebar.dart:54](../../../lib/features/mechanic/presentation/widgets/mechanic_sidebar.dart#L54)): a 700 px de ancho dejaría 420 px de contenido, menos que un teléfono. Convertirlo en rail es trabajo de la Fase 5, cuando se rediseñe el sidebar; aquí solo se corrige el umbral de 1200 a 840.

> **Alcance real de `_MechanicShell`, comprobado al escribir la Fase 5.** El `ShellRoute` que monta `MainScaffold` contiene **solo las 5 rutas de propietario** ([app_router.dart:359-405](../../../lib/core/router/app_router.dart#L359-L405)); las 10 rutas del panel de taller son `GoRoute` de primer nivel. La única ruta del shell que un mecánico alcanza es `/chat_list`, exenta del redirect por rol ([app_router.dart:246-250](../../../lib/core/router/app_router.dart#L246-L250)). Así que `_MechanicShell` gobierna **una** pantalla, no diez: las otras nueve montan hoy su propio shell copiado, y es la **Fase 5 Task 1** la que lo unifica en `MechanicScaffold` y hace que `_MechanicShell` delegue en él. Implementa `_MechanicShell` igualmente —da la navegación correcta en `/chat_list`—, pero no lo des por hecho como el shell del rol.

- [ ] **Step 1: Escribir el test que falla**

```dart
// test/core/widgets/main_scaffold_adaptive_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:autodoc/core/models/user_model.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/widgets/main_scaffold.dart';
import 'package:autodoc/core/widgets/navigation/app_bottom_nav.dart';
import 'package:autodoc/core/widgets/navigation/app_nav_rail.dart';
import 'package:autodoc/core/widgets/app_top_nav_bar.dart';
import 'package:autodoc/core/theme/app_theme.dart';

/// Doble del provider de perfil que solo fija el rol.
///
/// **Implementa** `UserProfileProvider` en vez de extenderlo, y no es una
/// preferencia de estilo: la clase real inicializa
/// `final UserService _userService = UserService()` en la declaración del
/// campo ([user_profile_provider.dart:8]), y `UserService` hace
/// `FirebaseFirestore.instance` en la suya ([user_service.dart:9]).
/// Extenderla ejecuta ambos inicializadores y **lanza** en un widget test sin
/// `Firebase.initializeApp()`. Los tres tests que ya existen en
/// `test/features/mechanic/presentation/pages/` usan este mismo patrón y
/// dejaron el motivo escrito.
///
/// A partir de la Fase 5 este doble vive en `test/support/mechanic_harness.dart`
/// como `FakeUserProfileProvider`; si esa fase ya está ejecutada, impórtalo
/// desde ahí en vez de duplicarlo aquí.
class _FakeProfileProvider extends ChangeNotifier
    implements UserProfileProvider {
  _FakeProfileProvider(this.rol);
  final String rol;

  @override
  UserModel? get userData => UserModel(
    idUsuario: 'test-uid',
    nombreCompleto: 'Ana Pérez',
    correo: 'ana@example.com',
    rol: rol,
    fechaRegistro: DateTime(2026, 1, 1),
  );

  @override
  bool get isLoading => false;
  @override
  bool get hasAttemptedFetch => true;
  @override
  String? get fetchedUserId => 'test-uid';
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

Future<void> pumpShell(
  WidgetTester tester, {
  required double width,
  required String rol,
  String location = '/dashboard',
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final router = GoRouter(
    initialLocation: location,
    routes: [
      ShellRoute(
        builder: (context, state, child) => MainScaffold(child: child),
        routes: [
          for (final path in [
            '/dashboard',
            '/garage',
            '/chat_list',
            '/workshop_directory',
            '/user_profile',
          ])
            GoRoute(
              path: path,
              builder: (context, state) => Center(child: Text('body $path')),
            ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ChangeNotifierProvider<UserProfileProvider>.value(
      value: _FakeProfileProvider(rol),
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('rol Propietario', () {
    testWidgets('compact (375) usa la barra inferior', (tester) async {
      await pumpShell(tester, width: 375, rol: 'Propietario');

      expect(find.byType(AppBottomNav), findsOneWidget);
      expect(find.byType(AppNavRail), findsNothing);
      expect(find.byType(AppTopNavBar), findsNothing);
    });

    testWidgets('medium (768) usa el rail colapsado', (tester) async {
      await pumpShell(tester, width: 768, rol: 'Propietario');

      expect(find.byType(AppNavRail), findsOneWidget);
      expect(tester.widget<AppNavRail>(find.byType(AppNavRail)).extended, isFalse);
      expect(find.byType(AppBottomNav), findsNothing);
    });

    testWidgets('expanded (1024) usa el rail extendido', (tester) async {
      await pumpShell(tester, width: 1024, rol: 'Propietario');

      expect(find.byType(AppNavRail), findsOneWidget);
      expect(tester.widget<AppNavRail>(find.byType(AppNavRail)).extended, isTrue);
      expect(find.byType(AppBottomNav), findsNothing);
    });

    testWidgets('large (1440) usa la barra superior', (tester) async {
      await pumpShell(tester, width: 1440, rol: 'Propietario');

      expect(find.byType(AppTopNavBar), findsOneWidget);
      expect(find.byType(AppBottomNav), findsNothing);
      expect(find.byType(AppNavRail), findsNothing);
    });

    testWidgets('exactamente una presentación de nav por ancho', (tester) async {
      for (final width in [320.0, 375.0, 600.0, 768.0, 840.0, 1024.0, 1200.0, 1440.0]) {
        await pumpShell(tester, width: width, rol: 'Propietario');

        final present = [
          tester.widgetList(find.byType(AppBottomNav)).length,
          tester.widgetList(find.byType(AppNavRail)).length,
          tester.widgetList(find.byType(AppTopNavBar)).length,
        ];

        expect(
          present.where((count) => count > 0).length,
          1,
          reason: 'a $width px hay ${present.where((c) => c > 0).length} navs',
        );
        expect(tester.takeException(), isNull, reason: 'overflow @$width');
      }
    });

    testWidgets('la ruta actual marca el destino correcto', (tester) async {
      await pumpShell(
        tester,
        width: 375,
        rol: 'Propietario',
        location: '/workshop_directory',
      );

      expect(
        tester.widget<AppBottomNav>(find.byType(AppBottomNav)).currentIndex,
        3,
      );
    });
  });

  group('rol Mecanico', () {
    testWidgets('compact y medium usan drawer, no sidebar fijo', (tester) async {
      for (final width in [375.0, 768.0]) {
        await pumpShell(tester, width: width, rol: 'Mecanico');

        expect(
          find.byType(Drawer),
          findsOneWidget,
          reason: 'sin drawer @$width',
        );
        expect(find.byType(AppBottomNav), findsNothing);
      }
    });

    testWidgets('expanded y large usan sidebar fijo, sin drawer', (
      tester,
    ) async {
      for (final width in [1024.0, 1440.0]) {
        await pumpShell(tester, width: width, rol: 'Mecanico');

        expect(find.byType(Drawer), findsNothing, reason: 'drawer @$width');
        expect(tester.takeException(), isNull, reason: 'overflow @$width');
      }
    });
  });
}
```

- [ ] **Step 2: Correr el test y confirmar que falla**

Run: `flutter test test/core/widgets/main_scaffold_adaptive_test.dart`
Expected: FAIL — `AppNavRail` no aparece a 768 ni a 1024 (el `MainScaffold` actual solo distingue `isDesktop`); a 768 encuentra `InstagramBottomNavBar`, que ni siquiera es `AppBottomNav`.

- [ ] **Step 3: Reescribir `MainScaffold`**

Sustituye el contenido completo de `lib/core/widgets/main_scaffold.dart` por:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/widgets/app_top_nav_bar.dart';
import 'package:autodoc/core/widgets/navigation/app_bottom_nav.dart';
import 'package:autodoc/core/widgets/navigation/app_nav_destination.dart';
import 'package:autodoc/core/widgets/navigation/app_nav_rail.dart';
import 'package:autodoc/features/mechanic/presentation/widgets/mechanic_sidebar.dart';

/// Shell de la aplicación: elige la presentación de la navegación principal
/// según la [WindowClass] y el rol del usuario.
///
/// | WindowClass | Propietario        | Mecánico          |
/// |-------------|--------------------|-------------------|
/// | compact     | barra inferior     | drawer            |
/// | medium      | rail colapsado     | drawer            |
/// | expanded    | rail extendido     | sidebar fijo      |
/// | large       | barra superior     | sidebar fijo      |
class MainScaffold extends StatelessWidget {
  final Widget child;

  const MainScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final windowClass = AppBreakpoints.of(context);
    final isMecanico =
        context.watch<UserProfileProvider>().userData?.rol == 'Mecanico';

    return isMecanico
        ? _MechanicShell(windowClass: windowClass, child: child)
        : _OwnerShell(windowClass: windowClass, child: child);
  }
}

class _OwnerShell extends StatelessWidget {
  final WindowClass windowClass;
  final Widget child;

  const _OwnerShell({required this.windowClass, required this.child});

  void _onDestinationSelected(BuildContext context, int index) {
    final destination = AppNavDestinations.owner[index];
    if (GoRouterState.of(context).uri.path != destination.route) {
      context.go(destination.route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = AppNavDestinations.indexForLocation(
      GoRouterState.of(context).uri.toString(),
    );

    return switch (windowClass) {
      WindowClass.compact => Scaffold(
        body: child,
        bottomNavigationBar: AppBottomNav(
          currentIndex: currentIndex,
          onDestinationSelected: (index) =>
              _onDestinationSelected(context, index),
        ),
      ),
      WindowClass.medium || WindowClass.expanded => Scaffold(
        body: Row(
          children: [
            AppNavRail(
              currentIndex: currentIndex,
              extended: windowClass == WindowClass.expanded,
              onDestinationSelected: (index) =>
                  _onDestinationSelected(context, index),
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: child),
          ],
        ),
      ),
      WindowClass.large => Scaffold(
        body: Column(
          children: [
            const AppTopNavBar(),
            Expanded(child: child),
          ],
        ),
      ),
    };
  }
}

class _MechanicShell extends StatelessWidget {
  final WindowClass windowClass;
  final Widget child;

  const _MechanicShell({required this.windowClass, required this.child});

  @override
  Widget build(BuildContext context) {
    // El sidebar mide 280 dp fijos: por debajo de `expanded` dejaría menos
    // contenido que un teléfono, así que sigue siendo drawer.
    final showFixedSidebar = windowClass.isAtLeastExpanded;

    return Scaffold(
      appBar: showFixedSidebar
          ? null
          : AppBar(
              title: const Text('AutoDoc Taller'),
              backgroundColor: context.appColors.surfaceContainer,
            ),
      drawer: showFixedSidebar ? null : const Drawer(child: MechanicSidebar()),
      body: Row(
        children: [
          if (showFixedSidebar) const MechanicSidebar(),
          Expanded(child: child),
        ],
      ),
    );
  }
}
```

Nota: el `switch` sobre `windowClass` es exhaustivo sobre el enum, así que si alguien añade una quinta clase el compilador obliga a decidir su navegación. Ese es el motivo de que `WindowClass` sea un enum y no tres booleanos.

- [ ] **Step 4: Correr el test y confirmar que pasa**

Run: `flutter test test/core/widgets/main_scaffold_adaptive_test.dart`
Expected: PASS (8 tests)

- [ ] **Step 5: Comprobar que no se rompió el test de shell existente**

Run: `flutter test test/core/widgets/main_scaffold_workshop_directory_test.dart`
Expected: PASS. Si falla porque buscaba `InstagramBottomNavBar`, actualiza el finder a `AppBottomNav` — el comportamiento navegacional no cambió, solo el widget que lo presenta.

- [ ] **Step 6: Verificar la app entera y commitear**

```bash
dart format . && flutter analyze && flutter test
```

Verificación manual: `flutter run -d chrome`, redimensionar de 375 a 1440 px de forma continua con sesión de Propietario y luego de Mecánico. La navegación debe cambiar en 600, 840 y 1200 sin parpadeos ni pérdida de la ruta actual.

```bash
git add lib/core/widgets/main_scaffold.dart test/core/widgets/main_scaffold_adaptive_test.dart test/core/widgets/main_scaffold_workshop_directory_test.dart
git commit -m "feat(shell): make MainScaffold adaptive across all four window classes

La franja 600-1199px recibía la barra inferior de teléfono estirada a lo ancho
de una tablet. Ahora usa NavigationRail (colapsado en medium, extendido en
expanded). El rol Mecánico pasa el sidebar fijo de >=1200 a >=840."
```

---

### Task 6: `AppTopNavBar` — tokenizar y hacerla resistente a overflow

**Files:**
- Modify: `lib/core/widgets/app_top_nav_bar.dart`
- Test: `test/core/widgets/app_top_nav_bar_test.dart`

**Interfaces:**
- Consumes: `AppNavDestinations` (Task 2); `AppMotion.hover`, `AppMotion.easeOut` (Fase 1 Task 2); `context.appColors`.
- Produces: `AppTopNavBar()` — misma API pública.

**Problemas medidos:**
- `Colors.black.withValues(alpha: 0.05)` en L33 y `Colors.white` en L191 — hardcodeados. Deben ser `AppShadows.lightSm`/`darkSm` y `colors.onPrimary`.
- Los 4 enlaces están duplicados a mano en L74–97, divergiendo de `AppNavDestinations` (le falta *Perfil*, que vive aparte al final).
- La `Row` de L39 no tiene protección de overflow: a 1200 px justos, con un nombre de usuario largo, revienta.
- El badge de notificaciones (L173–197) mide 16×16 dp con `padding: 4` — muy por debajo del mínimo tappable; y el `Stack` lo posiciona sobre el `IconButton` sin `Semantics`, así que un lector de pantalla anuncia "Notificaciones" sin decir cuántas hay sin leer.

- [ ] **Step 1: Escribir el test que falla**

```dart
// test/core/widgets/app_top_nav_bar_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/widgets/app_top_nav_bar.dart';
import 'package:autodoc/core/widgets/navigation/app_nav_destination.dart';

import '../../support/responsive_harness.dart';

void main() {
  // NOTA: AppTopNavBar depende de GoRouterState, ThemeProvider,
  // LanguageProvider, NotificationCenterProvider y UserProfileProvider.
  // Reutiliza el andamiaje de pumpShell de
  // test/core/widgets/main_scaffold_adaptive_test.dart: extráelo a
  // test/support/shell_harness.dart como primer paso de esta tarea y actualiza
  // el import de ambas suites.

  testWidgets('no desborda a 1200px, el ancho mínimo donde se muestra', (
    tester,
  ) async {
    await pumpTopNav(tester, width: 1200, userName: 'Un Nombre Largo De Verdad');
    expectNoOverflow(tester);
  });

  testWidgets('no desborda a 1200px con el nombre más largo plausible', (
    tester,
  ) async {
    await pumpTopNav(
      tester,
      width: 1200,
      userName: 'María de los Ángeles Hernández Villalobos',
    );
    expectNoOverflow(tester);
  });

  testWidgets('muestra los mismos destinos que AppNavDestinations', (
    tester,
  ) async {
    await pumpTopNav(tester, width: 1440);

    for (final destination in AppNavDestinations.owner) {
      expect(
        find.text(destination.label),
        findsWidgets,
        reason: 'falta ${destination.route} en la barra superior',
      );
    }
  });

  testWidgets('los controles de icono tienen tooltip', (tester) async {
    await pumpTopNav(tester, width: 1440);

    for (final button in tester.widgetList<IconButton>(find.byType(IconButton))) {
      expect(
        button.tooltip,
        isNotNull,
        reason: 'IconButton sin tooltip: ${button.icon}',
      );
      expect(button.tooltip, isNotEmpty);
    }
  });

  testWidgets('renderiza en dark mode sin excepciones', (tester) async {
    await pumpTopNav(tester, width: 1440, brightness: Brightness.dark);
    expectNoOverflow(tester);
  });
}
```

- [ ] **Step 2: Extraer el andamiaje compartido a `test/support/shell_harness.dart`**

Mueve `pumpShell` de `main_scaffold_adaptive_test.dart` a `test/support/shell_harness.dart` y añade `pumpTopNav(WidgetTester, {required double width, String userName = 'Ana Pérez', Brightness brightness = Brightness.light})`, que monta `AppTopNavBar` con los cinco providers que necesita. Actualiza el import de `main_scaffold_adaptive_test.dart`.

Run: `flutter test test/core/widgets/main_scaffold_adaptive_test.dart`
Expected: sigue en PASS tras el movimiento.

- [ ] **Step 3: Correr el test nuevo y confirmar que falla**

Run: `flutter test test/core/widgets/app_top_nav_bar_test.dart`
Expected: FAIL — el test de nombre largo desborda (`A RenderFlex overflowed by N pixels on the right`), y el test de destinos no encuentra "Perfil" como enlace de navegación.

- [ ] **Step 4: Implementar los arreglos**

4a. Sustituye el bloque de enlaces manuales (L74–97) por una iteración sobre la fuente única, envuelta para que pueda encogerse:

```dart
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final destination in AppNavDestinations.owner)
                      _TopNavLink(
                        title: destination.label,
                        icon: destination.icon,
                        semanticLabel: destination.semanticLabel,
                        isActive: currentPath == destination.route,
                        onTap: () => context.go(destination.route),
                      ),
                  ],
                ),
              ),
            ),
          ),
```

Esto sustituye a la vez los dos `Spacer()` de L71 y L99. Un `SingleChildScrollView` horizontal es la salida correcta aquí: la barra solo existe en `large`, donde el desbordamiento es un caso límite, y hacerla scrollable es preferible a truncar etiquetas.

4b. Elimina el bloque *Profile Action* duplicado del final (L205–242) y su `Consumer<UserProfileProvider>` **solo si** `/user_profile` ya aparece como destino tras 4a. Mantén el avatar como indicador de sesión, pero sin etiqueta "Mi Perfil" duplicada: sustituye el `Text('Mi Perfil')` por nada y envuelve el `CircleAvatar` en un `Tooltip(message: 'Tu cuenta')`.

4c. Sustituye la sombra hardcodeada de L31–37:

```dart
        boxShadow: Theme.of(context).brightness == Brightness.dark
            ? AppShadows.darkSm
            : AppShadows.lightSm,
```

Añade `import 'package:autodoc/core/theme/app_shadows.dart';`.

4d. Sustituye `Colors.white` de L191 por `colors.onPrimary` y da al badge semántica y tamaño mínimo:

```dart
                  if (notifProvider.hasUnread)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Semantics(
                        label:
                            '${notifProvider.unreadCount} notificaciones sin leer',
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: colors.error,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Text(
                            notifProvider.unreadCount > 9
                                ? '9+'
                                : '${notifProvider.unreadCount}',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: colors.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
```

4e. Añade `semanticLabel` a `_TopNavLink` y envuelve su `InkWell` en `Semantics(button: true, label: semanticLabel, child: ...)`. Añade también `tooltip: 'Cambiar idioma'` al `InkWell` del selector EN/ES (L124), que hoy es un cuadro con dos letras sin explicación.

- [ ] **Step 5: Correr los tests y confirmar que pasan**

Run: `flutter test test/core/widgets/app_top_nav_bar_test.dart`
Expected: PASS (5 tests)

- [ ] **Step 6: Verificar y commitear**

```bash
dart format . && flutter analyze && flutter test
git add lib/core/widgets/app_top_nav_bar.dart test/support/shell_harness.dart test/core/widgets/app_top_nav_bar_test.dart test/core/widgets/main_scaffold_adaptive_test.dart
git commit -m "fix(navigation): tokenize AppTopNavBar, make it overflow-safe and accessible

Consume AppNavDestinations en vez de duplicar 4 enlaces a mano, sustituye la
sombra y el blanco hardcodeados por tokens, envuelve los enlaces en un scroll
horizontal para que un nombre largo no reviente la Row a 1200px, y añade
tooltip/Semantics a los controles que solo eran iconos."
```

---

### Task 7: `MechanicSidebar` — tokenizar y unificar tipografía

**Files:**
- Modify: `lib/features/mechanic/presentation/widgets/mechanic_sidebar.dart`
- Test: `test/features/mechanic/presentation/widgets/mechanic_sidebar_test.dart`

**Interfaces:**
- Consumes: `AppTextStyles` (existente); `context.appColors`; `AppSpacing`, `AppRadius` (existentes).
- Produces: `MechanicSidebar()` — misma API pública.

**Problemas medidos:**
- **Una tercera familia tipográfica.** L82 usa `GoogleFonts.montserrat`, y L90/L236 usan `GoogleFonts.inter` directamente en vez de `AppTextStyles`. La app declara Inter como su única familia en [app_text_styles.dart](../../../lib/core/theme/app_text_styles.dart); Montserrat aparece solo aquí. Es una fuente extra descargándose en runtime para un único texto.
- 3 colores hardcodeados: `Colors.white.withValues(alpha: 0.7)` (L51), `Colors.white10` (L60), `Colors.white.withValues(alpha: 0.4)` (L61). En light mode el borde derecho es *blanco sobre blanco*: invisible.
- `width: 280` fijo (L54) sin `ConstrainedBox`: en `expanded` a 840 px deja 560 px de contenido.

- [ ] **Step 1: Escribir el test que falla**

```dart
// test/features/mechanic/presentation/widgets/mechanic_sidebar_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'lib/features/mechanic/presentation/widgets/mechanic_sidebar.dart',
  ).readAsStringSync();

  test('no usa una familia tipográfica fuera del design system', () {
    expect(
      source.contains('GoogleFonts.montserrat'),
      isFalse,
      reason: 'Montserrat es una tercera familia; la app usa Inter vía '
          'AppTextStyles. Ver CONVENTIONS.md §2.1.',
    );
    expect(
      source.contains('GoogleFonts.'),
      isFalse,
      reason: 'Usa AppTextStyles en vez de invocar GoogleFonts directamente.',
    );
  });

  test('no tiene colores literales', () {
    final offenders = <String>[];
    final lines = source.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trimLeft().startsWith('//')) continue;
      if (line.contains('Colors.transparent')) continue;
      if (RegExp(r'Colors\.(white|black|grey|gray)').hasMatch(line)) {
        offenders.add('${i + 1}: ${line.trim()}');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  testWidgets('el borde derecho es visible en light mode', (tester) async {
    // Verificación estructural: el borde debe salir de colors.outline, que por
    // construcción contrasta con la superficie en ambos temas.
    expect(source.contains('colors.outline'), isTrue);
  });
}
```

- [ ] **Step 2: Correr el test y confirmar que falla**

Run: `flutter test test/features/mechanic/presentation/widgets/mechanic_sidebar_test.dart`
Expected: FAIL en los tres tests.

- [ ] **Step 3: Implementar los arreglos**

3a. Borra `import 'package:google_fonts/google_fonts.dart';` y añade:

```dart
import 'package:autodoc/core/theme/app_radius.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
```

3b. Sustituye el bloque de fondo y borde (L49–64):

```dart
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        border: Border(
          right: BorderSide(
            color: colors.outline.withValues(alpha: isDark ? 0.3 : 0.5),
          ),
        ),
      ),
```

Y elimina la variable local `bgColor` y el `isDark` si deja de usarse en otro sitio (`flutter analyze` te lo dirá).

3c. Sustituye los tres usos de `GoogleFonts`:

```dart
                    Text(
                      'AutoDoc',
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    Text(
                      'Panel de Taller',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
```

```dart
        title: Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: titleColor,
          ),
        ),
```

3d. Sustituye los literales numéricos de spacing y radio por tokens: `EdgeInsets.all(24)` → `EdgeInsets.all(AppSpacing.xl)`, `SizedBox(width: 12)` → `SizedBox(width: AppSpacing.md)`, `SizedBox(height: 24)` → `SizedBox(height: AppSpacing.xl)`, `BorderRadius.circular(12)` → `BorderRadius.circular(AppRadius.md)`, `EdgeInsets.symmetric(horizontal: 16, vertical: 4)` → `EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.xs)`, `SizedBox(height: 16)` → `SizedBox(height: AppSpacing.base)`.

- [ ] **Step 4: Correr los tests y confirmar que pasan**

Run: `flutter test test/features/mechanic/presentation/widgets/mechanic_sidebar_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: Verificar visualmente en ambos temas**

`flutter run -d chrome` con sesión de Mecánico a 1440 px. En **light mode**, el borde derecho del sidebar debe verse ahora (antes era blanco sobre blanco). Compara antes/después.

- [ ] **Step 6: Verificar y commitear**

```bash
dart format . && flutter analyze && flutter test
git add lib/features/mechanic/presentation/widgets/mechanic_sidebar.dart test/features/mechanic/presentation/widgets/mechanic_sidebar_test.dart
git commit -m "fix(mechanic): tokenize MechanicSidebar and drop the third font family

Usaba GoogleFonts.montserrat para un solo texto (tercera familia descargándose
en runtime, fuera de AppTextStyles) y 3 colores literales, entre ellos un borde
blanco sobre fondo blanco que era invisible en light mode."
```

---

### Task 8: `AppScaffold` — limpiar y aplicar gutter adaptativo

**Files:**
- Modify: `lib/core/widgets/app_scaffold.dart`
- Test: `test/core/widgets/app_scaffold_test.dart`

**Interfaces:**
- Consumes: `AppBreakpoints`, `WindowClass` (Fase 1 Task 1); `AppPageBody` (Fase 1 Task 5); `context.appColors`.
- Produces: `AppScaffold({required Widget body, PreferredSizeWidget? appBar, Widget? bottomNavigationBar, Widget? floatingActionButton, bool useGradient = false, bool applyGutter = false})`. **El parámetro `applyGutter` es nuevo y por defecto `false`**, para que ninguna pantalla existente cambie de layout en esta fase; las fases 4–8 lo activan pantalla por pantalla.

**Problemas medidos:**
- Líneas 29–34: bloque comentado de `AppTopNavBar` que ya no aplica (lo gestiona `MainScaffold`). Código muerto.
- Líneas 27–53: un `Column` con un solo hijo `Expanded` envolviendo el body. No hace nada; es un nivel de anidamiento gratuito, contra la guideline *"Avoid deep nesting"* de `ui-ux-pro-max --stack flutter`.
- Línea 54–56: `Responsive.isDesktop(context) ? null : bottomNavigationBar` — oculta la barra inferior en `large` pero la mantiene en `medium`/`expanded`, donde `MainScaffold` ya pone el rail. Resultado: rail lateral **y** barra inferior a la vez en 600–1199 px.

- [ ] **Step 1: Escribir el test que falla**

```dart
// test/core/widgets/app_scaffold_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/widgets/app_scaffold.dart';

import '../../support/responsive_harness.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required double width,
    Widget? bottomNavigationBar,
    bool applyGutter = false,
  }) async {
    await pumpAtWidth(
      tester,
      AppScaffold(
        applyGutter: applyGutter,
        bottomNavigationBar: bottomNavigationBar,
        body: Container(key: const Key('body')),
      ),
      width: width,
    );
  }

  testWidgets('la barra inferior solo se muestra en compact', (tester) async {
    const bar = SizedBox(key: Key('bottom'), height: 60);

    await pump(tester, width: 375, bottomNavigationBar: bar);
    expect(find.byKey(const Key('bottom')), findsOneWidget);

    for (final width in [768.0, 1024.0, 1440.0]) {
      await pump(tester, width: width, bottomNavigationBar: bar);
      expect(
        find.byKey(const Key('bottom')),
        findsNothing,
        reason: 'barra inferior visible @$width, donde ya hay rail o top nav',
      );
    }
  });

  testWidgets('sin applyGutter el body ocupa todo el ancho', (tester) async {
    await pump(tester, width: 1440);
    expect(tester.getSize(find.byKey(const Key('body'))).width, 1440);
  });

  testWidgets('con applyGutter el body respeta el gutter y el ancho máximo', (
    tester,
  ) async {
    await pump(tester, width: 375, applyGutter: true);
    expect(tester.getSize(find.byKey(const Key('body'))).width, 375 - 16 * 2);

    await pump(tester, width: 1440, applyGutter: true);
    expect(tester.getSize(find.byKey(const Key('body'))).width, 1200 - 40 * 2);
  });

  testWidgets('no desborda en ningún ancho de auditoría', (tester) async {
    await forEachAuditWidth(tester, (width) async {
      await pump(tester, width: width, applyGutter: true);
      expectNoOverflow(tester);
    });
  });
}
```

- [ ] **Step 2: Correr el test y confirmar que falla**

Run: `flutter test test/core/widgets/app_scaffold_test.dart`
Expected: FAIL — a 768 y 1024 la barra inferior sigue visible; `applyGutter` no existe (error de compilación).

- [ ] **Step 3: Reescribir `AppScaffold`**

```dart
import 'package:flutter/material.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/widgets/app_page_body.dart';

/// Scaffold base de una pantalla de AutoDoc.
///
/// La navegación principal la pone [MainScaffold]; este widget solo aporta el
/// fondo, el gutter opcional y una barra inferior propia de la pantalla (p.ej.
/// una barra de acciones), que solo tiene sentido en `compact`.
class AppScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;

  /// Barra inferior **propia de la pantalla**. Se oculta fuera de `compact`,
  /// donde la navegación ya vive en el rail o en la barra superior.
  final Widget? bottomNavigationBar;

  final Widget? floatingActionButton;
  final bool useGradient;

  /// Envuelve [body] en [AppPageBody] (gutter por clase de ventana + ancho
  /// máximo centrado). Por defecto `false` para no alterar las pantallas que
  /// aún gestionan su propio padding; cada fase de módulo lo activa al
  /// migrar su pantalla.
  final bool applyGutter;

  const AppScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.useGradient = false,
    this.applyGutter = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isCompact = AppBreakpoints.of(context).isCompact;

    Widget content = applyGutter ? AppPageBody(child: body) : body;

    if (useGradient) {
      content = DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colors.surface, colors.surface.withValues(alpha: 0.95)],
          ),
        ),
        child: content,
      );
    }

    return Scaffold(
      appBar: appBar,
      body: content,
      bottomNavigationBar: isCompact ? bottomNavigationBar : null,
      floatingActionButton: floatingActionButton,
    );
  }
}
```

Cambios respecto al original: se elimina el bloque comentado, se elimina el `Column`/`Expanded` innecesario, `Container` → `DecoratedBox` (no había ningún parámetro de layout que justificara el `Container`), y la condición de la barra inferior pasa de `!isDesktop` a `isCompact`.

- [ ] **Step 4: Correr el test y confirmar que pasa**

Run: `flutter test test/core/widgets/app_scaffold_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 5: Comprobar que ninguna pantalla se rompió**

```bash
grep -rn "AppScaffold(" lib/features | wc -l
flutter test
flutter analyze
```

Expected: suite verde. `applyGutter` por defecto `false` y `useGradient` sin cambios significan que ninguna pantalla existente cambia de aspecto, **salvo** las que pasaban `bottomNavigationBar` y se veían en `medium`/`expanded`: ahí desaparece la doble navegación. Revisa esas pantallas a 768 px a mano.

- [ ] **Step 6: Commit**

```bash
dart format . && flutter analyze && flutter test
git add lib/core/widgets/app_scaffold.dart test/core/widgets/app_scaffold_test.dart
git commit -m "refactor(shell): clean AppScaffold and add opt-in adaptive gutter

Elimina un bloque comentado muerto y un Column/Expanded que no hacía nada, y
corrige la condición de la barra inferior: se ocultaba solo en >=1200px, así
que en 600-1199px coexistía con el rail lateral. Añade applyGutter (opt-in,
por defecto false) para que las fases de módulo migren pantalla a pantalla."
```

---

### Task 9: Extender el ratchet de colores a las rutas limpiadas

**Files:**
- Modify: `test/core/theme/no_hardcoded_colors_test.dart`

- [ ] **Step 1: Añadir las rutas de esta fase a `kTokenizedPaths`**

```dart
const List<String> kTokenizedPaths = [
  'lib/core/theme',
  'lib/core/widgets/app_page_body.dart',
  'lib/core/widgets/app_grid.dart',
  // ── Fase 2 ──
  'lib/core/widgets/navigation',
  'lib/core/widgets/main_scaffold.dart',
  'lib/core/widgets/app_scaffold.dart',
  'lib/core/widgets/app_top_nav_bar.dart',
  'lib/features/mechanic/presentation/widgets/mechanic_sidebar.dart',
];
```

- [ ] **Step 2: Correr el test y confirmar que pasa**

Run: `flutter test test/core/theme/no_hardcoded_colors_test.dart`
Expected: PASS. Si falla, quedan literales sin tokenizar en alguno de esos ficheros — arréglalos; no quites la ruta de la lista.

- [ ] **Step 3: Commit**

```bash
git add test/core/theme/no_hardcoded_colors_test.dart
git commit -m "test(theme): extend hardcoded-color ratchet to phase 2 paths"
```

---

## Verificación de cierre de fase

- [ ] `flutter test` — suite completa verde.
- [ ] `flutter analyze` — sin errores.
- [ ] `dart format .` sin cambios pendientes.
- [ ] `grep -rn "responsive_framework" lib pubspec.yaml` → vacío.
- [ ] `grep -rn "AppBottomNavBar\|InstagramBottomNavBar" lib test` → vacío.
- [ ] **Matriz manual de navegación.** `flutter run -d chrome`, sesión de Propietario y luego de Mecánico, redimensionando por los 8 anchos de auditoría. Anota en una tabla qué navegación aparece en cada uno y compárala con la matriz de la Task 5. Repite en dark mode.
- [ ] **Reduced motion.** Con reduced motion activo en el SO, redimensionar entre clases no debe producir animaciones de desplazamiento.
- [ ] Pre-Delivery Checklist de `ui-ux-pro-max` `references/pro-rules.md`, secciones *Interaction*, *Light/Dark Mode Contrast* y *Layout*.
- [ ] `Skill(review-animations)` sobre el diff de la fase.
- [ ] `Skill(superpowers:requesting-code-review)`.

**Criterio de éxito de la Fase 2:**

- Existe una sola escala de breakpoints en todo el árbol; `responsive_framework` está desinstalado.
- La navegación principal cambia de estructura en 600, 840 y 1200 px, y en cada ancho hay **exactamente una** presentación de navegación activa (verificado por test en los 8 anchos).
- La franja 600–1199 px, que antes recibía la UI de teléfono, tiene ahora un `NavigationRail` y recupera el ancho que ocupaba la barra inferior.
- Los destinos de navegación están declarados una sola vez (`AppNavDestinations`) y los consumen las tres presentaciones.
- Cero colores hardcodeados en el shell, protegido por el ratchet.
- Todos los controles de navegación tienen etiqueta visible o `tooltip`/`Semantics`, y área tappable ≥ 48 dp.
- Ninguna ruta de `app_router.dart` cambió.
