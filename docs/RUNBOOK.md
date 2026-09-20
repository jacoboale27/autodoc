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

### Pendiente 0 — ANTES de desplegar las reglas de H-01: contar talleres sin `estado`

**Bloqueante.** H-01 endurece dos sitios que antes miraban solo el `rol`:

- `storage.rules` → `isVinculadoAlVehiculo()` pasa a exigir taller **aprobado**. Afecta a
  `facturas/{vehicleId}` y a la galería `vehiculos/{vehicleId}/**`.
- `firestore.rules` → abrir una conversación como propietario exige que el `id_mecanico`
  nombrado sea un taller aprobado.

Ambas resuelven el estado con `.get('estado', 'pendiente')`. O sea: **un usuario con rol
`Mecanico` o `Taller` al que le falte el campo `estado`, o lo tenga con un valor heredado
fuera de `['aprobado','activo']`, pierde de golpe** el acceso a las facturas y a la galería de
los vehículos a los que está vinculado, y deja de poder recibir chats nuevos de propietarios.

Ninguna suite puede avisar de esto: `test_rules/storage.test.js:17` siembra siempre
`estado: 'activo'` y las suites nuevas siembran el caso a propósito. Es el mismo tipo de
trampa que el backfill de `abierto` en `fix/gaps-02` — una igualdad sobre un campo ausente no
devuelve nada.

**Qué hacer, en este orden:**

1. Contar, contra el proyecto real y **antes** de desplegar:

   ```
   cd functions
   node contar_talleres_sin_estado.js           # cuenta y lista; no escribe nada
   node contar_talleres_sin_estado.js --csv    # la lista completa, para decidir una a una
   ```

   Lo que hay que saber es cuántos documentos de `usuarios` cumplen
   `rol in ['Mecanico','Taller']` **y** (`estado` ausente **o** `estado` fuera de
   `['aprobado','activo']`).

2. Si el resultado es **cero**, desplegar reglas y app juntas. No hace falta nada más.

3. Si es **distinto de cero**, hay que decidir documento a documento antes de desplegar: los
   que estén operativos necesitan `estado: 'aprobado'`; los que estén realmente pendientes o
   suspendidos **deben** perder el acceso, que es justo el defecto que H-01 cierra. No hagas un
   backfill ciego a `'aprobado'`: convertiría el arreglo en su contrario.

**El expediente de verificación no se ve afectado**, y es deliberado: `verificaciones/{tallerId}`
sigue usando el `isMecanico()` laxo de `storage.rules`, porque un taller sube su NIT y sus fotos
precisamente cuando todavía no está aprobado.

### Pendiente 0ter — Limpiar los `foto_url` raspados de los vehículos existentes

**Comando:** `cd functions && node backfill_foto_url_ajena.js` (dry-run) y luego `--apply`.

Hasta el 2026-09-17 `VehicleProvider.addVehicle` llamaba a `VehicleImageService`, que buscaba en
SearchAPI.io (engine `google_images`) una foto de la marca y el modelo y guardaba **ese enlace**
en `vehiculos.foto_url`. O sea: **cada vehículo creado desde que existe la app** lleva enlazada
una imagen de un tercero. El servicio está retirado y `firestore.rules` ya impide que nazca otro,
pero eso no limpia los que hay.

Dos motivos, y el segundo es el que no caduca solo:

- **Propiedad intelectual.** Son fotos de catálogos de concesionario y bancos de imagen sobre las
  que AutoDoc no tiene licencia, pintadas como si fueran el coche de la persona. En una ficha de
  Google Play eso es exposición a una retirada.
- **Privacidad.** `foto_url` la lee todo el que puede ver el vehículo —el taller vinculado y sus
  empleados, aquel con quien el dueño lo comparta, y por la vista pública quien reciba un pase de
  historial—, así que cada visita le entrega al servidor ajeno la IP y el User-Agent del
  visitante. Es el mismo agujero que FUNC-01 cerró en `resenias.fotos`.

**No es bloqueante para desplegar** las reglas ni la app: la regla nueva valida `foto_url` solo
cuando **cambia** (`fotoDeVehiculoValidaEnUpdate`), así que un vehículo con enlace heredado se
sigue pudiendo editar mientras tanto. Pero **ninguna suite puede avisar de que falta**: los
emuladores se siembran limpios, así que el único sitio donde se ve el problema es producción.

El script borra el campo (`FieldValue.delete()`); la app cae al placeholder local. **No toca** las
URLs que ya apuntan a nuestro Storage: ésas son fotos que el propietario subió con
`VehiclePhotoService` y son suyas.

**Y un paso fuera del repo:** la clave `VEHICLE_IMAGE_API_KEY` ya no la usa nadie —se retiró de
`secrets.dart`, de los cinco `--dart-define` de `ci.yml`, de `.env.example`, de `app.env` y del
script de secretos—. Bórrala del panel de SearchAPI.io y del repositorio de secretos de GitHub.
Sigue viva en tu `.env` local, que un hook impide editar.

### Pendiente 0bis — Politicas TTL de Firestore (CUATRO, y una llevaba perdida desde UX-01)

**Firestore no configura TTL desde `firestore.indexes.json`.** Va por consola o por `gcloud`, y
por eso estos pasos se pierden: no hay ningun archivo del repo que los declare y ningun test que
los eche de menos.

**Y una ya se perdio.** La politica de `solicitudes_landing_control` se decidio en UX-01 y quedo
anotada **solo** en `docs/evidencia/UX-01-contacto-y-ctas.md`, nunca en este runbook. Es
literalmente el patron que el propio proyecto lleva cuatro tandas escribiendo: remitir un paso a
otro documento no lo cierra. Aqui quedan las cuatro.

| Coleccion | Campo | Por que |
|---|---|---|
| `solicitudes_landing_control` | `expira_en` | Un documento por IP del limitador de la landing. Sin TTL no se purga nunca. |
| `tokens_historial` | `purgar_en` | Un documento por pase de historial emitido (INNO-01). Guarda `{id_vehiculo, id_propietario}` — o sea un mapa de quien tiene que coche— en una coleccion que **nadie puede leer** y que por tanto nadie va a auditar. |
| `consultas_ia_control` | `expira_en` | Un documento por usuario del asistente de agenda, mas el cubo `_global`. Sin TTL crece un documento por persona que lo use, para siempre, aunque cada uno solo se lea durante 24 h. |
| `explicaciones_ia` | `expira_en` | Cache global de explicaciones del asistente: un documento por pregunta distinta. Sin TTL no se purga nunca **y una entrada mala se queda para siempre** — el cliente no puede borrarla (correcto) y no hay ningun barrido que lo haga. |

```bash
gcloud firestore fields ttls update expira_en   --collection-group=solicitudes_landing_control --enable-ttl --project=<projectId>

gcloud firestore fields ttls update purgar_en   --collection-group=tokens_historial --enable-ttl --project=<projectId>

gcloud firestore fields ttls update expira_en   --collection-group=consultas_ia_control --enable-ttl --project=<projectId>

gcloud firestore fields ttls update expira_en   --collection-group=explicaciones_ia --enable-ttl --project=<projectId>
```

**Las dos del asistente NO son bloqueantes para desplegar**, a diferencia de los backfills: sin
ellas la feature funciona igual y lo unico que pasa es que dos colecciones crecen sin fondo. Pero
la de `explicaciones_ia` es la unica via que existe para retirar una entrada de cache: la
coleccion esta cerrada al cliente por los dos lados y no hay barrido que la toque.

**El campo tiene que ser `Timestamp`, no milisegundos.** Con un numero la politica se crea sin
error y no borra nada jamas. Por eso `tokens_historial` guarda **dos** campos de tiempo:
`expira_en` en epoch ms (que es lo que compara el callable con `Date.now()`) y `purgar_en` como
`Date`, 48 h despues. Ese margen tampoco es cosmetico: si el TTL borrase justo al vencer, un pase
caducado pasaria de decir «ya caduco» a «no existe». Ningun test puede verlo — el emulador no
ejecuta politicas TTL.

Verificar despues de crearlas:

```bash
gcloud firestore fields ttls list --project=<projectId>
```

### Pendiente 0quater — Desplegar el asistente de agenda (IA-01), en este orden

El asistente es la primera pieza del proyecto que depende de un **proveedor externo de pago** y
de un **secreto**, así que su despliegue tiene un orden y no es negociable. Evidencia completa en
`docs/evidencia/IA-01-asistente-de-agenda.md`.

**1. El secreto — HECHO.**

```bash
firebase functions:secrets:set GEMINI_API_KEY --project production
```

La clave vive **solo** en Secret Manager. Nunca en un `.env` versionado, nunca en el bundle del
cliente. El input de la CLI va enmascarado; para comprobar que se pegó bien, compara la
**longitud** (`firebase functions:secrets:access GEMINI_API_KEY --project production | Measure-Object -Character`), no el contenido.

**2. Índices, ANTES que las funciones.**

```bash
firebase deploy --only firestore:indexes --project production
```

Sin ellos la agenda falla **solo en producción**: los emuladores sirven cualquier consulta sin
mirar `firestore.indexes.json`. Lo vigila `test/firestore_indices_test.dart`.

**3. Las dos políticas TTL del asistente** — ver Pendiente 0bis. No son bloqueantes, pero la de
`explicaciones_ia` es la única vía que existe para retirar una entrada mala de la caché.

**4. Reglas.**

```bash
firebase deploy --only firestore:rules --project production
```

**5. La función.**

```bash
firebase deploy --only functions:asistenteAutoDoc --project production
```

Pasa por la guarda `predeploy` `scripts/verificar_env_functions.js`, **y esa guarda no es
opcional**: la compuerta que elige entre Gemini y el doble de emulador mira
`FUNCTIONS_EMULATOR`, y esa variable **no está en las claves reservadas de firebase-tools**
(comprobado en la 15.28.2, `lib/functions/env.js`). Una línea en `functions/.env.<projectId>`
llegaría al proceso desplegado y el asistente serviría **respuestas enlatadas con pinta de
buenas**, sin que nada fallara ni nadie viera un error. Ninguna suite puede verlo: esos `.env`
están en `functions/.gitignore`.

**6. El kill switch, creado encendido y verificado en los DOS sentidos.**

Documento `configuracion/asistente_ia`, campo `activo: true`. Ponerlo a `false` tiene que dejar
la pantalla diciendo que el asistente está desactivado —no un error genérico— y volverlo a `true`
tiene que devolver el servicio sin desplegar nada.

Se lee **en cada petición**, a propósito: cachearlo significaría que apagarlo no surte efecto
inmediato, que es justo lo que un kill switch tiene que hacer. Cuesta una lectura por consulta.

**7. Cuotas.** `LIMITE_POR_USUARIO = 10` y `LIMITE_GLOBAL = 200` por ventana de 24 h. El corte
global va muy por debajo del free tier a propósito: quedarse sin cuota del proveedor a media demo
no se arregla con un despliegue, mientras que subir la constante sí.

**8. Hosting**, con `flutter clean` (no es opcional) y la guarda `verificar_bundle_web.js`.

**Siempre `--project` explícito.** El default de `.firebaserc` es `autodoc-staging`.

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
| `FIREBASE_WEB_API_KEY`, `FIREBASE_APP_ID_WEB`, `FIREBASE_MEASUREMENT_ID`, `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_PROJECT_ID`, `FIREBASE_AUTH_DOMAIN`, `FIREBASE_STORAGE_BUCKET`, `GOOGLE_MAPS_API_KEY`, `VEHICLE_IMAGE_API_KEY`, `RECAPTCHA_SITE_KEY`, `GOOGLE_SIGNIN_CLIENT_ID_WEB` | **Ambos niveles a la vez**, no uno u otro: (1) **Settings → Environments → `staging`** y **Settings → Environments → `production`** por separado, mismo nombre, **valor distinto** en cada uno — esto es lo que consumen `deploy_staging`/`deploy_production`. (2) **También** en Settings → Secrets and variables → Actions (nivel repositorio), con un valor razonable (p. ej. el de staging, o un valor de desarrollo) — este nivel es el único que puede ver `build_web_smoke` (ver la limitación de abajo: ese job no declara `environment:`), y sus guardias `[ -z ... ]; exit 1` (`ci.yml:118-147`) hacen fallar el job en cada PR si el secreto de repositorio no existe. GitHub resuelve el secreto de **Environment** con prioridad sobre el de **repositorio** para los jobs que sí declaran ese entorno, así que tener también un valor a nivel de repositorio **no** hace que `deploy_staging`/`deploy_production` usen el valor equivocado — el de Environment siempre gana ahí. |
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

## 8.1 CORS del bucket de Storage (solo afecta a Flutter Web)

`cors.json` es la configuracion CORS del bucket. **No se despliega con
`firebase deploy`**: hay que aplicarla a mano con `gcloud`, y hasta que se
aplica el bucket conserva la que tuviera antes.

Solo importa en la build web. En Android/iOS el SDK no pasa por CORS, asi que
un `cors.json` mal puesto no se nota hasta que alguien sube un archivo desde
el navegador — y entonces el error que llega a Dart no dice "CORS", dice
`unauthorized` o un fallo de red generico.

```bash
# Ver la configuracion que tiene el bucket ahora mismo
gcloud storage buckets describe gs://autodoc-6ef5a.firebasestorage.app   --format="default(cors_config)"

# Aplicar la de este repositorio
gcloud storage buckets update gs://autodoc-6ef5a.firebasestorage.app   --cors-file=cors.json
```

El fichero incluye `PUT`/`POST`/`DELETE` ademas de `GET`: una configuracion de
solo lectura deja pasar las descargas —que es lo que se ve al navegar— pero
tumba toda subida desde web (fotos de perfil, evidencia de verificacion,
galeria del taller, facturas). `origin` esta en `*`; conviene acotarlo a los
dominios de hosting reales cuando esten fijados.

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
`undefined` — no existe un ajuste de consola equivalente para v1.

**Estado (SEC-04, cerrada).** Esa verificación ya existe:
`functions/src/appCheck.js` la implementa y los **12** `onCall` de
`functions/index.js` la invocan como su primera línea. Un centinela
(`functions/test/app_check_cobertura.test.js`) impide que un callable nuevo
nazca sin ella: corta el entrypoint en bloques por `exports.` y falla si
alguno declara un `onCall` sin su `exigirAppCheck`. Cuenta bloques y no
ocurrencias a propósito — contar `onCall` y contar `exigirAppCheck` daría el
mismo número aunque un callable llevara dos comprobaciones y otro ninguna.

Lo que **no** hace ese cambio por sí solo es rechazar nada. El modo por
defecto es `monitor`:

| `APP_CHECK_ENFORCEMENT` | Efecto |
|---|---|
| ausente, o valor no reconocido | cae a `monitor` |
| `monitor` | no rechaza; registra cada llamada sin token, con el callable y el uid |
| `enforce` | rechaza con `failed-precondition`, con un mensaje que no nombra App Check |
| `off` | ni rechaza ni registra (válvula de emergencia sin desplegar código) |

Un valor no reconocido cae a `monitor` a propósito: caer a `off` sería
inseguro en silencio, y caer a `enforce` por una errata de configuración
dejaría fuera a la aplicación entera. Por el mismo motivo el mensaje de
rechazo es opaco — nombrar App Check, el proveedor o la variable le diría al
atacante contra qué está chocando.

### App Check — verificación reproducible

Procedimiento a ejecutar y **fechar** para dar por demostrado el enforcement.
Ningún paso necesita secretos en el registro: se anota el resultado, no la
clave.

1. **Cobertura de código**, reproducible en local y sin consola:

   ```bash
   cd functions && npx mocha test/app_check.test.js test/app_check_cobertura.test.js
   ```

   Cubre los 12 callables y los negativos de rechazo.

2. **Rechazo real en `enforce`**, contra el emulador y nunca contra
   producción:

   ```bash
   cd functions
   APP_CHECK_ENFORCEMENT=enforce npx firebase emulators:start --only functions \
     --project autodoc-rules-test
   ```

   Cualquier `onCall` invocado contra ese emulador debe devolver
   `failed-precondition`. El emulador de Functions **no emite tokens de App
   Check**, así que toda llamada desde él cae en el caso sin token — que es
   justo lo que vuelve verificable el rechazo, y también por qué el modo por
   defecto no puede ser `enforce`: con él, la suite de E2E entera dejaría de
   pasar.

   Este paso es **manual**: no hay todavía un spec que lo ejerza de punta a
   punta. Queda anotado como gap de SEC-04; lo que sí está automatizado es el
   paso 1, que prueba el rechazo a nivel de unidad.

3. **Métricas de consola** (Firebase Console → App Check → Métricas), por
   producto y por app. Anotar el porcentaje de peticiones con token válido de
   los últimos 7 días. **No pasar a `enforce` por debajo del 98 %.**

4. **Enforcement de Firestore y Storage** (Firebase Console → App Check →
   producto → Enforce), uno a uno, verificando entre cada paso.

| Fecha | Entorno | Paso | Resultado | Quién |
|---|---|---|---|---|
| _(pendiente)_ | staging | 3 — métricas | | |
| _(pendiente)_ | staging | 4 — Firestore/Storage Enforce | | |
| _(pendiente)_ | staging | `APP_CHECK_ENFORCEMENT=enforce` | | |
| _(pendiente)_ | production | 3 — métricas | | |
| _(pendiente)_ | production | 4 — Firestore/Storage Enforce | | |
| _(pendiente)_ | production | `APP_CHECK_ENFORCEMENT=enforce` | | |

**El orden importa:** staging entero antes que producción, y dentro de cada
entorno las métricas antes que cualquier `Enforce`. Poner
`APP_CHECK_ENFORCEMENT=enforce` con el porcentaje por debajo del umbral no es
un ajuste agresivo: es una caída de servicio para los clientes que aún no
firman.

**Cómo llega la variable a las funciones desplegadas.** No es un ajuste de
consola: en Cloud Functions v1 las variables de entorno se entregan con los
archivos `.env` que lee `firebase-tools` al desplegar, dentro de `functions/`:

| Archivo | Se aplica a |
|---|---|
| `functions/.env` | todos los proyectos |
| `functions/.env.autodoc-staging` | solo staging |
| `functions/.env.autodoc-6ef5a` | solo producción |

Ninguno está versionado ni debe estarlo. Para pasar un entorno a enforcement
se añade `APP_CHECK_ENFORCEMENT=enforce` al archivo de **ese** proyecto y se
redespliegan las funciones; sin redespliegue la variable no cambia. Cambiar el
modo es, por tanto, un despliegue, no un interruptor — tenerlo presente antes
de prometer una vuelta atrás inmediata. La marcha atrás rápida existe, pero es
otro despliegue con `off`.

**Y un aviso que cuesta caro olvidar:** `lib/main.dart:173-181` **omite App
Check en web cuando falta `RECAPTCHA_SITE_KEY`**, y lo omite entero contra
emuladores. Es decir, un build web sin esa clave emite **cero** tokens
válidos, por configuración y no por clientes antiguos. Poner `enforce` con la
web en ese estado no es una degradación parcial: es la caída total de la web.
El paso 3 lo detectaría, pero conviene mirar el build antes que las métricas.

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
`GOOGLE_MAPS_API_KEY`, `VEHICLE_IMAGE_API_KEY`), que hasta entonces NO se pasaban a
`flutter build web` en CI pese a estar ya disponibles en el job (la Tarea 16
los usaba solo para el service worker). Sigue existiendo el modo tolerante a
fallos si `RECAPTCHA_SITE_KEY` está vacío (App Check no bloquea el arranque),
pero el cliente web no emitirá tokens válidos hasta que el secreto esté
realmente configurado en GitHub (ver "Esquema de nombres de secretos" más
arriba, en "Acciones manuales pendientes").

---

## Trabajo pendiente / deuda conocida

### `buscarPropietarioPorCorreo` — cerrado por SEC-03 y SEC-04

Esta entrada describía un oráculo `correo -> (uid, nombre_completo)` sin
límite de tasa y difería su cierre a "cuando exista enforcement de App Check".
Las dos mitades están cerradas y la descripción ya no corresponde al código:

- **SEC-03** rehízo el contrato del callable. Ya no resuelve el correo: crea
  una solicitud con un código de invitación aleatorio y guarda el correo
  **hasheado**. La respuesta es indistinguible exista o no la cuenta destino,
  y cada intento se contabiliza por uid en `limitesCompartir` con una
  transacción que los serializa entre instancias.
- **SEC-04** añadió la verificación de `context.app` que esta entrada estaba
  esperando — en este callable y en los otros once.

Queda una condición, y es la de siempre: la verificación **solo rechaza** con
`APP_CHECK_ENFORCEMENT=enforce`. Mientras el despliegue siga en `monitor`, el
límite de tasa por uid es el único control activo contra el abuso
automatizado.

---

## Respaldo de Firestore — prerrequisitos (OPS-01)

`scheduledFirestoreExport` (`functions/src/exportacionFirestore.js`) es la
**única** copia de seguridad del proyecto. Corre cada 24 h y exporta la base
entera a Cloud Storage. Tres cosas tienen que existir fuera del repositorio y
**ningún test puede comprobarlas**:

1. **El bucket de destino.** Por defecto `gs://<projectId>-backups`; se puede
   fijar con `FIRESTORE_BACKUP_BUCKET` para que staging y producción no
   compartan destino. Debe estar en la misma región que la base de datos, o la
   exportación falla.

   ```bash
   gcloud storage buckets create gs://<projectId>-backups --location=<region>
   ```

2. **El rol de la cuenta de servicio.** La que ejecuta la función necesita
   `roles/datastore.importExportAdmin` en el proyecto y escritura en el
   bucket. Sin él la exportación muere con `PERMISSION_DENIED` — que ahora sí
   se relanza, así que Cloud Scheduler la marca fallida en vez de tragársela.

   ```bash
   gcloud projects add-iam-policy-binding <projectId> \
     --member=serviceAccount:<projectId>@appspot.gserviceaccount.com \
     --role=roles/datastore.importExportAdmin
   ```

3. **Política de ciclo de vida en el bucket.** Sin ella, una copia completa
   diaria se acumula indefinidamente y el coste crece sin techo. No es una
   optimización: es la diferencia entre un respaldo y una factura.

**Verificación fechada** — configurarlo no basta, hay que comprobarlo:

| Fecha | Entorno | Bucket existe | Rol IAM | Ciclo de vida | Última exportación correcta |
|---|---|---|---|---|---|
| _(pendiente)_ | staging | | | | |
| _(pendiente)_ | production | | | | |

Comprobar la última exportación con `gcloud storage ls
gs://<projectId>-backups` y con `firebase functions:log --only
scheduledFirestoreExport`. **Un respaldo que nunca se ha restaurado no está
demostrado**: la prueba completa incluye importar una exportación a un
proyecto desechable.

---

## Tareas programadas — qué corre y qué hay que operar (OPS-01)

Las cuatro funciones programadas del proyecto, todas
`pubsub.schedule('every 24 hours')`. Las cuatro tienen ya su lógica extraída y
probada con fixtures; aquí va lo que **no** puede cubrir un test.

| Función | Módulo | Qué falla si no se opera |
|---|---|---|
| `checkAlertsDaily` | `src/alertasVencidas.js` | nada externo; depende de `ultimo_aviso`, cerrado al cliente en `firestore.rules` |
| `sendReservationReminders` | `src/recordatoriosReserva.js` | necesita el índice `reservas (estado, fecha_hora_propuesta)` **desplegado antes** que la función |
| `caducarVinculosDeTalleresInactivos` | `src/caducarVinculos.js` | ver FUNC-02 |
| `scheduledFirestoreExport` | `src/exportacionFirestore.js` | bucket, rol IAM y ciclo de vida (arriba) |

Las cuatro **relanzan** el error en vez de tragárselo, para que Cloud
Scheduler las marque fallidas y reintente. Antes de OPS-01, dos terminaban en
un `console.error` y un barrido roto era indistinguible de un día sin trabajo.

**Zona horaria.** El recordatorio de citas calcula "mañana" en hora de
Colombia (UTC-5 fijo, sin horario de verano), no en UTC. Si algún día hay
usuarios fuera de Colombia ese supuesto deja de valer y hay que resolver la
zona por reserva.

### Orden de despliegue de OPS-01 — los dos pasos no son negociables

1. **`firebase deploy --only firestore:indexes` ANTES que las funciones.**
   `sendReservationReminders` pasa a acotar su consulta por fecha y necesita
   el índice `reservas (estado, fecha_hora_propuesta)`. Sin él la consulta
   muere con `failed-precondition` — y ahora, gracias al relanzamiento del
   error, morirá ruidosamente todos los días en vez de en silencio. Mejor,
   pero sigue siendo un día sin recordatorios por cada día que falte el
   índice.

2. **`node backfill_ultimo_aviso.js --apply` ANTES de desplegar las
   funciones.** `ultimo_aviso` no existe en ningún documento de producción, así
   que la primera corrida del barrido nuevo notificaría de golpe **todo** el
   volumen histórico de alertas pendientes vencidas o por vencer: un push, una
   escritura de notificación y un update por cada una, en una sola invocación.
   Y el caso que más documentos acumula es justo el que el cambio arregla —
   alertas vencidas que nadie cierra, que llevan meses avisando a diario.

   El script es dry-run por defecto. Estampa a cada alerta el escalón en el
   que está hoy y nada más, así que no le quita ningún aviso a nadie: lo único
   que suprime es la repetición que el usuario ya venía recibiendo.

3. **🔴 BLOQUEANTE — `node backfill_avisos_pendientes.js --apply` ANTES de
   desplegar las funciones, y DESPUÉS del paso 2.** Es el paso más peligroso
   de este cajón, porque su modo de fallo es **silencioso y total**.

   `checkAlertsDaily` pasa a consultar `avisos_pendientes == true` en vez de
   traerse todas las alertas `Pendiente` y descartar en memoria las que ya
   consumieron su último escalón (gap 1 del §5 de `GAPS-05-drenaje.md`). Una
   igualdad sobre un campo **ausente no devuelve nada**, y ninguna alerta de
   producción tiene ese campo: desplegar sin haber corrido el backfill deja la
   consulta diaria en **cero documentos**, o sea **todas las alertas dejan de
   avisar**. No hay error, no hay log y ninguna suite puede verlo — el barrido
   informa de una corrida limpia.

   Es la misma trampa que `abierto` en GAPS-02 (el tablero de todos los
   talleres salía vacío) y que `estado` en H-01. Aquí se ensayó gratis: al
   añadir el filtro, **once tests del barrido se pusieron rojos de golpe**
   porque sus siembras no escribían el campo.

   Va **después** del paso 2 porque deriva de `ultimo_aviso`: al revés, las
   alertas que aquel marca como `vencida` quedarían con los avisos encendidos y
   recibirían un aviso de más. Uno, no una cascada.

   El script es dry-run por defecto, es idempotente (salta las que ya tienen el
   campo) y recorre **todas** las alertas, no solo las `Pendiente`: `estado` es
   mutable, y una alerta completada que el usuario reabra volvería a la cola
   sin el campo, invisible para siempre.

   **No hace falta desplegar índices.** Son dos igualdades (`estado` y
   `avisos_pendientes`), y Firestore las resuelve con merge join de los índices
   de campo único.

Van al mismo cajón que `SOLICITUDES_LANDING_SALT` (UX-01),
`firebase functions:delete iniciarReparacionPorVehiculo` (FUNC-02) y
`node backfill_entregado.js --apply` (GAPS-02).

---

*Documento mantenido en `docs/RUNBOOK.md`. Actualizar con cada cambio operacional significativo.*
