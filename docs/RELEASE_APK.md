# Publicar el APK de AutoDoc en GitHub

## El problema que hay que entender primero

Firebase identifica a la app Android por **package name + huella SHA-1 del
certificado que la firmó**. Hoy `android/app/google-services.json` tiene
registrada **una sola huella**:

```
9520b26195264f6d2dd7178eb2c9708a31b131a2
```

Esa es la *debug keystore local* de este equipo (`~/.android/debug.keystore`).

Consecuencia práctica: un APK firmado con cualquier otra clave se instala y
arranca sin problemas, pero **Google Sign-In falla** con
`ApiException: 10 (DEVELOPER_ERROR)`. El fallo no aparece hasta que alguien
pulsa "Iniciar sesión con Google", así que es fácil repartir un APK roto
creyendo que está bien.

GitHub Actions genera una debug keystore **nueva y distinta en cada ejecución**.
Por eso el CI no puede usar la clave de debug: necesita una keystore de release
propia y estable, cuyo SHA-1 se registra una vez en Firebase.

---

## Opción A — APK local, ahora mismo (para una demo)

Funciona sin configurar nada, porque usa la debug keystore de este equipo, que
ya está registrada en Firebase.

```bash
flutter build apk --release --dart-define-from-file=.env
```

> **Si falla con `IllegalArgumentException: 25.0.2`** (o cualquier otra versión
> suelta como mensaje de error): Flutter está usando el JDK que trae Android
> Studio, y el compilador de Kotlin de Gradle no sabe parsear Java 25. `gradlew`
> por su cuenta funciona porque usa `JAVA_HOME`. Apunta Flutter al JDK 21:
>
> ```bash
> flutter config --jdk-dir "C:\Program Files\Microsoft\jdk-21.0.12.8-hotspot"
> ```
>
> Es config local de la máquina, no del repo — por eso no se versiona. El CI no
> se ve afectado: usa `actions/setup-java` con Java 21.

El resultado queda en `build/app/outputs/flutter-apk/app-release.apk`.

Subirlo a GitHub como release:

```bash
gh release create v1.0.0+1 \
  build/app/outputs/flutter-apk/app-release.apk \
  --title "AutoDoc 1.0.0+1" --notes "APK de demo"
```

**Limitación real:** solo funciona desde este equipo. Si se pierde
`~/.android/debug.keystore`, nadie más puede producir un APK que inicie sesión.
No sirve para Play Store.

---

## ¿Se puede aplazar la firma de release?

**Sí, para la demo.** El APK firmado con la keystore de debug funciona entero
—login con Google y mapa incluidos— porque su SHA-1 está registrado en Firebase.
Esa keystore es válida hasta **2056**, y el job de CI se salta solo mientras no
haya secretos, así que no deja el pipeline en rojo.

**El coste real de aplazarlo es uno, y conviene entenderlo antes de repartir el
APK:** Android ata la identidad de la app a su clave de firma. Si distribuyes
este APK firmado con la debug y luego cambias a una keystore de release,
**quien lo tenga instalado tendrá que desinstalarlo** — la actualización se
rechaza por firma distinta. No hay forma de evitarlo.

O sea:

| Escenario | ¿Aplazable? |
|---|---|
| Demo donde cada uno se descarga el APK del momento | Sí, sin problema |
| Gente que se queda la app y espera actualizaciones | Hazlo antes de repartirlo |
| Publicar en Google Play | No: Play rechaza un APK firmado con la debug |

Y un detalle de riesgo: la keystore de debug es **local a esta máquina y única**.
Si se pierde el equipo, nadie más puede producir un APK que inicie sesión.

Generar la keystore es un comando de treinta segundos. El coste de hacerlo ahora
es mucho menor que el de cambiar de clave después.

---

## Opción B — APK firmado y publicado por CI (lo correcto)

El job `release_apk` de `.github/workflows/ci.yml` ya está escrito. Falta darle
la keystore. Cuatro pasos, una sola vez.

### 1. Generar la keystore de release

**En PowerShell**, en una sola línea. El `\` de continuación es sintaxis de bash;
en PowerShell da error — es el fallo más común aquí:

```powershell
keytool -genkeypair -v -keystore "$HOME\autodoc-release.jks" -alias autodoc -keyalg RSA -keysize 2048 -validity 10000 -storetype PKCS12 -dname "CN=AutoDoc, O=AutoDoc, L=San Salvador, C=SV"
```

Con `-dname` solo pregunta la contraseña. Sin él, keytool encadena preguntas de
nombre y organización y acaba con **"¿Es correcto? [no]:"**, que en un JDK en
español espera `sí` — escribir `yes` deja el diálogo dando vueltas.

`PKCS12` es el formato estándar; con `JKS` keytool suelta un aviso de formato
propietario en cada uso. La extensión `.jks` se mantiene sin más motivo que
`.gitignore`, que ignora `*.jks`. Gradle firma igual con los dos: verificado.

Cuando pida `Enter keystore password`, escríbela y repítela. **No se ve nada
mientras tecleas**; es normal.

Queda en `C:\Users\<tu-usuario>\autodoc-release.jks`, **fuera del repo** a
propósito.

> Guarda el archivo y la contraseña en un gestor de contraseñas. Si se pierden no
> se puede volver a firmar la misma app: Android rechaza actualizaciones firmadas
> con otra clave, y no hay recuperación.

Para compilar en local con esa firma, crea `android/key.properties`:

```properties
storeFile=C:/Users/<tu-usuario>/autodoc-release.jks
storePassword=<la que pusiste>
keyAlias=autodoc
keyPassword=<la misma>
```

En PKCS12 la contraseña del almacén y la de la clave son la misma; por eso
`storePassword` y `keyPassword` van con el mismo valor.

**Barras normales, no invertidas.** Un `.properties` de Java trata la barra
invertida como carácter de escape, así que una ruta con `\` se corrompe al leerla.

`.gitignore` ya bloquea `*.jks`, `*.keystore` y `android/key.properties`.

### 2. Registrar su SHA-1 en Firebase

```powershell
keytool -list -v -keystore "$HOME\autodoc-release.jks" -alias autodoc | Select-String "SHA1:|SHA256:"
```

Firebase Console → Project settings → tu app Android (`com.autodoc.app`) →
**Add fingerprint** → pega el SHA-1 *y* el SHA-256.

Después **descarga el `google-services.json` actualizado** y reemplaza
`android/app/google-services.json`. Debe pasar a tener dos `certificate_hash`
(la de debug y la nueva de release). Commitea ese archivo.

Sin este paso el APK del CI se instala pero no deja iniciar sesión.

### 3. Configurar los secretos en GitHub

**Dónde:** en el repo → pestaña **Settings** → menú lateral **Secrets and
variables** → **Actions** → botón verde **New repository secret**. Nombre y
valor, y *Add secret*. Una vez guardado no se puede volver a leer, solo
reemplazar.

Sirven los *Repository secrets* aunque el job declare `environment: production`:
los de repositorio los ve cualquier job; los de Environment solo sirven para
sobreescribir uno concreto.

#### Los que hay que crear

Primero, los dos valores en base64. En PowerShell, desde la raíz del repo — cada
comando copia el resultado al portapapeles, listo para pegar:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("$HOME\autodoc-release.jks")) | Set-Clipboard
```

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("android\app\google-services.json")) | Set-Clipboard
```

Salen en **una sola línea, sin saltos**, que es justo lo que el workflow espera.

| Secreto | Valor |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | el primer comando |
| `ANDROID_KEYSTORE_PASSWORD` | la contraseña de la keystore |
| `ANDROID_KEY_PASSWORD` | la misma (en PKCS12 son una sola) |
| `ANDROID_KEY_ALIAS` | `autodoc` |
| `GOOGLE_SERVICES_JSON_BASE64` | el segundo comando |
| `GOOGLE_MAPS_API_KEY_ANDROID` | la key **Android** de `.env` |

#### Los que hay que actualizar

Ya existen, pero con valores viejos. Cópialos de `.env`:

| Secreto | Por qué cambió |
|---|---|
| `FIREBASE_APP_ID_ANDROID` | app nueva en Firebase → appId nuevo |
| `FIREBASE_ANDROID_API_KEY` | la app nueva trae su propia API key |
| `GOOGLE_MAPS_API_KEY` | la anterior **está muerta**; pon la key **Browser** |
| `VEHICLE_IMAGE_API_KEY` | sigue siendo SearchAPI.io; sácala de searchapi.io |

#### Los que ya están bien

`FIREBASE_PROJECT_ID`, `FIREBASE_AUTH_DOMAIN`, `FIREBASE_STORAGE_BUCKET`,
`FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_DATABASE_URL`, `RECAPTCHA_SITE_KEY`.
No los toques.

`GITHUB_TOKEN` no se configura: lo inyecta Actions solo.

> **Mientras falten los de firma, el job no falla: se salta.** El primer paso
> comprueba `ANDROID_KEYSTORE_BASE64` y `GOOGLE_SERVICES_JSON_BASE64`; si no
> están, deja el job en verde con un aviso y no construye nada. Así aplazar la
> firma no deja el pipeline en rojo permanente.

### 4. Push a `main`

El pipeline queda así:

```
analyze_and_test ─┐
rules_tests       ├─> deploy_production ─> release_apk
build_web_smoke  ─┘                        (APK + GitHub Release)
```

`release_apk` va **después** del deploy a propósito: el tag `vX.Y.Z+N` ya existe
cuando se crea la release, y un fallo firmando el APK nunca puede tumbar el
despliegue de producción.

El job verifica con `apksigner` que el APK **no** quedó firmado con la clave de
debug antes de publicarlo, y adjunta el `.apk` a la release del tag. Si la
release ya existe, reemplaza el adjunto (`--clobber`), así que es idempotente.

---

## `applicationId`

Ya es `com.autodoc.app` en el repo. Los registros externos que faltan (Firebase,
restricciones de la API key de Google Cloud) están en
[MIGRACION_APP_ID.md](MIGRACION_APP_ID.md). **Hazlos antes que nada de esta
guía**: hasta que no bajes el `google-services.json` nuevo, el build de Android
ni siquiera compila.
