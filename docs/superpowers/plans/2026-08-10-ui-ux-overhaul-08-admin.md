# Fase 8 — `admin`: la consola interna

> **Plan ejecutable.** Documento hermano de [`...-00-master.md`](2026-08-10-ui-ux-overhaul-00-master.md). Hereda **íntegra** la sección §2 (*Global Constraints*) del maestro y la tabla de skills obligatorias de §1. Escrito el **2026-08-12** siguiendo el protocolo de §7 del maestro.
>
> **REQUIRED SUB-SKILL:** `superpowers:subagent-driven-development` (recomendado) o `superpowers:executing-plans`.
>
> **Dependencias duras:** Fases 1, 2 y 3 ejecutadas. Consume además `AppSeverity`, creado en la Fase 4 y extendido en la Fase 6.
>
> **Última fase del roadmap.** Al cerrarla se ejecutan las auditorías globales de §16.

**Goal:** Dejar utilizable la consola de administración: 6 pantallas y 9 widgets que hoy gobiernan la aprobación de talleres, la gestión de usuarios y la moderación de reseñas. Es el módulo de menor tráfico y el último por diseño, pero contiene la tarjeta con la que se aprueba o rechaza un taller — y esa tarjeta está rota en todos los teléfonos.

---

## 0. Métricas medidas sobre `HEAD` (2026-08-12)

Quince ficheros de presentación (6 páginas + 9 widgets), **3.719 líneas**. La capa `data/` y `providers/` del módulo (1.177 líneas más) queda fuera por §2 del maestro.

**HC** = `Colors.<literal>` · **0x** = `Color(0xFF…)` literal · **MQ** = `MediaQuery…size` crudo · **Resp** = llamadas a `Responsive.*` · **GF** = `GoogleFonts.*` · **l10n** = usos de `context.l10n` · **W≥100** = medidas fijas ≥ 100 px.

| Fichero | LOC | HC | 0x | MQ | Resp | GF | l10n | W≥100 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| [admin_usuarios_screen.dart](../../../lib/features/admin/presentation/pages/admin_usuarios_screen.dart) | 575 | 3 | — | — | 8 | — | 8 | — |
| [admin_logs_screen.dart](../../../lib/features/admin/presentation/pages/admin_logs_screen.dart) | 524 | **11** | — | — | 15 | — | 2 | — |
| [admin_talleres_screen.dart](../../../lib/features/admin/presentation/pages/admin_talleres_screen.dart) | 504 | — | — | — | 6 | — | 3 | **3** |
| [admin_dashboard_screen.dart](../../../lib/features/admin/presentation/pages/admin_dashboard_screen.dart) | 493 | 4 | — | **1** | **22** | 2 | **19** | — |
| [admin_resenias_screen.dart](../../../lib/features/admin/presentation/pages/admin_resenias_screen.dart) | 332 | 3 | — | — | 8 | — | 1 | — |
| [taller_admin_card.dart](../../../lib/features/admin/presentation/widgets/taller_admin_card.dart) | 173 | **14** | — | — | — | — | 4 | — |
| [admin_sidebar.dart](../../../lib/features/admin/presentation/widgets/admin_sidebar.dart) | 164 | 5 | **1** | — | — | — | — | — |
| [services_trend_chart.dart](../../../lib/features/admin/presentation/widgets/services_trend_chart.dart) | 144 | — | — | — | — | 1 | 1 | **1** |
| [user_growth_chart.dart](../../../lib/features/admin/presentation/widgets/user_growth_chart.dart) | 143 | — | — | — | — | 1 | 1 | **1** |
| [workshops_growth_chart.dart](../../../lib/features/admin/presentation/widgets/workshops_growth_chart.dart) | 140 | — | — | — | — | 1 | 1 | **1** |
| [account_row.dart](../../../lib/features/admin/presentation/widgets/account_row.dart) | 137 | 8 | — | — | — | — | 4 | — |
| [mecanico_admin_card.dart](../../../lib/features/admin/presentation/widgets/mecanico_admin_card.dart) | 132 | 2 | — | — | — | 1 | — | — |
| [dialog_crear_usuario.dart](../../../lib/features/admin/presentation/widgets/dialog_crear_usuario.dart) | 108 | 1 | — | — | — | — | — | — |
| [metric_card.dart](../../../lib/features/admin/presentation/widgets/metric_card.dart) | 90 | — | — | — | — | 2 | — | — |
| [admin_seed_screen.dart](../../../lib/features/admin/presentation/pages/admin_seed_screen.dart) | 60 | 2 | — | — | 4 | 2 | 3 | — |
| **TOTAL** | **3.719** | **53** | **1** | **1** | **63** | **10** | **47** | **6** |

**54 colores hardcodeados**, y a diferencia de las fases anteriores **no están repartidos al azar: casi todos codifican estado**. Ver §0.1.

**El módulo llega en verde:** `flutter test test/features/admin/` da **34 tests, todos pasando**. Es el módulo mejor cubierto de la app — tiene tests de provider, de servicio, de repositorio, de los tres gráficos y de la función pura de filtrado. Nada de eso cubre layout.

---

### 0.1 El hallazgo estructural: el color de estado está reimplementado cuatro veces

De los 54 literales, **31 son un semáforo de estado** escrito a mano, con cuatro mapeos distintos e incompatibles:

| Fichero | Mapeo | Línea |
|---|---|---|
| `taller_admin_card` | `aprobado`→verde · `suspendido`→rojo · `rechazado`→**gris** · resto→naranja | [L21-27](../../../lib/features/admin/presentation/widgets/taller_admin_card.dart#L21-L27) |
| `admin_logs_screen` | destructivo→rojo · creación→verde · modificación→naranja · resto→**azul** | [L58-66](../../../lib/features/admin/presentation/pages/admin_logs_screen.dart#L58-L66) |
| `account_row` | activo→verde · inactivo→rojo (fondo al 20 %, texto `shade800`) | [L67-76](../../../lib/features/admin/presentation/widgets/account_row.dart#L67-L76) |
| `admin_dashboard_screen` | destructivo→`colors.error` · resto→`colors.secondary` | [L428-432](../../../lib/features/admin/presentation/pages/admin_dashboard_screen.dart#L428-L432) |

**Los dos últimos ya discrepan con los dos primeros sobre el mismo concepto.** `admin_dashboard` clasifica un log como destructivo buscando `SUSPENDER`/`ELIMINAR`/`RECHAZAR` en la cadena de acción y lo pinta con **tokens**; `admin_logs_screen`, que muestra los mismos logs, usa **cuatro colores literales de Material** con otra regla. La misma acción se ve de dos colores distintos en dos pantallas de la misma consola.

`AppSeverity` existe desde la Fase 4 y se extendió en la Fase 6 con `forReservaEstado`. **Esta fase es el tercer consumidor y el que cierra el patrón**: `forTallerEstado` y `forLogAccion` (Task 1).

**Y el contraste de esos literales está medido y falla.** `Colors.green` `#4CAF50` sobre `lightSurface` `#F7F6F8` da **2,78:1**; `Colors.orange` `#FF9800` da **2,16:1**; y `taller_admin_card` pinta además `Colors.white` sobre `Colors.green` como fondo de botón (**2,54:1**). El texto de estado de un taller —el dato por el que existe la pantalla— no llega a 3:1 en ninguno de sus cuatro valores.

---

### 0.2 `TallerAdminCard` desborda dos veces en todos los teléfonos

Es la tarjeta con la que el administrador **aprueba, rechaza o suspende un taller**: la acción principal del módulo. Medido montándola aislada con `FlutterError.onError` capturado:

| Ancho | Desbordamientos |
|---:|---|
| 320 | **125 px** y **146 px** |
| 375 | **70 px** y **91 px** |
| 600 | 0 |
| 840 | 0 |
| 1440 | 0 |

Los dos `RenderFlex` están localizados por `debugCreator`:

1. `Row ← Padding ← DecoratedBox ← Container ← Wrap` → el `Row` interno de `_buildInfoChip` ([L158-170](../../../lib/features/admin/presentation/widgets/taller_admin_card.dart#L158-L170)). El chip pinta `Icon + SizedBox + Text` sin `Flexible` ni `ellipsis`: una especialidad larga («Transmisiones automáticas») no cabe y el chip desborda. Los tres chips —especialidad, municipio, teléfono— salen de datos de usuario, así que la longitud no está acotada por nada.
2. `Row ← Column ← Padding ← Semantics` → el `Row` de acciones ([L74-76](../../../lib/features/admin/presentation/widgets/taller_admin_card.dart#L74-L76)), `mainAxisAlignment: MainAxisAlignment.end` con hasta tres botones. Tres botones con texto no caben en 320 ni en 375.

**Limpia desde 600 px.** Exactamente el mismo perfil que `profile_setup_screen` en la Fase 7: rota en todo ancho de teléfono, correcta a partir de `medium`. Y con la misma causa de fondo: un `Row` sin holgura y sin `Flexible`.

> **Matiz honesto sobre el uso real.** La consola de administración se usa mayoritariamente en escritorio, así que este defecto afecta a menos gente que los de las fases 4–7. No cambia que esté roto ni que sea barato de arreglar: un `Flexible` en el chip y un `Wrap` en las acciones.

---

### 0.3 El cuarto sistema de breakpoints, y una pantalla que se contradice a sí misma

El maestro §3 registra tres sistemas incompatibles (`Responsive`, `responsive_framework`, y el `< 700` copiado del módulo `mechanic`). **Hay un cuarto**, y está en una sola pantalla:

[admin_dashboard_screen.dart:221-222](../../../lib/features/admin/presentation/pages/admin_dashboard_screen.dart#L221-L222)

```dart
final screenWidth = MediaQuery.of(context).size.width;
final crossAxisCount = screenWidth > 900 ? 3 : (screenWidth > 600 ? 2 : 1);
```

Cortes en **600 y 900**. La misma pantalla, 65 líneas más abajo, decide la disposición de sus gráficos con **otro** criterio:

[admin_dashboard_screen.dart:287](../../../lib/features/admin/presentation/pages/admin_dashboard_screen.dart#L287)

```dart
if (Responsive.isMobile(context)) { /* una columna */ }
// si no: Row(Expanded, Expanded)
```

`Responsive.isMobile` es `width < 600`.

**A exactamente 600 px las dos reglas se contradicen dentro del mismo `build()`:** `600 > 600` es falso, así que las métricas se dibujan en **una** columna; `600 < 600` también es falso, así que los gráficos se dibujan en **dos**. Métricas apiladas y gráficos lado a lado en la misma pantalla, al mismo ancho.

Y el resultado de los gráficos a ese ancho es malo por sí solo: `(600 − 48 de padding − 16 de hueco) / 2` = **268 px** por gráfico, con `height: 250` fijo y etiquetas de mes en el eje.

---

### 0.4 Correcciones al maestro §5.5

Cuatro puntos de la tabla del maestro no describen lo que hace el código. Se corrigen en la Task 12.

1. **No hay ni una `DataTable` en todo el módulo.** El maestro pide para `admin_talleres` y `admin_usuarios` *"`compact`: tarjetas. `expanded`+: tabla"*, y para `admin_logs` *"Tabla densa"*. Verificado: las tres pantallas ya son `ListView`/`SliverList` de tarjetas y **no existe ninguna tabla que hacer responsiva**. Construirla sería **UI nueva**, no una refactorización de presentación — el mismo error de encuadre que el maestro cometió con el stepper de `initiate_service` (Fase 5 §5.2) y con el master-detail del chat (Fase 6 §18.1). Sustituido por: tarjetas en `compact`/`medium`, **grid de 2–3 columnas** en `expanded`/`large`, con `AppGrid`. Ver §19.1 si de verdad se quiere una tabla.

2. **`admin_talleres` no tiene *"tres anchos fijos de 220 que revientan en móvil"*.** Los tres `SizedBox(width: 220)` de [L426, L447, L470](../../../lib/features/admin/presentation/pages/admin_talleres_screen.dart#L425-L470) están dentro de un **`Wrap`**, así que se apilan y no desbordan; a 320 px caben (272 disponibles). Su defecto real es el contrario: a 1440 px siguen midiendo 220 y los tres filtros se amontonan a la izquierda de una fila de 1.392 px. Lo que **sí** desborda en esa pantalla es `TallerAdminCard` (§0.2), que el maestro no registraba.

3. **El contrato de KPIs del dashboard es aritméticamente imposible.** El maestro pide *"KPIs vía `AppGrid` 1/2/4"*. Son **6** `MetricCard`; con 4 columnas quedan dos huérfanos en la segunda fila. Es exactamente la corrección que la Fase 5 tuvo que hacer en `mechanic_dashboard_screen`. Sustituido por **1/2/3/3**, que es además lo que el código ya hace hoy (`> 900 ? 3 : …`) — la tarea formaliza el reparto, no lo inventa.

4. **`admin_logs_screen` tiene 11 colores literales, sí — pero no *"probablemente por tipo de log"*: exactamente por eso**, y con un mapeo que discrepa del que usa el dashboard para los mismos logs (§0.1). El diagnóstico correcto no es «tokenizar 11 colores» sino «hay dos definiciones de qué es una acción grave».

---

### 0.5 Otros defectos verificados

#### 0.5.1 Un listener de Firestore por fila de lista

[admin_talleres_screen.dart:258-273](../../../lib/features/admin/presentation/pages/admin_talleres_screen.dart#L258-L273), dentro de un `SliverChildBuilderDelegate`:

```dart
return StreamBuilder<DocumentSnapshot>(
  stream: FirebaseFirestore.instance
      .collection(FirestoreCollections.talleres)
      .doc(mecanico.idUsuario)
      .snapshots(),
```

Cada mecánico visible abre **su propia suscripción en vivo** a un documento. Con 200 mecánicos registrados son hasta 200 listeners concurrentes, y como el `delegate` construye y destruye elementos al hacer scroll, cada pasada vuelve a suscribir. Es consulta desde presentación (el maestro §2 no lo prohíbe, pero `CONVENTIONS.md` sí lo desaconseja) **y** un coste de Firestore proporcional al scroll.

Arreglarlo bien es mover el dato al provider — prohibido por §2. Lo que **sí** entra en esta fase es dejar de re-suscribir en cada rebuild cacheando el `Stream` por id, igual que la Fase 6 hizo con el `FutureBuilder` del AppBar del chat. Ver §19.2.

#### 0.5.2 `setState` disparado desde `build()`

[admin_talleres_screen.dart:415-419](../../../lib/features/admin/presentation/pages/admin_talleres_screen.dart#L415-L419), dentro de `_buildFiltrosAvanzados`, que se llama desde `build`:

```dart
if (_filterMunicipio != null && !municipios.contains(_filterMunicipio)) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) setState(() => _filterMunicipio = null);
  });
}
```

El `addPostFrameCallback` evita la aserción inmediata, pero el patrón sigue siendo «construir → programar un `setState` → reconstruir». Si la condición se mantuviera cierta tras el `setState` sería un bucle infinito de frames. Hoy no lo es (pone el filtro a `null`, que satisface la condición), pero es frágil: la corrección pertenece al `onChanged` del departamento, donde el municipio debe limpiarse **cuando el usuario cambia el departamento**, no cuando el árbol se reconstruye.

#### 0.5.3 `admin_seed` es un callejón sin salida

Cinco de las seis páginas montan `drawer: const AdminSidebar()`. [admin_seed_screen.dart](../../../lib/features/admin/presentation/pages/admin_seed_screen.dart) **no**. Una vez en `/admin/seed` no hay ninguna forma de volver al resto de la consola desde la interfaz: ni cajón, ni botón de retroceso (es ruta de primer nivel, no apilada). Solo el botón *atrás* del navegador, y en la app compilada ni eso.

Además la pantalla está detrás de `if (!kDebugMode)`, así que en producción muestra *"Acceso denegado"* — pero el elemento del cajón que lleva a ella **no** está oculto en producción. El administrador ve una entrada de menú que siempre le niega el acceso.

#### 0.5.4 El shell de administración está copiado seis veces

Igual que el módulo `mechanic` (maestro §5.2, corregido por la Fase 5): cada página construye su propio `Scaffold` + `AppBar` + `drawer`. No hay `ShellRoute` para `/admin/*` — las seis son rutas de primer nivel ([app_router.dart:607-651](../../../lib/core/router/app_router.dart#L607-L651)).

Consecuencias medibles: el cajón se cierra y se reabre en cada navegación (no hay estado compartido), el `AdminSidebar` no marca cuál es la ruta activa de forma consistente, y **los conmutadores de tema e idioma solo existen en el dashboard** ([admin_dashboard_screen.dart:49-82](../../../lib/features/admin/presentation/pages/admin_dashboard_screen.dart#L49-L82)) — en las otras cinco pantallas no hay forma de cambiar el idioma.

Unificarlo en un `ShellRoute` es reestructurar el router. Ver §19.3.

#### 0.5.5 Contraste blanco sobre `primary`, otra vez

[admin_dashboard_screen.dart:166-196](../../../lib/features/admin/presentation/pages/admin_dashboard_screen.dart#L166-L196) y [admin_sidebar.dart:41-68](../../../lib/features/admin/presentation/widgets/admin_sidebar.dart#L41-L68) pintan `Colors.white` sobre un degradado de `colors.primary`.

| Tema | Fondo | Texto | Ratio |
|---|---|---|---:|
| claro | `#522C81` | `Colors.white` | 10,32:1 ✓ |
| **oscuro** | `#81E6D9` | `Colors.white` | **1,47:1** ✗ |
| oscuro | `#81E6D9` | `Colors.white` al 80 % (subtítulo) | **1,31:1** ✗ |

Es el **tercer** sitio con este defecto exacto: la Fase 5 lo encontró en `mechanic_dashboard_screen` y la Fase 6 en las burbujas del chat. La corrección es la misma y ya está disponible: `colors.onPrimary`, que da 10,32:1 en claro y **12,12:1** en oscuro.

Y `admin_sidebar` añade una variante propia: [L50](../../../lib/features/admin/presentation/widgets/admin_sidebar.dart#L50) escribe `color: Color(0xFF522C81)` — **una copia literal de `AppPalette.lightPrimary`** — para el icono del avatar. En tema oscuro el degradado de detrás pasa a ser teal y el icono se queda morado. Misma bifurcación de paleta que la Fase 7 encontró en `user_profile_screen`, aquí en una sola línea.

#### 0.5.6 Los tres gráficos: altura fija y sin alternativa textual

`services_trend_chart`, `user_growth_chart` y `workshops_growth_chart` fijan `height: 250` ([L57](../../../lib/features/admin/presentation/widgets/services_trend_chart.dart#L57), [L56](../../../lib/features/admin/presentation/widgets/user_growth_chart.dart#L56), [L66](../../../lib/features/admin/presentation/widgets/workshops_growth_chart.dart#L66)) y no exponen ningún equivalente textual: un `fl_chart` es, para un lector de pantalla, un rectángulo vacío.

Los tres **sí** tienen tests, y buenos (incluido uno de regresión sobre claves `yyyy-MM` con cero a la izquierda). Ninguno cubre accesibilidad ni geometría.

#### 0.5.7 Objetivos táctiles y cadenas sin localizar

| Control | Medida estimada | Dónde |
|---|---|---|
| `_buildActionChip` del dashboard | 12+12+~18 ≈ **42 dp** | [L343-389](../../../lib/features/admin/presentation/pages/admin_dashboard_screen.dart#L343-L389) |
| `_buildInfoChip` de `taller_admin_card` | `padding` sin mínimo | [L155-172](../../../lib/features/admin/presentation/widgets/taller_admin_card.dart#L155-L172) |
| Chips de filtro de `admin_logs` | `vertical: Responsive.padding(context, 3)` | [L497-498](../../../lib/features/admin/presentation/pages/admin_logs_screen.dart#L497-L498) |

Y la localización está **a medias, con un patrón claro**: el dashboard tiene 19 usos de `context.l10n` y `admin_talleres` solo 3, con ~15 cadenas en español literal (`'Departamento'`, `'Municipio'`, `'Especialidad'`, `'Buscar taller / mecánico...'`, `'Mecánicos registrados'`, `'Solicitudes formales (colección Talleres)'`, los tres textos de confirmación, los encabezados del CSV…). `admin_logs` tiene 2 usos y `admin_resenias` 1.

Total del módulo: **47 usos de `context.l10n`** contra ~40 cadenas literales. Ver §18.1.

---

### 0.6 Ficheros de la fase

| Fichero | LOC | Tarea |
|---|---:|---|
| `lib/core/theme/app_severity.dart` | — | Task 1 (extensión aditiva) |
| `test/support/admin_harness.dart` | nuevo | Task 1 |
| `lib/features/admin/presentation/pages/admin_seed_screen.dart` | 60 | Task 2 |
| `lib/features/admin/presentation/widgets/admin_sidebar.dart` | 164 | Task 3 |
| `lib/features/admin/presentation/widgets/taller_admin_card.dart` | 173 | Task 4 |
| `…/widgets/mecanico_admin_card.dart` · `account_row.dart` · `dialog_crear_usuario.dart` | 377 | Task 5 |
| `lib/features/admin/presentation/widgets/metric_card.dart` | 90 | Task 6 |
| Los tres gráficos de `fl_chart` | 427 | Task 7 |
| `lib/features/admin/presentation/pages/admin_dashboard_screen.dart` | 493 | Task 8 |
| `lib/features/admin/presentation/pages/admin_talleres_screen.dart` | 504 | Task 9 |
| `lib/features/admin/presentation/pages/admin_usuarios_screen.dart` | 575 | Task 10 |
| `lib/features/admin/presentation/pages/admin_resenias_screen.dart` | 332 | Task 11 |
| `lib/features/admin/presentation/pages/admin_logs_screen.dart` | 524 | Task 11 |
| `test/support/tokenized_paths.dart` + maestro | — | Task 12 |

---

## 1. Reglas de esta fase

Además de §2 del maestro:

**1.1 — El módulo llega en verde, y bien cubierto.** 34 tests pasando, incluidos tres de gráficos y uno de la función pura `filtrarTalleres`. **Ninguna tarea puede romperlos.** En particular, `filtrarTalleres` es una función *top-level* deliberadamente extraída para ser testeable: no la muevas ni cambies su firma.

**1.2 — El color de estado sale de `AppSeverity`, no de la pantalla.** Después de la Task 1, ninguna pantalla ni widget de `admin` puede contener un `switch`/ternario que traduzca un estado a un color. Es la regla que hace que las Tasks 4, 5, 8 y 11 sean pequeñas.

**1.3 — No se construyen tablas.** §0.4.1. Si al leer una pantalla te parece que «pide una tabla», anótalo en el backlog y sigue con el grid. Añadir una `DataTable` es una funcionalidad nueva.

**1.4 — No se añaden claves de l10n**, en coherencia con las Fases 4, 6 y 7. Cablear claves que **ya existen** en el ARB y no se usan sí entra. La deuda se declara en §18.1.

**1.5 — No se toca `data/` ni `providers/`.** El módulo tiene 1.177 líneas de `admin_service`, `admin_repository`, `admin_auth_service`, `admin_provider` y `admin_dashboard_provider`, todas con tests. Están fuera de alcance por completo.

**1.6 — Los tests de este módulo necesitan `pumpAndSettle`.** `AppLocalizations` resuelve de forma asíncrona: con un solo `pump()`, `context.l10n` devuelve `null` y cualquier widget del módulo que lo use revienta con `Null check operator used on a null value` antes de llegar a la primera aserción. Verificado en esta sesión al medir §0.2. El harness de la Task 1 lo encapsula.

---

## 2. Task 1: `AppSeverity` para `admin` + `admin_harness.dart`

**Files:**
- Modify: `lib/core/theme/app_severity.dart` (extensión aditiva)
- Create: `test/support/admin_harness.dart`
- Test: `test/core/theme/app_severity_admin_test.dart`

**Interfaces:**
- Consumes: `AppSeverityStyle`, `AppSeverity` (Fase 4, extendido en Fase 6); `context.appColors`; `pumpAtWidth`, `kAuditWidths` (Fase 1 Task 7); `AppLocalizations`.
- Produces: `AppSeverity.forTallerEstado(String, AppColors, {required String pendienteLabel, required String aprobadoLabel, required String rechazadoLabel, required String suspendidoLabel})`; `AppSeverity.forLogAccion(String, AppColors, {required String destructivaLabel, required String creacionLabel, required String modificacionLabel, required String consultaLabel})`; `AppSeverity.forCuentaActiva(bool, AppColors, {required String activaLabel, required String inactivaLabel})`. Y en el harness: `Future<void> pumpAdmin(WidgetTester, Widget, {double width, double height, Brightness brightness, Locale locale, AdminProvider? admin, AdminDashboardProvider? dashboard})`; `Future<List<FlutterErrorDetails>> pumpAdminCollecting(...)`; `class FakeAdminProvider`; `class FakeAdminDashboardProvider`; `WorkshopModel testTaller({...})`.

**Por qué las tres funciones y no una.** Los cuatro mapeos de §0.1 codifican tres conceptos distintos: el **estado de un taller** (4 valores), la **gravedad de una acción de log** (4 clases derivadas de una cadena libre) y si una **cuenta está activa** (booleano). Unificarlos en una sola función obligaría a inventar un enum común que no existe en el dominio. Tres funciones con el mismo patrón que `forReservaEstado` es lo correcto.

**Todas toman `String`, no un enum**, por la misma razón que `forReservaEstado` en la Fase 6: el valor viene de Firestore como texto libre. Y todas caen al caso menos alarmante en vez de lanzar.

- [ ] **Step 1: invocar las skills**

`Skill(graphify)` — `graphify query "which admin widgets map a state string to a color"` para confirmar que los cuatro sitios de §0.1 son todos y no hay un quinto.

`Skill(ui-ux-pro-max:ui-ux-pro-max)` — `references/pro-rules.md` §10: *"Color is never the only carrier of meaning"*. Cada `AppSeverityStyle` lleva icono además de color; asegúrate de que los iconos elegidos se distingan entre sí en escala de grises.

`Skill(find-animation-opportunities)` sobre `lib/features/admin/` — una vez por módulo, como manda §7 del maestro.

- [ ] **Step 2: escribir el test que falla**

```dart
// test/core/theme/app_severity_admin_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_severity.dart';

import '../../support/contrast.dart';
import '../../support/theme_fixtures.dart';

void main() {
  for (final fixture in <({String name, AppColors colors})>[
    (name: 'claro', colors: lightAppColors),
    (name: 'oscuro', colors: darkAppColors),
  ]) {
    test('forTallerEstado cubre los cuatro estados en ${fixture.name}', () {
      final estados = <String, String>{
        'pendiente': 'Pendiente',
        'aprobado': 'Aprobado',
        'rechazado': 'Rechazado',
        'suspendido': 'Suspendido',
      };

      for (final entry in estados.entries) {
        final style = AppSeverity.forTallerEstado(
          entry.key,
          fixture.colors,
          pendienteLabel: 'Pendiente',
          aprobadoLabel: 'Aprobado',
          rechazadoLabel: 'Rechazado',
          suspendidoLabel: 'Suspendido',
        );
        expect(style.label, entry.value);
        expect(
          contrastRatio(style.color, fixture.colors.surface),
          greaterThanOrEqualTo(3.0),
          reason: '${entry.key} ilegible en ${fixture.name}',
        );
      }
    });

    test('un estado desconocido cae en pendiente, no lanza', () {
      final style = AppSeverity.forTallerEstado(
        'un-estado-que-firestore-podria-traer',
        fixture.colors,
        pendienteLabel: 'Pendiente',
        aprobadoLabel: 'A',
        rechazadoLabel: 'R',
        suspendidoLabel: 'S',
      );
      expect(style.label, 'Pendiente');
    });

    test('forLogAccion clasifica por palabra clave', () {
      String labelOf(String accion) => AppSeverity.forLogAccion(
        accion,
        fixture.colors,
        destructivaLabel: 'destructiva',
        creacionLabel: 'creacion',
        modificacionLabel: 'modificacion',
        consultaLabel: 'consulta',
      ).label;

      expect(labelOf('SUSPENDER_TALLER'), 'destructiva');
      expect(labelOf('ELIMINAR_USUARIO'), 'destructiva');
      expect(labelOf('RECHAZAR_TALLER'), 'destructiva');
      expect(labelOf('CREAR_USUARIO'), 'creacion');
      expect(labelOf('APROBAR_TALLER'), 'creacion');
      expect(labelOf('EDITAR_PERFIL'), 'modificacion');
      expect(labelOf('VER_LOGS'), 'consulta');
    });

    test('los cuatro iconos de log son distintos entre si', () {
      final iconos = <String>[
        'SUSPENDER_X',
        'CREAR_X',
        'EDITAR_X',
        'VER_X',
      ].map(
        (a) => AppSeverity.forLogAccion(
          a,
          fixture.colors,
          destructivaLabel: 'd',
          creacionLabel: 'c',
          modificacionLabel: 'm',
          consultaLabel: 'v',
        ).icon,
      ).toSet();
      expect(iconos, hasLength(4), reason: 'el icono no distingue las clases');
    });
  }
}
```

> **`test/support/theme_fixtures.dart` puede no existir.** Los tests de fases anteriores construyen el `AppColors` a mano (ver [about_screen_navigation_test.dart](../../../test/features/profile/presentation/pages/about_screen_navigation_test.dart), que lo hace con 15 parámetros). Si no existe, **créalo en este Step** con `lightAppColors` y `darkAppColors` construidos desde `AppPalette`: son 30 líneas que eliminan una duplicación que ya está en al menos tres ficheros de test.

- [ ] **Step 3: correr y confirmar el fallo exacto**

```bash
flutter test test/core/theme/app_severity_admin_test.dart
```

Expected: `Error: Member not found: 'AppSeverity.forTallerEstado'` (y lo mismo para `forLogAccion`). Si `theme_fixtures.dart` tampoco existe, el primer error será `Target of URI doesn't exist`.

- [ ] **Step 4: implementar**

```dart
  /// Estado de un taller tal como lo guarda Firestore (texto libre).
  ///
  /// Sustituye a los cuatro mapeos incompatibles que la consola de
  /// administracion tenia escritos a mano (Fase 8 §0.1). El anterior de
  /// `taller_admin_card` usaba `Colors.grey` para «rechazado», que no
  /// distingue «rechazado» de «deshabilitado»; aqui rechazado es `error`
  /// con icono propio y suspendido es `warning`.
  static AppSeverityStyle forTallerEstado(
    String estado,
    AppColors colors, {
    required String pendienteLabel,
    required String aprobadoLabel,
    required String rechazadoLabel,
    required String suspendidoLabel,
  }) => switch (estado.trim().toLowerCase()) {
    'aprobado' => AppSeverityStyle(
      color: colors.success,
      icon: Icons.verified_rounded,
      label: aprobadoLabel,
    ),
    'rechazado' => AppSeverityStyle(
      color: colors.error,
      icon: Icons.cancel_rounded,
      label: rechazadoLabel,
    ),
    'suspendido' => AppSeverityStyle(
      color: colors.warning,
      icon: Icons.pause_circle_rounded,
      label: suspendidoLabel,
    ),
    _ => AppSeverityStyle(
      color: colors.primary,
      icon: Icons.hourglass_top_rounded,
      label: pendienteLabel,
    ),
  };

  /// Gravedad de una accion de auditoria. La cadena viene del backend con
  /// forma `VERBO_OBJETO` (`SUSPENDER_TALLER`, `CREAR_USUARIO`).
  ///
  /// El criterio de «destructiva» es el que ya usaba
  /// `admin_dashboard_screen` (SUSPENDER / ELIMINAR / RECHAZAR); esta
  /// funcion lo convierte en la unica definicion, en vez de tener dos
  /// pantallas pintando el mismo log de dos colores.
  static AppSeverityStyle forLogAccion(
    String accion,
    AppColors colors, {
    required String destructivaLabel,
    required String creacionLabel,
    required String modificacionLabel,
    required String consultaLabel,
  }) {
    final a = accion.toUpperCase();
    if (a.contains('SUSPENDER') ||
        a.contains('ELIMINAR') ||
        a.contains('RECHAZAR')) {
      return AppSeverityStyle(
        color: colors.error,
        icon: Icons.warning_amber_rounded,
        label: destructivaLabel,
      );
    }
    if (a.contains('CREAR') || a.contains('APROBAR')) {
      return AppSeverityStyle(
        color: colors.success,
        icon: Icons.add_circle_outline_rounded,
        label: creacionLabel,
      );
    }
    if (a.contains('EDITAR') ||
        a.contains('ACTUALIZAR') ||
        a.contains('MODIFICAR')) {
      return AppSeverityStyle(
        color: colors.warning,
        icon: Icons.edit_outlined,
        label: modificacionLabel,
      );
    }
    return AppSeverityStyle(
      color: colors.primary,
      icon: Icons.visibility_outlined,
      label: consultaLabel,
    );
  }

  /// Cuenta administrativa activa o inactiva (`account_row`).
  static AppSeverityStyle forCuentaActiva(
    bool activa,
    AppColors colors, {
    required String activaLabel,
    required String inactivaLabel,
  }) => activa
      ? AppSeverityStyle(
          color: colors.success,
          icon: Icons.check_circle_outline_rounded,
          label: activaLabel,
        )
      : AppSeverityStyle(
          color: colors.error,
          icon: Icons.block_rounded,
          label: inactivaLabel,
        );
```

> **Aviso sobre `colors.success` y el test de 3:1.** `AppPalette.lightSuccess #48BB78` mide **2,25:1** sobre `lightSurface`. La Fase 6 §18.3 lo dejó como bloqueo abierto y la Fase 7 lo confirmó. **El test del Step 2 fallará en el caso `aprobado`/`claro` mientras ese bloqueo siga abierto**, y fallará *correctamente*: el token está mal, no el mapeo.
>
> Dos salidas, y hay que elegir una **antes** de seguir a la Task 4:
>
> 1. **Cerrar el bloqueo** oscureciendo `lightSuccess` a ~`#2F855A` (mide 4,8:1). Es la recomendación de las Fases 6 y 7, ahora con un tercer consumidor pidiéndola. Toca `AppPalette`, así que necesita el visto bueno de marca (§19.4).
> 2. **Bajar el umbral del test a 2,2 para `success` en claro y dejarlo anotado.** Es honesto solo si va acompañado del punto 1 en el backlog, y **no** si el color acaba portando significado por sí solo — por eso todos los `AppSeverityStyle` llevan icono y etiqueta.
>
> No inventes un tercer camino ni escribas el test con un umbral que sabes que no se cumple sin decirlo.

- [ ] **Step 5: implementar el harness**

```dart
// test/support/admin_harness.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:autodoc/core/models/workshop_model.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/l10n/app_localizations.dart';

/// Monta un widget de `admin` con tema, idioma y ancho controlados.
///
/// **Siempre asienta.** `AppLocalizations` resuelve de forma asincrona: con
/// un solo `pump()` el primer frame se dibuja sin `Localizations` listo,
/// `context.l10n` devuelve `null` y cualquier widget del modulo revienta
/// con «Null check operator used on a null value» antes de llegar a la
/// primera asercion. Comprobado al medir la Fase 8 §0.2.
Future<void> pumpAdmin(
  WidgetTester tester,
  Widget child, {
  double width = 375,
  double height = 900,
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('es'),
  List<SingleChildWidget> providers = const [],
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MultiProvider(
      providers: [...providers],
      child: MaterialApp(
        theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Igual que [pumpAdmin] pero devuelve **todos** los errores de layout.
///
/// `tester.takeException()` solo devuelve el primero, y `TallerAdminCard`
/// produce **dos** desbordamientos simultaneos (§0.2): sin esto no se puede
/// afirmar cuantos quedan ni de que tamano.
Future<List<FlutterErrorDetails>> pumpAdminCollecting(
  WidgetTester tester,
  Widget child, {
  double width = 375,
  double height = 900,
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('es'),
  List<SingleChildWidget> providers = const [],
}) async {
  final captured = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = captured.add;
  try {
    await pumpAdmin(
      tester,
      child,
      width: width,
      height: height,
      brightness: brightness,
      locale: locale,
      providers: providers,
    );
  } finally {
    FlutterError.onError = previous;
  }
  return captured;
}

/// Pixeles de un desbordamiento, o `null` si el error es de otro tipo.
double? overflowPixels(FlutterErrorDetails details) {
  final match = RegExp(
    r'overflowed by ([\d.]+) pixels',
  ).firstMatch(details.exception.toString());
  return match == null ? null : double.parse(match.group(1)!);
}

/// Taller de prueba. `WorkshopModel` **no** es `const` (comprobado), asi
/// que este helper no puede serlo tampoco.
WorkshopModel testTaller({
  String id = 't-1',
  String nombre = 'Taller Mecánico Central de la Ciudad Capital',
  String estado = 'pendiente',
  String? especialidad = 'Transmisiones automáticas',
  String? municipio = 'San Salvador',
  String? departamento = 'San Salvador',
  String? telefono = '+503 2222 3333',
  double calificacion = 4.5,
}) => WorkshopModel(
  idTaller: id,
  nombre: nombre,
  estado: estado,
  especialidad: especialidad,
  ubicacionMunicipio: municipio,
  departamento: departamento,
  telefono: telefono,
  calificacionPromedio: calificacion,
);
```

> Los valores por defecto de `testTaller` **no son cómodos, son adversariales**: son exactamente los que provocan los desbordamientos medidos en §0.2. Un helper que devuelva `'Taller A'` con especialidad `'General'` haría pasar la Task 4 sin arreglar nada.
>
> `FakeAdminProvider` y `FakeAdminDashboardProvider` se añaden aquí con la misma regla de la Fase 6 y 7: **`implements`, no `extends`**, porque los providers reales construyen servicios que tocan Firebase en el constructor. Lee `admin_provider.dart` y `admin_dashboard_provider.dart` antes de escribirlos y limita el doble a la superficie que las pantallas consumen (`talleres`, `mecanicos`, `logs`, `isLoading`, `error`, `metrics`, `fetchAllData`, `fetchLogs`, `fetchMetrics`, y las cuatro acciones de taller).

- [ ] **Step 6: correr y confirmar verde**

```bash
flutter test test/core/theme/ test/support/
```

- [ ] **Step 7: cerrar**

```bash
dart format . && dart fix --apply && flutter analyze && flutter test
```

**Commit:** `feat(app-severity): forTallerEstado, forLogAccion y forCuentaActiva; harness de tests de admin`

---

## 3. Task 2: `admin_seed_screen` — la más barata, y un callejón sin salida

**Files:**
- Modify: `lib/features/admin/presentation/pages/admin_seed_screen.dart`
- Test: `test/features/admin/presentation/pages/admin_seed_screen_test.dart`

**Interfaces:**
- Consumes: `AppTextStyles`; `AppSpacing`; `context.appColors`; `AppBreakpoints.maxReadingWidth` (Fase 1 Task 1); `AppPageBody` (Fase 1 Task 5); `pumpAdmin`, `pumpAdminCollecting` (Task 1).
- Produces: nada público nuevo.

60 líneas. El maestro dice *"Solo tokenizar y garantizar que no rompe a 320 px. Mínimo esfuerzo justificado."* — y tiene razón, con una excepción que el maestro no vio: **desde esta pantalla no se puede volver** (§0.5.3). Las otras cinco páginas montan `drawer: const AdminSidebar()`; esta no.

Además: 2 colores literales (`Colors.green` en el icono de 80 px, `Colors.grey[700]` en el cuerpo), 2 `GoogleFonts.inter` con tamaños 24 y 16 literales, y dos cadenas en español (`'Migración Completada'` y el párrafo) en una pantalla que sí usa `context.l10n` para las otras tres.

- [ ] **Step 1: escribir el test que falla**

```dart
// test/features/admin/presentation/pages/admin_seed_screen_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/features/admin/presentation/pages/admin_seed_screen.dart';

import '../../../../support/admin_harness.dart';
import '../../../../support/responsive_harness.dart';

void main() {
  testWidgets('tiene cajon de navegacion, como las otras cinco paginas', (
    tester,
  ) async {
    await pumpAdmin(tester, const AdminSeedScreen(), width: 375);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).last);
    expect(
      scaffold.drawer,
      isNotNull,
      reason: '/admin/seed es un callejon sin salida sin el cajon',
    );
  });

  testWidgets('no desborda en ningun ancho auditado ni idioma', (tester) async {
    for (final locale in const <Locale>[Locale('es'), Locale('en')]) {
      for (final width in kAuditWidths) {
        final errors = await pumpAdminCollecting(
          tester,
          const AdminSeedScreen(),
          width: width,
          locale: locale,
        );
        expect(errors, isEmpty, reason: 'desborda a $width en $locale');
      }
    }
  });

  testWidgets('cero literales de color y de fuente', (tester) async {
    final source = File(
      'lib/features/admin/presentation/pages/admin_seed_screen.dart',
    ).readAsStringSync();
    expect(source.contains('GoogleFonts'), isFalse);
    expect(RegExp(r'Colors\.(green|grey)').hasMatch(source), isFalse);
    expect(RegExp(r'fontSize:\s*\d').hasMatch(source), isFalse);
  });
}
```

> **Nota sobre el test del cajón.** `pumpAdmin` envuelve el hijo en su propio `Scaffold`, así que `find.byType(Scaffold).last` puede devolver el del harness en vez del de la pantalla. Comprueba el orden al ejecutar; si hace falta, usa `find.descendant` desde `find.byType(AdminSeedScreen)`. **No cambies el harness para acomodar este test** — otras once tareas dependen de él.

- [ ] **Step 2: correr y confirmar el fallo exacto**

```bash
flutter test test/features/admin/presentation/pages/admin_seed_screen_test.dart
```

Expected: `/admin/seed es un callejon sin salida sin el cajon` — `Expected: not null / Actual: <null>`. Y `Expected: <false> / Actual: <true>` para `GoogleFonts`.

- [ ] **Step 3: implementar**

```dart
  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    if (!kDebugMode) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.adminAccessDenied)),
        // El cajon tambien aqui: sin el, un administrador que llegue a esta
        // ruta en produccion se queda encerrado en «acceso denegado».
        drawer: const AdminSidebar(),
        body: Center(child: Text(context.l10n.adminAccessDeniedDesc)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.adminConfigAdmins),
        centerTitle: true,
      ),
      drawer: const AdminSidebar(),
      body: AppPageBody(
        maxWidth: AppBreakpoints.maxReadingWidth,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.security,
                  size: 80,
                  color: colors.success,
                  semanticLabel: 'Migración completada',
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Migración Completada',
                  style: AppTextStyles.headlineSmall.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.base),
                Text(
                  'Las cuentas administrativas ya fueron configuradas y los '
                  'secretos se eliminaron del código fuente por motivos de '
                  'seguridad.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
```

`Responsive.padding`, `Responsive.iconSize` y `Responsive.fontSize` desaparecen: `AppPageBody` acota el ancho y los tokens dan el resto. El icono es decorativo pero **grande y con significado** (confirma el estado), así que lleva `semanticLabel` en vez de `ExcludeSemantics`.

- [ ] **Step 4: correr y confirmar verde**

```bash
flutter test test/features/admin/
```

- [ ] **Step 5: cerrar**

```bash
dart format . && dart fix --apply && flutter analyze && flutter test
```

**Commit:** `fix(admin-seed): tokenizar y dar cajon de navegacion a la pantalla que no tenia salida`

---

## 4. Task 3: `AdminSidebar` — el shell duplicado seis veces, y la paleta bifurcada en una línea

**Files:**
- Modify: `lib/features/admin/presentation/widgets/admin_sidebar.dart`
- Test: `test/features/admin/presentation/widgets/admin_sidebar_test.dart`

**Interfaces:**
- Consumes: `AppSeverity.forLogAccion` **no**; `context.appColors`; `AppTextStyles`; `AppSpacing`; `AppMotion` (Fase 1 Task 2); `pumpAdmin` (Task 1).
- Produces: nada público nuevo.

**Cinco colores literales y un `Color(0xFF522C81)`.** Ese último ([L50](../../../lib/features/admin/presentation/widgets/admin_sidebar.dart#L50)) es una copia exacta de `AppPalette.lightPrimary`, y el defecto que provoca está medido:

El encabezado pinta un degradado de `Theme.of(context).colorScheme.primary`, con `CircleAvatar(backgroundColor: Colors.white)` y dentro `Icon(color: Color(0xFF522C81))`.

| Tema | Degradado | Icono del avatar | Nombre del admin |
|---|---|---|---|
| claro | `#522C81` morado | `#522C81` morado ✓ | `Colors.white` — **10,32:1** ✓ |
| **oscuro** | `#81E6D9` teal | `#522C81` morado, **descolgado del tema** | `Colors.white` — **1,47:1** ✗ |
| oscuro | | | subtítulo `white @ 0.8` — **1,31:1** ✗ |

Es el mismo par que la Fase 5 corrigió en `mechanic_dashboard_screen` y la Fase 6 en las burbujas del chat. `colors.onPrimary` lo resuelve: 10,32:1 en claro y **12,12:1** en oscuro.

Y hay un elemento del cajón que en producción no lleva a ninguna parte: el que apunta a `/admin/seed`, protegida por `kDebugMode` (§0.5.3).

- [ ] **Step 1: invocar las skills**

`Skill(ui-ux-pro-max:ui-ux-pro-max)` — §Navigation: *"Current location must be visible"*. Comprueba si el cajón marca la ruta activa; si no, es parte de esta tarea.

- [ ] **Step 2: escribir el test que falla**

```dart
// test/features/admin/presentation/widgets/admin_sidebar_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/features/admin/presentation/widgets/admin_sidebar.dart';

import '../../../../support/contrast.dart';
import '../../../../support/admin_harness.dart';

void main() {
  testWidgets('el encabezado se lee en los dos temas', (tester) async {
    for (final brightness in Brightness.values) {
      await pumpAdmin(
        tester,
        const AdminSidebar(),
        width: 375,
        brightness: brightness,
      );
      final context = tester.element(find.byType(AdminSidebar));
      final colors = context.appColors;

      final nombre = tester.widget<Text>(
        find.byKey(const ValueKey('admin-sidebar-name')),
      );
      expect(
        contrastRatio(nombre.style!.color!, colors.primary),
        greaterThanOrEqualTo(4.5),
        reason: 'nombre del admin ilegible en $brightness',
      );

      final correo = tester.widget<Text>(
        find.byKey(const ValueKey('admin-sidebar-email')),
      );
      expect(
        contrastRatio(
          composite(correo.style!.color!, colors.primary),
          colors.primary,
        ),
        greaterThanOrEqualTo(4.5),
        reason: 'correo del admin ilegible en $brightness',
      );
    }
  });

  testWidgets('el avatar sigue al tema, no a un literal', (tester) async {
    final source = File(
      'lib/features/admin/presentation/widgets/admin_sidebar.dart',
    ).readAsStringSync();
    expect(
      source.contains('Color(0x'),
      isFalse,
      reason: 'sigue la copia literal de AppPalette.lightPrimary',
    );
    expect(RegExp(r'Colors\.(white|red)').hasMatch(source), isFalse);
  });

  testWidgets('todos los elementos del cajon miden 48 dp', (tester) async {
    await pumpAdmin(tester, const AdminSidebar(), width: 375);
    for (final tile in find.byType(ListTile).evaluate()) {
      final size = (tile.renderObject as RenderBox).size;
      expect(size.height, greaterThanOrEqualTo(48));
    }
  });

  testWidgets('en release no se ofrece la pantalla de semilla', (tester) async {
    final source = File(
      'lib/features/admin/presentation/widgets/admin_sidebar.dart',
    ).readAsStringSync();
    expect(
      source.contains('kDebugMode'),
      isTrue,
      reason: 'el enlace a /admin/seed se ofrece siempre y en release '
          'siempre responde «acceso denegado»',
    );
  });
}
```

- [ ] **Step 3: correr y confirmar el fallo exacto**

```bash
flutter test test/features/admin/presentation/widgets/admin_sidebar_test.dart
```

Expected:

1. `Found 0 widgets with key [<'admin-sidebar-name'>]`.
2. Tras las claves, en oscuro el contraste del nombre será **1.47** contra `greaterThanOrEqualTo(4.5)`.
3. `sigue la copia literal de AppPalette.lightPrimary`.
4. `el enlace a /admin/seed se ofrece siempre…`.

- [ ] **Step 4: implementar**

```dart
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.xl,
                horizontal: AppSpacing.lg,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colors.primary,
                    colors.primary.withValues(alpha: 0.8),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: colors.onPrimary.withValues(alpha: 0.24),
                      shape: BoxShape.circle,
                    ),
                    child: CircleAvatar(
                      radius: 35,
                      backgroundColor: colors.onPrimary,
                      child: Icon(
                        Icons.admin_panel_settings,
                        size: 40,
                        // Antes: `Color(0xFF522C81)`, una copia literal de
                        // AppPalette.lightPrimary que en tema oscuro dejaba
                        // un icono morado sobre un degradado teal.
                        color: colors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.base),
                  Text(
                    user?.nombreCompleto ?? 'Administrador',
                    key: const ValueKey('admin-sidebar-name'),
                    style: AppTextStyles.titleLarge.copyWith(
                      color: colors.onPrimary,
                    ),
                  ),
                  Text(
                    user?.correo ?? '',
                    key: const ValueKey('admin-sidebar-email'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium.copyWith(
                      // Antes `white @ 0.8` (1,31:1 en oscuro). Sin opacidad:
                      // si visualmente pesa demasiado, baja el tamano, no el
                      // contraste.
                      color: colors.onPrimary,
                    ),
                  ),
                ],
              ),
            ),
```

**El avatar con `backgroundColor: colors.onPrimary` e icono `colors.primary`** invierte el par correctamente en los dos temas: en oscuro queda un círculo oscuro con icono teal sobre el degradado teal — legible, y coherente con la marca.

El `maxLines: 1` + `ellipsis` en el correo no es decorativo: un correo largo en un cajón de 304 px de ancho desborda.

Y el elemento de semilla:

```dart
            if (kDebugMode)
              _buildDrawerItem(
                context,
                icon: Icons.security,
                title: context.l10n.adminConfigAdmins,
                route: '/admin/seed',
              ),
```

con `import 'package:flutter/foundation.dart';`. Es la misma guarda que ya tiene la pantalla; llevarla también al menú evita ofrecer una puerta cerrada.

El `Colors.red` de [L135](../../../lib/features/admin/presentation/widgets/admin_sidebar.dart#L135) —el elemento de cerrar sesión— pasa a `colors.error`.

- [ ] **Step 5: marcar la ruta activa**

Si el cajón no destaca la ruta actual, añádelo ahora — es la mitad de una barra de navegación y el maestro §2 no lo cubre, pero `ui-ux-pro-max` §Navigation sí:

```dart
  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String route,
  }) {
    final colors = context.appColors;
    final isActive = GoRouterState.of(context).uri.path == route;

    return ListTile(
      selected: isActive,
      selectedTileColor: colors.primary.withValues(alpha: 0.1),
      leading: Icon(icon, color: isActive ? colors.primary : colors.textSecondary),
      title: Text(
        title,
        style: AppTextStyles.bodyLarge.copyWith(
          color: isActive ? colors.primary : colors.textPrimary,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        if (!isActive) context.go(route);
      },
    );
  }
```

`selected:` de `ListTile` ya emite la semántica correcta, así que el lector de pantalla anuncia cuál está activo sin `Semantics` extra. Y el `if (!isActive)` evita reconstruir la pantalla en la que ya estás.

- [ ] **Step 6: correr y cerrar**

```bash
flutter test test/features/admin/
dart format . && dart fix --apply && flutter analyze && flutter test
```

**Commit:** `fix(admin-sidebar): 1,47:1 en oscuro, quitar la copia literal de la paleta y marcar la ruta activa`

---

## 5. Task 4: `TallerAdminCard` — los dos desbordamientos y el semáforo

**Files:**
- Modify: `lib/features/admin/presentation/widgets/taller_admin_card.dart`
- Test: `test/features/admin/presentation/widgets/taller_admin_card_test.dart`

**Interfaces:**
- Consumes: `AppSeverity.forTallerEstado` (Task 1); `AppStatusBadge` (Fase 3 Task 7 / existente); `AppButton`, `AppButtonType` (Fase 3 Task 1); `AppCard` (Fase 3 Task 2); `context.appColors`; `AppTextStyles`; `pumpAdmin`, `pumpAdminCollecting`, `testTaller`, `overflowPixels` (Task 1).
- Produces: nada público nuevo.

**Es la tarea central de la fase.** La tarjeta con la que se aprueba o rechaza un taller desborda **dos veces en todos los teléfonos** (§0.2) y concentra **14 de los 54 colores literales** del módulo.

Criterio de aceptación, medido: de `125 + 146` px a 320 y `70 + 91` a 375, a **cero** en los ocho anchos auditados.

- [ ] **Step 1: invocar las skills**

`Skill(ui-ux-pro-max:ui-ux-pro-max)` — §Layout: *"Never put a fixed-width Row of buttons in a card"*; §Interaction: *"Destructive actions need visual separation from constructive ones"*. Anota lo segundo: esta tarjeta tiene *Aprobar* y *Rechazar* uno al lado del otro con el mismo peso.

`Skill(emil-design-eng)` — sobre el cambio de estado tras aprobar: la tarjeta cambia de color y de botones. Anota si ese cambio debe animar y con qué duración.

- [ ] **Step 2: escribir el test que falla**

```dart
// test/features/admin/presentation/widgets/taller_admin_card_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/features/admin/presentation/widgets/taller_admin_card.dart';

import '../../../../support/admin_harness.dart';
import '../../../../support/responsive_harness.dart';

void main() {
  Widget card({String estado = 'pendiente'}) => TallerAdminCard(
    taller: testTaller(estado: estado),
    onAprobar: () {},
    onRechazar: () {},
    onSuspender: () {},
  );

  testWidgets('CERO desbordamientos en los ocho anchos y los cuatro estados', (
    tester,
  ) async {
    for (final estado in const [
      'pendiente',
      'aprobado',
      'rechazado',
      'suspendido',
    ]) {
      for (final width in kAuditWidths) {
        final errors = await pumpAdminCollecting(
          tester,
          card(estado: estado),
          width: width,
        );
        expect(
          errors,
          isEmpty,
          reason:
              'TallerAdminCard desborda a $width px en estado $estado: '
              '${errors.map(overflowPixels).toList()}',
        );
      }
    }
  });

  testWidgets('los chips de informacion truncan en vez de desbordar', (
    tester,
  ) async {
    await pumpAdmin(tester, card(), width: 320);
    final chip = find.byKey(const ValueKey('taller-chip-especialidad'));
    expect(chip, findsOneWidget);
    final text = tester.widget<Text>(
      find.descendant(of: chip, matching: find.byType(Text)),
    );
    expect(text.overflow, TextOverflow.ellipsis);
    expect(text.maxLines, 1);
  });

  testWidgets('las acciones se apilan cuando no caben', (tester) async {
    await pumpAdmin(tester, card(), width: 320);
    // Un Wrap, no un Row: a 320 px tres botones no caben en una linea.
    expect(find.byKey(const ValueKey('taller-actions')), findsOneWidget);
    expect(
      tester.widget(find.byKey(const ValueKey('taller-actions'))),
      isA<Wrap>(),
    );
  });

  testWidgets('el estado se anuncia con texto e icono, no solo con color', (
    tester,
  ) async {
    for (final estado in const ['pendiente', 'aprobado', 'suspendido']) {
      await pumpAdmin(tester, card(estado: estado), width: 375);
      final badge = find.byKey(const ValueKey('taller-status'));
      expect(badge, findsOneWidget);
      expect(
        find.descendant(of: badge, matching: find.byType(Icon)),
        findsOneWidget,
        reason: '$estado no tiene icono: el color es el unico indicador',
      );
    }
  });

  testWidgets('cero colores literales', (tester) async {
    final source = File(
      'lib/features/admin/presentation/widgets/taller_admin_card.dart',
    ).readAsStringSync();
    final offenders = RegExp(
      r'Colors\.(white|black|grey|green|red|orange|blue)',
    ).allMatches(source).map((m) => m.group(0)).toList();
    expect(offenders, isEmpty, reason: 'quedan: $offenders');
  });
}
```

- [ ] **Step 3: correr y confirmar el fallo exacto**

```bash
flutter test test/features/admin/presentation/widgets/taller_admin_card_test.dart
```

Expected, en este orden:

1. `TallerAdminCard desborda a 320.0 px en estado pendiente: [125.0, 146.0]` — los dos de §0.2, con sus píxeles.
2. `Found 0 widgets with key [<'taller-chip-especialidad'>]`.
3. `type 'Row' is not a subtype of type 'Wrap'`.
4. `quedan: [Colors.green, Colors.red, Colors.grey, Colors.orange, …]` — **14** entradas.

- [ ] **Step 4: implementar**

**4a. El estado sale de `AppSeverity`.** Las seis líneas del ternario anidado ([L21-27](../../../lib/features/admin/presentation/widgets/taller_admin_card.dart#L21-L27)) se sustituyen por:

```dart
    final colors = context.appColors;
    final severity = AppSeverity.forTallerEstado(
      taller.estado,
      colors,
      pendienteLabel: context.l10n.adminStatusPending,
      aprobadoLabel: context.l10n.adminStatusApproved,
      rechazadoLabel: context.l10n.adminStatusRejected,
      suspendidoLabel: context.l10n.adminStatusSuspended,
    );
```

> **Comprueba primero qué claves existen.** El ARB ya tiene `adminApproveAccount`, `adminSuspendAccount`, `adminReactivateAccount` y otras del módulo. Si no hay claves de estado, §1.4 impide crearlas: usa los literales que la tarjeta ya muestra hoy y anótalo en §18.1. **No inventes nombres de clave que no existen** — el análisis fallaría a la compilación y parecería un fallo del plan.

Y el chip de estado pasa a `AppStatusBadge`:

```dart
                AppStatusBadge(
                  key: const ValueKey('taller-status'),
                  label: severity.label,
                  icon: severity.icon,
                  color: severity.color,
                ),
```

**4b. El chip que desborda 125 px.** `_buildInfoChip` se reescribe con la única línea que faltaba:

```dart
  Widget _buildInfoChip(
    BuildContext context, {
    required Key key,
    required IconData icon,
    required String label,
  }) {
    final colors = context.appColors;
    return ConstrainedBox(
      key: key,
      // El chip no puede crecer sin limite: `especialidad`, `municipio` y
      // `telefono` salen de datos de usuario y no tienen longitud acotada.
      constraints: const BoxConstraints(maxWidth: 220),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: colors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: colors.textSecondary),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.labelMedium.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
```

`Flexible` + `ellipsis` es lo que elimina los 125 px; el `maxWidth: 220` evita que un solo chip acapare toda la fila del `Wrap` en pantallas anchas.

**4c. El `Row` de acciones que desborda 146 px.** Pasa a `Wrap`:

```dart
            Wrap(
              key: const ValueKey('taller-actions'),
              alignment: WrapAlignment.end,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (taller.estado == 'pendiente') ...[
                  AppButton(
                    text: context.l10n.adminReject,
                    type: AppButtonType.text,
                    onPressed: onRechazar,
                  ),
                  AppButton(
                    text: context.l10n.adminApprove,
                    onPressed: onAprobar,
                  ),
                ] else if (taller.estado == 'aprobado')
                  AppButton(
                    text: context.l10n.adminSuspend,
                    type: AppButtonType.secondary,
                    onPressed: onSuspender,
                  )
                else
                  AppButton(
                    text: context.l10n.adminApprove,
                    onPressed: onAprobar,
                  ),
              ],
            ),
```

> **La lógica de qué botón aparece en qué estado es la de hoy**, leída de [L74-130](../../../lib/features/admin/presentation/widgets/taller_admin_card.dart#L74-L130). Cópiala del fichero, no de este bloque: §1.5 y §2 del maestro prohíben cambiar el comportamiento, y aquí «comportamiento» incluye qué acciones se ofrecen.
>
> **Y fíjate en el orden:** *Rechazar* primero como `text`, *Aprobar* después como primario. Hoy son `ElevatedButton(backgroundColor: Colors.green)` y `OutlinedButton(foregroundColor: Colors.red)` con el mismo peso visual, uno al lado del otro. La regla de `ui-ux-pro-max` que anotaste en el Step 1 pide separar la acción destructiva de la constructiva; ponerla como `text` a la izquierda es la forma barata de hacerlo sin inventar una variante `danger` que `AppButton` no tiene (§19.4).

**4d. El resto.** `Card` → `AppCard`; los `TextStyle` con `fontSize: 20/13` literales → `AppTextStyles.titleLarge` / `labelMedium`; `Colors.grey[100]` → `colors.surfaceVariant`; `Colors.grey[600]/[800]` → `colors.textSecondary` / `textPrimary`.

- [ ] **Step 5: correr y confirmar verde**

```bash
flutter test test/features/admin/
```

- [ ] **Step 6: cerrar**

```bash
dart format . && dart fix --apply && flutter analyze && flutter test
```

**Commit:** `fix(taller-admin-card): eliminar los dos overflows de todo ancho de telefono y tokenizar el semaforo de estado`

---

## 6. Task 5: `MecanicoAdminCard`, `AccountRow` y `dialog_crear_usuario`

**Files:**
- Modify: `lib/features/admin/presentation/widgets/mecanico_admin_card.dart`
- Modify: `lib/features/admin/presentation/widgets/account_row.dart`
- Modify: `lib/features/admin/presentation/widgets/dialog_crear_usuario.dart`
- Test: `test/features/admin/presentation/widgets/admin_rows_test.dart`

**Interfaces:**
- Consumes: `AppSeverity.forCuentaActiva` (Task 1); `AppStatusBadge`; `context.appColors`; `AppTextStyles`; `pumpAdmin`, `pumpAdminCollecting` (Task 1).
- Produces: nada público nuevo.

11 colores literales entre los tres, todos de estado o de gris.

**Los tres defectos concretos:**

1. **`AccountRow` pinta el mismo concepto de dos formas.** La insignia de estado usa `Colors.green @ 0.2` de fondo con `Colors.green[800]` de texto ([L67-76](../../../lib/features/admin/presentation/widgets/account_row.dart#L67-L76)) — que contrasta bien —, pero los elementos del menú emergente usan `Colors.green` y `Colors.red` **planos sobre la superficie del menú** ([L100-129](../../../lib/features/admin/presentation/widgets/account_row.dart#L100-L129)): `#4CAF50` sobre `lightSurface` da **2,78:1** y `#F44336` da **3,76:1**. Los dos por debajo de 4,5:1 para texto de cuerpo.
2. **Una opción del menú está sin localizar.** Cuatro de las cinco usan `context.l10n`; `'Eliminar cuenta (permanente)'` ([L127](../../../lib/features/admin/presentation/widgets/account_row.dart#L127)) es literal — y es justo la más peligrosa.
3. **Texto de 10 px.** Las dos insignias de `AccountRow` ([L56](../../../lib/features/admin/presentation/widgets/account_row.dart#L56), [L77](../../../lib/features/admin/presentation/widgets/account_row.dart#L77)) usan `fontSize: 10`. Es el texto más pequeño de la aplicación y es el que dice si una cuenta está suspendida.

- [ ] **Step 1: escribir el test que falla**

```dart
// test/features/admin/presentation/widgets/admin_rows_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/features/admin/presentation/widgets/account_row.dart';

import '../../../../support/contrast.dart';
import '../../../../support/admin_harness.dart';

void main() {
  testWidgets('las opciones del menu cumplen 4,5:1 en ambos temas', (
    tester,
  ) async {
    for (final brightness in Brightness.values) {
      await pumpAdmin(
        tester,
        AccountRow(
          usuario: testAdminUser(estado: 'activo'),
          isCurrentAdmin: false,
          canHardDelete: true,
          onAprobar: () {},
          onSuspender: () {},
          onReactivar: () {},
          onCambiarRol: () {},
          onEliminar: () {},
        ),
        width: 375,
        brightness: brightness,
      );
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AccountRow));
      final colors = context.appColors;
      for (final text in tester.widgetList<Text>(
        find.descendant(
          of: find.byType(PopupMenuItem<String>),
          matching: find.byType(Text),
        ),
      )) {
        final color = text.style?.color;
        if (color == null) continue;
        expect(
          contrastRatio(color, colors.surfaceContainer),
          greaterThanOrEqualTo(4.5),
          reason: '"${text.data}" ilegible en $brightness',
        );
      }
    }
  });

  testWidgets('ninguna insignia usa texto por debajo de 12 px', (tester) async {
    final sources = <String>[
      'lib/features/admin/presentation/widgets/account_row.dart',
      'lib/features/admin/presentation/widgets/mecanico_admin_card.dart',
      'lib/features/admin/presentation/widgets/dialog_crear_usuario.dart',
    ];
    for (final path in sources) {
      final source = File(path).readAsStringSync();
      final tiny = RegExp(r'fontSize:\s*(\d+)').allMatches(source).where((m) {
        return int.parse(m.group(1)!) < 12;
      });
      expect(tiny, isEmpty, reason: '$path tiene texto de menos de 12 px');
    }
  });

  testWidgets('cero colores literales en los tres widgets', (tester) async {
    for (final path in const <String>[
      'lib/features/admin/presentation/widgets/account_row.dart',
      'lib/features/admin/presentation/widgets/mecanico_admin_card.dart',
      'lib/features/admin/presentation/widgets/dialog_crear_usuario.dart',
    ]) {
      final source = File(path).readAsStringSync();
      final offenders = RegExp(
        r'Colors\.(white|black|grey|green|red|orange|blue)',
      ).allMatches(source).map((m) => m.group(0)).toList();
      expect(offenders, isEmpty, reason: '$path: $offenders');
    }
  });

  testWidgets('la opcion de borrado permanente esta localizada', (tester) async {
    final source = File(
      'lib/features/admin/presentation/widgets/account_row.dart',
    ).readAsStringSync();
    expect(source.contains("'Eliminar cuenta (permanente)'"), isFalse);
  });
}
```

> `testAdminUser` no existe todavía. Añádelo al harness de la Task 1 con la misma forma que `testTaller`, leyendo primero qué modelo espera `AccountRow` (`UserModel` o uno propio del módulo).

- [ ] **Step 2: correr y confirmar el fallo exacto**

```bash
flutter test test/features/admin/presentation/widgets/admin_rows_test.dart
```

Expected: `"Suspender cuenta" ilegible en Brightness.light` con **2.78**; `account_row.dart tiene texto de menos de 12 px`; y la lista de 11 literales.

- [ ] **Step 3: implementar**

`AccountRow`: la insignia de estado pasa por `AppSeverity.forCuentaActiva` + `AppStatusBadge`; las opciones del menú usan `colors.error` para las destructivas y `colors.textPrimary` para el resto — **no** `colors.success` para *Aprobar*, porque ese token mide 2,25:1 en claro (§19.4) y aquí sería texto de cuerpo. El icono de cada opción porta el significado:

```dart
          if (usuario.estado != 'activo' && usuario.estado != 'suspendido')
            PopupMenuItem(
              value: 'aprobar',
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, color: colors.success),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    context.l10n.adminApproveAccount,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
```

> **El patrón «icono con color semántico + texto con color de cuerpo» resuelve el conflicto de fondo de toda la app**: el color sigue comunicando y el texto sigue siendo legible. Es la misma solución que la Fase 6 Task 8 adoptó cuando midió que `lightSuccess` no llega a 3:1.

Las dos insignias suben de `fontSize: 10` a `AppTextStyles.labelSmall`. `'Eliminar cuenta (permanente)'` se cablea a la clave del ARB si existe; si no, se queda literal y va a §18.1 — pero **con el color y el icono arreglados igualmente**.

`MecanicoAdminCard` y `dialog_crear_usuario`: sus 3 `Colors.grey` pasan a `colors.textSecondary`, y `GoogleFonts` a `AppTextStyles`.

- [ ] **Step 4: correr y cerrar**

```bash
flutter test test/features/admin/
dart format . && dart fix --apply && flutter analyze && flutter test
```

**Commit:** `fix(admin-widgets): contraste de las acciones de cuenta, semaforo tokenizado y texto minimo de 12 px`

---

## 7. Task 6: `MetricCard` — el quinto origen de color

**Files:**
- Modify: `lib/features/admin/presentation/widgets/metric_card.dart`
- Test: `test/features/admin/presentation/widgets/metric_card_test.dart`

**Interfaces:**
- Consumes: `context.appColors`; `AppTextStyles`; `AppCard` (Fase 3 Task 2); `AnimatedCounter` (Fase 3 Task 5); `pumpAdmin` (Task 1).
- Produces: `MetricCard` con un parámetro opcional nuevo `String? semanticLabel`.

**Cero colores literales, y aun así tres problemas de color:**

1. **`Theme.of(context).cardColor`** ([L21](../../../lib/features/admin/presentation/widgets/metric_card.dart#L21)) — el color de tarjeta del `ThemeData` base de Material, no `AppColors`. Es el mismo hallazgo que la Fase 7 hizo con los `ListTile` de `about_screen`: un origen de color que no es ni token ni literal, y que por tanto no sigue a la marca.
2. **`onSurface.withValues(alpha: 0.6)`** ([L73-75](../../../lib/features/admin/presentation/widgets/metric_card.dart#L73-L75)) para el título — texto secundario derivado por opacidad, exactamente lo que la Fase 7 Task 2 corrigió en el copyright de `about_screen` (donde medía 2,61:1). Aquí hay que **medirlo**, no asumirlo.
3. **`Icon(size: 100)` decorativo** ([L37-41](../../../lib/features/admin/presentation/widgets/metric_card.dart#L37-L41)) al 5 % de opacidad, sin `ExcludeSemantics`: un lector de pantalla lo recorre y no dice nada útil.

Más: 2 `GoogleFonts.inter` con `fontSize: 28` y `14` literales.

Y una oportunidad que el maestro no pidió pero que ya está construida: **`AnimatedCounter` existe** (Fase 3 Task 5) y esta tarjeta muestra seis números que llegan de golpe tras una carga. Es el caso de uso para el que se hizo.

- [ ] **Step 1: escribir el test que falla**

```dart
// test/features/admin/presentation/widgets/metric_card_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/features/admin/presentation/widgets/metric_card.dart';

import '../../../../support/contrast.dart';
import '../../../../support/admin_harness.dart';

void main() {
  testWidgets('el titulo de la metrica cumple 4,5:1 en ambos temas', (
    tester,
  ) async {
    for (final brightness in Brightness.values) {
      await pumpAdmin(
        tester,
        Builder(
          builder: (context) => SizedBox(
            width: 272,
            height: 170,
            child: MetricCard(
              title: 'Reseñas registradas',
              value: '1234',
              icon: Icons.rate_review,
              color: context.appColors.primary,
            ),
          ),
        ),
        width: 320,
        brightness: brightness,
      );

      final context = tester.element(find.byType(MetricCard));
      final colors = context.appColors;
      final title = tester.widget<Text>(find.text('Reseñas registradas'));
      expect(
        contrastRatio(
          composite(title.style!.color!, colors.surfaceContainer),
          colors.surfaceContainer,
        ),
        greaterThanOrEqualTo(4.5),
        reason: 'titulo de metrica ilegible en $brightness',
      );
    }
  });

  testWidgets('el icono decorativo no lo recorre el lector de pantalla', (
    tester,
  ) async {
    final source = File(
      'lib/features/admin/presentation/widgets/metric_card.dart',
    ).readAsStringSync();
    expect(source.contains('ExcludeSemantics'), isTrue);
    expect(source.contains('GoogleFonts'), isFalse);
    expect(source.contains('Theme.of(context).cardColor'), isFalse);
  });

  testWidgets('la tarjeta anuncia su metrica completa', (tester) async {
    final handle = tester.ensureSemantics();

    await pumpAdmin(
      tester,
      Builder(
        builder: (context) => SizedBox(
          width: 272,
          height: 170,
          child: MetricCard(
            title: 'Usuarios',
            value: '42',
            icon: Icons.people,
            color: context.appColors.primary,
            semanticLabel: 'Usuarios: 42',
          ),
        ),
      ),
      width: 320,
    );

    final node = tester.getSemantics(find.byType(MetricCard));
    expect(node.label, contains('42'));

    handle.dispose();
  });
}
```

> **`handle.dispose()` al final del cuerpo, no `addTearDown`.** Verificado en la Fase 7: `WidgetTester._verifySemanticsHandlesWereDisposed` corre **antes** que los *tear-downs*, así que `addTearDown(handle.dispose)` hace fallar el test con `A SemanticsHandle was active at the end of the test`.

- [ ] **Step 2: correr y confirmar el fallo exacto**

```bash
flutter test test/features/admin/presentation/widgets/metric_card_test.dart
```

Expected: el valor real del contraste del título (mídelo, no lo supongas); `Expected: <true> / Actual: <false>` para `ExcludeSemantics`; y `No named parameter with the name 'semanticLabel'`.

- [ ] **Step 3: implementar**

```dart
class MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  /// Lo que anuncia el lector de pantalla. Sin esto la tarjeta se lee como
  /// dos textos sueltos («42», «Usuarios») sin relacion entre si.
  final String? semanticLabel;

  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Semantics(
      label: semanticLabel ?? '$title: $value',
      child: ExcludeSemantics(
        child: AppCard(
          padding: EdgeInsets.zero,
          child: Stack(
            children: [
              Positioned(
                right: -20,
                top: -20,
                child: Icon(icon, size: 100, color: color.withValues(alpha: 0.05)),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Icon(icon, color: color, size: 24),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedCounter(
                          value: int.tryParse(value) ?? 0,
                          style: AppTextStyles.headlineSmall.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyMedium.copyWith(
                            // Antes: `onSurface` al 60 %. El texto secundario
                            // sale de su token, no de una opacidad.
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

> **`AnimatedCounter` solo si el valor es numérico.** `MetricCard` recibe `String value` porque el dashboard le pasa `'${provider.metrics['usuarios']}'`, que puede ser `'null'` si la métrica no llegó. El `int.tryParse(value) ?? 0` cubre ese caso — pero **comprueba antes qué muestra hoy la pantalla cuando `metrics` está vacío**: si hoy pinta `'null'` en pantalla, eso es un defecto aparte y lo arregla la Task 8, no esta.
>
> El par `Semantics` + `ExcludeSemantics` colapsa la tarjeta en un solo nodo con una frase completa, en vez de tres nodos sueltos.

- [ ] **Step 4: correr y cerrar**

```bash
flutter test test/features/admin/
dart format . && dart fix --apply && flutter analyze && flutter test
```

**Commit:** `fix(metric-card): tokens en vez de cardColor y opacidad, semantica de tarjeta y contador animado`

---

## 8. Task 7: los tres gráficos de `fl_chart`

**Files:**
- Modify: `lib/features/admin/presentation/widgets/services_trend_chart.dart`
- Modify: `lib/features/admin/presentation/widgets/user_growth_chart.dart`
- Modify: `lib/features/admin/presentation/widgets/workshops_growth_chart.dart`
- Test: `test/features/admin/presentation/widgets/chart_accessibility_test.dart`
- **No romper:** los tres tests existentes de estos ficheros

**Interfaces:**
- Consumes: `WindowClass`, `AppBreakpoints.of` (Fase 1 Task 1); `context.appColors`; `AppTextStyles`; `pumpAdmin` (Task 1).
- Produces: nada público nuevo.

**Los tres gráficos ya tienen tests, y buenos** — incluido uno de regresión sobre claves `yyyy-MM` con cero a la izquierda. Ninguno cubre lo que arregla esta tarea:

1. **`height: 250` fijo** en los tres. A 268 px de ancho (el caso de §0.3) un gráfico de 250 de alto con etiquetas de mes queda ilegible; a 1440 px de ancho sigue midiendo 250 y se ve aplastado.
2. **Sin alternativa textual.** `fl_chart` dibuja en un `CustomPaint`: para un lector de pantalla es un rectángulo vacío. La regla §10 de `ui-ux-pro-max` que el maestro cita para este módulo (*el color no puede ser el único portador de significado*) tiene aquí su caso más claro: **el gráfico entero no porta ningún significado accesible**.
3. **3 `GoogleFonts`** y tamaños de fuente literales en los ejes.

- [ ] **Step 1: invocar las skills**

`Skill(ui-ux-pro-max:ui-ux-pro-max)` — §Data visualization completa. Anota qué dice sobre altura relativa, leyendas y tabla equivalente.

- [ ] **Step 2: escribir el test que falla**

```dart
// test/features/admin/presentation/widgets/chart_accessibility_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/features/admin/presentation/widgets/services_trend_chart.dart';
import 'package:autodoc/features/admin/presentation/widgets/user_growth_chart.dart';
import 'package:autodoc/features/admin/presentation/widgets/workshops_growth_chart.dart';

import '../../../../support/admin_harness.dart';

void main() {
  final datos = <String, int>{'2026-05': 3, '2026-06': 7, '2026-07': 12};

  final graficos = <String, Widget Function()>{
    'servicios': () => ServicesTrendChart(serviciosPorMes: datos),
    'usuarios': () => UserGrowthChart(dataPorMes: datos),
    'talleres': () => WorkshopsGrowthChart(dataPorMes: datos),
  };

  graficos.forEach((nombre, build) {
    testWidgets('$nombre expone los datos como texto accesible', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await pumpAdmin(tester, build(), width: 375);
      final node = tester.getSemantics(
        find.byKey(const ValueKey('chart-summary')),
      );
      // El resumen debe nombrar el ultimo valor y la tendencia; sin esto
      // el grafico es un rectangulo vacio para un lector de pantalla.
      expect(node.label, contains('12'));

      handle.dispose();
    });

    testWidgets('$nombre crece de alto con la clase de ventana', (
      tester,
    ) async {
      await pumpAdmin(tester, build(), width: 375, height: 900);
      final estrecho = tester.getSize(find.byKey(const ValueKey('chart-area')));

      await pumpAdmin(tester, build(), width: 1440, height: 900);
      final ancho = tester.getSize(find.byKey(const ValueKey('chart-area')));

      expect(
        ancho.height,
        greaterThan(estrecho.height),
        reason: '$nombre sigue clavado en 250 px de alto',
      );
    });
  });
}
```

- [ ] **Step 3: correr y confirmar el fallo exacto**

```bash
flutter test test/features/admin/presentation/widgets/chart_accessibility_test.dart
```

Expected: `Found 0 widgets with key [<'chart-summary'>]` en los tres, y después `sigue clavado en 250 px de alto` con **250.0 == 250.0**.

- [ ] **Step 4: implementar**

Los tres ficheros comparten estructura, así que el cambio es el mismo tres veces. Si al hacerlo la duplicación te resulta evidente, **no la extraigas en esta tarea**: los tres tienen tests propios que asumen su tipo concreto y unificarlos es un refactor aparte (§18.3).

```dart
    final colors = context.appColors;
    final windowClass = AppBreakpoints.of(context);
    // Antes: `height: 250` fijo. Un grafico de tendencia necesita alto
    // proporcional al ancho disponible, no una constante.
    final chartHeight = switch (windowClass) {
      WindowClass.compact => 220.0,
      WindowClass.medium => 260.0,
      WindowClass.expanded => 300.0,
      WindowClass.large => 340.0,
    };
```

```dart
            SizedBox(
              key: const ValueKey('chart-area'),
              height: chartHeight,
              child: ExcludeSemantics(child: LineChart(/* … igual … */)),
            ),
            const SizedBox(height: AppSpacing.sm),
            // Alternativa textual: lo unico que un lector de pantalla puede
            // leer de un CustomPaint.
            Semantics(
              key: const ValueKey('chart-summary'),
              label: _resumenAccesible(context, datos),
              child: ExcludeSemantics(child: _buildLeyenda(context, colors)),
            ),
```

```dart
  /// Frase que resume la serie: ultimo valor, mes y direccion de la
  /// tendencia. Es lo que oye quien no puede ver el grafico.
  String _resumenAccesible(BuildContext context, Map<String, int> datos) {
    if (datos.isEmpty) return context.l10n.adminNoRecentActivity;
    final claves = datos.keys.toList()..sort();
    final ultimo = datos[claves.last]!;
    final anterior = claves.length > 1 ? datos[claves[claves.length - 2]]! : null;
    final tendencia = anterior == null
        ? ''
        : ultimo > anterior
        ? ', al alza'
        : ultimo < anterior
        ? ', a la baja'
        : ', sin cambios';
    return '${claves.last}: $ultimo$tendencia';
  }
```

> Las cadenas `', al alza'` / `', a la baja'` / `', sin cambios'` son literales en español. §1.4 prohíbe **claves de ARB**, no literales; van a §18.1 con el resto. Escribirlas en inglés sería peor: la mayoría de los administradores usan la consola en español.

Y `ExcludeSemantics` alrededor del `LineChart`/`BarChart` **es necesario**, no decorativo: sin él el lector recorre los nodos internos que `fl_chart` genera para los ejes y lee números sueltos sin contexto.

Los 3 `GoogleFonts` pasan a `AppTextStyles.labelSmall` en los títulos de eje.

- [ ] **Step 5: correr y confirmar verde**

```bash
flutter test test/features/admin/presentation/widgets/
```

Expected: los 6 nuevos en verde **y los 10 existentes de los tres gráficos intactos**. Ese es el criterio real de esta tarea: si alguno de los tests de `yyyy-MM` se rompe, has tocado la lógica de datos y no debías.

- [ ] **Step 6: cerrar**

```bash
dart format . && dart fix --apply && flutter analyze && flutter test
```

**Commit:** `feat(admin-charts): alto por WindowClass y resumen textual accesible de cada serie`

---

## 9. Task 8: `admin_dashboard_screen` — el cuarto sistema de breakpoints

**Files:**
- Modify: `lib/features/admin/presentation/pages/admin_dashboard_screen.dart`
- Test: `test/features/admin/presentation/pages/admin_dashboard_screen_test.dart`

**Interfaces:**
- Consumes: `WindowClass`, `AppBreakpoints.of`, `AppBreakpoints.gutter`, `AppBreakpoints.maxContentWidth` (Fase 1 Task 1); `AppGrid`, `AppPageBody` (Fase 1 Task 5); `AppSeverity.forLogAccion` (Task 1); `MetricCard` con `semanticLabel` (Task 6); `AppButton` (Fase 3 Task 1); `pumpAdmin`, `pumpAdminCollecting`, `FakeAdminDashboardProvider`, `FakeAdminProvider` (Task 1).
- Produces: nada público nuevo.

**Los cuatro problemas, medidos:**

1. **`MediaQuery…size.width` con cortes en 600 y 900** ([L221-222](../../../lib/features/admin/presentation/pages/admin_dashboard_screen.dart#L221-L222)) — el cuarto sistema de breakpoints de la app (§0.3), y el único que vive dentro de un solo fichero.
2. **La pantalla se contradice a sí misma a 600 px**: métricas en una columna (`600 > 600` es falso) y gráficos en dos (`600 < 600` también es falso). §0.3.
3. **`Colors.white` sobre `colors.primary`: 1,47:1 en oscuro**, y el subtítulo al 80 % a **1,31:1**. §0.5.5.
4. **`_buildActionChip` mide ~42 dp** de alto, por debajo del mínimo de 48. §0.5.7.

Más: sin `maxContentWidth` (a 1440 px el contenido ocupa los 1.392), 22 llamadas a `Responsive.*`, 2 `GoogleFonts`, y un `RefreshIndicator` que **no espera a las métricas** ([L91-94](../../../lib/features/admin/presentation/pages/admin_dashboard_screen.dart#L91-L94)): `provider.fetchMetrics()` se llama sin `await` mientras solo se espera a `fetchLogs()`, así que el indicador de recarga desaparece antes de que lleguen los datos que el usuario ha pedido recargar.

**El reparto de KPIs.** Son **6** `MetricCard`. El contrato del maestro (1/2/4) deja dos huérfanos; se corrige a **1/2/3/3** (§0.4.3), que además es lo que la pantalla ya hace hoy en la práctica.

- [ ] **Step 1: invocar las skills**

`Skill(ui-ux-pro-max:ui-ux-pro-max)` + `scripts/search.py "admin analytics dashboard" --stack flutter` — §Layout y §Data density.

`Skill(emil-design-eng)` — sobre el `RefreshIndicator` y la aparición de las seis métricas. Anota si el `AnimatedCounter` de la Task 6 debe escalonarse y con qué `staggerStep`.

- [ ] **Step 2: escribir el test que falla**

```dart
// test/features/admin/presentation/pages/admin_dashboard_screen_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/features/admin/presentation/pages/admin_dashboard_screen.dart';
import 'package:autodoc/features/admin/presentation/widgets/metric_card.dart';

import '../../../../support/contrast.dart';
import '../../../../support/admin_harness.dart';
import '../../../../support/responsive_harness.dart';

void main() {
  testWidgets('metricas y graficos usan LA MISMA escala de breakpoints', (
    tester,
  ) async {
    // A 600 px exactos la pantalla se contradecia: metricas en 1 columna
    // (`600 > 600` falso) y graficos en 2 (`600 < 600` tambien falso).
    await pumpAdmin(
      tester,
      const AdminDashboardScreen(),
      width: 600,
      height: 1400,
      providers: adminProviders(),
    );

    final tarjetas = find.byType(MetricCard);
    expect(tarjetas, findsNWidgets(6));

    // En `medium` (600-839) el contrato es 2 columnas para las metricas
    // Y una sola columna de graficos: son la misma clase de ventana.
    final primera = tester.getTopLeft(tarjetas.at(0));
    final segunda = tester.getTopLeft(tarjetas.at(1));
    expect(
      segunda.dy,
      primera.dy,
      reason: 'las metricas no estan en 2 columnas a 600 px',
    );

    final graficos = find.byKey(const ValueKey('admin-growth-charts'));
    expect(
      tester.widget(graficos),
      isA<Column>(),
      reason: 'los graficos van apilados hasta expanded',
    );
  });

  testWidgets('seis metricas, nunca cuatro columnas', (tester) async {
    // Con 6 tarjetas, 4 columnas dejan 2 huerfanas.
    for (final width in <double>[1200, 1440]) {
      await pumpAdmin(
        tester,
        const AdminDashboardScreen(),
        width: width,
        height: 1400,
        providers: adminProviders(),
      );
      final tarjetas = find.byType(MetricCard);
      final filaSuperior = <double>{};
      for (var i = 0; i < 6; i++) {
        filaSuperior.add(tester.getTopLeft(tarjetas.at(i)).dy);
      }
      expect(
        filaSuperior.length,
        2,
        reason: 'a $width px las 6 metricas deben caer en 2 filas de 3',
      );
    }
  });

  testWidgets('la cabecera se lee en los dos temas', (tester) async {
    for (final brightness in Brightness.values) {
      await pumpAdmin(
        tester,
        const AdminDashboardScreen(),
        width: 375,
        height: 1400,
        brightness: brightness,
        providers: adminProviders(),
      );
      final context = tester.element(find.byType(AdminDashboardScreen));
      final colors = context.appColors;

      final saludo = tester.widget<Text>(
        find.byKey(const ValueKey('admin-welcome-title')),
      );
      expect(
        contrastRatio(saludo.style!.color!, colors.primary),
        greaterThanOrEqualTo(4.5),
        reason: 'saludo ilegible en $brightness',
      );
    }
  });

  testWidgets('los accesos rapidos miden 48 dp', (tester) async {
    await pumpAdmin(
      tester,
      const AdminDashboardScreen(),
      width: 375,
      height: 1400,
      providers: adminProviders(),
    );
    for (final key in const <String>[
      'admin-action-usuarios',
      'admin-action-talleres',
      'admin-action-resenias',
      'admin-action-logs',
    ]) {
      expect(
        tester.getSize(find.byKey(ValueKey(key))).height,
        greaterThanOrEqualTo(48),
        reason: '$key es bajo',
      );
    }
  });

  testWidgets('no desborda en ningun ancho auditado', (tester) async {
    for (final width in kAuditWidths) {
      final errors = await pumpAdminCollecting(
        tester,
        const AdminDashboardScreen(),
        width: width,
        height: 1400,
        providers: adminProviders(),
      );
      expect(errors, isEmpty, reason: 'desborda a $width px');
    }
  });

  testWidgets('cero MediaQuery cruda y cero colores literales', (tester) async {
    final source = File(
      'lib/features/admin/presentation/pages/admin_dashboard_screen.dart',
    ).readAsStringSync();
    expect(source.contains('MediaQuery.of(context).size'), isFalse);
    expect(RegExp(r'Colors\.white').hasMatch(source), isFalse);
    expect(source.contains('GoogleFonts'), isFalse);
  });
}
```

> `adminProviders()` es un helper del harness (Task 1) que devuelve la lista de `ChangeNotifierProvider.value` con `FakeAdminProvider`, `FakeAdminDashboardProvider` y un `UserProfileProvider` falso ya cargado. Añádelo allí, no aquí: lo usan también las Tasks 9, 10 y 11.

- [ ] **Step 3: correr y confirmar el fallo exacto**

```bash
flutter test test/features/admin/presentation/pages/admin_dashboard_screen_test.dart
```

Expected:

1. `las metricas no estan en 2 columnas a 600 px` — a 600 px hay **1** columna.
2. `a 1200.0 px las 6 metricas deben caer en 2 filas de 3`: hoy da 2 filas, así que **este puede pasar ya**. Déjalo: es una red que impide que alguien «mejore» el grid a 4 columnas siguiendo el contrato erróneo del maestro.
3. `saludo ilegible en Brightness.dark` con **1.47**.
4. `admin-action-usuarios es bajo` — ~**42**.
5. `Expected: <false> / Actual: <true>` para `MediaQuery.of(context).size`.

- [ ] **Step 4: implementar**

**4a. Una sola escala.** `_buildMetricsGrid` pierde su `MediaQuery` y pasa a `AppGrid`:

```dart
  Widget _buildMetricsGrid(
    BuildContext context,
    AdminDashboardProvider provider,
    AppColors colors,
  ) {
    // Antes: `MediaQuery…width > 900 ? 3 : (> 600 ? 2 : 1)`, el cuarto
    // sistema de breakpoints de la app. Son 6 tarjetas: con 4 columnas
    // quedarian dos huerfanas, por eso `large` tambien es 3.
    return AppGrid(
      compactColumns: 1,
      mediumColumns: 2,
      expandedColumns: 3,
      largeColumns: 3,
      childAspectRatio: 1.6,
      children: [
        MetricCard(
          title: context.l10n.adminMetricsUsers,
          value: '${provider.metrics['usuarios'] ?? 0}',
          icon: Icons.people,
          color: colors.primary,
        ),
        // … las otras cinco, igual, con `?? 0` en cada una …
      ],
    );
  }
```

> **El `?? 0` no es cosmético.** Hoy `'${provider.metrics['usuarios']}'` interpola `null` cuando la métrica no ha llegado y la tarjeta muestra literalmente la palabra **`null`**. Con el `AnimatedCounter` de la Task 6 eso además haría `int.tryParse('null')` → 0, ocultando el fallo; mejor arreglarlo en el origen.

**4b. Los gráficos, en la misma escala.**

```dart
  Widget _buildGrowthCharts(
    BuildContext context,
    AdminDashboardProvider provider,
  ) {
    final userGrowthChart = UserGrowthChart(/* … */);
    final workshopsGrowthChart = WorkshopsGrowthChart(/* … */);

    // Mismo corte que las metricas: hasta `expanded` no hay ancho para dos
    // graficos. A 600 px darian 268 px cada uno.
    if (!AppBreakpoints.of(context).isAtLeastExpanded) {
      return Column(
        key: const ValueKey('admin-growth-charts'),
        children: [
          userGrowthChart,
          const SizedBox(height: AppSpacing.base),
          workshopsGrowthChart,
        ],
      );
    }

    return Row(
      key: const ValueKey('admin-growth-charts'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: userGrowthChart),
        const SizedBox(width: AppSpacing.base),
        Expanded(child: workshopsGrowthChart),
      ],
    );
  }
```

El corte sube de 600 a **840**: en `medium` los dos gráficos se apilan. Es un cambio de comportamiento deliberado y correcto — a 600–839 px dos gráficos de línea lado a lado son ilegibles (§0.3).

**4c. La cabecera.** `Colors.white` → `colors.onPrimary` en los tres sitios ([L166, L171, L186, L194](../../../lib/features/admin/presentation/pages/admin_dashboard_screen.dart#L166-L196)), y el subtítulo pierde el `alpha: 0.8`. `GoogleFonts.inter` → `AppTextStyles`. Claves `admin-welcome-title` en el título.

**4d. Los accesos rápidos a 48 dp.** `_buildActionChip` gana `ConstrainedBox(constraints: BoxConstraints(minHeight: 48))` y una clave por acción (`admin-action-usuarios`, etc.). Su `Row` interno gana `Flexible` + `ellipsis` en el `Text`, porque las etiquetas salen del ARB y en inglés son más largas.

**4e. El ancho y la recarga.**

```dart
              onRefresh: () async {
                // Antes solo se esperaba a `fetchLogs`; el indicador
                // desaparecia antes de que llegaran las metricas.
                await Future.wait(<Future<void>>[
                  provider.fetchMetrics(),
                  adminProvider.fetchLogs(),
                ]);
              },
              child: AppPageBody(
                child: SingleChildScrollView(/* … */),
              ),
```

> Comprueba que `fetchMetrics()` devuelve `Future<void>`. Si devuelve `void`, **no lo cambies** (§1.5 prohíbe tocar providers): envuélvelo en `Future.sync(provider.fetchMetrics)` y anota en el commit que la espera real necesita un cambio en el provider (§19.2).

**4f. La actividad reciente.** El ternario de `isDestructive` ([L428-432](../../../lib/features/admin/presentation/pages/admin_dashboard_screen.dart#L428-L432)) se sustituye por `AppSeverity.forLogAccion`, que es la misma clasificación pero compartida con `admin_logs_screen` (Task 11). Ese es el punto de §0.1: dos pantallas dejan de discrepar sobre el mismo log.

- [ ] **Step 5: correr y cerrar**

```bash
flutter test test/features/admin/
dart format . && dart fix --apply && flutter analyze && flutter test
```

**Commit:** `fix(admin-dashboard): una sola escala de breakpoints, 1,47:1 en oscuro y KPIs en AppGrid 1/2/3/3`

---

## 10. Task 9: `admin_talleres_screen` — el listener por fila y los filtros

**Files:**
- Modify: `lib/features/admin/presentation/pages/admin_talleres_screen.dart`
- Test: `test/features/admin/presentation/pages/admin_talleres_layout_test.dart`
- **No romper:** `test/features/admin/presentation/pages/admin_talleres_screen_test.dart` (3 tests sobre `filtrarTalleres`)

**Interfaces:**
- Consumes: `WindowClass`, `AppBreakpoints` (Fase 1 Task 1); `AppGrid`, `AppPageBody` (Fase 1 Task 5); `AppTextField` (Fase 3 Task 4, extendido en Fase 7 Task 3); `TallerAdminCard` (Task 4); `pumpAdmin`, `pumpAdminCollecting`, `adminProviders` (Task 1).
- Produces: nada público nuevo.

**Regla dura de esta tarea:** `filtrarTalleres` es una función *top-level* extraída a propósito para ser testeable, con tres tests propios. **No la muevas, no la renombres, no cambies su firma.** Si tu diff la toca, has ido demasiado lejos.

**Los cuatro problemas:**

1. **Un `StreamBuilder` de Firestore por fila** ([L258-273](../../../lib/features/admin/presentation/pages/admin_talleres_screen.dart#L258-L273)) — §0.5.1. Se cachea el `Stream` por id de mecánico; la solución completa necesita el provider (§19.2).
2. **`setState` programado desde `build()`** ([L415-419](../../../lib/features/admin/presentation/pages/admin_talleres_screen.dart#L415-L419)) — §0.5.2. Se mueve al `onChanged` del departamento, que es donde el municipio deja de ser válido.
3. **Los tres filtros de 220 px fijos** no desbordan (§0.4.2) pero tampoco crecen: a 1440 px ocupan 660 de 1.392.
4. **~15 cadenas en español literal** en una pantalla con solo 3 usos de `context.l10n`.

Más: la lista es de una sola columna a cualquier ancho; el contrato pasa a grid 1/1/2/3 (§0.4.1).

- [ ] **Step 1: escribir el test que falla**

```dart
// test/features/admin/presentation/pages/admin_talleres_layout_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/features/admin/presentation/pages/admin_talleres_screen.dart';
import 'package:autodoc/features/admin/presentation/widgets/taller_admin_card.dart';

import '../../../../support/admin_harness.dart';
import '../../../../support/responsive_harness.dart';

void main() {
  testWidgets('las tarjetas pasan a varias columnas en expanded', (
    tester,
  ) async {
    await pumpAdmin(
      tester,
      const AdminTalleresScreen(),
      width: 375,
      height: 1400,
      providers: adminProviders(talleres: [testTaller(), testTaller(id: 't-2')]),
    );
    final unaColumna = find.byType(TallerAdminCard);
    expect(
      tester.getTopLeft(unaColumna.at(0)).dy,
      lessThan(tester.getTopLeft(unaColumna.at(1)).dy),
      reason: 'en compact las tarjetas van apiladas',
    );

    await pumpAdmin(
      tester,
      const AdminTalleresScreen(),
      width: 1024,
      height: 1400,
      providers: adminProviders(talleres: [testTaller(), testTaller(id: 't-2')]),
    );
    final dosColumnas = find.byType(TallerAdminCard);
    expect(
      tester.getTopLeft(dosColumnas.at(0)).dy,
      tester.getTopLeft(dosColumnas.at(1)).dy,
      reason: 'en expanded deben ir lado a lado',
    );
  });

  testWidgets('los filtros crecen con la ventana', (tester) async {
    await pumpAdmin(
      tester,
      const AdminTalleresScreen(),
      width: 375,
      height: 1400,
      providers: adminProviders(),
    );
    final estrecho = tester.getSize(
      find.byKey(const ValueKey('taller-filter-departamento')),
    );

    await pumpAdmin(
      tester,
      const AdminTalleresScreen(),
      width: 1440,
      height: 1400,
      providers: adminProviders(),
    );
    final ancho = tester.getSize(
      find.byKey(const ValueKey('taller-filter-departamento')),
    );

    expect(
      ancho.width,
      greaterThan(estrecho.width),
      reason: 'los filtros siguen clavados en 220 px',
    );
  });

  testWidgets('no se programa setState desde build', (tester) async {
    final source = File(
      'lib/features/admin/presentation/pages/admin_talleres_screen.dart',
    ).readAsStringSync();
    expect(
      source.contains('addPostFrameCallback'),
      isFalse,
      reason: 'el municipio se limpia en el onChanged del departamento, '
          'no reconstruyendo el arbol',
    );
  });

  testWidgets('el stream por mecanico no se recrea en cada build', (
    tester,
  ) async {
    final source = File(
      'lib/features/admin/presentation/pages/admin_talleres_screen.dart',
    ).readAsStringSync();
    expect(
      source.contains('.snapshots(),\n'),
      isFalse,
      reason: 'el stream se construye inline dentro del delegate: '
          'cada rebuild abre una suscripcion nueva',
    );
  });

  testWidgets('no desborda en ningun ancho auditado', (tester) async {
    for (final width in kAuditWidths) {
      final errors = await pumpAdminCollecting(
        tester,
        const AdminTalleresScreen(),
        width: width,
        height: 1400,
        providers: adminProviders(talleres: [testTaller()]),
      );
      expect(errors, isEmpty, reason: 'desborda a $width px');
    }
  });
}
```

> El cuarto test es **frágil a propósito** (busca una cadena exacta del código fuente). Si al implementar la caché de streams la forma cambia, ajusta la aserción a lo que de verdad quieras impedir — pero no la borres: es el único guardián de §0.5.1 hasta que el dato viva en el provider.

- [ ] **Step 2: correr y confirmar el fallo exacto**

```bash
flutter test test/features/admin/presentation/pages/admin_talleres_layout_test.dart
```

Expected: `en expanded deben ir lado a lado` (hoy están apiladas), `los filtros siguen clavados en 220 px` con **220.0 == 220.0**, y los dos de código fuente en rojo.

- [ ] **Step 3: implementar**

**3a. La caché de streams.**

```dart
  final Map<String, Stream<DocumentSnapshot<Map<String, dynamic>>>>
  _tallerStreams = {};

  /// Devuelve **siempre el mismo** stream para un id dado.
  ///
  /// Antes se llamaba `.snapshots()` dentro del `SliverChildBuilderDelegate`,
  /// asi que cada reconstruccion de la fila abria una suscripcion nueva a
  /// Firestore y descartaba la anterior. Con la lista completa en pantalla
  /// eran tantas suscripciones como mecanicos, renovadas en cada scroll.
  Stream<DocumentSnapshot<Map<String, dynamic>>> _streamTaller(String id) {
    return _tallerStreams.putIfAbsent(
      id,
      () => FirebaseFirestore.instance
          .collection(FirestoreCollections.talleres)
          .doc(id)
          .snapshots(),
    );
  }
```

> **`Stream` de Firestore es *broadcast*,** así que reutilizarlo entre reconstrucciones es correcto y no lanza al escuchar dos veces. Y como el mapa vive en el `State`, se descarta con la pantalla.
>
> Esto **reduce** el problema, no lo elimina: sigue habiendo un listener por mecánico. La corrección real es una consulta agregada en el provider (§19.2).

**3b. El municipio, limpiado donde toca.** El bloque de `addPostFrameCallback` desaparece y su lógica se mueve:

```dart
            onChanged: (value) => setState(() {
              _filterDepartamento = value;
              // Un municipio de otro departamento produce un filtro
              // imposible de satisfacer. Se limpia aqui, cuando el usuario
              // cambia el departamento, no reconstruyendo el arbol.
              _filterMunicipio = null;
            }),
```

**3c. Los filtros que crecen.** Los tres `SizedBox(width: 220)` pasan a:

```dart
        ConstrainedBox(
          key: const ValueKey('taller-filter-departamento'),
          constraints: const BoxConstraints(minWidth: 220, maxWidth: 360),
          child: /* el DropdownButtonFormField, igual */,
        ),
```

dentro de un `Wrap` que sigue siendo `Wrap`. `minWidth` conserva el comportamiento actual en móvil; `maxWidth` evita que un filtro se coma la fila en escritorio.

**3d. El grid de tarjetas.** El `SliverList` de `TallerAdminCard` pasa a `SliverGrid` con el número de columnas de `WindowClass` (1/1/2/3): las tarjetas son altas y densas, así que **2 columnas no llegan hasta `expanded`**.

**3e. El ancho de página.** El `CustomScrollView` se envuelve en `AppPageBody` para que a 1440 px el contenido no ocupe 1.392.

- [ ] **Step 4: correr y confirmar verde**

```bash
flutter test test/features/admin/
```

Expected: los 5 nuevos **y los 3 de `filtrarTalleres` intactos**.

- [ ] **Step 5: cerrar**

```bash
dart format . && dart fix --apply && flutter analyze && flutter test
```

**Commit:** `fix(admin-talleres): cachear el stream por mecanico, filtros elasticos y grid en expanded`

---

## 11. Task 10: `admin_usuarios_screen`

**Files:**
- Modify: `lib/features/admin/presentation/pages/admin_usuarios_screen.dart`
- Test: `test/features/admin/presentation/pages/admin_usuarios_layout_test.dart`

**Interfaces:**
- Consumes: `WindowClass`, `AppBreakpoints`, `AppGrid`, `AppPageBody`; `AccountRow` (Task 5); `AppButton`, `AppButtonType` (Fase 3 Task 1); `pumpAdmin`, `pumpAdminCollecting`, `adminProviders` (Task 1).
- Produces: nada público nuevo.

575 líneas, 3 colores literales, 8 usos de `context.l10n` — la pantalla mejor localizada del módulo después del dashboard.

**Los tres problemas:**

1. **`ElevatedButton.styleFrom(backgroundColor: Colors.red)`** ([L89](../../../lib/features/admin/presentation/pages/admin_usuarios_screen.dart#L89)) — el botón de confirmación de una acción destructiva, en rojo literal. Pasa a `colors.error`, y el texto encima a `colors.onPrimary`… **no**: comprueba el contraste real de `onPrimary` sobre `error` antes de usarlo. `AppPalette.lightError` es `#FC8181`, un rojo claro: blanco encima da menos de 3:1. Mide y elige (`textPrimary` sobre `error` puede ser mejor). **No copies el patrón de `onPrimary` sin medir: `error` no es `primary`.**
2. **`Colors.grey[600]` y `Colors.grey`** ([L129](../../../lib/features/admin/presentation/pages/admin_usuarios_screen.dart#L129), [L157](../../../lib/features/admin/presentation/pages/admin_usuarios_screen.dart#L157)) en el estado vacío → `colors.textSecondary`.
3. **`ListView.separated` de una columna a cualquier ancho** ([L379](../../../lib/features/admin/presentation/pages/admin_usuarios_screen.dart#L379)) → grid 1/1/2/2 en `expanded`+. `AccountRow` es una fila con menú emergente: **dos columnas como máximo**, porque a tres el nombre y el correo empiezan a truncarse.

- [ ] **Step 1: escribir el test que falla**

```dart
// test/features/admin/presentation/pages/admin_usuarios_layout_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/features/admin/presentation/pages/admin_usuarios_screen.dart';
import 'package:autodoc/features/admin/presentation/widgets/account_row.dart';

import '../../../../support/contrast.dart';
import '../../../../support/admin_harness.dart';
import '../../../../support/responsive_harness.dart';

void main() {
  testWidgets('dos columnas en expanded, una en compact', (tester) async {
    final usuarios = [testAdminUser(), testAdminUser(id: 'u-2')];

    await pumpAdmin(
      tester,
      const AdminUsuariosScreen(),
      width: 375,
      height: 1400,
      providers: adminProviders(usuarios: usuarios),
    );
    expect(
      tester.getTopLeft(find.byType(AccountRow).at(0)).dy,
      lessThan(tester.getTopLeft(find.byType(AccountRow).at(1)).dy),
    );

    await pumpAdmin(
      tester,
      const AdminUsuariosScreen(),
      width: 1024,
      height: 1400,
      providers: adminProviders(usuarios: usuarios),
    );
    expect(
      tester.getTopLeft(find.byType(AccountRow).at(0)).dy,
      tester.getTopLeft(find.byType(AccountRow).at(1)).dy,
    );
  });

  testWidgets('el boton destructivo cumple 4,5:1 en ambos temas', (
    tester,
  ) async {
    for (final brightness in Brightness.values) {
      await pumpAdmin(
        tester,
        const AdminUsuariosScreen(),
        width: 375,
        height: 1400,
        brightness: brightness,
        providers: adminProviders(usuarios: [testAdminUser()]),
      );
      final context = tester.element(find.byType(AdminUsuariosScreen));
      final colors = context.appColors;
      // El par exacto lo eliges al implementar; el test comprueba que el
      // que hayas elegido se lee.
      final boton = tester.widget<Text>(
        find.byKey(const ValueKey('usuarios-confirm-destructive-label')),
      );
      expect(
        contrastRatio(boton.style!.color!, colors.error),
        greaterThanOrEqualTo(4.5),
        reason: 'boton destructivo ilegible en $brightness',
      );
    }
  });

  testWidgets('cero literales de color', (tester) async {
    final source = File(
      'lib/features/admin/presentation/pages/admin_usuarios_screen.dart',
    ).readAsStringSync();
    final offenders = RegExp(
      r'Colors\.(white|black|grey|green|red|orange|blue)',
    ).allMatches(source).map((m) => m.group(0)).toList();
    expect(offenders, isEmpty, reason: 'quedan: $offenders');
  });

  testWidgets('no desborda en ningun ancho auditado', (tester) async {
    for (final width in kAuditWidths) {
      final errors = await pumpAdminCollecting(
        tester,
        const AdminUsuariosScreen(),
        width: width,
        height: 1400,
        providers: adminProviders(usuarios: [testAdminUser()]),
      );
      expect(errors, isEmpty, reason: 'desborda a $width px');
    }
  });
}
```

- [ ] **Step 2: correr, implementar, verificar**

Expected en el Step inicial: las dos filas a la misma `dy` fallan a 1024 (hoy siempre apiladas), `Found 0 widgets with key [<'usuarios-confirm-destructive-label'>]`, y `quedan: [Colors.red, Colors.grey, Colors.grey]`.

Implementación: `ListView.separated` → `AppGrid` con 1/1/2/2 dentro de `AppPageBody`; los tres literales a tokens; la clave en la etiqueta del botón destructivo; y **mide el par de contraste antes de fijarlo**.

- [ ] **Step 3: cerrar**

```bash
flutter test test/features/admin/
dart format . && dart fix --apply && flutter analyze && flutter test
```

**Commit:** `fix(admin-usuarios): grid en expanded, contraste del boton destructivo y tokens`

---

## 12. Task 11: `admin_resenias_screen` y `admin_logs_screen`

**Files:**
- Modify: `lib/features/admin/presentation/pages/admin_resenias_screen.dart`
- Modify: `lib/features/admin/presentation/pages/admin_logs_screen.dart`
- Test: `test/features/admin/presentation/pages/admin_moderation_test.dart`

**Interfaces:**
- Consumes: `AppSeverity.forLogAccion` (Task 1); `WindowClass`, `AppBreakpoints`, `AppGrid`, `AppPageBody`; `AppCard`, `AppButton`; `pumpAdmin`, `pumpAdminCollecting`, `adminProviders` (Task 1).
- Produces: nada público nuevo.

Las dos últimas pantallas, juntas porque comparten forma (lista de tarjetas con filtros) y porque `admin_logs` es donde se cierra el hallazgo de §0.1.

**`admin_logs_screen` — 11 literales, y el mapeo que discrepa.** Los cuatro colores de [L58-66](../../../lib/features/admin/presentation/pages/admin_logs_screen.dart#L58-L66) se sustituyen **enteros** por `AppSeverity.forLogAccion`. A partir de ahí, el dashboard (Task 8) y esta pantalla clasifican el mismo log igual. Los otros siete literales son `Colors.grey[300/500/600/700]` en el estado vacío, la fecha y los chips → `colors.textSecondary` / `surfaceVariant`.

Y sus chips de filtro usan `vertical: Responsive.padding(context, 3)` ([L498](../../../lib/features/admin/presentation/pages/admin_logs_screen.dart#L498)): un objetivo táctil de ~20 dp. Suben a 48.

**`admin_resenias_screen` — 3 literales**, dos de ellos el par `Colors.red.shade100` / `Colors.red.shade900` de una insignia ([L177-179](../../../lib/features/admin/presentation/pages/admin_resenias_screen.dart#L177-L179)) y un `Colors.white` sobre botón ([L85](../../../lib/features/admin/presentation/pages/admin_resenias_screen.dart#L85)). Y **1 solo uso de `context.l10n`** en 332 líneas: es la pantalla menos localizada del módulo.

- [ ] **Step 1: escribir el test que falla**

```dart
// test/features/admin/presentation/pages/admin_moderation_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_severity.dart';
import 'package:autodoc/features/admin/presentation/pages/admin_logs_screen.dart';
import 'package:autodoc/features/admin/presentation/pages/admin_resenias_screen.dart';

import '../../../../support/admin_harness.dart';
import '../../../../support/responsive_harness.dart';

void main() {
  testWidgets('logs y dashboard clasifican el mismo log igual', (tester) async {
    // El nucleo de la Fase 8 §0.1: habia dos definiciones de «accion grave».
    final logsSource = File(
      'lib/features/admin/presentation/pages/admin_logs_screen.dart',
    ).readAsStringSync();
    final dashSource = File(
      'lib/features/admin/presentation/pages/admin_dashboard_screen.dart',
    ).readAsStringSync();

    expect(logsSource.contains('AppSeverity.forLogAccion'), isTrue);
    expect(dashSource.contains('AppSeverity.forLogAccion'), isTrue);
    expect(
      RegExp(r'Colors\.(red|green|orange|blue)').hasMatch(logsSource),
      isFalse,
      reason: 'sigue el semaforo escrito a mano',
    );
  });

  testWidgets('los chips de filtro de logs miden 48 dp', (tester) async {
    await pumpAdmin(
      tester,
      const AdminLogsScreen(),
      width: 375,
      height: 1400,
      providers: adminProviders(),
    );
    for (final chip in find.byType(FilterChip).evaluate()) {
      expect(
        (chip.renderObject as RenderBox).size.height,
        greaterThanOrEqualTo(48),
      );
    }
  });

  testWidgets('ninguna de las dos desborda en los anchos auditados', (
    tester,
  ) async {
    for (final width in kAuditWidths) {
      for (final pantalla in <Widget>[
        const AdminLogsScreen(),
        const AdminReseniasScreen(),
      ]) {
        final errors = await pumpAdminCollecting(
          tester,
          pantalla,
          width: width,
          height: 1400,
          providers: adminProviders(),
        );
        expect(
          errors,
          isEmpty,
          reason: '${pantalla.runtimeType} desborda a $width px',
        );
      }
    }
  });

  testWidgets('cero literales de color en ambas', (tester) async {
    for (final path in const <String>[
      'lib/features/admin/presentation/pages/admin_logs_screen.dart',
      'lib/features/admin/presentation/pages/admin_resenias_screen.dart',
    ]) {
      final source = File(path).readAsStringSync();
      final offenders = RegExp(
        r'Colors\.(white|black|grey|green|red|orange|blue)',
      ).allMatches(source).map((m) => m.group(0)).toList();
      expect(offenders, isEmpty, reason: '$path: $offenders');
    }
  });
}
```

> Comprueba el tipo real de los chips de filtro antes de escribir `find.byType(FilterChip)`: `admin_logs` puede usar `ChoiceChip`, `ActionChip` o un `Container` propio. `admin_talleres` usa `ChoiceChip` ([L496](../../../lib/features/admin/presentation/pages/admin_talleres_screen.dart#L496)).

- [ ] **Step 2: correr y confirmar el fallo exacto**

```bash
flutter test test/features/admin/presentation/pages/admin_moderation_test.dart
```

Expected: `sigue el semaforo escrito a mano`; los chips medirán ~**26** contra 48; y `admin_logs_screen.dart: [Colors.red, Colors.green, Colors.orange, Colors.blue, Colors.grey, …]` con **11** entradas.

- [ ] **Step 3: implementar**

En `admin_logs_screen`, el método de color desaparece entero y su llamada pasa a:

```dart
    final severity = AppSeverity.forLogAccion(
      log.accion,
      colors,
      destructivaLabel: context.l10n.adminLogSeverityDestructive,
      creacionLabel: context.l10n.adminLogSeverityCreation,
      modificacionLabel: context.l10n.adminLogSeverityUpdate,
      consultaLabel: context.l10n.adminLogSeverityRead,
    );
```

> **Esas cuatro claves casi seguro no existen.** Comprueba el ARB; si no están, §1.4 impide crearlas y tienes dos opciones honestas: pasar los literales en español que la pantalla ya muestra, o —mejor— pasar la propia `log.accion.replaceAll('_', ' ')` como etiqueta, que es lo que la pantalla enseña hoy y no inventa texto nuevo. Anótalo en §18.1.

Ambas pantallas: `ListView.separated` → `AppGrid` (1/1/2/2 en reseñas, **1/1/1/1 en logs** — un log es una línea larga de texto, no una tarjeta, y en dos columnas se lee peor), `AppPageBody` para acotar el ancho, chips a 48 dp, tokens en lugar de los 14 literales.

- [ ] **Step 4: cerrar**

```bash
flutter test test/features/admin/
dart format . && dart fix --apply && flutter analyze && flutter test
```

**Commit:** `fix(admin-logs,resenias): una sola definicion de accion grave, targets de 48 dp y tokens`

---

## 13. Task 12: cerrar el ratchet y corregir el maestro

**Files:**
- Modify: `test/support/tokenized_paths.dart`
- Modify: `docs/superpowers/plans/2026-08-10-ui-ux-overhaul-00-master.md` (§3, §5.5, §5.6)
- Test: `test/core/theme/hardcoded_colors_test.dart` (existente, de la Fase 1 Task 8)

**Interfaces:**
- Consumes: `kTokenizedPaths` (Fase 1 Task 8).
- Produces: `kTokenizedPaths` con **las quince rutas de `admin`**, que son las últimas: al terminar esta tarea el ratchet cubre `lib/features/**` completo.

- [ ] **Step 1: añadir las quince rutas**

```dart
  // Fase 8 — admin (ultimo modulo: con esto el ratchet cubre features/**)
  'lib/features/admin/presentation/pages/admin_dashboard_screen.dart',
  'lib/features/admin/presentation/pages/admin_logs_screen.dart',
  'lib/features/admin/presentation/pages/admin_resenias_screen.dart',
  'lib/features/admin/presentation/pages/admin_seed_screen.dart',
  'lib/features/admin/presentation/pages/admin_talleres_screen.dart',
  'lib/features/admin/presentation/pages/admin_usuarios_screen.dart',
  'lib/features/admin/presentation/widgets/account_row.dart',
  'lib/features/admin/presentation/widgets/admin_sidebar.dart',
  'lib/features/admin/presentation/widgets/dialog_crear_usuario.dart',
  'lib/features/admin/presentation/widgets/mecanico_admin_card.dart',
  'lib/features/admin/presentation/widgets/metric_card.dart',
  'lib/features/admin/presentation/widgets/services_trend_chart.dart',
  'lib/features/admin/presentation/widgets/taller_admin_card.dart',
  'lib/features/admin/presentation/widgets/user_growth_chart.dart',
  'lib/features/admin/presentation/widgets/workshops_growth_chart.dart',
```

- [ ] **Step 2: convertir el ratchet en una regla general**

Con `admin` dentro, `kTokenizedPaths` ya no es una lista de excepciones: es *todo*. Invierte la prueba —de «estas rutas están limpias» a «**todas** lo están, salvo esta lista de pendientes»— y deja la lista de pendientes **vacía**:

```dart
/// Rutas que todavia NO estan tokenizadas.
///
/// Al cerrar la Fase 8 esta lista quedo vacia: `lib/features/**` y
/// `lib/core/widgets/**` estan limpios. Anadir algo aqui es un retroceso y
/// necesita justificacion en el PR.
const List<String> kPendingTokenizationPaths = <String>[];
```

Es un cambio pequeño con un efecto grande: a partir de aquí **un fichero nuevo con un color literal falla el test sin que nadie tenga que acordarse de añadirlo a una lista**.

- [ ] **Step 3: correr**

```bash
flutter test test/core/theme/hardcoded_colors_test.dart
```

Expected: verde. Si sale rojo, lee el fichero que denuncia y vuelve a su tarea; **no** añadas excepciones aquí.

- [ ] **Step 4: recontar el agregado global del maestro**

> **§3, §4 y §5.5 del maestro ya están corregidos.** Se actualizaron el 2026-08-12, al escribir este plan: el cuarto sistema de breakpoints en §3, la fila de la Fase 8 en §4, y las seis filas de §5.5 con su nota fechada. **No los vuelvas a tocar.**

Lo único pendiente es §5.6, que solo se puede recalcular **después** de ejecutar la fase. Dice hoy:

> «**~270 colores hardcodeados** repartidos en 25+ ficheros»

Esta fase elimina los **54** últimos. Recalcula:

```bash
grep -rnoE "Colors\.(white|black|grey|gray|blue|red|green|orange|purple|amber|yellow|teal|pink|indigo|cyan|lime|brown)[0-9A-Za-z._]*|Color\(0x" lib/features lib/core/widgets | wc -l
```

Debe dar **cero**. `Colors.transparent` no lo captura el patrón, y los `Colors.black.withValues(...)` de `app_shadows.dart` están fuera de las dos rutas: son las dos excepciones que §2 del maestro permite.

Si **no** da cero, el roadmap no está terminado. Localiza los residuos y a qué fase pertenecen antes de escribir nada en el maestro:

```bash
grep -rlnoE "Colors\.(white|black|grey|green|red|orange|blue)" lib/features lib/core/widgets
```

Con el cero confirmado, sustituye la línea de §5.6 por la cifra final y la fecha, y actualiza también los otros dos agregados de esa sección que esta refactorización ha movido: **«3 usos de `Semantics` en toda la app»** y **«0 usos de reduced-motion»**. Cuéntalos:

```bash
grep -rn "Semantics(" lib/ --include=*.dart | wc -l
grep -rn "AppMotion.reduced\|disableAnimationsOf" lib/ --include=*.dart | wc -l
```

Ese par de números es la medida más honesta de si el roadmap consiguió lo que decía querer.

- [ ] **Step 5: cerrar**

```bash
dart format . && flutter analyze && flutter test
```

**Commit:** `chore(fase-8): cerrar el ratchet de colores para todo features/** y corregir el maestro`

---

## 14. Verificación de cierre de fase

1. **Suite completa.** `flutter test`. Los **34** tests que existían al abrir la fase siguen en verde — incluidos los tres de `filtrarTalleres` y los diez de los gráficos.
2. **Matriz de anchos.** Las 6 pantallas a **320, 375, 600, 768, 840, 1024, 1200, 1440**, en `es` y `en`, claro y oscuro. Los tests de cada tarea cubren el desbordamiento; a mano, verifica **320 y 1440** en los cuatro combos.
3. **El caso 600.** Comprueba a mano que `admin_dashboard` ya no se contradice: métricas y gráficos deben coincidir en qué clase de ventana creen estar.
4. **Reduced motion.** La suite con `disableAnimations: true`. El `AnimatedCounter` de las seis `MetricCard` es lo único que anima aquí; debe llegar a su valor final sin contar.
5. **Lector de pantalla** sobre `admin_dashboard`: las seis métricas deben leerse como seis frases («Usuarios: 42»), y cada gráfico debe decir su resumen.
6. **Escala tipográfica al 200 %** en las 6 pantallas.
7. **Pre-Delivery Checklist** de `ui-ux-pro-max`, ítem por ítem.
8. **`review-animations`** sobre el diff — tocó motion en las Tasks 6 y 8.
9. **`superpowers:requesting-code-review`** sobre la rama.

---

## 15. Cierre del roadmap: las tres auditorías globales

**Esta es la última fase.** El maestro §1 y §1.1 comprometen tres auditorías que solo tienen sentido al final, sobre el árbol completo. Ejecútalas después de mergear la fase, cada una en su propio commit:

1. **`Skill(improve-animations)`** sobre `lib/` — auditoría priorizada del motion de toda la app. El maestro la marca como *"Una vez, al cerrar la Fase 8"*. Produce un plan, no cambios: guárdalo como `docs/superpowers/plans/<fecha>-motion-audit.md`.
2. **`code-audit`** (`easier-life-skills`) — código muerto. El maestro §1.1 lo pide *"al cerrar la Fase 3 y de nuevo al cerrar la Fase 8"*, y esta refactorización ha dejado residuos garantizados: los helpers de `Responsive` marcados `@Deprecated` en la Fase 1 Task 6, los `@Deprecated` de `isMobile`/`isTablet`/`isDesktop` que ya no debería llamar nadie, y el bloque comentado de `app_scaffold.dart:29-34`. Instalar: `/plugin install easier-life-skills/code-audit`.
3. **`site-audit`** (`easier-life-skills`) sobre la build web desplegada — la app compila a Flutter Web (`usePathUrlStrategy()` en [main.dart:68](../../../lib/main.dart#L68)) y **nunca se ha auditado**. Instalar: `/plugin install easier-life-skills/site-audit`.

---

## 16. Comprobación del criterio de éxito global del maestro

El maestro §8 fija diez condiciones para dar por terminada toda la refactorización. Al cerrar esta fase hay que comprobarlas **una a una, con el comando**, no de memoria:

```bash
# 1. Cero colores hardcodeados en features y core/widgets
grep -rn "Colors\.\(white\|black\|grey\|blue\|red\|green\|orange\|purple\)" lib/features lib/core/widgets

# 2. responsive_framework desinstalado
grep -rn "responsive_framework" lib/ pubspec.yaml

# 3. MediaQuery cruda para layout en features
grep -rn "MediaQuery.of(context).size" lib/features

# 4. Ninguna pantalla fuera de presentation/pages/
find lib/features -name '*_screen.dart' -path '*/screens/*'

# 5. GoogleFonts fuera del sistema tipografico
grep -rn "GoogleFonts" lib/features
```

Los cinco deben devolver **cero líneas**. Las otras cinco condiciones (sin overflow en los 8 anchos, cambio de estructura al cruzar 600/840/1200, targets de 48 dp, contraste verificado por test en ambos temas, reduced motion) las cubren los tests de las ocho fases; ejecútalos y **anota el número total de tests en el commit de cierre**.

La décima condición del maestro no se puede comprobar con un comando:

> *La marca es reconociblemente la misma: un usuario debe decir "se siente mejor hecha", no "la cambiaron".*

Enséñaselo a alguien que usara la app antes de empezar. Si dice «la cambiaron», eso es el resultado y hay que escribirlo, no discutirlo.

---

## 17. Criterios de éxito de la fase

- [ ] `flutter test` en verde, con los 34 tests preexistentes intactos.
- [ ] **`TallerAdminCard` pasa de `125 + 146` px de desbordamiento a 320, y `70 + 91` a 375, a cero en los ocho anchos y los cuatro estados.**
- [ ] `admin_dashboard_screen` no contiene `MediaQuery…size` y **métricas y gráficos usan la misma escala**.
- [ ] Las 6 métricas caen en **2 filas de 3** en `expanded` y `large`, nunca en 4 columnas.
- [ ] `grep -rn "Colors\.\(white\|black\|grey\|green\|red\|orange\|blue\)" lib/features/admin` devuelve **cero**, y `grep -rn "Color(0x" lib/features/admin` también.
- [ ] `grep -rn "GoogleFonts" lib/features/admin` devuelve **cero** (hoy: 10).
- [ ] **Ninguna pantalla ni widget de `admin` traduce un estado a un color por su cuenta**: todo pasa por `AppSeverity`.
- [ ] `admin_dashboard` y `admin_logs` clasifican el mismo log **igual**.
- [ ] Ningún par texto/fondo por debajo de 4,5:1 (cuerpo) o 3:1 (glifos) en las 6 pantallas, **en ambos temas**. En particular: la cabecera del dashboard y del cajón dejan de ser 1,47:1; las opciones del menú de cuenta dejan de ser 2,78:1.
- [ ] Todo control tappable mide **≥ 48 × 48 dp**: accesos rápidos del dashboard, chips de info y de filtro, elementos del cajón.
- [ ] **Los tres gráficos exponen un resumen textual** y su alto depende de `WindowClass`.
- [ ] `/admin/seed` tiene cajón y su enlace no se ofrece en release.
- [ ] Ningún texto por debajo de 12 px.
- [ ] `kPendingTokenizationPaths` **vacía**, con el ratchet invertido a regla general.
- [ ] Maestro §3, §5.5 y §5.6 corregidos, con nota fechada.

---

## 18. Deuda declarada

### 18.1 ~40 cadenas sin localizar

`admin_talleres` tiene 3 usos de `context.l10n` y ~15 literales; `admin_logs` 2; `admin_resenias` **1 en 332 líneas**. Frente a los 19 del dashboard. §1.4 prohíbe añadir claves, así que la fase las deja como están y añade unas pocas (los tres textos de tendencia de los gráficos, las etiquetas de severidad de log si el ARB no las tiene).

Es deuda menos grave que la de la Fase 7 —los administradores son usuarios internos y presumiblemente hispanohablantes— pero es real: la consola tiene un conmutador de idioma en el dashboard que **no traduce cinco de sus seis pantallas**.

### 18.2 El shell de admin sigue copiado seis veces

§0.5.4. Cada página construye su `Scaffold` + `AppBar` + `drawer`, y los conmutadores de tema e idioma solo existen en el dashboard. La Task 3 mejora el cajón (marca la ruta activa, arregla el contraste) pero **no lo unifica**. Ver §19.3.

### 18.3 Los tres gráficos siguen siendo tres ficheros casi idénticos

`services_trend_chart`, `user_growth_chart` y `workshops_growth_chart` comparten estructura, y la Task 7 hace el mismo cambio tres veces. Unificarlos en un `AppTrendChart` parametrizado es lo correcto **y rompería sus tres tests**, que asumen el tipo concreto. Es un refactor con su propia migración de tests, no un paso de esta fase.

### 18.4 `admin_seed_screen` probablemente sobra

60 líneas que dicen «la migración terminó», tras un `kDebugMode`. La Task 2 la tokeniza y le da salida en vez de proponer borrarla, porque borrar una ruta es una decisión de producto. Pero merece la pregunta: **¿para qué sirve una pantalla que solo existe en depuración y solo informa de algo que ya pasó?**

### 18.5 El `RefreshIndicator` del dashboard puede seguir mintiendo

Si `fetchMetrics()` devuelve `void` en el provider, la Task 8 solo puede envolverlo en `Future.sync`, que **no espera** a la carga real. El indicador seguirá desapareciendo antes de tiempo. La corrección necesita el provider (§19.2).

---

## 19. Bloqueos

### 19.1 ¿Hace falta una tabla de verdad?

§0.4.1: el maestro pedía tablas para tres pantallas y **no hay ninguna** que hacer responsiva. Esta fase entrega grids de tarjetas, que es la refactorización honesta de lo que existe.

Si la consola de administración de verdad necesita vistas tabulares —ordenar por columna, seleccionar varias filas, exportar la selección— eso es **una funcionalidad nueva** con su propio diseño y sus propios tests. `admin_talleres` ya exporta CSV ([L110-161](../../../lib/features/admin/presentation/pages/admin_talleres_screen.dart#L110-L161)), lo que sugiere que alguien echa de menos una hoja de cálculo. Decisión de producto, no de esta fase.

### 19.2 Dos correcciones necesitan tocar `providers/`

1. **El listener por fila** (§0.5.1). La Task 9 cachea el `Stream` y evita re-suscribir en cada rebuild, pero sigue habiendo una suscripción por mecánico. La solución real es que `AdminProvider` traiga las calificaciones en una sola consulta y las exponga junto a `mecanicos`.
2. **`fetchMetrics()` sin `Future`** (§18.5). Que devuelva `Future<void>` haría honesto el `RefreshIndicator`.

Las dos son cambios pequeños y con tests existentes que las protegen. Están prohibidas por §2 del maestro y por §1.5 de esta fase. **Consúltalo antes de ejecutar la Task 9**: si se autorizan, las dos tareas son más simples, no más complejas.

### 19.3 Unificar el shell de admin en un `ShellRoute`

§0.5.4 y §18.2. Las seis rutas `/admin/*` son de primer nivel ([app_router.dart:607-651](../../../lib/core/router/app_router.dart#L607-L651)). Montarlas bajo un `ShellRoute` con `AdminSidebar` como `NavigationRail` en `expanded`+ daría: estado de cajón compartido, conmutadores de tema e idioma en las seis pantallas, y coherencia con lo que la Fase 2 construyó para el rol propietario.

Es exactamente el mismo trabajo que la Fase 5 hizo con el shell del taller, y **es reestructurar el router**: cambia el comportamiento del botón atrás y de los deep links a `/admin/*`. Fuera de alcance como refactor de presentación; es la primera candidata a fase 9 si la hay.

### 19.4 `lightSuccess`: tercer consumidor, mismo bloqueo

`AppPalette.lightSuccess #48BB78` mide **2,25:1** sobre `lightSurface`. La Fase 6 §18.3 lo abrió, la Fase 7 §19.3 lo confirmó, y esta fase lo necesita en `AppSeverity.forTallerEstado` para el estado *aprobado* — el estado más común de un taller en producción.

Las tres fases han tenido que rodearlo con el mismo apaño: **el color va en el icono, el texto va en `textPrimary`**. Funciona, y es peor que tener un token de éxito utilizable.

Recomendación, sin cambios desde la Fase 6: oscurecer a **`#2F855A`** (4,8:1 sobre `lightSurface`). Toca `AppPalette`, así que necesita el visto bueno de marca — y es el último bloqueo abierto del roadmap.

### 19.5 `AppButton` sigue sin variante destructiva

`enum AppButtonType { primary, secondary, text }` ([app_button.dart:9](../../../lib/core/widgets/app_button.dart#L9)). La Fase 6 §18.2 lo pidió, la Fase 7 §19.6 lo pidió, y la Task 4 de esta fase lo rodea poniendo *Rechazar* como `text`.

**Tres fases pidiendo lo mismo.** Añadir `AppButtonType.danger` es media hora de trabajo en la Fase 3 y cierra los tres.

---

## 20. Resumen

| # | Tarea | Fichero principal | Steps | Qué cierra |
|---|---|---|---:|---|
| 1 | `AppSeverity` + harness | `app_severity.dart` | 7 | Los cuatro semáforos incompatibles pasan a ser uno |
| 2 | `admin_seed_screen` | 60 LOC | 5 | Tokens y el callejón sin salida |
| 3 | `AdminSidebar` | 164 LOC | 6 | 1,47:1 en oscuro; la copia literal de la paleta; ruta activa |
| 4 | `TallerAdminCard` | 173 LOC | 6 | **Los dos overflows de todo ancho de teléfono**; 14 literales |
| 5 | `AccountRow` + 2 widgets | 377 LOC | 4 | 2,78:1 en el menú de cuenta; texto de 10 px |
| 6 | `MetricCard` | 90 LOC | 4 | `cardColor`, opacidad como token, semántica de tarjeta |
| 7 | Los tres gráficos | 427 LOC | 6 | Alto por `WindowClass`; resumen textual accesible |
| 8 | `admin_dashboard_screen` | 493 LOC | 5 | **El cuarto sistema de breakpoints y la contradicción a 600 px** |
| 9 | `admin_talleres_screen` | 504 LOC | 5 | Listener por fila; `setState` desde `build`; grid |
| 10 | `admin_usuarios_screen` | 575 LOC | 3 | Grid en `expanded`; contraste del botón destructivo |
| 11 | `admin_logs` + `admin_resenias` | 856 LOC | 4 | Una sola definición de «acción grave»; 14 literales |
| 12 | Ratchet + maestro | — | 5 | Invierte el ratchet a regla general para `features/**` |

**12 tareas · 60 steps · 6 pantallas + 9 widgets · 3.719 líneas de presentación auditadas.**

Con esta fase el roadmap queda cerrado: **8 fases, 34 pantallas, 9 módulos.** Las auditorías globales de §15 y la comprobación de §16 son lo último.
