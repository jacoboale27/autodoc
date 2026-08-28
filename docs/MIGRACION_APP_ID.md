# Migración de `com.example.autodoc` → `com.autodoc.app`

## Estado: el renombrado está completo

Firebase tiene `com.autodoc.app` registrada **con huella SHA-1**, y el
`google-services.json` del repo lo refleja:

| package | app_id | OAuth Android | SHA-1 |
|---|---|---|---|
| `com.autodoc.app` | `1:702895874700:android:1dbffa73…` | sí (`client_type: 1`) | `9520b261…31b131a2` (debug) |

Falta añadir el SHA-1 **y el SHA-256** de la keystore de release cuando la
generes, y volver a descargar el JSON.

---

## Ya hecho en el repo

- `applicationId` y `namespace` → `com.autodoc.app`; `MainActivity.kt` movido a
  `android/app/src/main/kotlin/com/autodoc/app/`.
- Bundle iOS/macOS/Linux renombrado (`project.pbxproj`, `AppInfo.xcconfig`,
  `CMakeLists.txt`).
- `google-services.json` y `GoogleService-Info.plist` nuevos instalados.
  El plist anterior apuntaba a **otro proyecto Firebase** (`autodoc-654a0`,
  sender `248252592371`); el nuevo ya apunta a `autodoc-6ef5a`.
- `appId`, API keys y client ID de iOS propagados a `.env`, `app.env` y
  `firebase.json`, que además ya tiene la entrada `platforms.ios` que le faltaba.
- Esquema de URL de Google Sign-In (`REVERSED_CLIENT_ID`) añadido a
  `ios/Runner/Info.plist`. Sin él, el login en iOS abre Safari y no vuelve.
- El SHA-1 ya **no está hardcodeado** en Dart: `AppSecrets.androidCertSha1` llega
  por `--dart-define`, y el workflow lo deriva de la propia keystore con
  `keytool`, así que no puede desincronizarse de la firma real.

---

## Queda por hacer

### 1. Google Cloud: restringir las API keys

La key que usaba el proyecto para Maps y Translation
(`AIzaSyBp0xI7P-…`) **era la key autogenerada de Firebase para la app
`com.example.autodoc`**. Al borrar esa app, la key murió:

```
HTTP 400 — "API key expired. Please renew the API key."
```

Ya está sustituida en `.env` y `app.env` por la key de Android nueva
(`AIzaSyBZwi1Nh6…`), verificada contra Translation API (HTTP 200) y contra
Maps JavaScript API (sin error).

**Lo que queda: restringirlas.** Las tres keys que crea Firebase nacen
*abiertas* — comprobado: responden 200 sin cabecera `X-Android-*` y sin
`Referer`. Una key sin restringir incrustada en un APK público es cuota de
terceros facturada a tu proyecto.

Console → APIs & Services → Credentials:

| Key | Restricción | Valor |
|---|---|---|
| Android `AIzaSyBZwi1Nh6…` | Android apps | `com.autodoc.app` + SHA-1 **debug** y **release** |
| Browser `AIzaSyDjcLVHFY…` | HTTP referrers | dominios de Hosting (`autodoc-6ef5a.web.app/*`, etc.) |
| iOS `AIzaSyDlK23lv1…` | iOS apps | `com.autodoc.app` |

En cuanto las restrinjas, **la misma key deja de servir para web y Android**. Por
eso el job del APK usa `GOOGLE_MAPS_API_KEY_ANDROID` si existe, y cae a
`GOOGLE_MAPS_API_KEY` (la de web) si no. Configura ese secreto con la key de
Android antes de restringir nada.

### 2. Fotos de vehículos: se descartó Custom Search, siguen en SearchAPI.io

Se intentó migrar de SearchAPI.io a la Custom Search JSON API de Google y **se
revirtió**. Google rechaza el proyecto:

```
HTTP 403 — "This project does not have the access to Custom Search JSON API."
```

No es la key, ni el `cx`, ni que la API esté apagada. Las pruebas hechas:

| Prueba | Resultado | Qué descarta |
|---|---|---|
| Las 3 keys del proyecto (Android/Browser/iOS) | mismo 403 | no es la key ni sus restricciones |
| Key inventada | 400 `API key not valid` | la key es válida y reconocida |
| `cx` con un carácter cambiado | 400 `invalid argument` | el `cx` existe y pasa validación |
| Búsqueda web sin `searchType=image` | mismo 403 | no es la configuración del motor |
| YouTube Data v3, **API deshabilitada en el mismo proyecto** | `accessNotConfigured`, nombrando el proyecto 702895874700 | **así se ve un "API apagada", y no es lo que devuelve Custom Search** |
| Página de métricas de `customsearch.googleapis.com` | muestra tráfico con errores 403 | la API está habilitada y las peticiones llegan |

Conclusión: la API está habilitada, la petición pasa la puerta de enlace, y
quien rechaza el proyecto es el backend de Custom Search. Facturación tampoco
es — el proyecto despliega Cloud Functions, así que está en plan Blaze. Un
sondeo de 24 minutos siguió en 403, así que tampoco era propagación.

> Si algún día se quiere retomar: como la key de búsqueda es un secreto
> independiente (`VEHICLE_IMAGE_API_KEY` / `GOOGLE_CUSTOM_SEARCH_API_KEY`) y no
> la lee `firebase_options.dart` ni `google-services.json`, puede salir de
> **cualquier** proyecto de Google Cloud. Crear un proyecto nuevo a mano,
> habilitar ahí *Custom Search API* y generar una key aislaría si el bloqueo es
> de `autodoc-6ef5a` en concreto o de la cuenta.

**Estado actual:** `VehicleImageService` usa SearchAPI.io (engine
`google_images`), con `VEHICLE_IMAGE_API_KEY`. Sácala del panel de
[searchapi.io](https://www.searchapi.io/) y ponla en `.env`, `app.env` y en el
secreto de GitHub del mismo nombre.

### 3. Secretos de GitHub

Cambiaron al crear apps nuevas — actualiza los valores desde `.env`:

- `FIREBASE_APP_ID_ANDROID` ← nuevo
- `FIREBASE_ANDROID_API_KEY` ← **nuevo también** (la app nueva trae su propia key)
- `GOOGLE_MAPS_API_KEY` ← la vieja está **muerta**; pon aquí la key **Browser**
  (`AIzaSyDjcLVHFY…`), que es la que usan los builds de web
- `GOOGLE_MAPS_API_KEY_ANDROID` ← nuevo: la key **Android** (`AIzaSyBZwi1Nh6…`),
  que usa el job del APK

Y los que no existen aún: los cuatro de firma (`ANDROID_KEYSTORE_BASE64`,
`ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_PASSWORD`, `ANDROID_KEY_ALIAS`) más
`GOOGLE_SERVICES_JSON_BASE64` — `android/app/google-services.json` está en
`.gitignore`, así que el runner no lo tiene y el plugin de Google Services aborta
el build sin él. Detalle en [RELEASE_APK.md](RELEASE_APK.md).

### 4. Limpieza (opcional, al final)

Borra la app `com.example.autodoc` de Firebase cuando todo funcione. No pierdes
datos: Firestore, Auth y Storage son del *proyecto*, no de la *app*. Solo se
reinicia el histórico de Analytics y Crashlytics.

---

## Comprobación final

- [x] `google-services.json` tiene `client_type: 1` para `com.autodoc.app`
- [x] El APK de release compila en local, con `package: com.autodoc.app`, firma
      `9520b261…` (la registrada) y la key de Maps viva en el manifest
- [ ] `flutter run` en un Android real: **login con Google**, mapa visible, textos traducidos
- [ ] Push a `main` → `release_apk` publica la release con el APK adjunto
- [ ] Instalar **ese APK** y repetir login + mapa — es lo único que prueba la firma de release

## Notas

- **App Check** usa `AndroidPlayIntegrityProvider` ([main.dart:122](../lib/main.dart#L122)),
  ligado al package, así que la app nueva hay que registrarla también ahí.
  Mantén el enforcement en **monitorización** hasta después de la demo: un APK
  descargado de GitHub no viene de Play y Play Integrity puede rechazarlo. El
  código tolera el fallo (try/catch), pero con enforcement activo sería Firebase
  quien rechazara las peticiones.
- iOS quedó **configurado pero sin verificar**: no se puede compilar ni probar
  desde Windows. Un IPA en CI necesitaría cuenta Apple Developer, runner macOS y
  certificados; fuera de alcance para esta semana.
- `linux/` y `macos/` se renombraron por coherencia. No están conectados a ningún
  proyecto Firebase.
