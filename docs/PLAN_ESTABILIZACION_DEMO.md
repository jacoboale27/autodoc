# Plan de estabilización pre-presentación — AutoDoc

Fecha: 2026-08-26 · Rama: `main`

## Estado

| Bloque | Estado |
|---|---|
| A — reglas Firestore/Storage (§1.1, §1.4, §1.5) | ✅ hecho, verificado y **desplegado** |
| B — lógica de roles (§1.2, §1.3) | ✅ hecho y verificado |
| C — UI (§2.1, §2.2, §2.3) | ✅ hecho y verificado |
| D — web/hosting (§5.1, §5.2, §4.1) | ✅ hecho y verificado |
| §3.1 tema claro/oscuro | ✅ causa encontrada y arreglada |
| §5.2 búsqueda de imágenes | ✅ causa REAL encontrada y arreglada (ver §5.2) |
| §3.2 audio | ✅ cerrado — el usuario confirma que ya se envía sin error |
| §6.1 borrar mensaje del chat | ✅ causa encontrada y arreglada |
| §6.2 galería: "usuario no autorizado" | ✅ era §1.5 — reglas ya desplegadas, pendiente de probar en vivo |
| §4.3 deploy de Cloud Functions en CI | ✅ causa encontrada y arreglada |

**Reglas ya desplegadas en producción** (confirmado por el usuario el 2026-08-26), así
que el alta de mecánico, el servicio manual, la galería y la búsqueda de imágenes deberían
funcionar ya en la app real; falta la comprobación manual en vivo.

Verificación al cierre del Bloque B: `flutter analyze` limpio · **689/689** tests de
Flutter · **175/175** tests de reglas.

Objetivo: eliminar los errores y funcionalidades rotas que puedan aparecer durante la
demo. Cada punto lleva **causa raíz verificada en código** (o marcada explícitamente
como *no confirmada*), archivo/línea, y el arreglo propuesto.

---

## 0. Decisión previa que condiciona todo el plan

**¿La demo es en web (Chrome), en Android, o en ambos?**

No es una pregunta de estilo: cambia qué se arregla y en qué orden.

- Si es **web**: el audio de chat *no existe* (está oculto a propósito, ver §9), y
  aparece un bloqueador que no estaba en tu lista: **Google Sign-In está roto** (§10).
- Si es **Android**: §10 y §5 (duplicados solo-web) dejan de aplicar, y el audio pasa a
  ser un bug real a depurar con logs.

El resto (reglas de Firestore/Storage, roles, tema, notas, alertas) aplica en ambos.

---

## Bloque 1 — Bloqueadores duros (rompen el flujo en vivo)

### 1.1 Crear mecánicos: bucle infinito en `setup_profile` ✅ causa confirmada

**Causa raíz** — [firestore.rules:127](../firestore.rules#L127):

```
allow create: if isOwner(userId) && request.resource.data.rol == 'Propietario'
```

Al elegir rol *Mecanico*, `UserService.createUserData` es rechazado con
`permission-denied` → [`UserProfileProvider.updateProfile`](../lib/core/providers/user_profile_provider.dart)
devuelve `false` → [profile_setup_screen.dart:806](../lib/features/profile/presentation/pages/profile_setup_screen.dart#L806)
lanza y se queda en la misma pantalla. `userData` sigue `null`, así que
[app_router.dart:230-236](../lib/core/router/app_router.dart#L230) vuelve a mandar a
`/profile_setup`. Ese es el bucle.

**Complicación**: `UserModel.estado` tiene default `'activo'`
([user_model.dart:64](../lib/core/models/user_model.dart#L64)) y
`estadosMecanicoAprobado = {'aprobado','activo'}`
([app_router.dart:100](../lib/core/router/app_router.dart#L100)). Si solo se abre la
regla, todo mecánico nuevo entra **ya aprobado**, saltándose al administrador.

**Arreglo (3 cambios coordinados):**

1. `profile_setup_screen.dart` — al seleccionar *Mecanico*, construir el `UserModel` con
   `estado: 'pendiente'`; tras guardar, navegar a `/mechanic_pending` en lugar de
   `/mechanic_dashboard` ([línea 799-804](../lib/features/profile/presentation/pages/profile_setup_screen.dart#L799)).
2. `firestore.rules` — permitir el create de rol `'Mecanico'` **solo** con
   `estado == 'pendiente'`, manteniendo el resto de candados ya existentes
   (`id_taller_propietario` prohibido, métricas en cero):

   ```
   allow create: if isOwner(userId)
     && !('id_taller_propietario' in request.resource.data)
     && (!('calificacion_promedio' in request.resource.data) || request.resource.data.calificacion_promedio == 0)
     && (!('total_resenias' in request.resource.data) || request.resource.data.total_resenias == 0)
     && (
          (request.resource.data.rol == 'Propietario'
             && (!('estado' in request.resource.data) || request.resource.data.estado == 'activo'))
          || (request.resource.data.rol == 'Mecanico'
             && request.resource.data.estado == 'pendiente')
        );
   ```

   Sigue siendo imposible autoaprobarse: `estado` está excluido del `allow update` del
   propio usuario ([firestore.rules:155](../firestore.rules#L155)).
3. Test de regresión en `test_rules/usuarios.test.js`: mecánico con `pendiente` → OK;
   mecánico con `activo`/`aprobado` → denegado; `Administrador` → denegado.

**Pantalla de espera**: ya existe y está cableada —
[`mechanic_pending_screen.dart`](../lib/features/mechanic/presentation/pages/mechanic_pending_screen.dart)
y [app_router.dart:243-245](../lib/core/router/app_router.dart#L243). Solo hay que
revisar el copy y que el botón "ya me aprobaron" refresque bien. **No hay que crearla.**

---

### 1.2 Estados de aprobación: "aprobado" sale en rojo y con botón de aprobar ✅ confirmada

Hay **dos vocabularios** de estado conviviendo:

| Acción | Escribe | Archivo |
|---|---|---|
| `aprobarUsuario` | `'activo'` | [admin_service.dart:74](../lib/features/admin/data/services/admin_service.dart#L74) |
| `aprobarTaller` | `'aprobado'` | [admin_service.dart:142](../lib/features/admin/data/services/admin_service.dart#L142) |
| `reactivarTaller` | `'aprobado'` | [admin_service.dart:189](../lib/features/admin/data/services/admin_service.dart#L189) |

Y la UI solo reconoce uno:

- [account_row.dart:66,74](../lib/features/admin/presentation/widgets/account_row.dart#L66)
  → verde **solo** si `estado == 'activo'`; `'aprobado'` cae al `else` rojo.
- [account_row.dart:95](../lib/features/admin/presentation/widgets/account_row.dart#L95)
  → muestra "Aprobar" si `estado != 'activo' && estado != 'suspendido'`, así que a un
  `'aprobado'` le sigue ofreciendo aprobar.
- [mecanico_admin_card.dart:22](../lib/features/admin/presentation/widgets/mecanico_admin_card.dart#L22)
  → mismo sesgo.

**Arreglo**: un único helper de estado (p. ej. `lib/core/utils/estado_cuenta.dart`) que
exponga `esAprobado(estado)` (reutilizando `estadosMecanicoAprobado`), `esPendiente`,
`esSuspendido`, más color y etiqueta. Sustituir los tres sitios. Semáforo:
**amarillo = pendiente**, **verde = activo/aprobado**, **rojo = suspendido/rechazado**.
"Aprobar" solo visible si `esPendiente`.

---

### 1.3 Mecánico aprobado que aterriza en pantallas de propietario ⚠️ pendiente de confirmar

[`_normalizeRole`](../lib/core/router/app_router.dart#L113) mapea a `mechanic` **solo**
`'mecanico'` y `'taller'`; cualquier otro valor cae al `default: 'owner'`. Un rol
guardado como `'Mecánico'` (con tilde) o el que escriba `cambiarRolUsuario` desde el
panel admin haría exactamente lo que describes.

Además [main_scaffold.dart:35](../lib/core/widgets/main_scaffold.dart#L35) usa una
comparación **exacta** distinta (`rol == 'Mecanico'`), y `role_utils.dart` una tercera.
Tres criterios de rol en el repo.

**Acción**: (a) leer en Firestore el valor real de `rol` de la cuenta que falla; (b)
unificar los tres criterios en `role_utils.dart` normalizando acentos y mayúsculas; (c)
restringir a un enum el desplegable de "cambiar rol" del admin.

---

### 1.4 Completar servicio manual: `permission-denied` ✅ causa confirmada

**Causa raíz** — [firestore.rules:297](../firestore.rules#L297): el `create` de
`servicios` solo lo permite `isAdmin()` o `isMecanico()`. Pero
[`AlertProvider.userCompleteTask`](../lib/features/dashboard/presentation/providers/alert_provider.dart#L391)
lo ejecuta el **propietario**, con `id_taller: 'Manual (Propietario)'`.

**Sobre tu pregunta de las imágenes — sí se están guardando, y ese es el problema.**
La factura se sube a Storage en
[alert_provider.dart:379-387](../lib/features/dashboard/presentation/providers/alert_provider.dart#L379),
en `facturas/{vehicleId}/...`, ruta que `storage.rules` **sí** autoriza al propietario.
El `add()` de Firestore falla *después*. Resultado: el archivo queda **huérfano** en
Storage y `foto_factura_url` nunca se persiste en ningún documento.

**Arreglo:**

1. `firestore.rules` — añadir la rama del propietario al `create` de `servicios`:

   ```
   || (isVehicleOwner(request.resource.data.id_vehiculo)
        && request.resource.data.id_taller == 'Manual (Propietario)')
   ```

   Es seguro: el trigger `requestReviewOnServiceComplete` ya ignora los `id_taller` que
   contienen `'Manual'` ([functions/index.js:256](../functions/index.js#L256)), así que
   no puede otorgar `talleres_vinculados`.
2. `alert_provider.dart` — mover la subida a Storage **después** del `add()` exitoso, o
   borrar el blob en el `catch`, para no dejar huérfanos.
3. Sacar el bloque de `if (task != null)`: hoy, si la tarea no está en la lista local, el
   servicio **no se registra en absoluto** y aun así se muestra "Servicio validado ✓".
4. Test en `test_rules/servicios.test.js`.

---

### 1.5 Galería de fotos del vehículo: no sube ✅ causa confirmada (dos fallos apilados)

1. **Storage** — `VehiclePhotoService.addPhoto` sube a
   `vehiculos/{id}/fotos/{uuid}.jpg`
   ([vehicle_photo_service.dart:50](../lib/features/dashboard/data/services/vehicle_photo_service.dart#L50)),
   pero la regla es `match /vehiculos/{vehicleId}/{fileName}`
   ([storage.rules](../storage.rules)) y `{fileName}` es un comodín de **un solo
   segmento**. `fotos/{uuid}.jpg` son dos → ninguna regla matchea → denegado.
   **Fix**: `match /vehiculos/{vehicleId}/{allPaths=**}`.
2. **Firestore** — no existe `match /vehiculos/{vehiculoId}/fotos/{fotoId}` en
   `firestore.rules` (ver la lista de `match` del archivo). Las reglas **no se heredan**
   de la colección padre, así que fallan tanto el `set()` como el `streamPhotos()`.
   **Fix**: añadir el `match` anidado — lectura para quien ya puede leer el vehículo,
   escritura/borrado solo para `id_propietario`.
3. **UX** — [vehicle_gallery_widget.dart:53](../lib/features/dashboard/presentation/widgets/vehicle_gallery_widget.dart#L53)
   hace `await photoService.addPhoto(...)` sin `try/catch`: la excepción se pierde y el
   snackbar "Subiendo foto..." se queda colgado sin decir nada. Envolver, mostrar error, y
   confirmar el éxito.

---

## Bloque 2 — Fallos visibles pero no bloqueantes

### 2.1 Flechas de desplazamiento en "Alertas activas" ✅ HECHO

[dashboard_screen.dart:839](../lib/features/dashboard/presentation/pages/dashboard_screen.dart#L839)
es un `SingleChildScrollView(scrollDirection: Axis.horizontal)` sin controlador. En
desktop la rueda del ratón scrollea en vertical, así que no hay forma de moverlo.

**Arreglo**: `ScrollController` + botones `‹` / `›` que hagan `animateTo` un ancho de
tarjeta (las tarjetas ya están acotadas a `minWidth 150 / maxWidth 220`,
[línea 891](../lib/features/dashboard/presentation/pages/dashboard_screen.dart#L891)),
ocultando cada flecha cuando se llega al extremo. Añadir `Scrollbar` y soportar
`Shift+rueda`. Mostrar las flechas solo en punteros (no táctil).

**Hecho**: nuevo [`AppHorizontalScroller`](../lib/core/widgets/app_horizontal_scroller.dart).
Al implementarlo salieron **tres** causas apiladas, no una:

1. La rueda emite delta vertical y `Scrollable` solo consume la componente del eje que
   coincide con su dirección — para un scroll horizontal lee `scrollDelta.dx`, que en una
   rueda normal es siempre `0`.
2. `ScrollBehavior.dragDevices` excluye `PointerDeviceKind.mouse`, así que tampoco se
   podía arrastrar con el cursor.
3. `MaterialScrollBehavior.buildScrollbar` devuelve el hijo sin tocar en el eje
   horizontal: no había ni barra que arrastrar.

Con un dedo las tres desaparecen, y por eso solo se veía en desktop. El widget añade las
tres piezas. Las flechas se dibujan a partir de `expanded` y solo cuando queda recorrido
hacia ese lado. 7 tests en
[`app_horizontal_scroller_test.dart`](../test/core/widgets/app_horizontal_scroller_test.dart).

### 2.2 Quitar perfil y notificaciones duplicados del dashboard (solo web) ✅ HECHO

[dashboard_screen.dart:264-266](../lib/features/dashboard/presentation/pages/dashboard_screen.dart#L264)
pinta `NotificationBellButton` + avatar. En `WindowClass.large` el
[`AppTopNavBar`](../lib/core/widgets/app_top_nav_bar.dart) ya ofrece ambos.

**Arreglo**: envolver ese `Row` en `if (AppBreakpoints.of(context) != WindowClass.large)`.
Así móvil y tablet conservan sus accesos (donde la barra superior no existe) y solo
desaparece el duplicado en la vista ancha de escritorio.

**Hecho**: el `Row` lleva `Key('dashboard-header-acciones')` y se dibuja solo si
`!windowClass.isLarge`. La condición es la clase de ventana y **no `kIsWeb`** a propósito:
lo que decide si sobran no es la plataforma sino si el shell ya los está pintando, y eso
pasa exactamente en `large`. En compact el shell usa `AppBottomNav` y en medium/expanded
`AppNavRail`, y **ninguno de los dos incluye notificaciones ni perfil**: ahí son la única
vía de acceso. 2 tests en `dashboard_screen_layout_test.dart`.

### 2.3 Notas del vehículo demasiado estiradas ✅ HECHO

[`_buildNotesSection`](../lib/features/dashboard/presentation/pages/vehicle_profile_screen.dart#L469)
apila una `AppCard` a ancho completo por nota dentro de un `Column`, sin límite.

**Arreglo**: rejilla responsive (`Wrap` o el `AppGrid` que ya existe) — 1 columna en
compacto, 2-3 en expanded/large; acotar la altura de la sección con scroll interno a
partir de N notas; reducir el padding vertical de la tarjeta. Mantener el `Dismissible`.

**Hecho**: `LayoutBuilder` + `Wrap` (1 / 2 / 3 columnas), decidido por
`constraints.maxWidth` y no por `MediaQuery`, porque la sección puede vivir en un panel
más estrecho que la ventana.

`Wrap` y **no** el `AppGrid` existente: `AppGrid` es un `GridView.count` con
`childAspectRatio` fijo, así que impone la misma altura a todas las celdas — la nota de
una palabra dejaría un hueco enorme y la larga desbordaría. Hay un test que lo fija
(la nota larga debe medir más que la corta).

**Además, un fallo que no estaba reportado y sí es un crash**: `onDismissed` esperaba al
round-trip de Firestore antes de que la nota saliera de la lista, pero
`VehicleProvider.fetchVehicles` arranca con `_setLoading(true) → notifyListeners()`. Ese
rebuild intermedio remonta la nota ya descartada y `Dismissible` lanza *"A dismissed
Dismissible widget is still part of the tree"*. Se arregla con un set de notas en vuelo
(`_notasEliminandose`) que las saca de la lista al instante y las devuelve si el borrado
falla, con snackbar.

---

## Bloque 3 — Requieren reproducción antes de tocar código

Estos dos los revisé a fondo y **el cableado está bien**. No voy a "arreglar a ciegas":
necesito el síntoma exacto.

### 3.1 Cambio de tema claro/oscuro ⚠️ sin causa confirmada

Lo que verifiqué y **está correcto**:

- [main.dart:350-352](../lib/main.dart#L350) — `themeMode`/`theme`/`darkTheme` bien atados
  a `ThemeProvider` vía `context.watch`.
- [`ThemeProvider`](../lib/core/providers/theme_provider.dart) — `notifyListeners()` antes
  del `await` de `SharedPreferences`; sin carreras.
- `AppTheme.light` y `AppTheme.dark` tienen paletas realmente distintas
  (`#F7F6F8` vs `#0F172A`) y **ambos** registran la extensión `AppColors`.
- Cero usos de `AppPalette.light*` fuera de `app_theme.dart`.
- Ningún `MaterialApp` anidado que pise el tema.

**Qué necesito**: ¿desde qué pantalla lo cambias — barra superior, perfil de usuario,
dashboard de admin, o mecánico? ¿No pasa nada en absoluto, o cambia y se revierte solo?
Hay tres interruptores distintos y el de la barra superior **solo existe en
`WindowClass.large`**. Con eso lo cierro rápido.

### 3.2 Notas de voz ⚠️ depende de la plataforma

- En **web** el botón está **oculto a propósito**:
  [chat_screen.dart:572](../lib/features/chat/presentation/pages/chat_screen.dart#L572)
  `if (!kIsWeb)`, porque `record` no devuelve un `File` real en navegador. Si tu prueba
  fue en Chrome, "no se envía" es en realidad "no está". Implementar la grabación web es
  un trabajo aparte, no un arreglo.
- En **Android** todo lo comprobable cuadra: `RECORD_AUDIO` declarado en el manifiesto,
  la ruta `chat_audios/{convId}/{file}` coincide con `storage.rules`, y el
  `contentType: 'audio/mp4'` pasa `esAudioValido()`.

**Qué necesito**: el texto del error y el `logcat`/consola. Ahora mismo
[`subirAudioChat`](../lib/features/chat/presentation/providers/chat_provider.dart#L327)
se traga la excepción y la UI solo dice "No se pudo enviar la nota de voz" — hay que
loguear `e` para saber si es App Check, tamaño, o reglas.

---

## Bloque 4 — Hosting

### 4.1 La landing ✅ HECHO — y la causa de fondo estaba en el CI

Lo que verifiqué antes sigue en pie: producción responde 200 y su contenido coincide con
`landing-web/out/`. Pero eso era porque **alguien la había desplegado a mano**. El
pipeline no la estaba publicando bien, por dos motivos independientes:

**a) El CI nunca construía la landing.** `landing-web/out/` está en `.gitignore`, así que
en una VM limpia no existe. El job de producción hacía `pnpm install --frozen-lockfile`
y habilitaba `webframeworks`, pasos heredados de cuando el target usaba
`"source": "landing-web"` (hosting consciente de frameworks). Desde `332a384` el target
sirve `"public": "landing-web/out"`, un export estático — y **nadie lo construía**. El
deploy publicaba un directorio vacío.

**Arreglo**: `pnpm build` en el job, más un guard `test -s landing-web/out/es.html` que
rompe el pipeline antes de publicar una landing en blanco. Verificado en local: el build
genera `es.html`, `en.html` y `contact/privacy/terms` en ambos idiomas.

**b) El deploy de staging fallaba entero.** `firebase.json` declara dos targets de hosting
pero `.firebaserc` solo mapea `landing` para `autodoc-6ef5a`. Un
`firebase deploy --only hosting` contra staging aborta con *"Hosting target landing not
configured for autodoc-staging"* y se lleva por delante también el target `app`.

**Arreglo**: staging despliega `--only hosting:app`. No añado el target `landing` a
staging porque no me consta que ese sitio exista, y apuntar a un sitio inexistente falla
igual.

**c) La raíz `/` redirigía por JavaScript.** `landing-web/src/app/page.tsx` hace
`router.replace('/es')` en un `useEffect`: el visitante veía "Redirigiendo…" y una
hidratación completa de Next solo para rebotar.

**Arreglo**: `redirects` en `firebase.json` (`/` → `/es`, 302). En Firebase Hosting los
redirects se evalúan **antes** que los archivos estáticos, así que gana sobre
`out/index.html`. Dejo `page.tsx` a propósito como red de seguridad: si algún día la
landing se mueve a otro host sin configurar redirects, la raíz sigue funcionando en vez
de dar 404.

### 4.2 ¿Cambiar a Vercel o a un VPS?

Respuesta directa: **no antes de la presentación.**

- El hosting actual funciona (medido arriba). Migrar el día antes cambia un riesgo
  conocido y nulo por uno desconocido: DNS, certificados, propagación.
- **Vercel** sí es mejor encaje *a futuro* para `landing-web`: es Next.js nativo, te
  quita el `output: "export"` y recuperas el middleware de `next-intl` (que es la forma
  correcta de resolver `/` → `/es`, justo el punto 4.1). Migración realista: ~30 min.
  Merece la pena **después** de la demo.
- **VPS para la app Flutter**: no aporta nada. `build/web` son archivos estáticos; un VPS
  te da CDN peor, HTTPS manual y mantenimiento, y perderías la integración con Firebase
  Auth/Firestore/Storage que ya está en el mismo proyecto. **Recomiendo no hacerlo.**

Propuesta: dejar Firebase Hosting para la demo, aplicar el 4.1 (10 minutos), y evaluar
Vercel para la landing la semana siguiente.

---

### 4.3 El deploy de producción nunca ha desplegado las Cloud Functions ✅ HECHO

**Síntoma**: el job *Deploy to Production* falla en el paso *Deploy Cloud Functions to
Production* con `Error: An unexpected error has occurred.` y `exit code 2`.

**Causa raíz**: `firebase deploy --only functions` carga `functions/index.js` **en el
runner** para descubrir qué exports hay que desplegar. `functions/node_modules` está en
`.gitignore:69` y el workflow nunca ejecutaba `npm ci` dentro de `functions/`, así que
`require('firebase-functions')` (`functions/index.js:1`) falla con `Cannot find module`.
firebase-tools se traga ese `MODULE_NOT_FOUND` y lo reporta como el inútil "An unexpected
error has occurred.". La única pista real estaba una línea antes, y solo como warning:
`Couldn't find firebase-functions package in your source code. Have you run 'npm install'?`

firebase-tools **no** instala las dependencias por ti en local. Cloud Build sí las instala,
pero del lado del servidor y solo después de que el descubrimiento haya funcionado.

**No es una regresión**: `git log -p -- .github/workflows/ci.yml` no contiene ni un solo
`working-directory: functions` en toda la historia del archivo. Este paso no ha funcionado
nunca; las Cloud Functions de producción se han desplegado a mano.

**Efecto colateral que explica la otra mitad de §4.1**: este paso está *antes* del build de
la landing y del deploy de hosting. Al reventar aquí, el pipeline **nunca llegaba a
desplegar hosting**, ni el smoke test, ni el tag de versión.

**Arreglo**: paso `Install Cloud Functions dependencies` (`npm ci` con
`working-directory: functions`) justo antes del deploy, en `deploy_production` **y** en
`deploy_staging` — staging arrastraba el mismo defecto, solo que nunca llegó a ejecutarse.
Lleva un guard `node -e "require.resolve('firebase-functions')"` para que un fallo futuro
diga qué pasa en vez de "unexpected error".

**Verificación**:

- *Reproducido*: copiando `index.js` + `src/` a un directorio sin `node_modules`,
  `node -e "require('./index.js')"` → `Cannot find module 'firebase-functions'`, exit 1.
- *Arreglado*: con las dependencias instaladas y `FIREBASE_CONFIG`/`GCLOUD_PROJECT` puestos
  como los pone firebase-tools, el mismo require descubre **22 exports**
  (`checkAlertsDaily` … `publishTallerProfile`).
- `npm ci --dry-run` en `functions/`: lockfile en sync con `package.json`.
- `ci.yml` sigue siendo YAML válido; el paso queda inmediatamente antes del deploy de
  functions en ambos jobs.

**Pendiente, no bloqueante hoy**: el propio log avisa de que el runtime **Node.js 20 se
decomisiona el 2026-10-30**. Hoy (2026-08-26) todavía despliega, pero pasada esa fecha
`functions/package.json` (`engines.node: "20"`) dejará de poder desplegarse. Migrar a
Node 22 después de la demo.

---

## Bloque 5 — Encontrado durante la auditoría, no estaba en tu lista

### 5.1 Google Sign-In en web ✅ CORREGIDO EL DIAGNÓSTICO — no estaba roto

**Me equivoqué al calificar esto de bloqueador.** Al ir a arreglarlo leí
[auth_service.dart:22](../lib/features/auth/data/services/auth_service.dart#L22) y el
camino web no usa el paquete `google_sign_in`:

```dart
if (kIsWeb) {
  final GoogleAuthProvider authProvider = GoogleAuthProvider();
  return await _auth.signInWithPopup(authProvider);   // <- popup de FirebaseAuth
}
```

`signInWithPopup` resuelve su cliente OAuth desde la configuración del proyecto en la
consola de Firebase y **nunca lee el meta `google-signin-client_id`**. El placeholder era
inerte para el login. "Continuar con Google" en web no dependía de esto.

Quedaban dos defectos reales, ambos menores:

1. El literal `$GOOGLE_SIGNIN_CLIENT_ID_WEB` se servía al navegador tal cual, porque
   `flutter build web` solo sustituye la base href de ese archivo. **Arreglado**: client ID
   real (`client_type: 3` = Web, el mismo que ya está commiteado en
   `android/app/google-services.json`; un client ID de OAuth es público, no un secreto).
2. `signOut()` llamaba a `_googleSignIn.signOut()` también en web, lo que arrancaba el SDK
   de Google Identity Services con ese client ID basura en cada cierre de sesión. Estaba
   dentro de un `catch (_) {}`, así que no rompía nada, solo trabajo inútil.
   **Arreglado**: guardado con `if (!kIsWeb)`.

Guard de regresión en
[`web_index_html_test.dart`](../test/web_index_html_test.dart): falla si vuelve a aparecer
un `$PLACEHOLDER` que Flutter no sustituye.

### 5.2 Búsqueda de imágenes ✅ RESUELTO — la causa no era ninguna de las tres hipótesis

**Corrección al diagnóstico inicial.** Descartada la hipótesis del `--dart-define`
(el usuario arranca con `--dart-define-from-file=.env`, así que la key sí llega) y
descartada la de CORS (el fallo se ve también en Android). La causa real es otra:

`VehicleProvider.addVehicle` pide la imagen **antes** de escribir el vehículo, y
`getVehicleImage` empieza con un `get()` sobre `vehiculos/{id}` como atajo de caché.
Ese documento todavía no existe — y leer un documento inexistente de `/vehiculos` **no
devolvía "no existe"**: la regla evaluaba `resource.data.id_propietario` sobre un
`resource` nulo, lo que es un error de evaluación y por tanto `PERMISSION_DENIED`.

Verificado en el emulador: `evaluation error at L250 for 'get', Null value error`.

Esa excepción caía en el `catch` exterior de `getVehicleImage`, que devuelve
`_defaultImage`. **La llamada a SearchAPI nunca llegaba a ejecutarse.** Por eso en
Firestore el vehículo nuevo aparecía con `assets/images/default_vehicle.jpg`, con toda
la pinta de "la búsqueda no encontró nada".

Arreglado en tres sitios:
1. `firestore.rules` — rama `resource == null` en el `allow read` de `vehiculos`, con
   tres tests (incluido uno que verifica que leer un vehículo **ajeno que sí existe**
   sigue denegado).
2. `vehicle_image_service.dart` — el atajo de caché pasa a ser *best-effort* con su
   propio `try/catch`: si falla, se busca igualmente en vez de rendirse.
3. `vehicle_image_service.dart` — aviso explícito en consola si `VEHICLE_IMAGE_API_KEY`
   llega vacía, que era indistinguible de "no hay resultados".

Queda pendiente (no bloquea la demo): `getVehicleImage` solo se llama al crear el
vehículo, así que los vehículos creados **antes** de este arreglo siguen con el
placeholder. Hace falta un botón "buscar imagen" en el perfil, o borrarlos y recrearlos.

---

### 5.2-bis Notas del diagnóstico original (obsoletas, se conservan por trazabilidad)

Probé tu key de `.env` contra SearchAPI.io: **HTTP 200, 100 resultados**, con la
estructura `original.link` que el parser de
[vehicle_image_service.dart:118](../lib/core/services/vehicle_image_service.dart#L118)
espera. La API responde con `access-control-allow-origin: *`. **El servicio no está
caído y el código lo parsea bien.**

Tres causas candidatas, por probabilidad:

1. **La key no llega al binario.** `AppSecrets.vehicleImageApiKey` usa
   `String.fromEnvironment`, que se resuelve en **tiempo de compilación**. Si arrancas
   con `flutter run` / `flutter build web` sin `--dart-define-from-file=.env`, vale `''`
   → 401 → placeholder, en silencio. El `README.md:223` documenta el build **sin** los
   dart-define; el `launch.json` de VS Code sí los pasa. *Comprobar primero.*
2. **Solo se busca al crear el vehículo.** `getVehicleImage` se llama únicamente desde
   [`VehicleProvider.addVehicle`](../lib/features/dashboard/presentation/providers/vehicle_provider.dart#L166).
   Los vehículos ya existentes sin `foto_url` no se reintentan nunca. Si tu demo usa un
   vehículo creado antes, no habrá imagen jamás.
3. **CORS del host de destino en web.** La URL final apunta a servidores de terceros
   arbitrarios. Probé dos y ambos mandan `Access-Control-Allow-Origin: *`, pero no está
   garantizado para todos; los que no, caen al `errorWidget` de
   [`VehicleImageWidget`](../lib/core/widgets/vehicle_image_widget.dart).

**Arreglo por fases**: (1) verificar los dart-define y añadir un log/aviso si la key está
vacía; (2) botón "buscar imagen" en el perfil del vehículo para los ya creados; (3) *a
futuro*, rehospedar la imagen en Firebase Storage vía Cloud Function — elimina el
problema de CORS de raíz y hace la imagen permanente.

---

## Bloque 6 — Reportado tras probar los bloques A y B

### 6.1 "Borrar mensaje solo lo pone en gris y no sé si lo borra" ✅ HECHO

Sí lo borraba. `ChatRepository.deleteMensaje`
([chat_repository.dart:218](../lib/features/chat/data/repositories/chat_repository.dart#L218))
es un borrado suave: marca `is_deleted` y sustituye `contenido`. Las reglas lo permiten
(`allow update` para ambos participantes, `firestore.rules:505`), así que la escritura
pasa.

El problema es que lo que se borra no se nota, por tres motivos apilados:

1. **El contenido seguía a la vista.** `_buildMessageContent` decidía solo por `msg.tipo`,
   y el borrado suave no toca `tipo` ni `url_archivo`. Borrar una **imagen** seguía
   pintando la foto; borrar un **audio** seguía ofreciendo el reproductor. Lo único que
   cambiaba era el fondo de la burbuja. Este es el fallo de verdad.
2. **Solo se atenuaba el mensaje propio.** `ChatBubble` aplicaba el gris únicamente si
   `isMe`, así que al receptor le llegaba un "Este mensaje ha sido eliminado" con el mismo
   aspecto que cualquier otro.
3. **Un fallo era invisible.** `ChatProvider.deleteMensaje` devolvía `void` y se tragaba
   la excepción en `_error`, que nadie lee.

**Arreglo**: corte por `msg.isDeleted` antes del `switch` (icono + texto en cursiva sea
cual sea el tipo); `surfaceVariant` + contorno en ambos lados; `deleteMensaje` devuelve
`bool` y la pantalla muestra snackbar si falla. 4 tests en
[`chat_screen_deleted_message_test.dart`](../test/features/chat/presentation/pages/chat_screen_deleted_message_test.dart).

### 6.2 Galería: "el usuario no está autorizado para hacer la acción deseada" ⚠️ falta desplegar

Es exactamente §1.5, y el mensaje confirma el diagnóstico: es el `storage/unauthorized`
de Firebase Storage, el wildcard de un solo segmento contra la ruta de dos de la galería.
El arreglo está en `storage.rules` + `firestore.rules` y pasa sus tests en el emulador,
pero **producción sigue con las reglas antiguas** (último commit de reglas: 3 ago 2026).

Que ahora salga un error en vez de quedarse colgado en "Subiendo foto..." es el arreglo
de §1.5 funcionando: antes la excepción se perdía.

**No hay nada más que programar aquí. Falta un despliegue:**

```
firebase deploy --only firestore:rules,storage --project <produccion>
```

### 6.3 Notas de voz ✅ cerrado

El usuario confirma que graba y envía sin error. La sospecha de App Check /
Play Integrity queda descartada. Nota de valor para el futuro: los 9 tests de
`chat_audios` **nunca se habían ejecutado** — la suite de Storage moría en el timeout de
5 s del hook `beforeAll`. Ahora corren y pasan.

---

## Orden de ejecución propuesto

**Bloque A — reglas y backend** (un solo `firebase deploy`, un solo ciclo de test)
1. §1.1 create de mecánico con `pendiente`
2. §1.4 create de servicio manual por el propietario
3. §1.5 galería: `{allPaths=**}` en Storage + `match` de `fotos` en Firestore
4. Tests en `test_rules/` para los tres · desplegar reglas

**Bloque B — lógica de roles**
5. §1.1 (cliente) navegación a `/mechanic_pending` + `estado: 'pendiente'`
6. §1.2 helper único de estado + semáforo en las 3 vistas de admin
7. §1.3 unificar `_normalizeRole` / `isMechanicRole` / `MainScaffold`

**Bloque C — UI** ✅
8. ✅ §2.2 quitar duplicados (solo `WindowClass.large`)
9. ✅ §2.1 flechas en alertas
10. ✅ §2.3 rejilla de notas (+ crash del `Dismissible`)
10-bis. ✅ §6.1 borrado de mensaje del chat

**Bloque D — web/hosting**
11. §5.1 Google Sign-In ← *hacer pronto, es el primer clic de la demo*
12. §5.2 verificar dart-define de la key de imágenes
13. §4.1 redirect de `/` a nivel de hosting

**Bloque E — con tu input**
14. ✅ §3.1 tema
15. ✅ §3.2 audio — confirmado funcionando

**Bloque F — solo tú puedes hacerlo**
16. 🔴 `firebase deploy --only firestore:rules,storage` — **nada del bloque A está activo
    hasta que esto se ejecute**. Es lo que bloquea §1.1, §1.4, §1.5/§6.2 y §5.2.

**Verificación final**: `flutter analyze` · `flutter test` · `npm test` en `test_rules/` ·
recorrido manual de los 5 flujos de la demo en la plataforma real.
