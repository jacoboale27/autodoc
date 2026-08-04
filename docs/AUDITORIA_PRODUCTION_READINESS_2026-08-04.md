# Auditoría de Production Readiness — AutoDoc

**Fecha:** 2026-08-04 · **Alcance:** repo completo (`main`, commit `39c6231`) · **Metodología:** auditoría adversarial multi-experto (6 subagentes especializados: Arquitectura/Backend/DB/Cloud, Seguridad, DevOps/SRE/Performance, QA/Testing, Frontend/UX/Accesibilidad, Producto/Negocio), grafo de conocimiento (graphify, 3927 nodos/5320 edges), y verificación cruzada manual de discrepancias.

> **Limitación declarada:** no se dispuso de un navegador/Playwright funcional en esta sesión (el MCP se registró pero requiere reinicio de sesión para cargar). Todos los hallazgos de UX/Accesibilidad/frontend se basan en lectura estática de código, no en observación de la app en ejecución. Esto se marca explícitamente en cada sección afectada y reduce la confianza de esa puntuación, no la anula.

---

## 1. Resumen ejecutivo

AutoDoc es un proyecto **notablemente más maduro que un MVP típico** en varias dimensiones (reglas de Firestore con historial de hardening adversarial documentado, runbook operacional real de 471 líneas, separación de entornos GCP, CI con gates reales) pero tiene **brechas serias y concretas** que impiden certificarlo como listo para producción con usuarios y datos reales hoy. La brecha más grave no es un único bug crítico de seguridad — de hecho, no se encontró ninguno que bloquee por sí solo — sino un **patrón sistémico de confianza mal calibrada**: la suite de tests de integración pasa siempre aunque el flujo que dice probar nunca se ejecute (0 o 1 `expect()` mal ubicado en los 3 archivos), la cobertura real es 8.7%, hay una contraseña compartida hardcodeada para cuentas de Superusuario, un oráculo de enumeración de correos que el propio equipo documentó y no cerró, un script de aprobación masiva de talleres sin ninguna salvaguarda, y una accesibilidad casi inexistente (28/100).

## 2. Estado general del proyecto

Producto pre-revenue (cero código de monetización), en fase de preparación para lanzamiento (existe checklist de "Soft Launch" y runbook), con arquitectura Clean Architecture + Provider parcialmente respetada y backend 100% Firebase. El equipo demuestra buena disciplina de proceso (comentarios de auditoría previa en `firestore.rules`, CI con gates), pero la ejecución tiene huecos que una revisión superficial no detectaría.

## 3. Fortalezas

- Reglas de Firestore/Storage con historial de hardening adversarial real y documentado (hallazgos C1/H1/H2/M1/I-1/I-3 ya cerrados con comentarios explicando el porqué).
- Todas las Cloud Functions `onCall` verifican `context.auth` y el rol **almacenado** (nunca el del payload del cliente) antes de operaciones privilegiadas — sin escalamiento de privilegios vía payload.
- Separación real de proyectos GCP (staging/producción), CI con formateo + análisis + tests de reglas contra emulador + smoke test post-deploy real que verifica cache-control.
- `RUNBOOK.md` (471 líneas) es un documento operativo real, no un placeholder: incident response P0/P1 con SLA, backups, checklist de lanzamiento.
- Localización 100% sincronizada (360/360 claves ES/EN).
- `.env`/`app.env`/credenciales correctamente excluidos de git (verificado con `git ls-files` y `git log --all`).
- Scripts de backfill (`backfillTalleres.js`, `backfillEstadoMecanicos.js`) con dry-run por defecto y advertencias explícitas contra producción — buena disciplina, salvo la excepción del hallazgo 8.4.

## 4. Debilidades

Ver hallazgos por área (sección 8). En síntesis: fugas de arquitectura (UI llama a Firebase directo en 12+ archivos), testing con falsa sensación de seguridad, observabilidad casi nula (errores no llegan a Crashlytics), accesibilidad casi inexistente, y varios procesos de negocio (aprobación de talleres, moderación) reducidos a un clic sin criterios documentados.

## 5. Riesgos críticos

1. **Tests de integración que siempre pasan sin ejecutar el flujo real** (`integration_test/auth_flow_test.dart`, `alert_flow_test.dart`: 0 `expect()`; `vehicle_flow_test.dart`: 1 `expect()` dentro de un `if` sin `else`). El equipo cree tener cobertura E2E que no existe — riesgo de que un regresión real llegue a producción con "CI en verde".
2. **Contraseña temporal hardcodeada y compartida** (`functions/index.js:1333`, `SUPERUSER_TEMP_PASSWORD = 'AutoDoc2026*'`) para toda cuenta creada por un Superusuario, incluidas cuentas de Administrador — confirmado independientemente por dos subagentes.
3. **Oráculo de enumeración de correos sin mitigar**, admitido por el propio equipo en comentarios (`functions/index.js:1039-1052`), cuyo cierre depende de un toggle de App Check en consola de Firebase que **no puede verificarse desde el repo**.
4. **Backup de Firestore potencialmente fallando en silencio**: `scheduledFirestoreExport` asume que el bucket de backups existe y solo hace `console.error` si falla — nadie se entera si la "estrategia de backup" nunca funcionó.
5. **Script de aprobación masiva de talleres sin salvaguarda** (`functions/src/aprobarTodosTalleres.js`, no rastreado en git): aprueba en bloque todos los talleres sin criterios ni registro en `admin_logs`, a diferencia de sus scripts hermanos que sí tienen advertencias y dry-run.

## 6. Riesgos ocultos

- **Discrepancia entre política de privacidad y código real**: la política dice que al borrar una cuenta se "ofuscará" el historial; `onUserDelete` en realidad borra en duro (hard delete) y ni siquiera limpia `conversaciones/mensajes`.
- **Contraste de color insuficiente en mensajes de error críticos** (modo claro): blanco sobre `lightError`/`lightWarning`/`lightSuccess` no cumple WCAG AA (2.44:1, 1.90:1, 2.43:1 vs 4.5:1 requerido) — exactamente en los `SnackBar` de error de los formularios más sensibles.
- **`publishTallerProfile` se dispara en cada escritura de cualquier usuario**, no solo mecánicos, ejecutando un `delete()` innecesario en cada refresco de token FCM de cualquier Propietario — costo que escala con la población total, no con talleres.
- **CI estuvo en rojo ≥10 días** antes de corregirse (commit `39c6231` mezcla el fix real de CI con 6 cambios de producto no relacionados bajo una sola etiqueta), lo que implica que hubo una ventana donde PRs se mergearon a `main` sin que el gate protegiera nada.
- **`auth_screen.dart` no usa `Form`/`TextFormField`/`validator`** — el flujo de entrada más crítico de la app valida con `if` secuenciales y un `SnackBar` transitorio que solo muestra el primer error.

## 7. Riesgos futuros

- A medida que crezca la base de usuarios, `checkAlertsDaily` y `sendReservationReminders` escalan con el histórico total (sin índice compuesto, filtrado de fecha en memoria) y envían notificaciones secuencialmente sin batching — riesgo real de exceder el timeout de Cloud Functions.
- El dashboard admin abre 6 listeners `.snapshots()` sin `limit()` sobre colecciones completas solo para contar documentos — el costo de lectura crece linealmente con los datos, sin ingresos (monetización) que lo compensen.
- Deuda de accesibilidad (28/100) se vuelve más cara de corregir cuanto más crezca la superficie de UI sin `Semantics`.
- Sin vetting real de talleres ni monetización, el riesgo reputacional de un mal servicio de un taller "verificado" por un clic crece proporcionalmente a la adopción.

## 8. Hallazgos por área

### 8.1 Arquitectura / Backend / Base de datos / Cloud (Arquitecto de Software + Backend Staff + DB Engineer + Cloud Architect)

| # | Severidad | Hallazgo | Evidencia | Recomendación | Esfuerzo |
|---|---|---|---|---|---|
| A1 | Alta | UI llama a Firebase directamente en 12+ archivos, violando CONVENTIONS.md | `initiate_service_screen.dart:130,165`, `share_vehicle_sheet.dart:23-24`, `admin_talleres_screen.dart`, `chat_screen.dart`, etc. | Migrar a repositorios; regla de lint que prohíba imports de Firebase en `presentation/` | 3-5 días |
| A2 | Alta | Contraseña temporal hardcodeada y compartida para cuentas de Superusuario | `functions/index.js:1333` | Generar contraseña aleatoria por cuenta + forzar cambio | Bajo |
| A3 | Alta | Enumeración de propietarios por correo sin mitigar, dependiente de App Check no verificable | `functions/index.js:1039-1052`; `RECAPTCHA_SITE_KEY` opcional en `ci.yml:169-175` | Confirmar enforcement de App Check en consola; añadir rate-limiting propio | Medio |
| A4 | Alta | Sin validación de tipos/esquema en Firestore para la mayoría de colecciones | Reglas solo validan ownership, no tipos (ej. `kilometraje_actual` como string rompe `checkMileageOnVehicleUpdate` silenciosamente) | Añadir `is number`/`is string` en reglas críticas | Medio |
| A5 | Alta | Backup automatizado de Firestore sin verificación ni alerta de fallo | `scheduledFirestoreExport`, solo `console.error` | Alertar (email/Slack) ante fallo; verificar bucket existente | Bajo |
| A6 | Media | `publishTallerProfile` se dispara en cada escritura de cualquier usuario | Trigger sin filtro de rol antes del `delete()` | `get()` antes de `delete()`, filtrar por rol | Bajo |
| A7 | Media | Jobs programados sin índice compuesto, filtran fecha en memoria sobre la colección completa | `functions/index.js:79-101, 697-715` | Índice compuesto `(estado, fecha)` | Medio |
| A8 | Media | Cascadas de borrado sin reintento ni dead-letter | `onUserDelete`/`onVehicleDelete`, solo `console.error` | Cola de reintentos o Cloud Tasks | Medio |
| A9 | Media | Índice de Firestore huérfano por typo de mayúscula (`"Servicios"` vs `servicios`) | `firestore.indexes.json` vs `firestore_collections.dart:2` | Corregir el índice | Trivial |
| A10 | Media | Orden de deploy invertido entre staging y producción (Functions→Rules→Storage vs Rules→Storage→Functions) | `.github/workflows/ci.yml` | Unificar orden | Bajo |
| A11 | Media | Sin rollback automatizado ante fallo parcial de deploy | `deploy_production` job | Automatizar rollback o gate manual pre-prod | Medio |
| A12 | Baja-Media | Script `aprobarTodosTalleres.js` no commiteado, sin guardas, bypasea `admin_service.dart` y `admin_logs` | `functions/src/aprobarTodosTalleres.js` | Eliminar o dotarlo de las mismas guardas que sus hermanos | Bajo |
| A13 | Baja | God-provider emergente: `alert_provider.dart` (582 líneas) mezcla UI state + acceso directo a Firestore + lógica de negocio | — | Extraer `AlertRepository` | Medio |
| A14 | Baja | Carrera menor en `kilometraje_actual` (asignación directa, no transaccional) | — | Usar `FieldValue.increment`/transacción | Bajo |
| A15 | Baja | Rol admin representado con dos strings (`'Administrador'`/`'admin'`) | `firestore.rules:30`, `storage.rules:14` | Unificar constante | Trivial |
| A16 | Baja (corregido en debate) | ~~`app.env` tracked en git~~ — **verificado FALSO** (no está en `git ls-files` ni en `git log --all`). El hallazgo real que sí sobrevive: la misma clave de API se reutiliza localmente entre Firebase Android, Google Maps y Google Custom Search | `.env` local (no versionado) | Usar claves distintas y restringidas por servicio en Google Cloud Console, por higiene | Bajo |

**Puntuaciones del panel:** Arquitectura 58/100 · Escalabilidad 55/100 · DB/Cloud reliability 62/100.

### 8.2 Seguridad (Security Engineer)

| # | Severidad | Hallazgo | Evidencia | Recomendación | Esfuerzo |
|---|---|---|---|---|---|
| S1 | Alta | Contraseña temporal fija para cuentas creadas por Superusuario (= A2) | `functions/index.js:1333` | Ver A2 | Bajo |
| S2 | Media | Oráculo de enumeración de correos (= A3), cierre depende de App Check no verificable desde el repo | `functions/index.js:1028-1092`; `lib/main.dart:111-132` (App Check "no bloqueante" en cliente) | Ver A3 | Medio |
| S3 | Baja | `reservas.create` sin validar relación previa (riesgo residual ya reconocido por el equipo) | — | Añadir validación de relación | Bajo |
| S4 | Baja | Scripts de backfill sin guarda **programática** (solo comentarios) contra ejecución accidental en producción | `functions/src/*.js` | Guard por variable de entorno `NODE_ENV`/proyecto | Bajo |

**Verificado limpio:** sin API keys/claves privadas/service accounts hardcodeadas en el repo versionado; `secrets.dart`/`firebase_options.dart` usan exclusivamente `--dart-define`; reglas de Firestore leen el rol siempre del documento almacenado; landing Next.js 100% estático sin rutas API expuestas.

**Puntuación del panel:** Seguridad 74/100. Ningún hallazgo individual bloquea el lanzamiento, pero S1 y S2 deben resolverse antes o inmediatamente después de salir a producción.

### 8.3 DevOps / SRE / Performance

| # | Severidad | Hallazgo | Evidencia | Recomendación | Esfuerzo |
|---|---|---|---|---|---|
| D1 | Alta | Sin rollback automático en `deploy_production` ante fallo parcial | `.github/workflows/ci.yml:317-473` | Ver A11 | Medio |
| D2 | Alta | Errores capturados (68 `try/catch` + `debugPrint` en 13 archivos) nunca llegan a Crashlytics — solo `FlutterError.onError`/`PlatformDispatcher.onError` global | `lib/main.dart:138-144` | Reportar explícitamente a Crashlytics en cada catch relevante | Medio |
| D3 | Alta | Triggers de Firestore sin `failurePolicy`/reintentos — fallos transitorios de FCM se pierden silenciosamente | `functions/index.js` (0 usos de `functions.runWith`) | Configurar reintentos con backoff | Bajo-Medio |
| D4 | Alta | Notificaciones enviadas secuencialmente sin batching en `sendReservationReminders`/`checkAlertsDaily` | `functions/index.js:685-759, 66-161` | Batch + paginación con checkpoint de progreso | Medio |
| D5 | Media | Sin compresión de imágenes antes de subir, contra límite de 5MB en reglas | `vehicle_photo_service.dart:49-55` vs `storage.rules:35` | Comprimir client-side antes de subir | Bajo |
| D6 | Media | `FIREBASE_TOKEN` deprecado en vez de OIDC/service account | CI/CD deploy jobs | Migrar a Workload Identity Federation | Medio |
| D7 | Media | Gate de cobertura en 8% — honesto en origen, pero cubre ~1,200/13,988 líneas | `ci.yml` (ver también sección QA) | Ver 8.4 | — |

**Fortalezas verificadas:** paginación correcta con cursor (`limit(500)` + `startAfter`) en scheduled functions, agregados por-documento (no hot-document global), smoke test post-deploy real, rules tests contra emulador en cada PR.

**Puntuaciones del panel:** DevOps 58/100 · Observabilidad 35/100 · Rendimiento 50/100.

**¿Qué pasa con miles de usuarios concurrentes?** El hallazgo D4 (notificaciones secuenciales sin batching) es el más directamente ligado a esto: con miles de reservas/alertas activas, el riesgo de exceder el timeout de Cloud Functions y perder notificaciones sin checkpoint es real y no hipotético.

### 8.4 QA / Testing

| # | Severidad | Hallazgo | Evidencia | Recomendación | Esfuerzo |
|---|---|---|---|---|---|
| Q1 | **Crítica** | Tests de integración que siempre pasan sin ejecutar el flujo real | `integration_test/auth_flow_test.dart`, `alert_flow_test.dart`: 0 `expect()`; `vehicle_flow_test.dart`: 1 `expect()` dentro de `if (...isNotEmpty)` sin `else` | Reescribir con aserciones reales que fallen si el flujo no corre; correrlos en CI | Medio |
| Q2 | Alta | Gate de cobertura fijado en 8% *a partir de* la medición existente (1213/13988 líneas), no al revés | `ci.yml` comentario explícito | Subir el mínimo progresivamente en cada sprint | Bajo (proceso) |
| Q3 | Alta | 16 archivos de negocio activos sin ningún test, incluyendo `auth_service.dart`, `user_service.dart`, `reserva_repository.dart`/`provider.dart`, `workshop_service.dart` | Conteo directo de `lib/` vs `test/` | Priorizar tests unitarios en servicios de auth y reservas | Alto |
| Q4 | Alta | 6 de 14 colecciones de Firestore sin test adversarial (`conversaciones`/`mensajes`, `admin_logs`, `alertas`, `mantenimientos`, `historial_mantenimientos`, `notificaciones`) | `firestore.rules` (639 líneas) vs 11 `.test.js` en `test_rules/` | Extender tests de reglas a las colecciones faltantes, siguiendo el patrón adversarial ya usado en `usuarios.test.js` | Medio |
| Q5 | Alta | `functions/index.js` (1446 líneas), incluida lógica que bypasea reglas de Firestore vía Admin SDK, sin ningún test automatizado | `aggregateRatings`, `crearEmpleadoTaller`, `superUserDeleteAccount` | Suite de tests con emulador para Cloud Functions | Alto |
| Q6 | Media | `e2e/` (Playwright, 3 specs) no corre en CI | — | Añadir job de CI o eliminar si está obsoleto | Bajo |
| Q7 | Alta (proceso) | CI estuvo en rojo ≥10 días antes de corregirse; el commit de fix mezcló 6 cambios de producto no relacionados bajo la etiqueta "fix(ci)" | Diff de `39c6231` | Comits atómicos; alertar cuando `main` tiene CI roto | Bajo (proceso) |
| Q8 | Media | Sin checklist de QA/UAT manual real, más allá de un ítem genérico en el runbook | `docs/RUNBOOK.md` | Definir checklist de regresión manual pre-release | Bajo |

**Puntuaciones del panel:** Testing 22/100 · Calidad de código (lente QA) 48/100.

### 8.5 Frontend / UX / Accesibilidad

> Todos los hallazgos de esta sección son **[VERIFICADO EN CÓDIGO]** salvo indicación contraria; ninguno fue confirmado con navegador/lector de pantalla real por la limitación de herramientas ya declarada.

| # | Severidad | Hallazgo | Evidencia | Recomendación | Esfuerzo |
|---|---|---|---|---|---|
| F1 | Alta | 49% de archivos (48/98) usan `Colors.*`/`Color(0x...)` hardcodeado, violando CONVENTIONS.md | 452 ocurrencias; top: `profile_setup_screen.dart` (53) | Migrar a `AppColors`/tema | Medio |
| F2 | Alta | Contraste WCAG insuficiente en `error`/`warning`/`success` en modo claro, usado en `SnackBar`s de error críticos | Blanco/`lightError` 2.44:1, `lightWarning` 1.90:1, `lightSuccess` 2.43:1 (umbral AA 4.5:1) | Ajustar los 3 valores de paleta o los ~8 sitios de uso | Bajo |
| F3 | Alta | `Semantics`/`semanticLabel` casi inexistentes (1 archivo, 0 `semanticLabel` en toda la app) | 41 `IconButton`, solo 6 archivos con `tooltip` | Añadir Semantics a controles interactivos, priorizando flujos críticos | Alto |
| F4 | Alta | `auth_screen.dart` sin `Form`/`TextFormField`/`validator` — validación imperativa con `SnackBar` transitorio | — | Migrar a `Form` con validación inline por campo | Medio |
| F5 | Alta | 71% de pantallas (12/17) con `Stream`/`FutureBuilder` sin manejo de `hasError` | — | Añadir rama de error explícita | Medio |
| F6 | Media-Alta | `AppEmptyState`/`AppSnackbar` con 0 usos reales pese a existir; 21 archivos usan `ScaffoldMessenger` ad-hoc | — | Adoptar los widgets ya construidos | Medio |
| F7 | Media-Alta | 53% de archivos (52/98) con `fontSize` hardcodeado; solo 32% importa `Responsive` | 331 ocurrencias | Migrar a `AppTextStyles`/`Responsive` | Medio |
| F8 | Media | Sin clamp de `textScaler` del sistema — riesgo de overflow con accesibilidad de texto grande | `lib/main.dart` | Clamp de `textScaler` | Bajo |
| F9 | Media | `plate_formatter.dart` tiene mensajes de error hardcodeados en español mientras el resto del formulario usa `l10n` | líneas 72, 75 | Mover a `l10n` | Trivial |
| F10 | Media | `web/index.html` sin `<meta name="viewport">` | — | Añadir meta viewport | Trivial |
| F11 | Baja-Media | Sin loader/spinner en `<body>` inicial — riesgo de "flash blanco" en carga | `web/index.html` | Añadir splash/loader | Bajo |
| F12 | Baja | `EdgeInsets` numérico hardcodeado (61 ocurrencias) pese a existir `AppSpacing` | — | Migrar progresivamente | Bajo |

**Puntuaciones del panel:** UX 58/100 · **Accesibilidad 28/100** (confianza reducida explícitamente por falta de validación en vivo) · Consistencia Frontend 45/100.

### 8.6 Producto / Negocio

| # | Severidad | Hallazgo | Evidencia | Recomendación | Esfuerzo |
|---|---|---|---|---|---|
| P1 | Alta | Política de privacidad contradice el código real de borrado (dice "ofuscar", el código hace hard delete y no limpia chat) | `docs/privacy_policy.md` §4 vs `functions/index.js:767-802` | Alinear texto con implementación real | Bajo-Medio |
| P2 | Alta | Aprobación de talleres es un clic sin criterios documentados; existe script de aprobación masiva sin salvaguardas (= A12) | `admin_service.dart:144-153`; `aprobarTodosTalleres.js` | Definir checklist real de verificación; eliminar o resguardar el script | Medio |
| P3 | Media-Alta | ToS genérico: sin cláusula de menores, sin jurisdicción concreta, "verificación" de talleres no definida | `docs/terms_of_service.md` (24 líneas) | Revisión legal | Medio |
| P4 | Media | Contactos de escalación de incidentes vacíos (`[EMAIL]` sin rellenar en las 5 filas) pese a runbook por lo demás completo | `docs/RUNBOOK.md` §10 | Completar antes de lanzamiento | Trivial |
| P5 | Alta (informativo) | Cero código de monetización — producto pre-revenue, ToS confirma "uso gratuito" | grep de stripe/payment/pago/cobro | Definir modelo de negocio antes de escalar costos de Firebase | — |
| P6 | Media→Alta con crecimiento | Dashboard admin abre 6 listeners sin `limit()` sobre colecciones completas solo para contar | `admin_service.dart:238-330` | Usar contadores agregados en vez de listeners completos | Medio |

**Puntuación del panel:** Producto/negocio 46/100. **Mayor riesgo de negocio:** la plataforma no puede cobrar nada mientras asume el riesgo reputacional completo de un marketplace de confianza sin proceso real de verificación de talleres.

## 9. Checklist completo de producción

| Área | Estado | Nota |
|---|---|---|
| Arquitectura en capas respetada | ⚠️ | Violada en 12+ archivos (A1) |
| Gestión de secretos | ✅ | Sin secretos versionados; `--dart-define` en todo lado |
| Reglas Firestore/Storage least-privilege | ✅ | Con historial de hardening documentado |
| Autenticación/autorización server-side | ✅ | Rol siempre leído del documento almacenado |
| Rate-limiting en endpoints sensibles | ❌ | Oráculo de correo sin mitigar (A3/S2) |
| Backups verificados | ❌ | Sin alerta de fallo (A5) |
| CI con gates reales | ⚠️ | Existen, pero coverage 8% y estuvo roto 10+ días (Q2, Q7) |
| Tests de integración/E2E funcionales | ❌ | Pasan sin ejecutar el flujo real (Q1) |
| Cobertura de tests de reglas de Firestore | ⚠️ | 8/14 colecciones cubiertas (Q4) |
| Rollback automatizado en deploy | ❌ | No existe (A11/D1) |
| Observabilidad (Crashlytics/logging estructurado) | ❌ | Errores capturados no llegan a Crashlytics (D2) |
| Manejo de errores en Cloud Functions | ⚠️ | Sin reintentos/dead-letter (D3) |
| Rendimiento a escala (notificaciones, jobs) | ⚠️ | Sin batching en jobs masivos (D4) |
| Accesibilidad | ❌ | 28/100, casi sin Semantics |
| Consistencia de diseño (colores/tipografía) | ⚠️ | ~50% de archivos violan CONVENTIONS.md |
| Localización | ✅ | 100% sincronizada ES/EN |
| Documentación legal (ToS/Privacidad) | ⚠️ | Genérica y con contradicción con el código |
| Runbook operativo | ⚠️ | Real y detallado, pero contactos de escalación vacíos |
| Moderación/vetting de contenido y talleres | ❌ | Un clic sin criterios |
| Monetización | ❌ | Inexistente (aceptable si es pre-revenue por decisión, riesgoso si no) |
| Aislamiento de entornos (dev/staging/prod) | ✅ | Proyectos GCP separados, jobs por rama |

## 10. Acciones priorizadas (antes de producción)

1. Reescribir `integration_test/*` con aserciones reales o eliminarlos del "sistema de confianza" (Q1) — **bloqueante de confianza**.
2. Eliminar la contraseña hardcodeada compartida de Superusuario (A2/S1).
3. Confirmar/activar enforcement real de App Check en consola de Firebase para `buscarPropietarioPorCorreo`, o añadir rate-limiting propio (A3/S2).
4. Verificar que `scheduledFirestoreExport` realmente produce backups y alertar ante fallo (A5).
5. Eliminar o resguardar `aprobarTodosTalleres.js` (A12/P2).
6. Completar la tabla de contactos de escalación en `RUNBOOK.md` (P4).
7. Corregir el contraste WCAG de `error`/`warning`/`success` en modo claro (F2).
8. Alinear la política de privacidad con el comportamiento real de `onUserDelete` (P1).

## 11. Quick Wins (bajo esfuerzo, impacto real)

- Corregir el índice huérfano `"Servicios"`→`servicios` (A9).
- Añadir `<meta name="viewport">` a `web/index.html` (F10).
- Mover los mensajes de error de `plate_formatter.dart` a `l10n` (F9).
- Añadir `tooltip`/`semanticLabel` a los 41 `IconButton` existentes (parte de F3, incremental).
- `get()` antes de `delete()` en `publishTallerProfile` (A6).
- Comprimir imágenes client-side antes de subir (D5).

## 12. Mejoras estratégicas

- Migrar todas las llamadas Firebase de `presentation/` a la capa `data/` (A1) con un lint custom que lo prevenga a futuro.
- Sustituir `FIREBASE_TOKEN` por Workload Identity Federation en CI/CD (D6).
- Definir un modelo de monetización antes de escalar el gasto en lecturas Firestore (P5/P6).
- Programa de accesibilidad dedicado (Semantics, contraste, textScaler) antes de que la superficie de UI siga creciendo.

## 13. Deuda técnica

Fugas de arquitectura (A1), god-provider emergente (A13), inconsistencia de diseño (F1/F7/F12), 16 servicios sin test (Q3), doble representación del rol admin (A15). Ninguna es urgente aislada, pero juntas explican por qué el coverage real es 8.7% pese a la disciplina de proceso visible en otras áreas.

## 14. Riesgos para el negocio

Ver secciones 6 y 8.6: contradicción legal/técnica en privacidad, vetting de talleres inexistente, cero monetización, contactos de incidente vacíos.

## 15. Riesgos técnicos

Ver 8.1-8.4: fugas de capas, falta de reintentos, tests de integración inertes, 6 colecciones sin test adversarial.

## 16. Riesgos operativos

Backup sin verificación (A5), sin rollback automatizado (A11/D1), errores que no llegan a Crashlytics (D2), CI que estuvo roto sin alertar 10+ días (Q7).

## 17. Riesgos de escalabilidad

Jobs de notificación sin batching (D4), listeners admin sin límite (P6), triggers costosos por escritura de cualquier usuario (A6), queries sin índice compuesto filtrando en memoria (A7).

## 18. Riesgos de seguridad

Contraseña compartida hardcodeada (A2/S1), oráculo de enumeración sin mitigar (A3/S2). Ninguno confirmado como bloqueante aislado, pero ambos de prioridad alta y esfuerzo bajo — deberían cerrarse antes del lanzamiento, no "después".

## 19. Escenarios extremos ("what-if")

- **¿Qué pasa si falla `firebase deploy --only functions` a mitad de camino en producción?** No hay rollback automático; el smoke test detecta el problema después de que ya impactó producción (A11/D1).
- **¿Qué pasa si el bucket de backups nunca existió?** Nadie lo sabría — `scheduledFirestoreExport` solo hace `console.error` (A5).
- **¿Qué pasa si alguien filtra el repo (aunque sea privado) hoy?** Cualquier cuenta de Superusuario reciente es tomable con la contraseña hardcodeada hasta que el titular la cambie (A2).
- **¿Qué pasa con miles de reservas activas el mismo día?** `sendReservationReminders` puede exceder el timeout de Cloud Functions al enviar secuencialmente sin checkpoint (D4).
- **¿Qué pasa si un desarrollador nuevo corre `aprobarTodosTalleres.js` contra producción por error?** Aprueba todos los talleres sin criterio y sin dejar rastro en `admin_logs` — no tiene ninguna de las guardas que sí tienen sus scripts hermanos (A12).
- **¿Qué pasa si un usuario con lector de pantalla intenta usar la app?** Con 0 `semanticLabel` en toda la app, es razonable esperar que gran parte de la UI sea inoperable (F3) — no verificado en vivo, pero la señal de código es unánime.

## 20. Puntuaciones (0-100)

| Dimensión | Puntuación |
|---|---|
| Arquitectura | 58 |
| Calidad del código | 48 |
| Seguridad | 74 |
| Rendimiento | 50 |
| Escalabilidad | 55 |
| DevOps | 58 |
| Testing | 22 |
| Observabilidad | 35 |
| Mantenibilidad | 50 |
| UX | 58 |
| Documentación | 60 |
| *(Accesibilidad — fuera de la lista estándar pero crítica aquí)* | *28* |

## 21. Veredicto final

### ⚠️ Apto con condiciones — **no apto tal como está hoy**

No se encontró ningún hallazgo de seguridad que, aislado, obligue a bloquear el lanzamiento. Pero el conjunto de evidencia —tests de integración que dan una falsa sensación de cobertura (Q1), 8.7% de cobertura real, una contraseña compartida hardcodeada, un vector de enumeración reconocido y sin cerrar, un backup no verificado, un script administrativo sin salvaguardas, y una accesibilidad prácticamente inexistente— configura un perfil de riesgo incompatible con un lanzamiento comercial responsable sin antes resolver la lista de la sección 10.

**Condición para pasar a ✅ Apto para producción:** resolver los 8 puntos de la sección 10 (todos de esfuerzo bajo-medio, ninguno requiere rediseño), y comprometerse a un plan de aumento progresivo del gate de cobertura y de accesibilidad post-lanzamiento (secciones 11-12).

---

*Metodología: 6 auditorías paralelas independientes con mandato adversarial explícito, verificación cruzada manual de discrepancias (incluyendo una corrección confirmada: `app.env` NO está versionado en git, contrario a una afirmación inicial — ver hallazgo A16), y síntesis final. Limitación declarada: sin validación en navegador real (Playwright no disponible en esta sesión).*
