# 🔴 AUDITORÍA CREA J 2026 — SEGUNDA OPINIÓN (Claude Code)

Fecha: 2026-09-06 · Método: auditoría adversarial basada en evidencia (`AUDITORIA_CREA_J_2026_CLAUDE_CODE.md`).
Independiente de `AUDITORIA_CREA_J_2026_CODEX.md`, pero con contraste explícito contra su veredicto.
Herramientas: Graphify (disponible, 7802 nodos / 12106 aristas), Superpowers (disponible), Playwright MCP,
emuladores Firebase, suites reales del repositorio. **No se modificó el proyecto durante la auditoría.**

---

## 1. VEREDICTO EJECUTIVO

**Estado:** proyecto de alcance y disciplina de ingeniería muy por encima de lo típico en esta rúbrica —
1.571 pruebas automatizadas en verde, reglas de Firestore extensas y razonadas, higiene de secretos correcta—
pero con **cuatro defectos concretos y demostrables** que un evaluador puede encontrar leyendo el código, y
con la demostración de ejecución todavía incompleta en los flujos autenticados.

Lo que más pesa no es ningún bug aislado: es que **el repositorio contiene su propia evidencia de fallo**.
Hay una contraseña compartida escrita como literal con un comentario que la justifica; hay un comentario que
admite que existe un oráculo correo→PII y que se dejó deliberadamente abierto; y hay un
`e2e/reporte_playwright.md` commiteado que muestra dos ❌. Un profesor que abra el código encuentra los
defectos ya documentados por el propio equipo.

**Fortalezas reales (con evidencia):** capa de autorización servidor sólida y probada; suites verdes;
amplitud funcional y tecnológica genuina. **Debilidades reales:** credencial fija, verificación de correo sin
ningún gate servidor, oráculo de PII cuya única mitigación planificada está desactivada, y varias rutas que la
UI ofrece pero que en producción no se pueden alcanzar.

**Coincido con el 64/100 de Codex.** No por deferencia: llegué al mismo número por un camino distinto,
subiendo la confianza en Roles y BD (donde Codex no tenía evidencia y yo sí) y bajándola en Funcionalidad
(donde encontré una ruta rota que él no vio). Ver §24 para las discrepancias.

---

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

---

## 3. CONFIANZA

```text
CONFIANZA GLOBAL: Media-Alta
```

Más alta que la de Codex (Media) porque esta pasada **sí ejecutó** lo que él dejó inconcluso: la suite de
reglas contra emulador real (321 pruebas), la suite Flutter completa (1.123) y Functions (127). La capa de
autorización y la de persistencia dejan de ser "NO VERIFICADO".

Sigue sin ser Alta por una razón honesta: **no hay evidencia de recorrido autenticado extremo a extremo**.
La app apunta a producción y el plan de remediación prohíbe usar cuentas reales para QA, así que un E2E
autenticado exige primero cablear la build contra emuladores. Eso no se hizo y no se inventa.

---

## 4. COBERTURA DE AUDITORÍA

```text
Pantallas/rutas descubiertas:  40   ·  probadas en runtime: 4 públicas (heredado de Codex) + landing
Roles descubiertos:            4 (Propietario, Mecánico/Taller, Administrador, Superusuario)
Roles probados:                4 en la capa de reglas (emulador) · 0 en UI autenticada
Funciones descubiertas:        213 archivos Dart en lib/ · 2098 líneas de Cloud Functions
Reglas:                        firestore.rules 1403 líneas · storage.rules 299 líneas

Tests ejecutados en esta auditoría:
  Flutter (unit/widget):                     1123 PASS · 0 FAIL · exit 0
  Reglas (Firestore+Storage, emulador real):  321 PASS · 18/18 suites · exit 0
  Functions (Mocha):                          127 PASS · exit 0
  TOTAL                                      1571 PASS · 0 FAIL

Playwright (propio, esta pasada): landing en 375px, 4 aserciones de runtime — 4 hallazgos confirmados
Playwright (autenticado):  NO VERIFICADO — requiere build contra emulador, no autorizado contra producción
```

---

## 5. EVALUACIÓN POR CRITERIO

### 5.1 Amigabilidad — Muy Bueno — 15/20

**Requisito (Excelente):** interfaz intuitiva, clara y muy atractiva.

**Evidencia:** navegación adaptativa (`MainScaffold`), tema claro/oscuro, localización ES/EN completa en ARB,
utilidades de breakpoints, 1123 widget tests en verde. Codex verificó ausencia de overflow horizontal en
320/375/390/414 px en los formularios públicos.

**Hallazgos propios (Playwright, 375 px, `/es/contact.html`):**
- `nav` contiene 3 enlaces y **0 visibles** en 375 px; los únicos controles visibles son idioma, tema y
  "Probar Gratis". **No existe botón hamburguesa ni menú alternativo** → las secciones del sitio son
  inalcanzables en móvil. (`EVID-CL-UX-001`)
- 1 anidamiento `a > button` → HTML inválido y objetivo de foco ambiguo. (`EVID-CL-UX-002`)

**Hallazgo de código con implicación importante:** `web/index.html` **no declara `<meta name="viewport">`**
(la landing Next.js sí lo hace: `width=device-width, initial-scale=1`). Codex lo mencionó de pasada pero no
extrajo la consecuencia: **invalida parcialmente su propia evidencia responsive**. Playwright fija el viewport
por API y por eso no ve el problema; un navegador móvil real, sin ese meta, asume ~980 px de ancho CSS y monta
el layout de escritorio reducido. Si la demo se hace en la APK Android el punto es irrelevante; si se hace en
web sobre un teléfono, es el criterio de 20 puntos entero. (`EVID-CL-UX-003`)

**Otros:** 404 crudo, sin localizar y sin salida (`app_router.dart:371-372`); errores de Firestore mostrados en
bruto al usuario.

**Por qué no obtiene 20:** la navegación móvil de la landing no es utilizable, el 404 deja varado al usuario y
falta el meta viewport en la app web. **Cambio para subir:** meta viewport + menú móvil + 404 accionable.

### 5.2 Roles — Muy Bueno — 7/10

**Requisito (Excelente):** roles claramente definidos, bien implementados y diferenciados.

**Evidencia nueva y decisiva:** ejecuté la suite de reglas contra emulador real —
**321 pruebas, 18/18 suites, exit 0**, incluyendo `usuarios`, `mecanico-scope`, `empleados`,
`talleres-publico`, `verificaciones`, `reparaciones_estado`, `servicios_walkin`. Cubre explícitamente
«nadie puede auto-crearse como Administrador ni Superusuario» y «un propietario NO puede leer el documento de
otro usuario». **Esto convierte el `EVID-RULES-001 / ROLE-001..003 NO VERIFICADO` de Codex en verificado.**
(`EVID-CL-RULES-001`)

La autorización está donde debe: `firestore.rules` con `isAdmin()`, `isSuperUser()`, `isMecanico()` —y este
último exige además `estado in ['aprobado','activo']`, es decir, un taller pendiente no accede aunque burle el
router. Eso es autorización real, no ocultar botones.

**Defecto que impide el 10 (ROLE-01, confirmado):** `role_utils.dart` normaliza sin acentos y en minúsculas y
acepta `'mecánico'`, `'mecanico'`, `'admin'`; `firestore.rules` compara literales exactos
(`rol in ['Mecanico','Taller']`). Una cuenta guardada como `'Mecánico'` ve el panel de taller y recibe
`permission-denied` del backend. **Falla cerrado** —no es escalada de privilegios— pero es exactamente
"UI permitida / backend denegado". (`EVID-CL-ROLE-001`)

**Por qué no obtiene 10:** el Excellent Gate exige que no haya deficiencias importantes conocidas, y ROLE-01
lo es. **Cambio para subir:** vocabulario canónico único + migración de valores heredados.

### 5.3 Seguridad — Bueno — 10/20

**Requisito (Excelente):** validación por correo, cifrado y recuperación.

**Lo que sí hay:** Firebase Auth (hashing scrypt gestionado = "cifrado" cubierto), recuperación de contraseña,
envío de correo de verificación, App Check integrado, **higiene de secretos correcta** (`.env` y `app.env`
en `.gitignore`, ningún service account ni keystore commiteado — Codex no lo credita y merece crédito).

**🔴 SEC-01 — Contraseña compartida fija.** `functions/index.js:1982` define
`const SUPERUSER_TEMP_PASSWORD = 'AutoDoc2026*'` y `superUserCreateAccount` la asigna a **toda** cuenta creada
y **la devuelve al llamador** (`return { ..., passwordTemporal: SUPERUSER_TEMP_PASSWORD }`). Toda cuenta
provisionada por el panel —incluidos Administradores— nace con el mismo secreto, escrito en claro en el
repositorio. (`EVID-CL-SEC-001`)

**🔴 SEC-02 — La verificación de correo no se impone en ninguna capa.** Verificado por búsqueda exhaustiva:
`email_verified` / `emailVerified` **no aparece ni una sola vez** en `firestore.rules`, `storage.rules` ni
`functions/index.js`; tampoco hay gate en `app_router.dart`. Tras registrarse,
`auth_screen.dart:773` navega a `/profile_setup` incondicionalmente, y en login existe un botón literal
"continuar sin verificar". El correo se *valida como formato* y se *envía*, pero **nunca condiciona el
acceso**. (`EVID-CL-SEC-002`)

**🟠 SEC-03 — Oráculo correo→PII, con su mitigación desactivada.** `buscarPropietarioPorCorreo`
(`functions/index.js:1683-1722`) devuelve `{uid, correo, nombre}` de cualquier propietario a cualquier cuenta
Propietario, sin límite de tasa. El propio comentario del código lo admite y difiere la mitigación a App Check.
**Pero `main.dart:154-157` deja App Check explícitamente fail-open** y el comentario dice que se despliega
"en modo monitorización" antes de activar enforcement. **Es decir: la mitigación no existe hoy.**
(`EVID-CL-SEC-003`)

**🟡 Hallazgo nuevo — política de contraseñas mínima.** `auth_screen.dart:385` exige únicamente
`pass.length >= 6`, sin complejidad ni comprobación de contraseñas filtradas. Es el mínimo por defecto de
Firebase. (`EVID-CL-SEC-004`)

**🟢 Hallazgo nuevo — código privilegiado muerto en el cliente.** `AdminAuthService.seedAdminAccounts()` crea
cuentas y escribe `rol` arbitrario desde el cliente. **No tiene ningún consumidor** en `lib/`, y las reglas
bloquearían la escritura; pero es superficie muerta que un revisor leerá mal. (`EVID-CL-SEC-005`)

**Por qué no obtiene 15:** "Muy Bueno = registro seguro con validación básica de correo" no se sostiene cuando
la verificación no condiciona nada y una cuenta privilegiada nace con una contraseña conocida y publicada.

### 5.4 BD — Muy Bueno — 7/10

**Requisito (Excelente):** información clara, organizada, precisa y actualizada en tiempo real.

**Evidencia más fuerte de lo que Codex concedió:** las 321 pruebas de reglas corren contra el **emulador real
de Firestore/Storage**, no contra `FakeFirestore`, y cubren por entidad `vehiculos`, `conversaciones`,
`mensajes`, `cotizaciones`, `reservas`, `reparaciones`, `resenias`, `servicios`, `catalogo_servicios`,
`empleados`, `talleres`, `usuarios`, `perfil_publico`, `verificaciones`. Es semántica real de Firestore, con
reglas aplicadas. Codex lo descartó diciendo "las pruebas usan principalmente FakeFirestore/mocks": eso es
cierto de la suite Flutter, **no** de la suite de reglas.

**Defecto confirmado (DATA-01):** `chat_repository.dart:194-215` hace dos escrituras secuenciales
—cotización pública, luego margen privado— sin atomicidad. Si falla la segunda, queda una cotización pública
sin su margen. **Matiz importante que corrige al plan de remediación: el arreglo prescrito ("batch atómico")
es técnicamente imposible aquí.** La regla del hijo usa `get()` sobre el documento padre, y `get()` dentro de
un batch no ve las escrituras del mismo batch: el padre *debe* existir antes. El comentario del código tiene
razón. La única vía válida es la de estado `draft/pending`. (`EVID-CL-DB-001`)

**Por qué no obtiene 10:** falta el eslabón que el profesor mirará de verdad —el ciclo UI → escribir →
refrescar → ver— demostrado delante de una persona. La capa está probada; el recorrido visible no.

### 5.5 Funcionalidad — Bueno — 10/20

**Requisito (Excelente):** todas las funciones operan correctamente y sin errores.

**Evidencia a favor:** 1571 pruebas en verde, lógica de triggers de vínculo taller-vehículo probada caso por
caso, reglas probadas, build de landing con 15 rutas.

**Rutas que la UI ofrece y que en producción no se pueden ejercer:**

1. **🔴 VER-01 (confirmado, prioridad S1 del proyecto):** `workshop_verification_screen.dart:112` usa
   `ImagePicker().pickImage(...)`, que no selecciona PDF, mientras `storage.rules:237` ya admite
   `nit.(jpg|jpeg|png|webp|pdf)` y `file_picker` está en `pubspec.yaml:84` sin usar. El NIT —el documento más
   determinante para aprobar un taller— no se puede subir en PDF. (`EVID-CL-FUNC-001`)

2. **🟠 HALLAZGO NUEVO — el login de administrador por nombre de usuario nunca puede funcionar.**
   `auth_screen.dart:358` documenta como regla de negocio que en login se acepta "usuario admin sin arroba", y
   `auth_provider.dart:44-52` lo enruta a `AdminAuthService.loginAsAdmin`, que resuelve el usuario consultando
   la colección `usuarios`. Pero esa consulta se hace **sin sesión iniciada**, y `firestore.rules` dice
   `allow read: if isOwner(userId) || isAdmin()` para `usuarios`. Resultado: `permission-denied` → `null` →
   el login falla **siempre** con "No se encontró un usuario con ese nombre".
   **Y sus pruebas pasan porque todas usan correos (`'a@x.com'`) y `FakeFirebaseFirestore`, que no aplica
   reglas.** Es exactamente la misma trampa que `CLAUDE.md` advierte para el PDF del NIT: suite verde sobre un
   camino que nadie puede recorrer. (`EVID-CL-FUNC-002`)

3. **🟠 UX-01 (confirmado en runtime, peor de lo reportado):** el formulario de contacto tiene `action="#"`,
   **sin handler `onSubmit` de React**, y sus tres campos (`name`, `email`, `message`) **no son `required`**.
   No valida, no envía y no informa. Es un botón decorativo. El CTA de App Store apunta a
   `https://apps.apple.com/app/id123456789` en el DOM servido. (`EVID-CL-FUNC-003`)

4. **🟡 FUNC-01 (confirmado):** `review_sheet.dart:230-234` documenta que el selector de fotos solo aparece al
   crear; `updateReview()` nunca envía fotos. Editar una reseña las descarta.

5. **🟡 FUNC-02 (confirmado):** los tres `iniciar*` `@Deprecated` de `reparacion_provider.dart` no tienen
   ningún consumidor fuera de su propio archivo. Código muerto.

6. **🟡 E2E commiteado en rojo:** `e2e/reporte_playwright.md` muestra 1 suite y **dos ❌**. Además
   `e2e/playwright.config.js:17` arranca con `flutter run -d web-server`, que es un modo de depuración poco
   fiable para Playwright frente a `flutter build web`.

**Por qué no obtiene 15:** "errores menores" no describe un documento de verificación que no se puede subir ni
un login administrativo que nunca funciona.

### 5.6 Creatividad — Muy Bueno — 15/20

**Requisito (Excelente):** tecnologías modernas con innovaciones que enriquecen la App.

**Verificado que se usan de verdad** (no solo declaradas): `mobile_scanner` (QR, 1), `record` +
`audioplayers` (notas de voz en chat, 1+1), `fl_chart` (6), `hive` (caché offline, 5), `pdf`+`printing`
(expediente, 1), Maps, FCM, Crashlytics, App Check, CSV. La amplitud es genuina y por encima de la media.

**Hallazgo nuevo — dependencias declaradas con cero uso:** `image_painter` (0 archivos) y `lottie`
(0 archivos). Es el falso excelente "API instalada ≠ API aporta innovación" en su forma literal, y engorda el
bundle. (`EVID-CL-INNO-001`)

**Por qué no obtiene 20:** el valor diferencial no está *demostrado* en ejecución. **Este es el criterio más
barato de subir: no necesita código nuevo, necesita una demo guionizada.** Añadir el QR temporal antes de
tener eso sería invertir en el orden equivocado.

---

## 6. MATRIZ DE EVIDENCIA

| Evidence ID | Criterio | Tipo | Evidencia | Resultado |
|---|---|---|---|---|
| EVID-CL-RULES-001 | Roles/BD | Emulador | `test_rules`: 321 tests, 18/18 suites, exit 0, emuladores cerrados | **PASS** |
| EVID-CL-FLUT-001 | Funcionalidad | Tests | `flutter test`: 1123 PASS, exit 0 | **PASS** |
| EVID-CL-FUNC-000 | Funcionalidad | Tests | `functions: npm test`: 127 PASS | **PASS** |
| EVID-CL-SEC-001 | Seguridad | Código | `functions/index.js:1982` contraseña literal compartida y retornada | **FAIL** |
| EVID-CL-SEC-002 | Seguridad | Código | 0 ocurrencias de `email_verified` en reglas/functions/router | **FAIL** |
| EVID-CL-SEC-003 | Seguridad | Código | oráculo PII + App Check fail-open (`main.dart:154`) | **FAIL** |
| EVID-CL-SEC-004 | Seguridad | Código | política de contraseña = 6 caracteres, sin complejidad | **FAIL** |
| EVID-CL-SEC-005 | Seguridad | Código | `seedAdminAccounts` privilegiado, sin consumidor | **RIESGO** |
| EVID-CL-FUNC-001 | Funcionalidad | Código | `pickImage` en slot NIT; `file_picker` sin usar | **FAIL** |
| EVID-CL-FUNC-002 | Funcionalidad | Código+Reglas | login admin por usuario: lectura `usuarios` sin sesión → denegada siempre | **FAIL** |
| EVID-CL-FUNC-003 | Funcionalidad/UX | Playwright | contacto: `action="#"`, sin onSubmit, 0 campos required | **FAIL** |
| EVID-CL-UX-001 | Amigabilidad | Playwright | 375px: 0 de 3 enlaces de `nav` visibles, sin menú alternativo | **FAIL** |
| EVID-CL-UX-002 | Amigabilidad | Playwright | 1 anidamiento `a > button` | **FAIL** |
| EVID-CL-UX-003 | Amigabilidad | Código | `web/index.html` sin `<meta name="viewport">` | **FAIL** |
| EVID-CL-ROLE-001 | Roles | Código | `role_utils` acepta variantes que `firestore.rules` rechaza | **FAIL** |
| EVID-CL-DB-001 | BD | Código | cotización: dos escrituras no atómicas (batch inviable por `get()` en reglas) | **RIESGO** |
| EVID-CL-INNO-001 | Creatividad | Código | `image_painter` y `lottie`: 0 archivos que los importen | **FAIL** |
| EVID-CL-SEC-OK1 | Seguridad | Código | `.env`/`app.env` en `.gitignore`; sin service account ni keystore commiteados | **PASS** |
| EVID-CL-REFUT-001 | UX | Config | `firebase.json` target `app` **sí** tiene rewrite SPA `**` → `/index.html` | **REFUTA a Codex** |
| EVID-CL-REFUT-002 | Evidencia | Ejecución | la suite de reglas cierra limpia y libera puertos | **REFUTA QA-02** |

---

## 7. MATRIZ DE TESTS

| Test ID | Área | Test | Resultado | Evidencia |
|---|---|---|---|---|
| CL-RULES-001..018 | Roles/BD | 18 suites de reglas contra emulador | PASS (321) | EVID-CL-RULES-001 |
| CL-FLUT-001 | Funcionalidad | suite Flutter completa | PASS (1123) | EVID-CL-FLUT-001 |
| CL-FUNC-001 | Funcionalidad | suite Cloud Functions | PASS (127) | EVID-CL-FUNC-000 |
| CL-UX-375-A | Amigabilidad | landing 375px: overflow horizontal | PASS (367 ≤ 375) | EVID-CL-UX-001 |
| CL-UX-375-B | Amigabilidad | landing 375px: navegación alcanzable | **FAIL** | EVID-CL-UX-001 |
| CL-FUNC-CONTACT | Funcionalidad | contacto: handler y validación | **FAIL** | EVID-CL-FUNC-003 |
| CL-FUNC-CTA-IOS | Funcionalidad | CTA App Store apunta a ficha real | **FAIL** | EVID-CL-FUNC-003 |
| CL-AUTH-E2E-* | Seguridad | registro/login/logout autenticado real | **NO VERIFICADO** | requiere build contra emulador |
| CL-DB-CRUD-UI-* | BD | CRUD + refresh desde la UI | **NO VERIFICADO** | ídem |
| CL-ROLE-UI-* | Roles | matriz de roles en UI autenticada | **NO VERIFICADO** | ídem (capa de reglas SÍ probada) |

---

## 8. BUGS

```text
[🔴 CRÍTICO] Contraseña compartida fija para cuentas provisionadas
Ubicación: functions/index.js:1982, 2053
Pasos: superUserCreateAccount con cualquier rol
Esperado: secreto único, expirable, no retornado
Real: 'AutoDoc2026*' literal en el repo, idéntica para todas, devuelta al llamador
Criterio: Seguridad, Roles · Impacto: comprometer cualquier cuenta provisionada
```
```text
[🔴 CRÍTICO] La verificación de correo no condiciona ningún acceso
Ubicación: auth_screen.dart:773; 0 ocurrencias de email_verified en reglas/functions/router
Pasos: registrarse → cerrar el diálogo → se entra a /profile_setup y a los datos
Esperado: sin verificar no se accede a datos protegidos
Real: se accede; en login hay además "continuar sin verificar"
Criterio: Seguridad · Impacto: el criterio central de 20 puntos no se cumple
```
```text
[🟠 ALTO] Oráculo correo → PII, con la mitigación desactivada
Ubicación: functions/index.js:1683-1722 + main.dart:154-157
Real: cualquier Propietario obtiene (uid, correo, nombre) de cualquier otro, sin rate limit.
      La mitigación prevista (App Check) está en modo monitorización y fail-open en cliente.
Criterio: Seguridad
```
```text
[🟠 ALTO] El NIT no puede subirse en PDF (S1)
Ubicación: workshop_verification_screen.dart:112
Real: pickImage no ofrece PDF; storage.rules y el visor admin ya lo soportan; file_picker sin usar
Criterio: Funcionalidad · Impacto: bloquea la aprobación de talleres
```
```text
[🟠 ALTO] El login de administrador por nombre de usuario falla siempre — NUEVO
Ubicación: auth_provider.dart:44-52 → admin_auth_service.dart:_resolveUsernameToEmail
Pasos: en login escribir "admin" (sin @) y la contraseña correcta
Esperado: entrar al panel de administración
Real: la resolución consulta 'usuarios' sin sesión; la regla exige isOwner||isAdmin →
      permission-denied → null → "No se encontró un usuario con ese nombre"
Evidencia: firestore.rules (usuarios/allow read) + tests que solo usan correos y FakeFirestore
Criterio: Funcionalidad, Roles
```
```text
[🟠 ALTO] Formulario de contacto decorativo
Ubicación: landing-web/src/app/[locale]/contact/page.tsx:64
Real (Playwright): action="#", sin onSubmit, 0 de 3 campos required. No valida, no envía, no informa.
Criterio: Amigabilidad, Funcionalidad
```
```text
[🟡 MEDIO] Sin meta viewport en la app web
Ubicación: web/index.html (head sin <meta name="viewport">)
Impacto: en un navegador móvil real la app monta el layout de escritorio reducido.
         Playwright no lo detecta porque fija el viewport por API.
Criterio: Amigabilidad
```
```text
[🟡 MEDIO] Divergencia de vocabulario de roles (ROLE-01)
Ubicación: role_utils.dart:47-60 vs firestore.rules:42-50
Real: 'Mecánico'/'mecanico'/'admin' → la UI concede, el backend deniega. Falla cerrado.
Criterio: Roles
```
```text
[🟡 MEDIO] 404 crudo · [🟡] Reseña pierde fotos al editar · [🟢] Deprecated sin consumidor ·
[🟢] seedAdminAccounts muerto · [🟢] image_painter y lottie sin usar
```

---

## 9. SEGURIDAD

**CONFIRMADOS:** SEC-01 (contraseña compartida), SEC-02 (verificación no impuesta en ninguna capa),
SEC-03 (oráculo PII con mitigación inactiva), política de contraseñas de 6 caracteres.

**POTENCIALES:** `seedAdminAccounts` como superficie muerta; lectura pública de `resenias` expone
`id_usuario` del autor; divergencia de roles como fuente de confusión operativa.

**NO VERIFICADOS:** enforcement real de App Check en consola, políticas de Auth, MFA, revocación de sesión,
aislamiento multi-tenant bajo carga.

**LO QUE ESTÁ BIEN Y HAY QUE DECIRLO:** la autorización vive en el servidor y está *probada* (321 tests);
`isMecanico()` exige estado aprobado además del rol; el hard delete es exclusivo de Superusuario; nadie puede
auto-asignarse rol privilegiado (probado); no hay secretos commiteados.

---

## 10. UX/UI · 11. RESPONSIVE

| Viewport | Landing | App Flutter |
|---:|---|---|
| 320 px | sin overflow (Codex) | sin overflow (Codex, formularios públicos) |
| 375 px | sin overflow (367/375) pero **navegación 0/3 visible** (propio) | ídem |
| 390 px | — | sin overflow (Codex) |
| 414 px | — | sin overflow (Codex) |

**Advertencia sobre esta tabla:** todas estas mediciones fijan el viewport por API. Con `web/index.html` sin
meta viewport, **no predicen el comportamiento en un teléfono real**. Dashboards y vistas con datos siguen
NO VERIFICADOS en cualquier ancho.

---

## 12. ROLES

| Rol | Acción | Permitido | Resultado | Evidencia |
|---|---|---|---|---|
| Propietario | leer doc de otro usuario | No | **denegado (probado)** | EVID-CL-RULES-001 |
| Propietario | auto-asignarse Administrador/Superusuario/Taller | No | **denegado (probado)** | EVID-CL-RULES-001 |
| Mecánico pendiente | operaciones de taller | No | **denegado por `estado` (probado)** | EVID-CL-RULES-001 |
| Mecánico aprobado | operaciones de taller | Sí | **permitido (probado)** | EVID-CL-RULES-001 |
| Administrador | gestión | Sí | reglas probadas; **UI no probada** | — |
| Administrador | entrar por nombre de usuario | Sí (según UI) | **falla siempre** | EVID-CL-FUNC-002 |
| Superusuario | provisionar cuentas | Sí | **funciona, con credencial insegura** | EVID-CL-SEC-001 |
| Cuenta con rol acentuado | ver panel de taller | No | **UI concede, backend deniega** | EVID-CL-ROLE-001 |

---

## 13. BASE DE DATOS

Flujo UI → provider → repositorio → Firestore/Functions → stream → UI presente en todos los dominios.
La capa de reglas y persistencia está probada contra emulador real por entidad (§5.4). Lo que falta es el
ciclo visible: crear → refrescar → ver, delante de una persona. Cron, backup y notificaciones siguen sin
evidencia de despliegue ni de scheduler.

---

## 14. FUNCIONALIDADES

**🟢 Completas con evidencia:** autorización por rol y estado; lógica de vínculo taller-vehículo (triggers);
validación de formularios públicos; build de landing; suites de las tres capas.
**🟡 Parciales:** vehículos, chat, cotizaciones, reservas, reparaciones, reseñas, administración
(código y reglas sí; recorrido visible no).
**🔴 Rotas o inalcanzables:** PDF del NIT, login admin por nombre de usuario, contacto de la landing,
CTA de iOS, edición de fotos de reseña.
**⚪ No verificadas:** CRUD desde UI, notificaciones/cron/backup, flujos multirol autenticados, móvil real.

---

## 15. FALSOS EXCELENTES

1. **`file_picker` está en `pubspec.yaml` ≠ el NIT acepta PDF.** La rama PDF existe y su test pasa inyectando
   un `XFile` que el picker real nunca puede devolver.
2. **El login admin por usuario está implementado y testeado ≠ funciona.** Los tests solo pasan correos y usan
   `FakeFirestore`, que no aplica reglas. En producción la lectura se deniega siempre. *(Mismo patrón que 1 —
   y es el patrón que este proyecto debería buscar sistemáticamente.)*
3. **Se envía correo de verificación ≠ se exige.** Cero gates en reglas, functions y router.
4. **1571 tests en verde ≠ los flujos funcionan.** Las tres capas están probadas *por separado*; ningún test
   recorre UI → Auth → reglas → Firestore → UI.
5. **`image_painter` y `lottie` en `pubspec.yaml` ≠ innovación.** Cero importaciones.
6. **"Sin overflow horizontal en 320-414 px" ≠ funciona en un móvil.** Falta el meta viewport.
7. **Existe App Check ≠ hay protección.** Fail-open en cliente y modo monitorización en servidor.
8. **`seedAdminAccounts` existe ≠ se usa.** Cero consumidores.

---

## 16. LO QUE REALMENTE ESTÁ MUY BIEN

- **La capa de autorización.** 1403 líneas de reglas, comentadas con el razonamiento y el incidente que
  motivó cada una, y **321 pruebas contra emulador real que pasan**. Está muy por encima del nivel esperado.
- **Disciplina de pruebas.** 1571 pruebas en verde en tres capas, con teardown limpio.
- **Higiene de secretos.** `.env`, `app.env`, keystores fuera del repositorio; el único identificador literal
  es un client ID OAuth, que es público por diseño y está documentado como tal.
- **Honestidad técnica del código.** Varios comentarios documentan el riesgo residual aceptado en vez de
  ocultarlo (cotización no atómica, oráculo de correo). Es buena ingeniería —aunque, como se dice en §1,
  también deja el mapa de los defectos servido al evaluador.
- **Amplitud tecnológica real:** QR, mapas, PDF, gráficas, notas de voz, caché offline, push, Crashlytics.

---

## 17. TOP 10 PROBLEMAS

| # | Problema | Severidad | Criterio | Puntos en riesgo |
|---:|---|---|---|---:|
| 1 | Contraseña compartida fija y retornada | 🔴 Crítico | Seguridad | 5-10 |
| 2 | Verificación de correo sin ningún gate | 🔴 Crítico | Seguridad | 5-10 |
| 3 | NIT no aceptable en PDF (S1) | 🟠 Alto | Funcionalidad | 5 |
| 4 | Sin E2E autenticado / CRUD visible | 🟠 Alto | BD + Funcionalidad | 5+ |
| 5 | Login admin por usuario siempre falla (nuevo) | 🟠 Alto | Funcionalidad/Roles | 3 |
| 6 | Oráculo PII con mitigación inactiva | 🟠 Alto | Seguridad | 3 |
| 7 | Contacto decorativo + CTA iOS placeholder | 🟠 Alto | Amigabilidad/Func. | 3 |
| 8 | Navegación móvil inalcanzable en landing | 🟠 Alto | Amigabilidad | 3 |
| 9 | Sin meta viewport en la app web | 🟡 Medio | Amigabilidad | 2-5* |
| 10 | Divergencia de vocabulario de roles | 🟡 Medio | Roles | 2 |

\* 2 si la demo es la APK; hasta 5 si es web sobre un teléfono.

---

## 18. TOP 10 MEJORAS (impacto × facilidad)

1. **Borrar la constante de contraseña y emitir enlace de configuración único.** Crítico/Seguridad. Bajo esfuerzo, máximo retorno.
2. **Gate de `emailVerified` en router + `context.auth.token.email_verified` en callables privilegiados; quitar "continuar sin verificar".** Crítico/Seguridad.
3. **Una línea en `web/index.html`: el meta viewport.** Medio/Amigabilidad. El mejor ratio del informe.
4. **`file_picker` para el slot NIT (S1).** Alto/Funcionalidad. Ya asignada.
5. **Contacto: `mailto:` etiquetado o endpoint real, con `required` y feedback; ocultar el CTA de iOS.** Alto/Amigabilidad.
6. **Menú hamburguesa accesible en la landing.** Alto/Amigabilidad.
7. **Decidir el login admin por usuario: eliminarlo de la UI, o resolver el usuario en un callable.** Alto/Funcionalidad.
8. **Guion de demo grabado del recorrido completo por rol** (registro → verificar → crear vehículo → refrescar → cotización → ticket → reseña → PDF/QR). Sube BD, Funcionalidad y Creatividad **sin escribir código de producto**.
9. **Vocabulario canónico de roles + migración dry-run.** Medio/Roles.
10. **Quitar `image_painter`, `lottie`, los `@Deprecated` sin consumidor y `seedAdminAccounts`.** Bajo/Creatividad+Higiene.

---

## 19. FUNCIONALIDADES NUEVAS

| Función | Valor | Tecnología | Criterio | Dificultad | Impacto |
|---|---|---|---|---|---|
| QR temporal de historial compartido | interoperabilidad taller↔cliente con caducidad | callable + token expirable + `mobile_scanner` ya presente | Creatividad + Seguridad | Media | Alto |
| Expediente PDF verificable del vehículo | confianza y portabilidad | `pdf`/`printing` + Storage, ya presentes | Creatividad | Media | Alto |
| Recordatorio de mantenimiento explicable | proactividad | reglas locales sobre historial | Creatividad | Media | Medio |

**No implementar ninguna hasta cerrar los P0.** Regla 54: nunca C antes que A.

---

## 20. ROADMAP

**🔴 BLOQUEANTES (antes de presentar):** contraseña compartida · gate de verificación de correo · PDF del NIT ·
meta viewport · contacto y CTA de iOS.
**🟠 ALTO IMPACTO:** E2E autenticado contra emulador con CRUD+refresh por rol · oráculo PII · login admin por
usuario · menú móvil de la landing.
**🟡 PULIDO:** roles canónicos · 404 accionable · errores de Firestore localizados · fotos de reseña ·
limpieza de código muerto y dependencias sin usar.
**🟢 INNOVACIÓN:** solo tras lo anterior — demo guionizada primero, QR temporal después si hace falta.

---

## 21. PUNTUACIÓN DESPUÉS DE LAS MEJORAS

```text
PUNTUACIÓN ACTUAL:                 64/100
DESPUÉS DE BLOQUEANTES:            74-80/100
DESPUÉS DE ALTO IMPACTO + E2E:     84-91/100
POTENCIAL MÁXIMO:                  94-100/100
```

Estimaciones prudentes, no garantías. El salto mayor no viene de código nuevo sino de **evidencia**: las
capas ya están bien construidas y probadas; lo que falta es demostrar que se conectan.

---

## 22. VEREDICTO DEL ABOGADO DEL DIABLO

Asumí que mi propia puntuación era generosa y volví a pasar. Encontré dos argumentos que la sostienen a la
baja y uno que la sostiene al alza.

**El argumento más fuerte del profesor:** *"No necesito ejecutar la aplicación para bajarle la nota. Abro el
código y el propio proyecto me señala sus fallos: una contraseña compartida escrita en claro con un comentario
que la defiende; un comentario que admite que dejó abierto un oráculo de datos personales y difiere el arreglo
a un mecanismo que otro comentario reconoce desactivado; y un reporte de pruebas commiteado con dos cruces
rojas. Y cuando abro la aplicación, la verificación de correo —el corazón del criterio de 20 puntos— se puede
saltar con un botón."*

**Segundo argumento:** dos de los caminos que la interfaz ofrece no se pueden recorrer en producción (PDF del
NIT, login admin por usuario) y **en ambos casos la suite está verde**. Eso invita a preguntar de cuántas
funciones más el verde no significa nada.

**A favor del proyecto, y es justo decirlo:** 321 pruebas de autorización contra emulador real es más
evidencia de roles y BD de la que presenta la inmensa mayoría de los trabajos evaluados con esta rúbrica.
Ese trabajo es real y está infravalorado en el 7/10 de ambos criterios; lo único que lo mantiene ahí son
defectos concretos y arreglables, no una debilidad de fondo.

**Los tres riesgos principales:** (1) que el profesor lea `functions/index.js`; (2) que pida un registro en
vivo y salte la verificación; (3) que abra la app en su propio teléfono, en el navegador, sin meta viewport.

---

## 23. VEREDICTO FINAL DEL JUEZ

> **"Si yo fuera el profesor y evaluara hoy esta aplicación siguiendo estrictamente la rúbrica, le otorgaría 64/100."**

### Las 3 razones principales de esta puntuación:

1. **Los defectos de seguridad son concretos, verificables y están en el criterio que más pesa.** Una
   contraseña compartida en el repositorio y una verificación de correo que no condiciona nada impiden llamar
   "seguro" al registro, por muy correcto que sea todo lo demás.
2. **La ingeniería es mucho mejor que su demostración.** 1571 pruebas verdes y una capa de autorización
   ejemplar, pero ningún recorrido que atraviese UI → Auth → reglas → BD → UI. La rúbrica premia lo que se
   demuestra, y lo que se demuestra hoy son las capas por separado.
3. **Hay caminos que la interfaz promete y que en producción no existen** —el PDF del NIT y el login de
   administrador por nombre de usuario—, ambos con la suite en verde. Eso rebaja Funcionalidad y, más
   importante, rebaja la confianza en todo lo demás.

### Lo primero que arreglaría antes de presentar:

1. **La contraseña compartida y el gate de verificación de correo.** Son los dos únicos hallazgos que un
   profesor puede encontrar sin ejecutar nada, y valen hasta 10 puntos.
2. **El meta viewport, el formulario de contacto y el CTA de iOS.** Tres arreglos de minutos, todos visibles
   en el primer minuto de la demostración.
3. **Un recorrido E2E autenticado contra emulador, grabado.** Convierte de un golpe cuatro "NO VERIFICADO" en
   evidencia, y es lo que separa el 64 del 85.

---

## 24. DISCREPANCIAS CON LA AUDITORÍA DE CODEX

Coincido en el total (64/100) y en cada nivel por criterio. **No coincido en varias de las razones**, y en un
caso el plan de remediación contiene una instrucción técnicamente inviable.

**Refuto (con evidencia):**

| Afirmación de Codex / del plan | Realidad verificada |
|---|---|
| `EVID-RULES-001`: reglas NO VERIFICADO | `test_rules`: **321 PASS, 18/18 suites, exit 0** |
| `ROLE-001..003` y `DB-001..004`: NO VERIFICADO | la capa de autorización y persistencia **sí** está probada contra emulador real por entidad y por rol |
| Top-10 #10 «Deep-link estático 404» y UX-02 «hosting SPA probado» | `firebase.json` target `app` **ya tiene** `rewrites: [{source:"**", destination:"/index.html"}]`. **Falso positivo.** |
| `QA-02`: «la suite de reglas deja procesos y puertos ocupados» | corrió limpia, apagó los emuladores y liberó los puertos. **No reproducible hoy.** |
| «las pruebas usan principalmente FakeFirestore/mocks» | cierto de la suite Flutter, **falso** de la suite de reglas, que usa el emulador real |
| Suite Flutter «salida no capturada de forma concluyente» | **1123 PASS, exit 0** |

**Corrijo el plan de remediación (DATA-01):** la instrucción *«migrar las dos escrituras a batch atómico»* es
inviable. La regla de `cotizaciones/{id}/privado/{docId}` hace `get()` sobre el documento padre, y `get()`
dentro de un batch no ve las escrituras del mismo batch: el padre debe existir antes. El comentario del código
tiene razón. **La única vía válida es la alternativa `draft/pending` que el propio plan menciona en segundo
lugar; la primera opción debe eliminarse para que nadie la intente.**

**Añado (Codex no los reporta):**

1. El login de administrador por nombre de usuario **nunca puede funcionar** (§5.5, hallazgo 2). Alto.
2. La mitigación de SEC-03 **no existe hoy**: App Check está fail-open en cliente y en modo monitorización.
3. Política de contraseñas de 6 caracteres sin complejidad.
4. `image_painter` y `lottie` declaradas con cero uso.
5. `seedAdminAccounts`: código privilegiado muerto en el cliente.
6. La ausencia de meta viewport **invalida parcialmente la evidencia responsive de ambas auditorías**
   (Codex lo menciona pero no extrae la consecuencia).
7. Higiene de secretos correcta — mérito que Codex no acredita.

**Consecuencia práctica para el plan:** VER-01, SEC-01, SEC-02 y SEC-03 siguen siendo los P0 correctos. Pero
**QA-02 puede cerrarse sin trabajo**, **la parte de rewrite SPA de UX-02 ya está hecha**, y **QA-01 parte de
mucho más terreno ganado del que el plan asume**: lo que falta no es la matriz de reglas —existe y pasa— sino
el recorrido autenticado por la UI.
