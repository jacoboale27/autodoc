# 🔴 AUDITORÍA CREA J 2026

Fecha: 2026-09-06 · Método: auditoría adversarial basada en evidencia, adaptada de Claude Code a Codex (Graphify, Playwright CLI y revisores de solo lectura).

## 1. VEREDICTO EJECUTIVO

**Estado:** plataforma amplia y técnicamente interesante, con una base de roles y reglas razonablemente sólida, pero no defendible como «Excelente» hoy. Dos riesgos de credenciales, una verificación de correo eludible y ausencia de pruebas CRUD multirol reales amenazan la evaluación.

Fortalezas: Flutter/Firebase, 40 rutas, roles con reglas servidor, tests de lógica y Functions, interfaz de autenticación que arranca y valida en móvil. Debilidades: correo no obligatorio, contraseña temporal fija, enumeración de PII, contacto/CTA iOS incompletos y evidencia E2E insuficiente.

## 2. PUNTUACIÓN FINAL

| Criterio | Peso | Nivel | Puntos |
|---|---:|---|---:|
| Amigabilidad móvil | 20 | Muy Bueno | 15 |
| Roles establecidos | 10 | Muy Bueno | 7 |
| Seguridad de registro | 20 | Bueno | 10 |
| Información mediante BD | 10 | Muy Bueno | 7 |
| Funcionalidad completa | 20 | Bueno | 10 |
| Creatividad y tecnologías | 20 | Muy Bueno | 15 |
| **TOTAL** | **100** | | **64/100** |

## 3. CONFIANZA

**Media.** Hay evidencia de código, pruebas unitarias/Functions, build y Playwright sin sesión. No hay demostración reciente de CRUD tras recarga, roles reales, triggers desplegados, App Check ni Firebase Auth/Firestore en un entorno aislado completo.

## 4. COBERTURA DE AUDITORÍA

| Elemento | Descubierto | Probado en esta auditoría |
|---|---:|---:|
| Pantallas/rutas Flutter | 40 / 40 | 4 rutas públicas (`/`, onboarding, login, registro) |
| Roles | Propietario, Mecánico/Taller, Administrador, Superusuario | 0 con cuenta real |
| Flujos Playwright | matriz mínima 24 requerida | 6 sin mutación; 4 PASS, 2 no verificables |
| Pruebas Flutter | 223 archivos | suite iniciada; salida completa no capturada de forma concluyente |
| Functions | 11 suites | 127 casos PASS observados |
| Reglas | 18 suites | ejecución no concluyente: emulador/Jest quedó activo; reintento falló por puertos ocupados |
| Graphify | 7,719 nodos / 12,126 aristas / 347 comunidades | reindexado sin LLM; mapa complementado con router e inspección directa |

## 5. EVALUACIÓN POR CRITERIO

### Amigabilidad — 15/20

**Evidencia:** Playwright comprobó onboarding, login y registro en 320, 375, 390 y 414 px sin overflow horizontal; `MainScaffold` adapta navegación. **Problemas:** la navegación móvil de landing oculta secciones sin menú, el 404 no da salida y errores Firestore son crudos. **No obtiene 20:** faltan recorridos autenticados y accesibilidad asistida; `web/index.html` no declara viewport.

### Roles — 7/10

**Evidencia:** router protege estados/roles y Firestore bloquea autoasignación de privilegios (`firestore.rules:302-359`). **Problema:** el cliente normaliza variantes de rol que las reglas no admiten, posible UI permitida con backend denegado (`role_utils.dart:34-68`, `firestore.rules:42-50`). **No obtiene 10:** no se probó matriz de roles contra emulador.

### Seguridad — 10/20

**Evidencia:** Firebase Auth, recuperación y correo de verificación existen; Playwright verificó validación de vacío e email inválido. **Hallazgos:** verificación no se impone (`auth_screen.dart:568-571,779-784`), contraseña temporal global fija (`functions/index.js:1981-2053`) y oráculo de propietarios (`functions/index.js:1670-1722`). **No obtiene 15:** los defectos son reales; App Check/enforcement no es comprobable desde el repositorio.

### BD — 7/10

**Evidencia:** Firestore, streams, repositorios y reglas cubren vehículos, chat, reparaciones, reseñas y administración. **Límite:** las pruebas usan principalmente FakeFirestore/mocks; no se demostró CRUD+refresh real. **No obtiene 10:** no hay persistencia multirol observada.

### Funcionalidad — 10/20

**Evidencia:** Functions: 127 casos PASS; landing: build de 15 rutas estáticas; flujo público arrancó en navegador. **Problemas:** cotización con dos escrituras no atómicas (`chat_repository.dart:199-213`), edición de reseña sin fotos, contacto landing decorativo y CTA iOS placeholder. **No obtiene 15:** no hay E2E satisfactorio de flujos principales.

### Creatividad — 15/20

**Evidencia:** Flutter/Firebase, mapas, QR, chat/aduntos, PDF, notificaciones, historial/alertas y paneles por rol. **No obtiene 20:** falta demostrar valor diferencial en uso real y algunas integraciones siguen sin verificación E2E.

## 6. MATRIZ DE EVIDENCIA

| ID | Criterio | Tipo | Evidencia | Resultado |
|---|---|---|---|---|
| EVID-RUN-001 | UX | Playwright | Arranque a onboarding, sin errores de consola | PASS |
| EVID-AUTH-001 | Seguridad | Playwright | Login vacío: ambos campos inválidos | PASS |
| EVID-AUTH-002 | Seguridad | Playwright | Registro con email inválido rechazado | PASS |
| EVID-UX-001 | UX | Playwright | 320/375/390/414 px, `scrollWidth == innerWidth` en registro | PASS limitado |
| EVID-FUNC-001 | Funcionalidad | Tests | Functions `npm test`: 127 passing | PASS |
| EVID-BUILD-001 | Funcionalidad | Build | `landing-web: pnpm build`, 15 rutas | PASS |
| EVID-SEC-001 | Seguridad | Código | contraseña fija de superusuario | FAIL |
| EVID-SEC-002 | Seguridad | Código | correo verificable pero no obligatorio | FAIL |
| EVID-DB-001 | BD | Código/tests | repositorios/streams; sin CRUD real | NO VERIFICADO |
| EVID-RULES-001 | Roles | Emulador | ejecución de reglas quedó inconclusa | NO VERIFICADO |

## 7. MATRIZ DE TESTS

| Test ID | Área | Resultado | Evidencia |
|---|---|---|---|
| UX-001 | Onboarding público | PASS | EVID-RUN-001 |
| AUTH-004 | Login vacío | PASS | EVID-AUTH-001 |
| AUTH-002 | Registro email inválido | PASS | EVID-AUTH-002 |
| UX-001..004 | Registro 320/375/390/414 | PASS limitado | EVID-UX-001 |
| AUTH-001/005..010 | Registro/login/sesión reales | NO VERIFICADO | no se crearon cuentas producción |
| ROLE-001..003 | Matriz de roles | NO VERIFICADO | EVID-RULES-001 |
| DB-001..004 | CRUD+refresh | NO VERIFICADO | EVID-DB-001 |

## 8. BUGS

### [CRÍTICO] Contraseña temporal fija para cuentas privilegiadas

Ubicación: `functions/index.js:1981-2053` · Impacto: seguridad, roles, funcionalidad administrativa. Todas las cuentas creadas por el flujo reciben el mismo secreto y se devuelve al llamador.

### [CRÍTICO] Correo verificable pero no obligatorio

Ubicación: `auth_screen.dart:568-571,779-784` · Impacto: seguridad de registro. Tras enviar verificación se permite continuar; el login también permite continuar sin verificar.

### [ALTO] Enumeración de propietario y PII

Ubicación: `functions/index.js:1670-1722` · Impacto: seguridad. Callable permite a un propietario consultar correo arbitrario y devuelve UID, correo y nombre sin rate limit visible.

### [ALTO] Cotización parcialmente persistible

Ubicación: `chat_repository.dart:199-213` · Impacto: BD/funcionalidad. La escritura pública y el margen privado no son una operación atómica.

## 9. SEGURIDAD

**Confirmados:** cuatro bugs anteriores; validación cliente de vacío/email; reglas de perfil/vehículo y autorización sensible servidor. **Potenciales:** App Check fail-open del cliente y diferencia de vocabulario de roles. **No verificados:** enforcement App Check, políticas Auth, MFA, revocación, reset y aislamiento multi-tenant reales.

## 10. UX/UI

- Landing: contacto `action="#"` sin entrega/feedback; CTA App Store `id123456789`.
- Landing: navegación de secciones desaparece en móvil sin alternativa; controles anidados Link/button.
- Error Firebase no ofrece reintento; 404 sin acción/localización; historial muestra error técnico crudo.
- Fortalezas: navegación adaptativa, tema claro/oscuro, estados vacíos semánticos y validación de los formularios públicos probados.

## 11. RESPONSIVE / MÓVIL

| Viewport | Registro sin overflow horizontal | Resultado |
|---:|---|---|
| 320 px | `320 == 320` | PASS limitado |
| 375 px | `375 == 375` | PASS limitado |
| 390 px | `390 == 390` | PASS limitado |
| 414 px | `414 == 414` | PASS limitado |

Sólo se validó el formulario público; dashboards y vistas con datos quedan no verificados.

## 12. ROLES

| Rol | Acción | Resultado | Evidencia |
|---|---|---|---|
| Propietario | crear perfil sin elevar rol | Permitido/restringido por regla | `firestore.rules:302-359` |
| Mecánico | acceso a operaciones taller | Restringido por rol/estado | `firestore.rules:42-50` |
| Administrador | gestión | Código/rutas presentes | no probado runtime |
| Superusuario | provisionar cuentas | Riesgo crítico | EVID-SEC-001 |

## 13. BASE DE DATOS

Existe flujo UI → repositorio/provider → Firestore/Functions → stream/UI para los dominios principales. Aun así, no hay evidencia actual de create/update/delete persistido tras refresh con reglas y roles reales. Los cron/backup/notificaciones tampoco tienen despliegue o scheduler comprobado.

## 14. FUNCIONALIDADES

**🟢 Completas con evidencia local:** build landing, funciones unitarias cubiertas, validación pública de auth. **🟡 Parciales:** vehículos, alertas, chat, reservas, reparaciones, taller, reseñas, administración. **🔴 Rotas:** contacto landing y CTA iOS; seguridad de contraseña/verificación. **⚪ No verificadas:** CRUD real, notificaciones/cron, backup, flujos multirol y móvil autenticado.

## 15. FALSOS EXCELENTES

- Enviar email de verificación no equivale a exigirlo.
- Pruebas FakeFirestore no equivalen a reglas/persistencia real.
- El selector de PDF NIT mantiene una rama que el picker productivo no alcanza (prioridad S1 ya indicada por `CLAUDE.md`).

## 16. LO QUE REALMENTE ESTÁ MUY BIEN

- Separación de roles en reglas, guards y callables sensibles.
- 127 pruebas de Functions observadas exitosas y build Next.js limpio.
- UI pública arranca con Firebase, onboarding y validaciones accesibles; el registro no desborda en cuatro anchos móviles.

## 17. TOP 10 PROBLEMAS

| # | Problema | Severidad | Criterio | Puntos en riesgo |
|---:|---|---|---|---:|
| 1 | Contraseña temporal global | Crítico | Seguridad | 5+ |
| 2 | Correo no impuesto | Crítico | Seguridad | 5+ |
| 3 | Enumeración PII | Alto | Seguridad | 3+ |
| 4 | CRUD real no evidenciado | Alto | BD/Funcionalidad | 5+ |
| 5 | Cotización no atómica | Alto | BD/Funcionalidad | 3+ |
| 6 | App Check no demostrable | Alto | Seguridad | 2+ |
| 7 | E2E existente con fallos | Medio | Funcionalidad | 3+ |
| 8 | Contacto/CTA iOS | Medio | UX/Funcionalidad | 2+ |
| 9 | Roles normalizados distinto | Medio | Roles | 2+ |
| 10 | Deep-link estático 404 | Medio | UX | 2+ |

## 18. TOP 10 MEJORAS

1. Reemplazar contraseña fija por enlace de configuración único y expirable; forzar cambio. **Crítico / Seguridad.**
2. Bloquear acciones protegidas hasta `emailVerified`; eliminar «continuar sin verificar». **Crítico / Seguridad.**
3. Eliminar/restringir el callable de búsqueda por correo y devolver un mínimo de datos. **Alto / Seguridad.**
4. Crear suites emulador con dos cuentas y pruebas CRUD→refresh por cada rol. **Alto / BD/Funcionalidad.**
5. Hacer la cotización atómica o recuperable/idempotente. **Alto / BD.**
6. Reparar contacto y CTA reales. **Medio / UX.**
7. Añadir reintento y pantalla 404 accionable/localizada. **Medio / UX.**
8. Unificar vocabulario canónico de roles/migrar los heredados. **Medio / Roles.**
9. Añadir E2E autenticado con fixture/emulador, no producción. **Medio / Evidencia.**
10. Corregir S1: selector real PDF para NIT. **Medio / Funcionalidad.**

## 19. FUNCIONALIDADES NUEVAS

| Función | Valor | Tecnología | Criterio | Dificultad | Impacto |
|---|---|---|---|---|---|
| Expediente verificable del vehículo | confianza del usuario | PDF/Storage/QR | Creatividad | Media | Alto |
| Recordatorio predictivo explicable | mantenimiento proactivo | reglas/analítica local | Creatividad | Media | Medio |
| Compartir historial con QR temporal | interoperabilidad taller-cliente | QR/callable expirable | Creatividad/seguridad | Media | Alto |

## 20. ROADMAP A 100/100

**🔴 Bloqueantes:** credencial temporal, obligatoriedad de correo, enumeración PII, PDF NIT. **🟠 Alto impacto:** E2E emulador multirol y CRUD/refresco, atomicidad cotización, probar/activar enforcement. **🟡 Pulido:** contacto, CTA, 404/retry, roles heredados, accesibilidad. **🟢 Innovación:** QR temporal, expediente, recordatorio predictivo.

## 21. PUNTUACIÓN DESPUÉS DE LAS MEJORAS

Puntuación actual: **64/100**. Después de bloqueantes: **72–78/100**. Después de alto impacto y evidencia E2E: **82–90/100**. Potencial máximo: **95–100/100**, condicionado a pruebas funcionales reales y demo reproducible.

## 22. VEREDICTO DEL ABOGADO DEL DIABLO

El argumento más fuerte del profesor: «La app ofrece muchas funciones, pero no demuestra que sus roles, BD y registro funcionen seguros en la práctica; además, el control de correo puede eludirse y una cuenta privilegiada recibe una contraseña conocida». Riesgos principales: credenciales, verificación y ausencia de E2E multirol.

## 23. VEREDICTO FINAL DEL JUEZ

> **"Si yo fuera el profesor y evaluara hoy esta aplicación siguiendo estrictamente la rúbrica, le otorgaría 64/100."**

Las tres razones: 1) fallos concretos de seguridad; 2) amplitud funcional superior pero demostración runtime insuficiente; 3) UX móvil pública correcta con fallos de recorridos secundarios.

Lo primero que arreglaría: 1) contraseñas y verificación; 2) pruebas emulador E2E de roles/CRUD; 3) contacto/CTA, PDF NIT y rutas de error.
