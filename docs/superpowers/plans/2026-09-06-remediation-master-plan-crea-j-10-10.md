# 🎯 Remediation Master Plan — camino a 10/10 CREA J 2026

> **Para agentes:** ejecutar tarea por tarea con `executing-plans`; no iniciar una tarea dependiente sin su gate de evidencia. No se autoriza despliegue a producción ni uso de cuentas reales para QA. Usar emuladores/fixtures aislados.

**Objetivo:** eliminar los defectos y vacíos de evidencia que impiden defender 10/10, y producir una demostración reproducible según la rúbrica CREA J 2026.

**Arquitectura:** conservar Flutter + Provider + GoRouter + Firebase. Corregir primero los controles servidor y los flujos de identidad, luego su UI, y demostrar cada relación UI → Firebase mediante emuladores, Playwright y pruebas de reglas. No introducir microservicios ni reescrituras.

**Stack:** Flutter/Dart, Firebase Auth/Firestore/Storage/Functions, Provider, GoRouter, Jest + `@firebase/rules-unit-testing`, Mocha, Playwright, Graphify.

## Restricciones globales

- Base de evidencia: `docs/AUDITORIA_CREA_J_2026_CODEX.md` (64/100), no repetir auditoría antes de implementar.
- S1 (PDF de NIT) tiene prioridad de proyecto; confirmar asignación antes de editar para no duplicar trabajo.
- Todo copy visible Flutter se localiza en `lib/l10n/app_es.arb` y `app_en.arb`.
- Las reglas y Functions son la barrera de autorización; los guards de UI sólo complementan.
- Nuevas pruebas deben usar Auth/Firestore/Storage emulator y fixtures efímeros, nunca producción.
- Cada cambio de auth, reglas, schema o navegación exige regresión antes de avanzar.

---

## 1. Estado actual

| Métrica | Baseline |
|---|---:|
| Puntuación | **64/100** |
| Amigabilidad | 15/20 |
| Roles | 7/10 |
| Seguridad | 10/20 |
| BD | 7/10 |
| Funcionalidad | 10/20 |
| Creatividad | 15/20 |
| Críticos conocidos | 2 |
| Altos conocidos | 4 |
| Medios conocidos | 9+ |
| Tests fallidos/inconclusos | E2E histórico con 2 fallos; reglas sin resultado concluyente |
| No verificados críticos | correo real, roles multiusuario, CRUD+refresh, triggers/scheduler, App Check enforcement |

Los puntos perdidos no se recuperan por intención: sólo con comportamiento probado y evidencia enlazable.

## 2. Gap hacia 10/10

| Criterio | Qué falta para máximo |
|---|---|
| Amigabilidad 20/20 | recorridos completos mobile, navegación/errores recuperables, accesibilidad y landing sin CTAs rotos |
| Roles 10/10 | vocabulario canónico y pruebas UI+reglas+callables para permitir y denegar cada acción |
| Seguridad 20/20 | correo obligatorio, credenciales de un uso, anti-enumeración, recovery/session/logout y enforcement externo demostrados |
| BD 10/10 | CRUD real con refresh, reglas, relaciones y recuperación ante fallo parcial |
| Funcionalidad 20/20 | todos los flujos principales en verde, incluidos NIT PDF, cotizaciones, reseñas, cron/notificaciones verificables |
| Creatividad 20/20 | demo robusta de los diferenciadores existentes; sólo añadir una innovación si el juez aún no ve diferenciación |

## 3. Matriz completa de deficiencias

| ID | Problema | Sev. | Criterio | Corrección requerida | Evidencia de cierre |
|---|---|---|---|---|---|
| SEC-01 | contraseña temporal global fija | P0 | Seguridad | enlace de primera configuración, secreto aleatorio expirable y no retornable | callable/emulador: token único, expirado y reutilizado denegados |
| SEC-02 | email verificado no obligatorio | P0 | Seguridad | gate servidor y router; retirar continuar sin verificar | registro/login E2E: no llega a datos protegidos sin verificar |
| SEC-03 | enumeración correo→PII | P0 | Seguridad | reemplazar consulta por flujo consentimiento/relación; mínimo dato y rate limit | callable cross-account denegado y test anti-enumeración |
| VER-01 | NIT PDF inalcanzable | P0 | Funcionalidad | usar `file_picker` para NIT y mantener `image_picker` para imagen | widget+Playwright selecciona PDF y Storage emulator lo acepta |
| DATA-01 | cotización pública/privada no atómica | P1 | BD/Funcionalidad | batch/transaction o compensación idempotente | fallo de segunda escritura no deja estado público inconsistente |
| ROLE-01 | normalización UI ≠ reglas | P1 | Roles | enum/vocabulario canónico + migración de valores heredados | matriz de rol con variantes históricas |
| QA-01 | CRUD/roles/triggers no demostrados | P1 | BD/Funcionalidad | harness de emuladores, fixtures y Playwright por rol | C/U/D+refresh y denegaciones PASS |
| UX-01 | contacto y CTA App Store rotos | P1 | UX/Funcionalidad | formulario funcional o enlace `mailto`, CTA iOS válido/no visible | Playwright submit y link final verifican destino |
| UX-02 | errores y deep links sin recuperación | P1 | UX | retry, 404 localizada con Inicio, hosting SPA probado | Playwright error/retry y recarga deep link PASS |
| FUNC-01 | edición de reseña descarta fotos | P2 | Funcionalidad | conservar/reemplazar/eliminar fotos explícitamente | servicio+widget+Storage emulator PASS |
| FUNC-02 | APIs de reparación obsoletas | P2 | Funcionalidad | eliminar o encapsular rutas `@Deprecated` tras migración | análisis sin consumidor y regresión Kanban |
| UX-03 | movimiento, navegación móvil y semántica landing | P2 | UX | reduced motion, menú accesible y HTML válido | Playwright viewport/teclado + test reducido |
| UX-04 | errores Firestore crudos | P2 | UX | mensaje localizado, acción reintentar, sin detalle interno | widget test de error y Playwright |
| SEC-04 | App Check/enforcement no demostrable | P2 | Seguridad | registrar configuración/verificación reproducible de consola y rechazo emulable donde aplique | runbook con captura/resultado y prueba negativa |
| OPS-01 | cron/backup/notificaciones no demostrados | P2 | Funcionalidad | extraer lógica pura, ejecutar scheduler/function con fixtures y documentar prerequisitos | tests de función + evidencia de entorno staging |
| QA-02 | suite reglas deja procesos/puertos | P3 | Evidencia | teardown determinista y script único de emuladores | `npm test` de reglas termina con exit 0 y puertos liberados |
| INNO-01 | innovación no demostrada | P3 | Creatividad | guion/demo de mapa, QR, alertas y PDF; añadir QR temporal sólo si el mock judge no concede 20 | demo Playwright/staging y veredicto independiente |

### P0 — bloqueantes

| Task | Razón de bloqueo | Cierre mínimo |
|---|---|---|
| VER-01 | documento obligatorio del taller no puede ser PDF real | seleccionar, subir, refrescar y abrir PDF en emulador |
| SEC-01 | cuentas privilegiadas reciben una credencial predecible | invitación única/expirable sin contraseña retornada |
| SEC-02 | la propiedad del correo no condiciona el acceso | usuario no verificado no cruza gate ni llama APIs protegidas |
| SEC-03 | PII se enumera por correo arbitrario | respuesta indistinguible sin relación autorizada |

### P1 — alto impacto

| Task | Razón | Cierre mínimo |
|---|---|---|
| DATA-01 | cotización puede quedar inconsistente | atomicidad o recuperación idempotente demostrada |
| ROLE-01 | UI y backend pueden discrepar sobre rol | contrato canónico probado con datos heredados |
| QA-01 | no hay evidencia multirol/CRUD | matriz C/U/D+refresh y denies PASS |
| UX-01 | contacto/CTA prometen flujos que no terminan | submit y enlaces reales en ES/EN |
| UX-02 | errores/deep links varan al usuario | retry/404/ruta recargada PASS |

### P2 — importante

`FUNC-01`, `FUNC-02`, `UX-03`, `UX-04`, `SEC-04` y `OPS-01`: corrigen calidad, resiliencia, accesibilidad y evidencia de operación antes del mock evaluation.

### P3 — pulido

`QA-02` asegura limpieza de emuladores y `INNO-01` se ejecuta sólo si el juez aún no considera demostrable la creatividad máxima.

## 3.1 Objetivo verificable por criterio

| Criterio | Impedimento actual | Cambio y demostración necesarios para máximo |
|---|---|---|
| Amigabilidad 20/20 | CTAs/errores, navegación móvil y accesibilidad incompletos | UX-01..04 + Playwright en cuatro viewports, teclado, reduced motion, loading/error/empty y deep links |
| Roles 10/10 | vocabulario desigual y matriz runtime ausente | ROLE-01 + QA-01: permitir/denegar UI, reglas y callable por rol |
| Seguridad 20/20 | credencial fija, correo opcional, enumeración y enforcement externo no evidenciado | SEC-01..04 + Auth emulator: invitación, verificación, recovery, logout, negativos |
| BD 10/10 | no se ve persistencia real/recuperación | DATA-01 + QA-01: CRUD/refresco, relaciones, reglas y error parcial |
| Funcionalidad 20/20 | PDF NIT, reseñas y tareas automáticas sin prueba completa | VER-01, DATA-01, FUNC-01/02, OPS-01 y flujos E2E PASS |
| Creatividad 20/20 | valor diferencial no demostrado | demo de capacidades actuales; INNO-01 sólo si el juez exige evidencia adicional |

## 4. Priorización y dependencias

```text
VER-01 ──┐
SEC-01 ──┼─> QA-01 ─> H-01 (matriz Playwright) ─> FINAL-01
SEC-02 ──┤
SEC-03 ──┤
ROLE-01 ─┘

DATA-01 ─┐
FUNC-01 ─┼─> QA-01
FUNC-02 ─┘

UX-01 ─┐
UX-02 ─┼─> H-01
UX-03 ─┤
UX-04 ─┘

SEC-04 + OPS-01 + QA-02 ─> HARDEN-01 ─> FINAL-01
INNO-01 se decide sólo tras H-01.
```

## 5. Workstreams

| Stream | Tareas | Gate |
|---|---|---|
| A — Verificación de talleres | VER-01 | PDF NIT llega a Storage emulator y se abre desde ambas vistas |
| B — Auth y seguridad | SEC-01..04 | registro, login, recovery, sesión y ataques negativos PASS |
| C — Roles/autorización | ROLE-01, QA-01 | matriz UI + reglas + callable PASS |
| D — Datos/funcionalidad | DATA-01, FUNC-01, FUNC-02, OPS-01 | CRUD+refresh, triggers y recuperación de fallo PASS |
| E — UX/responsive | UX-01..04 | 320/375/390/414 y teclado/errores PASS |
| F — QA/hardening | QA-02, H-01, FINAL-01 | suites limpias y auditoría adversarial renovada |
| G — Creatividad | INNO-01 | demo juzgable, sin feature creep |

## 6. Plan por fases y score gates

| Fase | Entregable | Score defendible si pasa todo |
|---|---|---:|
| 0 — baseline | congelar evidencia, fixtures y scripts | 64 |
| 1 — bloqueantes | VER-01, SEC-01..03 | 72–78 |
| 2 — roles/seguridad | ROLE-01, SEC-04, primeras matrices | 80–85 |
| 3 — datos/funciones | DATA-01, FUNC-01/02, CRUD/triggers | 87–92 |
| 4 — UX móvil | UX-01..04 | 92–96 |
| 5 — estabilidad | OPS-01, QA-02, regresiones | 94–97 |
| 6 — creatividad | INNO-01 sólo si necesaria | 96–100 potencial |
| 7 — hardening | H-01 | no asignar nota; cerrar evidencia |
| 8 — mock evaluation | FINAL-01 | única fuente de la nota nueva |

## 7. Tareas ejecutables

### VER-01 — PDF NIT alcanzable desde el taller

**Prioridad:** P0 · **Rúbrica:** Funcionalidad, BD, UX.  
**Áreas:** `workshop_verification_screen.dart`, `pubspec.yaml`, `storage.rules`, `test/.../workshop_verification_screen_test.dart`, `test_rules/storage.test.js`, ARB.

- [ ] Escribir primero un widget test que simule selección de `application/pdf` para slot `nit` y pruebe nombre/tamaño/icono antes de subir.
- [ ] Sustituir sólo la ruta de selección de `nit` por `FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf','jpg','jpeg','png'])`; conservar la cámara/galería de imágenes para los otros slots.
- [ ] Normalizar el resultado a la abstracción existente de archivo pendiente; prohibir MIME/extensión no permitidos antes de iniciar upload.
- [ ] Añadir prueba de reglas Storage: NIT PDF válido permitido; PDF en otro slot y MIME falso denegados.
- [ ] Añadir Playwright/emulador: seleccionar PDF fixture, confirmar, refrescar y abrir la evidencia como admin.

**Aceptación:** PDF real seleccionable, previsualización textual, upload permitido sólo para NIT y visibilidad admin conservada. **Evidencia:** `EVID-VER-001..003`. **Regresión:** imágenes, reabrir verificación y viewer existente.

### SEC-01 — Provisionamiento sin contraseña compartida

**Prioridad:** P0 · **Rúbrica:** Seguridad/Roles.  
**Áreas:** `functions/index.js`, módulos Functions de usuario/admin, tests Mocha, pantalla/admin de creación y textos.

- [ ] Escribir tests de función: cada invitación crea URL/token distinto; token usado/expirado devuelve error genérico; la respuesta callable no contiene contraseña.
- [ ] Crear con Admin SDK un enlace de restablecimiento/configuración de Firebase Auth; persistir únicamente metadata no sensible (UID, emisor, creación, expiración, estado) si el flujo requiere trazabilidad.
- [ ] Invalidar/revocar invitación previa al regenerarla; no guardar ni loguear el enlace/secret.
- [ ] Reemplazar UI de “contraseña temporal” por estado “invitación enviada/copiada de forma segura” y no permitir Administrador sin proceso de primer acceso.
- [ ] Ejecutar pruebas Functions y un E2E contra Auth emulator de primera configuración.

**Aceptación:** no hay literal de contraseña compartida ni secreto retornado; una invitación es única, expira y no se reutiliza. **Evidencia:** `EVID-SEC-010..014`.

### SEC-02 — Verificación de correo obligatoria

**Prioridad:** P0 · **Rúbrica:** Seguridad/Funcionalidad.  
**Áreas:** `auth_screen.dart`, `auth_provider.dart`, `auth_service.dart`, `auth_session_provider.dart`, `app_router.dart`, reglas/callables que necesiten claim, tests auth/router, E2E.

- [ ] Escribir tests que fallen: usuario no verificado sólo puede ver pantalla de verificación/reenvío/logout; navegación directa a dashboard vuelve al gate.
- [ ] Definir allowlist de rutas públicas/no verificadas y aplicar redirect único en router; retirar la opción de continuar sin verificar.
- [ ] Tras confirmar el enlace, recargar `FirebaseAuth.currentUser`, actualizar sesión y dirigir a profile setup/dashboard sólo entonces.
- [ ] Para cada callable que crea datos privilegiados, comprobar `context.auth.token.email_verified === true` cuando sea compatible con el flujo; documentar excepciones mínimas.
- [ ] Ejecutar Auth emulator: registro, reenvío, token verificado, login sin verificar, logout y ruta directa.

**Aceptación:** ningún usuario no verificado crea/consulta datos protegidos; reenvío e ingreso posterior funcionan. **Evidencia:** `EVID-AUTH-020..027`.

### SEC-03 — Eliminar oráculo correo→PII

**Prioridad:** P0 · **Rúbrica:** Seguridad/BD.  
**Áreas:** `functions/index.js:1670-1722`, consumidores Flutter, pruebas Functions/reglas.

- [ ] Escribir pruebas negativas con dos cuentas: correo existente/inexistente producen respuesta indistinguible para quien no tiene relación autorizada.
- [ ] Reemplazar búsqueda arbitraria por identificador de relación/ticket o solicitud consentida; devolver sólo el mínimo dato necesario y nunca UID/correo ajeno.
- [ ] Verificar rol, relación activa y límite de intentos por emulador o control servidor disponible; registrar auditoría sin PII de consulta.
- [ ] Eliminar el consumidor/UI que acepte correo libre si no puede cumplir el contrato nuevo.

**Aceptación:** no se puede deducir existencia ni datos de un propietario sin relación. **Evidencia:** `EVID-SEC-030..034`.

### DATA-01 — Cotización consistente ante fallos

**Prioridad:** P1 · **Rúbrica:** BD/Funcionalidad.  
**Áreas:** `chat_repository.dart:193-237`, modelos de cotización, reglas `cotizaciones`, tests repositorio/reglas/Functions.

- [ ] Crear prueba que fuerce error de la escritura privada y compruebe que no queda cotización pública utilizable.
- [ ] Migrar las dos escrituras a batch atómico cuando las rutas compartan Firestore; si hay dependencia inevitable, crear estado `draft/pending` que sólo se publica tras confirmar privado y limpiar/reintentar idempotentemente.
- [ ] Ajustar reglas para que clientes no puedan publicar estado final sin el contrato privado exigido.
- [ ] E2E emulator: crear, refrescar, aceptar y disparar ticket una sola vez.

**Aceptación:** cero cotizaciones públicas incompletas y aceptación idempotente. **Evidencia:** `EVID-DB-010..015`.

### ROLE-01 — Contrato canónico de roles

**Prioridad:** P1 · **Rúbrica:** Roles/Seguridad.  
**Áreas:** `role_utils.dart`, `UserModel`, `firestore.rules:27-50`, providers/router, scripts de migración, pruebas Flutter/rules.

- [ ] Definir vocabulario persistido único (`Propietario`, `Mecanico`, `Taller`, `Administrador`, `Superusuario`) y parser de compatibilidad sólo en migración/lectura.
- [ ] Hacer que UI y reglas comparen el mismo conjunto; no autorizar con cadenas normalizadas que Firestore rechaza.
- [ ] Crear migración administrada, dry-run por defecto, con conteo de documentos heredados y rollback documentado.
- [ ] Probar cada rol canónico y variante heredada en router, reglas y callables.

**Aceptación:** ninguna cuenta ve capacidad que el backend le niega; migración no eleva privilegios. **Evidencia:** `EVID-ROLE-010..018`.

### QA-01 — Harness reproducible multirol y CRUD

**Prioridad:** P1 · **Rúbrica:** BD, Roles, Funcionalidad.  
**Áreas:** `test_rules/`, `test/firestore_rules/`, `e2e/`, helpers de fixtures y `firebase.json`.

- [ ] Crear fixtures explícitos para propietario A/B, taller A/B, admin y superusuario; nunca usar usuarios de producción.
- [ ] Cubrir por entidad: create → refresh → read → update → refresh → delete → refresh; incluir vehículos, chat, cotización, reserva, reparación, reseña y taller.
- [ ] Cubrir deny cases cross-tenant y bypass por deep link/callable para cada rol.
- [ ] Hacer que Playwright arranque sólo emuladores requeridos y use state aislado por proyecto.

**Aceptación:** matriz documentada con PASS/FAIL, screenshots/traces y limpieza. **Evidencia:** `EVID-QA-001..040`.

### UX-01 — Contacto y CTAs reales

**Prioridad:** P1 · **Rúbrica:** Amigabilidad/Funcionalidad.  
**Áreas:** `landing-web/src/app/[locale]/contact/page.tsx`, `HeroSection.tsx`, `Footer.tsx`, traducciones y pruebas Playwright landing.

- [ ] Decidir un único contrato: endpoint validado/persistido o `mailto:` claramente etiquetado; no usar formulario que aparenta enviar sin hacerlo.
- [ ] Añadir validación, estado loading, éxito y fallo localizado; si es endpoint, anti-spam y respuesta no reveladora.
- [ ] Reemplazar App Store placeholder por URL real validada o esconder CTA iOS hasta contar con ficha pública.
- [ ] Probar ES/EN, teclado y destinos externos sin navegación rota.

**Aceptación:** contacto informa resultado real y ningún CTA apunta a placeholder. **Evidencia:** `EVID-UX-010..015`.

### UX-02 — Recuperación ante error y deep links

**Prioridad:** P1 · **Rúbrica:** Amigabilidad/Funcionalidad.  
**Áreas:** `firebase_initialization_error_screen.dart`, `app_router.dart`, hosting Firebase, `README.md`, widget/E2E tests.

- [ ] Añadir botón accesible de reintento/reload al error de inicialización y texto localizado sin diagnóstico interno.
- [ ] Sustituir 404 por pantalla localizada con Inicio/Volver y preservar ruta inválida en telemetría segura.
- [ ] Probar hosting con rewrite SPA y recarga de rutas públicas/protegidas; corregir la configuración de despliegue, no el servidor `python` temporal.

**Aceptación:** errores no dejan al usuario varado y deep links desplegados no dan 404. **Evidencia:** `EVID-UX-020..025`.

### FUNC-01 — Edición completa de reseñas con fotos

**Prioridad:** P2 · **Rúbrica:** Funcionalidad/BD.  
**Áreas:** `review_sheet.dart:230-235`, `review_service.dart`, Storage rules, tests widget/servicio/reglas.

- [ ] Escribir test que edite texto y lista de fotos con conservar, añadir, borrar y reemplazar.
- [ ] Cambiar contrato de edición para aplicar cambios explícitos y borrar objetos huérfanos sólo tras escritura Firestore exitosa/idempotente.
- [ ] Probar que otro usuario/taller no puede alterar fotos ni la reseña.

**Aceptación:** editar no descarta fotos silenciosamente; Storage y Firestore quedan consistentes. **Evidencia:** `EVID-FUNC-020..024`.

### FUNC-02 — Retirar caminos obsoletos de reparación

**Prioridad:** P2 · **Rúbrica:** Funcionalidad.  
**Áreas:** `reparacion_provider.dart:42-136`, repositorio y consumidores, reglas/tests Kanban.

- [ ] Inventariar consumidores reales de `iniciar*`; escribir test de regresión del único flujo oficial (cotización aceptada → ticket → recepción).
- [ ] Eliminar los métodos sin consumidor o encapsularlos detrás de una única API interna con migración explícita.
- [ ] Mantener reglas que bloquean create directo y comprobar que el nuevo flujo no las viola.

**Aceptación:** existe un solo flujo de apertura documentado y probado. **Evidencia:** `EVID-FUNC-030..034`.

### UX-03 / UX-04 — Accesibilidad y errores de datos

**Prioridad:** P2 · **Rúbrica:** Amigabilidad.  
**Áreas:** `landing-web/src`, `service_history_screen.dart`, componentes de error/empty state, ARB, pruebas.

- [ ] Respetar `prefers-reduced-motion`, añadir menú móvil accesible y eliminar `Link > button` anidado.
- [ ] Reemplazar `Error: ${snapshot.error}` por estado localizado, reintento y logging seguro.
- [ ] Ejecutar Playwright a 320/375/390/414, tabulación y preferencia reduced-motion.

**Aceptación:** navegación móvil es descubrible, foco válido y ningún usuario ve error técnico. **Evidencia:** `EVID-UX-030..038`.

### SEC-04 / OPS-01 / QA-02 — Operación y suites confiables

**Prioridad:** P2/P3 · **Rúbrica:** Seguridad/Funcionalidad/Evidencia.  
**Áreas:** Firebase Console/runbook, `functions/index.js`, scripts `test_rules`, `firebase.json`, CI.

- [ ] Escribir runbook reproducible para App Check enforcement, dominios Auth, password policy, recovery y staging; registrar resultado sin secretos.
- [ ] Extraer lógica de cron/backup/notificación a funciones puras y probar entradas, errores y reintentos con fixtures.
- [ ] Corregir teardown de emuladores con `finally`/script único y verificar que 8080/9199/4400 quedan libres al salir.

**Aceptación:** `test_rules` termina con exit 0 y no deja procesos; configuración externa tiene evidencia fechada. **Evidencia:** `EVID-OPS-001..012`.

### H-01 / FINAL-01 — Hardening y segunda auditoría

**Prioridad:** P0 de salida · **Rúbrica:** todas.  
**Áreas:** todo el repositorio, matrices de evidencia y nuevo informe.

- [ ] Ejecutar gates por workstream: análisis, unitarias, Functions, reglas, build landing, Playwright y responsive.
- [ ] Ejecutar QA destructivo con fixtures: vacío, inválido, duplicado, doble submit, refresh, back/logout, rutas protegidas y cross-tenant.
- [ ] Generar matriz final Evidence ID → requisito → test → screenshot/trace.
- [ ] Repetir desde cero la auditoría adversarial CREA J 2026; usar nuevo abogado del diablo y juez independiente, sin arrastrar la nota 64.

**Aceptación:** cero P0/P1 abiertos, ningún no-verificado crítico y veredicto nuevo defendible. **Evidencia:** informe `AUDITORIA_CREA_J_2026_v2.md`.

## 8. Plan Playwright mínimo

| Grupo | Casos obligatorios |
|---|---|
| Auth | registro válido/inválido/duplicado, correo no verificado, verificación, recovery, login error, logout, refresh y ruta protegida |
| Roles | propietario/taller/admin: permitidos y denegados en UI, ruta directa y callable/regla |
| BD | CRUD+refresh de vehículo, chat, cotización, reserva, reparación, reseña y taller |
| NIT | PDF válido, tipo inválido, admin abre PDF, persistencia tras refresh |
| UX | 320/375/390/414, teclado, reduced motion, loading/error/empty, 404/retry, deep link |
| Landing | contacto ES/EN, CTA Android/iOS, navegación móvil y enlaces legales |

## 9. Riesgos de regresión

| Cambio | Riesgo | Regresión obligatoria |
|---|---|---|
| Auth/verificación | Alto | registro, login, Google, reset, logout, router, onboarding |
| Rules/schema | Alto | todas las entidades y cross-tenant emulator |
| Cotización/ticket | Alto | chat, reserva, trigger, Kanban, vínculo vehículo-taller |
| NIT/PDF Storage | Medio | imágenes existentes, admin viewer, tamaño/MIME |
| Router/hosting | Medio | rutas públicas/protegidas, recarga y móvil |
| Landing | Bajo/medio | locales, teclado, SEO/links/build |

## 10. Innovación recomendada

No añadir funcionalidad nueva hasta que H-01 deje todos los criterios existentes demostrados. Si el juez aún no concede 20/20 en creatividad, implementar **sólo** un QR temporal de historial compartido: callable que crea token con vencimiento y scope de lectura mínima, pantalla de escaneo existente, reglas que verifican token/relación y Playwright demo. Valor alto, visible en presentación y coherente con AutoDoc; no añadir IA ni servicios externos por marketing.

## 11. Checklist final 10/10

- [ ] Cero P0/P1 abiertos y todos los P2/P3 justificados o resueltos.
- [ ] Registro, email verification, recovery, sesión y logout demostrados en emulador.
- [ ] Roles pasan matriz UI + reglas + callable; ningún bypass cross-tenant.
- [ ] CRUD+refresh pasa para funciones principales y fallos parciales se recuperan.
- [ ] NIT PDF, contacto, CTAs, errores y deep links funcionan.
- [ ] Playwright cubre móvil, teclado, reduced motion y estados de error.
- [ ] Functions, reglas, Flutter, landing build y E2E terminan sin procesos huérfanos.
- [ ] Evidencia enlazada a cada criterio CREA, demo reproducible y nueva auditoría independiente concluida.

## 12. Orden exacto de ejecución

1. VER-01
2. SEC-01
3. SEC-02
4. SEC-03
5. ROLE-01
6. DATA-01
7. QA-02
8. QA-01 (auth/roles/BD base)
9. UX-01
10. UX-02
11. FUNC-01
12. FUNC-02
13. UX-03 / UX-04
14. SEC-04
15. OPS-01
16. H-01
17. INNO-01 (sólo si el mock judge lo exige)
18. FINAL-01

## Definition of Done por tarea

- [ ] implementación mínima y localizada;
- [ ] prueba nueva falla antes y pasa después;
- [ ] pruebas existentes relevantes pasan;
- [ ] Playwright/emulador cuando el comportamiento atraviesa UI, autorización o persistencia;
- [ ] responsive y localización si hay UI;
- [ ] Evidence ID, resultado y artefacto registrados;
- [ ] regresión del workstream ejecutada;
- [ ] reevaluación explícita del criterio CREA afectado.
