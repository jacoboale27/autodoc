# Fase 5 — Módulo `mechanic` (rol taller): shell único, layouts adaptativos, tokens y motion

> **Plan ejecutable.** Depende de las Fases 1–3 (y reutiliza dos primitivas de la Fase 4). Escrito el 2026-08-11 siguiendo el protocolo del §7 del [plan maestro](2026-08-10-ui-ux-overhaul-00-master.md), tras leer **completas** las 10 pantallas del módulo (6.145 líneas) más `reparacion_card.dart`.
>
> **REQUIRED SUB-SKILL para ejecutar:** `superpowers:subagent-driven-development` (recomendado) o `superpowers:executing-plans`.
> **Skills obligatorias por tarea:** `ui-ux-pro-max` y `emil-design-eng` en toda tarea de layout/motion; `apple-design` en la Task 3 (kanban con scroll y gestos); `find-animation-opportunities` una vez al abrir la fase. Ver §1 del maestro.

**Goal:** Que las 10 pantallas del panel de taller dejen de tener cada una su propio shell y su propio breakpoint, cambien de estructura en 600 / 840 / 1200 px, no tengan colores ni fuentes fuera del design system, y sean operables con lector de pantalla y con reduced motion — sin tocar `data/`, `providers/` ni los flujos de negocio.

**Architecture:** Una tarea inicial extrae el shell del rol taller (`MechanicScaffold`), que hoy está **copiado en ocho pantallas** con un breakpoint propio de 700 px. A partir de ahí cada pantalla es una tarea independiente y rechazable, ordenadas de menor a mayor superficie. La última tarea cierra el ratchet de colores y repara un agujero real del regex que la Fase 1 dejó abierto.

**Tech Stack:** Flutter 3.41.6 (Material 3), Provider, go_router 17, `fl_chart`, `google_maps_flutter`, `geolocator`, `mobile_scanner`, `flutter_animate`. Tests con `flutter_test` + `fake_cloud_firestore`. Sin dependencias nuevas.

---

## 0. Lo que se midió (2026-08-11, sobre `HEAD`)

**GF** = llamadas a `GoogleFonts.*`. **mont** = de ellas, `GoogleFonts.montserrat` (tercera familia tipográfica). **HC** = líneas con color literal. **Resp** = llamadas a `Responsive.*`. **`<700`** = el breakpoint propio del módulo. **LB** = `LayoutBuilder`.

| Pantalla | LOC | GF | mont | HC | Resp | `<700` | LB |
|---|---:|---:|---:|---:|---:|---:|---:|
| [initiate_service_screen.dart](../../../lib/features/mechanic/presentation/pages/initiate_service_screen.dart) | 1418 | 38 | 4 | 6 | 36 | — | — |
| [workshop_settings_screen.dart](../../../lib/features/mechanic/presentation/pages/workshop_settings_screen.dart) | 932 | 12 | **7** | 14 | 21 | 1 | — |
| [mechanic_dashboard_screen.dart](../../../lib/features/mechanic/presentation/pages/mechanic_dashboard_screen.dart) | 844 | 15 | — | 3 | 25 | 1 | **1** |
| [mechanic_reviews_screen.dart](../../../lib/features/mechanic/presentation/pages/mechanic_reviews_screen.dart) | 709 | 8 | — | 1 | 14 | 1 | — |
| [empleados_screen.dart](../../../lib/features/mechanic/presentation/pages/empleados_screen.dart) | 541 | 5 | — | 0 | 12 | 1 | — |
| [vehicle_search_screen.dart](../../../lib/features/mechanic/presentation/pages/vehicle_search_screen.dart) | 467 | 12 | — | 1 | 19 | 1 | — |
| [catalogo_servicios_screen.dart](../../../lib/features/mechanic/presentation/pages/catalogo_servicios_screen.dart) | 384 | 5 | — | 0 | 6 | 1 | — |
| [mechanic_service_history_screen.dart](../../../lib/features/mechanic/presentation/pages/mechanic_service_history_screen.dart) | 374 | 5 | — | 2 | 3 | 1 | — |
| [mechanic_pending_screen.dart](../../../lib/features/mechanic/presentation/pages/mechanic_pending_screen.dart) | 271 | 5 | — | 0 | 6 | — | — |
| [reparaciones_kanban_screen.dart](../../../lib/features/mechanic/presentation/pages/reparaciones_kanban_screen.dart) | 154 | 3 | — | 0 | 4 | 1 | — |
| [reparacion_card.dart](../../../lib/features/mechanic/presentation/widgets/reparacion_card.dart) | 51 | 1 | — | 0 | 0 | — | — |
| **TOTAL** | **6145** | **109** | **11** | **27** | **146** | **8** | **1** |

### 0.1 El hallazgo estructural: el shell está copiado ocho veces

Ocho de las diez pantallas contienen, literalmente, este bloque:

```dart
final isMobile = MediaQuery.of(context).size.width < 700;
...
appBar: isMobile ? AppBar(...) : null,
drawer: isMobile ? const Drawer(child: MechanicSidebar()) : null,
body: Row(children: [
  if (!isMobile) const MechanicSidebar(),
  Expanded(child: Column(children: [
    if (!isMobile) <barra superior de 64 dp>,
    Expanded(child: <contenido>),
  ])),
]),
```

Consecuencias medibles:

1. **`< 700` es un tercer sistema de breakpoints.** El maestro documentó dos (`Responsive` 600/900/1200 y `responsive_framework` 450/800/1920). Este es el tercero, y es el que gobierna toda la navegación del rol taller. A **650 px** `Responsive.isMobile` ya es `false` (empieza a escalar como tablet) mientras estas pantallas siguen dibujando el `AppBar` + drawer de teléfono. A **700 px** el sidebar fijo de 280 dp se activa y deja **420 px de contenido — menos que un teléfono**.
2. **La barra superior de escritorio está escrita seis veces** (`Container(height: 64, ...)` con su propio borde y su propio `Responsive.padding(context, 32)`), con cinco textos distintos y la misma estructura.
3. **Dos pantallas mienten sobre dónde estás.** [mechanic_dashboard_screen.dart:50](../../../lib/features/mechanic/presentation/pages/mechanic_dashboard_screen.dart#L50) y [vehicle_search_screen.dart:102](../../../lib/features/mechanic/presentation/pages/vehicle_search_screen.dart#L102) ponen el mismo título en el `AppBar` de teléfono — `'Panel de Taller'` — aunque una es el dashboard y la otra el buscador. En móvil el usuario no tiene forma de saber en qué pantalla está: la barra superior de escritorio sí distingue (`DASHBOARD` vs `BUSCAR VEHÍCULO`), pero esa barra no se dibuja en móvil.

La Task 1 extrae `MechanicScaffold` y las Tasks 3–10 lo consumen. Es la tarea de la que dependen todas las demás.

### 0.2 Correcciones al plan maestro

Todas verificadas leyendo el fichero; se corrigen aquí y en `...-00-master.md`.

| Dónde | Decía | Es |
|---|---|---|
| §3 «dos sistemas de breakpoints» | `Responsive` y `responsive_framework` | **Tres**: falta `MediaQuery...width < 700`, en 8 ficheros del módulo taller |
| §5.2 `initiate_service` GF=6 | 6 `GoogleFonts` | **38** (4 de ellas `montserrat`) |
| §5.2 `initiate_service` «flujo multi-paso → un paso por pantalla» | Stepper | **No es un flujo multi-paso.** Es un único `SingleChildScrollView > Column` con 8 secciones. Convertirlo en stepper cambiaría el flujo de negocio, prohibido por §2 del maestro. Contrato corregido: **dos columnas** en `expanded`/`large` (ver Task 11) |
| §5.2 `mechanic_dashboard` «usar como referencia de lo que ya funciona» | Su `LayoutBuilder` funciona | **Su `LayoutBuilder` está roto** y nunca produce las 3 columnas que calcula (ver Task 9) |
| §5.2 `workshop_settings` «16 colores» | Solo color | 14 líneas con literal **y 7 `GoogleFonts.montserrat`** — la tercera familia tipográfica no está solo en `mechanic_sidebar` |
| §5.2 `mechanic_service_history` «Sin `Responsive`» | 0 llamadas | **3** llamadas, y además 2 colores literales (`Colors.white` L126, `Colors.grey.shade600` L310) |
| §5.2 `mechanic_reviews` HC=— | 0 literales | **1**: `Colors.red` en [L375](../../../lib/features/mechanic/presentation/pages/mechanic_reviews_screen.dart#L375) |
| §5.2 KPIs «`AppGrid` 1/2/4» | 4 columnas en `large` | **1/2/3/3**: son 6 KPIs; 4 columnas deja dos huérfanos, 3 da dos filas llenas |

### 0.3 Correcciones a fases anteriores (bloqueantes si no se aplican)

Dos defectos reales encontrados al leer el código y los tests existentes. **Aplícalos antes de ejecutar la Fase 2**, o la Fase 2 fallará en ejecución.

**(a) El doble de `UserProfileProvider` de la Fase 2 Task 5 no compila en runtime de test.**
La Fase 2 Task 5 escribió `class _FakeProfileProvider extends UserProfileProvider`. Pero `UserProfileProvider` inicializa `final UserService _userService = UserService();` en la declaración del campo ([user_profile_provider.dart:8](../../../lib/core/providers/user_profile_provider.dart#L8)), y `UserService` a su vez hace `final FirebaseFirestore _firestore = FirebaseFirestore.instance;` en la suya ([user_service.dart:9](../../../lib/features/profile/data/services/user_service.dart#L9)). Extender la clase real ejecuta ambos inicializadores y **lanza** en un widget test sin `Firebase.initializeApp()`. Los tres tests que ya existen en este módulo usan `implements` por exactamente este motivo y lo dejaron escrito en un comentario ([reparaciones_kanban_screen_test.dart:16-21](../../../test/features/mechanic/presentation/pages/reparaciones_kanban_screen_test.dart#L16-L21)). **Fix:** en la Fase 2 Task 5, cambiar el doble a `implements UserProfileProvider` con los 10 miembros — que es exactamente `FakeUserProfileProvider` de la Task 1 de esta fase. Reutilízalo desde `test/support/mechanic_harness.dart`.

**(b) El regex del ratchet de la Fase 1 no detecta `Colors.white10` ni sus 12 hermanos.**
El patrón es `Colors\.(white|black|...)\b`. En `Colors.white70` el carácter siguiente a `white` es `7`, que es carácter de palabra: no hay frontera, la alternativa falla, y **la línea pasa el test**. Escapan `white10 white12 white24 white30 white38 white54 white70` y `black12 black26 black38 black45 black54 black87`. No es teórico: [mechanic_sidebar.dart:60](../../../lib/features/mechanic/presentation/widgets/mechanic_sidebar.dart#L60) usa `Colors.white10` y `main_scaffold.dart` usa `Colors.white12`/`Colors.black12`/`Colors.white70`/`Colors.black87` — los ficheros que la Fase 2 mete en el ratchet podrían regresionar sin que el test se entere.

**Corregido en origen:** el patrón de la Fase 1 Task 8 ya lleva el `\d*` tras `white`/`black`. Se arregla ahí y no aquí porque el ratchet tiene que proteger de verdad desde la Fase 2, no cuatro fases después. La Task 12 de esta fase solo **verifica** que la corrección está aplicada antes de añadir rutas nuevas.

### 0.4 Ficheros

| Fichero | Qué le pasa | Acción |
|---|---|---|
| `lib/features/mechanic/presentation/widgets/mechanic_scaffold.dart` | No existe. Shell único del rol. | **Crear** (Task 1) |
| `test/support/mechanic_harness.dart` | No existe. Doble de provider + `pumpMechanicScreen`. | **Crear** (Task 1) |
| `lib/core/widgets/main_scaffold.dart` | Su `_MechanicShell` (Fase 2) duplicará el shell nuevo. | Modificar (Task 1) |
| `lib/core/widgets/app_dialog_content.dart` | No existe. Los `SizedBox(width: 380/420)` de tres diálogos. | **Crear** (Task 4) |
| `.../pages/mechanic_pending_screen.dart` | No scrollea; pulso infinito sin reduced motion. | Modificar (Task 2) |
| `.../pages/reparaciones_kanban_screen.dart` + `widgets/reparacion_card.dart` | Desborda en vertical; sin responsividad. | Modificar (Task 3) |
| `.../pages/catalogo_servicios_screen.dart` | Lista de 1 columna; diálogo de 380 fijos. | Modificar (Task 4) |
| `.../pages/mechanic_service_history_screen.dart` | Date picker forzado a claro; diálogo de 380. | Modificar (Task 5) |
| `.../pages/empleados_screen.dart` | Diálogo de 420; `Switch` como acción destructiva. | Modificar (Task 6) |
| `.../pages/vehicle_search_screen.dart` | Hint a alpha 0.2; botón muerto; `Colors.white`. | Modificar (Task 7) |
| `.../pages/mechanic_reviews_screen.dart` | `itemBuilder` de 290 líneas; estrellas sin semántica. | Modificar (Task 8) |
| `.../pages/mechanic_dashboard_screen.dart` | `LayoutBuilder` roto; blanco sobre teal en dark. | Modificar (Task 9) |
| `.../pages/workshop_settings_screen.dart` | 7 `montserrat`; errores solo en SnackBar. | Modificar (Task 10) |
| `.../pages/initiate_service_screen.dart` | 38 `GoogleFonts`; una sola columna a 1440 px. | Modificar (Task 11) |
| `lib/core/theme/app_severity.dart` (Fase 4) | Le falta el mapeo de `AlertPriority`. | Modificar (Task 11) |
| `test/core/theme/no_hardcoded_colors_test.dart` | Faltan las rutas de esta fase. | Modificar (Task 12) |

**Orden:** primero el shell (Task 1), del que dependen ocho pantallas. Luego la única pantalla sin shell (Task 2, 271 LOC) para validar el patrón de tokens/motion en superficie pequeña. Después el kanban (Task 3), que es el caso responsivo más difícil y conviene resolver temprano. Luego, por tamaño ascendente, hasta `initiate_service` (1418 LOC) al final.

---

### Task 1: `MechanicScaffold` — un shell para las diez pantallas

**Files:**
- Create: `lib/features/mechanic/presentation/widgets/mechanic_scaffold.dart`
- Create: `test/support/mechanic_harness.dart`
- Modify: `lib/core/widgets/main_scaffold.dart`
- Test: `test/features/mechanic/presentation/widgets/mechanic_scaffold_test.dart`

**Interfaces:**
- Consumes: `AppBreakpoints`, `WindowClass`, `WindowClassX` (Fase 1 Task 1); `MechanicSidebar` (Fase 2 Task 7, ya tokenizado); `AppTextStyles`, `AppColors` (existentes); `pumpAtWidth`, `kAuditWidths`, `expectNoOverflow` (Fase 1 Task 7).
- Produces:
  - `MechanicScaffold({required String title, required Widget body, List<Widget> actions, Widget? floatingActionButton})`
  - `FakeUserProfileProvider({UserModel? user})`, `fakeTaller({...})`, `pumpMechanicScreen(...)` en `test/support/mechanic_harness.dart`.

**Por qué el umbral pasa de 700 a 840 (`expanded`):** el sidebar mide 280 dp fijos ([mechanic_sidebar.dart:54](../../../lib/features/mechanic/presentation/widgets/mechanic_sidebar.dart#L54)). A 700 px deja 420 px de contenido; a 840 px deja 560, que es la medida mínima de formulario del design system (`AppBreakpoints.maxFormWidth`). Es la misma matriz que la Fase 2 Task 5 ya decidió para el rol mecánico; esta tarea la hace real en las nueve pantallas que hoy no pasan por `MainScaffold`.

**Por qué también se toca `MainScaffold`:** de las 10 rutas del rol taller, **ninguna** está dentro del `ShellRoute` que monta `MainScaffold` ([app_router.dart:359-405](../../../lib/core/router/app_router.dart#L359-L405) contiene solo las 5 rutas de propietario). El `_MechanicShell` que añadió la Fase 2 solo se alcanza en **una** ruta: `/chat_list`, que está dentro del shell y está explícitamente exenta del redirect por rol ([app_router.dart:246-250](../../../lib/core/router/app_router.dart#L246-L250)). Para que un mecánico no vea dos shells distintos según entre a "Mensajes" o a "Dashboard", `_MechanicShell` pasa a **delegar** en `MechanicScaffold`.

- [ ] **Step 1: Invocar las skills de diseño**

`Skill(ui-ux-pro-max:ui-ux-pro-max)` + `python scripts/search.py "adaptive navigation shell sidebar drawer" --stack flutter`. Anota: qué dice sobre `NavigationDrawer` vs `Drawer` en Material 3 y sobre la anchura mínima de contenido junto a un panel lateral. `Skill(find-animation-opportunities)` sobre `lib/features/mechanic/` una sola vez, al abrir la fase: la lista resultante alimenta las Tasks 2, 3 y 9. Registra el resultado en el cuerpo del PR.

- [ ] **Step 2: Escribir el harness y el test que falla**

```dart
// test/support/mechanic_harness.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:autodoc/core/models/user_model.dart';
import 'package:autodoc/core/providers/theme_provider.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/features/auth/presentation/providers/auth_provider.dart';

/// Doble de `UserProfileProvider` para los tests del panel de taller.
///
/// **Implementa** en vez de extender, y no es una preferencia de estilo:
/// `UserProfileProvider` inicializa `final UserService _userService =
/// UserService()` en la declaración del campo, y `UserService` hace
/// `FirebaseFirestore.instance` en la suya. Extender la clase real ejecuta
/// ambos inicializadores y lanza en un widget test sin
/// `Firebase.initializeApp()`. Los tres tests que ya existían en este módulo
/// usan este mismo patrón por el mismo motivo.
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

/// Cuenta de taller dueña. Pasa [idTallerPropietario] para simular una
/// sub-cuenta de empleado (`MechanicSidebar` le oculta "Empleados" y
/// `EmpleadosScreen` le muestra "Acceso restringido").
UserModel fakeTaller({
  String id = 't1',
  String nombre = 'Taller Escobar',
  String? idTallerPropietario,
  String estado = 'activo',
}) => UserModel(
  idUsuario: id,
  nombreCompleto: nombre,
  correo: 'taller@example.com',
  rol: 'Mecanico',
  fechaRegistro: DateTime(2026, 1, 1),
  estado: estado,
  idTallerPropietario: idTallerPropietario,
);

/// Monta [screen] en la ruta [location] con los providers mínimos que
/// `MechanicSidebar` y las pantallas del panel necesitan, a un ancho fijo.
///
/// Fija el ancho con `tester.view` en vez de con `MediaQuery` a mano para
/// que `AppBreakpoints.of(context)` vea el mismo valor que en producción.
Future<void> pumpMechanicScreen(
  WidgetTester tester,
  Widget screen, {
  required double width,
  double height = 1000,
  String location = '/mechanic_dashboard',
  UserModel? user,
  Brightness brightness = Brightness.light,
  bool disableAnimations = false,
  List<ChangeNotifierProvider> extraProviders = const [],
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(width, height);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final router = GoRouter(
    initialLocation: location,
    routes: [GoRoute(path: location, builder: (context, state) => screen)],
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider<UserProfileProvider>(
          create: (_) => FakeUserProfileProvider(user: user ?? fakeTaller()),
        ),
        ...extraProviders,
      ],
      child: MaterialApp.router(
        theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: disableAnimations),
          child: child!,
        ),
      ),
    ),
  );
}
```

```dart
// test/features/mechanic/presentation/widgets/mechanic_scaffold_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/features/mechanic/presentation/widgets/mechanic_scaffold.dart';
import 'package:autodoc/features/mechanic/presentation/widgets/mechanic_sidebar.dart';

import '../../../../support/mechanic_harness.dart';
import '../../../../support/responsive_harness.dart';

void main() {
  Future<void> pump(WidgetTester tester, double width) => pumpMechanicScreen(
    tester,
    const MechanicScaffold(
      title: 'Catálogo de Servicios',
      body: Center(child: Text('contenido')),
    ),
    width: width,
  );

  testWidgets('compact y medium usan drawer, no sidebar fijo', (tester) async {
    for (final width in [320.0, 375.0, 600.0, 768.0]) {
      await pump(tester, width);
      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(Row),
          matching: find.byType(MechanicSidebar),
        ),
        findsNothing,
        reason: 'a $width px el sidebar de 280 dp no debe ocupar el layout',
      );
      expect(find.byType(AppBar), findsOneWidget, reason: 'a $width px');
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).drawer,
        isNotNull,
        reason: 'a $width px debe haber drawer para llegar a la navegación',
      );
    }
  });

  testWidgets('expanded y large usan sidebar fijo, sin AppBar', (tester) async {
    for (final width in [840.0, 1024.0, 1200.0, 1440.0]) {
      await pump(tester, width);
      await tester.pump();

      expect(find.byType(MechanicSidebar), findsOneWidget, reason: 'a $width px');
      expect(find.byType(AppBar), findsNothing, reason: 'a $width px');
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).drawer,
        isNull,
        reason: 'a $width px el sidebar ya está visible: el drawer sobra',
      );
    }
  });

  testWidgets('el título identifica la pantalla en las cuatro clases', (
    tester,
  ) async {
    await pump(tester, 375);
    await tester.pump();
    expect(find.text('Catálogo de Servicios'), findsOneWidget);

    await pump(tester, 1440);
    await tester.pump();
    expect(
      find.text('CATÁLOGO DE SERVICIOS'),
      findsOneWidget,
      reason: 'la barra de escritorio usa la variante en mayúsculas',
    );
  });

  testWidgets('no desborda en ninguno de los anchos de auditoría', (
    tester,
  ) async {
    for (final width in kAuditWidths) {
      await pump(tester, width);
      await tester.pump();
      expectNoOverflow(tester);
    }
  });

  testWidgets('el contenido recibe al menos 560 px cuando hay sidebar fijo', (
    tester,
  ) async {
    await pump(tester, 840);
    await tester.pump();

    final bodyWidth = tester.getSize(find.text('contenido')).width;
    expect(
      tester.getSize(find.byType(MechanicSidebar)).width,
      280,
      reason: 'el sidebar sigue midiendo 280 dp',
    );
    expect(
      bodyWidth,
      lessThanOrEqualTo(560),
      reason: 'sanity: el contenido cabe en el hueco que deja el sidebar',
    );
  });
}
```

- [ ] **Step 3: Correr el test y confirmar el fallo exacto**

Run: `flutter test test/features/mechanic/presentation/widgets/mechanic_scaffold_test.dart`
Expected: **FAIL** en compilación — `Error: Couldn't resolve the package 'mechanic_scaffold.dart'` / `Undefined name 'MechanicScaffold'`. El fichero de implementación aún no existe.

- [ ] **Step 4: Implementar `MechanicScaffold`**

```dart
// lib/features/mechanic/presentation/widgets/mechanic_scaffold.dart
import 'package:flutter/material.dart';

import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/features/mechanic/presentation/widgets/mechanic_sidebar.dart';

/// Shell único del rol taller.
///
/// Sustituye al bloque `MediaQuery.of(context).size.width < 700` +
/// `Row([if (!isMobile) MechanicSidebar(), Expanded(...)])` que estaba
/// copiado en ocho pantallas del módulo, cada una con su propia barra
/// superior de 64 dp y su propio título.
///
/// Implementa la matriz de navegación del rol mecánico fijada en la Fase 2:
///
/// | `WindowClass` | Navegación             |
/// |---------------|------------------------|
/// | `compact`     | `AppBar` + `Drawer`    |
/// | `medium`      | `AppBar` + `Drawer`    |
/// | `expanded`    | `MechanicSidebar` fijo |
/// | `large`       | `MechanicSidebar` fijo |
///
/// El corte está en `expanded` (840) y no en los 700 anteriores porque el
/// sidebar mide 280 dp fijos: a 700 px dejaba 420 px de contenido, menos que
/// un teléfono.
class MechanicScaffold extends StatelessWidget {
  /// Nombre de **esta** pantalla, no del panel. Se usa tal cual en el
  /// `AppBar` de teléfono y en mayúsculas en la barra de escritorio; antes
  /// dos pantallas distintas ponían ambas `'Panel de Taller'` en móvil.
  final String title;

  final Widget body;

  /// Acciones de la barra (tema, idioma, notificaciones). Se pintan en la
  /// barra que corresponda a la clase de ventana, nunca en las dos.
  final List<Widget> actions;

  final Widget? floatingActionButton;

  const MechanicScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    final windowClass = AppBreakpoints.of(context);
    final showFixedSidebar = windowClass.isAtLeastExpanded;
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: showFixedSidebar
          ? null
          : AppBar(
              backgroundColor: colors.surface,
              elevation: 0,
              iconTheme: IconThemeData(color: colors.primary),
              title: Text(
                title,
                style: AppTextStyles.titleMedium.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              actions: actions,
            ),
      drawer: showFixedSidebar ? null : const Drawer(child: MechanicSidebar()),
      floatingActionButton: floatingActionButton,
      body: Row(
        children: [
          if (showFixedSidebar) const MechanicSidebar(),
          Expanded(
            child: Column(
              children: [
                if (showFixedSidebar)
                  _MechanicTopBar(title: title, actions: actions),
                Expanded(child: body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Barra superior de escritorio del panel de taller.
///
/// Era un `Container(height: 64, ...)` repetido en seis pantallas con cinco
/// textos distintos y el mismo borde inferior dibujado a mano.
class _MechanicTopBar extends StatelessWidget {
  final String title;
  final List<Widget> actions;

  const _MechanicTopBar({required this.title, required this.actions});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      height: 64,
      padding: EdgeInsets.symmetric(
        horizontal: AppBreakpoints.gutter(AppBreakpoints.of(context)),
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          bottom: BorderSide(color: colors.outline.withValues(alpha: 0.4)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title.toUpperCase(),
                style: AppTextStyles.titleLarge.copyWith(
                  fontWeight: FontWeight.w900,
                  color: colors.primary,
                  letterSpacing: -0.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Correr el test y confirmar verde**

Run: `flutter test test/features/mechanic/presentation/widgets/mechanic_scaffold_test.dart`
Expected: **PASS (5 tests)**.

- [ ] **Step 6: Hacer que `MainScaffold` delegue en el shell nuevo**

En `lib/core/widgets/main_scaffold.dart`, sustituye el cuerpo de `_MechanicShell` (que la Fase 2 Task 5 dejó con su propio `Scaffold`) por:

```dart
class _MechanicShell extends StatelessWidget {
  final Widget child;

  const _MechanicShell({required this.child});

  /// Títulos de las rutas del `ShellRoute` alcanzables por un mecánico.
  /// Hoy solo `/chat_list`: es la única ruta del shell exenta del redirect
  /// por rol ([app_router.dart:246-250]). Las otras nueve rutas del panel de
  /// taller son `GoRoute` de primer nivel y montan `MechanicScaffold`
  /// directamente.
  static const Map<String, String> _titles = {'/chat_list': 'Mensajes'};

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    return MechanicScaffold(
      title: _titles[path] ?? 'AutoDoc Taller',
      body: child,
    );
  }
}
```

Y en `MainScaffold.build`, quita el parámetro `windowClass` de la llamada (`_MechanicShell` ya lo resuelve dentro de `MechanicScaffold`):

```dart
return isMecanico
    ? _MechanicShell(child: child)
    : _OwnerShell(windowClass: windowClass, child: child);
```

Añade el import de `mechanic_scaffold.dart` y **quita** el de `mechanic_sidebar.dart` si deja de usarse en este fichero.

> **Bloqueo a consultar, no resolver aquí:** el predicado de rol de la Fase 2 es `userData?.rol == 'Mecanico'`, comparación exacta. En el repo conviven **tres** criterios distintos: `_normalizeRole` acepta `'mecanico'` y `'taller'` ([app_router.dart:114-120](../../../lib/core/router/app_router.dart#L114-L120)), `isMechanicRole` acepta solo `'mecanico'` ([role_utils.dart:2-6](../../../lib/core/utils/role_utils.dart#L2-L6)), y `mechanicFirestoreRoles` es `['Mecanico']`. Además [mechanic_sidebar.dart:39-41](../../../lib/features/mechanic/presentation/widgets/mechanic_sidebar.dart#L39-L41) documenta que las sub-cuentas de empleado tienen `rol == 'Taller'`. Cuál de los tres es correcto es una pregunta del modelo de datos, no de UI. **Deja el predicado como está**, añade encima un comentario apuntando a esta nota, y súbelo al PR como pregunta.

- [ ] **Step 7: Comprobar que no se rompió la Fase 2**

Run: `flutter test test/core/widgets/main_scaffold_adaptive_test.dart`
Expected: PASS. Si el test de la Fase 2 buscaba `AppBar(title: Text('AutoDoc Taller'))` en `/chat_list`, actualiza el finder a `'Mensajes'`: el cambio es deliberado y está justificado arriba.

- [ ] **Step 8: Verificar y commitear**

```bash
dart format . && flutter analyze && flutter test
git add lib/features/mechanic/presentation/widgets/mechanic_scaffold.dart \
        test/support/mechanic_harness.dart \
        test/features/mechanic/presentation/widgets/mechanic_scaffold_test.dart \
        lib/core/widgets/main_scaffold.dart
git commit -m "feat(mechanic): extract MechanicScaffold as the single workshop shell

El shell del rol taller estaba copiado en ocho pantallas con un breakpoint
propio de 700 px (un tercer sistema, ademas de Responsive y
responsive_framework) y una barra superior de 64 dp reescrita seis veces.
MechanicScaffold aplica la matriz de la Fase 2 (drawer hasta 840, sidebar
fijo desde ahi) y toma el titulo real de cada pantalla: dos de ellas ponian
'Panel de Taller' en movil y el usuario no sabia donde estaba.
MainScaffold._MechanicShell delega aqui para que /chat_list vea el mismo
shell que el resto del panel."
```

---

### Task 2: `mechanic_pending_screen` — que scrollee y que el latido no sea eterno

**Files:**
- Modify: `lib/features/mechanic/presentation/pages/mechanic_pending_screen.dart`
- Test: `test/features/mechanic/presentation/pages/mechanic_pending_screen_test.dart`

**Interfaces:**
- Consumes: `AppPageBody`, `AppBreakpoints` (Fase 1 Task 5/1); `AppMotion` (Fase 1 Task 2); `AppButton` (Fase 3 Task 1); `AppSpacing`, `AppRadius`, `AppTextStyles`; `pumpMechanicScreen` (Task 1).
- Produces: nada público nuevo. `MechanicPendingScreen()` mantiene su API.

**Problemas medidos:**

1. **No scrollea.** El cuerpo es `SafeArea > Padding > Column` ([L87-90](../../../lib/features/mechanic/presentation/pages/mechanic_pending_screen.dart#L87-L90)) con icono de 120 + 40 + título + 16 + subtítulo + 12 + tarjeta de 3 filas + 40 + botón de 54 + 16 + botón de texto. A 320×568 (iPhone SE en horizontal, o cualquier teléfono con el teclado fuera) **desborda en vertical**.
2. **Pulso infinito.** `.animate(onPlay: (c) => c.repeat()).scale(duration: 2 s)` ([L111-121](../../../lib/features/mechanic/presentation/pages/mechanic_pending_screen.dart#L111-L121)) no para nunca, no consulta reduced motion, y hace que **`tester.pumpAndSettle()` sobre esta pantalla nunca termine** — ningún widget test puede usarla.
3. `Container(width: 120, height: 120)` fijo; `borderRadius: 16`/`12` literales; `600.ms`/`800.ms`/`1000.ms` literales; `ElevatedButton` crudo con `height: 54` en vez de `AppButton`.
4. Sin cota de ancho: a 1440 px el párrafo va de borde a borde.
5. `_infoRow` no marca el bloque como una unidad para el lector de pantalla.

**Decisión de motion (`emil-design-eng`, framework de decisión):** el pulso **se elimina**, no se tokeniza. Primera pregunta del framework: *¿debe animar?* La respuesta es no — nada ha cambiado, el usuario no está esperando a que ese icono haga algo, y la animación no comunica progreso real (el estado solo cambia cuando pulsa "Verificar Estado"). Es decoración que consume batería indefinidamente. La **entrada** escalonada sí se conserva: ahí sí hay un cambio de estado real (contenido que llega) y tiene propósito.

- [ ] **Step 1: Invocar las skills**

`Skill(emil-design-eng)`: confirma el descarte del `repeat()` contra el framework de decisión y anota la duración/curva de entrada. `Skill(ui-ux-pro-max:ui-ux-pro-max)` + `search.py "empty state waiting screen" --stack flutter`: anota la anchura de lectura recomendada.

- [ ] **Step 2: Escribir el test que falla**

```dart
// test/features/mechanic/presentation/pages/mechanic_pending_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/features/mechanic/presentation/pages/mechanic_pending_screen.dart';

import '../../../../support/mechanic_harness.dart';
import '../../../../support/responsive_harness.dart';

void main() {
  testWidgets('no desborda en ningún ancho de auditoría, ni en 568 de alto', (
    tester,
  ) async {
    for (final width in kAuditWidths) {
      await pumpMechanicScreen(
        tester,
        const MechanicPendingScreen(),
        width: width,
        height: 568,
        location: '/mechanic_pending',
        disableAnimations: true,
      );
      await tester.pump();
      expectNoOverflow(tester);
    }
  });

  testWidgets('la pantalla se estabiliza: no hay animación en bucle', (
    tester,
  ) async {
    await pumpMechanicScreen(
      tester,
      const MechanicPendingScreen(),
      width: 375,
      location: '/mechanic_pending',
    );

    // Con el `repeat()` actual esto lanza
    // "pumpAndSettle timed out": la animación nunca termina.
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('Cuenta Pendiente de Aprobación'), findsOneWidget);
  });

  testWidgets('usa AppButton, no un ElevatedButton crudo', (tester) async {
    await pumpMechanicScreen(
      tester,
      const MechanicPendingScreen(),
      width: 375,
      location: '/mechanic_pending',
      disableAnimations: true,
    );
    await tester.pump();

    expect(find.byType(AppButton), findsOneWidget);
    expect(find.byType(ElevatedButton), findsNothing);
  });

  testWidgets('el contenido no se estira más allá de la medida de formulario', (
    tester,
  ) async {
    await pumpMechanicScreen(
      tester,
      const MechanicPendingScreen(),
      width: 1440,
      location: '/mechanic_pending',
      disableAnimations: true,
    );
    await tester.pump();

    final width = tester
        .getSize(find.text('Cuenta Pendiente de Aprobación'))
        .width;
    expect(
      width,
      lessThanOrEqualTo(560),
      reason: 'un párrafo de 1440 px de ancho es ilegible',
    );
  });
}
```

- [ ] **Step 3: Correr el test y confirmar el fallo exacto**

Run: `flutter test test/features/mechanic/presentation/pages/mechanic_pending_screen_test.dart`
Expected: **FAIL, 4 de 4.**
- test 1: `A RenderFlex overflowed by NNN pixels on the bottom` a 320 px.
- test 2: `pumpAndSettle timed out`.
- test 3: `Expected: no matching candidates / Actual: found 1 ElevatedButton`.
- test 4: el ancho medido es ~1376, no ≤560.

- [ ] **Step 4: Implementar**

4a. Envuelve el contenido en scroll y cota de ancho. Sustituye el `SafeArea > Padding > Column` de [L87-90](../../../lib/features/mechanic/presentation/pages/mechanic_pending_screen.dart#L87-L90) por:

```dart
child: SafeArea(
  child: SingleChildScrollView(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
    child: AppPageBody(
      maxWidth: AppBreakpoints.maxFormWidth,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [ ... ],
      ),
    ),
  ),
),
```

4b. Reemplaza el icono animado ([L94-121](../../../lib/features/mechanic/presentation/pages/mechanic_pending_screen.dart#L94-L121)) por un helper sin bucle:

```dart
Widget _pendingIcon(AppColors colors) {
  final size = Responsive.size(context, 96);
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: colors.primary.withValues(alpha: 0.1),
      shape: BoxShape.circle,
      border: Border.all(
        color: colors.primary.withValues(alpha: 0.3),
        width: 2,
      ),
    ),
    child: Icon(
      Icons.schedule_rounded,
      size: size / 2,
      color: colors.primary,
      semanticLabel: 'Pendiente de aprobación',
    ),
  );
}
```

4c. Añade el helper de entrada escalonada y aplícalo a los cuatro bloques (icono, título, subtítulo, tarjeta) con `index` 0..3:

```dart
/// Entrada escalonada. Con reduced motion se devuelve el hijo tal cual: se
/// conserva el contenido y se elimina el desplazamiento, que es lo que la
/// preferencia pide.
Widget _entrance(BuildContext context, int index, Widget child) {
  if (AppMotion.reduced(context)) return child;
  final delay = AppMotion.staggerStep * index;
  return child
      .animate()
      .fadeIn(
        duration: AppMotion.sheetEnter,
        delay: delay,
        curve: AppMotion.easeOut,
      )
      .slideY(
        begin: 0.15,
        end: 0,
        duration: AppMotion.sheetEnter,
        delay: delay,
        curve: AppMotion.easeOut,
      );
}
```

4d. Sustituye el `SizedBox(height: 54) > ElevatedButton.icon` ([L192-222](../../../lib/features/mechanic/presentation/pages/mechanic_pending_screen.dart#L192-L222)) por:

```dart
SizedBox(
  width: double.infinity,
  child: AppButton(
    text: _checking ? 'Verificando...' : 'Verificar Estado',
    isLoading: _checking,
    onPressed: _checking ? null : _checkApprovalStatus,
    icon: const Icon(Icons.refresh_rounded),
  ),
),
```

4e. Tokeniza el resto: `BorderRadius.circular(16)` → `BorderRadius.circular(AppRadius.lg)`; `SizedBox(height: 40)` → `AppSpacing.xxxl`; `height: 16/12` → `AppSpacing.base`/`AppSpacing.md`; `Responsive.padding(context, 20)` en la tarjeta → `AppSpacing.xl`. Sustituye los seis `GoogleFonts.inter(...)` por `AppTextStyles.*` (`headlineSmall` para el título, `bodyMedium` para el subtítulo y las filas de info).

4f. Envuelve la tarjeta de información en `Semantics(container: true, label: '¿Qué sigue?')` para que el lector la anuncie como una unidad y no como tres textos sueltos.

- [ ] **Step 5: Correr el test y confirmar verde**

Run: `flutter test test/features/mechanic/presentation/pages/mechanic_pending_screen_test.dart`
Expected: **PASS (4 tests)**.

- [ ] **Step 6: Verificar y commitear**

```bash
dart format . && flutter analyze && flutter test
git add lib/features/mechanic/presentation/pages/mechanic_pending_screen.dart \
        test/features/mechanic/presentation/pages/mechanic_pending_screen_test.dart
git commit -m "fix(mechanic): make the pending screen scroll and stop the endless pulse

El cuerpo era un Column sin scroll: desbordaba en vertical a 320x568. El
icono tenia un .repeat() de 2 s que no paraba nunca, ignoraba reduced motion
y hacia que pumpAndSettle no terminara jamas sobre esta pantalla. Se elimina
en vez de tokenizarse: no comunica ningun cambio de estado (el estado solo
cambia al pulsar 'Verificar Estado'). La entrada escalonada si se conserva y
ahora respeta la preferencia del sistema."
```

---

### Task 3: `reparaciones_kanban_screen` — el kanban que no cabe, y que desborda

**Files:**
- Modify: `lib/features/mechanic/presentation/pages/reparaciones_kanban_screen.dart`
- Modify: `lib/features/mechanic/presentation/widgets/reparacion_card.dart`
- Test: `test/features/mechanic/presentation/pages/reparaciones_kanban_responsive_test.dart`

**Interfaces:**
- Consumes: `MechanicScaffold` (Task 1); `AppBreakpoints`, `WindowClass`, `WindowClassX` (Fase 1); `AppMotion`; `AppCard`, `AppEmptyState` (Fase 3); `AppSpacing`, `AppTextStyles`; `estadosReparacion`, `ReparacionModel` (existentes); `pumpMechanicScreen` (Task 1).
- Produces: `etiquetasEstado` pasa de privado (`_etiquetasEstado`) a **público** en el mismo fichero, porque el test necesita las cuatro etiquetas. `ReparacionCard` gana `siguienteEstadoLabel`.

**Problemas medidos:**

1. **Desborda en vertical, y es un bug real, no de estilo.** El árbol es `SingleChildScrollView(scrollDirection: horizontal) > Row > Container(width: 260) > Column` ([L74-89](../../../lib/features/mechanic/presentation/pages/reparaciones_kanban_screen.dart#L74-L89)). En un scroll horizontal el hijo recibe **ancho ilimitado pero altura acotada** al viewport. Con 4 tarjetas o más en una columna, el `Column` desborda por abajo y no hay forma de llegar a las de abajo.
2. **A 375 px se ven 1,4 columnas.** Cuatro columnas de 260 + margen 12 = 1.088 px de ancho mínimo. En un teléfono el usuario tiene que hacer scroll horizontal a ciegas para saber cuántos vehículos hay en cada estado.
3. `width: 260` y `margin: 12` fijos; `Responsive.fontSize` en los encabezados; `'Sin vehículos'` como `Text` suelto en vez de estado vacío.
4. `ReparacionCard` muestra **solo la placa**. No dice en qué estado está, ni desde cuándo, ni de quién es. El botón dice `'Avanzar'` sin decir a dónde.

**Contrato (corrige y concreta el del maestro §5.2):**

| `WindowClass` | Estructura |
|---|---|
| `compact`, `medium` | `TabBar` con un tab por estado, con el contador; una sola lista visible, con scroll vertical propio |
| `expanded`, `large` | Columnas reales. Si las 4 caben (`maxWidth ≥ 4×240 + 3×12`), `Expanded` y **sin scroll horizontal**; si no, ancho fijo 240 y scroll horizontal. Cada columna con su `ListView` vertical |

`apple-design` aplica aquí: si queda scroll horizontal (ventanas entre 840 y ~1000 px), debe conservar el momentum y el rebote nativo — se consigue dejando el `ScrollPhysics` por defecto de la plataforma y **no** forzando `ClampingScrollPhysics`.

**Nota honesta sobre drag & drop:** este tablero no tiene arrastre hoy (el avance es un botón) y **no se añade aquí**. Añadir `Draggable`/`DragTarget` cambiaría el modelo de interacción y tocaría `ReparacionProvider.cambiarEstado` en un flujo nuevo; es una feature, no una refactorización de UI. Queda en el backlog del PR.

- [ ] **Step 1: Invocar las skills**

`Skill(ui-ux-pro-max:ui-ux-pro-max)` + `search.py "kanban board column list mobile" --stack flutter`: anota qué recomienda para tableros en pantallas estrechas. `Skill(apple-design)`: anota qué dice sobre scroll con momentum y sobre el borde del contenedor cuando hay más columnas de las visibles.

- [ ] **Step 2: Escribir el test que falla**

```dart
// test/features/mechanic/presentation/pages/reparaciones_kanban_responsive_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:provider/provider.dart';

import 'package:autodoc/core/models/reparacion_model.dart';
import 'package:autodoc/features/mechanic/data/repositories/reparacion_repository.dart';
import 'package:autodoc/features/mechanic/presentation/pages/reparaciones_kanban_screen.dart';
import 'package:autodoc/features/mechanic/presentation/providers/reparacion_provider.dart';

import '../../../../support/mechanic_harness.dart';
import '../../../../support/responsive_harness.dart';

/// Siembra [count] reparaciones en el estado [estado] para que la columna
/// tenga más tarjetas de las que caben en el viewport.
Future<FakeFirebaseFirestore> seedReparaciones({
  int count = 8,
  String estado = 'recibido',
}) async {
  final firestore = FakeFirebaseFirestore();
  for (var i = 0; i < count; i++) {
    await firestore.collection('reparaciones').doc('r$i').set({
      'id_vehiculo': 'v$i',
      'id_taller': 't1',
      'id_propietario': 'p$i',
      'placa': 'ABC${100 + i}',
      'estado': estado,
      'historial_estados': <Map<String, dynamic>>[],
      'fecha_creacion': DateTime(2026, 8, 1),
      'fecha_actualizacion': DateTime(2026, 8, 5),
    });
  }
  return firestore;
}

Future<void> pumpKanban(
  WidgetTester tester, {
  required double width,
  required FakeFirebaseFirestore firestore,
  double height = 800,
}) async {
  await pumpMechanicScreen(
    tester,
    const ReparacionesKanbanScreen(idTaller: 't1'),
    width: width,
    height: height,
    location: '/mechanic_reparaciones',
    disableAnimations: true,
    extraProviders: [
      ChangeNotifierProvider(
        create: (_) => ReparacionProvider(
          repository: ReparacionRepository(firestore: firestore),
        ),
      ),
    ],
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('una columna con 8 tarjetas no desborda en vertical', (
    tester,
  ) async {
    final firestore = await seedReparaciones(count: 8);
    await pumpKanban(tester, width: 1440, firestore: firestore);

    expectNoOverflow(tester);
  });

  testWidgets('a 375 px los cuatro estados son tabs, no columnas', (
    tester,
  ) async {
    final firestore = await seedReparaciones(count: 2);
    await pumpKanban(tester, width: 375, firestore: firestore);

    expect(find.byType(TabBar), findsOneWidget);
    for (final label in etiquetasEstado.values) {
      expect(find.text(label), findsOneWidget, reason: 'falta el tab $label');
    }
    // Solo la lista del tab activo está montada.
    expect(find.byType(ListView), findsOneWidget);
  });

  testWidgets('a 1440 px las cuatro columnas caben sin scroll horizontal', (
    tester,
  ) async {
    final firestore = await seedReparaciones(count: 2);
    await pumpKanban(tester, width: 1440, firestore: firestore);

    expect(find.byType(TabBar), findsNothing);
    expect(
      find.byType(ListView),
      findsNWidgets(4),
      reason: 'cada estado debe tener su propia lista con scroll vertical',
    );

    final xs = tester
        .widgetList<Text>(find.byType(Text))
        .where((t) => etiquetasEstado.values.contains(t.data))
        .length;
    expect(xs, 4, reason: 'los cuatro encabezados de columna deben estar');
  });

  testWidgets('no desborda en ninguno de los anchos de auditoría', (
    tester,
  ) async {
    for (final width in kAuditWidths) {
      final firestore = await seedReparaciones(count: 5);
      await pumpKanban(tester, width: width, firestore: firestore);
      expectNoOverflow(tester);
    }
  });

  testWidgets('el botón de avanzar dice a qué estado avanza', (tester) async {
    final firestore = await seedReparaciones(count: 1);
    await pumpKanban(tester, width: 1440, firestore: firestore);

    expect(find.text('Avanzar a En Revisión'), findsOneWidget);
    expect(find.text('Avanzar'), findsNothing);
  });
}
```

- [ ] **Step 3: Correr el test y confirmar el fallo exacto**

Run: `flutter test test/features/mechanic/presentation/pages/reparaciones_kanban_responsive_test.dart`
Expected: **FAIL, 5 de 5.** El primero por compilación (`etiquetasEstado` es privado) y, una vez expuesto, test 1 por `A RenderFlex overflowed by NNN pixels on the bottom`, test 2 por `TabBar` no encontrado, test 3 por `findsNWidgets(4)` sobre 0 `ListView`, test 5 por texto `'Avanzar'`.

- [ ] **Step 4: Implementar la pantalla**

4a. Haz pública la tabla de etiquetas y añade el orden:

```dart
/// Etiquetas visibles de los estados del tablero, en el mismo orden que
/// `estadosReparacion`. Pública porque los tests y `ReparacionCard`
/// necesitan el nombre del estado siguiente.
const Map<String, String> etiquetasEstado = {
  'recibido': 'Recibido',
  'en_revision': 'En Revisión',
  'esperando_repuestos': 'Esperando Repuestos',
  'listo_para_entrega': 'Listo para Entregar',
};
```

4b. Sustituye todo el `build` por `MechanicScaffold` + `LayoutBuilder`:

```dart
@override
Widget build(BuildContext context) {
  return MechanicScaffold(
    title: 'Reparaciones',
    body: Consumer<ReparacionProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.reparaciones.isEmpty) {
          return Center(
            child: CircularProgressIndicator(color: context.appColors.primary),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final windowClass = AppBreakpoints.fromWidth(constraints.maxWidth);
            return windowClass.isAtLeastExpanded
                ? _ColumnsBoard(provider: provider, available: constraints.maxWidth)
                : _TabsBoard(provider: provider);
          },
        );
      },
    ),
  );
}
```

4c. Añade los dos layouts y la columna compartida:

```dart
/// Ancho mínimo de una columna del tablero. Por debajo de esto una placa
/// más el botón "Avanzar a Esperando Repuestos" ya no caben en dos líneas.
const double _anchoColumna = 240;

class _ColumnsBoard extends StatelessWidget {
  final ReparacionProvider provider;
  final double available;

  const _ColumnsBoard({required this.provider, required this.available});

  @override
  Widget build(BuildContext context) {
    final gutter = AppBreakpoints.gutter(AppBreakpoints.fromWidth(available));
    final n = estadosReparacion.length;
    final cabenTodas =
        available >= n * _anchoColumna + (n - 1) * AppSpacing.md + gutter * 2;

    final columnas = [
      for (var i = 0; i < n; i++)
        _EstadoColumn(provider: provider, index: i),
    ];

    if (cabenTodas) {
      return Padding(
        padding: EdgeInsets.all(gutter),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < n; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.md),
              Expanded(child: columnas[i]),
            ],
          ],
        ),
      );
    }

    // Physics por defecto: en iOS conserva el rebote y el momentum nativos.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.all(gutter),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < n; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.md),
            SizedBox(width: _anchoColumna, child: columnas[i]),
          ],
        ],
      ),
    );
  }
}

class _TabsBoard extends StatelessWidget {
  final ReparacionProvider provider;

  const _TabsBoard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return DefaultTabController(
      length: estadosReparacion.length,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: colors.primary,
            unselectedLabelColor: colors.textSecondary,
            indicatorColor: colors.primary,
            tabs: [
              for (final estado in estadosReparacion)
                Tab(
                  height: 48,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(etiquetasEstado[estado] ?? estado),
                      const SizedBox(width: AppSpacing.sm),
                      _ContadorBadge(
                        count: provider.reparaciones
                            .where((r) => r.estado == estado)
                            .length,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                for (var i = 0; i < estadosReparacion.length; i++)
                  _EstadoColumn(
                    provider: provider,
                    index: i,
                    mostrarEncabezado: false,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

```dart
/// Una columna del tablero: encabezado (solo en el layout de columnas) y la
/// lista de tarjetas con **su propio scroll vertical**. Ese scroll es la
/// corrección del desbordamiento: antes era un `Column` dentro de un scroll
/// horizontal, que recibe altura acotada y no puede crecer.
class _EstadoColumn extends StatelessWidget {
  final ReparacionProvider provider;
  final int index;
  final bool mostrarEncabezado;

  const _EstadoColumn({
    required this.provider,
    required this.index,
    this.mostrarEncabezado = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final estado = estadosReparacion[index];
    final esUltimo = index == estadosReparacion.length - 1;
    final siguienteEstado = esUltimo ? null : estadosReparacion[index + 1];
    final items = provider.reparaciones
        .where((r) => r.estado == estado)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (mostrarEncabezado) ...[
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    etiquetasEstado[estado] ?? estado,
                    style: AppTextStyles.titleSmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              _ContadorBadge(count: items.length),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Expanded(
          child: items.isEmpty
              ? const AppEmptyState(
                  title: 'Sin vehículos',
                  description: 'Ningún vehículo está en este estado.',
                  icon: Icons.directions_car_outlined,
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) => ReparacionCard(
                    reparacion: items[i],
                    esUltimoEstado: esUltimo,
                    siguienteEstadoLabel: siguienteEstado == null
                        ? null
                        : etiquetasEstado[siguienteEstado],
                    onAvanzar: siguienteEstado == null
                        ? null
                        : () => provider.cambiarEstado(
                            items[i].idReparacion,
                            siguienteEstado,
                          ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _ContadorBadge extends StatelessWidget {
  final int count;

  const _ContadorBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Semantics(
      label: '$count ${count == 1 ? 'vehículo' : 'vehículos'}',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Text(
            '$count',
            style: AppTextStyles.labelSmall.copyWith(color: colors.primary),
          ),
        ),
      ),
    );
  }
}
```

4d. Enriquece `ReparacionCard`:

```dart
class ReparacionCard extends StatelessWidget {
  final ReparacionModel reparacion;
  final VoidCallback? onAvanzar;
  final bool esUltimoEstado;

  /// Nombre visible del estado al que lleva [onAvanzar]. Sin esto el botón
  /// decía solo "Avanzar" y el usuario no sabía a dónde.
  final String? siguienteEstadoLabel;

  const ReparacionCard({
    super.key,
    required this.reparacion,
    this.onAvanzar,
    this.esUltimoEstado = false,
    this.siguienteEstadoLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final dias = DateTime.now().difference(reparacion.fechaActualizacion).inDays;

    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            reparacion.placa,
            style: AppTextStyles.titleSmall.copyWith(
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            dias == 0
                ? 'Actualizado hoy'
                : 'Hace $dias ${dias == 1 ? 'día' : 'días'}',
            style: AppTextStyles.bodySmall.copyWith(color: colors.textSecondary),
          ),
          if (!esUltimoEstado && siguienteEstadoLabel != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onAvanzar,
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: Text('Avanzar a $siguienteEstadoLabel'),
                style: TextButton.styleFrom(foregroundColor: colors.primary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Correr el test y confirmar verde**

Run: `flutter test test/features/mechanic/presentation/pages/reparaciones_kanban_responsive_test.dart`
Expected: **PASS (5 tests)**.

- [ ] **Step 6: Comprobar el test preexistente**

Run: `flutter test test/features/mechanic/presentation/pages/reparaciones_kanban_screen_test.dart`
Expected: PASS sin tocarlo — corre a 1400×1000, que es `large`, así que ve las cuatro columnas con sus cuatro encabezados y `findsOneWidget` para cada etiqueta se mantiene.

- [ ] **Step 7: Verificar y commitear**

```bash
dart format . && flutter analyze && flutter test
git add lib/features/mechanic/presentation/pages/reparaciones_kanban_screen.dart \
        lib/features/mechanic/presentation/widgets/reparacion_card.dart \
        test/features/mechanic/presentation/pages/reparaciones_kanban_responsive_test.dart
git commit -m "fix(mechanic): make the kanban board reachable on every window size

Las columnas eran Column dentro de un SingleChildScrollView horizontal: ese
viewport da ancho ilimitado pero altura acotada, asi que a partir de la
cuarta tarjeta la columna desbordaba por abajo y las de mas abajo eran
inalcanzables. Ahora cada columna tiene su propio ListView vertical. Por
debajo de 840 px el tablero pasa a tabs por estado con contador: cuatro
columnas de 260 px necesitaban 1088 px de ancho, asi que en telefono habia
que hacer scroll horizontal a ciegas. El boton dice a que estado avanza."
```

---

### Task 4: `catalogo_servicios_screen` — rejilla, y el primer diálogo que no cabe

**Files:**
- Create: `lib/core/widgets/app_dialog_content.dart`
- Modify: `lib/features/mechanic/presentation/pages/catalogo_servicios_screen.dart`
- Test: `test/core/widgets/app_dialog_content_test.dart`
- Test: `test/features/mechanic/presentation/pages/catalogo_servicios_responsive_test.dart`

**Interfaces:**
- Consumes: `MechanicScaffold` (Task 1); `AppGrid`, `AppPageBody`, `AppBreakpoints` (Fase 1); `AppCard`, `AppEmptyState` (Fase 3); `AppSpacing`, `AppTextStyles`.
- Produces: `AppDialogContent({required Widget child, double maxWidth = AppBreakpoints.maxFormWidth})` — **reutilizado por las Tasks 5 y 6**, que tienen el mismo problema.

**Problemas medidos:**

1. `SizedBox(width: 380)` dentro del `AlertDialog` ([L100-101](../../../lib/features/mechanic/presentation/pages/catalogo_servicios_screen.dart#L100-L101)). Un `AlertDialog` tiene 40 px de `insetPadding` a cada lado: a 320 px de ancho de pantalla el contenido dispone de 240 px y **380 desborda en horizontal**.
2. `ListView.separated` de una sola columna siempre ([L319](../../../lib/features/mechanic/presentation/pages/catalogo_servicios_screen.dart#L319)): a 1440 px cada ítem del catálogo es una fila de ~1.100 px con un icono a la izquierda, un nombre, un precio y una papelera. Espacio muerto puro.
3. Estado vacío escrito a mano ([L282-317](../../../lib/features/mechanic/presentation/pages/catalogo_servicios_screen.dart#L282-L317)) con `Responsive.iconSize(context, 56)` y sin cota de ancho.
4. `IconButton` de borrar **sin `tooltip`** ([L361-367](../../../lib/features/mechanic/presentation/pages/catalogo_servicios_screen.dart#L361-L367)): un lector de pantalla anuncia solo "botón".
5. El shell duplicado y la barra de 64 dp (`'CATÁLOGO DE SERVICIOS'`) — los resuelve `MechanicScaffold`.

**Por qué `AppDialogContent` y no `SizedBox(width: double.maxFinite)` a secas:** `double.maxFinite` dentro de un `AlertDialog` hace que el contenido tome **todo** el ancho disponible, que a 1440 px son 1.360. Hace falta el `ConstrainedBox` por fuera para acotar arriba y el `SizedBox` por dentro para llenar abajo. Es un patrón de dos capas que se equivoca fácil, por eso se encapsula una vez.

- [ ] **Step 1: Invocar las skills**

`Skill(ui-ux-pro-max:ui-ux-pro-max)` + `search.py "dialog modal form width" --stack flutter` y `search.py "list grid catalogue items" --stack flutter`. Anota la anchura máxima recomendada para un formulario en diálogo y el número de columnas por breakpoint para tarjetas de una o dos líneas.

- [ ] **Step 2: Escribir los tests que fallan**

```dart
// test/core/widgets/app_dialog_content_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/widgets/app_dialog_content.dart';

import '../../support/responsive_harness.dart';

void main() {
  Future<void> pumpDialog(WidgetTester tester, double width) async {
    await pumpAtWidth(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => const AlertDialog(
              title: Text('Nuevo ítem'),
              content: AppDialogContent(
                child: TextField(key: Key('campo')),
              ),
            ),
          ),
          child: const Text('abrir'),
        ),
      ),
      width: width,
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('no desborda ni siquiera a 320 px', (tester) async {
    await pumpDialog(tester, 320);
    expectNoOverflow(tester);
    expect(tester.getSize(find.byKey(const Key('campo'))).width, lessThan(320));
  });

  testWidgets('no se estira más allá de la medida de formulario', (
    tester,
  ) async {
    await pumpDialog(tester, 1440);
    expect(
      tester.getSize(find.byKey(const Key('campo'))).width,
      lessThanOrEqualTo(560),
    );
  });
}
```

```dart
// test/features/mechanic/presentation/pages/catalogo_servicios_responsive_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:provider/provider.dart';

import 'package:autodoc/core/widgets/app_empty_state.dart';
import 'package:autodoc/core/widgets/app_grid.dart';
import 'package:autodoc/features/mechanic/data/repositories/catalogo_repository.dart';
import 'package:autodoc/features/mechanic/presentation/pages/catalogo_servicios_screen.dart';
import 'package:autodoc/features/mechanic/presentation/providers/catalogo_provider.dart';

import '../../../../support/mechanic_harness.dart';
import '../../../../support/responsive_harness.dart';

Future<FakeFirebaseFirestore> seedCatalogo({int count = 6}) async {
  final firestore = FakeFirebaseFirestore();
  for (var i = 0; i < count; i++) {
    await firestore
        .collection('talleres')
        .doc('t1')
        .collection('catalogo_servicios')
        .doc('i$i')
        .set({'nombre': 'Cambio de aceite $i', 'precio': 25.0 + i});
  }
  return firestore;
}

Future<void> pumpCatalogo(
  WidgetTester tester, {
  required double width,
  required FakeFirebaseFirestore firestore,
}) async {
  await pumpMechanicScreen(
    tester,
    const CatalogoServiciosScreen(idTaller: 't1'),
    width: width,
    location: '/mechanic/catalogo',
    disableAnimations: true,
    extraProviders: [
      ChangeNotifierProvider(
        create: (_) =>
            CatalogoProvider(repository: CatalogoRepository(firestore: firestore)),
      ),
    ],
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('los ítems se distribuyen en rejilla, no en una sola columna', (
    tester,
  ) async {
    final firestore = await seedCatalogo();
    await pumpCatalogo(tester, width: 1440, firestore: firestore);

    expect(find.byType(AppGrid), findsOneWidget);

    final lefts = tester
        .widgetList<Text>(find.textContaining('Cambio de aceite'))
        .map((t) => tester.getTopLeft(find.text(t.data!)).dx)
        .toSet();
    expect(
      lefts.length,
      greaterThan(1),
      reason: 'a 1440 px debe haber más de una columna',
    );
  });

  testWidgets('el estado vacío usa AppEmptyState', (tester) async {
    final firestore = await seedCatalogo(count: 0);
    await pumpCatalogo(tester, width: 375, firestore: firestore);

    expect(find.byType(AppEmptyState), findsOneWidget);
  });

  testWidgets('el botón de borrar se anuncia', (tester) async {
    final firestore = await seedCatalogo(count: 1);
    await pumpCatalogo(tester, width: 375, firestore: firestore);

    final boton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.delete_outline),
    );
    expect(boton.tooltip, isNotNull);
    expect(boton.tooltip, contains('Eliminar'));
  });

  testWidgets('no desborda en ninguno de los anchos de auditoría', (
    tester,
  ) async {
    for (final width in kAuditWidths) {
      final firestore = await seedCatalogo();
      await pumpCatalogo(tester, width: width, firestore: firestore);
      expectNoOverflow(tester);
    }
  });

  test('el fichero no usa GoogleFonts ni el breakpoint de 700', () {
    final source = File(
      'lib/features/mechanic/presentation/pages/catalogo_servicios_screen.dart',
    ).readAsStringSync();

    expect(source.contains('GoogleFonts.'), isFalse);
    expect(source.contains('size.width < 700'), isFalse);
    expect(source.contains('MechanicSidebar'), isFalse);
  });
}
```

Añade `import 'dart:io';` al principio del segundo fichero de test.

- [ ] **Step 3: Correr los tests y confirmar el fallo exacto**

Run: `flutter test test/core/widgets/app_dialog_content_test.dart test/features/mechanic/presentation/pages/catalogo_servicios_responsive_test.dart`
Expected: **FAIL.** El primero por compilación (`AppDialogContent` no existe). El segundo: `AppGrid` no encontrado; `AppEmptyState` no encontrado; `boton.tooltip` es `null`; el test de fuente falla por `GoogleFonts.` (5 ocurrencias) y `size.width < 700`.

- [ ] **Step 4: Implementar**

```dart
// lib/core/widgets/app_dialog_content.dart
import 'package:flutter/material.dart';

import 'package:autodoc/core/theme/app_breakpoints.dart';

/// Contenido de un `AlertDialog` que ni desborda en teléfono ni se estira en
/// escritorio.
///
/// Sustituye al patrón `SizedBox(width: 380)` / `SizedBox(width: 420)`, que
/// desborda a 320 px (un `AlertDialog` reserva 40 px de `insetPadding` a cada
/// lado, así que el contenido dispone de 240).
///
/// Son dos capas y el orden importa: el `ConstrainedBox` acota por arriba y
/// el `SizedBox(width: double.maxFinite)` llena lo que quede por debajo. Solo
/// el `SizedBox` haría que el diálogo midiera 1.360 px en una ventana de
/// 1440; solo el `ConstrainedBox` dejaría el ancho al mínimo intrínseco de
/// los campos.
class AppDialogContent extends StatelessWidget {
  final Widget child;

  /// Por defecto la medida de formulario del design system.
  final double maxWidth;

  const AppDialogContent({
    super.key,
    required this.child,
    this.maxWidth = AppBreakpoints.maxFormWidth,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: SizedBox(width: double.maxFinite, child: child),
    );
  }
}
```

4a. En `_NuevoItemDialogState.build`, cambia `content: SizedBox(width: 380, child: Form(...))` por `content: AppDialogContent(child: Form(...))`.

4b. Sustituye todo el `build` de `_CatalogoServiciosScreenState` por `MechanicScaffold`, borrando `isMobile`, el `Row`, el `Drawer`, el `MechanicSidebar` y el `Container(height: 64)`:

```dart
@override
Widget build(BuildContext context) {
  return MechanicScaffold(
    title: 'Catálogo de Servicios',
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _mostrarDialogoAgregar(context),
      icon: const Icon(Icons.add),
      label: const Text('Nuevo Ítem'),
    ),
    body: Consumer<CatalogoProvider>(
      builder: (context, provider, _) {
        final items = provider.items;
        if (items.isEmpty) {
          return const AppEmptyState(
            title: 'Aún no tienes ítems en tu catálogo',
            description:
                'Agrega servicios y repuestos frecuentes para añadirlos '
                'con un clic al facturar.',
            icon: Icons.inventory_2_outlined,
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
          child: AppPageBody(
            child: AppGrid(
              compactColumns: 1,
              mediumColumns: 2,
              expandedColumns: 2,
              largeColumns: 3,
              spacing: AppSpacing.base,
              // Las columnas van de 288 px (compact a 320) a ~360 px (large
              // con maxContentWidth 1200 y 3 columnas). Con 3.4 la altura
              // queda entre 85 y 106 px, por encima de los 84 que necesita
              // un avatar de 40 más dos líneas de texto y el padding.
              childAspectRatio: 3.4,
              children: [
                for (final item in items) _CatalogoItemCard(item: item, onEliminar: _eliminar),
              ],
            ),
          ),
        );
      },
    ),
  );
}
```

4c. Extrae la tarjeta con el precio **debajo** del nombre (no al lado), que es lo que la hace sobrevivir a una columna de 288 px:

```dart
class _CatalogoItemCard extends StatelessWidget {
  final CatalogoItemModel item;
  final Future<void> Function(CatalogoItemModel) onEliminar;

  const _CatalogoItemCard({required this.item, required this.onEliminar});

  static final _currencyFormat = NumberFormat.currency(locale: 'es', symbol: '\$');

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: colors.primary.withValues(alpha: 0.15),
            child: Icon(Icons.build_outlined, color: colors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.nombre,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _currencyFormat.format(item.precio),
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: colors.error),
            tooltip: 'Eliminar ${item.nombre} del catálogo',
            onPressed: () => onEliminar(item),
          ),
        ],
      ),
    );
  }
}
```

Mueve `_currencyFormat` del `State` a la tarjeta (ahí es donde se usa) y borra el campo del `State`.

- [ ] **Step 5: Correr los tests y confirmar verde**

Run: `flutter test test/core/widgets/app_dialog_content_test.dart test/features/mechanic/presentation/pages/catalogo_servicios_responsive_test.dart`
Expected: **PASS (2 + 5 tests)**. Si el test de desbordamiento falla a algún ancho concreto, ajusta `childAspectRatio` en pasos de 0,2 — el test es la garantía, no el número.

- [ ] **Step 6: Comprobar el test preexistente**

Run: `flutter test test/features/mechanic/presentation/pages/catalogo_servicios_screen_test.dart`
Expected: PASS sin tocarlo. Sus dos casos abren el diálogo con el FAB y escriben en el campo `'Precio unitario'`; ni el FAB ni el `TextFormField` cambian de identidad.

- [ ] **Step 7: Verificar y commitear**

```bash
dart format . && flutter analyze && flutter test
git add lib/core/widgets/app_dialog_content.dart \
        lib/features/mechanic/presentation/pages/catalogo_servicios_screen.dart \
        test/core/widgets/app_dialog_content_test.dart \
        test/features/mechanic/presentation/pages/catalogo_servicios_responsive_test.dart
git commit -m "feat(mechanic): grid layout and fluid dialog for the service catalogue

El AlertDialog fijaba SizedBox(width: 380) y desbordaba a 320 px: un
AlertDialog reserva 40 px de inset a cada lado, asi que el contenido solo
tiene 240. AppDialogContent encapsula el patron de dos capas y lo reutilizan
las Tasks 5 y 6. La lista pasa a AppGrid 1/2/2/3: a 1440 px cada item era
una fila de 1100 px con un icono, un nombre y un precio."
```

---

### Task 5: `mechanic_service_history_screen` — el selector de fechas que ignora el dark mode

**Files:**
- Modify: `lib/features/mechanic/presentation/pages/mechanic_service_history_screen.dart`
- Test: `test/features/mechanic/presentation/pages/mechanic_service_history_responsive_test.dart`

**Interfaces:**
- Consumes: `MechanicScaffold` (Task 1); `AppDialogContent` (Task 4); `AppGrid`, `AppPageBody` (Fase 1); `AppCard`, `AppEmptyState`, `AppButton` (Fase 3); `AppSpacing`, `AppTextStyles`.
- Produces: `MechanicServiceHistoryScreen({FirebaseFirestore? firestore})` — parámetro opcional nuevo, por defecto `FirebaseFirestore.instance`. **Es aditivo y no rompe a `app_router.dart`.** Es el mismo mecanismo que la Fase 4 Task 9 introdujo en `ServiceHistoryScreen`, y sin él la pantalla no se puede montar en un widget test: el `StreamBuilder` toca `FirebaseFirestore.instance` en `build`.

**Problemas medidos:**

1. **`showDateRangePicker` fuerza `ColorScheme.light`** ([L121-133](../../../lib/features/mechanic/presentation/pages/mechanic_service_history_screen.dart#L121-L133)) con `onPrimary: Colors.white`. Con la app en oscuro el selector sale en claro: fondo blanco, texto oscuro, contra un `Scaffold` casi negro. Es el mismo defecto que la Fase 4 corrigió en dos pantallas del módulo dashboard.
2. `SizedBox(width: 380)` en el diálogo de detalle ([L237-238](../../../lib/features/mechanic/presentation/pages/mechanic_service_history_screen.dart#L237-L238)).
3. `Colors.grey.shade600` en `_detalleRow` ([L310](../../../lib/features/mechanic/presentation/pages/mechanic_service_history_screen.dart#L310)) — y `SizedBox(width: 110)` para la etiqueta, que a 320 px deja 130 px para el valor.
4. `Image.network(record.fotoFacturaUrl!)` ([L281](../../../lib/features/mechanic/presentation/pages/mechanic_service_history_screen.dart#L281)) sin `loadingBuilder`, sin `errorBuilder` y sin `semanticLabel`: si la URL falla, el diálogo muestra el icono roto por defecto de Flutter sin explicación.
5. Tres estados vacíos escritos a mano ([L170-177](../../../lib/features/mechanic/presentation/pages/mechanic_service_history_screen.dart#L170-L177), [L201-208](../../../lib/features/mechanic/presentation/pages/mechanic_service_history_screen.dart#L201-L208)) y uno de error.
6. `ListView.builder` de una columna siempre; `EdgeInsets.all(16.0)` y `EdgeInsets.symmetric(horizontal: 16)` literales conviviendo con `Responsive.padding(context, 32)`.

- [ ] **Step 1: Invocar las skills**

`Skill(ui-ux-pro-max:ui-ux-pro-max)` + `search.py "date range filter history list" --stack flutter`. Anota qué dice sobre filtros persistentes y sobre indicar que un filtro está activo.

- [ ] **Step 2: Escribir el test que falla**

```dart
// test/features/mechanic/presentation/pages/mechanic_service_history_responsive_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

import 'package:autodoc/core/widgets/app_empty_state.dart';
import 'package:autodoc/core/widgets/app_grid.dart';
import 'package:autodoc/features/mechanic/presentation/pages/mechanic_service_history_screen.dart';

import '../../../../support/mechanic_harness.dart';
import '../../../../support/responsive_harness.dart';

Future<FakeFirebaseFirestore> seedServicios({int count = 4}) async {
  final firestore = FakeFirebaseFirestore();
  for (var i = 0; i < count; i++) {
    await firestore.collection('servicios').doc('s$i').set({
      'id_taller': 't1',
      'tipo_servicio': 'Cambio de aceite $i',
      'fecha': DateTime(2026, 7, 10 + i),
      'kilometraje_servicio': 50000 + i,
      'costo': 45.0 + i,
    });
  }
  return firestore;
}

Future<void> pumpHistorial(
  WidgetTester tester, {
  required double width,
  required FakeFirebaseFirestore firestore,
  Brightness brightness = Brightness.light,
}) async {
  await pumpMechanicScreen(
    tester,
    MechanicServiceHistoryScreen(firestore: firestore),
    width: width,
    location: '/mechanic_service_history',
    brightness: brightness,
    disableAnimations: true,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('los servicios se distribuyen en rejilla en escritorio', (
    tester,
  ) async {
    final firestore = await seedServicios();
    await pumpHistorial(tester, width: 1440, firestore: firestore);

    expect(find.byType(AppGrid), findsOneWidget);
    final lefts = tester
        .widgetList<Text>(find.textContaining('Cambio de aceite'))
        .map((t) => tester.getTopLeft(find.text(t.data!)).dx)
        .toSet();
    expect(lefts.length, greaterThan(1));
  });

  testWidgets('sin servicios muestra AppEmptyState', (tester) async {
    final firestore = await seedServicios(count: 0);
    await pumpHistorial(tester, width: 375, firestore: firestore);

    expect(find.byType(AppEmptyState), findsOneWidget);
  });

  testWidgets('no desborda en ninguno de los anchos de auditoría', (
    tester,
  ) async {
    for (final width in kAuditWidths) {
      final firestore = await seedServicios();
      await pumpHistorial(tester, width: width, firestore: firestore);
      expectNoOverflow(tester);
    }
  });

  test('el selector de fechas no fuerza un ColorScheme claro', () {
    final source = File(
      'lib/features/mechanic/presentation/pages/'
      'mechanic_service_history_screen.dart',
    ).readAsStringSync();

    expect(
      source.contains('ColorScheme.light('),
      isFalse,
      reason: 'con la app en oscuro el selector salía en claro',
    );
    expect(source.contains('GoogleFonts.'), isFalse);
    expect(source.contains('Colors.grey'), isFalse);
    expect(source.contains('SizedBox(width: 380)'), isFalse);
    expect(source.contains('size.width < 700'), isFalse);
  });
}
```

- [ ] **Step 3: Correr el test y confirmar el fallo exacto**

Run: `flutter test test/features/mechanic/presentation/pages/mechanic_service_history_responsive_test.dart`
Expected: **FAIL, 4 de 4.** El primero por compilación: `MechanicServiceHistoryScreen` no acepta `firestore`. Tras añadir el parámetro, fallan `AppGrid`, `AppEmptyState` y las cinco aserciones de fuente.

- [ ] **Step 4: Implementar**

4a. Añade el parámetro inyectable y úsalo en el `StreamBuilder`:

```dart
class MechanicServiceHistoryScreen extends StatefulWidget {
  /// Inyectable **solo** para tests: el `StreamBuilder` de esta pantalla
  /// consulta Firestore directamente, así que sin esto no se puede montar
  /// en un widget test. En producción se deja sin pasar.
  final FirebaseFirestore? firestore;

  const MechanicServiceHistoryScreen({super.key, this.firestore});
  ...
}
```

y dentro del `State`: `FirebaseFirestore get _db => widget.firestore ?? FirebaseFirestore.instance;`, sustituyendo `FirebaseFirestore.instance` de [L150](../../../lib/features/mechanic/presentation/pages/mechanic_service_history_screen.dart#L150) por `_db`.

4b. **Elimina el `builder:` completo del `showDateRangePicker`** ([L121-133](../../../lib/features/mechanic/presentation/pages/mechanic_service_history_screen.dart#L121-L133)). `AppTheme` ya tematiza los selectores en ambos modos; el `Theme(...)` de aquí solo servía para romperlo:

```dart
onPressed: () async {
  final picked = await showDateRangePicker(
    context: context,
    firstDate: DateTime(2000),
    lastDate: DateTime.now(),
    initialDateRange: _dateRange,
  );
  if (picked != null) setState(() => _dateRange = picked);
},
```

4c. Cambia el shell por `MechanicScaffold(title: 'Mis Servicios', body: ...)` y borra `isMobile`, el `Row`, el `Drawer`, el `MechanicSidebar` y el `Container(height: 64)`.

4d. Sustituye los tres estados vacíos y el de error por `AppEmptyState`:

```dart
if (snapshot.hasError) {
  return const AppEmptyState(
    title: 'No se pudo cargar tu historial',
    description: 'Revisa tu conexión e inténtalo de nuevo.',
    icon: Icons.cloud_off_outlined,
  );
}
...
if (filteredRecords.isEmpty) {
  return AppEmptyState(
    title: _dateRange == null
        ? 'No has realizado ningún servicio aún'
        : 'No hay servicios en este rango de fechas',
    description: _dateRange == null
        ? 'Los servicios que registres desde "Buscar Vehículo" aparecerán aquí.'
        : 'Prueba a ampliar el rango o a quitar el filtro.',
    icon: Icons.receipt_long_outlined,
  );
}
```

4e. Cambia el `ListView.builder` por `AppPageBody` + `AppGrid(compactColumns: 1, mediumColumns: 1, expandedColumns: 2, largeColumns: 2, childAspectRatio: 2.8)` dentro de un `SingleChildScrollView`. Dos columnas como máximo: la tarjeta lleva tipo de servicio, precio, fecha, kilometraje y una descripción en cursiva, y a tres columnas la descripción se corta en la primera palabra.

4f. Arregla el diálogo de detalle: `content: AppDialogContent(child: SingleChildScrollView(...))`, y la imagen:

```dart
ClipRRect(
  borderRadius: BorderRadius.circular(AppRadius.sm),
  child: Image.network(
    record.fotoFacturaUrl!,
    semanticLabel: 'Factura del servicio',
    loadingBuilder: (context, child, progress) => progress == null
        ? child
        : const SizedBox(
            height: 160,
            child: Center(child: CircularProgressIndicator()),
          ),
    errorBuilder: (context, error, stack) => Padding(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Text(
        'No se pudo cargar la factura.',
        style: AppTextStyles.bodySmall.copyWith(
          color: context.appColors.textSecondary,
        ),
      ),
    ),
  ),
),
```

4g. `_detalleRow`: sustituye `Colors.grey.shade600` por `colors.textSecondary` y el `SizedBox(width: 110)` por un layout que apila en `compact`:

```dart
Widget _detalleRow(BuildContext context, String label, String value) {
  final colors = context.appColors;
  final apilado = AppBreakpoints.of(context).isCompact;
  final etiqueta = Text(
    label,
    style: AppTextStyles.labelMedium.copyWith(
      fontWeight: FontWeight.bold,
      color: colors.textSecondary,
    ),
  );
  final valor = Text(
    value,
    style: AppTextStyles.bodyMedium.copyWith(color: colors.textPrimary),
  );

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
    child: apilado
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [etiqueta, valor],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 110, child: etiqueta),
              Expanded(child: valor),
            ],
          ),
  );
}
```

4h. Tokeniza lo que queda: los 5 `GoogleFonts.inter` → `AppTextStyles.*`; `fontSize: 16`/`13` literales → los estilos del sistema; `EdgeInsets.all(16.0)` → `AppSpacing.base`. El botón de filtro pasa a `AppButton(type: AppButtonType.secondary, ...)` y, cuando `_dateRange != null`, el `IconButton` de limpiar recibe `tooltip: 'Quitar el filtro de fechas'`.

- [ ] **Step 5: Correr el test y confirmar verde**

Run: `flutter test test/features/mechanic/presentation/pages/mechanic_service_history_responsive_test.dart`
Expected: **PASS (4 tests)**.

- [ ] **Step 6: Verificar y commitear**

```bash
dart format . && flutter analyze && flutter test
git add lib/features/mechanic/presentation/pages/mechanic_service_history_screen.dart \
        test/features/mechanic/presentation/pages/mechanic_service_history_responsive_test.dart
git commit -m "fix(mechanic): stop forcing a light date picker in the service history

showDateRangePicker envolvia el selector en un Theme con ColorScheme.light y
onPrimary: Colors.white, asi que con la app en oscuro salia un panel blanco
sobre un Scaffold casi negro. El AlertDialog de detalle fijaba 380 px y
desbordaba a 320. La imagen de la factura no tenia loadingBuilder,
errorBuilder ni semanticLabel."
```

---

### Task 6: `empleados_screen` — rejilla, diálogo fluido y un `Switch` que no es un interruptor

**Files:**
- Modify: `lib/features/mechanic/presentation/pages/empleados_screen.dart`
- Test: `test/features/mechanic/presentation/pages/empleados_responsive_test.dart`

**Interfaces:**
- Consumes: `MechanicScaffold` (Task 1); `AppDialogContent` (Task 4); `AppGrid`, `AppPageBody` (Fase 1); `AppCard`, `AppEmptyState`, `AppTextField` (Fase 3); `AppSpacing`, `AppTextStyles`.
- Produces: nada público nuevo.

**Problemas medidos:**

1. `SizedBox(width: 420)` en el diálogo "Nuevo empleado" ([L104-105](../../../lib/features/mechanic/presentation/pages/empleados_screen.dart#L104-L105)).
2. **El `Switch` miente sobre lo que hace** ([L504-510](../../../lib/features/mechanic/presentation/pages/empleados_screen.dart#L504-L510)): `onChanged: empleado.activo ? (_) => _confirmarDesactivar(empleado) : null`. Un interruptor promete dos sentidos; este solo va en uno, y cuando está apagado queda deshabilitado para siempre. El usuario que lo apaga por error no puede deshacerlo desde aquí. Además dispara un diálogo de confirmación, que es comportamiento de botón, no de interruptor.
3. Lista de una sola columna; tarjeta con `Row > Expanded(Column de 4 textos) > Column(Switch + texto)`: a 320 px la columna de texto se queda en ~180 px y el correo se corta.
4. **Dos estados vacíos escritos a mano**: "Acceso restringido" ([L300-329](../../../lib/features/mechanic/presentation/pages/empleados_screen.dart#L300-L329)) y "Aún no tienes empleados" ([L391-424](../../../lib/features/mechanic/presentation/pages/empleados_screen.dart#L391-L424)). Y el `Scaffold` de acceso restringido **repite el shell entero** una segunda vez en el mismo fichero.
5. Cinco `TextFormField` crudos en el diálogo en vez de `AppTextField` (que desde la Fase 3 asocia la etiqueta al campo para el lector de pantalla).

- [ ] **Step 1: Invocar las skills**

`Skill(ui-ux-pro-max:ui-ux-pro-max)` + `search.py "destructive action confirmation list item" --stack flutter`. Anota qué control corresponde a una acción destructiva con confirmación y por qué un `Switch` no lo es.

- [ ] **Step 2: Escribir el test que falla**

```dart
// test/features/mechanic/presentation/pages/empleados_responsive_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:provider/provider.dart';

import 'package:autodoc/core/widgets/app_empty_state.dart';
import 'package:autodoc/core/widgets/app_grid.dart';
import 'package:autodoc/features/mechanic/data/repositories/empleado_repository.dart';
import 'package:autodoc/features/mechanic/presentation/pages/empleados_screen.dart';
import 'package:autodoc/features/mechanic/presentation/providers/empleado_provider.dart';

import '../../../../support/mechanic_harness.dart';
import '../../../../support/responsive_harness.dart';

Future<FakeFirebaseFirestore> seedEmpleados({int count = 4}) async {
  final firestore = FakeFirebaseFirestore();
  for (var i = 0; i < count; i++) {
    await firestore
        .collection('talleres')
        .doc('t1')
        .collection('empleados')
        .doc('e$i')
        .set({
          'id_taller_propietario': 't1',
          'nombre_completo': 'Empleado $i',
          'correo': 'empleado$i@taller.com',
          'rol': i.isEven ? 'Mecanico' : 'Recepcionista',
          'activo': true,
        });
  }
  return firestore;
}

Future<void> pumpEmpleados(
  WidgetTester tester, {
  required double width,
  required FakeFirebaseFirestore firestore,
  String? idTallerPropietario,
}) async {
  await pumpMechanicScreen(
    tester,
    const EmpleadosScreen(idTaller: 't1'),
    width: width,
    location: '/mechanic/empleados',
    disableAnimations: true,
    user: fakeTaller(idTallerPropietario: idTallerPropietario),
    extraProviders: [
      ChangeNotifierProvider(
        create: (_) =>
            EmpleadoProvider(repository: EmpleadoRepository(firestore: firestore)),
      ),
    ],
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('los empleados se distribuyen en rejilla en escritorio', (
    tester,
  ) async {
    final firestore = await seedEmpleados();
    await pumpEmpleados(tester, width: 1440, firestore: firestore);

    expect(find.byType(AppGrid), findsOneWidget);
    final lefts = tester
        .widgetList<Text>(find.textContaining('Empleado '))
        .map((t) => tester.getTopLeft(find.text(t.data!)).dx)
        .toSet();
    expect(lefts.length, greaterThan(1));
  });

  testWidgets('desactivar es un botón, no un Switch', (tester) async {
    final firestore = await seedEmpleados(count: 1);
    await pumpEmpleados(tester, width: 375, firestore: firestore);

    expect(
      find.byType(Switch),
      findsNothing,
      reason: 'un Switch promete dos sentidos; esta acción solo va en uno',
    );
    expect(find.widgetWithIcon(IconButton, Icons.person_off_outlined), findsOneWidget);
  });

  testWidgets('los dos estados vacíos usan AppEmptyState', (tester) async {
    final vacio = await seedEmpleados(count: 0);
    await pumpEmpleados(tester, width: 375, firestore: vacio);
    expect(find.byType(AppEmptyState), findsOneWidget);

    final conDatos = await seedEmpleados();
    await pumpEmpleados(
      tester,
      width: 375,
      firestore: conDatos,
      idTallerPropietario: 'otro-taller',
    );
    expect(find.byType(AppEmptyState), findsOneWidget);
    expect(find.text('Acceso restringido'), findsOneWidget);
  });

  testWidgets('no desborda en ninguno de los anchos de auditoría', (
    tester,
  ) async {
    for (final width in kAuditWidths) {
      final firestore = await seedEmpleados();
      await pumpEmpleados(tester, width: width, firestore: firestore);
      expectNoOverflow(tester);
    }
  });

  test('el fichero no repite el shell ni fija anchos de diálogo', () {
    final source = File(
      'lib/features/mechanic/presentation/pages/empleados_screen.dart',
    ).readAsStringSync();

    expect(source.contains('GoogleFonts.'), isFalse);
    expect(source.contains('size.width < 700'), isFalse);
    expect(source.contains('SizedBox(width: 420)'), isFalse);
    expect(
      'MechanicScaffold('.allMatches(source).length,
      1,
      reason: 'el shell se declara una vez, no dos',
    );
  });
}
```

- [ ] **Step 3: Correr el test y confirmar el fallo exacto**

Run: `flutter test test/features/mechanic/presentation/pages/empleados_responsive_test.dart`
Expected: **FAIL, 5 de 5**: no hay `AppGrid`, hay un `Switch`, no hay `AppEmptyState`, y el test de fuente falla por `GoogleFonts.`, `size.width < 700` y `SizedBox(width: 420)`.

- [ ] **Step 4: Implementar**

4a. Unifica los **dos** `Scaffold` en uno. El `build` queda con una sola llamada a `MechanicScaffold` y la rama de sub-cuenta solo cambia el `body` y quita el FAB:

```dart
@override
Widget build(BuildContext context) {
  final idTallerPropietario =
      context.watch<UserProfileProvider>().userData?.idTallerPropietario;
  final esSubCuentaEmpleado =
      idTallerPropietario != null && idTallerPropietario.isNotEmpty;

  return MechanicScaffold(
    title: 'Empleados',
    floatingActionButton: esSubCuentaEmpleado
        ? null
        : FloatingActionButton.extended(
            onPressed: () => _mostrarDialogoCrearEmpleado(context),
            icon: const Icon(Icons.person_add),
            label: const Text('Nuevo Empleado'),
          ),
    body: esSubCuentaEmpleado
        ? const AppEmptyState(
            title: 'Acceso restringido',
            description:
                'Solo el dueño del taller puede gestionar cuentas de empleados.',
            icon: Icons.lock_outline,
          )
        : Consumer<EmpleadoProvider>(
            builder: (context, provider, _) {
              final empleados = provider.empleados;
              if (empleados.isEmpty) {
                return const AppEmptyState(
                  title: 'Aún no tienes empleados',
                  description:
                      'Crea sub-cuentas para que tu personal pueda operar '
                      'el panel del taller.',
                  icon: Icons.badge_outlined,
                );
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: AppPageBody(
                  child: AppGrid(
                    compactColumns: 1,
                    mediumColumns: 2,
                    expandedColumns: 2,
                    largeColumns: 3,
                    spacing: AppSpacing.base,
                    childAspectRatio: 2.4,
                    children: [
                      for (final empleado in empleados)
                        _EmpleadoCard(
                          empleado: empleado,
                          onDesactivar: () => _confirmarDesactivar(empleado),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
  );
}
```

4b. Sustituye el `Switch` por un `IconButton` de acción destructiva más una etiqueta de estado legible:

```dart
class _EmpleadoCard extends StatelessWidget {
  final EmpleadoModel empleado;
  final VoidCallback onDesactivar;

  const _EmpleadoCard({required this.empleado, required this.onDesactivar});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final rol = empleado.rol == 'Recepcionista' ? 'Recepcionista' : 'Mecánico';

    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: colors.primary.withValues(alpha: 0.15),
            child: Icon(Icons.person, color: colors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  empleado.nombreCompleto,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  empleado.correo,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: colors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                // El estado se comunica con texto además de con color: a un
                // usuario con daltonismo el verde y el gris le llegan igual.
                _EstadoChip(activo: empleado.activo, rol: rol),
              ],
            ),
          ),
          if (empleado.activo)
            IconButton(
              icon: Icon(Icons.person_off_outlined, color: colors.error),
              tooltip: 'Desactivar a ${empleado.nombreCompleto}',
              onPressed: onDesactivar,
            ),
        ],
      ),
    );
  }
}
```

`_EstadoChip` es un `Container` con `AppRadius.full`, fondo `colors.success.withValues(alpha: 0.12)` o `colors.textSecondary.withValues(alpha: 0.12)`, y texto `'$rol · Activo'` / `'$rol · Inactivo'` con `AppTextStyles.labelSmall`.

4c. En el diálogo: `content: AppDialogContent(child: Form(...))` y los cinco `TextFormField` pasan a `AppTextField` con `label:`, `isRequired: true` donde corresponda y `helperText: 'Mínimo 6 caracteres'` en la contraseña (hoy ese requisito solo aparece **después** de fallar la validación).

4d. Borra los 5 `GoogleFonts.inter`, los `Responsive.fontSize` de la tarjeta y el `Responsive.iconSize(context, 56)` de los estados vacíos (`AppEmptyState` ya los resuelve).

- [ ] **Step 5: Correr el test y confirmar verde**

Run: `flutter test test/features/mechanic/presentation/pages/empleados_responsive_test.dart`
Expected: **PASS (5 tests)**.

- [ ] **Step 6: Comprobar el test preexistente**

Run: `flutter test test/features/mechanic/presentation/pages/empleados_screen_test.dart`
Expected: **FAIL en una aserción**, y es esperado: el test busca `find.text('Recepcionista')` y ahora el rol vive dentro del chip como `'Recepcionista · Activo'`. Actualiza esa aserción a `find.textContaining('Recepcionista')`. Las otras dos (`'Juan Pérez'`, `'juan@taller.com'`) siguen valiendo. Deja constancia en el commit: el cambio de texto es deliberado, no una regresión.

- [ ] **Step 7: Verificar y commitear**

```bash
dart format . && flutter analyze && flutter test
git add lib/features/mechanic/presentation/pages/empleados_screen.dart \
        test/features/mechanic/presentation/pages/empleados_screen_test.dart \
        test/features/mechanic/presentation/pages/empleados_responsive_test.dart
git commit -m "fix(mechanic): replace the one-way employee Switch with a real action

El Switch solo iba en un sentido (onChanged: activo ? ... : null): al
apagarlo quedaba deshabilitado para siempre y no habia forma de deshacerlo
desde la pantalla. Ademas abria un dialogo de confirmacion, que es
comportamiento de boton. Ahora es un IconButton con tooltip, y el estado se
lee como texto ademas de por color. El fichero tenia el shell entero escrito
dos veces (una para la rama de acceso restringido); ahora es uno."
```

---

### Task 7: `vehicle_search_screen` — el campo que casi no se ve y el botón que no hace nada

**Files:**
- Modify: `lib/features/mechanic/presentation/pages/vehicle_search_screen.dart`
- Test: `test/features/mechanic/presentation/pages/vehicle_search_responsive_test.dart`

**Interfaces:**
- Consumes: `MechanicScaffold` (Task 1); `AppPageBody`, `AppBreakpoints` (Fase 1); `AppCard`, `AppButton`, `AppEmptyState` (Fase 3); `AppSpacing`, `AppRadius`, `AppTextStyles`; `VehicleProvider` (existente, **no se toca**).
- Produces: nada público nuevo.

**Problemas medidos:**

1. **El `hintText` es prácticamente invisible.** `hintStyle: TextStyle(color: colors.primary.withValues(alpha: 0.2))` ([L262-265](../../../lib/features/mechanic/presentation/pages/vehicle_search_screen.dart#L262-L265)). Morado `#522C81` al 20 % sobre `surfaceContainer` da un contraste por debajo de 1,5:1, muy lejos del 4,5:1 que pide WCAG AA para texto. El propio ejemplo de formato de placa (`'Ej: ABC123'`) es lo que el usuario necesita leer.
2. **`TextButton(onPressed: () {})` — "SABER MÁS" no hace nada** ([L450-460](../../../lib/features/mechanic/presentation/pages/vehicle_search_screen.dart#L450-L460)). Es un control enfocable, anunciable y pulsable que no tiene destino.
3. **La campana de notificaciones no es un botón**: `Icon(Icons.notifications_none, color: colors.textSecondary)` suelto en la barra ([L181](../../../lib/features/mechanic/presentation/pages/vehicle_search_screen.dart#L181)). El dashboard sí usa `NotificationBellButton`; aquí es decoración que parece interactiva.
4. `Colors.white` en las iniciales del avatar ([L196](../../../lib/features/mechanic/presentation/pages/vehicle_search_screen.dart#L196)).
5. `GestureDetector` sobre el botón de QR ([L272-286](../../../lib/features/mechanic/presentation/pages/vehicle_search_screen.dart#L272-L286)): sin `Semantics`, sin feedback de pulsación y sin garantía de 48 dp (a `isMobile` mide 20 + 2×12 = 44 dp).
6. `isMobile ? 24 : 40`, `isMobile ? 18 : 22`, `isMobile ? 1 : 2`… 11 ternarios de escala repartidos por el fichero, y `maxWidth: isMobile ? double.infinity : 800` como sexta constante de anchura de contenido.
7. `_buildRecentItem(dynamic vehicle, ...)` — parámetro `dynamic`: se pierde el chequeo de tipos sobre `vehicle.placa`, `vehicle.marca`, `vehicle.anio`.

- [ ] **Step 1: Invocar las skills**

`Skill(ui-ux-pro-max:ui-ux-pro-max)` + `search.py "search input field prominent" --stack flutter`: anota el contraste mínimo del placeholder y el tamaño mínimo del control accesorio. `Skill(emil-design-eng)`: anota el feedback de pulsación del botón de QR.

- [ ] **Step 2: Escribir el test que falla**

```dart
// test/features/mechanic/presentation/pages/vehicle_search_responsive_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/features/mechanic/presentation/pages/vehicle_search_screen.dart';

import '../../../../support/contrast.dart';
import '../../../../support/mechanic_harness.dart';
import '../../../../support/responsive_harness.dart';

void main() {
  Future<void> pumpBusqueda(WidgetTester tester, double width) async {
    await pumpMechanicScreen(
      tester,
      const VehicleSearchScreen(),
      width: width,
      location: '/mechanic_search',
      disableAnimations: true,
    );
    await tester.pump();
  }

  testWidgets('el placeholder de la placa cumple el contraste de texto', (
    tester,
  ) async {
    await pumpBusqueda(tester, 375);

    final context = tester.element(find.byType(VehicleSearchScreen));
    final colors = context.appColors;
    final field = tester.widget<TextField>(find.byType(TextField).first);
    final hintColor = field.decoration!.hintStyle!.color!;

    expect(
      contrastRatio(hintColor, colors.surfaceContainer),
      greaterThanOrEqualTo(4.5),
      reason: 'el hint dice el formato de la placa: hay que poder leerlo',
    );
  });

  testWidgets('el botón de QR mide al menos 48 dp y se anuncia', (
    tester,
  ) async {
    await pumpBusqueda(tester, 375);

    final boton = find.bySemanticsLabel(RegExp('QR'));
    expect(boton, findsOneWidget);
    final size = tester.getSize(boton.first);
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('no desborda en ninguno de los anchos de auditoría', (
    tester,
  ) async {
    for (final width in kAuditWidths) {
      await pumpBusqueda(tester, width);
      expectNoOverflow(tester);
    }
  });

  test('no quedan controles muertos ni colores literales', () {
    final source = File(
      'lib/features/mechanic/presentation/pages/vehicle_search_screen.dart',
    ).readAsStringSync();

    expect(
      source.contains('onPressed: () {}'),
      isFalse,
      reason: '"SABER MÁS" era un botón enfocable sin destino',
    );
    expect(source.contains('Colors.white'), isFalse);
    expect(source.contains('GoogleFonts.'), isFalse);
    expect(source.contains('size.width < 700'), isFalse);
    expect(
      source.contains('dynamic vehicle'),
      isFalse,
      reason: 'el parámetro dynamic desactivaba el chequeo de tipos',
    );
  });
}
```

- [ ] **Step 3: Correr el test y confirmar el fallo exacto**

Run: `flutter test test/features/mechanic/presentation/pages/vehicle_search_responsive_test.dart`
Expected: **FAIL, 4 de 4.** El primero da un ratio en torno a **1,4:1**. El segundo no encuentra ningún nodo semántico con "QR". El cuarto falla en las cinco aserciones.

- [ ] **Step 4: Implementar**

4a. Shell: `MechanicScaffold(title: 'Buscar Vehículo', actions: [const NotificationBellButton(), ...], body: ...)`. Con esto desaparecen `_buildTopBar`, el `Icon` decorativo de campana, el avatar con `Colors.white` (el sidebar ya identifica la cuenta) y los 11 ternarios de `isMobile`, que pasan a resolverse por `WindowClass` en un solo sitio.

4b. Contenido:

```dart
body: SingleChildScrollView(
  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
  child: AppPageBody(
    maxWidth: AppBreakpoints.maxReadingWidth,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SearchCard(
          controller: _searchController,
          isSearching: _isSearching,
          onSearch: _handleSearch,
          onScan: _scanQR,
        ),
        const SizedBox(height: AppSpacing.xl),
        _RecentSearches(onSelect: _abrirVehiculo),
      ],
    ),
  ),
),
```

4c. En `_SearchCard`, el `hintStyle` pasa a `AppTextStyles.bodyLarge.copyWith(color: colors.textSecondary)` — el token secundario que la Fase 1 Task 4 ya subió a 5,05:1 sobre `surface`. Y el botón de QR deja de ser un `GestureDetector`:

```dart
Semantics(
  button: true,
  label: 'Escanear código QR de la placa',
  child: IconButton(
    onPressed: onScan,
    // 48 dp garantizados por el tamaño mínimo de IconButton en Material 3;
    // el GestureDetector anterior medía 44 en teléfono.
    icon: Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.secondary,
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.qr_code_scanner, color: colors.primary, size: 20),
    ),
  ),
),
```

4d. **Borra la tarjeta "Asistente de Servicio"** completa ([L409-465](../../../lib/features/mechanic/presentation/pages/vehicle_search_screen.dart#L409-L465)) o cablea su botón. El texto que muestra ("Escanee el VIN en el marco de la puerta del conductor") describe una funcionalidad que **no existe**: el escáner de esta pantalla lee la placa, no el VIN, y "SABER MÁS" no lleva a ninguna parte.

> **Bloqueo a consultar antes de ejecutar este paso.** Borrar contenido visible es una decisión de producto, no de diseño. Pregunta en el PR: *(a)* borrar la tarjeta, *(b)* dejarla y cablear "SABER MÁS" a una ruta de ayuda que habría que crear, o *(c)* dejar el texto y quitar solo el botón muerto. **Si no hay respuesta, aplica (c)**: es la opción reversible y la que no borra información. El test solo exige que no quede `onPressed: () {}`.

4e. Estado vacío de búsquedas recientes → `AppEmptyState(title: 'No hay búsquedas recientes', description: 'Los vehículos que busques aparecerán aquí para volver a abrirlos con un toque.', icon: Icons.history)`.

4f. Tipa el parámetro: `Widget _buildRecentItem(VehicleModel vehicle, ...)` e importa `vehicle_model.dart`. Si `VehicleProvider.recentSearches` no está tipado como `List<VehicleModel>`, **para y documenta el bloqueo** — tiparlo sería tocar `providers/`, prohibido por §2 del maestro; en ese caso deja el `dynamic` y quita esa aserción del test con un comentario que explique por qué.

- [ ] **Step 5: Correr el test y confirmar verde**

Run: `flutter test test/features/mechanic/presentation/pages/vehicle_search_responsive_test.dart`
Expected: **PASS (4 tests)**.

- [ ] **Step 6: Verificar y commitear**

```bash
dart format . && flutter analyze && flutter test
git add lib/features/mechanic/presentation/pages/vehicle_search_screen.dart \
        test/features/mechanic/presentation/pages/vehicle_search_responsive_test.dart
git commit -m "fix(mechanic): make the plate search field readable and operable

El hintText estaba a colors.primary con alpha 0.2: alrededor de 1.4:1 de
contraste, cuando ese hint es justo el que ensena el formato de placa que hay
que escribir. El boton de QR era un GestureDetector de 44 dp sin semantica.
La campana de la barra era un Icon decorativo que parecia pulsable. Y habia
un TextButton con onPressed vacio, enfocable y anunciable, sin destino."
```

---

### Task 8: `mechanic_reviews_screen` — estrellas que el lector de pantalla no ve

**Files:**
- Modify: `lib/features/mechanic/presentation/pages/mechanic_reviews_screen.dart`
- Test: `test/features/mechanic/presentation/pages/mechanic_reviews_responsive_test.dart`

**Interfaces:**
- Consumes: `MechanicScaffold` (Task 1); `AppGrid`, `AppPageBody` (Fase 1); `AppCard`, `AppEmptyState` (Fase 3); `AppSectionHeader` (Fase 4 Task 2); `AppSpacing`, `AppRadius`, `AppTextStyles`; `ReviewService`, `ordenarResenias` (existentes).
- Produces: `MechanicReviewsScreen({FirebaseFirestore? firestore})` — aditivo. `ReviewService` ya acepta `firestore` en su constructor ([review_service.dart:32-33](../../../lib/features/reviews/data/services/review_service.dart#L32-L33)), así que un solo parámetro cubre el `StreamBuilder` directo **y** el servicio.

**Problemas medidos:**

1. **Las estrellas son solo dibujo.** `List.generate(5, (i) => Icon(Icons.star, color: i < r.estrellas ? warning : gris))` ([L289-308](../../../lib/features/mechanic/presentation/pages/mechanic_reviews_screen.dart#L289-L308)). Un lector de pantalla anuncia cinco iconos sin etiqueta; la calificación, que es el dato principal de la pantalla, no se transmite.
2. **`Colors.red`** en la acción "Reportar" ([L375](../../../lib/features/mechanic/presentation/pages/mechanic_reviews_screen.dart#L375)) — el único literal del fichero, y precisamente en un botón destructivo que tiene token (`colors.error`).
3. **`itemBuilder` de 290 líneas** ([L272-563](../../../lib/features/mechanic/presentation/pages/mechanic_reviews_screen.dart#L272-L563)) con el diálogo de reportar anidado dentro. `ui-ux-pro-max` marca el anidamiento profundo como problema de mantenimiento y de rendimiento de rebuild.
4. `SizedBox(width: 30)` para el contador de la distribución ([L689-699](../../../lib/features/mechanic/presentation/pages/mechanic_reviews_screen.dart#L689-L699)): con 100 reseñas o más el número se corta.
5. Las barras de distribución (`LinearProgressIndicator`) no tienen etiqueta semántica: la proporción se comunica solo por longitud y color.
6. `IconButton` de bandera sin `tooltip`; lista de una columna siempre; `EdgeInsets.fromLTRB(24, 0, 24, 24)` y `EdgeInsets.symmetric(horizontal: 24)` literales conviviendo con `Responsive.padding(context, 24)`.

- [ ] **Step 1: Invocar las skills**

`Skill(ui-ux-pro-max:ui-ux-pro-max)` + `search.py "rating stars accessible review list" --stack flutter`. Anota cómo se anuncia una calificación de 5 estrellas y cómo se etiqueta una barra de distribución.

- [ ] **Step 2: Escribir el test que falla**

```dart
// test/features/mechanic/presentation/pages/mechanic_reviews_responsive_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

import 'package:autodoc/core/widgets/app_empty_state.dart';
import 'package:autodoc/core/widgets/app_grid.dart';
import 'package:autodoc/features/mechanic/presentation/pages/mechanic_reviews_screen.dart';

import '../../../../support/mechanic_harness.dart';
import '../../../../support/responsive_harness.dart';

Future<FakeFirebaseFirestore> seedResenias({int count = 4}) async {
  final firestore = FakeFirebaseFirestore();
  await firestore.collection('usuarios').doc('t1').set({
    'calificacion_promedio': 4.5,
    'total_resenias': count,
  });
  for (var i = 0; i < count; i++) {
    await firestore.collection('resenias').doc('r$i').set({
      'id_taller': 't1',
      'id_usuario': 'u$i',
      'estrellas': 5 - (i % 5),
      'comentario': 'Muy buen servicio $i',
      'fecha_resenia': DateTime(2026, 7, 1 + i),
      'fotos': <String>[],
    });
  }
  return firestore;
}

Future<void> pumpResenias(
  WidgetTester tester, {
  required double width,
  required FakeFirebaseFirestore firestore,
}) async {
  await pumpMechanicScreen(
    tester,
    MechanicReviewsScreen(firestore: firestore),
    width: width,
    location: '/mechanic_reviews',
    disableAnimations: true,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('cada reseña anuncia su calificación', (tester) async {
    final firestore = await seedResenias(count: 1);
    await pumpResenias(tester, width: 375, firestore: firestore);

    expect(
      find.bySemanticsLabel(RegExp(r'5 de 5 estrellas')),
      findsOneWidget,
      reason: 'la calificación es el dato principal y solo se dibujaba',
    );
  });

  testWidgets('las reseñas se distribuyen en rejilla en escritorio', (
    tester,
  ) async {
    final firestore = await seedResenias();
    await pumpResenias(tester, width: 1440, firestore: firestore);

    expect(find.byType(AppGrid), findsOneWidget);
  });

  testWidgets('sin reseñas muestra AppEmptyState', (tester) async {
    final firestore = await seedResenias(count: 0);
    await pumpResenias(tester, width: 375, firestore: firestore);

    expect(find.byType(AppEmptyState), findsOneWidget);
  });

  testWidgets('no desborda en ninguno de los anchos de auditoría', (
    tester,
  ) async {
    for (final width in kAuditWidths) {
      final firestore = await seedResenias();
      await pumpResenias(tester, width: width, firestore: firestore);
      expectNoOverflow(tester);
    }
  });

  test('el fichero está tokenizado y la tarjeta está extraída', () {
    final source = File(
      'lib/features/mechanic/presentation/pages/mechanic_reviews_screen.dart',
    ).readAsStringSync();

    expect(source.contains('Colors.red'), isFalse);
    expect(source.contains('GoogleFonts.'), isFalse);
    expect(source.contains('size.width < 700'), isFalse);
    expect(source.contains('SizedBox(width: 30)'), isFalse);
    expect(
      source.contains('class _ReviewCard'),
      isTrue,
      reason: 'el itemBuilder de 290 líneas se extrae a su propio widget',
    );
  });
}
```

- [ ] **Step 3: Correr el test y confirmar el fallo exacto**

Run: `flutter test test/features/mechanic/presentation/pages/mechanic_reviews_responsive_test.dart`
Expected: **FAIL, 5 de 5.** El primero por compilación (`MechanicReviewsScreen` no acepta `firestore`); tras añadirlo, no hay ningún nodo semántico con "5 de 5 estrellas", no hay `AppGrid` ni `AppEmptyState`, y el test de fuente falla en las cinco aserciones.

- [ ] **Step 4: Implementar**

4a. Parámetro inyectable: `final FirebaseFirestore? firestore;`, `FirebaseFirestore get _db => widget.firestore ?? FirebaseFirestore.instance;`, y `ReviewService(firestore: widget.firestore)` en vez de `ReviewService()`. Construye el servicio **una vez** en `initState` en un campo del `State`, no en cada `build` como hoy ([L39](../../../lib/features/mechanic/presentation/pages/mechanic_reviews_screen.dart#L39)).

4b. Shell: `MechanicScaffold(title: 'Mis Reseñas', body: ...)`.

4c. Extrae el `itemBuilder` a `class _ReviewCard extends StatelessWidget` y el diálogo de reportar a un método del `State`. La tarjeta empieza por la calificación anunciable:

```dart
/// Cinco estrellas con una única etiqueta semántica.
///
/// Antes eran cinco `Icon` sueltos: el lector de pantalla anunciaba cinco
/// iconos sin nombre y la calificación no llegaba.
class _Estrellas extends StatelessWidget {
  final int estrellas;

  const _Estrellas({required this.estrellas});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Semantics(
      label: '$estrellas de 5 estrellas',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 5; i++)
              Icon(
                i < estrellas ? Icons.star : Icons.star_border,
                size: 16,
                color: i < estrellas
                    ? colors.warning
                    : colors.textSecondary.withValues(alpha: 0.4),
              ),
          ],
        ),
      ),
    );
  }
}
```

Fíjate en el segundo cambio: la estrella vacía pasa de `Icons.star` con opacidad 0,2 a **`Icons.star_border`**. Con opacidad 0,2 el contraste contra el fondo era ~1,2:1 y, en una captura o en pantalla al sol, cinco estrellas llenas y tres llenas se veían igual. La forma distingue donde el color no llega.

4d. `Colors.red` → `colors.error` en la acción del diálogo de reportar, y el `IconButton` de bandera recibe `tooltip: 'Reportar esta reseña'`.

4e. Lista → `AppPageBody` + `AppGrid(compactColumns: 1, mediumColumns: 1, expandedColumns: 2, largeColumns: 2, childAspectRatio: 1.9)`. Dos columnas como techo: la tarjeta puede llevar comentario largo, fotos y respuesta del taller.

4f. Distribución: sustituye `SizedBox(width: 30)` por `ConstrainedBox(constraints: BoxConstraints(minWidth: 32))` y envuelve cada fila en `Semantics`:

```dart
Semantics(
  label: '$i estrellas: ${counts[i]} de $total reseñas',
  child: ExcludeSemantics(child: Row(...)),
)
```

4g. Estado vacío → `AppEmptyState`. Gutters: sustituye `EdgeInsets.fromLTRB(24, 0, 24, 24)`, `EdgeInsets.symmetric(horizontal: 24)` y los `Responsive.padding(context, 24)` por el gutter de `AppPageBody`. El `DropdownButton` de orden pasa a `AppSectionHeader(title: 'Reseñas', trailing: DropdownButton(...))`.

- [ ] **Step 5: Correr el test y confirmar verde**

Run: `flutter test test/features/mechanic/presentation/pages/mechanic_reviews_responsive_test.dart`
Expected: **PASS (5 tests)**.

- [ ] **Step 6: Verificar y commitear**

```bash
dart format . && flutter analyze && flutter test
git add lib/features/mechanic/presentation/pages/mechanic_reviews_screen.dart \
        test/features/mechanic/presentation/pages/mechanic_reviews_responsive_test.dart
git commit -m "fix(mechanic): announce review ratings and split the 290-line itemBuilder

Las cinco estrellas eran Icon sueltos sin etiqueta: un lector de pantalla
anunciaba cinco iconos sin nombre y la calificacion, que es el dato principal
de la pantalla, no llegaba. La estrella vacia pasa de star con alpha 0.2
(~1.2:1) a star_border, para que la forma distinga donde el color no llega.
El itemBuilder de 290 lineas, con el dialogo de reportar anidado dentro, sale
a _ReviewCard."
```

---

### Task 9: `mechanic_dashboard_screen` — el `LayoutBuilder` que nunca produjo tres columnas

**Files:**
- Modify: `lib/features/mechanic/presentation/pages/mechanic_dashboard_screen.dart`
- Test: `test/features/mechanic/presentation/pages/mechanic_dashboard_responsive_test.dart`

**Interfaces:**
- Consumes: `MechanicScaffold` (Task 1); `AppGrid`, `AppPageBody`, `AppBreakpoints`, `WindowClassX` (Fase 1); `AppCard`, `AppButton` (Fase 3); `AppSectionHeader` (Fase 4 Task 2); `AppSpacing`, `AppRadius`, `AppTextStyles`; `NotificationBellButton` (existente); `contrastRatio` (Fase 1 Task 4).
- Produces: `MechanicDashboardScreen({FirebaseFirestore? firestore})` — aditivo, mismo motivo que en las Tasks 5 y 8 (tres `StreamBuilder` tocan `FirebaseFirestore.instance` en `build`).

**Problemas medidos:**

1. **El `LayoutBuilder` está roto.** El maestro lo señalaba como "referencia de lo que ya funciona". No funciona. En [L384-448](../../../lib/features/mechanic/presentation/pages/mechanic_dashboard_screen.dart#L384-L448):

   ```dart
   final double cardWidth = isMobile ? constraints.maxWidth : (constraints.maxWidth - 48) / 3;
   ...
   Wrap(spacing: 24, runSpacing: 24, children: [ _buildMetricCard(..., width: cardWidth), ... ])
   ```

   Pero `_buildMetricCard` devuelve `AppCard(padding: Responsive.padding(context, 24), child: SizedBox(width: cardWidth, ...))`: el `SizedBox` va **dentro** del padding de la tarjeta. Con la ventana a 1440 px, `constraints.maxWidth` es 1000 (el `Container(maxWidth: 1000)` de [L112-113](../../../lib/features/mechanic/presentation/pages/mechanic_dashboard_screen.dart#L112-L113)), así que `cardWidth = (1000 − 48) / 3 = 317,33`. El ancho **externo** de cada tarjeta es 317,33 + 2×27,6 de padding (`scaleFactor` 1,15 a 1400 px) + 2 de borde = **374,53**. Tres tarjetas más dos separaciones de 24 suman **1.171,6 > 1.000**. Nunca caben tres. El tablero calcula una rejilla de 3 y dibuja una de 2, con ~227 px muertos a la derecha de cada fila.

2. **Texto blanco sobre teal en dark: 1,47:1.** La tarjeta "Atención Rápida" tiene un degradado de `colors.primary` y encima `Text(..., color: Colors.white)` ([L298](../../../lib/features/mechanic/presentation/pages/mechanic_dashboard_screen.dart#L298)). En modo oscuro `primary` es el teal `#81E6D9` (luminancia relativa 0,663), así que el contraste contra blanco es **(1,05)/(0,713) = 1,47:1** — el mínimo para texto de cuerpo es 4,5:1. En claro el mismo código da 10,3:1 y pasa: **el defecto existe solo en dark**, que es exactamente lo que ocurre cuando se infiere un tema desde el otro. Los otros dos `Colors.white` son el avatar de la barra ([L224](../../../lib/features/mechanic/presentation/pages/mechanic_dashboard_screen.dart#L224)) y el icono del `AppButton` ([L312](../../../lib/features/mechanic/presentation/pages/mechanic_dashboard_screen.dart#L312)).

3. **Los conmutadores de tema e idioma están escritos dos veces**, idénticos: en el `AppBar` de teléfono ([L58-96](../../../lib/features/mechanic/presentation/pages/mechanic_dashboard_screen.dart#L58-L96)) y en la barra de escritorio ([L177-216](../../../lib/features/mechanic/presentation/pages/mechanic_dashboard_screen.dart#L177-L216)), con distinto color cada uno.

4. `TextButton('EN'/'ES')` sin `tooltip` ni `Semantics`: se anuncia como "ES", que no dice que sea un conmutador de idioma.

5. **La gráfica no tiene alternativa accesible.** `fl_chart` pinta en canvas: para un lector de pantalla la sección "Tendencia de Ingresos" está vacía. Y `SizedBox(height: 250)` fijo en las cuatro clases de ventana.

6. `_buildServiceTile` es un `Container` crudo ([L785-841](../../../lib/features/mechanic/presentation/pages/mechanic_dashboard_screen.dart#L785-L841)) sin `onTap` ni feedback, aunque la tarjeta "Total Servicios" sí navega al historial: el usuario aprende que las filas de servicio son pulsables y aquí no lo son.

7. `maxWidth: isMobile ? double.infinity : 1000` — séptima constante de anchura de contenido del repo.

**Contrato (corrige el «1/2/4» del maestro):** `AppGrid(compactColumns: 1, mediumColumns: 2, expandedColumns: 3, largeColumns: 3)`. Son **6** KPIs: con 4 columnas quedan dos huérfanos en la segunda fila; con 3 quedan dos filas llenas.

- [ ] **Step 1: Invocar las skills**

`Skill(ui-ux-pro-max:ui-ux-pro-max)` + `search.py "dashboard kpi cards chart" --stack flutter`: anota el número de columnas por breakpoint y qué exige su sección de *Charts* sobre alternativas textuales. `Skill(emil-design-eng)`: decide si los KPIs deben entrar escalonados o no (son datos, no una lista navegable).

- [ ] **Step 2: Escribir el test que falla**

```dart
// test/features/mechanic/presentation/pages/mechanic_dashboard_responsive_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/widgets/app_grid.dart';
import 'package:autodoc/features/mechanic/presentation/pages/mechanic_dashboard_screen.dart';

import '../../../../support/contrast.dart';
import '../../../../support/mechanic_harness.dart';
import '../../../../support/responsive_harness.dart';

Future<FakeFirebaseFirestore> seedTaller() async {
  final firestore = FakeFirebaseFirestore();
  await firestore.collection('usuarios').doc('t1').set({
    'calificacion_promedio': 4.5,
    'total_resenias': 12,
  });
  for (var i = 0; i < 3; i++) {
    await firestore.collection('servicios').doc('s$i').set({
      'id_taller': 't1',
      'id_vehiculo': 'v$i',
      'tipo_servicio': 'Servicio $i',
      'fecha': DateTime(2026, 8, 1 + i),
      'costo': 100.0 + i,
    });
  }
  return firestore;
}

Future<void> pumpDashboard(
  WidgetTester tester, {
  required double width,
  required FakeFirebaseFirestore firestore,
  Brightness brightness = Brightness.light,
}) async {
  await pumpMechanicScreen(
    tester,
    MechanicDashboardScreen(firestore: firestore),
    width: width,
    location: '/mechanic_dashboard',
    brightness: brightness,
    disableAnimations: true,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('los 6 KPIs salen en 3 columnas a 1440 px', (tester) async {
    final firestore = await seedTaller();
    await pumpDashboard(tester, width: 1440, firestore: firestore);

    expect(find.byType(AppGrid), findsOneWidget);

    final lefts = <double>{};
    for (final titulo in [
      'Ingresos (Mes)',
      'Servicios (Mes)',
      'Total Servicios',
      'Vehículos Atendidos',
      'Calificación',
      'Reseñas',
    ]) {
      lefts.add(tester.getTopLeft(find.text(titulo)).dx);
    }
    expect(
      lefts.length,
      3,
      reason: 'el Wrap + SizedBox anterior solo llegaba a 2 columnas: la '
          'tarjeta medía cardWidth + 55 px de padding que el cálculo ignoraba',
    );
  });

  testWidgets('el texto de "Atención Rápida" es legible en dark', (
    tester,
  ) async {
    final firestore = await seedTaller();
    await pumpDashboard(
      tester,
      width: 375,
      firestore: firestore,
      brightness: Brightness.dark,
    );

    final context = tester.element(find.byType(MechanicDashboardScreen));
    final colors = context.appColors;
    final texto = tester.widget<Text>(
      find.text('Inicia un nuevo servicio buscando la placa del vehículo.'),
    );

    expect(
      contrastRatio(texto.style!.color!, colors.primary),
      greaterThanOrEqualTo(4.5),
      reason: 'Colors.white sobre el teal de dark daba 1,47:1',
    );
  });

  testWidgets('la gráfica de ingresos tiene alternativa textual', (
    tester,
  ) async {
    final firestore = await seedTaller();
    await pumpDashboard(tester, width: 1024, firestore: firestore);

    expect(
      find.bySemanticsLabel(RegExp('Tendencia de ingresos')),
      findsOneWidget,
      reason: 'fl_chart pinta en canvas: sin Semantics la sección está vacía '
          'para un lector de pantalla',
    );
  });

  testWidgets('no desborda en ninguno de los anchos de auditoría', (
    tester,
  ) async {
    for (final width in kAuditWidths) {
      final firestore = await seedTaller();
      await pumpDashboard(tester, width: width, firestore: firestore);
      expectNoOverflow(tester);
    }
  });

  test('el fichero está tokenizado y no duplica la barra de acciones', () {
    final source = File(
      'lib/features/mechanic/presentation/pages/mechanic_dashboard_screen.dart',
    ).readAsStringSync();

    expect(source.contains('Colors.white'), isFalse);
    expect(source.contains('GoogleFonts.'), isFalse);
    expect(source.contains('size.width < 700'), isFalse);
    expect(
      'Consumer2<ThemeProvider, LanguageProvider>'.allMatches(source).length,
      1,
      reason: 'los conmutadores de tema e idioma estaban escritos dos veces',
    );
  });
}
```

- [ ] **Step 3: Correr el test y confirmar el fallo exacto**

Run: `flutter test test/features/mechanic/presentation/pages/mechanic_dashboard_responsive_test.dart`
Expected: **FAIL, 5 de 5.** El primero por compilación (falta `firestore`); tras añadirlo, `lefts.length` da **2**, no 3 — la prueba numérica del bug. El segundo da ~**1,47**. El tercero no encuentra el nodo semántico. El quinto falla en las cuatro aserciones.

- [ ] **Step 4: Implementar**

4a. Parámetro inyectable (`FirebaseFirestore get _db => widget.firestore ?? FirebaseFirestore.instance;`) y sustitución de los tres `FirebaseFirestore.instance`.

4b. Shell y acciones **una sola vez**:

```dart
return MechanicScaffold(
  title: 'Dashboard',
  actions: const [_TemaIdiomaActions(), SizedBox(width: AppSpacing.base), NotificationBellButton()],
  body: ...,
);
```

con el bloque duplicado extraído tal cual:

```dart
/// Conmutadores de tema e idioma. Estaban escritos dos veces —una en el
/// `AppBar` de teléfono y otra en la barra de escritorio— con distinto color
/// cada uno. `MechanicScaffold` los pinta en la barra que corresponda.
class _TemaIdiomaActions extends StatelessWidget {
  const _TemaIdiomaActions();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Consumer2<ThemeProvider, LanguageProvider>(
      builder: (context, themeProvider, languageProvider, _) {
        final isDark = themeProvider.themeMode == ThemeMode.dark;
        final isEnglish = languageProvider.currentLocale.languageCode == 'en';

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: isDark ? 'Cambiar a modo claro' : 'Cambiar a modo oscuro',
              icon: Icon(
                isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                color: colors.primary,
              ),
              onPressed: () => themeProvider.setThemeMode(
                isDark ? ThemeMode.light : ThemeMode.dark,
              ),
            ),
            IconButton(
              tooltip: isEnglish ? 'Cambiar a español' : 'Switch to English',
              onPressed: () =>
                  languageProvider.changeLanguage(isEnglish ? 'es' : 'en'),
              icon: Text(
                isEnglish ? 'EN' : 'ES',
                style: AppTextStyles.labelLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.primary,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
```

4c. **La rejilla de KPIs.** Borra el `LayoutBuilder`, el `Wrap` y el parámetro `width` de `_buildMetricCard` — el `SizedBox(width: width)` interno era la causa del descuadre. `AppGrid` decide las columnas por `constraints.maxWidth` y la tarjeta se limita a llenar su celda:

```dart
AppGrid(
  compactColumns: 1,
  mediumColumns: 2,
  expandedColumns: 3,
  largeColumns: 3,
  spacing: AppSpacing.xl,
  // Columnas de ~276 px (medium) a ~373 px (large con maxContentWidth
  // 1200). La tarjeta necesita ~110 px de alto: caja de icono de 64 más
  // padding. 2.6 deja entre 106 y 143.
  childAspectRatio: 2.6,
  children: [ _MetricCard(...), ... ],
)
```

4d. Contraste: en la tarjeta "Atención Rápida", `Colors.white` → `colors.onPrimary`; el `icon:` del `AppButton` pierde su `color:` explícito (el botón ya fija el foreground). En la barra desaparece el avatar con `Colors.white` — el sidebar ya identifica la cuenta.

> **Si el test de contraste sigue fallando en dark tras el cambio, párate.** Significaría que `AppPalette.darkOnPrimary` no contrasta con `darkPrimary`, y entonces el defecto está en la paleta, no en esta pantalla. Repórtalo en el PR en vez de compensarlo aquí con un color local: §2 del maestro prohíbe tocar `AppPalette` fuera de la excepción ya justificada en la Fase 1.

4e. Gráfica: altura por clase de ventana y alternativa textual.

```dart
Semantics(
  label:
      'Tendencia de ingresos de los últimos 6 meses. '
      '${_resumenTextual(ingresosPorMes)}',
  child: ExcludeSemantics(
    child: SizedBox(
      height: AppBreakpoints.of(context).isCompact ? 200 : 280,
      child: LineChart(...),
    ),
  ),
),
```

donde `_resumenTextual` devuelve algo como `'Julio 1.240 dólares, agosto 980 dólares…'` recorriendo el mapa que la pantalla ya calcula. Es la alternativa mínima: sin ella la sección no existe para un lector de pantalla.

4f. `_buildServiceTile` → `AppCard(margin: EdgeInsets.zero, onTap: () => context.push('/mechanic_service_history'), ...)`, que con la Fase 3 ya trae press y hover.

4g. Tokeniza el resto: los 15 `GoogleFonts.inter` → `AppTextStyles.*`; `BorderRadius.circular(24/16/12)` → `AppRadius.*`; `SizedBox(height: 24/32)` → `AppSpacing.*`; los títulos de sección ("Tendencia de Ingresos", "Servicios Recientes") → `AppSectionHeader`; `maxWidth: isMobile ? double.infinity : 1000` → `AppPageBody()` con su `maxContentWidth` por defecto.

- [ ] **Step 5: Correr el test y confirmar verde**

Run: `flutter test test/features/mechanic/presentation/pages/mechanic_dashboard_responsive_test.dart`
Expected: **PASS (5 tests)**.

- [ ] **Step 6: Verificar y commitear**

```bash
dart format . && flutter analyze && flutter test
git add lib/features/mechanic/presentation/pages/mechanic_dashboard_screen.dart \
        test/features/mechanic/presentation/pages/mechanic_dashboard_responsive_test.dart
git commit -m "fix(mechanic): the KPI grid never produced the 3 columns it computed

cardWidth salia (maxWidth - 48) / 3, pero el SizedBox iba DENTRO del padding
de AppCard: el ancho externo real era cardWidth + 55 px, asi que tres
tarjetas necesitaban 1171 px en un contenedor de 1000 y solo entraban dos,
con 227 px muertos por fila. Ahora lo decide AppGrid (1/2/3/3: son 6 KPIs, y
con 4 columnas quedaban dos huerfanos). Ademas el texto de 'Atencion Rapida'
era Colors.white sobre el degradado de primary: en dark, blanco sobre teal
#81E6D9 son 1.47:1 cuando el minimo es 4.5. En claro daba 10.3:1 y pasaba
desapercibido."
```

---

### Task 10: `workshop_settings_screen` — la tercera tipografía y los errores que se van solos

**Files:**
- Modify: `lib/features/mechanic/presentation/pages/workshop_settings_screen.dart`
- Test: `test/features/mechanic/presentation/pages/workshop_settings_responsive_test.dart`

**Interfaces:**
- Consumes: `MechanicScaffold` (Task 1); `AppPageBody`, `AppBreakpoints`, `WindowClassX` (Fase 1); `AppCard`, `AppButton`, `AppTextField` (Fase 3); `AppSectionHeader` (Fase 4 Task 2); `AppSpacing`, `AppRadius`, `AppTextStyles`; `UserProfileProvider` (existente, **no se toca**).
- Produces: nada público nuevo.

**Problemas medidos:**

1. **7 `GoogleFonts.montserrat`** ([L247](../../../lib/features/mechanic/presentation/pages/workshop_settings_screen.dart#L247), [L278](../../../lib/features/mechanic/presentation/pages/workshop_settings_screen.dart#L278), [L337](../../../lib/features/mechanic/presentation/pages/workshop_settings_screen.dart#L337), [L479](../../../lib/features/mechanic/presentation/pages/workshop_settings_screen.dart#L479), [L524](../../../lib/features/mechanic/presentation/pages/workshop_settings_screen.dart#L524), [L625](../../../lib/features/mechanic/presentation/pages/workshop_settings_screen.dart#L625), [L810](../../../lib/features/mechanic/presentation/pages/workshop_settings_screen.dart#L810)). El maestro atribuía la tercera familia solo a `mechanic_sidebar`; el grueso está aquí.
2. **Los errores de validación se muestran en `SnackBar`, no junto al campo.** Tres reglas —especialidad, departamento/municipio y coordenadas— se comprueban en `_saveSettings` ([L150-180](../../../lib/features/mechanic/presentation/pages/workshop_settings_screen.dart#L150-L180)) y avisan con un `SnackBar` que desaparece a los pocos segundos, sin marcar qué campo falta y sin desplazar hasta él. En un formulario de nueve campos el usuario tiene que recordar el mensaje mientras busca el campo.
3. **"Por GPS" no da ningún feedback.** `_obtenerUbicacionGPS` pone `_isLoading = true` ([L750](../../../lib/features/mechanic/presentation/pages/workshop_settings_screen.dart#L750)), pero `_isLoading` solo lo consume el botón "Guardar Cambios" del final del formulario. El usuario pulsa "Por GPS", el botón no cambia, y la fijación GPS puede tardar varios segundos.
4. **14 líneas con color literal**: `Colors.grey[200]`, `Colors.grey[300]`, `Colors.white10`, `Colors.black.withValues(0.05)`, `Colors.white` (×4) y **`Colors.green` (×3)** para el estado "Coordenadas Registradas" ([L650](../../../lib/features/mechanic/presentation/pages/workshop_settings_screen.dart#L650), [L654](../../../lib/features/mechanic/presentation/pages/workshop_settings_screen.dart#L654), [L776](../../../lib/features/mechanic/presentation/pages/workshop_settings_screen.dart#L776)), habiendo `colors.success`.
5. `_buildInputField` y `_buildDropdownField` son reimplementaciones a mano con la etiqueta como `Text` hermano en un `Column` — el mismo defecto de accesibilidad que la Fase 3 Task 4 corrigió en `AppTextField`.
6. `maxWidth: 800` fijo; una sola columna en las cuatro clases; `GoogleMap` en un diálogo de `height: 350` fijo y sin `Semantics`.
7. `theme.colorScheme.primary` y `colors.primary` mezclados en el mismo fichero.

**Contrato:** `compact`/`medium` una columna acotada a `maxFormWidth`; `expanded`/`large` **dos columnas** — izquierda "Información Pública" (nombre, especialidad, departamento, municipio, teléfono), derecha "Ubicación Geográfica".

- [ ] **Step 1: Invocar las skills**

`Skill(ui-ux-pro-max:ui-ux-pro-max)` + `search.py "long form validation inline errors" --stack flutter`. Anota dónde debe aparecer un error de validación y qué hacer cuando el campo que falla está fuera del viewport.

- [ ] **Step 2: Escribir el test que falla**

```dart
// test/features/mechanic/presentation/pages/workshop_settings_responsive_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/widgets/app_text_field.dart';
import 'package:autodoc/features/mechanic/presentation/pages/workshop_settings_screen.dart';

import '../../../../support/mechanic_harness.dart';
import '../../../../support/responsive_harness.dart';

void main() {
  Future<void> pumpAjustes(WidgetTester tester, double width) async {
    await pumpMechanicScreen(
      tester,
      const WorkshopSettingsScreen(),
      width: width,
      location: '/workshop_settings',
      disableAnimations: true,
    );
    await tester.pump();
  }

  testWidgets('a 1440 px el formulario usa dos columnas', (tester) async {
    await pumpAjustes(tester, 1440);

    final nombre = tester.getTopLeft(find.text('Nombre del Taller')).dx;
    final ubicacion = tester.getTopLeft(find.text('Ubicación Geográfica')).dx;
    expect(
      ubicacion,
      greaterThan(nombre + 100),
      reason: 'la ubicación debe ir en la segunda columna, no debajo',
    );
  });

  testWidgets('a 375 px el formulario es una sola columna', (tester) async {
    await pumpAjustes(tester, 375);

    final nombre = tester.getTopLeft(find.text('Nombre del Taller'));
    final ubicacion = tester.getTopLeft(find.text('Ubicación Geográfica'));
    expect(ubicacion.dx, closeTo(nombre.dx, 1));
    expect(ubicacion.dy, greaterThan(nombre.dy));
  });

  testWidgets('los campos usan AppTextField, con la etiqueta asociada', (
    tester,
  ) async {
    await pumpAjustes(tester, 375);

    expect(find.byType(AppTextField), findsWidgets);
    final semantics = tester.getSemantics(find.byType(EditableText).first);
    expect(semantics.label, contains('Nombre del Taller'));
  });

  testWidgets('el error de coordenadas se muestra junto al campo', (
    tester,
  ) async {
    await pumpAjustes(tester, 375);

    await tester.tap(find.text('Guardar Cambios'));
    await tester.pump();

    expect(
      find.text('Registra tu ubicación para que los clientes te encuentren'),
      findsOneWidget,
      reason: 'antes era un SnackBar que desaparecía sin señalar el campo',
    );
  });

  testWidgets('no desborda en ninguno de los anchos de auditoría', (
    tester,
  ) async {
    for (final width in kAuditWidths) {
      await pumpAjustes(tester, width);
      expectNoOverflow(tester);
    }
  });

  test('no queda la tercera familia tipográfica ni colores literales', () {
    final source = File(
      'lib/features/mechanic/presentation/pages/workshop_settings_screen.dart',
    ).readAsStringSync();

    expect(source.contains('GoogleFonts.montserrat'), isFalse);
    expect(source.contains('GoogleFonts.'), isFalse);
    expect(source.contains('Colors.green'), isFalse);
    expect(source.contains('Colors.grey'), isFalse);
    expect(source.contains('Colors.white'), isFalse);
    expect(source.contains('size.width < 700'), isFalse);
  });
}
```

- [ ] **Step 3: Correr el test y confirmar el fallo exacto**

Run: `flutter test test/features/mechanic/presentation/pages/workshop_settings_responsive_test.dart`
Expected: **FAIL, 6 de 6.** Test 1: `ubicacion.dx` es igual a `nombre.dx` (una sola columna). Test 3: no hay ningún `AppTextField`. Test 4: no existe ese texto (el mensaje sale en `SnackBar` y con otro literal). Test 6: falla en las seis aserciones.

- [ ] **Step 4: Implementar**

4a. Shell: `MechanicScaffold(title: 'Configuración', body: ...)`. Desaparecen `_buildTopBar`, `isMobile`, el `Row`, el `Drawer` y el `MechanicSidebar`.

4b. Dos columnas por clase de ventana:

```dart
body: SingleChildScrollView(
  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
  child: AppPageBody(
    maxWidth: AppBreakpoints.of(context).isAtLeastExpanded
        ? AppBreakpoints.maxContentWidth
        : AppBreakpoints.maxFormWidth,
    child: Form(
      key: _formKey,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final dosColumnas =
              AppBreakpoints.fromWidth(constraints.maxWidth).isAtLeastExpanded;
          final infoPublica = _InfoPublicaSection(...);
          final ubicacion = _UbicacionSection(...);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (dosColumnas)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: infoPublica),
                    const SizedBox(width: AppSpacing.xl),
                    Expanded(child: ubicacion),
                  ],
                )
              else ...[
                infoPublica,
                const SizedBox(height: AppSpacing.xl),
                ubicacion,
              ],
              const SizedBox(height: AppSpacing.xxl),
              AppButton(
                text: 'Guardar Cambios',
                isLoading: _isSaving,
                onPressed: _isSaving ? null : _saveSettings,
              ),
            ],
          );
        },
      ),
    ),
  ),
),
```

4c. **Validación en línea.** Sustituye los tres `SnackBar` de `_saveSettings` por errores adyacentes al control:

- Especialidad y Departamento/Municipio ya son `DropdownButtonFormField` dentro del `Form`: basta con darles `validator:` y quitar el chequeo manual. `_formKey.currentState!.validate()` los marcará en rojo con su mensaje debajo.
- Las coordenadas no son un campo de formulario. Añade un `String? _errorUbicacion` al `State`, ponlo en `_saveSettings` cuando falten y píntalo bajo los dos botones de la sección de ubicación:

```dart
if (_errorUbicacion != null) ...[
  const SizedBox(height: AppSpacing.sm),
  Text(
    _errorUbicacion!,
    style: AppTextStyles.bodySmall.copyWith(color: colors.error),
  ),
],
```

con el literal exacto `'Registra tu ubicación para que los clientes te encuentren'`, y límpialo (`_errorUbicacion = null`) en cuanto se fijen coordenadas por GPS o por mapa.

4d. **Feedback del botón GPS.** Separa el estado: `_isSaving` para "Guardar Cambios" y `_isLocating` para "Por GPS". El botón pasa a `AppButton(text: 'Por GPS', isLoading: _isLocating, icon: const Icon(Icons.gps_fixed), onPressed: _isLocating ? null : _obtenerUbicacionGPS)`, y "En Mapa" a `AppButton(type: AppButtonType.secondary, ...)`. Renombra el `_isLoading` actual a `_isSaving` en los cuatro sitios donde aparece.

4e. Campos: `_buildInputField` → `AppTextField(label:, controller:, prefixIcon:, keyboardType:, validator:, isRequired:, helperText:)` y borra el helper. `_buildDropdownField` se conserva (no hay `AppDropdownField` en el design system) pero pasa a usar `AppTextStyles` para la etiqueta y `colors.outline.withValues(alpha: 0.4)` para los bordes en vez de `isDark ? Colors.white10 : Colors.grey[300]!`.

4f. Colores y tipografía: los 3 `Colors.green` → `colors.success`; `Colors.grey[200]/[300]` y `Colors.white10` → `colors.outline.withValues(alpha: 0.4)`; el `BoxShadow` manual de `Colors.black` → la tarjeta pasa a `AppCard`, que ya trae `AppShadows`; los 4 `Colors.white` de `foregroundColor` desaparecen al usar `AppButton`. Los 12 `GoogleFonts.*` → `AppTextStyles.*`, y los dos encabezados de sección → `AppSectionHeader(title:, subtitle:)`.

4g. Diálogo del mapa: `content: AppDialogContent(maxWidth: 640, child: SizedBox(height: AppBreakpoints.of(context).isCompact ? 280 : 400, child: ...))`, con el mapa envuelto en `Semantics(label: 'Mapa para elegir la ubicación del taller. Toca para marcar el punto.')` y el `ElevatedButton('Confirmar')` con `Colors.white` → `AppButton`.

> **Verificación manual obligatoria:** `GoogleMap` **no renderiza en `flutter_test`** sin un mock de plataforma, igual que en la Fase 4 Task 11. El diálogo del mapa se verifica a mano con `flutter run -d chrome` a 375 / 768 / 1440, en claro y oscuro, con capturas en el PR. Los tests de esta tarea cubren el formulario, no el mapa.

- [ ] **Step 5: Correr el test y confirmar verde**

Run: `flutter test test/features/mechanic/presentation/pages/workshop_settings_responsive_test.dart`
Expected: **PASS (6 tests)**.

- [ ] **Step 6: Verificar y commitear**

```bash
dart format . && flutter analyze && flutter test
git add lib/features/mechanic/presentation/pages/workshop_settings_screen.dart \
        test/features/mechanic/presentation/pages/workshop_settings_responsive_test.dart
git commit -m "fix(mechanic): inline validation and one typeface in workshop settings

Tres reglas del formulario (especialidad, departamento/municipio,
coordenadas) avisaban por SnackBar: el mensaje desaparecia solo, no marcaba
que campo faltaba y no desplazaba hasta el, en un formulario de nueve campos.
Ahora el error va junto al control. 'Por GPS' compartia _isLoading con
'Guardar Cambios', asi que al pulsarlo no cambiaba nada mientras el GPS
fijaba posicion. Y este fichero tenia 7 de las 11 GoogleFonts.montserrat del
modulo: la tercera familia tipografica no estaba solo en el sidebar."
```

---

### Task 11: `initiate_service_screen` — 1.418 líneas en una columna

**Files:**
- Modify: `lib/features/mechanic/presentation/pages/initiate_service_screen.dart`
- Modify: `lib/core/theme/app_severity.dart` (Fase 4 Task 1)
- Test: `test/features/mechanic/presentation/pages/initiate_service_responsive_test.dart`
- Test: `test/core/theme/app_severity_test.dart` (existente, se amplía)

**Interfaces:**
- Consumes: `AppPageBody`, `AppBreakpoints`, `WindowClassX` (Fase 1); `AppCard`, `AppButton`, `AppTextField` (Fase 3); `AppSectionHeader`, `AppSeverity`, `AppSeverityStyle` (Fase 4); `AppSpacing`, `AppRadius`, `AppTextStyles`.
- Produces: `AppSeverity.forAlertPriority(AlertPriority, AppColors, {required String altaLabel, required String mediaLabel, required String bajaLabel})` — método nuevo, aditivo, sobre la clase de la Fase 4.
- **No** usa `MechanicScaffold`: esta pantalla se abre con `context.push` desde "Buscar Vehículo" y es una vista de detalle con flecha de atrás. Meterle el sidebar rompería el modelo de navegación (el usuario está en medio de una tarea, no navegando por el panel).

**Problemas medidos:**

1. **38 `GoogleFonts`**, el fichero con más del repo, 4 de ellas `montserrat`. El maestro contaba 6.
2. **Una sola columna en las cuatro clases.** A 1440 px es una tira central de 8 secciones apiladas con `Responsive.padding(context, 20)` y sin cota de ancho: el formulario ocupa todo el ancho de la ventana.
3. **La severidad está escrita por quinta vez.** `_getStatusIcon` ([L1407-1416](../../../lib/features/mechanic/presentation/pages/initiate_service_screen.dart#L1407-L1416)) mapea `MaintenanceStatus` a icono y color a mano, en vez de usar `AppSeverity` de la Fase 4.
4. **Las alertas distinguen severidad solo por color.** `_buildAlertsList` ([L1309-1342](../../../lib/features/mechanic/presentation/pages/initiate_service_screen.dart#L1309-L1342)) usa `error` para `AlertPriority.high` y `warning` para el resto, pero **el mismo `Icons.warning_amber_rounded` para ambas**. Con protanopia son la misma tarjeta.
5. **6 colores literales**, todos `Colors.white` sobre el degradado de `colors.primary` en la cabecera del vehículo ([L801](../../../lib/features/mechanic/presentation/pages/initiate_service_screen.dart#L801), [L806](../../../lib/features/mechanic/presentation/pages/initiate_service_screen.dart#L806), [L818](../../../lib/features/mechanic/presentation/pages/initiate_service_screen.dart#L818), [L827](../../../lib/features/mechanic/presentation/pages/initiate_service_screen.dart#L827)) y en dos `foregroundColor` ([L670](../../../lib/features/mechanic/presentation/pages/initiate_service_screen.dart#L670), [L1274](../../../lib/features/mechanic/presentation/pages/initiate_service_screen.dart#L1274)). **Mismo defecto de 1,47:1 en dark que la Task 9.**
6. **Tres campos con caja idéntica escritos tres veces**: `_buildKmInput`, `_buildCostoInput` y `_buildManoDeObraInput` ([L874-989](../../../lib/features/mechanic/presentation/pages/initiate_service_screen.dart#L874-L989)) son el mismo `Container` con `Row(Icon, Expanded(TextField), [sufijo])` y distinto icono. Los tres usan `TextField` crudo con `InputBorder.none`, así que ninguno tiene etiqueta asociada ni mensaje de error.
7. `Card` + `ListTile` crudos en la lista de materiales ([L1010-1054](../../../lib/features/mechanic/presentation/pages/initiate_service_screen.dart#L1010-L1054)); `ElevatedButton`/`OutlinedButton` crudos en cinco sitios; `showModalBottomSheet` del catálogo sin cota de ancho (a 1440 px es una hoja de 1440).

**Corrección del contrato del maestro:** decía «flujo multi-paso → un paso por pantalla en `compact`, stepper lateral en `expanded`». **No es un flujo multi-paso.** Es un único `SingleChildScrollView > Column` con 8 secciones y un solo botón de envío. Convertirlo en stepper cambiaría el flujo de negocio, que §2 del maestro prohíbe. Contrato real:

| `WindowClass` | Estructura |
|---|---|
| `compact`, `medium` | Una columna acotada a `maxFormWidth` |
| `expanded`, `large` | **Dos columnas.** Izquierda: vehículo, kilometraje, alertas, tareas. Derecha: materiales, mano de obra, total, observaciones, factura y el botón de finalizar |

- [ ] **Step 1: Invocar las skills**

`Skill(ui-ux-pro-max:ui-ux-pro-max)` + `search.py "long form two column layout" --stack flutter`: anota el criterio para partir un formulario en dos columnas y dónde debe quedar la acción principal. `Skill(emil-design-eng)`: decide si el total (que se recalcula al añadir materiales) debe animar su cambio de valor.

- [ ] **Step 2: Ampliar el test de `AppSeverity` y escribir el de la pantalla**

Añade a `test/core/theme/app_severity_test.dart`:

```dart
  test('forAlertPriority da icono distinto por prioridad, no solo color', () {
    final colors = AppTheme.light.extension<AppColors>()!;

    final alta = AppSeverity.forAlertPriority(
      AlertPriority.high,
      colors,
      altaLabel: 'Crítica',
      mediaLabel: 'Media',
      bajaLabel: 'Informativa',
    );
    final media = AppSeverity.forAlertPriority(
      AlertPriority.medium,
      colors,
      altaLabel: 'Crítica',
      mediaLabel: 'Media',
      bajaLabel: 'Informativa',
    );

    expect(alta.color, colors.error);
    expect(media.color, colors.warning);
    expect(
      alta.icon,
      isNot(media.icon),
      reason: 'con protanopia el color no distingue: la forma sí',
    );
  });
```

```dart
// test/features/mechanic/presentation/pages/initiate_service_responsive_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/models/vehicle_model.dart';
import 'package:autodoc/features/mechanic/presentation/pages/initiate_service_screen.dart';

import '../../../../support/mechanic_harness.dart';
import '../../../../support/responsive_harness.dart';

VehicleModel vehiculoFake() => VehicleModel(
  idVehiculo: 'v1',
  idPropietario: 'p1',
  placa: 'ABC123',
  marca: 'Toyota',
  modelo: 'Corolla',
  anio: 2020,
  kilometrajeActual: 50000,
);

void main() {
  Future<void> pumpServicio(WidgetTester tester, double width) async {
    await pumpMechanicScreen(
      tester,
      InitiateServiceScreen(
        vehiculoId: 'v1',
        vehiculoPrecargado: vehiculoFake(),
      ),
      width: width,
      location: '/initiate_service/v1',
      disableAnimations: true,
    );
    await tester.pump();
  }

  testWidgets('a 1440 px el formulario usa dos columnas', (tester) async {
    await pumpServicio(tester, 1440);

    final km = tester.getTopLeft(find.text('KILOMETRAJE DE INGRESO')).dx;
    final costo = tester
        .getTopLeft(find.text('COSTO DEL SERVICIO (TOTAL)'))
        .dx;
    expect(
      costo,
      greaterThan(km + 100),
      reason: 'el bloque de facturación va en la segunda columna',
    );
  });

  testWidgets('a 375 px es una sola columna', (tester) async {
    await pumpServicio(tester, 375);

    final km = tester.getTopLeft(find.text('KILOMETRAJE DE INGRESO'));
    final costo = tester.getTopLeft(find.text('COSTO DEL SERVICIO (TOTAL)'));
    expect(costo.dx, closeTo(km.dx, 1));
    expect(costo.dy, greaterThan(km.dy));
  });

  testWidgets('no desborda en ninguno de los anchos de auditoría', (
    tester,
  ) async {
    for (final width in kAuditWidths) {
      await pumpServicio(tester, width);
      expectNoOverflow(tester);
    }
  });

  test('el fichero usa el design system, no su propia versión', () {
    final source = File(
      'lib/features/mechanic/presentation/pages/initiate_service_screen.dart',
    ).readAsStringSync();

    expect(source.contains('GoogleFonts.'), isFalse);
    expect(source.contains('Colors.white'), isFalse);
    expect(
      source.contains('_getStatusIcon'),
      isFalse,
      reason: 'la severidad la resuelve AppSeverity, quinta copia eliminada',
    );
    expect(
      source.contains('class _BoxedField'),
      isTrue,
      reason: 'los tres campos con caja idéntica se escriben una vez',
    );
  });
}
```

- [ ] **Step 3: Correr los tests y confirmar el fallo exacto**

Run: `flutter test test/core/theme/app_severity_test.dart test/features/mechanic/presentation/pages/initiate_service_responsive_test.dart`
Expected: **FAIL.** `AppSeverity.forAlertPriority` no existe. En la pantalla: test 1 con `costo.dx == km.dx` (una columna), y el test de fuente falla en las cuatro aserciones.

- [ ] **Step 4: Implementar**

4a. Añade a `lib/core/theme/app_severity.dart`:

```dart
  /// Severidad de una alerta de mantenimiento.
  ///
  /// `initiate_service_screen` pintaba alta y media con distinto color pero
  /// **el mismo icono**: con protanopia eran la misma tarjeta.
  static AppSeverityStyle forAlertPriority(
    AlertPriority prioridad,
    AppColors colors, {
    required String altaLabel,
    required String mediaLabel,
    required String bajaLabel,
  }) => switch (prioridad) {
    AlertPriority.high => AppSeverityStyle(
      color: colors.error,
      icon: Icons.error_rounded,
      label: altaLabel,
    ),
    AlertPriority.medium => AppSeverityStyle(
      color: colors.warning,
      icon: Icons.warning_rounded,
      label: mediaLabel,
    ),
    AlertPriority.low => AppSeverityStyle(
      color: colors.secondary,
      icon: Icons.info_rounded,
      label: bajaLabel,
    ),
  };
```

4b. Estructura de dos columnas. Sustituye el `Column` de 8 secciones ([L442-549](../../../lib/features/mechanic/presentation/pages/initiate_service_screen.dart#L442-L549)) por dos listas y un `LayoutBuilder`:

```dart
body: SingleChildScrollView(
  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
  child: LayoutBuilder(
    builder: (context, constraints) {
      final dosColumnas =
          AppBreakpoints.fromWidth(constraints.maxWidth).isAtLeastExpanded;

      final izquierda = <Widget>[
        _VehicleHeaderCard(vehiculo: _vehiculo!),
        const SizedBox(height: AppSpacing.base),
        _buildTicketReparacionBanner(colors),
        const SizedBox(height: AppSpacing.xl),
        const AppSectionHeader(title: 'Kilometraje de ingreso', uppercase: true),
        const SizedBox(height: AppSpacing.md),
        _BoxedField(
          icon: Icons.speed,
          label: 'Kilometraje de ingreso',
          controller: _kmController,
          keyboardType: TextInputType.number,
          suffix: 'KM',
        ),
        const SizedBox(height: AppSpacing.xl),
        const AppSectionHeader(title: 'Alertas detectadas', uppercase: true),
        const SizedBox(height: AppSpacing.md),
        _buildAlertsList(alertProvider, colors),
        const SizedBox(height: AppSpacing.xl),
        const AppSectionHeader(title: 'Tareas a realizar', uppercase: true),
        const SizedBox(height: AppSpacing.md),
        _buildMaintenanceTasks(alertProvider, colors),
      ];

      final derecha = <Widget>[ /* materiales, mano de obra, total, observaciones, factura, botón */ ];

      return AppPageBody(
        maxWidth: dosColumnas
            ? AppBreakpoints.maxContentWidth
            : AppBreakpoints.maxFormWidth,
        child: dosColumnas
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: izquierda,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xxl),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: derecha,
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [...izquierda, const SizedBox(height: AppSpacing.xl), ...derecha],
              ),
      );
    },
  ),
),
```

4c. Un solo campo con caja, en lugar de tres:

```dart
/// Campo con caja e icono. Era el mismo `Container` con `Row(Icon,
/// Expanded(TextField), [sufijo])` escrito tres veces (kilometraje, coste,
/// mano de obra), y los tres con `TextField` crudo e `InputBorder.none`: sin
/// etiqueta asociada al input y sin sitio donde mostrar un error.
class _BoxedField extends StatelessWidget {
  final IconData icon;
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final String? suffix;
  final bool readOnly;
  final String? helperText;

  const _BoxedField({
    required this.icon,
    required this.label,
    required this.controller,
    this.keyboardType,
    this.suffix,
    this.readOnly = false,
    this.helperText,
  });

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: label,
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      suffixText: suffix,
      helperText: helperText,
      prefixIcon: Icon(icon, color: context.appColors.primary),
    );
  }
}
```

El de coste queda `readOnly: true` con `helperText: 'Se calcula sumando materiales y mano de obra'` — hoy ese hecho solo se deduce del `hintText`, que desaparece en cuanto hay valor.

4d. Cabecera del vehículo: extrae `_VehicleHeaderCard` y sustituye los cuatro `Colors.white` por `colors.onPrimary` (y `colors.onPrimary.withValues(alpha: 0.8)` para la placa). Es el mismo fallo de 1,47:1 en dark de la Task 9: la misma corrección y el mismo motivo para no compensarlo con un color local.

4e. Alertas y tareas con `AppSeverity`:

```dart
final estilo = AppSeverity.forAlertPriority(
  alert.prioridad,
  colors,
  altaLabel: 'Crítica',
  mediaLabel: 'Preventiva',
  bajaLabel: 'Informativa',
);
...
Icon(estilo.icon, color: estilo.color, size: 20),
...
Semantics(label: '${estilo.label}: ${alert.titulo}', child: ...),
```

y borra `_getStatusIcon`, sustituyéndolo en `CheckboxListTile.secondary` por `AppSeverity.forStatus(status, colors, optimalLabel: 'Al día', preventiveLabel: 'Próximo', criticalLabel: 'Vencido')`.

4f. Hoja del catálogo: `showModalBottomSheet(..., constraints: BoxConstraints(maxWidth: AppBreakpoints.maxFormWidth))` — a 1440 px hoy es una hoja de 1.440 px de ancho con `ListTile` de una línea.

4g. Tokeniza el resto: los 38 `GoogleFonts.*` → `AppTextStyles.*`; `_buildSectionTitle` → `AppSectionHeader(uppercase: true)` (borra el helper); `Card` + `ListTile` de materiales → `AppCard`; los cinco `ElevatedButton`/`OutlinedButton` → `AppButton`; los `BorderRadius.circular(24/16/12/10)` → `AppRadius.*`; los `SizedBox(height: 40/24/16/12)` → `AppSpacing.*`; los `TextField` del diálogo "Agregar Material" → `AppTextField`.

- [ ] **Step 5: Correr los tests y confirmar verde**

Run: `flutter test test/core/theme/app_severity_test.dart test/features/mechanic/presentation/pages/initiate_service_responsive_test.dart`
Expected: **PASS**.

- [ ] **Step 6: Verificar y commitear**

```bash
dart format . && flutter analyze && flutter test
git add lib/core/theme/app_severity.dart \
        lib/features/mechanic/presentation/pages/initiate_service_screen.dart \
        test/core/theme/app_severity_test.dart \
        test/features/mechanic/presentation/pages/initiate_service_responsive_test.dart
git commit -m "refactor(mechanic): two-column service form, one severity source, one typeface

El fichero mas grande de la app (1418 lineas, 38 GoogleFonts) dibujaba una
sola tira central en las cuatro clases de ventana. Desde 840 px pasa a dos
columnas: recepcion a la izquierda, facturacion a la derecha. Las alertas
distinguian alta de media solo por color, con el mismo icono en ambas: se
anade AppSeverity.forAlertPriority y desaparece la quinta copia del semaforo.
Los tres campos con caja identica pasan a ser uno, y con AppTextField ganan
etiqueta asociada al input y sitio donde mostrar el error."
```

---

### Task 12: Cierre del ratchet de colores

**Files:**
- Modify: `test/core/theme/no_hardcoded_colors_test.dart`

**Interfaces:**
- Consumes: `kTokenizedPaths`, `kExemptFiles` (Fase 1 Task 8).
- Produces: el regex corregido y las rutas de la Fase 5 en el ratchet.

- [ ] **Step 1: Confirmar que el regex ya cubre las constantes de opacidad**

El agujero descrito en §0.3(b) **se corrigió en origen**: la Fase 1 Task 8 ya lleva el `\d*` tras `white`/`black`. Verifícalo antes de seguir:

```bash
grep -n 'white|black)\\d\*' test/core/theme/no_hardcoded_colors_test.dart
```

Expected: una línea. Si no aparece, la Fase 1 se ejecutó con la versión antigua del plan — aplica el patrón corregido que figura ahí (Task 8 Step 1) antes de continuar, porque sin él las rutas que este paso va a añadir quedarían protegidas solo a medias.

- [ ] **Step 2: Correr el ratchet tal como está antes de tocarlo**

Run: `flutter test test/core/theme/no_hardcoded_colors_test.dart`
Expected: **PASS.** Si falla, hay una regresión en una ruta ya ratcheteada de las Fases 1–4 y hay que arreglarla antes de añadir nada. **Arregla el fichero, nunca el regex.**

- [ ] **Step 3: Añadir las rutas de la Fase 5**

```dart
  // ── Fase 5 (módulo mechanic) ──
  'lib/core/widgets/app_dialog_content.dart',
  'lib/features/mechanic/presentation/pages',
  'lib/features/mechanic/presentation/widgets',
```

- [ ] **Step 4: Correr y confirmar que pasa**

Run: `flutter test test/core/theme/no_hardcoded_colors_test.dart`
Expected: **PASS**. Si falla, quedan literales en alguna de las 10 pantallas o en los dos widgets — arréglalos; **no quites la ruta de la lista**.

- [ ] **Step 5: Comprobar que el módulo quedó limpio**

```bash
grep -rn "GoogleFonts\." lib/features/mechanic         # esperado: vacío
grep -rn "size.width < 700" lib/features/mechanic      # esperado: vacío
grep -rn "montserrat" lib/features/mechanic            # esperado: vacío
grep -rn "MechanicSidebar" lib/features/mechanic/presentation/pages   # esperado: vacío
```

Los cuatro deben devolver cero líneas. El último es la prueba de que ninguna pantalla vuelve a montar el shell por su cuenta.

- [ ] **Step 6: Verificar y commitear**

```bash
dart format . && flutter analyze && flutter test
git add test/core/theme/no_hardcoded_colors_test.dart
git commit -m "chore(mechanic): extend the colour ratchet to the workshop module

Se anaden lib/features/mechanic/presentation/{pages,widgets} y
app_dialog_content.dart a kTokenizedPaths: 27 lineas con color literal, 109
GoogleFonts y 11 montserrat menos, y ninguna puede volver."
```

---

## Verificación de cierre de fase

- [ ] `flutter test` — suite completa en verde, incluidos los tres tests preexistentes del módulo (`catalogo_servicios_screen_test`, `empleados_screen_test`, `reparaciones_kanban_screen_test`).
- [ ] `flutter analyze` — sin issues nuevos.
- [ ] `dart format .` sin cambios pendientes.
- [ ] Los cuatro `grep` de la Task 12 Step 5, vacíos.
- [ ] **Matriz de anchos y temas.** `flutter run -d chrome`, recorrer las 10 pantallas a **320 / 375 / 600 / 768 / 840 / 1024 / 1200 / 1440**, en claro y oscuro. Ninguna con scroll horizontal. Atención especial a la franja **600–839**, que es donde el shell antiguo (700) y el nuevo (840) discrepan: entre esos dos valores la navegación cambia de sidebar fijo a drawer, y es el cambio más visible de la fase.
- [ ] **El corte de 840 en vivo.** Redimensionar lentamente entre 800 y 880 px en `mechanic_dashboard`: el sidebar debe aparecer/desaparecer una sola vez, sin parpadeo ni salto de scroll.
- [ ] **Daltonismo.** Con *Emulate vision deficiencies → Protanopia* en DevTools, comprobar en `initiate_service` que una alerta crítica y una preventiva siguen distinguiéndose (`Icons.error_rounded` vs `Icons.warning_rounded`), y en `mechanic_reviews` que 5 estrellas y 3 estrellas se distinguen (`star` vs `star_border`).
- [ ] **Reduced motion.** Con la preferencia activa: `mechanic_pending` no debe desplazar nada al entrar y debe seguir siendo plenamente usable.
- [ ] **Lector de pantalla.** Con el *Semantics Debugger*: en `mechanic_reviews` cada tarjeta debe anunciar "N de 5 estrellas"; en `mechanic_dashboard` la sección de la gráfica debe anunciar el resumen textual; en `reparaciones_kanban` cada columna debe anunciar su contador.
- [ ] **Verificación manual del mapa** (Task 10): el diálogo de `GoogleMap` a 375 / 768 / 1440, claro y oscuro, con capturas en el PR. No está cubierto por tests.
- [ ] Pre-Delivery Checklist de `ui-ux-pro-max` (`references/pro-rules.md`) completa.
- [ ] `Skill(review-animations)` sobre el diff de la fase (Tasks 2, 3 y 9 tocan motion).
- [ ] `Skill(superpowers:requesting-code-review)` sobre la rama.

## Criterio de éxito de la Fase 5

- El shell del rol taller existe **una vez**. `grep -c "MechanicScaffold(" lib/features/mechanic/presentation/pages` devuelve 8 usos y `mechanic_scaffold.dart` es la única declaración.
- **El breakpoint de 700 px desaparece del repo**, y con él el tercer sistema de breakpoints. Queda `AppBreakpoints` como única fuente.
- Las 10 pantallas cambian de estructura en al menos uno de los cortes 600 / 840 / 1200: rejilla (`catalogo`, `empleados`, `service_history`, `reviews`, dashboard), dos columnas (`workshop_settings`, `initiate_service`), tabs↔columnas (`kanban`) o ancho acotado (`pending`, `vehicle_search`).
- Cero `GoogleFonts` directos, cero `montserrat` y cero colores literales en todo `lib/features/mechanic`, protegido por el ratchet — con el regex ya sin el agujero de las 13 constantes de opacidad.
- El kanban es alcanzable con cualquier número de tarjetas y en cualquier ancho.
- Ningún texto sobre el degradado de `primary` baja de 4,5:1 **en dark**, que es donde estaba el fallo (1,47:1) y donde ni la Task 9 ni la Task 11 lo habrían visto probando solo en claro.
- La severidad se comunica con icono además de color en las dos pantallas del módulo que la muestran, desde `AppSeverity`.
- Todo control tappable mide ≥48 dp y todo control sin texto visible tiene `tooltip` o `Semantics.label`.

## Deuda declarada y bloqueos a consultar

**Declarado, no escondido:**

1. **Drag & drop en el kanban** (Task 3): el tablero avanza con un botón, no arrastrando. Añadirlo es una feature nueva que tocaría el flujo de `cambiarEstado`, no una refactorización de UI. Backlog.
2. **`GoogleMap` no se verifica por test** (Task 10): no renderiza en `flutter_test` sin un mock de plataforma. Verificación manual con capturas, igual que en la Fase 4 Task 11.
3. **Tres pantallas consultan Firestore directamente desde `build`** (`mechanic_dashboard`, `mechanic_reviews`, `mechanic_service_history`). Esta fase solo añade el parámetro `firestore` opcional para poder testearlas; **no** mueve las consultas a un repositorio, que sería tocar la capa `data/`. `mechanic_dashboard` además abre **tres `StreamBuilder` sobre la misma consulta** a `servicios` (métricas, gráfica y recientes): tres listeners donde bastaría uno. Backlog explícito.
4. **`_scanQR` puede disparar varios `pop()`** ([vehicle_search_screen.dart:32-42](../../../lib/features/mechanic/presentation/pages/vehicle_search_screen.dart#L32-L42)): `MobileScanner.onDetect` se invoca de forma continua mientras el código esté en cuadro, y no hay guarda. Es un bug de comportamiento, no de presentación; queda fuera del alcance de esta fase. Backlog.

**Bloqueos que exigen decisión antes o durante la ejecución:**

1. **Task 1 Step 6 — el predicado de rol.** Conviven tres criterios incompatibles (`_normalizeRole` acepta `'taller'`, `isMechanicRole` no, `mechanicFirestoreRoles` es `['Mecanico']`) y las sub-cuentas de empleado tienen `rol == 'Taller'`. Es una pregunta del modelo de datos. **No lo resuelvas en una tarea de UI**: deja el predicado como está y súbelo al PR.
2. **Task 7 Step 4d — la tarjeta "Asistente de Servicio".** Su texto describe un escáner de VIN que no existe (el de esta pantalla lee placas) y su botón no lleva a ninguna parte. Borrar contenido visible es decisión de producto. Opción por defecto si no hay respuesta: quitar solo el botón muerto.
3. **Task 7 Step 4f — `VehicleProvider.recentSearches`.** Si no está tipado como `List<VehicleModel>`, tiparlo sería tocar `providers/`. En ese caso deja el `dynamic`, quita esa aserción del test y documenta el motivo.
4. **Task 9 Step 4d y Task 11 Step 4d — `AppPalette.darkOnPrimary`.** Si el test de contraste sigue fallando en dark tras usar `colors.onPrimary`, el defecto está en la paleta y no en la pantalla. Párate y repórtalo: §2 del maestro prohíbe tocar `AppPalette` fuera de la excepción ya justificada en la Fase 1.
