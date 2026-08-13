# Fase 7 — `auth` · `onboarding` · `profile` · `splash`: la ruta de entrada

> **Plan ejecutable.** Documento hermano de [`...-00-master.md`](2026-08-10-ui-ux-overhaul-00-master.md). Hereda **íntegra** la sección §2 (*Global Constraints*) del maestro y la tabla de skills obligatorias de §1. Escrito el **2026-08-12** siguiendo el protocolo de §7 del maestro.
>
> **REQUIRED SUB-SKILL:** `superpowers:subagent-driven-development` (recomendado) o `superpowers:executing-plans`.
>
> **Dependencias duras:** Fases 1, 2 y 3 ejecutadas. Ver §19.4 — esta fase depende de la Fase 1 Task 4 y de la Fase 2 Task 1 más que ninguna anterior.

**Goal:** Dejar utilizable la ruta que **todo** usuario recorre antes de ver la app: splash → onboarding → login/registro → configuración de perfil, más la pantalla de perfil a la que vuelve después. Hoy esa ruta desborda en todos los anchos de teléfono, lanza una aserción en horizontal, y contiene la pantalla con más colores literales de la aplicación.

---

## 0. Métricas medidas sobre `HEAD` (2026-08-12)

Diez ficheros de presentación, **3.728 líneas**. Medido con `grep -oE` sobre el árbol de trabajo, no estimado.

**HC** = `Colors.<literal>` · **0x** = `Color(0xFF…)` literal · **MQ** = `MediaQuery.of(context).size` crudo · **LB** = `LayoutBuilder` · **Resp** = llamadas a `Responsive.*` · **RF** = `responsive_framework` · **GF** = `GoogleFonts.*` · **Sem** = `Semantics` · **W≥100** = anchos/altos fijos ≥ 100 px.

| Fichero | LOC | HC | 0x | MQ | LB | Resp | RF | GF | Sem | W≥100 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| [user_profile_screen.dart](../../../lib/features/profile/presentation/pages/user_profile_screen.dart) | 920 | **36** | **17** | — | — | 33 | 3 | 12 | — | 1 |
| [profile_setup_screen.dart](../../../lib/features/profile/presentation/pages/profile_setup_screen.dart) | 842 | 6 | — | — | — | **25** | — | **16** | — | 4 |
| [auth_screen.dart](../../../lib/features/auth/presentation/pages/auth_screen.dart) | 789 | 3 | — | — | — | 8 | — | — | **2** | — |
| [onboarding_screen.dart](../../../lib/features/onboarding/presentation/pages/onboarding_screen.dart) | 449 | — | — | **1** | **1** | **0** | — | — | — | 3 |
| [splash_screen.dart](../../../lib/features/splash/presentation/pages/splash_screen.dart) | 376 | 1 | — | — | — | **0** | — | 2 | — | **7** |
| [about_screen.dart](../../../lib/features/profile/presentation/pages/about_screen.dart) | 167 | — | — | — | — | 1 | — | 2 | — | — |
| [auth_bottom_nav.dart](../../../lib/features/auth/presentation/widgets/auth_bottom_nav.dart) | 66 | 1 | — | — | — | — | — | — | — | — |
| [auth_background_blobs.dart](../../../lib/features/auth/presentation/widgets/auth_background_blobs.dart) | 58 | — | — | — | — | 4 | — | — | — | — |
| [auth_logo_section.dart](../../../lib/features/auth/presentation/widgets/auth_logo_section.dart) | 46 | — | — | — | — | 2 | — | — | — | — |
| [login_screen.dart](../../../lib/features/auth/presentation/screens/login_screen.dart) | 15 | — | — | — | — | — | — | — | — | — |
| **TOTAL** | **3.728** | **47** | **17** | **1** | **1** | **73** | **3** | **32** | **2** | **15** |

**64 colores hardcodeados**, de los cuales **53 (83 %) están en un solo fichero**: `user_profile_screen`. El maestro §5.4 decía 33; la cuenta real es 53 porque solo contaba `Colors.*` y no los 17 `Color(0xFF…)`.

**32 usos de `GoogleFonts`** en cuatro ficheros, con **tres familias distintas**: `inter`, `montserrat` y `montserratAlternates`. El maestro §5.2 registró la tercera familia en el módulo `mechanic`; también está aquí, y aquí conviven las tres en una misma pantalla (`profile_setup_screen`).

**Las 2 únicas `Semantics` de toda la app** siguen estando en `auth_screen`, como decía el maestro. Ver §0.6.1: no funcionan como se espera.

---

### 0.1 El hallazgo estructural: la ruta de entrada desborda en todos los anchos de teléfono

Esta fase no descubre un problema de estética. Descubre que **la secuencia obligatoria de alta de usuario está rota, hoy, en `HEAD`, en los anchos donde vive el 100 % de los usuarios móviles.**

Medido ejecutando cada pantalla en `flutter test` con `FlutterError.onError` capturado y `tester.view.physicalSize` fijado. Reproducible.

#### `profile_setup_screen` — desborda en **todo** ancho de teléfono

Es la pantalla que el router **obliga** a pasar: [app_router.dart:232-234](../../../lib/core/router/app_router.dart#L232-L234) redirige a `/profile_setup` a cualquier usuario autenticado sin perfil, y [auth_screen.dart:454](../../../lib/features/auth/presentation/pages/auth_screen.dart#L454) navega ahí tras cada registro. Nadie llega al dashboard sin cruzarla.

| Ancho | Desbordamientos | Píxeles |
|---:|---:|---|
| 320 | 2 | **144** y **176** |
| 360 | 2 | 104 y 136 |
| **375** | 2 | **89** y **121** |
| 390 | 2 | 74 y 106 |
| 414 | 2 | 50 y 82 |
| 480 | 1 | 16 |
| 600 | 0 | — |
| 840 | 0 | — |

Los dos `RenderFlex` están localizados por `debugCreator`:

1. `Row ← _AppBarTitleBox ← … ← NavigationToolbar` → el `Row` del `title:` en [profile_setup_screen.dart:56](../../../lib/features/profile/presentation/pages/profile_setup_screen.dart#L56) (`Icon` + `'AutoDoc'`).
2. `Row ← Align ← Padding ← … ← GestureDetector` → el `Row` interno del `TextButton.icon` de *Salir* en [profile_setup_screen.dart:75](../../../lib/features/profile/presentation/pages/profile_setup_screen.dart#L75).

**La causa es aritmética, no de estilo.** El `AppBar` reparte el ancho dando prioridad a `actions:`. Los `actions` de esta pantalla son dos: el `TextButton.icon` de *Salir* y una `Column` con `'PASO 1 DE 1'` (10 px, `letterSpacing: 1.5`) sobre una barra de 60 px, con `EdgeInsets.only(right: 24, left: 8)`. Entre ambos consumen ~250 px de los 320 disponibles; al `title:` le quedan ~70 px para un `Icon(22)` + `SizedBox(8)` + `'AutoDoc'` en `montserratAlternates` a 18 px negrita, que necesita ~214. De ahí los 144 px.

**Solo deja de desbordar a partir de 600 px**, es decir, en `medium`. En `compact` —el 100 % del uso real— desborda siempre.

#### `onboarding_screen` — lanza una aserción en horizontal

[onboarding_screen.dart:133-138](../../../lib/features/onboarding/presentation/pages/onboarding_screen.dart#L133-L138):

```dart
ConstrainedBox(
  constraints: BoxConstraints(
    maxHeight: MediaQuery.of(context).size.height * 0.4,
    minHeight: 200,
  ),
```

Cuando la altura del viewport es menor que **500 px**, `maxHeight` cae por debajo de `minHeight` y las restricciones dejan de estar normalizadas. `ConstrainedBox` valida sus restricciones en el constructor, así que el resultado es:

```
BoxConstraints has non-normalized height constraints.
```

Verificado a **800 × 400**. Todos los teléfonos en horizontal miden menos de 500 px de alto: un iPhone SE en horizontal son 320 px, un Pixel ~411. **Girar el teléfono durante el onboarding rompe la pantalla.** Es la única `MediaQuery` cruda del módulo (§0 columna MQ = 1) y también su único `LayoutBuilder`.

#### `splash_screen` — desborda 92 px en vertical en horizontal

Verificado a **800 × 400**: `A RenderFlex overflowed by 92 pixels on the bottom.` La `Column` de [splash_screen.dart:173-174](../../../lib/features/splash/presentation/pages/splash_screen.dart#L173-L174) usa `mainAxisAlignment: spaceBetween` con contenido de altura fija (logo 128, texto de 48 px, indicador 48, barra 4) dentro de un `Padding(32)`. A 320 × 640 y 375 × 812 está limpia; en horizontal no cabe.

#### `auth_screen` — desborda a 320 px **solo en inglés**

Este es el más instructivo de los cuatro, porque explica por qué nadie lo ha visto.

El separador de [auth_screen.dart:308-330](../../../lib/features/auth/presentation/pages/auth_screen.dart#L308-L330) es `Expanded(Divider) + Padding(horizontal: 16, Text) + Expanded(Divider)`. A 320 px la tarjeta mide 272 y su contenido interior **208 px**. Medido:

| Locale | Texto | Ancho del texto | + padding 32 | Resultado |
|---|---|---:|---:|---|
| `es` | `"O CONTINUAR CON"` | 172,5 px | 204,5 | cabe, **3,5 px** para dos `Divider` |
| `en` | `"OR CONTINUE WITH"` | 184,0 px | 216,0 | **desborda 10,0 px** |

El equipo desarrolla en español y el margen en español es de 3,5 píxeles. Una palabra más larga en cualquier idioma futuro rompe la pantalla de login. El arreglo no es acortar la cadena: es que el `Text` sea `Flexible` con `ellipsis`, o que el separador se apile bajo `compact`.

---

### 0.2 Los seis desbordamientos, en una tabla

Todos verificados en esta sesión, sobre `HEAD`, con `FlutterError.onError` capturado.

| # | Pantalla | Condición | Síntoma | Origen |
|---|---|---|---|---|
| 1 | `profile_setup` | ancho < 600 | `RenderFlex` horizontal, 16–144 px | `AppBar` `title:` L56 |
| 2 | `profile_setup` | ancho < 480 | `RenderFlex` horizontal, 82–176 px | `TextButton.icon` *Salir* L75 |
| 3 | `onboarding` | **alto < 500** | `BoxConstraints has non-normalized height` | `ConstrainedBox` L133 |
| 4 | `onboarding` | ancho ≤ 320 | `RenderFlex` horizontal, 24 px | barra superior L67 |
| 5 | `splash` | alto < ~500 | `RenderFlex` vertical, 92 px | `Column` `spaceBetween` L173 |
| 6 | `auth` | ancho ≤ 320 **y locale `en`** | `RenderFlex` horizontal, 10 px | separador L308 |

**Cinco de las seis pantallas de la fase desbordan.** La sexta (`about_screen`) no desborda porque no tiene nada que desbordar; su problema es el contrario (§0.6.4).

---

### 0.3 `user_profile_screen` bifurcó la paleta

53 colores literales no son 53 descuidos. Son **una segunda paleta**, declarada en el `build()`:

[user_profile_screen.dart:99-107](../../../lib/features/profile/presentation/pages/user_profile_screen.dart#L99-L107)

```dart
final primaryPurple = theme.colorScheme.primary;
final accentColor = const Color(0xFF98FFD9);
final bgColorStart = isDark ? const Color(0xFF1E293B) : const Color(0xFFF7F6F8);
final bgColorEnd   = isDark ? const Color(0xFF0F172A) : const Color(0xFFECE9F1);
final textColor    = isDark ? Colors.white : const Color(0xFF0F172A);
```

Cuatro de esos literales son **copias exactas de `AppPalette`**: `#F7F6F8` es `lightSurface`, `#0F172A` es `lightTextPrimary` y `darkSurface`, `#1E293B` es `darkSurfaceVariant`. Y `#64748B`, que aparece cuatro veces más abajo, es `lightTextSecondary`.

**Consecuencia concreta y comprobable:** la Fase 1 Task 4 corrige `lightTextSecondary` porque mide 4,42:1. Esa corrección **no llegará a esta pantalla**, porque la pantalla no lee el token: lo copió. Cualquier ajuste futuro de marca dejará esta pantalla atrás en silencio. Ese es el argumento real para tokenizarla, más fuerte que el conteo.

**`#98FFD9` no existe en `AppPalette`.** Es un color inventado en esta pantalla. Y tiene dos problemas:

1. Se pasa a `_buildProfileHeader(user, primaryPurple, accentColor, textColor)` ([L187-192](../../../lib/features/profile/presentation/pages/user_profile_screen.dart#L187-L192)) donde el parámetro se llama `accent` y **no se usa en ninguna línea del cuerpo**. Es un parámetro muerto.
2. Su uso real es `Switch.adaptive(activeTrackColor: const Color(0xFF98FFD9))` ([L566-570](../../../lib/features/profile/presentation/pages/user_profile_screen.dart#L566-L570)). El *thumb* del `Switch` en Material 3 activo es `colorScheme.onPrimary` — blanco en tema claro. Luminancia relativa de `#98FFD9` = 0,8321; contra blanco (1,0):

   ```
   (1,0 + 0,05) / (0,8321 + 0,05) = 1,19:1
   ```

   **Un interruptor blanco sobre una pista casi blanca.** El usuario no puede ver si el modo oscuro, el idioma o el tema del sistema están activados. Tres interruptores, los tres ilegibles.

#### El defecto de 1,00:1: no puedes ver tu propio nombre mientras lo editas

[user_profile_screen.dart:596-611](../../../lib/features/profile/presentation/pages/user_profile_screen.dart#L596-L611), en `_buildInfoField`:

```dart
style: GoogleFonts.inter(
  color: isDark ? Colors.white : const Color(0xFF1E293B),   // ← texto
),
decoration: InputDecoration(
  filled: true,
  fillColor: enabled ? Colors.white : Colors.transparent,   // ← fondo
```

El color del texto depende del tema. El color del relleno **no**: es `Colors.white` siempre que el campo esté habilitado, y el campo se habilita cuando `_isEditing` es cierto.

**En tema oscuro, al pulsar el lápiz de editar, el campo del nombre se vuelve blanco y el texto sigue siendo blanco: 1,00:1.** El usuario edita a ciegas. Es exactamente la misma clase de fallo que la Fase 6 encontró en las tarjetas del chat —un color de texto que asume un fondo y un fondo que asume otro tema— y aparece aquí de forma independiente.

Los bordes tienen el mismo problema en menor grado: `enabledBorder: BorderSide(color: Colors.grey[200]!)` ([L622-625](../../../lib/features/profile/presentation/pages/user_profile_screen.dart#L622-L625)) pinta `#EEEEEE` en los dos temas, un borde casi blanco alrededor de un campo sobre una tarjeta oscura.

#### No se puede editar el perfil por encima del corte de tablet

[user_profile_screen.dart:180-181](../../../lib/features/profile/presentation/pages/user_profile_screen.dart#L180-L181):

```dart
if (!ResponsiveBreakpoints.of(context).largerThan(TABLET))
  _buildAppBar(context, primaryPurple, textColor),
```

El único control que cambia `_isEditing` es el `IconButton` de la derecha de ese `_buildAppBar` ([L259-267](../../../lib/features/profile/presentation/pages/user_profile_screen.dart#L259-L267)). Y el `FloatingActionButton` que guarda solo existe `if (_isEditing)` ([L207](../../../lib/features/profile/presentation/pages/user_profile_screen.dart#L207)).

Por encima de 800 px la barra no se dibuja → no hay botón de editar → `_isEditing` nunca puede volverse `true` → no hay botón de guardar. **En web y en tablet horizontal el perfil es de solo lectura, sin que nada lo indique.** No es una decisión de diseño documentada: es la consecuencia no intencionada de esconder una barra que contenía la única acción.

Tras la Fase 2 Task 1 el corte pasa de `> 800` a `≥ 840`, pero **el fallo sobrevive intacto** — solo se mueve. Lo arregla la Task 13 de esta fase.

---

### 0.4 El splash no espera a la carga; la carga espera al splash

[splash_screen.dart:34](../../../lib/features/splash/presentation/pages/splash_screen.dart#L34):

```dart
Future.delayed(const Duration(seconds: 3), () async {
```

Antes de **comprobar nada**, la pantalla espera tres segundos fijos. Después, si hay usuario autenticado, entra en un bucle de espera ([L49-55](../../../lib/features/splash/presentation/pages/splash_screen.dart#L49-L55)):

```dart
int attempts = 0;
while ((!profileProvider.hasAttemptedFetch || profileProvider.isLoading) && attempts < 10) {
  await Future.delayed(const Duration(milliseconds: 500));
  attempts++;
}
```

10 × 500 ms = **5 segundos más**. Peor caso: **8 segundos de splash** para un usuario con sesión iniciada y una red lenta. Mejor caso, con todo en caché: 3 segundos exactos, ni uno menos, porque los 3 s no dependen de nada.

Y la barra de progreso de [L350-352](../../../lib/features/splash/presentation/pages/splash_screen.dart#L350-L352) es un `TweenAnimationBuilder` de `0.0` a `1.0` en `Duration(seconds: 3)` — **una barra falsa** que no mide ninguna carga. Llega al 100 % justo cuando arranca la comprobación real y después puede quedarse llena hasta cinco segundos.

Esto no es cosmético: es el arranque percibido de la aplicación, y es el número que un usuario juzga antes que ninguna otra cosa.

**Restricción que impone al plan:** el `AnimationController` de [L28-31](../../../lib/features/splash/presentation/pages/splash_screen.dart#L28-L31) usa `..repeat()`, que no termina nunca. Cualquier test que haga `pumpAndSettle()` **mientras el splash está montado se cuelga**. El test existente ([splash_screen_onboarding_test.dart](../../../test/features/splash/presentation/pages/splash_screen_onboarding_test.dart)) sobrevive porque solo llama a `pumpAndSettle()` *después* de haber navegado fuera. La Task 1 de esta fase resuelve esto en el harness; no lo resuelvas ad-hoc en cada test.

#### El nombre de la app es medio invisible en tema oscuro

[splash_screen.dart:256-286](../../../lib/features/splash/presentation/pages/splash_screen.dart#L256-L286) pinta `"Auto"` en `colors.success` y `"Doc"` en `colors.secondary`, ambos a 48 px sobre un fondo `colors.primary`.

| Tema | Fondo | `"Auto"` | ratio | `"Doc"` | ratio |
|---|---|---|---:|---|---:|
| claro | `#522C81` | `#48BB78` | **4,25:1** ✓ | `#81E6D9` | 7,00:1 ✓ |
| oscuro | `#81E6D9` | `#48BB78` | **1,65:1** ✗ | `#522C81` | 7,00:1 ✓ |

En oscuro `primary` y `success` son ambos claros, así que la primera mitad del nombre de la aplicación cae a **1,65:1** — por debajo incluso del umbral de 3:1 para texto grande — mientras la segunda mitad se lee a 7,00:1. El logotipo aparece partido por la mitad.

Nota para quien ejecute: el problema es el **par**, no `lightSuccess` por sí solo. Aquí `success` es el color equivocado para un texto de marca; ver §19.3, que hereda de la Fase 6 el bloqueo abierto sobre `lightSuccess`.

---

### 0.5 Correcciones al maestro §5.4

Cinco filas de la tabla del maestro estaban mal medidas o describían algo que el código no hace. Se corrigen en el maestro al ejecutar la Task 14.

1. **`user_profile_screen` tiene 53 colores literales, no 33.** El conteo original omitió los 17 `Color(0xFF…)`. Y la instrucción *"Migrar las 2 llamadas a `responsive_framework`"* **ya no corresponde a esta fase**: la [Fase 2 Task 1](2026-08-10-ui-ux-overhaul-02-shell-navigation.md) declara explícitamente `user_profile_screen.dart:2,119,180` entre sus ficheros a modificar. Esta fase **consume** esa migración; lo que añade es arreglar el fallo funcional que la migración conserva (§0.3).

2. **`profile_setup_screen` no es multi-paso.** El maestro dice *"Onboarding de perfil, multi-paso"*. El indicador de la barra superior dice literalmente `'PASO 1 DE 1'` ([L103](../../../lib/features/profile/presentation/pages/profile_setup_screen.dart#L103)) sobre un `FractionallySizedBox(widthFactor: 1.0)` ([L119-121](../../../lib/features/profile/presentation/pages/profile_setup_screen.dart#L119-L121)) — una barra de progreso que está al 100 % antes de que el usuario escriba nada. Es un único formulario. El contrato *"Progreso visible"* no aplica; lo que aplica es **quitar el indicador falso**, porque un progreso que siempre marca completo es peor que ninguno.

3. **`login_screen.dart` no es una pantalla.** El maestro le asigna *"Mismo tratamiento que `auth_screen`"*. Son **15 líneas** que devuelven `const AuthScreen(isLogin: true)`. Su comentario de documentación afirma envolver el layout *"with a `SingleChildScrollView` and `ConstrainedBox` to prevent visual overflow in landscape mode"* — **no hace nada de eso**; esos widgets están dentro de `AuthScreen`. Ver §0.6.5 sobre su test.

4. **El módulo tiene 3 widgets de `auth` que el maestro no inventarió**: `auth_background_blobs` (58), `auth_bottom_nav` (66) y `auth_logo_section` (46). Suman 170 líneas y contienen dos de los defectos de accesibilidad de la fase (§0.6.2).

5. **`about_screen` no es *"la más barata"* sin más.** Es barata en líneas, pero contiene el peor contraste medido de la fase (§0.6.4) y un `setState` sin guarda de `mounted`. Sigue siendo buena primera tarea de pantalla; el contrato es correcto, la caracterización no.

---

### 0.6 Otros defectos verificados

#### 0.6.1 Las 2 únicas `Semantics` de la app se anuncian dos veces

[auth_screen.dart:464-467](../../../lib/features/auth/presentation/pages/auth_screen.dart#L464-L467) y [L512-514](../../../lib/features/auth/presentation/pages/auth_screen.dart#L512-L514):

```dart
Semantics(
  label: _isLoginMode ? 'Botón Iniciar sesión' : 'Botón Registrarse',
  button: true,
```

`button: true` ya hace que el lector de pantalla anuncie el rol. Con la etiqueta empezando por *"Botón"*, TalkBack lee **"Botón Iniciar sesión, botón"**. Además las tres etiquetas están **en español literal** en la única pantalla del proyecto que localiza todo lo demás: un usuario con el sistema en inglés oye la interfaz en inglés y los botones en español.

El maestro pedía *"elevar a referencia de a11y del resto"*. La referencia hay que arreglarla antes de elevarla.

#### 0.6.2 Objetivos táctiles por debajo del mínimo, medidos

| Control | Fichero | Tamaño medido | Mínimo |
|---|---|---:|---:|
| `Checkbox` de *Recordarme* | [auth_screen.dart:258-271](../../../lib/features/auth/presentation/pages/auth_screen.dart#L258-L271) | **20 × 20** (a 320, 375 **y** 1440) | 48 × 48 |
| *"¿Olvidaste tu contraseña?"* | [auth_screen.dart:286-290](../../../lib/features/auth/presentation/pages/auth_screen.dart#L286-L290) | `minimumSize: Size.zero` + `shrinkWrap` | 48 × 48 |
| Acciones de `AuthBottomNav` | [auth_bottom_nav.dart:45-64](../../../lib/features/auth/presentation/widgets/auth_bottom_nav.dart#L45-L64) | `Icon(20)` + `labelSmall`, sin padding | 48 × 48 |
| Cámara de perfil | [profile_setup_screen.dart:323-366](../../../lib/features/profile/presentation/pages/profile_setup_screen.dart#L323-L366) | `padding 8` + `Icon(16)` ≈ 32 × 32 | 48 × 48 |
| Cámara de perfil | [user_profile_screen.dart:337-352](../../../lib/features/profile/presentation/pages/user_profile_screen.dart#L337-L352) | `padding 8` + `Icon(20)` ≈ 36 × 36 | 48 × 48 |

El `Checkbox` de 20 × 20 se midió a los tres anchos: **`Responsive` no lo toca**, porque está dentro de un `SizedBox(width: 20, height: 20)` literal. Es la prueba de que el sistema de escalado actual no resuelve accesibilidad.

Los tres botones de `AuthBottomNav` (*Ayuda*, *Privacidad*, *Términos*) además **no llevan a ningún sitio**: muestran un `SnackBar` que dice `'Abriendo sección de $label...'` ([L47-49](../../../lib/features/auth/presentation/widgets/auth_bottom_nav.dart#L47-L49)) y nada más. Tres callejones sin salida en la pantalla de login, dos de ellos legalmente relevantes (privacidad y términos). `about_screen` **sí** tiene las URLs reales (`https://autodoc.app/privacidad` y `/terminos`, [about_screen.dart:136,146](../../../lib/features/profile/presentation/pages/about_screen.dart#L136-L146)).

#### 0.6.3 El onboarding muestra tres veces la misma imagen de relleno de un CDN de Google

[onboarding_screen.dart:21-46](../../../lib/features/onboarding/presentation/pages/onboarding_screen.dart#L21-L46). Las tres diapositivas comparten `imageUrl`, y la segunda lo dice en un comentario: `// Reusing placeholder as requested`. La URL es `https://lh3.googleusercontent.com/aida-public/AB6AXu…` — un enlace efímero generado por una herramienta de diseño.

`CachedNetworkImage` se usa **sin `errorWidget`** ([L220-232](../../../lib/features/onboarding/presentation/pages/onboarding_screen.dart#L220-L232)); solo hay `placeholder`, que es un `Container` de color plano. Cuando la URL caduque —o el usuario esté sin red, que es el caso normal en un primer arranque— **el panel se queda vacío para siempre, sin mensaje**. La primera pantalla de la aplicación.

`assets/images/` contiene hoy `dashboard_screen_lightmode.jpg`, `garage_screen_lightmode.jpg`, `workshop-directory_screen_lightmode.jpg` y `default_vehicle.jpg`, y `assets/` está declarado en [pubspec.yaml:144-146](../../../pubspec.yaml#L144-L146). No hay ilustraciones de onboarding. Ver §19.1.

#### 0.6.4 `about_screen`: el peor contraste medido de la fase

[about_screen.dart:153-160](../../../lib/features/profile/presentation/pages/about_screen.dart#L153-L160), el aviso de copyright:

```dart
color: colors.textSecondary.withValues(alpha: 0.7),
fontSize: 12,
```

`#64748B` al 70 % compuesto sobre `lightSurface` `#F7F6F8` da `#909BAC`. Contra el mismo fondo:

```
(0,92474 + 0,05) / (0,32353 + 0,05) = 2,61:1
```

Texto de 12 px a **2,61:1**, cuando el mínimo es 4,5:1. Bajar la opacidad de un token que ya está al límite (§19.4) es la forma más directa de romper el contraste, y aquí está hecho explícitamente.

Además, a 1440 px la tarjeta de información mide **1392 px de ancho** (medido) — cuatro `ListTile` con el *chevron* a 1392 px del icono. Y `_initPackageInfo` ([L25-31](../../../lib/features/profile/presentation/pages/about_screen.dart#L25-L31)) llama a `setState` tras un `await` **sin comprobar `mounted`**: salir de la pantalla mientras carga la versión lanza.

Detalle menor pero real: los tres `ListTile` con `title: const Text(...)` sin color heredan el `onSurface` del `ThemeData` base de Material, no `AppColors`. Medido en oscuro: `#E7E0E8`. Es un **cuarto** origen de color en la pantalla, además de los tokens, los literales y `GoogleFonts`.

#### 0.6.5 El test de `login_screen` no prueba nada

[login_screen_test.dart](../../../test/features/auth/login_screen_test.dart) se titula *"LoginScreen uses SingleChildScrollView and ConstrainedBox for landscape layout"* y afirma:

```dart
expect(find.byType(SingleChildScrollView), findsAtLeastNWidgets(1));
expect(find.byType(ConstrainedBox), findsAtLeastNWidgets(1));
```

`LoginScreen` no contiene ninguno de los dos: los encuentra porque `AuthScreen` los tiene, y `ConstrainedBox` aparece además en decenas de widgets internos de Material. El test pasa por construcción y seguiría pasando aunque `LoginScreen` estuviera vacío. **No puede romperse**, así que no protege nada. La Task 7 lo sustituye por uno que sí falla si el contrato se rompe.

#### 0.6.6 Fugas y datos que se pierden

| Qué | Dónde | Efecto |
|---|---|---|
| `PageController` nunca se libera | [onboarding_screen.dart:18](../../../lib/features/onboarding/presentation/pages/onboarding_screen.dart#L18) — no hay `dispose()` | Fuga; aserción al recargar en caliente |
| `passwordController` nunca se libera | [user_profile_screen.dart:736](../../../lib/features/profile/presentation/pages/user_profile_screen.dart#L736) | Fuga en cada apertura del diálogo de borrado |
| `setState` tras `await` sin `mounted` | [about_screen.dart:27-30](../../../lib/features/profile/presentation/pages/about_screen.dart#L27-L30) | Excepción al salir durante la carga |
| `_notificationsEnabled` nunca se persiste | [profile_setup_screen.dart:26,603-612](../../../lib/features/profile/presentation/pages/profile_setup_screen.dart#L603-L612) | El usuario desactiva las notificaciones y la app las ignora. Ver §19.2 |

#### 0.6.7 Dos peticiones de red a terceros en la ruta de entrada

| Recurso | Origen | Dónde |
|---|---|---|
| Logotipo de Google | `https://www.google.com/images/branding/googleg/1x/googleg_standard_color_128dp.png` | [auth_screen.dart:538-543](../../../lib/features/auth/presentation/pages/auth_screen.dart#L538-L543) |
| Avatar por defecto | `https://www.w3schools.com/howto/img_avatar.png` | [user_profile_screen.dart:316-318](../../../lib/features/profile/presentation/pages/user_profile_screen.dart#L316-L318) |

El primero se descarga en cada visita a la pantalla de login y su `errorBuilder` es `Icon(Icons.g_mobiledata, color: Colors.blue)` — un color literal. El segundo hace que **cada usuario sin foto de perfil descargue un avatar de marcador de posición desde w3schools.com**, cada vez que abre su perfil.

#### 0.6.8 Cadenas sin localizar y claves de l10n muertas

`onboarding_screen`, `profile_setup_screen` y `splash_screen` tienen **cero** claves de l10n. Todo su texto es español literal en el código: ~50 cadenas, incluidos los tres títulos y descripciones del onboarding y los dos textos explicativos de rol.

Consecuencia: **un usuario con el sistema en inglés recibe el splash, el onboarding completo y la configuración de perfil en español**, y la app solo se vuelve bilingüe cuando llega al dashboard.

Al mismo tiempo, el ARB tiene claves definidas que nadie usa:

| Clave | Estado |
|---|---|
| `upDeleteAccountTitle` | Definida. El código usa `const Text('Eliminar Cuenta')` ([user_profile_screen.dart:748](../../../lib/features/profile/presentation/pages/user_profile_screen.dart#L748)) |
| `authTabLogin`, `authTabRegister`, `authTabSupport` | Definidas. `auth_screen` no tiene pestañas |

Ver §1.4: añadir claves queda fuera de alcance, **cablear las que ya existen no**.

---

### 0.7 Ficheros de la fase

| Fichero | LOC | Tarea |
|---|---:|---|
| `test/support/entry_harness.dart` | nuevo | Task 1 |
| `lib/features/profile/presentation/pages/about_screen.dart` | 167 | Task 2 |
| `lib/core/widgets/app_text_field.dart` | — | Task 3 (extensión aditiva) |
| `lib/features/auth/presentation/pages/auth_screen.dart` | 789 | Tasks 4 y 5 |
| `lib/features/auth/presentation/widgets/auth_bottom_nav.dart` | 66 | Task 6 |
| `lib/features/auth/presentation/widgets/auth_logo_section.dart` | 46 | Task 6 |
| `lib/features/auth/presentation/widgets/auth_background_blobs.dart` | 58 | Task 6 |
| `lib/features/auth/presentation/screens/login_screen.dart` | 15 | Task 7 |
| `lib/features/onboarding/presentation/pages/onboarding_screen.dart` | 449 | Tasks 8 y 9 |
| `lib/features/splash/presentation/pages/splash_screen.dart` | 376 | Task 10 |
| `lib/features/profile/presentation/pages/profile_setup_screen.dart` | 842 | Task 11 |
| `lib/features/profile/presentation/pages/user_profile_screen.dart` | 920 | Tasks 12 y 13 |
| `test/support/tokenized_paths.dart` | — | Task 14 |

---

## 1. Reglas de esta fase

Además de §2 del maestro:

**1.1 — El módulo llega en verde.** `flutter test test/features/auth/ test/features/profile/ test/features/splash/` da **23 tests, todos pasando** en `HEAD`. A diferencia de la Fase 6, aquí no hay nada roto que arreglar en la suite: cualquier rojo que aparezca durante la fase lo has introducido tú.

**1.2 — `pumpAndSettle` es peligroso en dos de estas pantallas y obligatorio en otra.**

- **`splash_screen`**: su `AnimationController` usa `..repeat()`. `pumpAndSettle()` con el splash montado **no termina nunca**. Usa `pump(Duration)` explícito.
- **`onboarding_screen`**: con `pump()` a secas deja temporizadores vivos y el test falla en el *teardown* con `Failed assertion: '!timersPending'`. Necesita `pumpAndSettle()`.
- La Task 1 encapsula ambas reglas. No las reimplementes por tarea.

**1.3 — No se toca `data/` ni `providers/`.** Regla del maestro §2. Aplica con fuerza aquí: `profile_setup_screen` guarda un `UserModel` y el modelo no tiene campo de notificaciones (§19.2).

**1.4 — No se añaden claves de l10n**, en coherencia con las Fases 4 y 6. **Excepción explícita:** cablear claves que **ya existen** en el ARB y no se usan (§0.6.8) no añade ninguna clave y sí entra. La deuda de las ~50 cadenas sin localizar se declara en §18.1 y es la mayor de la fase.

**1.5 — No se cambia ningún flujo de negocio.** En concreto: no se cambia a qué ruta navega cada pantalla, ni el orden splash → onboarding → login → setup, ni la semántica de `rol`. La Task 10 cambia *cuándo* navega el splash, no *adónde*.

**1.6 — Cada tarea verifica en `es` y en `en`.** §0.1 demuestra que un desbordamiento de esta fase depende del idioma. El harness de la Task 1 lo parametriza; úsalo.

**1.7 — Los blobs decorativos no son negociables como marca, pero sí como coste.** `auth`, `splash`, `onboarding` y `profile_setup` pintan entre dos y cuatro círculos difuminados, y `onboarding` además apila **tres** capas de desenfoque simultáneas (dos `ImageFiltered` de sigma 30 y 40, más un `BackdropFilter` de 12). Se conservan; se les pone presupuesto y se respeta *reduced motion*.

---

## 2. Task 1: `entry_harness.dart` — el andamiaje sin el que ninguna otra tarea se puede escribir

**Files:**
- Create: `test/support/entry_harness.dart`
- Test: `test/support/entry_harness_test.dart`

**Interfaces:**
- Consumes: `pumpAtWidth`, `kAuditWidths` (Fase 1 Task 7); `AppTheme.light` / `AppTheme.dark`; `AppLocalizations`; `MockAuthService`, `MockAdminAuthService` (`test/helpers/test_helpers.mocks.dart`).
- Produces: `Future<void> pumpEntry(WidgetTester, Widget, {double width, double height, Brightness brightness, Locale locale, bool disableAnimations, UserProfileProvider? profile, AuthSessionProvider? session})`; `Future<void> pumpEntryNoSettle(...)` con la misma firma; `List<FlutterErrorDetails> collectLayoutErrors(void Function())`; `Future<List<FlutterErrorDetails>> pumpEntryCollecting(...)`; `class FakeUserProfileProvider`; `UserModel testUser({...})`; `const List<Locale> kEntryLocales`.

**Por qué esta tarea existe y va primera.** Tres hechos medidos en §0 hacen que el harness genérico de la Fase 1 no baste para este módulo:

1. **`tester.takeException()` devuelve una sola excepción.** `profile_setup_screen` produce **dos** `RenderFlex` simultáneos y el framework colapsa ambos en `Multiple exceptions (2) were detected…`. Sin capturar `FlutterError.onError` no se puede afirmar *cuántos* desbordamientos quedan ni de qué tamaño, que es exactamente el criterio de aceptación de la Task 11.
2. **`pumpAndSettle` se cuelga en el splash y es obligatorio en el onboarding** (§1.2). Dos reglas contradictorias que deben vivir en un sitio, no repetidas en diez ficheros.
3. **Un desbordamiento de esta fase depende del idioma** (§0.1). Sin un parámetro `locale` los tests no lo verían.

- [ ] **Step 1: invocar las skills**

`Skill(graphify)` — `graphify query "what does user_profile_screen consume from providers"` para confirmar la superficie exacta que el doble de prueba debe implementar antes de escribirlo.

`Skill(ui-ux-pro-max:ui-ux-pro-max)` + `scripts/search.py "authentication signup onboarding profile settings" --stack flutter` — anota qué recomienda para pantallas de entrada; se usará en las Tasks 4, 5, 8 y 11.

`Skill(find-animation-opportunities)` sobre `lib/features/auth/ lib/features/onboarding/ lib/features/splash/ lib/features/profile/` — una vez por módulo, como manda §7 del maestro. Anota su veredicto sobre las cuatro pantallas con blobs animados y sobre el splash.

- [ ] **Step 2: escribir el test que falla**

```dart
// test/support/entry_harness_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'entry_harness.dart';

void main() {
  testWidgets('pumpEntry monta con AppColors, l10n y el ancho pedido', (
    tester,
  ) async {
    late BuildContext captured;
    await pumpEntry(
      tester,
      Builder(
        builder: (context) {
          captured = context;
          return const SizedBox.shrink();
        },
      ),
      width: 375,
    );

    expect(Theme.of(captured).extension<AppColorsProbe>(), isNull);
    expect(MediaQuery.sizeOf(captured).width, 375);
    expect(Localizations.localeOf(captured), const Locale('es'));
  });

  testWidgets('pumpEntry acepta locale en', (tester) async {
    late BuildContext captured;
    await pumpEntry(
      tester,
      Builder(
        builder: (context) {
          captured = context;
          return const SizedBox.shrink();
        },
      ),
      width: 375,
      locale: const Locale('en'),
    );
    expect(Localizations.localeOf(captured), const Locale('en'));
  });

  testWidgets('collectLayoutErrors devuelve los DOS desbordamientos', (
    tester,
  ) async {
    final errors = await pumpEntryCollecting(
      tester,
      const _TwoOverflows(),
      width: 200,
    );
    expect(errors, hasLength(2));
    expect(errors.every((e) => e.exception.toString().contains('overflowed')), isTrue);
  });

  testWidgets('FakeUserProfileProvider expone userData y notifica', (
    tester,
  ) async {
    final fake = FakeUserProfileProvider(userData: testUser(nombre: 'Ada'));
    var notified = 0;
    fake.addListener(() => notified++);
    expect(fake.userData!.nombreCompleto, 'Ada');
    expect(await fake.updateProfile(testUser(nombre: 'Grace')), isTrue);
    expect(fake.userData!.nombreCompleto, 'Grace');
    expect(notified, 1);
  });
}

class _TwoOverflows extends StatelessWidget {
  const _TwoOverflows();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        SizedBox(
          width: 100,
          child: Row(children: [SizedBox(width: 300, height: 10)]),
        ),
        SizedBox(
          width: 100,
          child: Row(children: [SizedBox(width: 400, height: 10)]),
        ),
      ],
    );
  }
}
```

> **Nota sobre `AppColorsProbe`:** no existe y no debe existir. Esa línea es un centinela deliberado: la primera aserción está escrita para **fallar a la compilación** y obligarte a leer el harness antes de darlo por bueno. Sustitúyela en el Step 4 por `expect(captured.appColors.primary, AppPalette.lightPrimary);` una vez que el harness compile.

- [ ] **Step 3: correr y confirmar el fallo exacto**

```bash
flutter test test/support/entry_harness_test.dart
```

Expected: error de compilación `Error: Couldn't resolve the package 'entry_harness'` o `Target of URI doesn't exist: 'entry_harness.dart'` — el fichero aún no existe. Ese es el fallo correcto para el primer paso.

- [ ] **Step 4: implementar el harness**

```dart
// test/support/entry_harness.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:autodoc/core/models/user_model.dart';
import 'package:autodoc/core/providers/language_provider.dart';
import 'package:autodoc/core/providers/theme_provider.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/features/auth/presentation/providers/auth_provider.dart';
import 'package:autodoc/l10n/app_localizations.dart';

import '../helpers/test_helpers.mocks.dart';

/// Los dos idiomas soportados. §0.1 de la Fase 7 demuestra que un
/// desbordamiento de este modulo solo aparece en `en`: toda tarea de
/// pantalla debe recorrer esta lista, no asumir `es`.
const List<Locale> kEntryLocales = <Locale>[Locale('es'), Locale('en')];

/// Usuario de prueba con valores estables (nada de `DateTime.now()`, que
/// haria los tests dependientes del reloj).
UserModel testUser({
  String id = 'u-1',
  String nombre = 'Usuario De Prueba',
  String correo = 'prueba@autodoc.app',
  String rol = 'Propietario',
  String? fotoPerfilUrl,
}) {
  return UserModel(
    idUsuario: id,
    nombreCompleto: nombre,
    correo: correo,
    rol: rol,
    fechaRegistro: DateTime.utc(2024, 3, 15),
    fotoPerfilUrl: fotoPerfilUrl,
  );
}

/// Doble de prueba de `UserProfileProvider`.
///
/// **Usa `implements`, no `extends`.** `UserProfileProvider` inicializa
/// `UserService()` como campo, y `UserService` toca
/// `FirebaseFirestore.instance` al construirse: heredar de el hace estallar
/// el test antes del primer `pump`. Misma leccion que la Fase 6.
class FakeUserProfileProvider with ChangeNotifier implements UserProfileProvider {
  FakeUserProfileProvider({
    UserModel? userData,
    this.isLoading = false,
    this.error,
    this.updateSucceeds = true,
  }) : _userData = userData;

  UserModel? _userData;
  @override
  bool isLoading;
  @override
  String? error;

  /// Controla el valor que devuelve [updateProfile], para poder ejercitar
  /// la rama de error de la pantalla de perfil sin tocar Firebase.
  bool updateSucceeds;

  /// Ultima llamada recibida, para aserciones.
  UserModel? lastUpdated;
  XFile? lastImageFile;

  @override
  UserModel? get userData => _userData;

  @override
  bool get hasAttemptedFetch => true;

  @override
  String? get fetchedUserId => _userData?.idUsuario;

  @override
  bool hasAttemptedFetchFor(String userId) => _userData?.idUsuario == userId;

  @override
  Future<void> fetchUserData(String userId) async {}

  @override
  Future<bool> updateProfile(
    UserModel updatedUser, {
    XFile? imageFile,
    bool isNewUser = false,
  }) async {
    lastUpdated = updatedUser;
    lastImageFile = imageFile;
    if (!updateSucceeds) return false;
    _userData = updatedUser;
    notifyListeners();
    return true;
  }

  @override
  void clearUserData() {
    _userData = null;
    notifyListeners();
  }
}

Widget _wrap(
  Widget child, {
  required Brightness brightness,
  required Locale locale,
  required bool disableAnimations,
  UserProfileProvider? profile,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>(
        create: (_) => AuthProvider(
          authService: MockAuthService(),
          adminAuthService: MockAdminAuthService(),
        ),
      ),
      ChangeNotifierProvider<UserProfileProvider>.value(
        value: profile ?? FakeUserProfileProvider(userData: testUser()),
      ),
      ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
      ChangeNotifierProvider<LanguageProvider>(
        create: (_) => LanguageProvider(),
      ),
    ],
    child: MaterialApp(
      theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: disableAnimations),
          child: child,
        ),
      ),
    ),
  );
}

void _sizeView(WidgetTester tester, double width, double height) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Monta [child] y **asienta** las animaciones.
///
/// Necesario para `onboarding_screen`: con `pump()` a secas deja
/// temporizadores vivos y el test revienta en el teardown con
/// `Failed assertion: '!timersPending'`.
///
/// **No lo uses con `SplashScreen`** — su `AnimationController` usa
/// `..repeat()` y `pumpAndSettle` no termina nunca. Para el splash existe
/// [pumpEntryNoSettle].
Future<void> pumpEntry(
  WidgetTester tester,
  Widget child, {
  double width = 375,
  double height = 812,
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('es'),
  bool disableAnimations = false,
  UserProfileProvider? profile,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  _sizeView(tester, width, height);
  await tester.pumpWidget(
    _wrap(
      child,
      brightness: brightness,
      locale: locale,
      disableAnimations: disableAnimations,
      profile: profile,
    ),
  );
  await tester.pumpAndSettle(const Duration(milliseconds: 50));
}

/// Igual que [pumpEntry] pero avanza el reloj un tiempo acotado en vez de
/// asentar. Es la unica forma de montar `SplashScreen` en un test.
Future<void> pumpEntryNoSettle(
  WidgetTester tester,
  Widget child, {
  double width = 375,
  double height = 812,
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('es'),
  bool disableAnimations = false,
  UserProfileProvider? profile,
  Duration advance = const Duration(milliseconds: 500),
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  _sizeView(tester, width, height);
  await tester.pumpWidget(
    _wrap(
      child,
      brightness: brightness,
      locale: locale,
      disableAnimations: disableAnimations,
      profile: profile,
    ),
  );
  await tester.pump(advance);
}

/// Ejecuta [body] capturando **todos** los `FlutterErrorDetails` de layout.
///
/// `tester.takeException()` solo devuelve el primero; cuando hay dos o mas
/// los colapsa en `Multiple exceptions (N) were detected`, que no dice ni
/// cuantos pixeles ni donde. `profile_setup_screen` produce exactamente dos
/// (Fase 7 §0.1), asi que el criterio de aceptacion de su tarea necesita
/// esta funcion.
List<FlutterErrorDetails> collectLayoutErrors(void Function() body) {
  final captured = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = captured.add;
  try {
    body();
  } finally {
    FlutterError.onError = previous;
  }
  return captured;
}

/// Monta [child] y devuelve todos los errores de layout que produjo.
Future<List<FlutterErrorDetails>> pumpEntryCollecting(
  WidgetTester tester,
  Widget child, {
  double width = 375,
  double height = 812,
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('es'),
  bool disableAnimations = false,
  UserProfileProvider? profile,
}) async {
  final captured = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = captured.add;
  try {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    _sizeView(tester, width, height);
    await tester.pumpWidget(
      _wrap(
        child,
        brightness: brightness,
        locale: locale,
        disableAnimations: disableAnimations,
        profile: profile,
      ),
    );
    await tester.pump();
  } finally {
    FlutterError.onError = previous;
  }
  return captured;
}

/// Extrae los pixeles de un desbordamiento, para aserciones legibles.
/// Devuelve `null` si el error no es un `RenderFlex overflowed`.
double? overflowPixels(FlutterErrorDetails details) {
  final match = RegExp(
    r'overflowed by ([\d.]+) pixels',
  ).firstMatch(details.exception.toString());
  return match == null ? null : double.parse(match.group(1)!);
}
```

Sustituye ahora la línea centinela del test por:

```dart
expect(captured.appColors.primary, AppPalette.lightPrimary);
```

añadiendo `import 'package:autodoc/core/theme/app_colors.dart';` al test.

- [ ] **Step 5: correr y confirmar verde**

```bash
flutter test test/support/entry_harness_test.dart
```

Expected: 4 tests en verde.

- [ ] **Step 6: verificar la restricción del splash antes de escribir la Task 10**

Añade este test al mismo fichero. No es decorativo: convierte §1.2 en algo que el árbol comprueba.

```dart
  testWidgets('pumpEntryNoSettle monta un widget con animacion infinita', (
    tester,
  ) async {
    await pumpEntryNoSettle(tester, const _ForeverSpinner(), width: 320);
    expect(find.byType(_ForeverSpinner), findsOneWidget);
    // Sin asentar: si alguien cambia pumpEntryNoSettle por pumpEntry,
    // este test se cuelga en vez de fallar, y eso es la senal.
  });
```

```dart
class _ForeverSpinner extends StatefulWidget {
  const _ForeverSpinner();
  @override
  State<_ForeverSpinner> createState() => _ForeverSpinnerState();
}

class _ForeverSpinnerState extends State<_ForeverSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    duration: const Duration(seconds: 2),
    vsync: this,
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      RotationTransition(turns: _c, child: const SizedBox(width: 10, height: 10));
}
```

- [ ] **Step 7: cerrar**

```bash
dart format . && dart fix --apply && flutter analyze && flutter test
```

**Commit:** `test(entry): harness de montaje, locales y captura multiple de overflows para la fase 7`

---

## 3. Task 2: `about_screen` — tokens, ancho de lectura y el contraste de 2,61:1

**Files:**
- Modify: `lib/features/profile/presentation/pages/about_screen.dart`
- Test: `test/features/profile/presentation/pages/about_screen_responsive_test.dart`
- No tocar: `test/features/profile/presentation/pages/about_screen_navigation_test.dart` (debe seguir en verde)

**Interfaces:**
- Consumes: `WindowClass`, `AppBreakpoints.maxReadingWidth` (Fase 1 Task 1); `AppPageBody` (Fase 1 Task 5); `AppTextStyles`; `context.appColors`; `pumpEntry`, `kEntryLocales` (Task 1); `contrastRatio` (Fase 1 Task 4).
- Produces: nada público nuevo.

**Los cuatro defectos medidos** (§0.6.4):

1. Copyright a **2,61:1** por aplicar `alpha: 0.7` sobre `textSecondary`.
2. La tarjeta mide **1392 px** a 1440 px de ventana.
3. `setState` tras `await` sin `mounted`.
4. Dos `GoogleFonts.montserrat` y cinco `TextStyle` crudos con tamaños literales (16, 28, 12), en una pantalla que ya importa `AppTextStyles` en el resto del proyecto.

Y un quinto, de comportamiento: `_launchUrl` ([L33-38](../../../lib/features/profile/presentation/pages/about_screen.dart#L33-L38)) hace `if (await canLaunchUrl(url)) { await launchUrl(url); }` — si no se puede abrir, **no pasa nada en absoluto**. Tocar *Política de Privacidad* en un dispositivo sin navegador es un no-op silencioso.

- [ ] **Step 1: invocar las skills**

`Skill(ui-ux-pro-max:ui-ux-pro-max)` — `references/pro-rules.md` §Typography: *readable line length 45–75 characters*; §Color: *"Never rely on opacity to create a secondary text color — derive a token"*. Anota ambas en el commit.

- [ ] **Step 2: escribir el test que falla**

```dart
// test/features/profile/presentation/pages/about_screen_responsive_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/features/profile/presentation/pages/about_screen.dart';

import '../../../../support/contrast.dart';
import '../../../../support/entry_harness.dart';

void main() {
  testWidgets('el contenido no supera el ancho de lectura en large', (
    tester,
  ) async {
    await pumpEntry(tester, const AboutScreen(), width: 1440, height: 900);

    final card = find.byKey(const ValueKey('about-info-card'));
    expect(card, findsOneWidget);
    expect(
      tester.getSize(card).width,
      lessThanOrEqualTo(AppBreakpoints.maxReadingWidth),
    );
  });

  testWidgets('el copyright cumple 4.5:1 en claro y en oscuro', (tester) async {
    for (final brightness in Brightness.values) {
      await pumpEntry(
        tester,
        const AboutScreen(),
        width: 375,
        brightness: brightness,
      );
      final context = tester.element(find.byType(AboutScreen));
      final colors = context.appColors;

      final copyright = tester.widget<Text>(
        find.byKey(const ValueKey('about-copyright')),
      );
      final color = copyright.style!.color!;
      expect(
        contrastRatio(composite(color, colors.surface), colors.surface),
        greaterThanOrEqualTo(4.5),
        reason: 'copyright ilegible en $brightness',
      );
    }
  });

  testWidgets('no desborda en ningun ancho auditado, en ambos idiomas', (
    tester,
  ) async {
    for (final locale in kEntryLocales) {
      for (final width in kAuditWidths) {
        final errors = await pumpEntryCollecting(
          tester,
          const AboutScreen(),
          width: width,
          locale: locale,
        );
        expect(
          errors,
          isEmpty,
          reason: 'about_screen desborda a $width px en ${locale.languageCode}',
        );
      }
    }
  });

  testWidgets('no usa GoogleFonts ni tamanos de fuente literales', (
    tester,
  ) async {
    final source = File(
      'lib/features/profile/presentation/pages/about_screen.dart',
    ).readAsStringSync();
    expect(source.contains('GoogleFonts'), isFalse);
    expect(RegExp(r'fontSize:\s*\d').hasMatch(source), isFalse);
  });
}
```

Añade `import 'dart:io';` y el import de `kAuditWidths` desde `test/support/responsive_harness.dart`.

- [ ] **Step 3: correr y confirmar el fallo exacto**

```bash
flutter test test/features/profile/presentation/pages/about_screen_responsive_test.dart
```

Expected, cuatro fallos concretos:

1. `Expected: exactly one matching candidate / Actual: _KeyWidgetFinder:<Found 0 widgets with key [<'about-info-card'>]>` — las claves aún no existen.
2. Tras añadirlas, el ancho será **1392,0** frente a `lessThanOrEqualTo(720.0)`.
3. El contraste del copyright será **2.61** frente a `greaterThanOrEqualTo(4.5)`.
4. `Expected: <false> / Actual: <true>` en `GoogleFonts`.

- [ ] **Step 4: implementar**

Reemplaza el cuerpo de `about_screen.dart`. Cambios concretos:

```dart
  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;                       // ← guarda que faltaba
    setState(() {
      _version = info.version;
      _buildNumber = info.buildNumber;
    });
  }

  Future<void> _launchUrl(String urlString) async {
    final url = Uri.parse(urlString);
    final opened = await canLaunchUrl(url) && await launchUrl(url);
    if (!opened && mounted) {
      // El usuario merece saber que no pasó nada.
      AppSnackbar.show(context, context.l10n.upAboutLinkError,
          type: SnackbarType.error);
    }
  }
```

> **Alto.** `upAboutLinkError` **no existe** en el ARB y §1.4 prohíbe añadir claves. Usa en su lugar la cadena que ya existe para errores genéricos, o —si no la hay— deja el fallo visible sin texto nuevo mostrando el `SnackBar` con la URL:
>
> ```dart
>     if (!opened && mounted) {
>       AppSnackbar.show(context, urlString, type: SnackbarType.error);
>     }
> ```
>
> Es feo y es correcto: enseña al usuario la dirección que no se pudo abrir para que la copie. Queda anotado en §18.2 como deuda de copy.

El cuerpo:

```dart
  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surfaceContainer,
        elevation: 0,
        title: Text(
          'Acerca de AutoDoc',
          style: AppTextStyles.titleMedium.copyWith(color: colors.textPrimary),
        ),
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      body: AppPageBody(
        maxWidth: AppBreakpoints.maxReadingWidth,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: AppSpacing.xxl),
              Container(
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.directions_car,
                  size: 80,
                  color: colors.primary,
                  semanticLabel: 'AutoDoc',
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'AutoDoc',
                style: AppTextStyles.headlineMedium.copyWith(
                  color: colors.textPrimary,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Tu copiloto digital para el cuidado del vehículo',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: colors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxl),
              Container(
                key: const ValueKey('about-info-card'),
                decoration: BoxDecoration(
                  color: colors.surfaceContainer,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Column(
                  children: [
                    _tile(
                      colors,
                      icon: Icons.info_outline,
                      title: 'Versión',
                      trailing: Text(
                        _version.isEmpty ? '—' : '$_version ($_buildNumber)',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                    _divider(colors),
                    _tile(
                      colors,
                      icon: Icons.email_outlined,
                      title: 'Soporte Técnico',
                      onTap: () => _launchUrl('mailto:soporte@autodoc.app'),
                    ),
                    _divider(colors),
                    _tile(
                      colors,
                      icon: Icons.privacy_tip_outlined,
                      title: 'Política de Privacidad',
                      onTap: () => _launchUrl('https://autodoc.app/privacidad'),
                    ),
                    _divider(colors),
                    _tile(
                      colors,
                      icon: Icons.gavel_outlined,
                      title: 'Términos y Condiciones',
                      onTap: () => _launchUrl('https://autodoc.app/terminos'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                '© ${DateTime.now().year} AutoDoc Inc.\n'
                'Todos los derechos reservados.',
                key: const ValueKey('about-copyright'),
                style: AppTextStyles.bodySmall.copyWith(
                  color: colors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider(AppColors colors) =>
      Divider(height: 1, color: colors.outline.withValues(alpha: 0.2));

  Widget _tile(
    AppColors colors, {
    required IconData icon,
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: colors.primary),
      title: Text(
        title,
        style: AppTextStyles.bodyLarge.copyWith(color: colors.textPrimary),
      ),
      trailing:
          trailing ??
          (onTap == null
              ? null
              : Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: colors.textSecondary,
                )),
      onTap: onTap,
    );
  }
```

**Los tres cambios que hacen pasar los tests, explicados:**

- **El copyright pierde el `withValues(alpha: 0.7)`.** Pasa de `#909BAC` (2,61:1) a `#64748B` sobre `lightSurface`. Con la Fase 1 Task 4 aplicada eso es **≥ 4,5:1**; ver §19.4 — sin la Fase 1 este test falla por unas centésimas y el fallo parecerá estar aquí.
- **Los `ListTile` reciben color explícito** vía `_tile`, cerrando el cuarto origen de color (§0.6.4).
- **`_version.isEmpty ? '—'`** evita el `" ()"` que se ve durante la carga de `package_info_plus`.

- [ ] **Step 5: correr y confirmar verde**

```bash
flutter test test/features/profile/presentation/pages/about_screen_responsive_test.dart
flutter test test/features/profile/
```

Expected: los 4 nuevos en verde y `about_screen_navigation_test.dart` intacto.

- [ ] **Step 6: cerrar**

```bash
dart format . && dart fix --apply && flutter analyze && flutter test
```

**Commit:** `fix(about): ancho de lectura, contraste del copyright (2,61 a 4,5:1) y tokens de tipografia`

---

## 4. Task 3: extender `AppTextField` — lo que los formularios de esta fase necesitan y no tiene

**Files:**
- Modify: `lib/core/widgets/app_text_field.dart`
- Test: `test/core/widgets/app_text_field_entry_test.dart`

**Interfaces:**
- Consumes: `AppTextStyles`, `AppRadius`, `AppSpacing`, `context.appColors`; la versión de la Fase 3 Task 4 de este mismo fichero.
- Produces: `AppTextField` con seis parámetros nuevos, **todos opcionales y con valor por defecto que preserva el comportamiento actual**: `bool enabled = true`, `FocusNode? focusNode`, `TextInputAction? textInputAction`, `void Function(String)? onSubmitted`, `Iterable<String>? autofillHints`, `bool obscureToggle = false`.

**Por qué esta tarea y por qué aquí.** Las Tasks 4 y 11 sustituyen cinco `TextField` crudos por `AppTextField`. Hoy eso sería un **retroceso funcional**: el componente compartido no tiene `enabled` (que `user_profile_screen` necesita para su modo lectura/edición), ni `autofillHints` (sin los cuales los gestores de contraseñas dejan de funcionar en la pantalla de login), ni `textInputAction`/`onSubmitted` (hoy pulsar *Enter* en el formulario de login no hace nada), ni forma de mostrar la contraseña.

La Fase 3 Task 4 es dueña de este fichero y ya lo mejora. Esta tarea **añade encima**, sin cambiar nada de lo que aquella dejó. Si la Fase 3 aún no se ha ejecutado, **para y ejecútala primero**: escribir esto sobre la versión antigua provoca un conflicto garantizado.

- [ ] **Step 1: invocar las skills**

`Skill(ui-ux-pro-max:ui-ux-pro-max)` — `references/pro-rules.md` §Forms: *"Correct keyboard type"*, *"Autofill / password manager support"*, *"Show password toggle"*, *"Enter key submits"*. Los cuatro son exactamente los cuatro parámetros que faltan; anótalo.

- [ ] **Step 2: escribir el test que falla**

```dart
// test/core/widgets/app_text_field_entry_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/widgets/app_text_field.dart';

import '../../support/entry_harness.dart';

void main() {
  testWidgets('enabled: false deshabilita el campo', (tester) async {
    await pumpEntry(
      tester,
      const Scaffold(body: AppTextField(label: 'Nombre', enabled: false)),
    );
    final field = tester.widget<TextFormField>(find.byType(TextFormField));
    expect(field.enabled, isFalse);
  });

  testWidgets('propaga autofillHints y textInputAction', (tester) async {
    await pumpEntry(
      tester,
      const Scaffold(
        body: AppTextField(
          label: 'Correo',
          autofillHints: <String>[AutofillHints.email],
          textInputAction: TextInputAction.next,
        ),
      ),
    );
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.autofillHints, contains(AutofillHints.email));
    expect(editable.textInputAction, TextInputAction.next);
  });

  testWidgets('onSubmitted se dispara al enviar desde el teclado', (
    tester,
  ) async {
    String? submitted;
    await pumpEntry(
      tester,
      Scaffold(
        body: AppTextField(
          label: 'Correo',
          onSubmitted: (value) => submitted = value,
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField), 'ada@autodoc.app');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(submitted, 'ada@autodoc.app');
  });

  testWidgets('obscureToggle muestra y oculta la contrasena', (tester) async {
    await pumpEntry(
      tester,
      const Scaffold(
        body: AppTextField(
          label: 'Contraseña',
          obscureText: true,
          obscureToggle: true,
        ),
      ),
    );

    expect(
      tester.widget<EditableText>(find.byType(EditableText)).obscureText,
      isTrue,
    );

    final toggle = find.byKey(const ValueKey('app-text-field-obscure-toggle'));
    expect(toggle, findsOneWidget);
    expect(tester.getSize(toggle).height, greaterThanOrEqualTo(48));

    await tester.tap(toggle);
    await tester.pump();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).obscureText,
      isFalse,
    );
  });

  testWidgets('el toggle tiene tooltip', (tester) async {
    await pumpEntry(
      tester,
      const Scaffold(
        body: AppTextField(
          label: 'Contraseña',
          obscureText: true,
          obscureToggle: true,
        ),
      ),
    );
    expect(find.byType(Tooltip), findsWidgets);
  });
}
```

- [ ] **Step 3: correr y confirmar el fallo exacto**

```bash
flutter test test/core/widgets/app_text_field_entry_test.dart
```

Expected: cinco errores de compilación, uno por parámetro:
`Error: No named parameter with the name 'enabled'.` — y lo mismo para `autofillHints`, `textInputAction`, `onSubmitted` y `obscureToggle`.

- [ ] **Step 4: implementar**

`AppTextField` pasa de `StatelessWidget` a `StatefulWidget` **solo porque `obscureToggle` necesita estado local**. Todo lo demás se propaga tal cual.

```dart
class AppTextField extends StatefulWidget {
  // … campos existentes de la Fase 3 …

  /// Si `false`, el campo se muestra en modo lectura. `user_profile_screen`
  /// alterna entre lectura y edición con este parámetro.
  final bool enabled;

  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final void Function(String)? onSubmitted;

  /// Pistas para el gestor de contraseñas del sistema. Sin esto, iOS y
  /// Android no ofrecen rellenar el formulario de acceso.
  final Iterable<String>? autofillHints;

  /// Añade un botón de ojo que alterna [obscureText]. Solo tiene sentido
  /// cuando `obscureText` es `true`.
  final bool obscureToggle;

  const AppTextField({
    super.key,
    // … existentes …
    this.enabled = true,
    this.focusNode,
    this.textInputAction,
    this.onSubmitted,
    this.autofillHints,
    this.obscureToggle = false,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscured = widget.obscureText;

  @override
  void didUpdateWidget(AppTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.obscureText != widget.obscureText) {
      _obscured = widget.obscureText;
    }
  }

  Widget? _buildSuffix(AppColors colors) {
    if (!widget.obscureToggle) return widget.suffixIcon;
    return Tooltip(
      message: _obscured ? 'Mostrar contraseña' : 'Ocultar contraseña',
      child: IconButton(
        key: const ValueKey('app-text-field-obscure-toggle'),
        // 48x48 real: IconButton por defecto ya lo garantiza, pero lo
        // dejamos explícito porque InputDecoration puede encogerlo.
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        icon: Icon(
          _obscured
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
          color: colors.textSecondary,
        ),
        onPressed: () => setState(() => _obscured = !_obscured),
      ),
    );
  }
  // … build() idéntico al de la Fase 3 salvo los siete puntos de conexión …
}
```

Los puntos de conexión dentro del `TextFormField`:

```dart
        TextFormField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          enabled: widget.enabled,
          obscureText: _obscured,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          onFieldSubmitted: widget.onSubmitted,
          autofillHints: widget.enabled ? widget.autofillHints : null,
          // … el resto igual …
          decoration: InputDecoration(
            // … igual …
            suffixIcon: _buildSuffix(colors),
          ),
        ),
```

> **`autofillHints: widget.enabled ? … : null` no es cosmética.** Flutter lanza si un campo deshabilitado declara *autofill hints* dentro de un `AutofillGroup`; el ternario evita esa aserción cuando `user_profile_screen` pinta el correo en modo lectura.

Los dos textos del `Tooltip` son cadenas nuevas en español. §1.4 prohíbe **claves de ARB**, no literales; quedan anotados en §18.1 junto al resto.

- [ ] **Step 5: correr y confirmar verde**

```bash
flutter test test/core/widgets/
```

Expected: los 5 nuevos en verde **y** `app_text_field_test.dart` de la Fase 3 sin cambios — es la prueba de que la extensión es aditiva.

- [ ] **Step 6: cerrar**

```bash
dart format . && dart fix --apply && flutter analyze && flutter test
```

**Commit:** `feat(app-text-field): enabled, autofill, accion de teclado y toggle de contrasena (aditivo)`

---

## 5. Task 4: `auth_screen` — el formulario

**Files:**
- Modify: `lib/features/auth/presentation/pages/auth_screen.dart` (solo `_buildTextField`, `_buildGlassCard` de la mitad del formulario hacia abajo, `_buildSubmitButton`, `_buildGoogleButton`)
- Test: `test/features/auth/auth_screen_form_test.dart`

**Interfaces:**
- Consumes: `AppTextField` con los parámetros de la Task 3; `AppButton` (Fase 3 Task 1); `pumpEntry`, `pumpEntryCollecting`, `kEntryLocales`, `overflowPixels` (Task 1); `context.appColors`; `AppMotion` (Fase 1 Task 2).
- Produces: nada público nuevo.

**Los siete defectos que arregla, todos medidos o citados:**

| # | Defecto | Evidencia |
|---|---|---|
| 1 | Desborda **10,0 px** a 320 px en `en` | §0.1, medido |
| 2 | `Checkbox` de **20 × 20** en los tres anchos | §0.6.2, medido |
| 3 | *"¿Olvidaste tu contraseña?"* con `minimumSize: Size.zero` | [L286-290](../../../lib/features/auth/presentation/pages/auth_screen.dart#L286-L290) |
| 4 | Sin `autofillHints`, sin `keyboardType`, sin `textInputAction`: *Enter* no envía | [L369-386](../../../lib/features/auth/presentation/pages/auth_screen.dart#L369-L386) |
| 5 | Sin toggle de contraseña | [L371](../../../lib/features/auth/presentation/pages/auth_screen.dart#L371) |
| 6 | `Container(height: Responsive.size(context, 52))` alrededor del campo | [L363](../../../lib/features/auth/presentation/pages/auth_screen.dart#L363) |
| 7 | Errores de validación en `SnackBar`, no junto al campo | [L407-446](../../../lib/features/auth/presentation/pages/auth_screen.dart#L407-L446) |

**Sobre el #6, que es el menos obvio y el más grave para accesibilidad.** El campo va dentro de un `Container` de altura **fija** de 52 px escalada por ancho de ventana. `Responsive.size` multiplica por el ancho, no por la escala tipográfica del sistema. Un usuario con el tamaño de fuente al 200 % —una preferencia de accesibilidad de primer nivel en iOS y Android— obtiene un campo cuyo texto no cabe en su caja. El arreglo es quitar la altura fija: `AppTextField` se dimensiona por su contenido.

**Sobre el #7.** `_handleEmailRegister` valida el correo y la longitud de la contraseña y muestra el resultado en un `SnackBar` que tapa el propio formulario. La regla §8 de `ui-ux-pro-max` pide el error **junto al campo**. `AppTextField` ya acepta `validator`; basta con envolver en un `Form` y usarlo. **Esto no cambia ninguna regla de negocio**: las tres condiciones (`isEmpty`, `_isValidEmail`, `length < 6`) se conservan exactamente, solo cambia dónde se muestran.

- [ ] **Step 1: invocar las skills**

`Skill(ui-ux-pro-max:ui-ux-pro-max)` + `scripts/search.py "login signup form" --stack flutter` — §Forms completa. Verifica los cuatro puntos del checklist: teclado correcto, autofill, toggle de contraseña, *Enter* envía.

`Skill(emil-design-eng)` — sobre el `AnimatedSwitcher` de [L118-125](../../../lib/features/auth/presentation/pages/auth_screen.dart#L118-L125), que hoy usa `Duration(milliseconds: 300)` literal y la curva por defecto (`Curves.linear`). Anota la curva y duración que propone para un cambio de contenido de este tamaño.

- [ ] **Step 2: escribir el test que falla**

```dart
// test/features/auth/auth_screen_form_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/widgets/app_text_field.dart';
import 'package:autodoc/features/auth/presentation/pages/auth_screen.dart';

import '../../support/entry_harness.dart';

void main() {
  testWidgets('no desborda a 320 px en NINGUNO de los dos idiomas', (
    tester,
  ) async {
    for (final locale in kEntryLocales) {
      final errors = await pumpEntryCollecting(
        tester,
        const AuthScreen(isLogin: true),
        width: 320,
        locale: locale,
      );
      expect(
        errors,
        isEmpty,
        reason:
            'auth_screen desborda a 320 px en ${locale.languageCode}: '
            '${errors.map(overflowPixels).toList()}',
      );
    }
  });

  testWidgets('el checkbox de recordarme mide al menos 48x48', (tester) async {
    await pumpEntry(tester, const AuthScreen(isLogin: true), width: 375);
    final target = find.byKey(const ValueKey('auth-remember-me'));
    expect(target, findsOneWidget);
    final size = tester.getSize(target);
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('el enlace de contrasena olvidada mide al menos 48 de alto', (
    tester,
  ) async {
    await pumpEntry(tester, const AuthScreen(isLogin: true), width: 375);
    final target = find.byKey(const ValueKey('auth-forgot-password'));
    expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
  });

  testWidgets('los campos declaran teclado, autofill y accion', (tester) async {
    await pumpEntry(tester, const AuthScreen(isLogin: true), width: 375);

    final email = tester.widget<AppTextField>(
      find.byKey(const ValueKey('auth-email-field')),
    );
    expect(email.keyboardType, TextInputType.emailAddress);
    expect(email.autofillHints, contains(AutofillHints.username));
    expect(email.textInputAction, TextInputAction.next);

    final password = tester.widget<AppTextField>(
      find.byKey(const ValueKey('auth-password-field')),
    );
    expect(password.autofillHints, contains(AutofillHints.password));
    expect(password.textInputAction, TextInputAction.done);
    expect(password.obscureToggle, isTrue);
  });

  testWidgets('el formulario esta dentro de un AutofillGroup', (tester) async {
    await pumpEntry(tester, const AuthScreen(isLogin: true), width: 375);
    expect(find.byType(AutofillGroup), findsOneWidget);
  });

  testWidgets('registro con correo invalido muestra el error JUNTO al campo', (
    tester,
  ) async {
    await pumpEntry(tester, const AuthScreen(isLogin: false), width: 375);

    await tester.enterText(
      find.byKey(const ValueKey('auth-email-field')),
      'no-es-un-correo',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-password-field')),
      'secreta123',
    );
    await tester.tap(find.byKey(const ValueKey('auth-submit')));
    await tester.pumpAndSettle();

    // El error vive en el formulario, no en un SnackBar encima de el.
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Ingresa un correo válido'), findsOneWidget);
  });

  testWidgets('el campo del correo no tiene altura fija', (tester) async {
    await pumpEntry(tester, const AuthScreen(isLogin: true), width: 375);
    final small = tester.getSize(find.byKey(const ValueKey('auth-email-field')));

    await pumpEntry(
      tester,
      const AuthScreen(isLogin: true),
      width: 375,
      // Simula el tamano de fuente del sistema al 200 %.
      // (el harness aplica textScaler cuando se le pasa)
    );
    expect(small.height, greaterThan(0));
  });
}
```

> El último test es un **esqueleto deliberado**: `pumpEntry` no acepta `textScaler` todavía. En el Step 4 añade el parámetro `TextScaler textScaler = TextScaler.noScaling` a `pumpEntry`/`pumpEntryCollecting` en `entry_harness.dart` (una línea en `MediaQuery.copyWith`) y complétalo comparando la altura a `TextScaler.linear(2.0)` contra la altura sin escalar: debe **crecer**, no quedarse en 52.

- [ ] **Step 3: correr y confirmar el fallo exacto**

```bash
flutter test test/features/auth/auth_screen_form_test.dart
```

Expected, en este orden:

1. `auth_screen desborda a 320 px en en: [10.0]` — el desbordamiento de §0.1, ahora nombrado por el test.
2. `Found 0 widgets with key [<'auth-remember-me'>]` — las claves no existen.
3. Tras añadirlas, el `Checkbox` medirá **Size(20.0, 20.0)** contra `greaterThanOrEqualTo(48)`.
4. `type 'TextField' is not a subtype of type 'AppTextField'` — los campos aún son `TextField` crudos.
5. `Expected: exactly one matching candidate` para `AutofillGroup`: **findsNothing**.
6. En el test de validación: `find.byType(SnackBar)` encontrará **uno**, porque hoy el error va ahí.

- [ ] **Step 4: implementar**

**4a. Envolver en `Form` + `AutofillGroup`.** En `_buildGlassCard`, la `Column` interior pasa a:

```dart
          child: AutofillGroup(
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [ /* … */ ],
              ),
            ),
          ),
```

con `final _formKey = GlobalKey<FormState>();` en el estado.

**4b. Sustituir `_buildTextField` por dos `AppTextField`.** Borra el método `_buildTextField` completo ([L342-390](../../../lib/features/auth/presentation/pages/auth_screen.dart#L342-L390)) — desaparecen con él la altura fija de 52 y el `Container` decorado a mano.

```dart
              AppTextField(
                key: const ValueKey('auth-email-field'),
                label: _isLoginMode
                    ? context.l10n.authEmailOrUserLabel
                    : context.l10n.authEmailLabel,
                hintText: _isLoginMode
                    ? context.l10n.authEmailOrUserHint
                    : context.l10n.authEmailHint,
                controller: _emailController,
                prefixIcon: Icon(Icons.mail_outline, color: colors.textSecondary),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
                validator: (value) {
                  final email = (value ?? '').trim();
                  if (email.isEmpty) return context.l10n.authCompleteCredentials;
                  // En login se admite tambien usuario admin sin arroba:
                  // esa es la regla de negocio existente, no se cambia.
                  if (!_isLoginMode && !_isValidEmail(email)) {
                    return context.l10n.authEnterValidEmail;
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                key: const ValueKey('auth-password-field'),
                label: context.l10n.authPasswordLabel,
                hintText: context.l10n.authPasswordHint,
                controller: _passwordController,
                prefixIcon: Icon(Icons.lock_outline, color: colors.textSecondary),
                obscureText: true,
                obscureToggle: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => _submit(),
                validator: (value) {
                  final pass = value ?? '';
                  if (pass.isEmpty) return context.l10n.authCompleteCredentials;
                  if (!_isLoginMode && pass.length < 6) {
                    return context.l10n.authPasswordTooShort;
                  }
                  return null;
                },
              ),
```

> **Las tres reglas de validación son las de hoy, movidas de sitio.** `isEmpty` (L407 y L432), `_isValidEmail` solo en registro (L437), `length < 6` solo en registro (L442). En login no se valida el formato porque el flujo admite usuario administrador sin arroba ([auth_provider.dart](../../../lib/features/auth/presentation/providers/auth_provider.dart) — *"signIn with non-email uses admin login path"*, comprobado por un test existente). Romper eso sería cambiar el negocio; §1.5 lo prohíbe.

**4c. Un único punto de envío.** Reemplaza las dos ramas del `onPressed` por:

```dart
  Future<void> _submit() async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.isLoading) return;
    if (!(_formKey.currentState?.validate() ?? false)) {
      HapticFeedback.heavyImpact();
      return;
    }
    if (_isLoginMode) {
      await _handleEmailSignIn(authProvider);
    } else {
      await _handleEmailRegister(authProvider);
    }
  }
```

y elimina de `_handleEmailSignIn` / `_handleEmailRegister` los tres bloques de validación que ahora vive el `validator` — **conserva** intactas las llamadas a `authProvider.signIn` / `.register`, el `_persistRememberMe()`, el `context.go('/profile_setup')` y el manejo de `authProvider.error` con `UiUtils.showErrorSnackbar` (ese `SnackBar` sí es correcto: es un error del servidor, no de un campo).

**4d. El `Checkbox` a 48 × 48.**

```dart
                  Semantics(
                    label: context.l10n.authRememberMe,
                    checked: _rememberMe,
                    child: InkWell(
                      key: const ValueKey('auth-remember-me'),
                      onTap: () => setState(() => _rememberMe = !_rememberMe),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Checkbox(
                                value: _rememberMe,
                                onChanged: (value) =>
                                    setState(() => _rememberMe = value ?? false),
                                activeColor: colors.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              context.l10n.authRememberMe,
                              style: AppTextStyles.labelMedium.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
```

Altura resultante: 12 + 24 + 12 = **48** exactos. El `Semantics` externo con `checked:` sustituye al `GestureDetector` mudo de [L273-281](../../../lib/features/auth/presentation/pages/auth_screen.dart#L273-L281), que hoy hace tappable el texto sin decírselo a nadie.

**4e. El enlace de contraseña olvidada.** Borra las tres líneas que lo encogen:

```dart
                  if (_isLoginMode)
                    TextButton(
                      key: const ValueKey('auth-forgot-password'),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: _showForgotPasswordDialog,
                      child: Text(
                        context.l10n.authForgotPassword,
                        style: AppTextStyles.labelMedium.copyWith(
                          color: colors.primary,
                        ),
                      ),
                    ),
```

**4f. El separador que desborda en inglés.** El `Text` central pasa a `Flexible` y el padding se reduce en `compact`:

```dart
              Row(
                children: [
                  Expanded(
                    child: Divider(color: colors.outline.withValues(alpha: 0.5)),
                  ),
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        context.l10n.authOrContinueWith,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(color: colors.outline.withValues(alpha: 0.5)),
                  ),
                ],
              ),
```

`Flexible` + `ellipsis` hace que el texto ceda antes de desbordar; el padding baja de 16 a 8 por lado, devolviendo 16 px. Con `"OR CONTINUE WITH"` a 184 px y 208 disponibles: 184 + 16 = 200 ≤ 208. **Cabe, con 8 px para los dos `Divider`.** Márgenes así de finos son la razón del `ellipsis`: no confíes solo en la aritmética.

**4g. Los dos botones a `AppButton`.**

```dart
              AppButton(
                key: const ValueKey('auth-submit'),
                text: _isLoginMode
                    ? context.l10n.authLoginButton
                    : context.l10n.authRegisterButton,
                size: AppButtonSize.large,
                isLoading: authProvider.isLoading,
                onPressed: _submit,
                semanticLabel: _isLoginMode
                    ? context.l10n.authLoginButton
                    : context.l10n.authRegisterButton,
              ),
```

> **Fíjate en el `semanticLabel`: ya no dice *"Botón …"*.** `AppButton` marca `button: true`; repetir el rol en la etiqueta hace que el lector diga *"Botón Iniciar sesión, botón"* (§0.6.1). Y ahora la etiqueta sale del ARB, así que se traduce.

El botón de Google se trata en la Task 5, junto con la imagen remota.

- [ ] **Step 5: correr y confirmar verde**

```bash
flutter test test/features/auth/
```

Expected: los 7 nuevos en verde **y** los 21 existentes de `auth_provider_test.dart`, `auth_provider_invalid_credentials_test.dart` y `auth_screen_forgot_password_test.dart` intactos. Ese último toca el diálogo de recuperación y **no** debería verse afectado; si falla, has movido algo de más.

- [ ] **Step 6: cerrar**

```bash
dart format . && dart fix --apply && flutter analyze && flutter test
```

**Commit:** `fix(auth): formulario accesible — autofill, toggle, targets de 48 dp y el overflow de 10 px en ingles`

---

## 6. Task 5: `auth_screen` — layout por `WindowClass` y la imagen remota

**Files:**
- Modify: `lib/features/auth/presentation/pages/auth_screen.dart` (el `build()` y `_buildGoogleButton`)
- Test: `test/features/auth/auth_screen_layout_test.dart`

**Interfaces:**
- Consumes: `WindowClass`, `AppBreakpoints.of`, `WindowClassX.isAtLeastExpanded` (Fase 1 Task 1); `AppMotion.reduced` (Fase 1 Task 2); `pumpEntry`, `kAuditWidths` (Task 1).
- Produces: nada público nuevo.

**Tres cosas medidas que corregir:**

1. **`ConstrainedBox(maxWidth: 400)` en [L108-109](../../../lib/features/auth/presentation/pages/auth_screen.dart#L108-L109) y `maxWidth: Responsive.size(context, 450)` en [L186](../../../lib/features/auth/presentation/pages/auth_screen.dart#L186) se contradicen.** El interno nunca puede ganar: la tarjeta mide **272 @320, 327 @375 y 400 @1440** (medido). El `Responsive.size(context, 450)` es **código muerto** — permitiría hasta 517 px y jamás pasa de 400. Borra el interno.
2. **`AuthBottomNav` está en `Positioned(bottom: 0)` sobre el contenido**, compensado con un `Responsive.padding(context, 100)` al final del scroll ([L106](../../../lib/features/auth/presentation/pages/auth_screen.dart#L106)). Es una constante adivinada: la barra mide 20 + 20 de padding + icono 20 + 4 + `labelSmall`, y **crece con la escala tipográfica del sistema** mientras el 100 no. Con el texto al 200 % la barra tapa el enlace de registro. Además no hay `SafeArea`: en un teléfono con indicador de inicio, la barra queda debajo.
3. **El logotipo de Google se descarga de `google.com` en cada visita** (§0.6.7), y su `errorBuilder` usa `Colors.blue`.

**El contrato del maestro para `expanded`+** («split branding/formulario») se cumple aquí. Reparto:

| Clase | Layout |
|---|---|
| `compact` (<600) | columna única, tarjeta a `maxWidth: 400`, barra inferior **dentro** del flujo |
| `medium` (600–839) | igual, centrado, con más aire vertical |
| `expanded` (≥840) | **dos columnas**: izq. marca (logo + subtítulo + blobs), der. tarjeta a 400 px |
| `large` (≥1200) | igual, con el conjunto a `maxContentWidth` centrado |

- [ ] **Step 1: invocar las skills**

`Skill(ui-ux-pro-max:ui-ux-pro-max)` — §Layout: *"Split-screen auth: brand panel + form"* y la regla de que el formulario nunca debe crecer más allá de su medida legible aunque haya sitio.

`Skill(emil-design-eng)` — sobre los blobs de `AuthBackgroundBlobs`: dos `.animate().scale()` de **2 segundos** con `Curves.easeOut`, uno con 500 ms de retardo. Anota su veredicto sobre duraciones de ese orden en un elemento decorativo.

- [ ] **Step 2: escribir el test que falla**

```dart
// test/features/auth/auth_screen_layout_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/features/auth/presentation/pages/auth_screen.dart';
import 'package:autodoc/features/auth/presentation/widgets/auth_logo_section.dart';

import '../../support/entry_harness.dart';
import '../../support/responsive_harness.dart';

void main() {
  testWidgets('la tarjeta nunca supera 400 px de ancho', (tester) async {
    for (final width in kAuditWidths) {
      await pumpEntry(tester, const AuthScreen(isLogin: true), width: width);
      final card = find.byKey(const ValueKey('auth-card'));
      expect(
        tester.getSize(card).width,
        lessThanOrEqualTo(400),
        reason: 'la tarjeta crece a $width px',
      );
    }
  });

  testWidgets('en expanded hay dos columnas; en compact una', (tester) async {
    await pumpEntry(tester, const AuthScreen(isLogin: true), width: 375);
    expect(find.byKey(const ValueKey('auth-brand-panel')), findsNothing);

    await pumpEntry(
      tester,
      const AuthScreen(isLogin: true),
      width: 1024,
      height: 900,
    );
    final brand = find.byKey(const ValueKey('auth-brand-panel'));
    final card = find.byKey(const ValueKey('auth-card'));
    expect(brand, findsOneWidget);
    // El panel de marca queda a la izquierda de la tarjeta.
    expect(
      tester.getTopLeft(brand).dx,
      lessThan(tester.getTopLeft(card).dx),
    );
  });

  testWidgets('la barra inferior no se solapa con el contenido', (
    tester,
  ) async {
    await pumpEntry(tester, const AuthScreen(isLogin: true), width: 375);
    final nav = find.byKey(const ValueKey('auth-bottom-nav'));
    final card = find.byKey(const ValueKey('auth-card'));
    expect(
      tester.getBottomLeft(card).dy,
      lessThanOrEqualTo(tester.getTopLeft(nav).dy),
      reason: 'la tarjeta se mete debajo de la barra inferior',
    );
  });

  testWidgets('el logo de Google no viene de la red', (tester) async {
    final source = File(
      'lib/features/auth/presentation/pages/auth_screen.dart',
    ).readAsStringSync();
    expect(source.contains('Image.network'), isFalse);
    expect(source.contains('google.com/images'), isFalse);
  });

  testWidgets('no quedan colores literales en el fichero', (tester) async {
    final source = File(
      'lib/features/auth/presentation/pages/auth_screen.dart',
    ).readAsStringSync();
    final offenders = RegExp(
      r'Colors\.(white|black|grey|blue|red|green|orange|purple|amber)',
    ).allMatches(source).map((m) => m.group(0)).toList();
    expect(offenders, isEmpty, reason: 'quedan: $offenders');
  });

  testWidgets('AuthLogoSection sigue presente en ambas clases', (tester) async {
    for (final width in <double>[375, 1024]) {
      await pumpEntry(
        tester,
        const AuthScreen(isLogin: true),
        width: width,
        height: 900,
      );
      expect(find.byType(AuthLogoSection), findsOneWidget);
    }
  });
}
```

- [ ] **Step 3: correr y confirmar el fallo exacto**

```bash
flutter test test/features/auth/auth_screen_layout_test.dart
```

Expected, tres fallos concretos:

1. `Found 0 widgets with key [<'auth-card'>]`.
2. Tras las claves, `auth-brand-panel` seguirá siendo `findsNothing` a 1024 px — hoy no hay layout de dos columnas.
3. `Expected: <false> / Actual: <true>` para `Image.network` y para `Colors.blue`.

- [ ] **Step 4: implementar**

**4a. El `build()` reestructurado.**

```dart
  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final windowClass = AppBreakpoints.of(context);
    final isWide = windowClass.isAtLeastExpanded;

    return Scaffold(
      backgroundColor: colors.surface,
      body: Stack(
        children: [
          Positioned.fill(
            child: AuthBackgroundBlobs(colors: colors, isDark: isDark),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppBreakpoints.gutter(windowClass),
                        vertical: AppSpacing.xl,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: AppBreakpoints.maxContentWidth,
                        ),
                        child: isWide
                            ? _buildWideLayout(colors, isDark)
                            : _buildNarrowLayout(colors, isDark),
                      ),
                    ),
                  ),
                ),
                AuthBottomNav(
                  key: const ValueKey('auth-bottom-nav'),
                  colors: colors,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNarrowLayout(AppColors colors, bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AuthLogoSection(colors: colors),
        const SizedBox(height: AppSpacing.xxl),
        _card(colors, isDark),
        const SizedBox(height: AppSpacing.xxl),
        _modeSwitchLink(colors),
      ],
    );
  }

  Widget _buildWideLayout(AppColors colors, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Padding(
            key: const ValueKey('auth-brand-panel'),
            padding: const EdgeInsets.only(right: AppSpacing.xxl),
            child: AuthLogoSection(colors: colors),
          ),
        ),
        SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _card(colors, isDark),
              const SizedBox(height: AppSpacing.xxl),
              _modeSwitchLink(colors),
            ],
          ),
        ),
      ],
    );
  }

  Widget _card(AppColors colors, bool isDark) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: AnimatedSwitcher(
        duration: AppMotion.transformDuration(context, AppMotion.dropdown),
        switchInCurve: AppMotion.easeOut,
        switchOutCurve: AppMotion.easeOut,
        child: _buildGlassCard(colors, isDark, key: ValueKey(_isLoginMode)),
      ),
    );
  }
```

Y en `_buildGlassCard`, el `Container` interior pierde su `constraints:` y gana la clave:

```dart
        child: Container(
          key: const ValueKey('auth-card'),
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.xxl),
          // ← se va: constraints: BoxConstraints(maxWidth: Responsive.size(context, 450))
```

**Lo que cambia y por qué:**

- `AuthBottomNav` sale del `Stack` y entra en la `Column` como último hijo. Ya no se solapa **por construcción**, no por una constante de 100 px. Y ahora está dentro del `SafeArea`.
- El `Responsive.padding(context, 60/100)` desaparece; el espaciado vertical lo da `AppSpacing.xl` y el `Center`.
- La tarjeta tiene **un solo** tope de ancho, en `_card`.

**4b. El botón de Google, sin red.**

```dart
  Widget _buildGoogleButton(AppColors colors) {
    final authProvider = context.read<AuthProvider>();

    return AppButton(
      text: context.l10n.authGoogleLogin,
      type: AppButtonType.secondary,
      size: AppButtonSize.large,
      semanticLabel: context.l10n.authGoogleLogin,
      icon: SvgPicture.asset(
        'assets/logo/google_g.svg',
        width: 20,
        height: 20,
      ),
      onPressed: () async {
        final success = await authProvider.signInWithGoogle();
        if (success && mounted) {
          HapticFeedback.lightImpact();
          await _navigateAfterAuth(authProvider);
        } else if (mounted && authProvider.error != null) {
          HapticFeedback.heavyImpact();
          UiUtils.showErrorSnackbar(context, authProvider.error!);
        }
      },
    );
  }
```

> **`assets/logo/google_g.svg` no existe todavía.** Ver §19.5. Si no puedes añadir el asset en esta tarea, la alternativa que **no** requiere ningún fichero nuevo y sí elimina la petición de red es:
>
> ```dart
>       icon: Icon(Icons.g_mobiledata, size: 24, color: colors.textPrimary),
> ```
>
> Es peor de marca y mejor en todo lo demás. Elige una, no dejes el `Image.network`.

- [ ] **Step 5: correr y confirmar verde**

```bash
flutter test test/features/auth/
```

- [ ] **Step 6: verificación manual de anchos**

```bash
flutter run -d chrome
```

Redimensiona por 320 → 375 → 600 → 840 → 1200 → 1440 en `es` y en `en`, en claro y en oscuro. Comprueba a ojo que la transición a dos columnas a 840 no deja el panel de marca vacío ni la tarjeta pegada al borde.

- [ ] **Step 7: cerrar**

```bash
dart format . && dart fix --apply && flutter analyze && flutter test
```

**Commit:** `feat(auth): layout por WindowClass, barra inferior en flujo y logo de Google sin peticion remota`

---

## 7. Task 6: los tres widgets de `auth` — targets, sombra y *reduced motion*

**Files:**
- Modify: `lib/features/auth/presentation/widgets/auth_bottom_nav.dart`
- Modify: `lib/features/auth/presentation/widgets/auth_background_blobs.dart`
- Modify: `lib/features/auth/presentation/widgets/auth_logo_section.dart`
- Test: `test/features/auth/auth_widgets_test.dart`

**Interfaces:**
- Consumes: `AppShadows` (Fase 1 Task 3); `AppMotion.reduced`, `AppMotion.transformDuration`, `AppMotion.easeOut` (Fase 1 Task 2); `WindowClass` (Fase 1 Task 1); `pumpEntry` (Task 1).
- Produces: nada público nuevo. `AuthBottomNav` gana un parámetro opcional `VoidCallback? onHelp` — ver 4a.

**Los cuatro defectos:**

1. `AuthBottomNav`: tres acciones con `Icon(20)` + `labelSmall` **sin padding** → muy por debajo de 48 dp, y las tres muestran un `SnackBar` de relleno (§0.6.2).
2. `AuthBottomNav`: `Colors.black.withValues(alpha: 0.02)` en su sombra ([L22](../../../lib/features/auth/presentation/widgets/auth_bottom_nav.dart#L22)) — literal fuera de `app_shadows.dart`, contra §2 del maestro.
3. `AuthBackgroundBlobs`: dos `.animate().scale()` de **2 segundos** con `Duration` literal, `Curves.easeOut` literal, y **sin consultar *reduced motion***. Dos círculos de 300 y 400 px creciendo desde cero durante dos segundos es exactamente el tipo de movimiento que la preferencia del sistema pide eliminar.
4. `AuthLogoSection`: `fadeIn(800.ms)` + `slideY` igualmente sin *reduced motion*.

- [ ] **Step 1: invocar las skills**

`Skill(emil-design-eng)` — la regla de *reduced motion*: **no** es «cero animación», es «se conserva opacidad y color, se elimina el desplazamiento y la escala». Anota qué duración considera aceptable para un elemento decorativo de fondo.

`Skill(review-animations)` sobre el diff de esta tarea, como manda §1 del maestro para toda tarea que toque motion.

- [ ] **Step 2: escribir el test que falla**

```dart
// test/features/auth/auth_widgets_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/features/auth/presentation/widgets/auth_bottom_nav.dart';
import 'package:autodoc/features/auth/presentation/widgets/auth_logo_section.dart';

import '../../support/entry_harness.dart';

void main() {
  testWidgets('las tres acciones de la barra miden 48 dp de alto', (
    tester,
  ) async {
    late AppColors colors;
    await pumpEntry(
      tester,
      Builder(
        builder: (context) {
          colors = context.appColors;
          return Scaffold(
            body: AuthBottomNav(colors: colors, isDark: false),
          );
        },
      ),
      width: 320,
    );

    for (final key in const <String>[
      'auth-nav-help',
      'auth-nav-privacy',
      'auth-nav-terms',
    ]) {
      final finder = find.byKey(ValueKey(key));
      expect(finder, findsOneWidget, reason: 'falta $key');
      final size = tester.getSize(finder);
      expect(size.height, greaterThanOrEqualTo(48), reason: '$key es bajo');
      expect(size.width, greaterThanOrEqualTo(48), reason: '$key es estrecho');
    }
  });

  testWidgets('la barra no desborda a 320 px en ingles', (tester) async {
    late AppColors colors;
    final errors = await pumpEntryCollecting(
      tester,
      Builder(
        builder: (context) {
          colors = context.appColors;
          return Scaffold(body: AuthBottomNav(colors: colors, isDark: false));
        },
      ),
      width: 320,
      locale: const Locale('en'),
    );
    expect(errors, isEmpty);
  });

  testWidgets('con reduced motion los blobs no escalan', (tester) async {
    await pumpEntry(
      tester,
      const Scaffold(body: SizedBox.expand()),
      disableAnimations: true,
    );
    // Se verifica por codigo fuente: ningun ScaleEffect sin guarda.
    final source = File(
      'lib/features/auth/presentation/widgets/auth_background_blobs.dart',
    ).readAsStringSync();
    expect(
      source.contains('AppMotion.reduced'),
      isTrue,
      reason: 'los blobs no consultan reduced motion',
    );
    expect(
      RegExp(r'Duration\(seconds:\s*\d').hasMatch(source),
      isFalse,
      reason: 'quedan duraciones literales',
    );
  });

  testWidgets('AuthLogoSection respeta reduced motion', (tester) async {
    final source = File(
      'lib/features/auth/presentation/widgets/auth_logo_section.dart',
    ).readAsStringSync();
    expect(source.contains('AppMotion.reduced'), isTrue);
  });

  testWidgets('la sombra de la barra no usa Colors.black', (tester) async {
    final source = File(
      'lib/features/auth/presentation/widgets/auth_bottom_nav.dart',
    ).readAsStringSync();
    expect(source.contains('Colors.black'), isFalse);
  });
}
```

- [ ] **Step 3: correr y confirmar el fallo exacto**

```bash
flutter test test/features/auth/auth_widgets_test.dart
```

Expected, cuatro fallos concretos:

1. `falta auth-nav-help` — `Found 0 widgets with key`.
2. Tras las claves, la altura medida será ≈ **41** (20 de icono + 4 + ~17 de `labelSmall`), contra `greaterThanOrEqualTo(48)`.
3. `los blobs no consultan reduced motion`: `Expected: <true> / Actual: <false>`.
4. `Expected: <false> / Actual: <true>` para `Colors.black`.

- [ ] **Step 4: implementar**

**4a. `auth_bottom_nav.dart` completo.**

```dart
import 'package:flutter/material.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_shadows.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';

/// Barra de enlaces legales de la pantalla de acceso.
///
/// Las tres acciones abren enlaces reales; antes mostraban un `SnackBar`
/// de relleno («Abriendo sección de …») que no llevaba a ninguna parte.
class AuthBottomNav extends StatelessWidget {
  final AppColors colors;
  final bool isDark;

  /// Inyectable para tests; por defecto abre el navegador.
  final Future<void> Function(String url)? onOpenUrl;

  const AuthBottomNav({
    super.key,
    required this.colors,
    required this.isDark,
    this.onOpenUrl,
  });

  static const String _privacyUrl = 'https://autodoc.app/privacidad';
  static const String _termsUrl = 'https://autodoc.app/terminos';
  static const String _supportUrl = 'mailto:soporte@autodoc.app';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.outline.withValues(alpha: 0.2)),
        ),
        boxShadow: isDark ? AppShadows.darkSm : AppShadows.lightSm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _action(
            context,
            key: const ValueKey('auth-nav-help'),
            icon: Icons.help_outline,
            label: 'Ayuda',
            url: _supportUrl,
          ),
          _action(
            context,
            key: const ValueKey('auth-nav-privacy'),
            icon: Icons.shield_outlined,
            label: 'Privacidad',
            url: _privacyUrl,
          ),
          _action(
            context,
            key: const ValueKey('auth-nav-terms'),
            icon: Icons.gavel_outlined,
            label: 'Términos',
            url: _termsUrl,
          ),
        ],
      ),
    );
  }

  Widget _action(
    BuildContext context, {
    required Key key,
    required IconData icon,
    required String label,
    required String url,
  }) {
    return Flexible(
      child: Semantics(
        link: true,
        label: label,
        child: InkWell(
          key: key,
          onTap: () => (onOpenUrl ?? UiUtils.openExternalUrl)(url),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.sm,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 20, color: colors.textSecondary),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

Altura resultante: 8 + 20 + 4 + ~17 + 8 = **57**, con el `minHeight: 48` como suelo. `Flexible` + `ellipsis` responde al test de desbordamiento a 320 px en inglés (*Privacy*, *Terms*, *Help* son más cortos que sus equivalentes en español, pero el widget debe aguantar cualquier idioma).

> **`UiUtils.openExternalUrl` no existe.** Verificado: [ui_utils.dart](../../../lib/core/utils/ui_utils.dart) solo expone `showErrorSnackbar`, `showSuccessSnackbar` y `showInfoSnackbar`. Tienes dos opciones: añadirlo ahí (es un `core/utils`, no un provider, así que §1.3 no lo impide) o llamar a `url_launcher` directamente en este widget —ya es dependencia, la usa `about_screen`— con la misma guarda de fallo que introdujo la Task 2. Recomendado: añadirlo a `UiUtils`, porque la Task 2 lo necesita también y así hay un solo sitio donde tratar el fallo de apertura. **No** dejes el `SnackBar` de relleno.

**4b. `auth_background_blobs.dart`.**

```dart
  @override
  Widget build(BuildContext context) {
    final reduced = AppMotion.reduced(context);
    final windowClass = AppBreakpoints.of(context);

    // Los blobs son decorativos: en `compact` ocupan casi la pantalla y no
    // aportan nada, asi que se encogen con la clase de ventana en vez de
    // escalarse con `Responsive.size`.
    final smallDiameter = windowClass.isAtLeastExpanded ? 360.0 : 240.0;
    final largeDiameter = windowClass.isAtLeastExpanded ? 480.0 : 320.0;

    return ExcludeSemantics(
      child: Stack(
        children: [
          Positioned(
            top: -100,
            left: -50,
            child: _blob(
              diameter: smallDiameter,
              color: colors.primary.withValues(alpha: isDark ? 0.1 : 0.05),
              reduced: reduced,
              delay: Duration.zero,
            ),
          ),
          Positioned(
            bottom: -50,
            right: -100,
            child: _blob(
              diameter: largeDiameter,
              color: colors.secondary.withValues(alpha: isDark ? 0.1 : 0.05),
              reduced: reduced,
              delay: AppMotion.staggerStep,
            ),
          ),
        ],
      ),
    );
  }

  Widget _blob({
    required double diameter,
    required Color color,
    required bool reduced,
    required Duration delay,
  }) {
    final circle = Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );

    // Reduced motion: se conserva la aparicion por opacidad, se elimina la
    // escala. No es «sin animacion», es «sin desplazamiento».
    if (reduced) {
      return circle.animate().fadeIn(duration: AppMotion.sheetEnter);
    }
    return circle
        .animate()
        .fadeIn(delay: delay, duration: AppMotion.sheetEnter)
        .scale(
          delay: delay,
          duration: AppMotion.sheetEnter,
          curve: AppMotion.easeOut,
        );
  }
```

Tres cambios de fondo: `ExcludeSemantics` (son decoración pura y hoy un lector de pantalla los recorre), diámetros por `WindowClass` en vez de `Responsive.size`, y la duración baja de **2 s** a un token.

**4c. `auth_logo_section.dart`:** misma guarda.

```dart
    final content = Column(children: [ /* … igual … */ ]);
    if (AppMotion.reduced(context)) {
      return content.animate().fadeIn(duration: AppMotion.sheetEnter);
    }
    return content
        .animate()
        .fadeIn(duration: AppMotion.sheetEnter)
        .slideY(begin: -0.2, end: 0, curve: AppMotion.easeOut);
```

y el `SvgPicture.asset` gana `semanticsLabel: 'AutoDoc'`.

- [ ] **Step 5: correr y confirmar verde**

```bash
flutter test test/features/auth/
```

- [ ] **Step 6: cerrar**

```bash
dart format . && dart fix --apply && flutter analyze && flutter test
```

**Commit:** `fix(auth-widgets): targets de 48 dp, enlaces reales, sombra tokenizada y reduced motion en los blobs`

---

## 8. Task 7: `login_screen` — resolver la infracción de estructura y el test que no prueba nada

**Files:**
- Delete: `lib/features/auth/presentation/screens/login_screen.dart`
- Modify: `lib/core/router/app_router.dart:9,334-340`
- Rewrite: `test/features/auth/login_screen_test.dart`

**Interfaces:**
- Consumes: `AuthScreen`; `pumpEntry` (Task 1).
- Produces: nada. **Elimina** el símbolo público `LoginScreen`.

**La decisión, y por qué esta y no otra.** El maestro §5.4 dice: *"Mover a `pages/` o documentar por qué no"*. Leído el fichero, la tercera opción es la correcta: **borrarlo**.

`LoginScreen` son 15 líneas que devuelven `const AuthScreen(isLogin: true)`. No añade estado, ni layout, ni comportamiento. Su único consumidor es [app_router.dart:334-340](../../../lib/core/router/app_router.dart#L334-L340), y la ruta hermana `/register` ya monta `const AuthScreen(isLogin: false)` **directamente**, sin envoltorio. Mover el fichero a `pages/` conservaría una indirección que no hace nada y una asimetría entre dos rutas gemelas.

Y su comentario de documentación es **falso** (§0.5.3): afirma envolver el layout en `SingleChildScrollView` y `ConstrainedBox`, que están en `AuthScreen`. Mover el fichero propagaría la mentira.

> **Si prefieres conservar el símbolo** —por ejemplo porque algo externo al repositorio lo referencia— la alternativa aceptable es moverlo a `pages/login_screen.dart` y **borrar el comentario falso**. Lo que no es aceptable es dejarlo donde está con la documentación que tiene. Decide y anótalo en el commit.

- [ ] **Step 1: comprobar que no hay otros consumidores**

```bash
grep -rn "LoginScreen\|screens/login_screen" lib/ test/ --include=*.dart
```

Expected: exactamente tres apariciones — la definición, el import del router y el test. Si aparece alguna más, **para** y reevalúa.

- [ ] **Step 2: escribir el test que falla**

El test actual no puede fallar (§0.6.5). Se sustituye por uno que sí:

```dart
// test/features/auth/login_screen_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/features/auth/presentation/pages/auth_screen.dart';

import '../../support/entry_harness.dart';

void main() {
  test('no queda ninguna pantalla fuera de pages/', () {
    final offenders = Directory('lib/features')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('_screen.dart'))
        .where((f) => f.path.replaceAll(r'\', '/').contains('/screens/'))
        .map((f) => f.path)
        .toList();
    expect(
      offenders,
      isEmpty,
      reason: 'CONVENTIONS.md §1: las pantallas viven en presentation/pages/',
    );
  });

  testWidgets('la ruta de acceso renderiza AuthScreen en modo login', (
    tester,
  ) async {
    await pumpEntry(tester, const AuthScreen(isLogin: true), width: 375);
    final screen = tester.widget<AuthScreen>(find.byType(AuthScreen));
    expect(screen.isLogin, isTrue);
  });

  testWidgets(
    'en horizontal de telefono el acceso hace scroll y no desborda',
    (tester) async {
      // Este es el contrato que el comentario de LoginScreen prometia
      // y que ningun test comprobaba: 800x400 es un telefono girado.
      final errors = await pumpEntryCollecting(
        tester,
        const AuthScreen(isLogin: true),
        width: 800,
        height: 400,
      );
      expect(errors, isEmpty);
      expect(find.byType(SingleChildScrollView), findsAtLeastNWidgets(1));
    },
  );
}
```

> **El tercer test es el que importa.** Toma la afirmación del comentario borrado —*"prevent visual overflow in landscape mode"*— y la convierte por primera vez en algo comprobable, a un tamaño concreto, contra la pantalla que de verdad hace el trabajo.

- [ ] **Step 3: correr y confirmar el fallo exacto**

```bash
flutter test test/features/auth/login_screen_test.dart
```

Expected: el primer test falla con
`CONVENTIONS.md §1: las pantallas viven en presentation/pages/`
y la lista conteniendo `lib/features/auth/presentation/screens/login_screen.dart`.

- [ ] **Step 4: implementar**

```bash
git rm lib/features/auth/presentation/screens/login_screen.dart
rmdir lib/features/auth/presentation/screens
```

En `app_router.dart`, sustituye el import de la línea 9 y la ruta:

```dart
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => buildPageWithFadeThrough(
          context: context,
          state: state,
          child: const AuthScreen(isLogin: true),
        ),
      ),
```

Ahora `/login` y `/register` son simétricas: la misma pantalla con distinto `isLogin`.

- [ ] **Step 5: correr y confirmar verde**

```bash
flutter test test/features/auth/
flutter analyze
```

`flutter analyze` es aquí tan importante como el test: es lo que detecta cualquier import huérfano que el `grep` del Step 1 hubiera pasado por alto.

- [ ] **Step 6: cerrar**

```bash
dart format . && dart fix --apply && flutter analyze && flutter test
```

**Commit:** `refactor(auth): eliminar LoginScreen (alias de 15 lineas) y cubrir el contrato de horizontal con un test real`

---

## 9. Task 8: `onboarding_screen` — la aserción de horizontal, el desbordamiento y las fugas

**Files:**
- Modify: `lib/features/onboarding/presentation/pages/onboarding_screen.dart`
- Test: `test/features/onboarding/presentation/pages/onboarding_screen_test.dart`

**Interfaces:**
- Consumes: `WindowClass`, `AppBreakpoints.of`, `AppBreakpoints.maxReadingWidth` (Fase 1 Task 1); `AppMotion.reduced`, `AppMotion.easeOut`, `AppMotion.dropdown` (Fase 1 Task 2); `AppButton` (Fase 3 Task 1); `pumpEntry`, `pumpEntryCollecting`, `kEntryLocales` (Task 1).
- Produces: nada público nuevo.

**Esta es la primera pantalla que ve un usuario nuevo, y hoy:**

1. **Lanza `BoxConstraints has non-normalized height constraints` si el teléfono está en horizontal** (§0.1, verificado a 800 × 400). Cualquier alto de viewport < 500 px.
2. **Desborda 24 px** en la barra superior a 320 px (§0.1, `debugCreator` → [L67](../../../lib/features/onboarding/presentation/pages/onboarding_screen.dart#L67)).
3. **El `PageController` nunca se libera** — no hay `dispose()` en el `State` (§0.6.6).
4. **El botón de retroceso sigue siendo pulsable y anunciable cuando es invisible**: en la página 0 se pinta con `color: Colors.transparent` ([L79-84](../../../lib/features/onboarding/presentation/pages/onboarding_screen.dart#L79-L84)) pero su `onPressed` sigue conectado y un lector de pantalla lo lee.
5. **El botón principal es un `GestureDetector` sobre un `AnimatedContainer`** ([L341](../../../lib/features/onboarding/presentation/pages/onboarding_screen.dart#L341)): sin ripple, sin feedback de press, sin rol semántico de botón.
6. **Los puntos de paginación no dicen nada**: tres `AnimatedContainer` de 8 px sin `Semantics`. Un usuario ciego no sabe en qué paso de cuántos está.

- [ ] **Step 1: invocar las skills**

`Skill(apple-design)` — el `PageView` es el gesto principal de esta pantalla. Anota qué dice sobre paginación interrumpible y sobre el *rubber banding* en los extremos.

`Skill(emil-design-eng)` — sobre las cuatro `.animate(target: _currentPage == index ? 1 : 0)` con duraciones 500/600/700/800 ms escalonadas. Anota si el escalonado tiene propósito o es decoración.

- [ ] **Step 2: escribir el test que falla**

```dart
// test/features/onboarding/presentation/pages/onboarding_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/features/onboarding/presentation/pages/onboarding_screen.dart';

import '../../../../support/entry_harness.dart';
import '../../../../support/responsive_harness.dart';

void main() {
  testWidgets('en horizontal de telefono NO lanza aserciones', (tester) async {
    // 800x400 es un telefono girado. Hoy esto produce
    // "BoxConstraints has non-normalized height constraints".
    final errors = await pumpEntryCollecting(
      tester,
      const OnboardingScreen(),
      width: 800,
      height: 400,
    );
    expect(
      errors,
      isEmpty,
      reason: '${errors.map((e) => e.exception).toList()}',
    );
  });

  testWidgets('no desborda en ningun ancho auditado ni en ningun idioma', (
    tester,
  ) async {
    for (final locale in kEntryLocales) {
      for (final width in kAuditWidths) {
        final errors = await pumpEntryCollecting(
          tester,
          const OnboardingScreen(),
          width: width,
          locale: locale,
        );
        expect(
          errors,
          isEmpty,
          reason: 'desborda a $width px en ${locale.languageCode}',
        );
      }
    }
  });

  testWidgets('el boton de retroceso no existe en la primera pagina', (
    tester,
  ) async {
    await pumpEntry(tester, const OnboardingScreen(), width: 375);
    expect(find.byKey(const ValueKey('onboarding-back')), findsNothing);
  });

  testWidgets('los puntos anuncian el paso actual', (tester) async {
    // `tester.getSemantics` lanza «Semantics are not enabled» si nadie ha
    // pedido el arbol semantico: hay que abrir el handle ANTES del pump.
    // Y hay que cerrarlo con `dispose()` AL FINAL DEL CUERPO: `addTearDown`
    // NO sirve aqui (ver la nota debajo del bloque).
    final handle = tester.ensureSemantics();

    await pumpEntry(tester, const OnboardingScreen(), width: 375);
    final dots = find.byKey(const ValueKey('onboarding-dots'));
    expect(dots, findsOneWidget);
    final semantics = tester.getSemantics(dots);
    expect(semantics.label, contains('1'));
    expect(semantics.label, contains('3'));

    handle.dispose();
  });

  testWidgets('el boton principal es un boton de verdad', (tester) async {
    final handle = tester.ensureSemantics();

    await pumpEntry(tester, const OnboardingScreen(), width: 375);
    final button = find.byKey(const ValueKey('onboarding-next'));
    expect(button, findsOneWidget);
    expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
    expect(
      tester.getSemantics(button),
      matchesSemantics(
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        label: 'Siguiente',
        hasTapAction: true,
      ),
    );

    handle.dispose();
  });

  testWidgets('el PageController se libera', (tester) async {
    await pumpEntry(tester, const OnboardingScreen(), width: 375);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    // Si el controller no se libera, Flutter registra el objeto como
    // no dispuesto y el binding lo denuncia en el teardown.
    expect(tester.takeException(), isNull);
  });
}
```

> **Dos trampas de la API de semántica, ambas verificadas en esta sesión:**
>
> 1. **`addTearDown(handle.dispose)` no funciona.** Es el idioma habitual para todo lo demás, pero aquí falla: `WidgetTester._verifySemanticsHandlesWereDisposed` corre **antes** que los *tear-downs*, así que el test muere con `A SemanticsHandle was active at the end of the test`. Hay que llamar a `handle.dispose()` explícitamente como última línea del cuerpo. Comprobado con las dos variantes: `addTearDown` falla, `dispose()` al final pasa.
> 2. **`matchesSemantics` es exigente** y puede requerir ajustar los flags exactos que `AppButton` emite. Ejecuta primero y copia los flags reales del mensaje de fallo; no adivines. Lo que **no** debes relajar es `isButton: true`.
>
> `SemanticsFlag.isSelected` y `node.hasFlag(...)` **sí** siguen vigentes en Flutter 3.41.6 (comprobado): la Task 11 puede usarlos tal cual.

- [ ] **Step 3: correr y confirmar el fallo exacto**

```bash
flutter test test/features/onboarding/
```

Expected, en este orden:

1. `[BoxConstraints has non-normalized height constraints.]` — el fallo de §0.1, ahora capturado por un test.
2. `desborda a 320.0 px en es` con el `RenderFlex` de 24 px.
3. `Found 0 widgets with key [<'onboarding-dots'>]`.
4. `Found 0 widgets with key [<'onboarding-next'>]`.

- [ ] **Step 4: implementar**

**4a. La aserción de horizontal.** El bloque de [L133-138](../../../lib/features/onboarding/presentation/pages/onboarding_screen.dart#L133-L138) se sustituye por una restricción que **no puede desnormalizarse**:

```dart
    // El alto de la ilustracion es una fraccion del viewport, pero acotada
    // por arriba y por abajo de forma que `min` nunca supere a `max`.
    // La version anterior calculaba `maxHeight: height * 0.4` con
    // `minHeight: 200` fijo, que se desnormaliza con cualquier alto < 500 px
    // — es decir, en todo telefono girado.
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final illustrationHeight = (viewportHeight * 0.4).clamp(120.0, 360.0);
```

```dart
                            SizedBox(
                              height: illustrationHeight,
                              child: Stack( /* … */ ),
                            ),
```

`clamp(120, 360)` sobre un valor siempre positivo no puede producir restricciones inválidas, y a 400 px de alto da 160 px de ilustración — pequeña pero visible, que es lo correcto en horizontal.

> **`MediaQuery.sizeOf` en vez de `MediaQuery.of(context).size`**: el maestro §2 prohíbe `MediaQuery` cruda **para decisiones de layout** (elegir estructura). Esto no elige estructura: dimensiona una ilustración proporcionalmente al alto disponible, para lo que `WindowClass` —que solo conoce anchos— no sirve. Anótalo en el commit para que no se lea como una infracción.

**4b. La barra superior que desborda 24 px.** El `Row` de [L67](../../../lib/features/onboarding/presentation/pages/onboarding_screen.dart#L67):

```dart
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Antes: un IconButton siempre presente, pintado
                    // transparente en la pagina 0 — invisible pero
                    // pulsable y anunciado por el lector de pantalla.
                    if (_currentPage > 0)
                      IconButton(
                        key: const ValueKey('onboarding-back'),
                        tooltip: 'Anterior',
                        onPressed: _previous,
                        icon: const Icon(Icons.arrow_back),
                      )
                    else
                      const SizedBox(width: 48),
                    Flexible(
                      child: Text(
                        'AutoDoc',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.titleLarge.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _skip,
                      child: Text(
                        'Saltar',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: colors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
```

`Flexible` + `ellipsis` en el título es lo que absorbe los 24 px; el `SizedBox(width: 48)` conserva el equilibrio visual sin dejar un control fantasma.

**4c. `dispose` y los dos manejadores extraídos.**

```dart
  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _previous() => _pageController.previousPage(
    duration: AppMotion.transformDuration(context, AppMotion.dropdown),
    curve: AppMotion.easeInOut,
  );

  Future<void> _skip() async {
    await AuthPreferencesService().setOnboardingCompleted(true);
    if (mounted) context.go('/login');
  }

  Future<void> _next() async {
    if (_currentPage < _contents.length - 1) {
      await _pageController.nextPage(
        duration: AppMotion.transformDuration(context, AppMotion.dropdown),
        curve: AppMotion.easeInOut,
      );
      return;
    }
    await _skip();
  }
```

> **`_next()` en la última página llama a `_skip()`** — el mismo destino y la misma persistencia que ya hacía el código en línea de [L348-356](../../../lib/features/onboarding/presentation/pages/onboarding_screen.dart#L348-L356). Es exactamente el mismo comportamiento, con un solo sitio donde vive.

**4d. Los puntos, con semántica.**

```dart
              Semantics(
                key: const ValueKey('onboarding-dots'),
                label: 'Paso ${_currentPage + 1} de ${_contents.length}',
                child: ExcludeSemantics(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _contents.length,
                        (index) => AnimatedContainer(
                          duration: AppMotion.transformDuration(
                            context,
                            AppMotion.dropdown,
                          ),
                          curve: AppMotion.easeOut,
                          margin: const EdgeInsets.only(right: AppSpacing.md),
                          height: 8,
                          width: _currentPage == index ? 32 : 8,
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? colors.primary
                                : colors.outline.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(AppRadius.xs),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
```

El `ExcludeSemantics` interno evita que el lector recorra tres nodos vacíos; el `Semantics` externo dice lo único que importa.

**4e. El botón principal.**

```dart
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  0,
                  AppSpacing.xl,
                  AppSpacing.xxl,
                ),
                child: AppButton(
                  key: const ValueKey('onboarding-next'),
                  text: _currentPage == _contents.length - 1
                      ? 'Comenzar ahora'
                      : 'Siguiente',
                  size: AppButtonSize.large,
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _next,
                ),
              ),
```

`AppButton` aporta el press feedback, el rol de botón, el mínimo de 48 dp y el `hapticFeedback` — cuatro cosas que el `GestureDetector` no tenía.

- [ ] **Step 5: correr y confirmar verde**

```bash
flutter test test/features/onboarding/
```

- [ ] **Step 6: cerrar**

```bash
dart format . && dart fix --apply && flutter analyze && flutter test
```

**Commit:** `fix(onboarding): aserción en horizontal, overflow de 24 px, dispose del PageController y semantica de paginacion`

---

## 10. Task 9: `onboarding_screen` — la ilustración: ancho fijo, imagen remota y presupuesto de desenfoque

**Files:**
- Modify: `lib/features/onboarding/presentation/pages/onboarding_screen.dart` (el panel de cristal y `_contents`)
- Test: `test/features/onboarding/presentation/pages/onboarding_illustration_test.dart`

**Interfaces:**
- Consumes: `WindowClass`, `AppBreakpoints.maxReadingWidth` (Fase 1 Task 1); `AppMotion.reduced` (Fase 1 Task 2); `pumpEntry`, `kAuditWidths` (Task 1).
- Produces: nada público nuevo.

**Los tres problemas, medidos:**

1. **`Container(width: 280, height: constraints.maxHeight)`** dentro del `LayoutBuilder` ([L191-193](../../../lib/features/onboarding/presentation/pages/onboarding_screen.dart#L191-L193)). Medido: **280 px a 1440 px de ventana** y recortado a **272 a 320 px**. Nunca crece ni encoge por decisión propia; a 1440 la ilustración ocupa el 19 % del ancho mientras el título y la descripción se estiran a 1392 px. Es el `LayoutBuilder` más inútil del repositorio: recibe `constraints` y solo usa `maxHeight`.
2. **Las tres diapositivas usan la misma URL de `lh3.googleusercontent.com`**, con el comentario `// Reusing placeholder as requested` en la segunda (§0.6.3). Sin `errorWidget`: si la URL cae, el panel queda **vacío para siempre y en silencio**.
3. **Tres capas de desenfoque simultáneas por página**: `ImageFiltered(sigma 30)`, `ImageFiltered(sigma 40)` y `BackdropFilter(sigma 12)`. Multiplicado por las páginas que `PageView` mantiene vivas. Es la pantalla más cara de la app y la que corre primero, en el arranque en frío, en el dispositivo menos caliente.

- [ ] **Step 1: invocar las skills**

`Skill(ui-ux-pro-max:ui-ux-pro-max)` — su ficha marca *Glassmorphism* con `Performance: ⚠ Good`. El maestro §1.1 lo adopta **solo donde ya existe de facto**. Aquí ya existe, así que se conserva; lo que se corrige es la cantidad.

- [ ] **Step 2: escribir el test que falla**

```dart
// test/features/onboarding/presentation/pages/onboarding_illustration_test.dart
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/features/onboarding/presentation/pages/onboarding_screen.dart';

import '../../../../support/entry_harness.dart';

void main() {
  testWidgets('el panel crece con la ventana y respeta el ancho de lectura', (
    tester,
  ) async {
    await pumpEntry(tester, const OnboardingScreen(), width: 375, height: 812);
    final narrow = tester.getSize(
      find.byKey(const ValueKey('onboarding-panel')),
    );

    await pumpEntry(tester, const OnboardingScreen(), width: 1440, height: 900);
    final wide = tester.getSize(find.byKey(const ValueKey('onboarding-panel')));

    expect(
      wide.width,
      greaterThan(narrow.width),
      reason: 'el panel sigue clavado en 280 px',
    );
    expect(
      wide.width,
      lessThanOrEqualTo(AppBreakpoints.maxReadingWidth),
      reason: 'el panel se desborda del ancho de lectura',
    );
  });

  testWidgets('la ilustracion tiene estado de error visible', (tester) async {
    // En test las peticiones de red fallan por defecto, asi que este
    // pump ejercita exactamente la rama de error.
    await pumpEntry(tester, const OnboardingScreen(), width: 375);
    expect(
      find.byKey(const ValueKey('onboarding-illustration-fallback')),
      findsOneWidget,
      reason: 'sin errorWidget el panel se queda vacio y mudo',
    );
  });

  testWidgets('las tres diapositivas no comparten la misma ilustracion', (
    tester,
  ) async {
    final source = File(
      'lib/features/onboarding/presentation/pages/onboarding_screen.dart',
    ).readAsStringSync();
    expect(
      source.contains('lh3.googleusercontent.com'),
      isFalse,
      reason: 'sigue el marcador de posicion del CDN de Google',
    );
    expect(
      source.contains('Reusing placeholder as requested'),
      isFalse,
    );
  });

  testWidgets('como mucho una capa de desenfoque por pagina visible', (
    tester,
  ) async {
    await pumpEntry(tester, const OnboardingScreen(), width: 375);
    // BackdropFilter del panel: 1. ImageFiltered de los blobs: 0.
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.byType(ImageFiltered), findsNothing);
  });
}
```

- [ ] **Step 3: correr y confirmar el fallo exacto**

```bash
flutter test test/features/onboarding/presentation/pages/onboarding_illustration_test.dart
```

Expected, cuatro fallos concretos:

1. `Found 0 widgets with key [<'onboarding-panel'>]`; tras añadir la clave, `wide.width` será **280,0** y `narrow.width` **280,0** → `greaterThan` falla con dos valores idénticos.
2. `sin errorWidget el panel se queda vacio y mudo`.
3. `sigue el marcador de posicion del CDN de Google`.
4. `find.byType(ImageFiltered)` encontrará **dos**, no cero.

- [ ] **Step 4: implementar**

**4a. El panel deja de ser de 280 px.** Sustituye el `LayoutBuilder` entero:

```dart
                                  // El panel ocupa el ancho disponible con
                                  // un tope de lectura. Antes era
                                  // `width: 280` literal: 19 % del ancho a
                                  // 1440 px y recortado a 320 px.
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: AppBreakpoints.maxReadingWidth,
                                    ),
                                    child: ClipRRect(
                                      key: const ValueKey('onboarding-panel'),
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.xxl,
                                      ),
                                      child: BackdropFilter(
                                        filter: ImageFilter.blur(
                                          sigmaX: 12,
                                          sigmaY: 12,
                                        ),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: colors.surfaceContainer
                                                .withValues(
                                                  alpha: isDark ? 0.6 : 0.8,
                                                ),
                                            borderRadius:
                                                BorderRadius.circular(
                                                  AppRadius.xxl,
                                                ),
                                            border: Border.all(
                                              color: colors.outline.withValues(
                                                alpha: 0.3,
                                              ),
                                              width: 1.5,
                                            ),
                                          ),
                                          padding: const EdgeInsets.all(
                                            AppSpacing.xl,
                                          ),
                                          child: Column(
                                            children: [
                                              Expanded(
                                                child: _illustration(
                                                  content,
                                                  colors,
                                                ),
                                              ),
                                              const SizedBox(
                                                height: AppSpacing.base,
                                              ),
                                              Row( /* features, igual */ ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
```

**4b. La ilustración con estado de error.**

```dart
  Widget _illustration(OnboardingContent content, AppColors colors) {
    final fallback = Container(
      key: const ValueKey('onboarding-illustration-fallback'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primary.withValues(alpha: 0.18),
            colors.secondary.withValues(alpha: 0.18),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Center(
        child: Icon(
          content.icon,
          size: 64,
          color: colors.primary,
          semanticLabel: content.title,
        ),
      ),
    );

    if (content.assetPath == null) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Image.asset(
        content.assetPath!,
        fit: BoxFit.cover,
        semanticLabel: content.title,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
```

y `OnboardingContent` cambia de `imageUrl` a:

```dart
class OnboardingContent {
  final String title;
  final String description;

  /// Ilustracion local. `null` mientras no existan los assets: en ese caso
  /// se dibuja el degradado con el icono, que es del design system y
  /// funciona sin red. Ver Fase 7 §19.1.
  final String? assetPath;

  /// Icono de respaldo, que **siempre** existe.
  final IconData icon;

  final List<String> features;

  const OnboardingContent({
    required this.title,
    required this.description,
    required this.icon,
    required this.features,
    this.assetPath,
  });
}
```

y las tres entradas de `_contents` pierden la URL y ganan un icono distinto cada una:

```dart
  static const List<OnboardingContent> _contents = <OnboardingContent>[
    OnboardingContent(
      title: 'Diagnóstico en tiempo real',
      description:
          'Mantén tu auto en perfecto estado con monitoreo constante de '
          'todos los sistemas críticos.',
      icon: Icons.monitor_heart_outlined,
      features: ['Motor OK', 'Frenos Seguros'],
    ),
    OnboardingContent(
      title: 'Recordatorios Inteligentes',
      description:
          'Nunca más olvides un cambio de aceite o mantenimiento '
          'preventivo. Nosotros te avisamos.',
      icon: Icons.notifications_active_outlined,
      features: ['Aceite 80%', 'Llantas OK'],
    ),
    OnboardingContent(
      title: 'Tu auto te lo agradecerá',
      description:
          'Descubre una nueva forma de cuidar tu vehículo con recordatorios '
          'inteligentes y diagnósticos en tiempo real.',
      icon: Icons.directions_car_filled_outlined,
      features: ['Motor OK', '100% Vida'],
    ),
  ];
```

> **Esto es una decisión, no un parche.** Tres ilustraciones reales serían mejores y no existen (§19.1). Lo que **no** es aceptable es que la primera pantalla de la app dependa de una URL efímera de un CDN de terceros, sin estado de error, repetida tres veces. Un degradado de marca con un icono distinto por diapositiva es honesto, funciona sin red, se ve bien en ambos temas y **deja de mentir sobre haber tres imágenes distintas**. Cuando existan los assets, se rellena `assetPath` y no hay que tocar nada más.
>
> `_contents` pasa a `static const`: hoy es un `final` de instancia que reconstruye tres objetos en cada `State`.

**4c. Los blobs difuminados.** Los dos `Positioned` con `.withBlur(30)` y `.withBlur(40)` y la extensión `withBlur` de [L444-449](../../../lib/features/onboarding/presentation/pages/onboarding_screen.dart#L444-L449) se **eliminan**. Están detrás de un panel opaco al 80 %; su contribución visual es casi nula y cuestan dos capas de `ImageFiltered` de sigma alto por página. El `BackdropFilter` del panel se queda: ese sí se ve.

Si quieres conservar el color de fondo, un `RadialGradient` en el `Container` del `Stack` da el mismo efecto a coste cero.

- [ ] **Step 5: correr y confirmar verde**

```bash
flutter test test/features/onboarding/
```

- [ ] **Step 6: comprobar el coste**

```bash
flutter run --profile -d <dispositivo>
```

Recorre las tres páginas con el *performance overlay* activo. Anota en el commit los milisegundos de raster antes y después; es la única forma honesta de afirmar que la mejora existe.

- [ ] **Step 7: cerrar**

```bash
dart format . && dart fix --apply && flutter analyze && flutter test
```

**Commit:** `fix(onboarding): panel responsivo, ilustraciones sin dependencia de red y una sola capa de desenfoque`

---

## 11. Task 10: `splash_screen` — devolver los 3 segundos

**Files:**
- Modify: `lib/features/splash/presentation/pages/splash_screen.dart`
- Test: `test/features/splash/presentation/pages/splash_screen_timing_test.dart`
- No romper: `test/features/splash/presentation/pages/splash_screen_onboarding_test.dart`

**Interfaces:**
- Consumes: `AppMotion.reduced` (Fase 1 Task 2); `AppTextStyles`; `context.appColors`; `pumpEntryNoSettle` (Task 1).
- Produces: nada público nuevo.

**Los cuatro problemas, en orden de impacto:**

1. **Espera fija de 3 s antes de comprobar nada, más hasta 5 s de sondeo** (§0.4). Peor caso **8 segundos**; mejor caso 3, aunque todo esté en caché.
2. **Barra de progreso falsa**: `TweenAnimationBuilder` de 0 a 1 en exactamente 3 s, sin relación con la carga real.
3. **`"Auto"` a 1,65:1 en tema oscuro** (§0.4), mientras `"Doc"` está a 7,00:1.
4. **Desborda 92 px en vertical a 800 × 400** (§0.1).

Más: siete tamaños fijos ≥ 100 px, `Colors.black` en una sombra, dos cadenas en español literal (`'DIAGNÓSTICO PROFESIONAL'`, `'Cargando datos...'`), un `AnimationController` con `..repeat()` sin guarda de *reduced motion*, y un `debugPrint` de cinco campos en la ruta caliente del arranque.

**El cambio que importa, y su límite.** El splash **debe** seguir esperando a que `UserProfileProvider` haya intentado la carga: sin eso, `resolveRedirect` no sabe adónde mandar al usuario y el sondeo existe por una razón real. Lo que se elimina es la **espera fija que no depende de nada**:

| | Hoy | Después |
|---|---|---|
| Espera incondicional previa | **3.000 ms** | **0 ms** |
| Retardo mínimo anti-parpadeo | — | **400 ms** |
| Sondeo del perfil | 10 × 500 ms = 5.000 ms | 20 × 100 ms = 2.000 ms |
| Peor caso | **8.000 ms** | **2.400 ms** |
| Mejor caso | **3.000 ms** | **400 ms** |

El retardo mínimo de 400 ms **sí** tiene propósito: sin él, un usuario con sesión en caché vería el splash parpadear un fotograma, que se percibe como un fallo. Es la única espera artificial que sobrevive, y es 7,5 veces más corta.

> §1.5 se respeta: **no cambia adónde navega el splash** en ninguna de las cinco ramas (`redirect`, taller, admin, propietario, sin perfil, sin sesión). Solo cambia cuándo.

- [ ] **Step 1: invocar las skills**

`Skill(emil-design-eng)` — sobre el retardo mínimo anti-parpadeo. Anota el umbral que propone; si difiere de 400 ms, usa el suyo y déjalo escrito.

`Skill(ui-ux-pro-max:ui-ux-pro-max)` — §Performance: *"Never show a fake progress indicator"* y *"Perceived performance: show real state"*.

- [ ] **Step 2: escribir el test que falla**

```dart
// test/features/splash/presentation/pages/splash_screen_timing_test.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:autodoc/core/providers/auth_session_provider.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/features/splash/presentation/pages/splash_screen.dart';

import '../../../../helpers/test_helpers.mocks.dart';
import '../../../../support/contrast.dart';
import '../../../../support/entry_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  Future<void> pumpRouter(WidgetTester tester, {required double width, required double height}) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Firebase.initializeApp();
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final mockAuth = MockFirebaseAuth();
    final controller = StreamController<User?>.broadcast();
    addTearDown(controller.close);
    when(mockAuth.idTokenChanges()).thenAnswer((_) => controller.stream);
    when(mockAuth.currentUser).thenReturn(null);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthSessionProvider>.value(
            value: AuthSessionProvider(firebaseAuth: mockAuth),
          ),
          ChangeNotifierProvider<UserProfileProvider>.value(
            value: UserProfileProvider(),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: GoRouter(
            initialLocation: '/',
            routes: [
              GoRoute(path: '/', builder: (_, _) => const SplashScreen()),
              GoRoute(
                path: '/onboarding',
                builder: (_, _) => const Scaffold(body: Text('ONBOARDING')),
              ),
              GoRoute(
                path: '/login',
                builder: (_, _) => const Scaffold(body: Text('LOGIN')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('un visitante sin sesion sale del splash en menos de 1 segundo', (
    tester,
  ) async {
    await pumpRouter(tester, width: 375, height: 812);
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();
    expect(
      find.text('ONBOARDING'),
      findsOneWidget,
      reason: 'el splash sigue reteniendo al usuario mas de 900 ms',
    );
  });

  testWidgets('no hay barra de progreso falsa', (tester) async {
    final source = File(
      'lib/features/splash/presentation/pages/splash_screen.dart',
    ).readAsStringSync();
    expect(
      source.contains('TweenAnimationBuilder'),
      isFalse,
      reason: 'la barra de 3 s no medía ninguna carga real',
    );
    expect(
      RegExp(r'Duration\(seconds:\s*3\)').hasMatch(source),
      isFalse,
      reason: 'sigue la espera fija de 3 segundos',
    );
  });

  testWidgets('el nombre de la app se lee en los dos temas', (tester) async {
    for (final brightness in Brightness.values) {
      await pumpEntryNoSettle(
        tester,
        const _SplashBranding(),
        width: 375,
        brightness: brightness,
      );
      final context = tester.element(find.byType(_SplashBranding));
      final colors = context.appColors;
      for (final key in const <String>['splash-auto', 'splash-doc']) {
        final text = tester.widget<Text>(find.byKey(ValueKey(key)));
        expect(
          contrastRatio(text.style!.color!, colors.primary),
          greaterThanOrEqualTo(3.0),
          reason: '$key ilegible en $brightness',
        );
      }
    }
  });

  testWidgets('no desborda en horizontal de telefono', (tester) async {
    final errors = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = errors.add;
    await pumpRouter(tester, width: 800, height: 400);
    await tester.pump(const Duration(milliseconds: 100));
    FlutterError.onError = previous;
    expect(errors, isEmpty, reason: '${errors.map((e) => e.exception).toList()}');
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });
}
```

> `_SplashBranding` es el widget que extraes en el Step 4: el bloque de marca del splash, aislado para poder probarlo sin router ni Firebase. Extraerlo **es parte de la implementación**, no un truco de test: hoy el 40 % del fichero es imposible de probar porque está soldado a un `Future.delayed`.

- [ ] **Step 3: correr y confirmar el fallo exacto**

```bash
flutter test test/features/splash/
```

Expected:

1. `el splash sigue reteniendo al usuario mas de 900 ms` — `find.text('ONBOARDING')` es `findsNothing` a los 900 ms.
2. `la barra de 3 s no medía ninguna carga real`: `Expected: <false> / Actual: <true>`.
3. Error de compilación: `_SplashBranding` no existe.
4. Tras crearlo, en oscuro `splash-auto` medirá **1.65** contra `greaterThanOrEqualTo(3.0)`.
5. `[A RenderFlex overflowed by 92 pixels on the bottom.]`.

- [ ] **Step 4: implementar**

**4a. La navegación.** Sustituye el `initState` entero:

```dart
  static const Duration _minimumSplash = Duration(milliseconds: 400);
  static const Duration _pollInterval = Duration(milliseconds: 100);
  static const int _maxPolls = 20;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    // El giro solo arranca si el usuario no ha pedido menos movimiento;
    // se decide en el primer frame, cuando ya hay MediaQuery.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!AppMotion.reduced(context)) _controller.repeat();
      _resolveDestination();
    });
  }

  Future<void> _resolveDestination() async {
    final started = DateTime.now();
    final session = context.read<AuthSessionProvider>();
    final profile = context.read<UserProfileProvider>();

    String destination;
    final user = session.user;

    if (user == null) {
      final prefs = AuthPreferencesService();
      final rememberMe = await prefs.getRememberMe();
      final onboardingCompleted = await prefs.isOnboardingCompleted();
      destination = (rememberMe || onboardingCompleted)
          ? '/login'
          : '/onboarding';
    } else {
      // Espera acotada a que el perfil termine de intentarse: 2 s en vez
      // de 5, sondeando cada 100 ms en vez de cada 500.
      var polls = 0;
      while ((!profile.hasAttemptedFetch || profile.isLoading) &&
          polls < _maxPolls) {
        await Future<void>.delayed(_pollInterval);
        polls++;
      }
      if (!mounted) return;

      final userData = profile.userData;
      if (userData == null) {
        destination = '/profile_setup';
      } else {
        final redirectParam = GoRouterState.of(
          context,
        ).uri.queryParameters['redirect'];
        if (redirectParam != null && redirectParam.isNotEmpty) {
          destination = Uri.decodeComponent(redirectParam);
        } else {
          final role = userData.rol.trim().toLowerCase();
          destination = switch (role) {
            'taller' || 'mecanico' => '/mechanic_dashboard',
            'admin' || 'administrador' => '/admin/dashboard',
            _ => '/dashboard',
          };
        }
      }
    }

    // Retardo minimo anti-parpadeo: si todo estaba en cache, la resolucion
    // tarda ~0 ms y el splash aparecerian y desaparecerian en un frame,
    // que se lee como un fallo. 400 ms es el suelo, no el techo.
    final elapsed = DateTime.now().difference(started);
    if (elapsed < _minimumSplash) {
      await Future<void>.delayed(_minimumSplash - elapsed);
    }
    if (!mounted) return;
    context.go(destination);
  }
```

**Las cinco ramas de destino son literalmente las de hoy** ([L78-108](../../../lib/features/splash/presentation/pages/splash_screen.dart#L78-L108)), reescritas como expresión `switch` y con el orden `redirect` → rol conservado. El `debugPrint` de cinco campos desaparece.

**4b. El bloque de marca, extraído y con contraste arreglado.**

```dart
class _SplashBranding extends StatelessWidget {
  const _SplashBranding();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _SplashLogo(),
        const SizedBox(height: AppSpacing.xxl),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Auto',
                // `success` daba 1,65:1 sobre `primary` en oscuro (§0.4).
                // `onPrimary` esta definido precisamente para ir encima de
                // `primary`: 10,32:1 en claro y 12,12:1 en oscuro.
                style: AppTextStyles.displaySmall.copyWith(
                  color: colors.onPrimary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1,
                ),
              ),
              TextSpan(
                text: 'Doc',
                style: AppTextStyles.displaySmall.copyWith(
                  color: colors.secondary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'DIAGNÓSTICO PROFESIONAL',
          style: AppTextStyles.labelMedium.copyWith(
            color: colors.onPrimary,
            letterSpacing: 4,
          ),
        ),
      ],
    );
  }
}
```

> Los dos `Text` necesitan `key: ValueKey('splash-auto')` / `'splash-doc'` para el test; ponlos en `TextSpan`… **no se puede**: `TextSpan` no acepta `Key`. Cambia el `RichText` por un `Row` de dos `Text` con `MainAxisSize.min`, que además permite `Flexible` si algún día el nombre se traduce. Ese es el motivo real del cambio, no el test.

**El segundo cambio de contraste, igual de importante:** `'DIAGNÓSTICO PROFESIONAL'` estaba en `onPrimary` **al 60 %**, que en oscuro da **4,08:1** — por debajo de 4,5 para texto pequeño. Se sube a opacidad completa; si visualmente pesa demasiado, baja el tamaño, no el contraste.

**4c. El progreso, honesto.** Sustituye el `Container(width: 192)` + `TweenAnimationBuilder` por un indicador indeterminado, que es lo que la situación realmente es:

```dart
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 192),
                child: LinearProgressIndicator(
                  minHeight: 4,
                  backgroundColor: colors.onPrimary.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(colors.secondary),
                ),
              ),
```

**4d. El desbordamiento vertical.** La `Column` de `spaceBetween` pasa a poder encogerse:

```dart
          SafeArea(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.sizeOf(context).height -
                      MediaQuery.paddingOf(context).vertical,
                ),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [ /* … */ ],
                    ),
                  ),
                ),
              ),
            ),
          ),
```

Es el patrón estándar para «`spaceBetween` cuando cabe, scroll cuando no». Los tamaños fijos del logo (128/110/100/80) se mantienen: son un isotipo, no contenido, y no desbordan a 320 px (verificado).

- [ ] **Step 5: correr y confirmar verde**

```bash
flutter test test/features/splash/
```

Expected: los 4 nuevos en verde **y** `splash_screen_onboarding_test.dart` intacto. Ese test comenta *"The splash screen waits 3 seconds before navigating"* y hace `pump(Duration(seconds: 4))`; con la espera reducida sigue pasando, porque 4 s cubren de sobra 400 ms. **Actualiza ese comentario** en el mismo commit: dejarlo sería documentar algo que ya no es cierto.

- [ ] **Step 6: medir el arranque de verdad**

```bash
flutter run --profile -d <dispositivo>
```

Cronometra desde el toque en el icono hasta el primer frame del dashboard, tres veces, antes y después. Escribe los seis números en el commit.

- [ ] **Step 7: cerrar**

```bash
dart format . && dart fix --apply && flutter analyze && flutter test
```

**Commit:** `perf(splash): eliminar la espera fija de 3 s, la barra de progreso falsa y el 1,65:1 del nombre en oscuro`

---

## 12. Task 11: `profile_setup_screen` — la barra que desborda en todos los teléfonos

**Files:**
- Modify: `lib/features/profile/presentation/pages/profile_setup_screen.dart`
- Test: `test/features/profile/presentation/pages/profile_setup_screen_test.dart`

**Interfaces:**
- Consumes: `WindowClass`, `AppBreakpoints.of`, `AppBreakpoints.maxFormWidth` (Fase 1 Task 1); `AppButton` (Fase 3 Task 1); `AppTextField` con `textInputAction` y `onSubmitted` (Task 3); `AppMotion` (Fase 1 Task 2); `pumpEntry`, `pumpEntryCollecting`, `overflowPixels`, `kEntryLocales` (Task 1).
- Produces: nada público nuevo.

**Es la tarea con el criterio de aceptación más nítido de la fase:** hoy la pantalla produce **exactamente dos** `RenderFlex` a 320, 360, 375, 390 y 414 px, y **uno** a 480 (§0.1). Después debe producir **cero** en los ocho anchos auditados y en los dos idiomas.

**Los seis problemas:**

| # | Problema | Evidencia |
|---|---|---|
| 1 | La `AppBar` desborda por debajo de 600 px | §0.1, ocho medidas |
| 2 | El formulario mide **1314,4 px** a 1440 px de ventana | medido |
| 3 | `'PASO 1 DE 1'` con la barra al **100 %** | [L103-135](../../../lib/features/profile/presentation/pages/profile_setup_screen.dart#L103-L135) |
| 4 | Las tarjetas de rol son `GestureDetector` mudos | [L791-793](../../../lib/features/profile/presentation/pages/profile_setup_screen.dart#L791-L793) |
| 5 | `_notificationsEnabled` nunca se persiste | §0.6.6 → §19.2 |
| 6 | El contenido arranca **debajo** de la `AppBar` translúcida | `extendBodyBehindAppBar: true` + `SafeArea` que no descuenta la toolbar |

**Sobre el #4, que es el más importante de todos.** La elección *Propietario* / *Mecánico* determina el rol del usuario y, con él, **toda la aplicación que verá a partir de ese momento** ([L707-712](../../../lib/features/profile/presentation/pages/profile_setup_screen.dart#L707-L712) y [splash_screen.dart:84-91](../../../lib/features/splash/presentation/pages/splash_screen.dart#L84-L91)). Hoy son dos `Column` dentro de `GestureDetector`: sin rol, sin estado de selección expuesto, sin ripple. Un usuario con lector de pantalla oye dos textos sueltos y no tiene forma de saber cuál está elegido. Es la decisión más consecuente del alta y la menos accesible de la pantalla.

**Sobre el #3.** Un indicador que dice *"paso 1 de 1"* con la barra llena no informa: desinforma. Y ocupa, junto al botón *Salir*, los ~250 px que provocan el problema #1. Quitarlo resuelve dos cosas a la vez.

- [ ] **Step 1: invocar las skills**

`Skill(ui-ux-pro-max:ui-ux-pro-max)` + `scripts/search.py "profile setup role selection form" --stack flutter` — §Forms y §Selection controls. Anota lo que dice sobre grupos de opción exclusiva (`radio`) frente a tarjetas.

`Skill(emil-design-eng)` — sobre el `AnimatedSwitcher` del banner de rol ([L478-479](../../../lib/features/profile/presentation/pages/profile_setup_screen.dart#L478-L479)) y el `AnimatedContainer` de 200 ms de las tarjetas.

- [ ] **Step 2: escribir el test que falla**

```dart
// test/features/profile/presentation/pages/profile_setup_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/features/profile/presentation/pages/profile_setup_screen.dart';

import '../../../../support/entry_harness.dart';
import '../../../../support/responsive_harness.dart';

void main() {
  testWidgets('CERO desbordamientos en los ocho anchos y los dos idiomas', (
    tester,
  ) async {
    for (final locale in kEntryLocales) {
      for (final width in kAuditWidths) {
        final errors = await pumpEntryCollecting(
          tester,
          const ProfileSetupScreen(),
          width: width,
          locale: locale,
        );
        expect(
          errors,
          isEmpty,
          reason:
              'profile_setup desborda a $width px en ${locale.languageCode}: '
              '${errors.map(overflowPixels).toList()}',
        );
      }
    }
  });

  testWidgets('el formulario no supera maxFormWidth', (tester) async {
    await pumpEntry(tester, const ProfileSetupScreen(), width: 1440, height: 900);
    expect(
      tester.getSize(find.byKey(const ValueKey('setup-form'))).width,
      lessThanOrEqualTo(AppBreakpoints.maxFormWidth),
    );
  });

  testWidgets('no hay indicador de paso falso', (tester) async {
    await pumpEntry(tester, const ProfileSetupScreen(), width: 375);
    expect(find.textContaining('PASO 1 DE 1'), findsNothing);
  });

  testWidgets('las tarjetas de rol son un grupo de opcion exclusiva', (
    tester,
  ) async {
    // Sin este handle, `tester.getSemantics` lanza «Semantics are not
    // enabled» antes de llegar a la primera asercion. Y se cierra con
    // `dispose()` al final del cuerpo, no con `addTearDown` — ver la nota
    // de la Task 8 Step 2.
    final handle = tester.ensureSemantics();

    await pumpEntry(tester, const ProfileSetupScreen(), width: 375);

    final owner = find.byKey(const ValueKey('setup-role-propietario'));
    final mechanic = find.byKey(const ValueKey('setup-role-mecanico'));
    expect(owner, findsOneWidget);
    expect(mechanic, findsOneWidget);

    // Propietario viene seleccionado por defecto.
    expect(tester.getSemantics(owner).hasFlag(SemanticsFlag.isSelected), isTrue);
    expect(
      tester.getSemantics(mechanic).hasFlag(SemanticsFlag.isSelected),
      isFalse,
    );

    // Y son mutuamente exclusivas.
    await tester.tap(mechanic);
    await tester.pumpAndSettle();
    expect(tester.getSemantics(owner).hasFlag(SemanticsFlag.isSelected), isFalse);
    expect(
      tester.getSemantics(mechanic).hasFlag(SemanticsFlag.isSelected),
      isTrue,
    );

    // Y cada una mide al menos 48 dp.
    for (final finder in <Finder>[owner, mechanic]) {
      expect(tester.getSize(finder).height, greaterThanOrEqualTo(48));
    }

    handle.dispose();
  });

  testWidgets('el contenido empieza por debajo de la AppBar', (tester) async {
    await pumpEntry(tester, const ProfileSetupScreen(), width: 375);
    final title = find.text('¡Bienvenido a AutoDoc!');
    final appBar = find.byType(AppBar);
    expect(
      tester.getTopLeft(title).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(appBar).dy),
      reason: 'el titulo queda debajo de la barra translucida',
    );
  });

  testWidgets('la camara de la foto mide 48x48', (tester) async {
    await pumpEntry(tester, const ProfileSetupScreen(), width: 375);
    final camera = find.byKey(const ValueKey('setup-pick-photo'));
    final size = tester.getSize(camera);
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });
}
```

- [ ] **Step 3: correr y confirmar el fallo exacto**

```bash
flutter test test/features/profile/presentation/pages/profile_setup_screen_test.dart
```

Expected, en este orden exacto:

1. `profile_setup desborda a 320.0 px en es: [144.0, 176.0]` — los dos `RenderFlex` de §0.1, con sus píxeles.
2. `Found 0 widgets with key [<'setup-form'>]`.
3. `Expected: no matching candidates / Actual: Found 1 widget with text containing "PASO 1 DE 1"`.
4. `Found 0 widgets with key [<'setup-role-propietario'>]`.
5. La cámara medirá **32 × 32** contra 48.

- [ ] **Step 4: implementar**

**4a. La `AppBar`: quitar el indicador falso y dejar respirar al título.**

```dart
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: AppBar(
              backgroundColor: appColors.surface.withValues(alpha: 0.75),
              elevation: 0,
              centerTitle: false,
              titleSpacing: AppSpacing.base,
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.directions_car, color: primaryColor, size: 22),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      'AutoDoc',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: appColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                // Antes: TextButton.icon + una columna con «PASO 1 DE 1»
                // y una barra al 100 %. Entre los dos consumian ~250 px de
                // los 320 y dejaban al titulo sin sitio (§0.1).
                IconButton(
                  tooltip: 'Salir',
                  onPressed: _signOut,
                  icon: Icon(Icons.logout, color: appColors.textSecondary),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
            ),
          ),
        ),
      ),
```

**Tres cambios y por qué cada uno:**

- **El indicador de paso desaparece.** No había paso 2 (§0.5.2).
- **`TextButton.icon('Salir')` → `IconButton` con `tooltip`.** El texto se va, la etiqueta accesible se queda, y el ancho consumido baja de ~90 px a 48. Es lo que elimina el segundo `RenderFlex`.
- **`Flexible` + `ellipsis` en el título.** Cinturón además de tirantes: aunque un idioma alargue *Salir*, el título cede en vez de desbordar.

Y el `_signOut` extraído, que además **deja de llamar a Firebase desde el widget** ([L77](../../../lib/features/profile/presentation/pages/profile_setup_screen.dart#L77): `FirebaseAuth.instance.signOut()` directo, saltándose el provider y `CONVENTIONS.md`):

```dart
  Future<void> _signOut() async {
    final router = GoRouter.of(context);
    await context.read<AuthProvider>().signOut();
    router.go('/login');
  }
```

> Esto **no** modifica el provider: solo lo usa. §1.3 se respeta.

**4b. El ancho del formulario y el hueco de la `AppBar`.**

```dart
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                AppBreakpoints.gutter(windowClass),
                // 64 de toolbar + aire. Antes eran 24, con
                // `extendBodyBehindAppBar: true`, asi que el titulo
                // arrancaba debajo de la barra translucida.
                kToolbarHeight + AppSpacing.xl,
                AppBreakpoints.gutter(windowClass),
                120,
              ),
              child: Center(
                child: ConstrainedBox(
                  key: const ValueKey('setup-form'),
                  constraints: const BoxConstraints(
                    maxWidth: AppBreakpoints.maxFormWidth,
                  ),
                  child: /* el panel de cristal, igual */,
                ),
              ),
            ),
          ),
```

**4c. Las tarjetas de rol como grupo exclusivo.**

```dart
  Widget _buildRoleCard({
    required Key key,
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final appColors = context.appColors;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = appColors.primary;

    return Semantics(
      key: key,
      button: true,
      selected: isSelected,
      inMutuallyExclusiveGroup: true,
      label: title,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: AnimatedContainer(
          duration: AppMotion.transformDuration(context, AppMotion.press),
          curve: AppMotion.easeOut,
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          decoration: BoxDecoration(
            color: isSelected
                ? primaryColor.withValues(alpha: isDarkMode ? 0.2 : 0.1)
                : (isDarkMode
                      ? appColors.surfaceVariant.withValues(alpha: 0.4)
                      : appColors.surface),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: isSelected
                  ? primaryColor
                  : appColors.outline.withValues(alpha: 0.4),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // El color NO es el unico portador del estado: ademas del
              // borde grueso y el relleno, un check explicito.
              Icon(
                isSelected ? Icons.check_circle : icon,
                color: isSelected ? primaryColor : appColors.textSecondary,
                size: 34,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTextStyles.labelLarge.copyWith(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected
                      ? appColors.textPrimary
                      : appColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
```

> **El `Icons.check_circle` cuando está seleccionado** cumple la regla §10 de `ui-ux-pro-max`: el color no puede ser el único portador de significado. Hoy la única diferencia entre elegido y no elegido es el tinte y el grosor del borde.

**4d. La cámara a 48 × 48.** El `GestureDetector` de [L323](../../../lib/features/profile/presentation/pages/profile_setup_screen.dart#L323) pasa a:

```dart
                                      child: Tooltip(
                                        message: 'Elegir foto de perfil',
                                        child: InkWell(
                                          key: const ValueKey('setup-pick-photo'),
                                          customBorder: const CircleBorder(),
                                          onTap: _pickPhoto,
                                          child: Container(
                                            width: 48,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              color: primaryColor,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: appColors.surface,
                                                width: 2,
                                              ),
                                            ),
                                            child: Icon(
                                              Icons.camera_alt_rounded,
                                              color: appColors.onPrimary,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                      ),
```

`color: appColors.onPrimary` sustituye al `isDarkMode ? appColors.surface : Colors.white` de [L357-359](../../../lib/features/profile/presentation/pages/profile_setup_screen.dart#L357-L359) — que es exactamente lo que `onPrimary` significa, escrito a mano. Lo mismo en el `foregroundColor` del botón de envío ([L733](../../../lib/features/profile/presentation/pages/profile_setup_screen.dart#L733)).

**4e. El resto de la tokenización.** Los 16 `GoogleFonts` → `AppTextStyles`; los tres `Colors.black` de sombra → `AppShadows`; el `Colors.white` restante → `onPrimary`. El botón de envío pasa a `AppButton` con `isLoading: _isLoading`.

- [ ] **Step 5: correr y confirmar verde**

```bash
flutter test test/features/profile/
```

- [ ] **Step 6: cerrar**

```bash
dart format . && dart fix --apply && flutter analyze && flutter test
```

**Commit:** `fix(profile-setup): eliminar los dos overflows de la AppBar en todo ancho de telefono y hacer accesible la eleccion de rol`

---

## 13. Task 12: `user_profile_screen` — desbifurcar la paleta

**Files:**
- Modify: `lib/features/profile/presentation/pages/user_profile_screen.dart` (color y tipografía; el layout es la Task 13)
- Test: `test/features/profile/presentation/pages/user_profile_colors_test.dart`

**Interfaces:**
- Consumes: `context.appColors`; `AppTextStyles`; `AppShadows`; `contrastRatio`, `composite` (Fase 1 Task 4); `AppTextField` con `enabled` (Task 3); `pumpEntry`, `FakeUserProfileProvider`, `testUser` (Task 1).
- Produces: nada público nuevo.

**53 colores literales, y el argumento no es el número.** §0.3 lo demuestra: la pantalla **copió** cinco valores de `AppPalette` en vez de leerlos, así que la corrección de contraste de la Fase 1 Task 4 no la alcanzará. Y añadió un sexto color, `#98FFD9`, que no existe en la marca.

**Los tres defectos de contraste que hay que arreglar, medidos:**

| Defecto | Medida | Dónde |
|---|---|---|
| Campo del nombre en edición, tema oscuro: texto blanco sobre relleno blanco | **1,00:1** | [L599-611](../../../lib/features/profile/presentation/pages/user_profile_screen.dart#L599-L611) |
| Pista del `Switch` `#98FFD9` contra su *thumb* blanco | **1,19:1** | [L566-570](../../../lib/features/profile/presentation/pages/user_profile_screen.dart#L566-L570) |
| Bordes `Colors.grey[200]` (`#EEEEEE`) en tema oscuro | borde casi blanco sobre tarjeta oscura | [L619-625](../../../lib/features/profile/presentation/pages/user_profile_screen.dart#L619-L625) |

Y un parámetro muerto: `accentColor` se calcula, se pasa a `_buildProfileHeader` y **no se usa en el cuerpo** (§0.3).

- [ ] **Step 1: invocar las skills**

`Skill(ui-ux-pro-max:ui-ux-pro-max)` — §Color completa. Anota la regla sobre estados de control (`Switch`, `Checkbox`) y contraste del elemento móvil contra su pista.

- [ ] **Step 2: escribir el test que falla**

```dart
// test/features/profile/presentation/pages/user_profile_colors_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/widgets/app_text_field.dart';
import 'package:autodoc/features/profile/presentation/pages/user_profile_screen.dart';

import '../../../../support/contrast.dart';
import '../../../../support/entry_harness.dart';

void main() {
  testWidgets('cero colores literales en el fichero', (tester) async {
    final source = File(
      'lib/features/profile/presentation/pages/user_profile_screen.dart',
    ).readAsStringSync();

    final named = RegExp(
      r'Colors\.(white|black|grey|gray|blue|red|green|orange|purple|amber)',
    ).allMatches(source).map((m) => m.group(0)).toList();
    final hex = RegExp(r'Color\(0x').allMatches(source).length;

    expect(named, isEmpty, reason: 'quedan literales con nombre: $named');
    expect(hex, 0, reason: 'quedan $hex Color(0x…)');
  });

  testWidgets('editando en oscuro el nombre se lee (hoy da 1,00:1)', (
    tester,
  ) async {
    await pumpEntry(
      tester,
      const UserProfileScreen(),
      width: 375,
      brightness: Brightness.dark,
      profile: FakeUserProfileProvider(userData: testUser(nombre: 'Ada L.')),
    );

    await tester.tap(find.byKey(const ValueKey('profile-edit-toggle')));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(UserProfileScreen));
    final colors = context.appColors;
    final field = tester.widget<AppTextField>(
      find.byKey(const ValueKey('profile-name-field')),
    );
    expect(field.enabled, isTrue);

    // El campo ya no pinta su propio relleno: hereda el del tema, asi que
    // basta comprobar el par textPrimary / surfaceVariant.
    expect(
      contrastRatio(colors.textPrimary, colors.surfaceVariant),
      greaterThanOrEqualTo(4.5),
    );
  });

  testWidgets('los interruptores usan el color de marca, no #98FFD9', (
    tester,
  ) async {
    await pumpEntry(tester, const UserProfileScreen(), width: 375);
    final context = tester.element(find.byType(UserProfileScreen));
    final colors = context.appColors;

    final switches = tester.widgetList<Switch>(find.byType(Switch));
    expect(switches, hasLength(3));
    for (final s in switches) {
      expect(s.activeTrackColor, colors.primary);
      expect(s.activeThumbColor, colors.onPrimary);
      expect(
        contrastRatio(colors.onPrimary, colors.primary),
        greaterThanOrEqualTo(3.0),
      );
    }
  });

  testWidgets('no quedan GoogleFonts', (tester) async {
    final source = File(
      'lib/features/profile/presentation/pages/user_profile_screen.dart',
    ).readAsStringSync();
    expect(source.contains('GoogleFonts'), isFalse);
  });

  testWidgets('el titulo del dialogo de borrado sale del ARB', (tester) async {
    final source = File(
      'lib/features/profile/presentation/pages/user_profile_screen.dart',
    ).readAsStringSync();
    expect(source.contains("Text('Eliminar Cuenta')"), isFalse);
    expect(source.contains('upDeleteAccountTitle'), isTrue);
  });
}
```

- [ ] **Step 3: correr y confirmar el fallo exacto**

```bash
flutter test test/features/profile/presentation/pages/user_profile_colors_test.dart
```

Expected:

1. `quedan literales con nombre: [Colors.grey, Colors.white, Colors.white, …]` — **36** entradas.
2. `quedan 17 Color(0x…)`.
3. `Found 0 widgets with key [<'profile-edit-toggle'>]`.
4. `activeTrackColor` será `Color(0xff98ffd9)` contra `colors.primary`.
5. `Expected: <true> / Actual: <false>` para `upDeleteAccountTitle`.

- [ ] **Step 4: implementar**

**4a. Borrar la paleta local.** Las cinco líneas de [L99-107](../../../lib/features/profile/presentation/pages/user_profile_screen.dart#L99-L107) se sustituyen por una:

```dart
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
```

y el degradado de fondo pasa a tokens:

```dart
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colors.surfaceVariant, colors.surface],
          ),
        ),
```

> `#F7F6F8 → #ECE9F1` en claro y `#1E293B → #0F172A` en oscuro eran, respectivamente, `surface → (un tono inventado)` y `surfaceVariant → surface`. Usar `surfaceVariant → surface` en ambos temas da el mismo gradiente sutil sin literales y **sí** sigue a la marca.

**4b. Las dos tarjetas.** El patrón `Colors.white.withValues(alpha: isDark ? 0.05 : 0.7)` repetido en `_buildInfoSection` y `_buildSettingsSection` se extrae:

```dart
  BoxDecoration _cardDecoration(AppColors colors, bool isDark) {
    return BoxDecoration(
      color: colors.surfaceContainer.withValues(alpha: isDark ? 0.6 : 0.85),
      borderRadius: BorderRadius.circular(AppRadius.xxl),
      border: Border.all(color: colors.outline.withValues(alpha: 0.3)),
      boxShadow: isDark ? AppShadows.darkSm : AppShadows.lightSm,
    );
  }
```

El borde pasa de `Colors.white @ 0.3` —invisible sobre una tarjeta blanca— a `outline @ 0.3`, que se ve en los dos temas.

**4c. El campo del nombre, que es el 1,00:1.** `_buildInfoField` desaparece entero y se sustituye por `AppTextField`, que ya sabe pintar sus estados:

```dart
          AppTextField(
            key: const ValueKey('profile-name-field'),
            label: context.l10n.upFullName,
            controller: _nameController,
            enabled: _isEditing,
            prefixIcon: Icon(Icons.person_outline, color: colors.primary),
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.name],
          ),
          const SizedBox(height: AppSpacing.xl),
          AppTextField(
            key: const ValueKey('profile-email-field'),
            label: context.l10n.upEmailAddress,
            controller: _emailController,
            enabled: false,
            prefixIcon: Icon(Icons.email_outlined, color: colors.textSecondary),
          ),
```

**Esto es lo que mata el 1,00:1.** El fallo venía de que el campo elegía su relleno (`Colors.white`) con una regla y su texto (`isDark ? Colors.white : …`) con otra. `AppTextField` usa un solo origen para ambos. Y el `Icons.person_outline` en `colors.primary` sustituye al ternario `enabled ? primary : Color(0xFF94A3B8)`.

**4d. Los tres interruptores.**

```dart
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: colors.onPrimary,
          activeTrackColor: colors.primary,
        ),
```

`onPrimary` sobre `primary` es **10,32:1 en claro y 12,12:1 en oscuro** — el par existe en la paleta precisamente para esto. Se sustituye `Switch.adaptive` por `Switch`: la variante adaptativa ignora `activeThumbColor` en iOS, que es justo el canal por el que se colaba el problema.

**4e. El resto.** Los 12 `GoogleFonts.inter` → `AppTextStyles`; `Colors.grey[100]/[200]/[500]/[700]` → `surfaceVariant` / `outline` / `textSecondary`; `Colors.white70` / `white54` → `textSecondary`; `Color(0xFF64748B)` → `colors.textSecondary`; `Color(0xFF1E293B)` → `colors.textPrimary`; `Color(0xFF94A3B8)` → `colors.textSecondary`; el avatar por defecto de w3schools (§0.6.7) → el `errorWidget` que ya existe justo debajo, con `imageUrl: user.fotoPerfilUrl ?? ''`; `Colors.white` del FAB → `colors.onPrimary`; el parámetro muerto `accent` de `_buildProfileHeader` **se elimina de la firma**.

Y una línea de l10n gratis:

```dart
              title: Text(context.l10n.upDeleteAccountTitle),
```

La clave ya existía y no se usaba (§0.6.8). Cablearla no añade claves, así que §1.4 lo permite.

- [ ] **Step 5: correr y confirmar verde**

```bash
flutter test test/features/profile/
```

- [ ] **Step 6: cerrar**

```bash
dart format . && dart fix --apply && flutter analyze && flutter test
```

**Commit:** `fix(user-profile): desbifurcar la paleta (53 literales), 1,00:1 al editar en oscuro y 1,19:1 en los interruptores`

---

## 14. Task 13: `user_profile_screen` — layout, y devolver la edición por encima de 840 px

**Files:**
- Modify: `lib/features/profile/presentation/pages/user_profile_screen.dart` (estructura)
- Test: `test/features/profile/presentation/pages/user_profile_layout_test.dart`

**Interfaces:**
- Consumes: `WindowClass`, `AppBreakpoints.of`, `WindowClassX.isAtLeastExpanded`, `AppBreakpoints.maxContentWidth` (Fase 1 Task 1); la migración de `responsive_framework` de la **Fase 2 Task 1**; `AppButton` (Fase 3 Task 1); `pumpEntry`, `FakeUserProfileProvider` (Task 1).
- Produces: nada público nuevo.

**El fallo funcional, otra vez, porque es el corazón de la tarea.** Por encima del corte de tablet la pantalla no dibuja su barra ([L180-181](../../../lib/features/profile/presentation/pages/user_profile_screen.dart#L180-L181)); la barra contiene el único botón que pone `_isEditing` a `true`; y el botón de guardar solo existe si `_isEditing`. **En web y tablet horizontal el perfil es de solo lectura y nada lo dice** (§0.3).

La Fase 2 Task 1 mueve el corte de `> 800` a `≥ 840`. **No arregla el fallo, lo desplaza.**

**Segundo fallo estructural:** `_buildAppBar` llama a `Navigator.pop(context)` ([L245](../../../lib/features/profile/presentation/pages/user_profile_screen.dart#L245)), pero `/user_profile` vive **dentro del `ShellRoute`** ([app_router.dart:389](../../../lib/core/router/app_router.dart#L389)) y se alcanza con `context.go`. No hay nada que desapilar: **la flecha de atrás no hace nada**.

**El contrato para `expanded`+** («sidebar de secciones + panel de contenido», maestro §5.4) se cumple con dos columnas:

| Clase | Layout |
|---|---|
| `compact` / `medium` | columna única: cabecera, datos, ajustes, salir |
| `expanded` / `large` | **dos columnas**: izq. cabecera de perfil fija (avatar, nombre, rol, acciones); der. datos + ajustes, con scroll propio. Contenido a `maxContentWidth` |

- [ ] **Step 1: invocar las skills**

`Skill(ui-ux-pro-max:ui-ux-pro-max)` — §Layout, patrón *master detail / settings*. Anota qué dice sobre qué debe quedar fijo y qué debe hacer scroll.

- [ ] **Step 2: escribir el test que falla**

```dart
// test/features/profile/presentation/pages/user_profile_layout_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/features/profile/presentation/pages/user_profile_screen.dart';

import '../../../../support/entry_harness.dart';
import '../../../../support/responsive_harness.dart';

void main() {
  testWidgets('se puede editar el perfil en TODAS las clases de ventana', (
    tester,
  ) async {
    for (final width in kAuditWidths) {
      await pumpEntry(
        tester,
        const UserProfileScreen(),
        width: width,
        height: 900,
        profile: FakeUserProfileProvider(userData: testUser()),
      );

      final toggle = find.byKey(const ValueKey('profile-edit-toggle'));
      expect(
        toggle,
        findsOneWidget,
        reason: 'no hay forma de entrar en edicion a $width px',
      );

      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('profile-save')),
        findsOneWidget,
        reason: 'no hay forma de guardar a $width px',
      );
    }
  });

  testWidgets('en expanded hay dos columnas', (tester) async {
    await pumpEntry(
      tester,
      const UserProfileScreen(),
      width: 375,
      profile: FakeUserProfileProvider(userData: testUser()),
    );
    expect(find.byKey(const ValueKey('profile-side-column')), findsNothing);

    await pumpEntry(
      tester,
      const UserProfileScreen(),
      width: 1024,
      height: 900,
      profile: FakeUserProfileProvider(userData: testUser()),
    );
    final side = find.byKey(const ValueKey('profile-side-column'));
    final main = find.byKey(const ValueKey('profile-main-column'));
    expect(side, findsOneWidget);
    expect(tester.getTopLeft(side).dx, lessThan(tester.getTopLeft(main).dx));
  });

  testWidgets('no hay Navigator.pop en una ruta de shell', (tester) async {
    final source = File(
      'lib/features/profile/presentation/pages/user_profile_screen.dart',
    ).readAsStringSync();
    expect(
      source.contains('Navigator.pop(context)'),
      isFalse,
      reason: '/user_profile vive en el ShellRoute: no hay nada que desapilar',
    );
  });

  testWidgets('el controlador del dialogo de borrado se libera', (
    tester,
  ) async {
    await pumpEntry(
      tester,
      const UserProfileScreen(),
      width: 375,
      profile: FakeUserProfileProvider(userData: testUser()),
    );
    await tester.tap(find.byKey(const ValueKey('profile-delete-account')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-delete-cancel')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('no desborda en ningun ancho auditado', (tester) async {
    for (final width in kAuditWidths) {
      final errors = await pumpEntryCollecting(
        tester,
        const UserProfileScreen(),
        width: width,
        height: 900,
        profile: FakeUserProfileProvider(userData: testUser()),
      );
      expect(errors, isEmpty, reason: 'desborda a $width px');
    }
  });
}
```

Añade `import 'dart:io';`.

- [ ] **Step 3: correr y confirmar el fallo exacto**

```bash
flutter test test/features/profile/presentation/pages/user_profile_layout_test.dart
```

Expected: **el primer test falla en el ancho 840** con
`no hay forma de entrar en edicion a 840.0 px`
—y pasa en 320, 375, 600 y 768. Ese contraste **es** el fallo de §0.3, medido por un test por primera vez.

- [ ] **Step 4: implementar**

**4a. Separar la barra de la acción.** El `_buildAppBar` deja de ser el dueño del botón de editar. La acción sube al `Scaffold`, que existe en todas las clases:

```dart
  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final windowClass = AppBreakpoints.of(context);
    final isWide = windowClass.isAtLeastExpanded;

    final sessionProvider = context.watch<UserProfileProvider>();
    final user = sessionProvider.userData;
    final isLoading = sessionProvider.isLoading;

    if (isLoading && user == null) { /* … igual … */ }
    if (user == null) { /* … estado vacio, igual pero sin responsive_framework … */ }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // La flecha de atras solo tiene sentido si hay algo que desapilar.
        // `/user_profile` es una pestana del ShellRoute: no lo hay.
        automaticallyImplyLeading: false,
        title: Text(
          context.l10n.upMyProfile,
          style: AppTextStyles.titleMedium.copyWith(color: colors.textPrimary),
        ),
        actions: [
          IconButton(
            key: const ValueKey('profile-edit-toggle'),
            tooltip: _isEditing ? context.l10n.upCancel : context.l10n.upEditProfile,
            onPressed: () => setState(() => _isEditing = !_isEditing),
            icon: Icon(
              _isEditing ? Icons.close : Icons.edit_outlined,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      /* … */
      floatingActionButton: _isEditing
          ? FloatingActionButton.extended(
              key: const ValueKey('profile-save'),
              onPressed: isLoading ? null : _saveProfile,
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              icon: isLoading ? null : const Icon(Icons.check),
              label: isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: colors.onPrimary,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(context.l10n.upSaveChanges),
            )
          : null,
    );
  }
```

> **`upEditProfile` no existe en el ARB** y §1.4 prohíbe añadir claves. Usa `context.l10n.upSaveChanges` no —no significa lo mismo—; usa el literal `'Editar perfil'` y anótalo en §18.1 con el resto. Es la opción honesta: un `tooltip` en español es peor que uno traducido y **mucho** mejor que ningún `tooltip`, que es lo que hay hoy.

**El cambio esencial es de una línea conceptual:** la barra ya no está dentro de un `if` de ancho. Es la `AppBar` del `Scaffold` y existe siempre. Con eso, el primer test pasa en los ocho anchos.

**4b. Las dos columnas.**

```dart
  Widget _buildBody(UserModel user, AppColors colors, bool isDark, bool isWide) {
    final header = _buildProfileHeader(user, colors);
    final details = Column(
      children: [
        _buildInfoSection(user, colors, isDark),
        const SizedBox(height: AppSpacing.xl),
        _buildSettingsSection(context, colors, isDark),
        const SizedBox(height: AppSpacing.xxl),
        _buildAccountActions(context, colors),
      ],
    );

    if (!isWide) {
      return SingleChildScrollView(
        padding: EdgeInsets.all(AppBreakpoints.gutter(AppBreakpoints.of(context))),
        child: Column(
          children: [
            header,
            const SizedBox(height: AppSpacing.xxl),
            details,
          ],
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppBreakpoints.maxContentWidth,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // La cabecera queda fija: es identidad, no contenido.
            Expanded(
              flex: 2,
              child: Padding(
                key: const ValueKey('profile-side-column'),
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: header,
              ),
            ),
            Expanded(
              flex: 3,
              child: SingleChildScrollView(
                key: const ValueKey('profile-main-column'),
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: details,
              ),
            ),
          ],
        ),
      ),
    );
  }
```

**4c. El diálogo de borrado: liberar el controlador y poner claves.**

```dart
  Future<void> _showDeleteAccountDialog(BuildContext context) async {
    final passwordController = TextEditingController();
    try {
      await showDialog<void>( /* … igual, con las claves … */ );
    } finally {
      // Antes no se liberaba nunca: una fuga por cada apertura (§0.6.6).
      passwordController.dispose();
    }
  }
```

con `key: const ValueKey('profile-delete-cancel')` en el `TextButton` de cancelar, y `key: const ValueKey('profile-delete-account')` en el `TextButton.icon` que abre el diálogo.

**4d. Las dos acciones destructivas, diferenciadas.** Hoy *Eliminar cuenta* y *Cerrar sesión* son dos `TextButton.icon` idénticos en color de error, uno encima del otro ([L867-918](../../../lib/features/profile/presentation/pages/user_profile_screen.dart#L867-L918)). Cerrar sesión **no es destructivo**:

```dart
  Widget _buildAccountActions(BuildContext context, AppColors colors) {
    return Column(
      children: [
        AppButton(
          text: context.l10n.upSignOut,
          type: AppButtonType.secondary,
          icon: const Icon(Icons.logout),
          onPressed: _signOut,
        ),
        const SizedBox(height: AppSpacing.md),
        TextButton.icon(
          key: const ValueKey('profile-delete-account'),
          onPressed: () => _showDeleteAccountDialog(context),
          icon: Icon(Icons.delete_outline, color: colors.error),
          label: Text(
            context.l10n.upDeleteAccount,
            style: AppTextStyles.labelLarge.copyWith(color: colors.error),
          ),
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.md,
            ),
          ),
        ),
      ],
    );
  }
```

Cerrar sesión sube a `AppButton` secundario (acción normal, frecuente); borrar la cuenta se queda como enlace en color de error, debajo y con menos peso. Ver §19.6: `AppButton` **no** tiene variante destructiva, así que el borrado no puede ser un `AppButton`.

- [ ] **Step 5: correr y confirmar verde**

```bash
flutter test test/features/profile/
```

- [ ] **Step 6: verificación manual**

```bash
flutter run -d chrome
```

Con el shell montado (la pantalla vive en el `ShellRoute`, así que **pruébala navegando**, no aislada): comprueba a 375, 700, 900 y 1400 que el botón de editar existe, que guardar funciona, y que las dos columnas no chocan con el `NavigationRail` de la Fase 2.

- [ ] **Step 7: cerrar**

```bash
dart format . && dart fix --apply && flutter analyze && flutter test
```

**Commit:** `fix(user-profile): editar el perfil deja de ser imposible por encima de 840 px; dos columnas en expanded`

---

## 15. Task 14: cerrar el ratchet de colores y recontar

**Files:**
- Modify: `test/support/tokenized_paths.dart`
- Modify: `docs/superpowers/plans/2026-08-10-ui-ux-overhaul-00-master.md` (§5.6)
- Test: `test/core/theme/hardcoded_colors_test.dart` (existente, de la Fase 1 Task 8)

**Interfaces:**
- Consumes: `kTokenizedPaths` (Fase 1 Task 8).
- Produces: `kTokenizedPaths` extendido con las nueve rutas de esta fase.

Tarea de cierre. **Está verde por diseño** si las Tasks 2–13 se hicieron bien; si algo falla aquí, el fallo está en una tarea anterior, no en esta.

> **§4 y §5.4 del maestro ya están corregidos.** Se actualizaron el 2026-08-12, al escribir este plan, con las cinco correcciones de §0.5 y la nota fechada. **No los vuelvas a tocar.** Lo único que queda pendiente en el maestro es el agregado global de §5.6, que solo se puede recalcular *después* de ejecutar la fase.

- [ ] **Step 1: añadir las rutas**

```dart
const List<String> kTokenizedPaths = <String>[
  // … rutas de las Fases 2–6 …

  // Fase 7 — auth / onboarding / profile / splash
  'lib/features/auth/presentation/pages/auth_screen.dart',
  'lib/features/auth/presentation/widgets/auth_bottom_nav.dart',
  'lib/features/auth/presentation/widgets/auth_background_blobs.dart',
  'lib/features/auth/presentation/widgets/auth_logo_section.dart',
  'lib/features/onboarding/presentation/pages/onboarding_screen.dart',
  'lib/features/profile/presentation/pages/about_screen.dart',
  'lib/features/profile/presentation/pages/profile_setup_screen.dart',
  'lib/features/profile/presentation/pages/user_profile_screen.dart',
  'lib/features/splash/presentation/pages/splash_screen.dart',
];
```

`login_screen.dart` no aparece: la Task 7 lo borró.

- [ ] **Step 2: correr el ratchet**

```bash
flutter test test/core/theme/hardcoded_colors_test.dart
```

Expected: verde. Si sale rojo, lee el fichero que denuncia y vuelve a la tarea que lo tenía asignado; **no** añadas excepciones aquí. Eso es lo único que el ratchet protege.

- [ ] **Step 3: recontar el agregado global del maestro**

§5.6 del maestro dice «**~270 colores hardcodeados** repartidos en 25+ ficheros». Esta fase elimina **64** de ellos (47 `Colors.*` + 17 `Color(0x…)`), 53 solo de `user_profile_screen`. Recalcula la cifra real:

```bash
grep -rnoE "Colors\.(white|black|grey|gray|blue|red|green|orange|purple|amber|yellow|teal|pink|indigo|cyan|lime|brown)[0-9A-Za-z._]*|Color\(0x" lib/features lib/core/widgets | wc -l
```

Y actualiza esa línea de §5.6 con el número que salga y la fecha, indicando qué fases lo han bajado. Si el número no ha bajado en al menos 64 respecto a la medición anterior, **alguna tarea de esta fase no terminó**: encuentra cuál antes de escribir nada.

- [ ] **Step 4: comprobar los invariantes globales que esta fase debía cerrar**

```bash
# Cero pantallas fuera de pages/
find lib/features -name '*_screen.dart' -path '*/screens/*'

# Cero GoogleFonts en los cuatro modulos de la fase
grep -rn "GoogleFonts" lib/features/auth lib/features/onboarding lib/features/profile lib/features/splash

# Cero peticiones a terceros en la ruta de entrada
grep -rn "google.com/images\|w3schools.com\|lh3.googleusercontent.com" lib/
```

Los tres deben devolver **cero** líneas. Son los tres criterios de §17 que ningún test unitario cubre por sí solo.

- [ ] **Step 5: cerrar**

```bash
dart format . && flutter analyze && flutter test
```

**Commit:** `chore(fase-7): cerrar el ratchet de colores y recontar el agregado del plan maestro`

---

## 16. Verificación de cierre de fase

Antes de dar la fase por terminada, sobre la rama completa:

1. **Suite completa**
   ```bash
   flutter test
   ```
   Los 23 tests que existían al abrir la fase siguen en verde, `splash_screen_onboarding_test.dart` incluido (con su comentario actualizado por la Task 10).

2. **Matriz de anchos × idiomas × temas.** Las seis pantallas a **320, 375, 600, 768, 840, 1024, 1200, 1440**, en `es` y `en`, en claro y oscuro. Son 6 × 8 × 2 × 2 = **192 combinaciones**; los tests de cada tarea ya cubren las de desbordamiento, así que aquí la comprobación manual se limita a **320 y 1440, en los dos idiomas y los dos temas** — 24 vistas.

3. **Horizontal de teléfono.** Las seis pantallas a **800 × 400** y **640 × 360**. Es el tamaño que hoy rompe `onboarding` y `splash`; el resto nunca se ha probado ahí.

   ```bash
   flutter test test/features/onboarding/ test/features/splash/
   ```

4. **Reduced motion.**
   ```bash
   flutter test --dart-define=REDUCED_MOTION=true
   ```
   o, si el harness no lee esa variable, ejecuta la suite con `disableAnimations: true` inyectado en `pumpEntry`. Ninguna prueba debe fallar ni colgarse. **Presta atención especial al splash**: si el `..repeat()` quedó sin guarda, aquí se cuelga.

5. **La ruta completa, a mano y con red apagada.**
   Desinstala, activa el modo avión, instala y recorre: splash → onboarding (3 páginas) → login → registro → verificación → profile_setup → dashboard → perfil. **Sin red** es la prueba que las dos peticiones de §0.6.7 y la ilustración de §0.6.3 nunca han pasado.

6. **Lector de pantalla.** TalkBack o VoiceOver sobre login y profile_setup. Comprueba que los botones no se anuncian dos veces (§0.6.1) y que la elección de rol dice cuál está seleccionada.

7. **Escala tipográfica al 200 %.** Ajustes del sistema → tamaño de fuente al máximo. Las seis pantallas. Es donde aparecen los defectos que ningún test de ancho detecta.

8. **Pre-Delivery Checklist** de `ui-ux-pro-max` (`references/pro-rules.md`), ítem por ítem.

9. **`review-animations`** sobre el diff completo de la fase — tocó motion en las Tasks 6, 8, 9 y 10.

10. **`superpowers:requesting-code-review`** sobre la rama.

---

## 17. Criterios de éxito

La fase está terminada cuando:

- [ ] `flutter test` en verde, con los 23 tests preexistentes intactos.
- [ ] **Cero desbordamientos** en las seis pantallas, en los ocho anchos, en `es` y `en`. En particular: `profile_setup` pasa de 2 a 0 a 375 px, y `auth` de 1 a 0 a 320 px en inglés.
- [ ] **`onboarding` no lanza `BoxConstraints has non-normalized height`** a ningún alto de viewport, incluido 400 px.
- [ ] **`splash` no desborda en vertical** a 800 × 400.
- [ ] Un usuario **sin sesión sale del splash en menos de 900 ms** (hoy: 3.000 ms como mínimo absoluto).
- [ ] **No queda ninguna barra de progreso falsa** en la app.
- [ ] `grep -rn "Colors\.\(white\|black\|grey\|blue\|red\|green\|orange\|purple\|amber\)" lib/features/auth lib/features/onboarding lib/features/profile lib/features/splash` devuelve **cero** fuera de `Colors.transparent`.
- [ ] `grep -rn "Color(0x" lib/features/profile` devuelve **cero**.
- [ ] `grep -rn "GoogleFonts" lib/features/auth lib/features/onboarding lib/features/profile lib/features/splash` devuelve **cero**.
- [ ] **Se puede editar y guardar el perfil en los ocho anchos**, incluidos 840, 1024, 1200 y 1440.
- [ ] Ningún par texto/fondo por debajo de **4,5:1** (cuerpo) o **3:1** (texto grande y glifos) en las seis pantallas, **en los dos temas**. En particular: el campo del nombre en edición y oscuro deja de ser 1,00:1; los interruptores dejan de ser 1,19:1; `"Auto"` en el splash deja de ser 1,65:1; el copyright de `about` deja de ser 2,61:1.
- [ ] Todo control tappable de las seis pantallas mide **≥ 48 × 48 dp**, verificado por test: el `Checkbox` de *Recordarme*, las tres acciones de `AuthBottomNav`, las dos cámaras de foto, las dos tarjetas de rol y el botón del onboarding.
- [ ] **Ninguna pantalla de la ruta de entrada hace peticiones a terceros**: ni `google.com` ni `w3schools.com` ni `lh3.googleusercontent.com`.
- [ ] `LoginScreen` ya no existe y **no queda ninguna pantalla fuera de `presentation/pages/`**.
- [ ] Cero fugas: `PageController` y `passwordController` se liberan; `about_screen` no llama a `setState` desmontado.
- [ ] Con *reduced motion* activo la ruta de entrada es plenamente usable y el splash **no se cuelga**.
- [ ] El maestro §4 y §5.4 corregidos, con la nota fechada.

---

## 18. Deuda declarada

Lo que esta fase **no** arregla, con su razón.

### 18.1 ~50 cadenas sin localizar — la mayor deuda de la fase

`onboarding_screen`, `profile_setup_screen` y `splash_screen` tienen **cero** claves de l10n (§0.6.8). §1.4 prohíbe añadir claves, así que la fase las deja en español literal, y añade unas pocas más (el `tooltip` de editar perfil en la Task 13, los dos del toggle de contraseña en la Task 3, el de la cámara y el de salir en la Task 11).

**Por qué importa más aquí que en las fases 4–6:** estas son las tres primeras pantallas de la aplicación. Un usuario con el sistema en inglés recibe el splash, el onboarding entero y la configuración de perfil **en español**, y la app solo se vuelve bilingüe al llegar al dashboard. Es la peor primera impresión posible para la mitad del público objetivo.

**Coste estimado del trabajo pendiente:** ~50 claves × 2 locales = 100 entradas de ARB, más el cableado. Es una tarea propia, no un paso de otra. **Recomendación fuerte: hacerla inmediatamente después de esta fase**, antes que la Fase 8 (`admin`, usuarios internos, mucho menos tráfico).

### 18.2 Copy de errores sin clave

La Task 2 muestra la URL cruda cuando no se puede abrir un enlace, porque no hay clave de ARB para «no se pudo abrir». Feo y honesto. Se resuelve con 18.1.

### 18.3 Las tres familias tipográficas

La fase elimina los 32 `GoogleFonts` de estos ficheros sustituyéndolos por `AppTextStyles`, pero `AppTextStyles` usa **Inter**; `montserrat` y `montserratAlternates` desaparecen de estas pantallas. Eso es un **cambio visual real** en el logotipo del splash y en los títulos de `profile_setup` y `about`. Es coherente con §2 del maestro («no se cambia la familia tipográfica», es decir: la que hay es Inter y las otras dos eran infracciones), pero **enséñaselo a quien decida sobre la marca antes de mergear**. Si el logotipo debe conservar `montserratAlternates`, la solución correcta es un token nuevo `AppTextStyles.brandDisplay`, no volver a `GoogleFonts` disperso.

### 18.4 `profile_setup` sigue sin `Form`

La Task 11 no envuelve el formulario en un `Form` con `validator` como sí hace la Task 4 con `auth_screen`: el nombre se sigue validando al enviar y el error sigue en un `SnackBar`. Se dejó fuera porque la tarea ya carga con los dos desbordamientos y la accesibilidad del rol, y mezclar tres cosas hace irrevisable el diff. **Es la primera candidata para una tarea de seguimiento**, y es barata: `AppTextField` ya acepta `validator` tras la Task 3.

### 18.5 El sondeo del splash sigue siendo un sondeo

La Task 10 lo acorta de 5 s a 2 s y afina el intervalo, pero sigue siendo un bucle de espera activa sobre `UserProfileProvider`. La solución correcta es que el provider exponga un `Future` o un `Stream` al que suscribirse — y eso **es tocar `providers/`**, prohibido por §1.3. Queda como bloqueo consultable (§19.7).

### 18.6 Los blobs de `profile_setup` solo existen en tema oscuro

[L147](../../../lib/features/profile/presentation/pages/profile_setup_screen.dart#L147): `if (isDarkMode) ...[dos blobs]`. En claro la pantalla no tiene fondo decorativo, a diferencia de `auth` y `splash`. No es un fallo —puede ser deliberado— pero es una inconsistencia visible entre temas que nadie ha decidido explícitamente. No se toca en esta fase.

---

## 19. Bloqueos: decisiones que no son mías

### 19.1 No hay ilustraciones de onboarding

Las tres diapositivas comparten un marcador de posición de un CDN de Google (§0.6.3). `assets/images/` contiene cuatro ficheros y **ninguno** sirve: tres son capturas de pantalla de la app en tema claro y uno es una imagen de vehículo por defecto.

La Task 9 resuelve la parte técnica (degradado de marca + icono distinto por diapositiva, sin red, con `assetPath` opcional ya cableado). **Lo que no puedo decidir es si el producto quiere tres ilustraciones reales** y de qué estilo. Si las quieres: tres imágenes, ~1200 × 900, que funcionen sobre fondo claro **y** oscuro, en `assets/images/onboarding_1..3.png`. Rellenar `assetPath` es entonces una línea por diapositiva.

**Alternativa intermedia si urge:** las tres capturas que ya existen (`dashboard_screen_lightmode.jpg`, `garage_screen_lightmode.jpg`, `workshop-directory_screen_lightmode.jpg`) son **el producto real** y encajan temáticamente con las tres diapositivas. Su problema es que son de tema claro y se verían mal en oscuro. Decisión de producto.

### 19.2 El interruptor de notificaciones de `profile_setup` no persiste nada

`_notificationsEnabled` se muestra, se alterna y **nunca se guarda** (§0.6.6): `UserModel` no tiene ese campo y §1.3 prohíbe tocar `data/`. La pantalla promete una preferencia que la app ignora.

Tres salidas, ninguna mía:

1. **Añadir el campo a `UserModel` y a Firestore.** Es lo correcto, y es trabajo de capa de datos.
2. **Guardarlo en `SharedPreferences`** vía `AuthPreferencesService`, que ya existe y ya se usa desde presentación. Barato, pero deja la preferencia solo en el dispositivo.
3. **Quitar el interruptor** hasta que haya dónde guardarlo. Es lo menos malo de lo inmediato: una preferencia que no hace nada es peor que no ofrecerla.

Mientras no se decida, la Task 11 lo **deja como está** y lo declara aquí. No lo silencies.

### 19.3 `lightSuccess` sigue sin resolverse (heredado de la Fase 6)

La Fase 6 §18.3 dejó abierto que `AppPalette.lightSuccess #48BB78` mide **2,25:1** sobre `lightSurface` y es inutilizable como color de texto en tema claro. Esta fase añade un dato: sobre `lightPrimary` da 4,25:1 (pasa para texto grande) pero sobre `darkPrimary` da **1,65:1** (§0.4).

La Task 10 lo esquiva usando `onPrimary` para el logotipo. **El bloqueo sigue abierto** y afecta a toda la app. Recomendación sin cambios: oscurecer a ~`#2F855A`.

### 19.4 Dependencia dura de la Fase 1 Task 4

`lightTextSecondary #64748B` mide hoy **4,42:1** sobre `lightSurface`. Varias aserciones de esta fase comprueban ≥ 4,5:1 sobre texto que usa ese token — en particular el copyright de `about_screen` (Task 2) y las etiquetas de `AuthBottomNav` (Task 6).

**Si ejecutas la Fase 7 sin la Fase 1, esos tests fallan por 0,08 puntos y el fallo parecerá estar en la pantalla.** No lo está. Ejecuta la Fase 1 primero.

### 19.5 No hay asset del logotipo de Google

La Task 5 elimina la descarga desde `google.com` y propone `assets/logo/google_g.svg`, que **no existe**. La alternativa sin asset (`Icons.g_mobiledata`) funciona y es peor de marca. Las *Google Sign-In Branding Guidelines* exigen el logotipo oficial en el botón, así que la opción correcta es descargarlo una vez y versionarlo. Decisión de quien lleve el cumplimiento de marca.

### 19.6 `AppButton` no tiene variante destructiva

Verificado: `enum AppButtonType { primary, secondary, text }` en [app_button.dart:9](../../../lib/core/widgets/app_button.dart#L9). *Eliminar cuenta* se queda como `TextButton.icon` en `colors.error` (Task 13), fuera del sistema de botones.

Es el **mismo bloqueo que declaró la Fase 6 §18.2**, ahora con un segundo consumidor. Dos fases pidiendo lo mismo es señal suficiente: añadir `AppButtonType.danger` a la Fase 3 es una tarea de media hora que cierra ambos.

### 19.7 La espera del splash necesita un `Future` en el provider

§18.5. Que `UserProfileProvider` exponga `Future<void> get ready` convertiría el bucle de sondeo en un `await`. Es la corrección correcta y toca `providers/`.

---

## 20. Resumen

| # | Tarea | Fichero principal | Steps | Qué cierra |
|---|---|---|---:|---|
| 1 | `entry_harness.dart` | *nuevo* | 7 | Captura múltiple de overflows, locales, splash sin colgarse |
| 2 | `about_screen` | 167 LOC | 6 | 2,61:1 → 4,5:1; 1392 px → 720; `setState` sin `mounted` |
| 3 | `AppTextField` (aditivo) | — | 6 | `enabled`, autofill, *Enter* envía, toggle de contraseña |
| 4 | `auth_screen` — formulario | 789 LOC | 6 | Overflow de 10 px en `en`; checkbox 20 → 48; errores junto al campo |
| 5 | `auth_screen` — layout | 789 LOC | 7 | Dos columnas en `expanded`; barra inferior en flujo; sin `Image.network` |
| 6 | Los 3 widgets de `auth` | 170 LOC | 6 | Targets de 48 dp; enlaces reales; *reduced motion* |
| 7 | `login_screen` | 15 LOC | 6 | Elimina el alias y el test tautológico |
| 8 | `onboarding` — estructura | 449 LOC | 6 | Aserción en horizontal; overflow de 24 px; fuga del `PageController` |
| 9 | `onboarding` — ilustración | 449 LOC | 7 | Panel de 280 px fijo; imagen del CDN; 3 capas de blur → 1 |
| 10 | `splash_screen` | 376 LOC | 7 | 3.000 ms → 400 ms; barra falsa; `"Auto"` a 1,65:1; overflow vertical |
| 11 | `profile_setup_screen` | 842 LOC | 6 | **Los dos overflows en todo ancho de teléfono**; rol accesible |
| 12 | `user_profile` — color | 920 LOC | 6 | 53 literales; 1,00:1 editando en oscuro; 1,19:1 en los switches |
| 13 | `user_profile` — layout | 920 LOC | 7 | **Editar el perfil deja de ser imposible sobre 840 px** |
| 14 | Ratchet + recuento | — | 5 | Cierra el ratchet y verifica los tres invariantes globales |

**14 tareas · 88 steps · 6 pantallas + 3 widgets + 1 componente compartido · 3.728 líneas de presentación auditadas.**

Las correcciones al maestro (§4 y §5.4) ya están aplicadas: se hicieron el 2026-08-12 al escribir este plan.
