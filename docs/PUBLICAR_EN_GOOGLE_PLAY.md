# Publicar AutoDoc en Google Play

Estado del repo a 2026-09-17, verificado contra el árbol. Cada afirmación de la
sección 1 sale de un fichero que se citó al comprobarla.

Esta guía **no repite** `docs/RELEASE_APK.md`, que cubre la keystore y el APK de
GitHub Releases. Aquí está lo que Play exige **además** de eso, y sobre todo las
trampas que el flujo de APK no puede ver porque solo aparecen cuando Play
re-firma el artefacto.

---

## 1. Lo que YA está resuelto (no vuelvas a tocarlo)

| Requisito de Play | Estado | Evidencia |
|---|---|---|
| `applicationId` definitivo | Listo — `com.autodoc.app` | `android/app/build.gradle.kts:63` |
| `targetSdk` ≥ 36 (deadline 31-ago-2026) | Listo — Flutter 3.41 resuelve 36 | `FlutterExtension.kt:34` |
| Firma de release en Gradle | Listo, con fallback avisado | `build.gradle.kts:80-110` |
| Iconos adaptativos | Listo | `flutter_launcher_icons` en `pubspec.yaml:118` |
| Splash | Listo | `flutter_native_splash` en `pubspec.yaml:66` |
| Política de privacidad publicada | Listo | `landing-web/src/app/[locale]/privacy` |
| Términos de servicio publicados | Listo | `landing-web/src/app/[locale]/terms` |
| **Borrado de cuenta desde la app** | Listo | `user_profile_screen.dart:811` → `auth_service.dart:82` |
| CI que firma y verifica el artefacto | Listo | job `release_apk` en `.github/workflows/ci.yml:561` |

El borrado de cuenta merece un párrafo: Play lo exige desde 2024 **dentro de la
app y además por una URL web**, y rechaza fichas que solo lo ofrecen por correo.
La app ya lo tiene en el perfil. Lo que falta es la **URL web pública** de
solicitud de borrado, que es una página en la landing, no código de la app.

---

## 2. Bloqueantes técnicos — trabajo de repo

### 2.0 Dos cosas que estaban rotas y no lo sabía nadie

Las dos salieron de ejecutar `flutter build appbundle`, no de leer código. Es el
argumento de por qué la §1 se verificó ejecutando y no citando.

**(a) El pub cache estaba corrupto: 27 paquetes vacíos.** `firebase_core`,
`firebase_auth`, `cloud_firestore`, `firebase_storage`, `firebase_app_check`,
`printing`, `package_info_plus`, `file_picker` y 19 más estaban en el cache como
**directorios sin un solo fichero**. `pubspec.lock` los resolvía a esas versiones,
así que Flutter los daba por instalados.

El síntoma no apuntaba a la causa ni de lejos:

```
Could not find the firebase_core FlutterFire plugin, have you added it
as a dependency in your pubspec?
```

…con `firebase_core: ^4.7.0` presente en `pubspec.yaml`. `.flutter-plugins-dependencies`
listaba **20 plugins de Android en vez de 28**, y los que faltaban eran justo los
de los directorios vacíos. Flutter no distingue "paquete ausente" de "paquete
presente y vacío".

**Estado: arreglado.** Se retiraron los 27 directorios con `rmdir` —que por
construcción se niega a borrar algo que no esté vacío, así que no pudo llevarse
nada bueno por delante— y `flutter pub get` los volvió a bajar. Verificado: el
cache quedó poblado y los 28 plugins vuelven a detectarse.

Merece saberse porque **ninguna suite lo habría avisado**: `flutter analyze` y
`flutter test` tampoco podían correr, pero nadie los había lanzado desde que el
cache se corrompió. Si vuelve a pasar, el patrón a buscar es un directorio vacío
en `~/AppData/Local/Pub/Cache/hosted/pub.dev/`.

**(b) No hay keystore de release en esta máquina.** `docs/RELEASE_APK.md` y el
propio `android/key.properties` sugieren que sí, y `key.properties` existe — pero
su `storeFile` apunta a:

```
C:/Users/User/AppData/Local/Temp/claude/.../scratchpad/p12.jks
```

…un scratchpad de una sesión anterior, ya borrado. No hay ningún `.jks` ni
`.keystore` en el repo, en `~`, ni en ninguna ruta razonable: solo
`~/.android/debug.keystore`.

Esto **no es opcional y es tuyo, no mío**: la contraseña tiene que ir a tu gestor
de contraseñas y yo no debo conocerla. Es el paso 1 de `docs/RELEASE_APK.md` §B.1
y hay que hacerlo antes de poder subir nada a Play. Si se pierden la keystore o
la contraseña, **no se puede volver a firmar la misma app nunca**: Android
rechaza actualizaciones firmadas con otra clave y no hay recuperación.

### 2.1 Play exige AAB, y el CI produce APK

El job `release_apk` corre `flutter build apk`. Para apps nuevas Play **solo
acepta Android App Bundle** (`.aab`). El APK sigue siendo útil para la demo de
GitHub Releases, así que no se sustituye: se añade.

```bash
flutter build appbundle --release --dart-define-from-file=.env
# -> build/app/outputs/bundle/release/app-release.aab
```

`apksigner` no lee un `.aab`; la verificación anti-debug-keystore del CI hay que
rehacerla con `bundletool` o dejarla solo sobre el APK.

### 2.2 LA TRAMPA: Play App Signing cambia el SHA-1, y Google Sign-In muere

Esto es lo que rompe la primera release de casi todo el mundo, y el flujo de APK
de `RELEASE_APK.md` **no puede detectarlo** porque solo pasa en Play.

Al subir el primer `.aab`, Google Play App Signing **re-firma la app con una
clave que Google guarda**. Tu keystore pasa a ser solo la *upload key*. O sea:

- El SHA-1 que registraste en Firebase = tu keystore = **el que Play descarta**.
- El SHA-1 que tendrán los usuarios de Play = el de Google = **no está en Firebase**.

Consecuencia: la app se instala, arranca, se ve perfecta, y **Google Sign-In
falla con `ApiException: 10` para todos los usuarios de Play** mientras en tu APK
local funciona. Es indistinguible de un bug de código.

**Cómo se cierra** (obligatorio, después de subir el primer bundle):

1. Play Console → Release → Setup → **App signing**.
2. Copia el **SHA-1 del "App signing key certificate"** (el de Google, no el de upload).
3. Firebase Console → Project settings → app Android `com.autodoc.app` → **Add fingerprint**. Pega SHA-1 y SHA-256.
4. Descarga el `google-services.json` nuevo y reemplaza `android/app/google-services.json`. Debe quedar con **tres** `certificate_hash`: debug, upload y Play.
5. Commit, y **vuelve a subir un bundle** con ese json.

Hoy `android/app/google-services.json` tiene **una sola** huella (`9520b261…`,
la debug local). Con esa sola huella la app de Play no inicia sesión.

### 2.3 `versionCode` está en 1 y Play exige uno nuevo cada subida

`pubspec.yaml:19` dice `version: 1.0.0+1`. Play rechaza un bundle cuyo
`versionCode` ya se subió, incluso si lo borraste del borrador. Sube el `+N`
antes de cada subida, o pásale `--build-number` al build desde CI
(`--build-number=${{ github.run_number }}` es lo habitual).

### 2.4 El nombre de la app sale en minúscula

`android/app/src/main/AndroidManifest.xml:10` dice `android:label="autodoc"`.
Ese es el texto bajo el icono en el teléfono. Debería ser `AutoDoc`.

### 2.5 Los permisos sensibles necesitan justificación

El manifest declara tres que Play revisa a mano:

- `ACCESS_FINE_LOCATION` — directorio de talleres / mapa.
- `RECORD_AUDIO` — notas de voz del chat.
- (implícito por `image_picker`) cámara y fotos.

Play pide **prominent disclosure**: un diálogo propio, antes del permiso del
sistema, que explique para qué se usa. Y en el formulario de *Data safety* hay
que declarar ubicación precisa, audio, fotos, correo y datos del vehículo,
diciendo si se comparten con terceros y si se pueden borrar.

Merece comprobarse si la app ya muestra ese diálogo previo; si no, es trabajo de
UI antes de enviar.

---

## 3. Lo que tienes que hacer TÚ (fuera del repo)

Ordenado por dependencia. Los tiempos son de calendario, no de trabajo.

### Paso 1 — Cuenta de desarrollador · 25 USD, pago único · 1-3 días

`play.google.com/console` → crear cuenta. **La elección importa más de lo que
parece:**

| | Cuenta personal | Cuenta de organización |
|---|---|---|
| Verificación | DNI/pasaporte | DUNS + documentos de la empresa |
| Tiempo | horas a 3 días | 1-4 semanas |
| **Closed testing obligatorio** | **Sí: 12 testers, 14 días seguidos** | No |

Si AutoDoc tiene entidad legal detrás, **la cuenta de organización te ahorra las
dos semanas de closed testing**. Es la decisión de más impacto de toda la guía y
no se puede cambiar después.

### Paso 2 — Closed testing, si fuiste por cuenta personal · 14 días mínimo

Google exige, para cuentas personales creadas después del 13-nov-2023: **12
testers que acepten la invitación y sigan inscritos 14 días continuos**. Si uno
se sale, el contador se reinicia. Luego solicitas acceso a producción y Google lo
revisa.

Empieza a juntar los 12 correos **ahora**, en paralelo con todo lo demás. Es el
único paso que no se puede acelerar con trabajo.

### Paso 3 — Assets de la ficha

| Asset | Especificación | Quién lo hace |
|---|---|---|
| Título | ≤ 30 caracteres | tú (decisión de marca) |
| Descripción corta | ≤ 80 caracteres | te propongo, eliges |
| Descripción completa | ≤ 4000 caracteres | la redacto |
| Icono | 512×512 PNG 32-bit, < 1 MB | del `flutter_launcher_icons` ya existente |
| Feature graphic | **1024×500**, JPEG o PNG 24-bit **sin transparencia** | a generar |
| Capturas de teléfono | 2 a 8, entre 320 y 3840 px, ratio entre 16:9 y 9:16 | **§4: Playwright** |
| Vídeo promocional | URL de YouTube, público, sin anuncios | **§5: HyperFrames** |

El feature graphic es el error más común: **cualquier transparencia lo rechaza**,
y en la ficha real se recorta por los lados en móvil — el texto tiene que vivir
en el tercio central.

### Paso 4 — URL pública de borrado de cuenta

Play la pide aparte de la política de privacidad. Una página en la landing
(`/eliminar-cuenta`) que explique qué se borra, en cuánto tiempo, y con un
formulario o un correo. La app ya hace el borrado; falta la puerta web.

### Paso 5 — Declaraciones de "App content" en la consola

Todas obligatorias antes de enviar: política de privacidad (URL), acceso a la app
(credenciales de prueba para el revisor — **dale una cuenta de propietario y una
de taller, si no no puede revisar medio producto**), anuncios, clasificación de
contenido, público objetivo, seguridad de datos, permisos sensibles, cumplimiento
financiero si hay pagos.

### Paso 6 — Secretos de CI

`docs/RELEASE_APK.md` §3 los lista. Siguen sin configurar; hasta que lo estén, el
job se salta en verde y no produce nada.

---

## 4. Plan de capturas con Playwright

### La idea central

**No construyas un harness nuevo.** `e2e/` ya arranca la app compilada contra
emuladores con fixtures sembrados, ya resuelve el arranque de Flutter web y ya
tiene helpers de sesión. Una suite de capturas es un `playwright.capturas.js` que
reutiliza `global-setup.js`, `esperarAppLista()` y los helpers de login.

### Las cuatro trampas, con su arreglo

**1. El bundle de E2E se renderiza en INGLÉS.** Está documentado en `CLAUDE.md`
(INNO-01) y cuesta una tarde si no se sabe: Chromium arranca con el locale del
sistema y Flutter resuelve `AppLocalizations` con `navigator.language`. Lo que lo
esconde es que los rótulos que NO pasan por el ARB ("Garaje", "Talleres") siguen
en español, así que la pantalla parece bilingüe y no rota.

```js
use: {
  locale: 'es-CO',
  launchOptions: { args: ['--lang=es-CO'] },
}
```

Y una aserción de guardia en cada captura: si el rótulo esperado en español no
aparece, falla. Una captura en inglés subida a la ficha es peor que ninguna.

**2. Los fixtures actuales son impresentables.** `seed-emulators.js` siembra
"Propietaria A", "Taller A", placa `E2E-AAA`, `Toyota Corolla`. Eso en una ficha
de tienda dice "software sin terminar". Hace falta un **seed de vitrina**
separado (`seed-vitrina.js`): nombres reales de taller, placas con formato
salvadoreño (`docs/placas-el-salvador.md` ya tiene el formato), historial con
fechas creíbles, reseñas de 4-5 estrellas con texto, fotos reales.

El seed de vitrina es lo que decide si las capturas venden. Es más trabajo que la
suite de Playwright y da más resultado.

**3. Flutter web necesita un clic antes de existir para los selectores.** Ya está
en `CLAUDE.md`: sin `page.mouse.click(10,10)` no se construye el árbol de
semántica y `getByRole` no encuentra nada. Para capturas además hay que dejar
asentar las animaciones — y `pumpAndSettle` no aplica aquí, es
`await page.waitForTimeout(…)` o esperar a un elemento concreto.

**4. El tamaño tiene que ser de teléfono — pero NO el de un teléfono real.**

Ésta es la trampa menos evidente de las cuatro, y cayó en la primera corrida.
Play exige que cada lado esté entre 320 y 3840 px **y que el lado largo no
supere el doble del corto**. Los teléfonos actuales son más altos que 2:1, así
que un viewport "realista" produce capturas que la consola **rechaza**:

| Viewport | @3x | Ratio | Play |
|---|---|---|---|
| 412 × 915 (Pixel moderno) | 1236 × 2745 | 1:2.22 | **rechazada** |
| 360 × 640 | **1080 × 1920** | 1:1.78 | correcta, y es el tamaño recomendado |

```js
viewport: { width: 360, height: 640 },
deviceScaleFactor: 3,   // -> 1080 x 1920, exactamente 9:16
isMobile: true,
hasTouch: true,
```

360 dp de ancho no es un apaño: es el ancho lógico más común de Android, así que
la app tiene que verse bien ahí de todas formas.

**5. Media app no carga sus propios datos, y `goto` la deja vacía.**

`page.goto` recarga la página entera, o sea reinicia la app y vacía los
providers. Y hay pantallas que dependen de que otra las haya llenado:

| Pantalla | ¿Se carga sola? |
|---|---|
| `/service_history/:id` | Sí — `StreamBuilder` propio sobre Firestore |
| `/compartir_historial/:id` | Sí — emite en `initState` |
| `/mechanic_reviews`, `/mechanic_dashboard` | Sí |
| **`/garage`** | **No** — solo lee `vehicleProvider.vehicles` |
| **`/alerts`** | **No** — depende de `vehicleProvider.selectedVehicle` |

El único sitio que llama a `fetchVehicles` al entrar es el dashboard
(`dashboard_screen.dart:54`). Medido: un `goto('/garage')` en frío da «No tienes
vehículos en tu garaje» con tres vehículos sembrados.

La suite lo esquiva entrando una vez por `/dashboard` y navegando **dentro** de
la app (pestañas) para esas dos, y dejando `goto` solo para las autónomas.

> **Esto es además un defecto de producción, no un artefacto del test.**
> Cualquiera que entre a `/garage` por un enlace directo, o que pulse **F5**
> estando ahí, ve el garaje vacío teniendo coches. Es la misma familia que el
> crash de `/task_config` al recargar que levantó H-01. No lo arregla esta
> tanda; queda anotado.

### Las 8 capturas, en orden de ficha

El orden importa: Play muestra las 2-3 primeras en resultados de búsqueda, y esas
deciden la instalación. Van las de más valor percibido primero, no las del flujo
cronológico.

| # | Pantalla | Ruta | Qué vende | Rol |
|---|---|---|---|---|
| 1 | Garaje con 2-3 vehículos | `/garage` | "todos mis carros en un sitio" | propietario |
| 2 | Historial de servicios | `/mechanic_service_history` | el corazón del producto | propietario |
| 3 | **Pase de historial con QR** | pantalla de INNO-01 | el diferenciador, nadie más lo tiene | propietario |
| 4 | Directorio de talleres + mapa | `/workshop_directory` | red real, no app vacía | propietario |
| 5 | Chat con el taller | `/chat/:id` | la relación, no solo el dato | propietario |
| 6 | Alertas (SOAT / revisión) | `/alerts` | "me avisa antes de la multa" | propietario |
| 7 | Panel del mecánico | `/mechanic_dashboard` | el otro lado del mercado | taller |
| 8 | Reseñas del taller | `/mechanic_reviews` | confianza | taller |

Las 3 y 7 son las que diferencian a AutoDoc de un cuaderno de notas. Si solo
hubiera presupuesto para cuatro capturas, serían 1, 2, 3 y 4.

### La foto del vehículo: por qué NO se usan las de SearchAPI

La primera tanda de capturas salió con un **Mercedes-Benz sedán plateado bajo el
rótulo «Toyota Hilux»**. Era `assets/images/default_vehicle.jpg`, el placeholder
que se pinta cuando un vehículo no tiene `foto_url`.

Se arregló sustituyendo ese asset por una **silueta geométrica neutra** (sin
marca, sin modelo, 18 KB frente a los 395 KB del render fotográfico). Eso cierra
además un defecto de producción: cualquier usuario cuya búsqueda de imagen
fallara veía un Mercedes etiquetado como su coche.

**Lo que NO se hizo, a propósito: rellenar `foto_url` con lo que devuelve
SearchAPI.io.** La clave funciona —200, CORS abierto, 100 resultados— pero lo
que devuelve son **fotos de terceros raspadas de Google Imágenes**: en la
consulta de prueba, imágenes de Arnold Clark Leasing servidas desde
`cdn.imagin.studio`. Publicar una captura con una foto comercial ajena en la
ficha de Play es riesgo de retirada por propiedad intelectual, y no es un riesgo
que valga la pena por una foto de coche.

Si quieres fotos reales en las capturas 1 y 6, la vía limpia es sembrar
`foto_url` en `seed-vitrina.js` con **imágenes sobre las que tengas derechos**.
El widget ya acepta rutas `assets/…` además de URLs
(`vehicle_image_widget.dart:30`), así que basta con meterlas en el bundle.

> Nota aparte: que la app rellene el historial de sus usuarios con imágenes
> raspadas de Google es una decisión de producto anterior a esta tanda y con el
> mismo problema de fondo. No se toca aquí, pero conviene mirarla antes de
> crecer.

### Sobre los marcos de dispositivo

Play NO exige marco de teléfono, y las capturas a sangre (sin marco) rinden mejor
en móvil porque la imagen ocupa más. Si se quiere marco + titular encima, eso es
composición posterior: ahí entra la skill `store-screenshots` de la §6, que toma
el PNG crudo de Playwright y le pone marco, fondo de marca y copy.

**Playwright produce el píxel. La composición es un segundo paso.** Separar los
dos permite regenerar los titulares sin volver a levantar emuladores.

### Qué quedó escrito

| Fichero | Qué es |
|---|---|
| `e2e/scripts/seed-vitrina.js` | Fixtures presentables: Sofía Mendoza, Talleres La Ceiba, 3 vehículos con placas SV válidas, 6 servicios, 2 talleres, 2 reseñas con texto |
| `e2e/scripts/global-setup-vitrina.js` | Gemelo de `global-setup.js` que siembra la vitrina en vez de los fixtures de test |
| `e2e/playwright.capturas.config.js` | locale `es-CO` forzado, viewport 412×915 @3x, `workers: 1` |
| `e2e/capturas/helpers.js` | `abrirApp`, `entrarComo`, `comprobarPantalla`, `capturar` |
| `e2e/capturas/propietario.spec.js` | Capturas 1-6 |
| `e2e/capturas/taller.spec.js` | Capturas 7-8 |

```bash
cd e2e
npm run build:web     # solo si el bundle no está compilado (tarda varios minutos)
npm run capturas      # deja los PNG en e2e/capturas/out/
```

Tres decisiones que conviene no deshacer sin leer el motivo, comentado en el
código:

- **Los dos seeds no pueden convivir.** Ambos empiezan borrando Firestore
  entero, así que el último que corre gana. Por eso la vitrina tiene su propio
  `globalSetup` y no se mezcla con `npm test`.
- **Todas las capturas de un rol van en un solo `test`.** Cada arranque de la
  app cuesta caro (CanvasKit + persistencia offline) y degrada el emulador Java;
  partirlas en seis tests hace caer las últimas por timeout.
- **`comprobarPantalla` afirma dos cosas distintas** — que hay un rótulo en
  español y que hay un dato de la vitrina — porque hay dos fallos distintos que
  producen un PNG bonito e inútil: renderizar en inglés, y renderizar una
  pantalla vacía porque falló la siembra.

**Lo que NO está verificado todavía:** los specs no se han ejecutado. Requieren
`npm run build:web` (varios minutos, con `flutter clean` incluido) y los cuatro
emuladores arriba. Los rótulos de las aserciones salen del ARB real
(`lib/l10n/app_es.arb`) y las rutas del router real
(`lib/core/router/app_router.dart`), pero **la primera corrida va a pedir
ajustes** — sobre todo en `/alerts`, que puede exigir seleccionar un vehículo
antes de mostrar nada (`alertsSelectVehicle` existe en el ARB).

---

## 5. Vídeo promocional con HyperFrames

Restricciones que aplican a cualquier concepto:

- Play acepta **solo una URL de YouTube**, pública, sin anuncios ni contenido
  restringido. No se sube un MP4 a la consola.
- Se muestra **antes** de las capturas en la ficha. Es lo primero que se ve.
- Duración que rinde: **30 s**, máximo 2 min. Los primeros 5 s deciden.
- La mayoría lo ve **sin sonido** al principio: los subtítulos no son accesorios.
- Play desaconseja explícitamente mostrar precios, premios o "mejor app de X".

HyperFrames (`/plugin install hyperframes@claude-plugins-official`) renderiza
HTML+CSS+GSAP a MP4 con Chrome headless y FFmpeg, y trae **captura de sitio web a
vídeo**, que encaja directo con este proyecto: la app **ya corre en web** desde
`e2e/` contra emuladores. O sea que el mismo montaje que produce las capturas
puede producir las tomas en movimiento del vídeo, sin grabar una pantalla a mano.

### Concepto elegido: "El carro que cuenta su historia"

La escena es una reventa. Es el momento donde el historial vale dinero de verdad,
y usa el pase QR de INNO-01, que es lo único que ningún competidor tiene.

**Guion a 30 s, montaje híbrido** (capturas reales de la app dentro de marcos de
teléfono animados, con tipografía entre tomas):

| t | Imagen | Texto en pantalla |
|---|---|---|
| 0-4 s | Dos manos, una llave de carro entre ellas. Corte a la pregunta. | «¿Y el historial?» |
| 4-8 s | Carpeta de facturas arrugadas. Silencio visual, plano fijo. | «La respuesta de siempre.» |
| 8-14 s | Vendedor abre AutoDoc → pantalla del pase → QR aparece con la cuenta atrás viva. | «La respuesta de AutoDoc.» |
| 14-21 s | Comprador escanea. El historial se despliega: 6 servicios, con el sello de taller verificado y el auto-declarado marcado distinto. | «Seis servicios. Verificados por el taller.» |
| 21-26 s | Contraplano: la cuenta atrás del pase llegando a cero. | «Caduca solo. Tú decides cuándo.» |
| 26-30 s | Logo + llamada a la acción. | «AutoDoc — el historial que viaja con tu carro.» |

Tres decisiones del guion que no son estéticas:

- **La distinción verificado / auto-declarado se ve en pantalla**, en el segundo
  14-21. Es la funcionalidad entera: si un vendedor puede escribirse el historial
  y sale igual de respaldado, el QR no prueba nada. Enseñarlo es lo que hace
  creíble todo lo demás.
- **La caducidad ocupa cinco segundos**, que es mucho en un vídeo de treinta. Es
  lo que separa "compartir el historial" de "regalar tus datos", y es la objeción
  que un vendedor real pone.
- **Ningún plano necesita audio para entenderse.** La mayoría lo verá en mudo.

**Lo que hay que resolver antes de rodar:**

1. **Las tomas de la app salen de la suite de capturas**, no de una grabación a
   mano: mismo seed de vitrina, mismo locale forzado, pero con `video: 'on'` o con
   la captura de sitio web de HyperFrames sobre `http://localhost:5555`.
2. **La cuenta atrás del pase es real y corre**, así que el plano del segundo 21-26
   se puede grabar de verdad en vez de animarlo — pero hay que emitir el pase con
   una caducidad corta para no esperar.
3. **Play desaconseja precios, premios y superlativos.** El guion no los usa; al
   ajustar el copy, que siga sin usarlos.
4. **Sube el MP4 a YouTube como público** (no "no listado": Play exige público) y
   pega la URL en la ficha.

---

## 6. Orden recomendado

Decisión tomada: **cuenta personal**. Eso mete los 14 días de closed testing en
el camino crítico, así que el carril A manda y el B se ajusta a él.

```
CARRIL A (calendario — manda)          CARRIL B (trabajo)
---------------------------------      --------------------------------
0. >>> GENERAR LA KEYSTORE <<<         1. Fix: android:label     [hecho]
   (tuyo: la contraseña es tuya)       2. Fix: appbundle en CI   [hecho]
1. Crear cuenta Play (25 USD)          3. Fix: versionCode       [hecho]
2. Reclutar 12 testers  ← empieza YA   4. seed-vitrina.js        [hecho]
3. Subir primer AAB a internal         5. Suite de capturas      [sin correr]
4. >>> Registrar SHA-1 de Play         6. Feature graphic + icono
    en Firebase <<<                    7. Copy de la ficha
5. Closed testing, 14 días seguidos    8. Página /eliminar-cuenta
6. Solicitar acceso a producción       9. Vídeo
7. Enviar a revisión
```

Dos pasos de A bloquean todo lo demás y merecen leerse dos veces:

**A0 — la keystore.** Sin ella no hay AAB que subir. Está medido: el build llega
entero hasta `:app:validateSigningRelease` y muere ahí. Es tuyo porque la
contraseña tiene que vivir en tu gestor de contraseñas, no en una transcripción.

**A4 — el SHA-1 de Play en Firebase.** Depende de A3 y, si se salta, el closed
testing **no mide nada**: los 12 testers instalan la app y ninguno puede iniciar
sesión, así que los 14 días se gastan sobre una app rota y hay que repetirlos.

Y **A2 empieza hoy**, en paralelo con todo: reclutar 12 personas que acepten y no
se salgan en dos semanas es el único paso que no se acelera trabajando más.
