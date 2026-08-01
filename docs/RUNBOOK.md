# AutoDoc — Runbook de Producción

> **Versión:** 1.0 | **Última actualización:** 2026-07 | **Propietario:** Equipo AutoDoc

Este documento cubre los procedimientos operacionales para mantener AutoDoc en producción.

---

## ⚠️ Acciones manuales pendientes (requieren consola/facturación)

La acción de creación de proyecto es parte de la Tarea 16 del plan de
corrección de hallazgos críticos
(`.superpowers/sdd/2026-07-29-correccion-hallazgos-criticos/task-16-brief.md`,
Step 1), pero **ningún agente puede ejecutarla**: requiere autenticación real
contra Google Cloud/Firebase y permisos de facturación en la organización.
Debe ejecutarla una persona con esas credenciales.

> Nota: el Step 6 del mismo brief pedía rotar la clave de Google Maps
> `***REMOVED-GOOGLE-MAPS-API-KEY***` por sospecha de exposición en el
> historial de git. El propietario del proyecto verificó directamente en
> Google Cloud Console que esa clave **no está expuesta**, así que esta
> acción se descarta — no requiere rotación.

### Pendiente 1 — Crear el proyecto de staging (Step 1 del brief)

```bash
firebase projects:create autodoc-staging --display-name "AutoDoc Staging"
firebase use --add
```

Seleccionar `autodoc-staging` y asignarle el alias `staging`. Requiere
permisos de facturación en la organización.

**Mientras este paso no se ejecute**, el alias `staging` declarado en
`.firebaserc` (ver `## Entornos` más abajo) apunta a un proyecto Firebase que
todavía no existe, así que **cualquier despliegue a staging (job
`deploy_staging` en `.github/workflows/ci.yml`) fallará**. Esto es el
comportamiento esperado hasta que se complete este paso — no es un defecto de
la configuración añadida en la Tarea 16.

**Falta también el target de hosting `landing` para staging.** `firebase.json`
declara dos configuraciones de hosting, `app` y `landing` (target `landing`,
`source: landing-web`), pero `.firebaserc` solo define el target `hosting.app`
para `autodoc-staging` — no existe un target `landing` en staging. En cuanto
`autodoc-staging` exista, ejecutar antes del primer `firebase deploy --only
hosting --project staging`:

```bash
firebase target:apply hosting landing <landing-site-id> --project autodoc-staging
```

donde `<landing-site-id>` es el sitio de Firebase Hosting que se cree para la
landing de staging (Firebase Console → Hosting → Add another site, dentro del
proyecto `autodoc-staging`). Sin este paso, `firebase deploy --only hosting
--project staging` fallará con `Error: Hosting target landing not
configured` — no es una regresión de esta tarea; staging no tenía ningún
target de hosting configurado antes de la Tarea 16.

### Pendiente 2 — Esquema de nombres de secretos en GitHub (fix wave Fase E)

`.github/workflows/ci.yml` usa dos esquemas de nombres de secretos distintos
que **no** son inconsistentes por accidente, sino que dependen de si el
secreto está atado a un GitHub **Environment** o es un secreto de
**repositorio**:

- Los jobs `deploy_staging` y `deploy_production` declaran
  `environment: staging` y `environment: production` respectivamente
  (`.github/workflows/ci.yml`, ver la línea `environment:` dentro de cada
  job). Esto significa que un secreto de **Environment** con el mismo
  nombre (p. ej. `FIREBASE_WEB_API_KEY`) resuelve a un **valor distinto**
  según el job que lo consulte — sin necesidad de sufijos como `_STAGING`/
  `_PROD` en el nombre.
- `FIREBASE_PROJECT_STAGING` y `FIREBASE_PROJECT_PROD` (usados en los pasos
  `firebase deploy --project ...` de `deploy_staging`/`deploy_production`)
  son nombres heredados de antes de que existiera el patrón de Environments:
  como cada entorno necesita un id de proyecto distinto en el mismo paso de
  despliegue, se optó por sufijar el nombre en vez de depender de
  Environments. Son secretos de **repositorio** (un solo par nombre/valor,
  visible en ambos jobs), y eso es intencional para estos dos secretos en
  particular.

**Regla para configurar cada secreto nuevo en GitHub (Settings):**

| Secreto | Dónde configurarlo |
|---|---|
| `FIREBASE_WEB_API_KEY`, `FIREBASE_APP_ID_WEB`, `FIREBASE_MEASUREMENT_ID`, `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_PROJECT_ID`, `FIREBASE_AUTH_DOMAIN`, `FIREBASE_STORAGE_BUCKET`, `GOOGLE_MAPS_API_KEY`, `VEHICLE_IMAGE_API_KEY`, `GOOGLE_CUSTOM_SEARCH_API_KEY`, `GOOGLE_CUSTOM_SEARCH_CX`, `RECAPTCHA_SITE_KEY`, `GOOGLE_SIGNIN_CLIENT_ID_WEB` | **Ambos niveles a la vez**, no uno u otro: (1) **Settings → Environments → `staging`** y **Settings → Environments → `production`** por separado, mismo nombre, **valor distinto** en cada uno — esto es lo que consumen `deploy_staging`/`deploy_production`. (2) **También** en Settings → Secrets and variables → Actions (nivel repositorio), con un valor razonable (p. ej. el de staging, o un valor de desarrollo) — este nivel es el único que puede ver `build_web_smoke` (ver la limitación de abajo: ese job no declara `environment:`), y sus guardias `[ -z ... ]; exit 1` (`ci.yml:118-147`) hacen fallar el job en cada PR si el secreto de repositorio no existe. GitHub resuelve el secreto de **Environment** con prioridad sobre el de **repositorio** para los jobs que sí declaran ese entorno, así que tener también un valor a nivel de repositorio **no** hace que `deploy_staging`/`deploy_production` usen el valor equivocado — el de Environment siempre gana ahí. |
| `FIREBASE_PROJECT_STAGING`, `FIREBASE_PROJECT_PROD`, `FIREBASE_TOKEN` | Settings → Secrets and variables → Actions (nivel repositorio) — nombres ya sufijados por entorno o de uso compartido; no requieren Environments. |

**Limitación conocida — el job `build_web_smoke` NO declara `environment:`.**
A diferencia de `deploy_staging`/`deploy_production`, el job
`build_web_smoke` (`.github/workflows/ci.yml`, jobs `build_web_smoke:`) no
tiene una línea `environment:`, así que **nunca** puede resolver secretos de
Environment bajo ninguna configuración — solo ve secretos de nivel
repositorio. Por eso la tabla de arriba exige configurar los 13 secretos
también a nivel de repositorio: sin ese fallback, `build_web_smoke` fallaría
en cada PR por las guardias `[ -z ... ]` del paso "Inject web runtime
config" (`ci.yml:118-147`). En la práctica esto es aceptable porque ese job
solo hace un build de humo con `FLAVOR=dev` y no despliega nada, pero si en
el futuro se necesita que `dev` tenga su propia configuración de Firebase
distinta de la de repositorio, habría que añadir `environment: dev` (u otro
nombre) a ese job. No se modifica en este fix wave — es una decisión que
afecta el comportamiento de aprobación/protección del job y debe tomarla
una persona con acceso real a la configuración de GitHub del repositorio,
no un agente.

---

## Entornos

| Alias | Proyecto Firebase | Uso | Datos |
|---|---|---|---|
| `staging` | `autodoc-staging` | Desarrollo y QA. **Alias por defecto.** | Sintéticos, desechables |
| `production` | `autodoc-6ef5a` | Producción | Reales. Nunca para pruebas |

Reglas de operación:
- `firebase deploy` sin `--project` va a **staging** por diseño.
- Toda regla de Firestore o Storage se despliega **primero** en staging, donde
  CI la valida con `test_rules/`, y solo después en producción.
- Desarrollo local: `firebase emulators:start`. Nunca apuntar a `production`.
- Los datos de prueba presentes hoy en producción («wowow», «Mecánico 1»,
  «Gola», placa «128») deben migrarse a staging y eliminarse de producción.

> **Nota:** el alias `staging` en `.firebaserc` apunta a `autodoc-staging`,
> que aún no existe hasta que se complete el "Pendiente 1" de arriba.

---

## 1. Acceso a herramientas de operación

| Herramienta | URL / Comando |
|-------------|---------------|
| Firebase Console | https://console.firebase.google.com/project/[PROJECT_ID] |
| Google Cloud Console | https://console.cloud.google.com/project/[PROJECT_ID] |
| Crashlytics Dashboard | Firebase Console → Crashlytics |
| Cloud Functions Logs | `firebase functions:log --project [PROJECT_ID]` |
| GitHub Actions CI | https://github.com/[ORG]/autodoc/actions |

> **Nota:** Reemplaza `[PROJECT_ID]` y `[ORG]` con los valores reales del proyecto.

---

## 2. Rotación de credenciales admin

### 2.1 Cambiar contraseña de admin
1. Ir a Firebase Console → Authentication → Users
2. Buscar el usuario admin por email
3. Hacer click en los 3 puntos → "Reset password"
4. El admin recibe email con link para cambiar contraseña

### 2.2 Rotar service account (CI/CD)
```bash
# 1. Crear nuevo service account key
gcloud iam service-accounts keys create new-key.json \
  --iam-account firebase-adminsdk@[PROJECT_ID].iam.gserviceaccount.com

# 2. Actualizar secret en GitHub
gh secret set FIREBASE_TOKEN --body "$(cat new-key.json)"

# 3. Eliminar key antigua del IAM Console
# Firebase Console → Project Settings → Service accounts → Manage service account permissions
```

### 2.3 Rotar FCM API Key
1. Firebase Console → Project Settings → Cloud Messaging
2. Generar nueva Server Key
3. Actualizar variable de entorno en Cloud Functions (si aplica)

---

## 3. Suspender usuario

### Via panel admin (recomendado)
1. Login como Administrador en la app
2. Ir a Admin → Usuarios
3. Encontrar el usuario → "Suspender" → ingresar motivo
4. El sistema registra en `admin_logs` y actualiza `estado: suspendido`

### Via Firebase Console (emergencia)
```bash
# Deshabilitar cuenta en Firebase Auth
firebase auth:export users.json --project [PROJECT_ID]
# Luego en Firebase Console → Authentication → Users → Disable user
```

---

## 4. Suspender taller

### Via panel admin
1. Admin → Talleres
2. Encontrar el taller → "Suspender"
3. Esto actualiza el campo `estado` en la colección `usuarios` del mecánico
4. El mecánico ve la pantalla `MechanicPendingScreen` al intentar acceder

### Efecto en producción
- El mecánico es redirigido a `/mechanic_pending` por el router
- No puede iniciar servicios ni acceder al dashboard
- Los clientes no ven el taller en el directorio si `estado != 'activo'`

---

## 5. Respuesta a incidente de seguridad

### Nivel P0 — Brecha de datos activa

**Tiempo de respuesta objetivo: < 30 minutos**

```
1. AISLAR
   - Firebase Console → Authentication → "Disable all new user registrations" (Settings)
   - Si hay function comprometida: firebase functions:delete [functionName]
   
2. IDENTIFICAR
   - Revisar admin_logs en Firestore para actividad sospechosa
   - Revisar Cloud Functions logs: firebase functions:log
   - Revisar Firebase Auth activity log en Google Cloud Console
   
3. CONTENER  
   - Cambiar service account keys (ver §2.2)
   - Revocar todos los tokens FCM si es necesario
   - Actualizar reglas Firestore a modo restrictivo temporal:
     match /{doc=**} { allow read, write: if false; }
   
4. RECUPERAR
   - Restaurar reglas normales desde firestore.rules en git
   - firebase deploy --only firestore --project [PROD_PROJECT]
   - Habilitar registros nuevamente
   
5. DOCUMENTAR
   - Crear issue post-mortem en GitHub
   - Notificar a usuarios afectados si aplica (GDPR/privacidad)
```

### Nivel P1 — Servicio degradado

```
1. Verificar Crashlytics para errores masivos
2. Revisar Cloud Functions logs para errores 500
3. Verificar Firestore usage en Firebase Console
4. Considerar rollback (ver §6)
```

---

## 6. Rollback de deploy

### Rollback de Cloud Functions

```bash
# Ver versiones desplegadas
gcloud functions list --project [PROJECT_ID]

# Rollback a versión anterior del código
git checkout [PREVIOUS_COMMIT_HASH] -- functions/
firebase deploy --only functions --project [PROJECT_ID]

# Volver a la versión actual
git checkout main -- functions/
```

### Rollback de Flutter Web (Firebase Hosting)

```bash
# Ver historial de releases
firebase hosting:releases:list --project [PROJECT_ID]

# Rollback al release anterior (usa el ID del release)
firebase hosting:rollback [RELEASE_ID] --project [PROJECT_ID]
```

### Rollback de Firestore Rules

```bash
# Restaurar reglas de producción conocidas-buenas desde git
git checkout [SAFE_COMMIT] -- firestore.rules
firebase deploy --only firestore:rules --project [PROJECT_ID]
```

---

## 7. Procedimientos de monitoreo

### 7.1 Verificación diaria (cron interno)
- [ ] Crashlytics: sin nuevos crash groups críticos
- [ ] Cloud Functions: tasa de error < 1%
- [ ] Firestore: sin alertas de usage
- [ ] Auth: sin picos de registros sospechosos

### 7.2 Alertas configuradas (Cloud Monitoring)
- Functions falla 3+ veces en 1h → alerta email a equipo
- Firestore reads > umbral → alerta de costo

### 7.3 Ver logs de functions en tiempo real
```bash
firebase functions:log --project [PROJECT_ID] --follow
```

---

## 8. Índices Firestore requeridos

Los siguientes índices compuestos deben estar activos en producción:

| Colección | Campos | Dirección |
|-----------|--------|-----------|
| `alertas` | `id_vehiculo` ASC, `estado` ASC | Compuesto |
| `alertas` | `id_vehiculo` ASC, `fecha_limite` ASC | Compuesto |
| `conversaciones` | `id_propietario` ASC, `ultimoMensajeTs` DESC | Compuesto |
| `conversaciones` | `id_mecanico` ASC, `ultimoMensajeTs` DESC | Compuesto |
| `servicios` | `id_vehiculo` ASC, `fecha` DESC | Compuesto |
| `reservas` | `id_propietario` ASC, `estado` ASC | Compuesto |
| `reservas` | `id_mecanico` ASC, `estado` ASC | Compuesto |

Para crear manualmente: Firebase Console → Firestore → Indexes → Create Index

---

## 9. Backup de Firestore

### Backup manual (emergencia pre-deploy)
```bash
gcloud firestore export gs://[PROJECT_ID]-backups/manual-$(date +%Y%m%d) \
  --project [PROJECT_ID]
```

### Backup automático (scheduled export)
Configurar en Cloud Scheduler (Cloud Console):
- Frecuencia: `0 2 * * *` (2am diario)
- Target: `gs://[PROJECT_ID]-backups/daily`
- Comando: Cloud Functions → `scheduledFirestoreExport`

### Restaurar backup
```bash
gcloud firestore import gs://[PROJECT_ID]-backups/[BACKUP_ID] \
  --project [PROJECT_ID]
```

---

## 10. Escalación y contactos

| Rol | Responsabilidad | Contacto |
|-----|----------------|---------|
| Tech Lead | Incidentes P0, arquitectura | [EMAIL] |
| Backend Dev | Functions, Firestore, reglas | [EMAIL] |
| Flutter Dev | App crashes, bugs UI | [EMAIL] |
| DevOps | CI/CD, hosting, Firebase | [EMAIL] |
| Legal | Privacidad, cumplimiento | [EMAIL] |

### SLAs internos
- **P0** (app caída / brecha): < 30 min respuesta, < 2h resolución
- **P1** (funcionalidad crítica degradada): < 2h respuesta, < 8h resolución  
- **P2** (bug no crítico): < 24h respuesta, próximo sprint

---

## 11. Checklist pre-lanzamiento (Soft Launch)

- [ ] Reglas Firestore desplegadas y testeadas con emulador
- [ ] Reglas Storage desplegadas
- [ ] Cloud Functions desplegadas y testeadas
- [ ] Firebase App Check activo (Play Integrity en Android, DeviceCheck en iOS)
- [ ] Crashlytics recibiendo eventos de prueba
- [ ] Push notifications: Android ✅ iOS ✅ Web ✅
- [ ] Deep links verificados: chat, reserva, alerta
- [ ] Landing page en dominio final con SSL
- [ ] Privacy Policy publicada y enlazada desde app
- [ ] Terms of Service publicados y enlazados
- [ ] Índices Firestore activos (sin "Building")
- [ ] Staging sign-off completo por QA
- [ ] Backup inicial de Firestore creado
- [ ] Runbook distribuido al equipo

---

## App Check — activación

App Check debe desplegarse en **dos fases** para no dejar fuera a usuarios con
clientes antiguos en caché:

1. **Monitorización** (semana 1): registrar las apps en la consola de Firebase
   → App Check, con enforcement **desactivado**. Revisar en las métricas el
   porcentaje de peticiones con token válido.
2. **Enforcement** (semana 2, si el porcentaje supera el 98 %): activar el
   enforcement en Firestore y Storage desde la consola (ver distinción con
   Functions más abajo), uno a uno, verificando entre cada paso.

Requisito previo: la Tarea 1 de este plan (cabeceras de caché) debe estar en
producción, porque de lo contrario los clientes antiguos sin App Check quedan
atrapados en caché y el enforcement los expulsaría de forma permanente.

**Dos entornos, dos site keys.** Desde la Fase E existen dos proyectos de
Firebase/Google Cloud independientes — `staging`/`autodoc-staging` y
`production`/`autodoc-6ef5a` — y las claves de sitio de reCAPTCHA Enterprise
están atadas a un proyecto de GCP concreto y a una lista de dominios
permitidos: la clave de producción no sirve para el dominio de staging (y
viceversa). Cada entorno necesita su **propia** clave de sitio, registrada
como el secreto de GitHub `RECAPTCHA_SITE_KEY` en el Environment
correspondiente (ver "Esquema de nombres de secretos" en la sección de
Acciones manuales pendientes). App Check debe validarse primero en staging
con su propia `RECAPTCHA_SITE_KEY`, siguiendo la misma regla de "reglas
primero en staging" que ya aplica a Firestore/Storage en este runbook (ver
`## Entornos` más arriba).

**Firestore/Storage vs. Cloud Functions — el enforcement NO es simétrico.**
Para Firestore y Storage, activar el enforcement de App Check es un ajuste de
consola (Firebase Console → App Check → seleccionar el producto → Enforce).
Para Cloud Functions **no basta con un toggle**: este repo usa Cloud
Functions **v1** (`functions/index.js`, `require('firebase-functions')`), y
en v1 el enforcement de App Check se implementa a **nivel de código**,
revisando `context.app` dentro de cada `onCall` y rechazando la llamada si es
`undefined` — no existe un ajuste de consola equivalente para v1. Hoy
**ningún** `onCall` de `functions/index.js` verifica `context.app`, así que
activar App Check en la consola no protege las Functions de este proyecto en
absoluto; solo protege Firestore y Storage. Implementar esa verificación de
código es trabajo pendiente, ver "Trabajo pendiente / deuda conocida" más
abajo — no se implementó en la Fase E ni en este fix wave.

**Nota sobre CI/CD (actualizada, Fase E fix wave):** `flutter_ci.yml` ya no
existe — la Tarea 15 lo eliminó por completo. El único workflow de web es
`.github/workflows/ci.yml`, y hoy **sí** pasa `--dart-define=RECAPTCHA_SITE_KEY=...`
en los 3 pasos `flutter build web` (`build_web_smoke`, `deploy_staging`,
`deploy_production` — ver los pasos "Build Flutter Web (release)" / "Build
Flutter Web for staging" / "Build Flutter Web for production" en ese archivo).
Además, el fix wave de la revisión final de Fase E conectó ahí mismo el resto
de secretos que `lib/config/secrets.dart` necesita para que la app funcione en
tiempo de ejecución (`FIREBASE_WEB_API_KEY`, `FIREBASE_APP_ID_WEB`,
`FIREBASE_MEASUREMENT_ID`, `FIREBASE_MESSAGING_SENDER_ID`,
`FIREBASE_PROJECT_ID`, `FIREBASE_AUTH_DOMAIN`, `FIREBASE_STORAGE_BUCKET`,
`GOOGLE_MAPS_API_KEY`, `VEHICLE_IMAGE_API_KEY`, `GOOGLE_CUSTOM_SEARCH_API_KEY`,
`GOOGLE_CUSTOM_SEARCH_CX`), que hasta entonces NO se pasaban a
`flutter build web` en CI pese a estar ya disponibles en el job (la Tarea 16
los usaba solo para el service worker). Sigue existiendo el modo tolerante a
fallos si `RECAPTCHA_SITE_KEY` está vacío (App Check no bloquea el arranque),
pero el cliente web no emitirá tokens válidos hasta que el secreto esté
realmente configurado en GitHub (ver "Esquema de nombres de secretos" más
arriba, en "Acciones manuales pendientes").

---

## Trabajo pendiente / deuda conocida

### `buscarPropietarioPorCorreo` sigue expuesto a enumeración sin límite de tasa

`functions/index.js:922` (`exports.buscarPropietarioPorCorreo`), con el
comentario explicativo en `functions/index.js:897-921`: la Fase C cerró
parcialmente el hallazgo Important de que esta función actúa, para cualquier
cuenta con rol Propietario, como un oráculo `correo -> (uid, nombre_completo)`
sobre toda la población de propietarios, sin límite de tasa (una cuenta
Propietario puede crearse un vehículo desechable en un solo write para pasar
el gate de `vehicleId + soy su propietario`). El comentario en el código
diferia deliberadamente el cierre completo de este hallazgo a "App Check
(Fase E, Tarea 14 del plan)", asumiendo que el enforcement de App Check en
Functions bloquearía las llamadas que no vengan de la app real.

Con la Fase E terminada, ese enforcement **no existe todavía**: como se
explica arriba, las Cloud Functions v1 de este repo requieren verificar
`context.app` a nivel de código en cada `onCall`, y ningún `onCall` de
`functions/index.js` lo hace hoy — activar App Check en la consola de
Firebase no protege esta función. El hallazgo queda, por tanto, **abierto sin
dueño**: no se implementó en la Fase E ni en este fix wave (que es
deliberadamente solo de documentación/CI, no de cambios de comportamiento en
producción). Cerrarlo requiere una tarea propia que añada la verificación de
`context.app` en `buscarPropietarioPorCorreo` (y evalúe si conviene
extenderla a otros `onCall` sensibles), con su propia revisión — no debe
implementarse como un fix de documentación.

---

*Documento mantenido en `docs/RUNBOOK.md`. Actualizar con cada cambio operacional significativo.*
