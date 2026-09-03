# QA con Playwright CLI + endurecimiento DevOps para la demo — Plan de implementación

> **Para trabajadores agénticos:** SUB-SKILL REQUERIDA: usa `superpowers:subagent-driven-development`
> (recomendado) o `superpowers:executing-plans` para implementar este plan tarea a tarea.
> Los pasos usan sintaxis de casilla (`- [ ]`) para el seguimiento.

**Fecha:** 2026-09-01 · **Rama base:** `main` (`388cad9`) · **Demo:** 2026-09-03

**Goal:** Dejar AutoDoc en estado presentable el 2026-09-03 con evidencia — un arnés de
Playwright CLI que corre de verdad (hoy no corre), cobertura E2E de los cinco flujos que se
van a enseñar, regresión automatizada de los cuatro bloqueadores 🔴 ya corregidos, y un
camino de despliegue con verificación previa y vuelta atrás ensayada.

**Architecture:** Tres capas independientes que se pueden abortar por separado sin perder las
anteriores. **(1) Arnés**: se sustituye el `webServer` roto de Playwright (`flutter run
-d web-server`, que la memoria del proyecto documenta como inservible) por
`flutter build web` + servidor estático con guardia de bundle completo, y se sustituyen los
`waitForTimeout(15000)` por espera real al árbol de semántica de Flutter. **(2) Cobertura**:
un spec por rol siguiendo el guion literal de la demo, más un spec de regresión de los
hallazgos 🔴. **(3) Entrega**: el mismo arnés se apunta con `E2E_BASE_URL` contra un
**canal de preview** de Firebase Hosting, se verifica ahí, y solo entonces se clona a `live`
— lo que da la vuelta atrás gratis.

**Tech Stack:** Playwright `@playwright/test` (subir a ≥1.51 por `storageState({indexedDB:true})`)
· Node 24.14.1 · Flutter 3.41.6 / Dart 3.11 · Firebase CLI 15.28.2 (Hosting, Auth, Firestore,
Storage, Functions) · GitHub Actions · `gh` 2.97.0.

**Spec:** `docs/qa/REPORTE_QA_PLAYWRIGHT_2026-08-28.md` (§N de este plan se refiere a sus
secciones) y `docs/PLAN_ESTABILIZACION_DEMO.md`. Las decisiones que corrigieron ese plan
durante su ejecución están en `docs/superpowers/plans/2026-08-28-decisiones-de-ejecucion.md`
y **hay que leerlas antes** de tocar nada que ese registro mencione.

---

## Global Constraints

- **No hay entorno de staging.** `docs/RUNBOOK.md` §"Pendiente 1": `autodoc-staging` **no
  existe todavía** (requiere permisos de facturación). El alias está declarado en
  `.firebaserc` pero apunta al vacío, así que el job `deploy_staging` de CI **falla siempre**.
  Todo este plan corre contra **producción `autodoc-6ef5a`** bajo cuarentena. Ver Decisión 0.
- **Cada acción de QA escribe en producción.** Reglas de higiene, sin excepción:
  - Cuentas permitidas: `nadie@gmail.com` / `hola123` (Propietario),
    `taller1@taller.com` / `hola123` (Taller aprobado, "Taller Prueba"),
    `superadmin@autodocsv.com` / `SuperAdmin123` (Superusuario). No crear otras.
  - Si hace falta crear una, prefijo `qa.` obligatorio y anotarla en el registro de rastro
    (Tarea 16) para que el usuario la borre.
  - **Nunca** pulsar Aprobar/Rechazar sobre una verificación de un taller real.
  - Buscar una placa en el panel del taller ya **no** crea ticket (arreglado en `13ab14a`),
    pero confirmar el ticket sí notifica al propietario. Ver §2.2.
- **El bundle de web exige `flutter clean`.** `flutter build web` sobre un `build/` sucio
  emite un bundle incompleto (`assets/` vacío, sin `manifest.json`) y la app arranca en blanco
  con `FormatException: Unexpected token '<'`. `flutter clean` no es opcional. Presupuestar
  **4–6 min** por build.
- **Puerta de formato.** `dart format --output=none --set-exit-if-changed .` sobre el árbol
  entero antes de cada commit — es lo que hace el CI (`ci.yml:34`) y ya tumbó `main` dos veces.
  El hook local existe pero hay que activarlo: `git config core.hooksPath .githooks`.
- **Verificación por tarea:** `flutter analyze` limpio + `flutter test` en verde antes de commit
  en cualquier tarea que toque Dart. Las tareas de sólo-JS/CI no lo requieren.
- **Idioma de la UI**: cualquier texto visible nuevo va en `lib/l10n/app_es.arb` **y**
  `app_en.arb`. Sin literales en pantalla. (`CONVENTIONS.md`)
- **Los selectores E2E van por `getByLabel` sobre el árbol de semántica**, no por CSS: Flutter
  Web con CanvasKit no emite DOM de la UI. Esto condiciona todo el arnés.

---

## Decisión 0 — contra qué entorno se demuestra (léase antes que nada)

No es cosmética: cambia qué tareas aplican.

| Opción | Coste | Riesgo |
|---|---|---|
| **A. Producción + canal de preview (recomendada)** | 0 € y 0 min de infraestructura | La QA escribe en datos reales; se mitiga con las reglas de cuarentena de arriba |
| B. Crear `autodoc-staging` primero | Permisos de facturación + poblar datos desde cero + 13 secretos de GitHub por entorno | Alto para 48 h: `deploy_staging` nunca ha corrido verde, y una demo sobre datos vacíos no enseña nada |

**Recomendación: A.** Se demuestra sobre `autodoc-6ef5a`, que es donde viven las cuentas y los
vehículos que hacen que la demo se vea poblada. Crear staging queda como tarea **post-demo**
(Tarea 20). Todo el plan asume A; si se elige B, las Tareas 12–15 cambian de proyecto pero no
de forma.

---

## Estado verificado hoy (2026-09-01) — de dónde parte el plan

Reconocido en el repo, no supuesto:

| Hecho | Evidencia | Consecuencia |
|---|---|---|
| 🔴 El arnés E2E **no puede correr** | `e2e/playwright.config.js:19` usa `flutter run -d web-server`, que la memoria del proyecto y `docs/qa/REPORTE_QA_PLAYWRIGHT_2026-08-28.md` §1 documentan como página en blanco permanente | Tarea 3 |
| 🔴 `e2e/node_modules` no está instalado | `ls e2e/node_modules` vacío | Tarea 2 |
| 🟠 Los navegadores de Playwright **sí** están | `~/AppData/Local/ms-playwright/chromium-1234`, `firefox-1538`, `webkit-2336` | No hay que descargar 400 MB |
| 🔴 **El CI no tiene ningún job E2E** | `.github/workflows/ci.yml`, 6 jobs: `analyze_and_test`, `rules_tests`, `build_web_smoke`, `deploy_staging`, `deploy_production`, `release_apk`. Cero menciones a Playwright | Tarea 12 |
| 🔴 `deploy_staging` falla siempre | `docs/RUNBOOK.md` "Pendiente 1" — `autodoc-staging` no existe | Tarea 15 |
| 🟠 `build_web_smoke` **no sube el bundle** como artefacto | `ci.yml:111-205`, no hay `upload-artifact` | Tarea 12 lo necesita para no compilar dos veces |
| 🟠 Los 7 tests existentes son frágiles por diseño | `waitForTimeout(15000)` fijo, `retries: 0`, `reuseExistingServer: true` | Tareas 5–6 |
| 🟠 Hay 13 ficheros sin commitear (placas de El Salvador) + 1 test sin trackear | `git status` | Tarea 1 — o entra o se aparta, pero no se demuestra desde un árbol sucio |
| 🟠 Los dos MCP de Playwright no conectan | `CONNECT_TIMEOUT` a 30 s en esta sesión, ambos | El plan es **CLI puro**; el MCP sólo lo necesita `site-audit` (ver más abajo) |
| 🟡 `taller6@taller.com` ya está corregida a `taller1@` | `git diff e2e/tests/mecanico.spec.js` | Entra con la Tarea 1 |
| 🟡 Rastro de QA vivo en producción | §5 del informe: tickets `P376-571` y `P859-392` + un mensaje de chat "Mensaje de prueba QA 28/08" | Tarea 16 — saldrían en pantalla durante la demo |
| 🟡 App Check sin token confirmado | §2.17; `lib/main.dart:147` activa `ReCaptchaEnterpriseProvider` | Tarea 14 — un canal de preview tiene dominio nuevo y la clave de reCAPTCHA está atada a dominio |

---

## Skills y automatizaciones que aportan valor a este plan

Resultado de `find-skills` (marketplaces revisadas: `claude-plugins-official` 280+ plugins,
`easier-life-skills` 13, `karpathy-skills` 1, `ui-ux-pro-max-skill` 1 — modo offline, no se
buscó en la web porque no se pidió). Cada fila dice **en qué tarea concreta** se usa.

### Ya instaladas — de uso obligatorio en este plan

| Skill | Dónde se usa aquí |
|---|---|
| `superpowers:writing-plans` | Este documento |
| `superpowers:subagent-driven-development` | Ejecución de las Tareas 3–11, que son independientes entre sí |
| `superpowers:test-driven-development` | Tareas 5, 6, 10: test que falla → arnés → test que pasa |
| `superpowers:systematic-debugging` | Obligatoria en la Tarea 7 en cuanto un spec falle: la tentación con CanvasKit es subir el timeout, y eso esconde la causa |
| `superpowers:verification-before-completion` | Puerta de la Tarea 19 — nadie declara "listo" sin pegar la salida del comando |
| `superpowers:requesting-code-review` | Antes del merge de la rama de la Tarea 18 |
| `graphify` | Localizar los widgets y providers de cada pantalla del guion sin leer 733 líneas de `app_router.dart` a mano (grafo en `graphify-out/graph.json`, 3977 nodos) |
| `firebase-deploy-check` *(proyecto)* | **Puerta obligatoria** antes del `hosting:clone` de la Tarea 18 — es de solo lectura y verifica rama, flavor, diffs de reglas y proyecto destino |
| `/test` *(proyecto)* | Tareas 1 y 19: corre unit + rules en el orden correcto |
| `.claude/agents/firestore-rules-reviewer` | Sólo si la Tarea 14 acaba tocando `firestore.rules` |
| `code-review` *(built-in)* | Tarea 18, sobre el diff acumulado |

### Recomendadas para instalar — ordenadas por valor real aquí

#### 1. `site-audit` · easier-life-skills · Relevancia: **Alta**

**Qué hace:** `site-mapper` recorre el sitio una vez vía Playwright MCP y produce
`sitemap.json`; después `ux-analyst`, `accessibility-auditor`, `performance-auditor` y
`bug-script-runner` corren **en paralelo** sobre ese artefacto compartido. `bug-script-runner`
genera un spec de Playwright con selectores reales y lo ejecuta con `npx playwright test`.

**Por qué encaja:** es literalmente la forma del trabajo de la Tarea 11. El informe del 28-ago
tiene tres hallazgos de accesibilidad (§2.13, y los commits `ff2a1fb`, `a5f773d`, `6d89fdb` que
los cerraron) sin ninguna prueba automática que impida la regresión, y un hallazgo de arranque
de 5 s (§2.12) sin medición reproducible. Que genere el spec con selectores reales importa
mucho aquí: en CanvasKit los selectores no se adivinan.

**Salvedad — bloqueante hoy:** depende del **MCP de Playwright, que no conecta en esta sesión**
(`CONNECT_TIMEOUT` 30 s, los dos servidores). Reintentar la conexión antes de contar con esta
skill; si no levanta, la Tarea 11 hace la versión manual descrita ahí.

```
/plugin marketplace add dan323/easier-life-skills
/plugin install easier-life-skills/site-audit
```

#### 2. `firebase` · claude-plugins-official · Relevancia: **Alta**

**Qué hace:** MCP oficial de Google para Firestore, Auth, Functions, Hosting y Storage.

**Por qué encaja:** la Tarea 16 tiene que borrar de producción dos tickets de reparación
(`P376-571`, `P859-392`) y un mensaje de chat, y la Tarea 17 tiene que congelar un conjunto de
datos de demo. Hacerlo por la UI es justo lo que generó el rastro; hacerlo por consola web es
lento y no deja registro. Con el MCP queda scriptado y auditable. También cubre un punto ciego
que el CLI no alcanza: **verificar desde fuera** que `superadmin@autodocsv.com` tiene
`rol: 'Superusuario'` y no un valor heredado — que es la raíz de §2.1.

```
/plugin marketplace add anthropics/claude-plugins-official
/plugin install claude-plugins-official/firebase
```

#### 3. `chrome-devtools-mcp` · claude-plugins-official · Relevancia: **Alta**

**Qué hace:** controla un Chrome real — trazas de rendimiento, peticiones de red y mensajes de
consola **con el origen en el código**.

**Por qué encaja:** es el sustituto directo del MCP de Playwright caído, y cubre lo que el CLI
de Playwright hace peor. Tres hallazgos abiertos son exactamente de su dominio: el 403 de
Storage de §2.1 (petición de red), el App Check sin token de §2.17 (consola), y los 5 s de
arranque de §2.12 (traza de rendimiento). Ya existe `docs/qa/qa-consola-completa.log` como
prueba de que esa información se recogió a mano la vez anterior.

```
/plugin install claude-plugins-official/chrome-devtools-mcp
```

#### 4. `dependency-audit` · easier-life-skills · Relevancia: **Media-alta**

**Qué hace:** escanea dependencias buscando versiones obsoletas y vulnerabilidades conocidas
(`npm audit`, `pip-audit`, `cargo audit`), informe de sólo lectura.

**Por qué encaja:** este repo tiene **cuatro árboles de dependencias JS independientes** —
`functions/` (npm), `e2e/` (npm), `test_rules/` (npm) y `landing-web/` (pnpm) — y el CI no
audita ninguno: `analyze_and_test` sólo mira Dart. `functions/` se despliega a producción.
Es la Tarea 17.

```
/plugin install easier-life-skills/dependency-audit
```

#### 5. `mergify` · claude-plugins-official · Relevancia: **Media**

**Qué hace:** Test Insights — detección de tests inestables y cuarentena, además de colas de
merge.

**Por qué encaja:** un arnés E2E sobre CanvasKit **va a ser inestable**; es la naturaleza del
soporte. Sin datos de inestabilidad, el equipo hará lo de siempre: subir timeouts hasta que
deje de fallar, que es exactamente cómo se llegó al `waitForTimeout(15000)` actual. Instalar
después de que la Tarea 12 lleve unos días produciendo ejecuciones — antes no tiene señal.

```
/plugin install claude-plugins-official/mergify
```

#### 6. `sentry` · claude-plugins-official · Relevancia: **Media — post-demo**

**Por qué encaja:** la demo va contra producción sin ningún seguimiento de errores; si algo
revienta en vivo, la única evidencia es la consola del navegador del presentador.

**Por qué NO antes de la demo:** instrumentar Sentry toca `lib/main.dart`, añade una dependencia
y exige un build nuevo a 48 h de la presentación. Riesgo mal pagado. Anotado para el día
siguiente (Tarea 20).

#### 7. `code-audit` · easier-life-skills · Relevancia: **Baja para esta ventana**

Código muerto, cambios REST rompedores y calidad de logging. Valioso para el repo, irrelevante
para dejar la demo en pie en dos días. Post-demo.

### Revisadas y descartadas

| Skill | Motivo |
|---|---|
| `playwright@claude-plugins-official` | **Ya instalada** — y además **duplicada**: `installed_plugins.json` la lista dos veces en scope local para el mismo proyecto (`b819188d2eea` y `ed404106fcd8`, con `projectPath` que sólo difiere en la mayúscula de `c:`/`C:`). Sospechosa de causar el `CONNECT_TIMEOUT`. Ver Tarea 2, paso 5 |
| `web-app-penetration-testing`, `owasp-top-10-testing`, `penetration-testing-with-strix` | Ya instaladas, pero **lanzar un pentest contra producción a 48 h de la demo es imprudente**: crea datos, puede disparar límites de Firebase y bloquear cuentas. Post-demo, y contra staging |
| `testsprite-verify` / `testsprite-onboard` | Ya instaladas. Se solapan con Playwright para el mismo trabajo; meter un segundo arnés en 48 h duplica el mantenimiento sin añadir cobertura. Las cuentas de `testsprite_tests/tmp/config.json` son de emulador y no sirven contra producción |
| `docs` (changelog) | Útil, pero no mueve la aguja de la demo |
| `gitlab`, `teamcity-cli` | El proyecto usa GitHub Actions |
| `browser-use` | Se solapa con `chrome-devtools-mcp`, que es más preciso para trazas y red |
| `ui-ux-pro-max` | Ya instalada; el diseño no está en alcance esta semana |

---

## Mapa de ficheros

| Fichero | Responsabilidad | Tarea |
|---|---|---|
| `e2e/package.json` | Scripts (`test`, `test:demo`, `test:deployed`, `report`) y subida a Playwright ≥1.51 | 2 |
| `e2e/playwright.config.js` | **Reescrito**: proyectos desktop/mobile, reintentos, reporters, `webServer` conmutable por `E2E_BASE_URL` | 3 |
| `e2e/scripts/serve-build.js` *(nuevo)* | Servidor estático de `build/web` con fallback SPA **y guardia de bundle completo** | 4 |
| `e2e/support/flutter.js` *(nuevo)* | `waitForFlutterReady`, `enableSemantics`, `collectConsoleErrors` — mata los `waitForTimeout` | 5 |
| `e2e/support/accounts.js` *(nuevo)* | Las tres cuentas en un solo sitio, leídas de env con valor por defecto | 5 |
| `e2e/tests/auth.setup.js` *(nuevo)* | Login una vez por rol → `storageState` con `indexedDB: true` | 6 |
| `e2e/tests/{propietario,mecanico,registro}.spec.js` | Migrados a los helpers | 6 |
| `e2e/tests/demo-propietario.spec.js` *(nuevo)* | Guion literal de la demo, rol Propietario | 7 |
| `e2e/tests/demo-taller.spec.js` *(nuevo)* | Guion literal, rol Taller aprobado | 8 |
| `e2e/tests/demo-admin.spec.js` *(nuevo)* | Guion literal, rol Superusuario | 9 |
| `e2e/tests/regresion-bloqueadores.spec.js` *(nuevo)* | §2.1, §2.2, §2.3, §7.2 no vuelven | 10 |
| `e2e/tests/salud.spec.js` *(nuevo)* | Consola limpia, semántica presente, arranque bajo presupuesto | 11 |
| `.github/workflows/ci.yml` | `upload-artifact` en `build_web_smoke` + job `e2e_smoke` + guardia en `deploy_staging` | 12, 15 |
| `docs/RUNBOOK_DEMO.md` *(nuevo)* | Guion minuto a minuto, plan B y vuelta atrás | 18 |
| `docs/qa/rastro-produccion.md` *(nuevo)* | Registro de todo lo que la QA escribe en producción | 16 |

---

## Cronograma

| Cuándo | Fase | Tareas | Resultado |
|---|---|---|---|
| **Día 1 mañana** (2026-09-01) | 0 — Congelar y arrancar el arnés | 1–4 | `npx playwright test` arranca y carga la app |
| **Día 1 tarde** | 1 — Fiabilidad | 5–6 | Los 7 tests actuales pasan sin un solo `waitForTimeout` |
| **Día 2 mañana** (2026-09-02) | 2 — Cobertura de la demo | 7–11 | Los 3 guiones + regresión + salud, en verde |
| **Día 2 tarde** | 3 — DevOps | 12–17 | CI con puerta E2E · rastro limpio · vuelta atrás ensayada |
| **Día 2 noche** | 4 — Ensayo general | 18–19 | Go / No-Go firmado |
| Post-demo | 5 | 20 | Staging, Sentry, pentest |

**Tiempo de máquina que no se puede comprimir:** cada `flutter clean && flutter build web` son
4–6 min y este plan los pide ~6 veces (Tareas 4, 7, 12, 18, 19 ×2). Son ~35 min de reloj de
pared. Encadenarlos con otro trabajo, no esperarlos en vacío.

---

# Fase 0 — Congelar el árbol y hacer que el arnés arranque

## Tarea 1: Cerrar el trabajo en vuelo y fijar la línea base

Hay 13 ficheros modificados y 1 sin trackear (la funcionalidad de placas de El Salvador). No se
ensaya una demo desde un árbol sucio: o entra, o se aparta a una rama.

**Files:**
- Verify: todo el árbol
- Modify: ninguno (esta tarea sólo mide y commitea lo que ya existe)

**Interfaces:**
- Produce: un commit en `main` (o una rama apartada) y **el número exacto** de tests que pasan.
  Todas las tareas posteriores comparan contra ese número.

- [ ] **Paso 1: Activar el hook de formato local**

```bash
git config core.hooksPath .githooks
```

Existe porque la puerta de formato del CI tumbó `main` dos veces (`8fec781` y el run
33448386711, que murió en 26 s y dejó sin ejecutar todo `deploy_production`). El hook de
Claude Code sólo reacciona a `Edit|Write`: un fichero escrito por `sed` o por un subagente llega
sin formatear al commit.

- [ ] **Paso 2: Medir la línea base**

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
cd test_rules && npm test && cd ..
```

Esperado: formato limpio · analyze limpio · **≥689** tests de Flutter · **≥175** tests de reglas.
Apunta los números reales. Si algo falla, **para aquí** y arréglalo — el resto del plan asume
esta línea base.

- [ ] **Paso 3: Decidir el destino del trabajo en vuelo**

Si los tests de placas pasan → entra en `main`:

```bash
git add -A
git commit -m "feat(placas): formato de placas de El Salvador y kilometraje en el alta"
```

Si NO pasan → se aparta, no se arregla a 48 h de la demo:

```bash
git stash push -u -m "placas-el-salvador-wip"
```

Anota cuál de las dos ramas tomaste al principio de `docs/RUNBOOK_DEMO.md` (Tarea 18).

- [ ] **Paso 4: Crear la rama de trabajo**

```bash
git checkout -b qa/demo-readiness-2026-09-03
```

---

## Tarea 2: Reparar la instalación del arnés E2E

`e2e/node_modules` no existe, así que hoy `npx playwright test` ni siquiera arranca. Y la versión
declarada (`^1.40.1`) es anterior a `storageState({ indexedDB: true })`, que es lo que hace
viable reutilizar la sesión de Firebase Auth entre tests.

**Files:**
- Modify: `e2e/package.json`
- Create: `e2e/.gitignore` (ampliar el existente)

**Interfaces:**
- Produce: `npx playwright --version` ≥ 1.51 dentro de `e2e/`, y los scripts `test`, `test:demo`,
  `test:deployed`, `report`.

- [ ] **Paso 1: Instalar y subir Playwright**

```bash
cd e2e
npm install --save-dev @playwright/test@latest
npx playwright --version
```

Esperado: `Version 1.5x.y` con `x >= 1`. Si sale < 1.51, **para**: la Tarea 6 depende de
`indexedDB: true` y hay que cambiar de estrategia (ver su Paso 6, plan B).

- [ ] **Paso 2: Confirmar que los navegadores ya están (no descargar 400 MB de más)**

```bash
npx playwright install --dry-run chromium
```

Los navegadores están en `~/AppData/Local/ms-playwright` (`chromium-1234`, `firefox-1538`,
`webkit-2336`). Si la versión nueva de Playwright pide una revisión distinta de Chromium:

```bash
npx playwright install chromium
```

- [ ] **Paso 3: Escribir los scripts**

Sustituye el bloque `"scripts"` de `e2e/package.json` por:

```json
  "scripts": {
    "test": "playwright test",
    "test:demo": "playwright test tests/demo-",
    "test:regresion": "playwright test tests/regresion-bloqueadores.spec.js",
    "test:deployed": "playwright test --project=desktop",
    "report": "playwright show-report results/html",
    "report:md": "node scripts/generate_report.js"
  },
```

`test:deployed` está pensado para usarse con `E2E_BASE_URL` puesto (Tarea 18), que desactiva el
`webServer` local.

- [ ] **Paso 4: Ignorar los artefactos**

Añade a `e2e/.gitignore`:

```
node_modules/
results/
test-results/
playwright-report/
.auth/
```

`.auth/` guardará los `storageState`, **que contienen tokens de sesión de cuentas reales de
producción**. Que nunca entre en git.

- [ ] **Paso 5: Deduplicar el plugin de Playwright (causa probable del MCP caído)**

`~/.claude/plugins/installed_plugins.json` lista `playwright@claude-plugins-official` **dos
veces** en scope local para este mismo proyecto: `b819188d2eea` y `ed404106fcd8`, con
`projectPath` que sólo difiere en la mayúscula de la unidad (`c:\` frente a `C:\`). Los dos
servidores MCP dan `CONNECT_TIMEOUT` a 30 s.

```bash
claude plugin list
```

Desinstala la entrada duplicada y reinicia la sesión. **No bloquea este plan** — el plan es CLI
puro — pero sí bloquea la skill `site-audit` de la Tarea 11.

- [ ] **Paso 6: Commit**

```bash
git add e2e/package.json e2e/package-lock.json e2e/.gitignore
git commit -m "chore(e2e): subir Playwright a >=1.51 e instalar el arnes"
```

---

## Tarea 3: Reescribir `playwright.config.js`

Esta es la tarea que convierte el arnés de decorativo en real. La configuración actual arranca
la app con `flutter run -d web-server`, que **deja la página en blanco indefinidamente** cuando
Playwright se conecta (dos clientes sobre el mismo DDC/dwds; el otro modo, `-d chrome`, muere con
`WipError -32000 Cannot find context with specified id`). Está documentado en §1 del informe de
QA y en la memoria del proyecto. Mientras esa línea siga ahí, ningún test puede pasar.

**Files:**
- Modify: `e2e/playwright.config.js` (reescritura completa)

**Interfaces:**
- Consume: `e2e/scripts/serve-build.js` (Tarea 4).
- Produce: proyectos `setup`, `desktop`, `mobile`; `E2E_BASE_URL` y `E2E_PORT` como variables de
  entorno; reporters en `e2e/results/`.

- [ ] **Paso 1: Reemplazar el fichero entero**

```javascript
// @ts-check
const { defineConfig, devices } = require('@playwright/test');

const PORT = Number(process.env.E2E_PORT || 5600);

// Si E2E_BASE_URL viene puesta, se prueba contra una URL ya desplegada
// (canal de preview de Firebase Hosting, Tarea 18) y NO se levanta servidor local.
const EXTERNAL = process.env.E2E_BASE_URL;
const BASE_URL = EXTERNAL || `http://127.0.0.1:${PORT}`;

module.exports = defineConfig({
  testDir: './tests',
  outputDir: './results/artifacts',

  // Un arranque de CanvasKit sobre Firebase de produccion puede pasar de 30 s.
  timeout: 150_000,
  expect: { timeout: 25_000 },

  // Los tres roles comparten CUENTAS REALES de produccion: dos workers sobre
  // la misma cuenta se pisan el estado. Serie, a proposito. No subir.
  fullyParallel: false,
  workers: 1,

  retries: process.env.CI ? 2 : 1,
  forbidOnly: !!process.env.CI,

  reporter: [
    ['list'],
    ['html', { outputFolder: 'results/html', open: 'never' }],
    ['json', { outputFile: 'results/test-results.json' }],
    ['junit', { outputFile: 'results/junit.xml' }],
  ],

  use: {
    baseURL: BASE_URL,
    trace: 'retain-on-failure',
    video: 'retain-on-failure',
    screenshot: 'only-on-failure',
    actionTimeout: 25_000,
    navigationTimeout: 90_000,
    locale: 'es-SV',
    timezoneId: 'America/El_Salvador',
    // Flutter Web pinta en canvas: sin esto los videos salen en blanco.
    launchOptions: { args: ['--force-color-profile=srgb'] },
  },

  projects: [
    {
      name: 'setup',
      testMatch: /auth\.setup\.js/,
      use: { ...devices['Desktop Chrome'], viewport: { width: 1440, height: 900 } },
    },
    {
      name: 'desktop',
      dependencies: ['setup'],
      use: { ...devices['Desktop Chrome'], viewport: { width: 1440, height: 900 } },
    },
    {
      name: 'mobile',
      dependencies: ['setup'],
      // El panel de admin no tiene layout movil; se prueba solo en desktop.
      testIgnore: /demo-admin\.spec\.js/,
      use: { ...devices['Pixel 7'] },
    },
  ],

  webServer: EXTERNAL
    ? undefined
    : {
        command: `node scripts/serve-build.js --port=${PORT}`,
        url: `${BASE_URL}/index.html`,
        timeout: 60_000,
        reuseExistingServer: !process.env.CI,
        stdout: 'pipe',
        stderr: 'pipe',
      },
});
```

- [ ] **Paso 2: Verificar que la configuración carga**

```bash
cd e2e && npx playwright test --list
```

Esperado: lista los tests bajo los proyectos `setup`, `desktop` y `mobile`. **Aún fallará al
ejecutar** porque `scripts/serve-build.js` no existe — eso es la Tarea 4.

- [ ] **Paso 3: Commit**

```bash
git add e2e/playwright.config.js
git commit -m "fix(e2e): servir el bundle compilado en vez de 'flutter run', que deja la pagina en blanco"
```

---

## Tarea 4: Servidor estático con guardia de bundle

El `flutter build web` sobre un `build/` sucio produce un bundle **que arranca en blanco** con
`FormatException: Unexpected token '<'` — `assets/` vacío, sin `manifest.json`, sin
`favicon.png`, sin `firebase-messaging-sw.js`, y con `main.dart.js_*.part.js` viejos mezclados
con un `main.dart.js` nuevo. Ya pasó una vez y costó una sesión entera de depuración. El
servidor se niega a arrancar sobre un bundle así en vez de dejar que el fallo aparezca como un
timeout de Playwright a los 150 s.

**Files:**
- Create: `e2e/scripts/serve-build.js`

**Interfaces:**
- Produce: `node scripts/serve-build.js --port=5600` sirviendo `build/web` con fallback SPA;
  sale con código 1 y un mensaje accionable si el bundle está incompleto.

- [ ] **Paso 1: Escribir el servidor**

```javascript
#!/usr/bin/env node
// Sirve build/web con fallback SPA. Sin dependencias: solo node:http y node:fs.
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');

const ROOT = path.resolve(__dirname, '..', '..', 'build', 'web');
const portArg = process.argv.find((a) => a.startsWith('--port='));
const PORT = Number(portArg ? portArg.split('=')[1] : 5600);

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.wasm': 'application/wasm',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.woff2': 'font/woff2',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.bin': 'application/octet-stream',
  '.map': 'application/json; charset=utf-8',
};

// --- Guardia de bundle completo -------------------------------------------
// Los seis ficheros que faltaban en el bundle roto del 2026-08-28.
const REQUIRED = [
  'index.html',
  'main.dart.js',
  'flutter_bootstrap.js',
  'manifest.json',
  'favicon.png',
  'firebase-messaging-sw.js',
];

function bail(msg) {
  console.error(`\n[serve-build] ${msg}\n`);
  console.error('[serve-build] Reconstruye el bundle:');
  console.error('[serve-build]   flutter clean && flutter pub get \\');
  console.error('[serve-build]   && flutter build web --dart-define-from-file=.env\n');
  process.exit(1);
}

if (!fs.existsSync(ROOT)) bail(`No existe ${ROOT}.`);

for (const rel of REQUIRED) {
  if (!fs.existsSync(path.join(ROOT, rel))) bail(`Bundle incompleto: falta ${rel}.`);
}

const assetsDir = path.join(ROOT, 'assets');
if (!fs.existsSync(assetsDir) || fs.readdirSync(assetsDir).length === 0) {
  bail('Bundle incompleto: assets/ esta vacio.');
}

// Restos de un build anterior mezclados con uno nuevo: el sintoma exacto de
// haber compilado sin flutter clean.
const indexMtime = fs.statSync(path.join(ROOT, 'index.html')).mtimeMs;
const stale = fs
  .readdirSync(ROOT)
  .filter((f) => f.startsWith('main.dart.js'))
  .filter((f) => indexMtime - fs.statSync(path.join(ROOT, f)).mtimeMs > 3600_000);
if (stale.length) {
  bail(`Restos de un build anterior (mas de 1 h mas viejos que index.html): ${stale.join(', ')}`);
}
// --------------------------------------------------------------------------

const server = http.createServer((req, res) => {
  const urlPath = decodeURIComponent((req.url || '/').split('?')[0]);
  let filePath = path.join(ROOT, urlPath);

  // Nunca salir de ROOT.
  if (!path.resolve(filePath).startsWith(ROOT)) {
    res.writeHead(403).end('Forbidden');
    return;
  }

  if (fs.existsSync(filePath) && fs.statSync(filePath).isDirectory()) {
    filePath = path.join(filePath, 'index.html');
  }

  // Fallback SPA: go_router usa rutas como /mechanic_dashboard que no son ficheros.
  if (!fs.existsSync(filePath)) {
    filePath = path.join(ROOT, 'index.html');
  }

  const ext = path.extname(filePath).toLowerCase();
  res.writeHead(200, {
    'Content-Type': MIME[ext] || 'application/octet-stream',
    'Cache-Control': 'no-store',
    // CanvasKit y los workers de Flutter piden aislamiento de origen cruzado.
    'Cross-Origin-Opener-Policy': 'same-origin',
    'Cross-Origin-Embedder-Policy': 'credentialless',
  });
  fs.createReadStream(filePath).pipe(res);
});

server.listen(PORT, '127.0.0.1', () => {
  console.log(`[serve-build] ${ROOT} -> http://127.0.0.1:${PORT}`);
});
```

- [ ] **Paso 2: Comprobar que la guardia dispara**

Con el `build/web` actual (que puede estar sucio o no existir):

```bash
cd e2e && node scripts/serve-build.js --port=5600
```

Si el bundle está mal, esperado: salida con el mensaje `Bundle incompleto: falta ...` y código 1.
**Ese fallo es el éxito de este paso.** Si arranca a la primera, sigue al Paso 3 igual.

- [ ] **Paso 3: Construir el bundle bueno**

```bash
cd .. && flutter clean && flutter pub get && flutter build web --dart-define-from-file=.env
```

4–6 min. `flutter clean` no es negociable.

- [ ] **Paso 4: Comprobar que ahora sirve**

```bash
cd e2e && node scripts/serve-build.js --port=5600 &
curl -s -o /dev/null -w "%{http_code} %{content_type}\n" http://127.0.0.1:5600/index.html
curl -s -o /dev/null -w "%{http_code} %{content_type}\n" http://127.0.0.1:5600/main.dart.js
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:5600/mechanic_dashboard
```

Esperado: `200 text/html; charset=utf-8` · `200 text/javascript; charset=utf-8` · `200` (fallback
SPA). Mata el servidor al terminar.

- [ ] **Paso 5: Commit**

```bash
git add e2e/scripts/serve-build.js
git commit -m "feat(e2e): servidor estatico con guardia de bundle incompleto"
```

---

# Fase 1 — Fiabilidad: quitar las esperas ciegas

## Tarea 5: Helpers de semántica de Flutter

Los tres specs actuales empiezan con `await page.waitForTimeout(15000)`. Es una apuesta: en una
máquina lenta o con Firebase frío, 15 s no bastan y el test falla por una razón que no tiene nada
que ver con lo que prueba; en una rápida, se regalan 15 s por test. Con 7 tests son 105 s de
espera pura, y la Fase 2 los multiplica.

**Files:**
- Create: `e2e/support/flutter.js`
- Create: `e2e/support/accounts.js`

**Interfaces:**
- Produce: `waitForFlutterReady(page, opts)`, `enableSemantics(page)`, `gotoApp(page, ruta)`,
  `collectConsoleErrors(page)`, `login(page, cuenta)`.
- Produce: `ACCOUNTS.propietario | .taller | .admin`, cada una `{ email, password, rol, home }`.

- [ ] **Paso 1: Escribir `e2e/support/accounts.js`**

```javascript
// Cuentas reales del proyecto de PRODUCCION autodoc-6ef5a.
// No crear cuentas nuevas sin prefijo `qa.` y sin anotarlas en
// docs/qa/rastro-produccion.md (Tarea 16).
const ACCOUNTS = {
  propietario: {
    email: process.env.E2E_OWNER_EMAIL || 'nadie@gmail.com',
    password: process.env.E2E_OWNER_PASSWORD || 'hola123',
    rol: 'Propietario',
    home: '/dashboard',
  },
  taller: {
    email: process.env.E2E_SHOP_EMAIL || 'taller1@taller.com',
    password: process.env.E2E_SHOP_PASSWORD || 'hola123',
    rol: 'Mecanico',
    home: '/mechanic_dashboard',
  },
  admin: {
    email: process.env.E2E_ADMIN_EMAIL || 'superadmin@autodocsv.com',
    password: process.env.E2E_ADMIN_PASSWORD || 'SuperAdmin123',
    rol: 'Superusuario',
    home: '/admin/dashboard',
  },
};

module.exports = { ACCOUNTS };
```

- [ ] **Paso 2: Escribir `e2e/support/flutter.js`**

```javascript
const { expect } = require('@playwright/test');

/**
 * Espera a que el motor de Flutter haya montado la vista.
 * Sustituye a waitForTimeout(15000): espera a un hecho, no a un reloj.
 */
async function waitForEngine(page, timeout = 120_000) {
  await page.waitForFunction(
    () => !!document.querySelector('flt-glass-pane, flutter-view, flt-scene-host'),
    undefined,
    { timeout },
  );
}

/**
 * Fuerza el arbol de semantica y espera a que tenga nodos.
 * Sin esto, getByLabel() no encuentra NADA en CanvasKit: la UI es un canvas.
 */
async function enableSemantics(page, timeout = 60_000) {
  const placeholder = page.locator(
    'flt-semantics-placeholder, [aria-label="Enable accessibility"]',
  );
  if (await placeholder.count()) {
    await placeholder.first().click({ force: true, timeout: 10_000 }).catch(() => {});
  } else {
    // Truco documentado: un clic cualquiera dispara el arbol semantico.
    await page.mouse.click(8, 8);
  }
  await page.waitForFunction(
    () => {
      const host = document.querySelector('flt-semantics-host');
      return !!host && host.childElementCount > 0;
    },
    undefined,
    { timeout },
  );
}

/** Navega a una ruta y deja la app lista para getByLabel(). */
async function gotoApp(page, ruta = '/') {
  await page.goto(ruta, { waitUntil: 'domcontentloaded' });
  await waitForEngine(page);
  await enableSemantics(page);
}

/**
 * Errores de consola que NO son regresiones nuevas. Cada entrada cita el
 * hallazgo que la justifica; si se cierra el hallazgo, se borra la linea.
 */
const ERRORES_TOLERADOS = [
  /AppCheck|app-check|appCheck/i,          // §2.17, sin cerrar
  /ReCAPTCHA|recaptcha/i,                  // §2.17
  /Failed to load resource.*status of 404.*favicon/i,
  /net::ERR_BLOCKED_BY_CLIENT/i,           // bloqueadores del navegador
];

/** Empieza a recoger errores de consola. Devuelve el array vivo. */
function collectConsoleErrors(page) {
  const errores = [];
  page.on('console', (msg) => {
    if (msg.type() !== 'error') return;
    const texto = msg.text();
    if (ERRORES_TOLERADOS.some((re) => re.test(texto))) return;
    errores.push(texto);
  });
  page.on('pageerror', (err) => errores.push(`pageerror: ${err.message}`));
  page.on('response', (res) => {
    if (res.status() >= 400 && !/favicon/.test(res.url())) {
      errores.push(`HTTP ${res.status()} ${res.url()}`);
    }
  });
  return errores;
}

/** Inicia sesion desde la pantalla de login y espera al home del rol. */
async function login(page, cuenta) {
  await gotoApp(page, '/login');

  const email = page.getByLabel(/Correo|Email/i).first();
  await expect(email).toBeVisible({ timeout: 60_000 });
  await email.click();
  await email.fill(cuenta.email);

  const pass = page.getByLabel(/Contraseña|Password/i).first();
  await pass.click();
  await pass.fill(cuenta.password);

  await page.getByLabel(/Iniciar Sesión|Log In|Ingresar/i).first().click();

  // El router redirige segun el rol (lib/core/router/app_router.dart:154-159).
  await page.waitForURL((url) => url.pathname === cuenta.home, { timeout: 90_000 });
  await enableSemantics(page);
}

module.exports = {
  waitForEngine,
  enableSemantics,
  gotoApp,
  collectConsoleErrors,
  login,
  ERRORES_TOLERADOS,
};
```

- [ ] **Paso 3: Test que prueba el helper, no la app**

Crea `e2e/tests/arnes.spec.js`:

```javascript
const { test, expect } = require('@playwright/test');
const { gotoApp } = require('../support/flutter');

test.describe('Arnes', () => {
  test('la app carga y expone el arbol de semantica', async ({ page }) => {
    const t0 = Date.now();
    await gotoApp(page, '/');
    const ms = Date.now() - t0;

    const nodos = await page.evaluate(
      () => document.querySelector('flt-semantics-host')?.childElementCount ?? 0,
    );
    expect(nodos).toBeGreaterThan(0);

    console.log(`[arnes] semantica lista en ${ms} ms`);
    // Presupuesto holgado: si esto se pasa, algo va muy mal (ver §2.12).
    expect(ms).toBeLessThan(60_000);
  });
});
```

- [ ] **Paso 4: Ejecutar**

```bash
cd e2e && npx playwright test tests/arnes.spec.js --project=desktop
```

Esperado: **1 passed**, y en la salida `[arnes] semantica lista en NNNN ms`. **Apunta ese
número** — es la línea base de arranque para la Tarea 11.

Si falla en `waitForEngine`: el bundle está mal, vuelve a la Tarea 4 Paso 3.
Si falla en `enableSemantics`: usa `superpowers:systematic-debugging`. **No subas el timeout
sin entender por qué** — así nació el `waitForTimeout(15000)` que estás quitando.

- [ ] **Paso 5: Commit**

```bash
git add e2e/support e2e/tests/arnes.spec.js
git commit -m "feat(e2e): esperar al arbol de semantica en vez de a un reloj"
```

---

## Tarea 6: Sesión reutilizable y migración de los specs existentes

Cada login cuesta ~20 s contra Firebase de producción. Con 3 roles × ~10 tests son ~10 min de
puro login. `storageState` lo hace una vez por rol.

**Aviso importante:** Firebase Web SDK guarda la sesión en **IndexedDB**, no en `localStorage`.
El `storageState` clásico de Playwright **no** captura IndexedDB; hace falta
`storageState({ indexedDB: true })`, disponible desde Playwright 1.51. De ahí la Tarea 2.

**Files:**
- Create: `e2e/tests/auth.setup.js`
- Modify: `e2e/tests/propietario.spec.js`, `e2e/tests/mecanico.spec.js`, `e2e/tests/registro.spec.js`

**Interfaces:**
- Consume: `login`, `gotoApp` de `support/flutter.js`; `ACCOUNTS` de `support/accounts.js`.
- Produce: `e2e/.auth/propietario.json`, `taller.json`, `admin.json`.

- [ ] **Paso 1: Escribir `e2e/tests/auth.setup.js`**

```javascript
const { test: setup, expect } = require('@playwright/test');
const path = require('node:path');
const { ACCOUNTS } = require('../support/accounts');
const { login } = require('../support/flutter');

const AUTH_DIR = path.join(__dirname, '..', '.auth');

for (const [nombre, cuenta] of Object.entries(ACCOUNTS)) {
  setup(`sesion de ${nombre}`, async ({ page, context }) => {
    await login(page, cuenta);
    await expect(page).toHaveURL(new RegExp(`${cuenta.home}$`));

    // indexedDB: true es imprescindible — Firebase Auth vive ahi.
    await context.storageState({
      path: path.join(AUTH_DIR, `${nombre}.json`),
      indexedDB: true,
    });
  });
}
```

- [ ] **Paso 2: Ejecutar sólo el setup**

```bash
cd e2e && npx playwright test --project=setup
```

Esperado: **3 passed**, y tres ficheros en `e2e/.auth/`.

- [ ] **Paso 3: Verificar que la sesión de verdad se reutiliza**

Este paso existe porque el Paso 2 puede pasar y aun así la sesión no restaurarse. Crea
`e2e/tests/sesion.spec.js`:

```javascript
const { test, expect } = require('@playwright/test');
const { ACCOUNTS } = require('../support/accounts');
const { gotoApp } = require('../support/flutter');

test.use({ storageState: '.auth/propietario.json' });

test('la sesion guardada evita el login', async ({ page }) => {
  await gotoApp(page, ACCOUNTS.propietario.home);
  // Si la sesion NO se restauro, el router manda a /login (app_router.dart:227).
  await expect(page).toHaveURL(new RegExp(`${ACCOUNTS.propietario.home}$`));
});
```

```bash
npx playwright test tests/sesion.spec.js --project=desktop
```

Esperado: **1 passed**.

- [ ] **Paso 4: Plan B si el Paso 3 falla**

Si la URL acaba en `/login`, `indexedDB: true` no basta para el SDK de Firebase en esta versión.
**No pierdas más de 30 minutos aquí.** Repliega a login por test: borra `auth.setup.js`,
`sesion.spec.js` y el proyecto `setup` de la configuración, y usa en cada spec:

```javascript
test.beforeEach(async ({ page }) => {
  await login(page, ACCOUNTS.propietario);
});
```

Cuesta ~20 s por test. Con el volumen de este plan son ~7 min extra en la suite completa:
molesto, no bloqueante. Anótalo como deuda y sigue.

- [ ] **Paso 5: Migrar los tres specs existentes**

Sustituye el `beforeEach` de `e2e/tests/mecanico.spec.js` por:

```javascript
const { test, expect } = require('@playwright/test');
const { ACCOUNTS } = require('../support/accounts');
const { gotoApp } = require('../support/flutter');

test.use({ storageState: '.auth/taller.json' });

test.describe('Flujos del Mecánico', () => {
  test.beforeEach(async ({ page }) => {
    await gotoApp(page, ACCOUNTS.taller.home);
  });

  test('Verificación de Pantalla de Escáner', async ({ page }) => {
    await page.getByLabel(/Escanear Placa|Nuevo Servicio|Escanear/i).first().click();
    await expect(page.getByLabel(/Placa|Vehículo|Buscar/i).first()).toBeVisible();
  });

  test('Historial de Servicios del Taller', async ({ page }) => {
    await page.getByLabel(/Historial|Servicios/i).first().click();
    await expect(page.getByLabel(/Terminado|Fecha|Completado/i).first()).toBeVisible();
  });
});
```

Aplica el mismo patrón a `propietario.spec.js` con `.auth/propietario.json` y
`ACCOUNTS.propietario.home`. **`registro.spec.js` no lleva `storageState`** — prueba el alta de
usuarios nuevos, así que arranca sin sesión; sustituye ahí sólo los `waitForTimeout` por
`gotoApp(page, '/register')`.

> ⚠️ `registro.spec.js` **crea usuarios reales en producción** cada vez que corre. Márcalo con
> `test.describe.skip` para la suite por defecto y déjalo detrás de una variable:
> `test.describe(process.env.E2E_ALLOW_SIGNUP ? 'Registro' : 'Registro (omitido)', ...)`. Los
> usuarios que cree van al registro de la Tarea 16.

- [ ] **Paso 6: Comprobar que no queda ni un `waitForTimeout`**

```bash
cd e2e && grep -rn "waitForTimeout" tests/ support/ && echo "QUEDAN ESPERAS CIEGAS" || echo "limpio"
```

Esperado: `limpio`.

- [ ] **Paso 7: Suite completa**

```bash
npx playwright test --project=desktop
```

Esperado: todo verde salvo el registro omitido. **Apunta el tiempo total** — es la referencia
para el presupuesto de CI de la Tarea 12.

- [ ] **Paso 8: Commit**

```bash
git add e2e/tests e2e/support
git commit -m "feat(e2e): sesion reutilizable por rol y specs sin esperas ciegas"
```

---

# Fase 2 — Cobertura de lo que se va a enseñar

> **Principio de esta fase:** los specs de demo recorren **exactamente** el guion que se va a
> presentar, en el mismo orden. No son tests de cobertura: son un ensayo automatizado. Si el
> guion cambia, cambian ellos.
>
> **Principio de seguridad:** ningún spec de esta fase **confirma** una escritura sobre datos
> reales. Todos llegan hasta el diálogo de confirmación y cancelan. Lo que sí escribe
> (registro de usuarios, cierre de servicio) queda detrás de una variable de entorno y del
> registro de rastro de la Tarea 16.

## Tarea 7: Guion del Propietario

**Files:**
- Create: `e2e/tests/demo-propietario.spec.js`

**Interfaces:**
- Consume: `.auth/propietario.json`, `gotoApp`, `collectConsoleErrors`.
- Produce: capturas numeradas en `e2e/results/artifacts/` que sirven de storyboard de la demo.

- [ ] **Paso 1: Escribir el spec**

```javascript
const { test, expect } = require('@playwright/test');
const { gotoApp, collectConsoleErrors } = require('../support/flutter');

test.use({ storageState: '.auth/propietario.json' });

test.describe('Demo — Propietario', () => {
  test('recorrido completo del guion', async ({ page }, testInfo) => {
    const errores = collectConsoleErrors(page);

    await test.step('1. Panel principal', async () => {
      await gotoApp(page, '/dashboard');
      await expect(page.getByLabel(/Mis Vehículos|Garaje|Vehicles/i).first()).toBeVisible();
      await testInfo.attach('01-dashboard', {
        body: await page.screenshot({ fullPage: false }),
        contentType: 'image/png',
      });
    });

    await test.step('2. Garaje con al menos un vehiculo', async () => {
      await gotoApp(page, '/garage');
      const tarjetas = page.getByLabel(/Placa|P\d{3}-\d{3}/i);
      await expect(tarjetas.first()).toBeVisible();
      // §2.7: el nombre del vehiculo se recortaba a dos letras.
      const etiqueta = await tarjetas.first().getAttribute('aria-label');
      expect(etiqueta && etiqueta.length).toBeGreaterThan(3);
      await testInfo.attach('02-garaje', {
        body: await page.screenshot(),
        contentType: 'image/png',
      });
    });

    await test.step('3. Perfil del vehiculo e historial', async () => {
      await page.getByLabel(/Placa|P\d{3}-\d{3}/i).first().click();
      await page.waitForURL(/\/vehicle_profile\//, { timeout: 60_000 });
      await expect(page.getByLabel(/Historial|Mantenimiento|Kilometraje/i).first())
        .toBeVisible();
      await testInfo.attach('03-vehiculo', {
        body: await page.screenshot(),
        contentType: 'image/png',
      });
    });

    await test.step('4. Alertas coherentes', async () => {
      await gotoApp(page, '/alerts');
      const criticas = await page.getByLabel(/CRÍTICO/i).allTextContents();
      const optimas = await page.getByLabel(/ÓPTIMO/i).allTextContents();
      // §7.3: la misma tarea salia a la vez como CRITICO y como OPTIMO.
      const solape = criticas.filter((c) =>
        optimas.some((o) => o.split(' ')[0] && c.includes(o.split(' ')[0])),
      );
      expect(solape, `Tarea duplicada en dos severidades: ${solape.join(' | ')}`).toHaveLength(0);
      await testInfo.attach('04-alertas', {
        body: await page.screenshot(),
        contentType: 'image/png',
      });
    });

    await test.step('5. Directorio de talleres', async () => {
      await gotoApp(page, '/workshop_directory');
      await expect(page.getByLabel(/Taller|Buscar|Mapa/i).first()).toBeVisible();
      await testInfo.attach('05-talleres', {
        body: await page.screenshot(),
        contentType: 'image/png',
      });
    });

    await test.step('6. Chat', async () => {
      await gotoApp(page, '/chat_list');
      // §2.13: la barra lateral debe estar en el arbol semantico.
      await expect(page.getByLabel(/Conversaciones|Chats|Mensajes/i).first()).toBeVisible();
      await testInfo.attach('06-chat', {
        body: await page.screenshot(),
        contentType: 'image/png',
      });
    });

    expect(errores, `Errores de consola:\n${errores.join('\n')}`).toEqual([]);
  });
});
```

- [ ] **Paso 2: Ejecutar en desktop y en móvil**

```bash
cd e2e && npx playwright test tests/demo-propietario.spec.js
```

Esperado: **2 passed** (desktop + mobile). Si el paso 4 falla, §7.3 sigue abierto: anótalo como
hallazgo y **decide si se arregla o si se saca del guion** — no lo silencies.

- [ ] **Paso 3: Revisar las capturas como storyboard**

```bash
npx playwright show-report results/html
```

Míralas en orden. Si alguna no se ve presentable, ese es un hallazgo de demo, no un fallo de test.

- [ ] **Paso 4: Commit**

```bash
git add e2e/tests/demo-propietario.spec.js
git commit -m "test(e2e): guion de demo del propietario con capturas"
```

---

## Tarea 8: Guion del Taller

**Files:**
- Create: `e2e/tests/demo-taller.spec.js`

**Interfaces:**
- Consume: `.auth/taller.json`. Cuenta: `taller1@taller.com` ("Taller Prueba", aprobado).

- [ ] **Paso 1: Escribir el spec**

```javascript
const { test, expect } = require('@playwright/test');
const { gotoApp, collectConsoleErrors } = require('../support/flutter');

test.use({ storageState: '.auth/taller.json' });

// Placa de un vehiculo real de nadie@gmail.com, confirmada en el informe del 28-ago.
const PLACA = process.env.E2E_PLACA || 'P376-571';

test.describe('Demo — Taller aprobado', () => {
  test('recorrido completo del guion', async ({ page }, testInfo) => {
    const errores = collectConsoleErrors(page);

    await test.step('1. Tablero del taller', async () => {
      await gotoApp(page, '/mechanic_dashboard');
      await expect(page.getByLabel(/Servicios|Tablero|Reparaciones/i).first()).toBeVisible();
      await testInfo.attach('01-tablero', {
        body: await page.screenshot(), contentType: 'image/png',
      });
    });

    await test.step('2. Buscar placa — SIN confirmar el ticket', async () => {
      await gotoApp(page, '/mechanic_search');
      const campo = page.getByLabel(/Placa|Buscar/i).first();
      await campo.click();
      await campo.fill(PLACA);
      await page.keyboard.press('Enter');
      await expect(page.getByLabel(new RegExp(PLACA, 'i')).first()).toBeVisible();
      await testInfo.attach('02-placa-encontrada', {
        body: await page.screenshot(), contentType: 'image/png',
      });
      // §2.2: el ticket ya NO se crea al buscar (13ab14a). Se sale sin confirmar.
    });

    await test.step('3. Kanban de reparaciones', async () => {
      await gotoApp(page, '/mechanic_reparaciones');
      await expect(page.getByLabel(/Recibido|En Revisión|Terminado/i).first()).toBeVisible();
      await testInfo.attach('03-kanban', {
        body: await page.screenshot(), contentType: 'image/png',
      });
    });

    await test.step('4. Galeria del taller', async () => {
      await gotoApp(page, '/workshop_gallery');
      // §6.2 / §1.5: la galeria daba "usuario no autorizado". Las imagenes deben cargar.
      const fallos = [];
      page.on('response', (r) => {
        if (r.url().includes('firebasestorage') && r.status() >= 400) {
          fallos.push(`${r.status()} ${r.url()}`);
        }
      });
      await page.waitForTimeout(3_000); // unica espera fija: dar margen a las imagenes
      expect(fallos, `Storage rechazo:\n${fallos.join('\n')}`).toEqual([]);
      await testInfo.attach('04-galeria', {
        body: await page.screenshot(), contentType: 'image/png',
      });
    });

    await test.step('5. Historial y resenias', async () => {
      await gotoApp(page, '/mechanic_service_history');
      await expect(page.getByLabel(/Historial|Fecha|Completado/i).first()).toBeVisible();
      await gotoApp(page, '/mechanic_reviews');
      await testInfo.attach('05-resenias', {
        body: await page.screenshot(), contentType: 'image/png',
      });
    });

    expect(errores, `Errores de consola:\n${errores.join('\n')}`).toEqual([]);
  });
});
```

- [ ] **Paso 2: Ejecutar y commitear**

```bash
cd e2e && npx playwright test tests/demo-taller.spec.js
git add e2e/tests/demo-taller.spec.js
git commit -m "test(e2e): guion de demo del taller"
```

---

## Tarea 9: Guion del Administrador

**Files:**
- Create: `e2e/tests/demo-admin.spec.js`

- [ ] **Paso 1: Escribir el spec**

```javascript
const { test, expect } = require('@playwright/test');
const { gotoApp, collectConsoleErrors } = require('../support/flutter');

test.use({ storageState: '.auth/admin.json' });

test.describe('Demo — Administrador', () => {
  test('recorrido completo del guion', async ({ page }, testInfo) => {
    const errores = collectConsoleErrors(page);
    const storage403 = [];
    page.on('response', (r) => {
      if (r.url().includes('firebasestorage') && r.status() === 403) {
        storage403.push(r.url());
      }
    });

    for (const [nombre, ruta, etiqueta] of [
      ['01-panel', '/admin/dashboard', /Métricas|Usuarios|Talleres|Resumen/i],
      ['02-usuarios', '/admin/usuarios', /Usuario|Rol|Estado/i],
      ['03-talleres', '/admin/talleres', /Taller|Estado/i],
      ['04-verificaciones', '/admin/verificaciones', /Verificación|Fachada|Pendiente/i],
      ['05-resenias', '/admin/resenias', /Reseña|Calificación|Moderar/i],
      ['06-logs', '/admin/logs', /Registro|Acción|Fecha/i],
    ]) {
      await test.step(nombre, async () => {
        await gotoApp(page, ruta);
        await expect(page.getByLabel(etiqueta).first()).toBeVisible();
        await testInfo.attach(nombre, {
          body: await page.screenshot(), contentType: 'image/png',
        });
      });
    }

    // §2.1: el superadmin no veia la foto de fachada — storage.rules no aceptaba
    // 'Superusuario' en isAdmin(). Cerrado; esta assercion impide la regresion.
    expect(storage403, `403 de Storage para el superadmin:\n${storage403.join('\n')}`)
      .toEqual([]);

    // §2.15: el rol legado 'Usuario' ya no debe aparecer (migrado en c96a43f).
    await gotoApp(page, '/admin/usuarios');
    const roles = await page.getByLabel(/Rol/i).allTextContents();
    expect(roles.filter((r) => /\bUsuario\b/.test(r) && !/Propietario/.test(r))).toHaveLength(0);

    expect(errores, `Errores de consola:\n${errores.join('\n')}`).toEqual([]);
  });
});
```

> ⚠️ **Este spec no pulsa Aprobar ni Rechazar en `/admin/verificaciones`.** Es irreversible
> sobre un taller real. Sólo comprueba que la evidencia **se ve**, que es lo que estaba roto.

- [ ] **Paso 2: Ejecutar y commitear**

```bash
cd e2e && npx playwright test tests/demo-admin.spec.js --project=desktop
git add e2e/tests/demo-admin.spec.js
git commit -m "test(e2e): guion de demo del administrador"
```

---

## Tarea 10: Regresión de los cuatro bloqueadores 🔴

Los cuatro se corrigieron entre el 28 y el 31 de agosto, pero **ninguno tiene una prueba E2E que
impida que vuelvan**. Son los que hundirían la demo.

**Files:**
- Create: `e2e/tests/regresion-bloqueadores.spec.js`

- [ ] **Paso 1: Escribir el spec**

```javascript
const { test, expect } = require('@playwright/test');
const { gotoApp } = require('../support/flutter');

// §2.3 — El alta de vehiculo: el año "parecia relleno pero estaba vacio".
test.describe('§2.3 alta de vehiculo — el año se ve y se conserva', () => {
  test.use({ storageState: '.auth/propietario.json' });

  test('el año seleccionado queda visible en el campo', async ({ page }) => {
    await gotoApp(page, '/garage');
    await page.getByLabel(/Agregar Vehículo|Añadir|Nuevo Vehículo/i).first().click();

    const anio = page.getByLabel(/Año|Year/i).first();
    await expect(anio).toBeVisible();
    await anio.click();
    await page.getByLabel(/^2020$/).first().click();

    const valor = await anio.getAttribute('aria-label');
    expect(valor, 'El campo de año quedo vacio tras elegir 2020').toMatch(/2020/);

    // Se abandona el formulario: NO se crea vehiculo en produccion.
    await page.getByLabel(/Cancelar|Cerrar/i).first().click();
  });
});

// §2.2 — Buscar una placa NO debe crear ticket ni notificar al propietario.
test.describe('§2.2 buscar placa no crea ticket', () => {
  test.use({ storageState: '.auth/taller.json' });

  test('el kanban tiene los mismos tickets antes y despues de buscar', async ({ page }) => {
    const contar = async () => {
      await gotoApp(page, '/mechanic_reparaciones');
      return page.getByLabel(/Recibido.*P\d{3}-\d{3}|P\d{3}-\d{3}/i).count();
    };

    const antes = await contar();

    await gotoApp(page, '/mechanic_search');
    const campo = page.getByLabel(/Placa|Buscar/i).first();
    await campo.click();
    await campo.fill(process.env.E2E_PLACA || 'P376-571');
    await page.keyboard.press('Enter');
    await expect(page.getByLabel(/P\d{3}-\d{3}/i).first()).toBeVisible();

    const despues = await contar();
    expect(despues, 'Buscar una placa creo un ticket (regresion de §2.2)').toBe(antes);
  });
});

// §7.2 — Un taller no podia cerrar un servicio si el vehiculo no tenia tareas.
test.describe('§7.2 finalizar servicio sin tareas configuradas', () => {
  test.use({ storageState: '.auth/taller.json' });

  test('la pantalla no es un callejon sin salida', async ({ page }) => {
    await gotoApp(page, '/mechanic_reparaciones');
    const ticket = page.getByLabel(/P\d{3}-\d{3}/i).first();
    test.skip((await ticket.count()) === 0, 'No hay ticket abierto sobre el que probar');
    await ticket.click();

    const finalizar = page.getByLabel(/FINALIZAR SERVICIO|Finalizar/i).first();
    await expect(finalizar).toBeVisible();
    await expect(finalizar, 'El boton de finalizar esta deshabilitado').toBeEnabled();

    await finalizar.click();
    // Con tareas vacias ya NO debe salir el bloqueo seco de antes.
    await expect(page.getByLabel(/Selecciona al menos una tarea realizada/i))
      .toHaveCount(0);

    // Se cancela: no se cierra un servicio real.
    await page.getByLabel(/Cancelar|Cerrar|Volver/i).first().click();
  });
});
```

> El caso §2.1 (403 de Storage para el superadmin) ya está cubierto por la aserción
> `storage403` de la Tarea 9. No se duplica.

- [ ] **Paso 2: Ejecutar**

```bash
cd e2e && npx playwright test tests/regresion-bloqueadores.spec.js --project=desktop
```

Esperado: **3 passed** (o alguno `skipped` si no hay ticket abierto). **Un fallo aquí es un
No-Go de la Tarea 19**, no un test que ajustar.

- [ ] **Paso 3: Commit**

```bash
git add e2e/tests/regresion-bloqueadores.spec.js
git commit -m "test(e2e): regresion de los cuatro bloqueadores del informe del 28-ago"
```

---

## Tarea 11: Salud — consola, semántica y arranque

**Files:**
- Create: `e2e/tests/salud.spec.js`

- [ ] **Paso 1 (opcional, si el MCP de Playwright revive): delegar en `site-audit`**

```
/plugin install easier-life-skills/site-audit
```

Con el MCP en pie, `site-audit` produce `sitemap.json` y corre en paralelo `ux-analyst`,
`accessibility-auditor` y `performance-auditor`. Ejecuta esto **antes** del Paso 2 y usa sus
hallazgos para afinar los umbrales de abajo. Si el MCP sigue en `CONNECT_TIMEOUT`, salta al
Paso 2 sin más — el spec manual cubre lo esencial.

- [ ] **Paso 2: Escribir el spec**

```javascript
const { test, expect } = require('@playwright/test');
const { gotoApp, collectConsoleErrors } = require('../support/flutter');

// Presupuesto de arranque. §2.12 quito 5 s sacando el permiso de push del
// camino critico (bc7d72a). Ajusta con el numero real de la Tarea 5 Paso 4.
const PRESUPUESTO_MS = Number(process.env.E2E_BUDGET_MS || 25_000);

test.describe('Salud de la app', () => {
  test('el arranque en frio entra en presupuesto', async ({ page }) => {
    const t0 = Date.now();
    await gotoApp(page, '/login');
    const ms = Date.now() - t0;
    console.log(`[salud] arranque en frio: ${ms} ms (presupuesto ${PRESUPUESTO_MS})`);
    expect(ms).toBeLessThan(PRESUPUESTO_MS);
  });

  test('la pantalla de login no ensucia la consola', async ({ page }) => {
    const errores = collectConsoleErrors(page);
    await gotoApp(page, '/login');
    expect(errores, errores.join('\n')).toEqual([]);
  });

  test('las pantallas publicas exponen semantica', async ({ page }) => {
    for (const ruta of ['/', '/login', '/register', '/onboarding']) {
      await gotoApp(page, ruta);
      const nodos = await page.evaluate(
        () => document.querySelector('flt-semantics-host')?.childElementCount ?? 0,
      );
      expect(nodos, `Sin arbol semantico en ${ruta}`).toBeGreaterThan(0);
    }
  });

  test('ningun control interactivo se queda sin nombre', async ({ page }) => {
    // §2.13 / ff2a1fb: habia AppCards pulsables sin semanticLabel.
    await gotoApp(page, '/login');
    const sinNombre = await page.evaluate(() => {
      const host = document.querySelector('flt-semantics-host');
      if (!host) return ['sin arbol semantico'];
      return [...host.querySelectorAll('[role="button"]')]
        .filter((el) => !el.getAttribute('aria-label')?.trim())
        .map((el) => el.outerHTML.slice(0, 120));
    });
    expect(sinNombre, sinNombre.join('\n')).toEqual([]);
  });
});
```

- [ ] **Paso 3: Ejecutar, ajustar el presupuesto con el dato real, commitear**

```bash
cd e2e && npx playwright test tests/salud.spec.js --project=desktop
git add e2e/tests/salud.spec.js
git commit -m "test(e2e): guardias de consola, semantica y presupuesto de arranque"
```

---

# Fase 3 — DevOps

## Tarea 12: Puerta E2E en el pipeline

`ci.yml` tiene 6 jobs y **ninguno** ejecuta Playwright. Un E2E que sólo corre en el portátil de
quien lo escribió deja de correr el martes siguiente.

El diseño evita compilar dos veces: `build_web_smoke` ya hace el build de web pero **tira el
resultado**. Se sube como artefacto y `e2e_smoke` lo descarga.

**Files:**
- Modify: `.github/workflows/ci.yml`

**Interfaces:**
- Produce: artefacto `web-bundle`; job `e2e_smoke`; artefacto `playwright-report`.

- [ ] **Paso 1: Subir el bundle desde `build_web_smoke`**

Añade como último paso del job `build_web_smoke`:

```yaml
      - name: Subir el bundle web para el job de E2E
        uses: actions/upload-artifact@v4
        with:
          name: web-bundle
          path: build/web
          retention-days: 3
          if-no-files-found: error
```

- [ ] **Paso 2: Añadir el job `e2e_smoke`**

Insértalo después de `build_web_smoke` y **antes** de `deploy_staging`:

```yaml
  e2e_smoke:
    name: E2E Smoke (Playwright)
    runs-on: ubuntu-latest
    needs: build_web_smoke
    timeout-minutes: 35
    # Arranca sin bloquear: durante los primeros dias informa, no tumba.
    # Quitar esta linea cuando lleve 5 ejecuciones seguidas en verde (ver Paso 6).
    continue-on-error: true
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: npm
          cache-dependency-path: e2e/package-lock.json

      - name: Descargar el bundle web
        uses: actions/download-artifact@v4
        with:
          name: web-bundle
          path: build/web

      - name: Instalar dependencias del arnes
        working-directory: e2e
        run: npm ci

      - name: Instalar Chromium
        working-directory: e2e
        run: npx playwright install --with-deps chromium

      - name: Ejecutar la suite
        working-directory: e2e
        env:
          E2E_OWNER_EMAIL: ${{ secrets.E2E_OWNER_EMAIL }}
          E2E_OWNER_PASSWORD: ${{ secrets.E2E_OWNER_PASSWORD }}
          E2E_SHOP_EMAIL: ${{ secrets.E2E_SHOP_EMAIL }}
          E2E_SHOP_PASSWORD: ${{ secrets.E2E_SHOP_PASSWORD }}
          E2E_ADMIN_EMAIL: ${{ secrets.E2E_ADMIN_EMAIL }}
          E2E_ADMIN_PASSWORD: ${{ secrets.E2E_ADMIN_PASSWORD }}
        run: npx playwright test --project=desktop

      - name: Subir el informe
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: playwright-report
          path: |
            e2e/results/html
            e2e/results/junit.xml
            e2e/results/artifacts
          retention-days: 7
```

- [ ] **Paso 3: Cargar los seis secretos**

```bash
gh secret set E2E_OWNER_EMAIL     --body "nadie@gmail.com"
gh secret set E2E_OWNER_PASSWORD  --body "hola123"
gh secret set E2E_SHOP_EMAIL      --body "taller1@taller.com"
gh secret set E2E_SHOP_PASSWORD   --body "hola123"
gh secret set E2E_ADMIN_EMAIL     --body "superadmin@autodocsv.com"
gh secret set E2E_ADMIN_PASSWORD  --body "SuperAdmin123"
```

Van a **nivel de repositorio**, no de Environment: `e2e_smoke` no declara `environment:`, igual
que `build_web_smoke`, así que sólo ve secretos de repositorio (`docs/RUNBOOK.md`, "Pendiente 2").

> ⚠️ **Estas credenciales son de producción.** Que estén en secretos de GitHub significa que
> cualquiera con permiso de escritura en el repo puede exfiltrarlas con un workflow. Es
> aceptable para tres cuentas de prueba desechables; **no** lo sería para `superadmin` si esa
> cuenta tuviera datos reales que perder. Anotar en `docs/RUNBOOK.md` y rotarlas después de la
> demo (§2.2 del runbook ya describe cómo).

- [ ] **Paso 4: Validar el YAML antes de empujar**

```bash
gh workflow view "AutoDoc CI/CD" || python -c "import yaml,sys; yaml.safe_load(open('.github/workflows/ci.yml')); print('YAML OK')"
```

- [ ] **Paso 5: Empujar y observar**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: puerta de humo E2E con Playwright sobre el bundle de build_web_smoke"
git push -u origin qa/demo-readiness-2026-09-03
gh pr create --fill --title "QA + DevOps para la demo del 2026-09-03"
gh run watch
```

- [ ] **Paso 6: Cuándo volverlo bloqueante**

Cuando `e2e_smoke` acumule **5 ejecuciones seguidas en verde**, quita `continue-on-error: true` y
añádelo a `needs:` de `deploy_production`. **No lo hagas antes de la demo**: un E2E inestable que
bloquea el despliegue el día de la presentación es peor que no tenerlo.

---

## Tarea 13: Informe legible del recorrido

`e2e/scripts/generate_report.js` ya existe y produce `e2e/reporte_playwright.md`, pero se
alimenta del formato viejo de `results/test-results.json`. Con la configuración nueva la ruta
cambia y aparecen los `test.step`.

**Files:**
- Modify: `e2e/scripts/generate_report.js`

- [ ] **Paso 1: Comprobar qué produce hoy**

```bash
cd e2e && node scripts/generate_report.js && cat reporte_playwright.md
```

- [ ] **Paso 2: Que recorra los `suites` anidados y liste los pasos**

El reporter JSON de Playwright anida `suites[].suites[].specs[].tests[].results[]`. Ajusta el
recorrido para que baje recursivamente y para cada spec imprima el título, el estado, la duración
y —si falló— el `error.message` recortado a 400 caracteres. Añade al pie la ruta del informe HTML
(`results/html/index.html`) y la de las capturas (`results/artifacts/`).

- [ ] **Paso 3: Ejecutar la suite entera y generar el informe**

```bash
npx playwright test --project=desktop; node scripts/generate_report.js
git add e2e/scripts/generate_report.js e2e/reporte_playwright.md
git commit -m "chore(e2e): informe markdown al dia con el reporter nuevo"
```

---

## Tarea 14: Confirmar App Check antes de que rompa la demo

§2.17 quedó sin cerrar: App Check no consigue token. `lib/main.dart:147` activa
`ReCaptchaEnterpriseProvider(AppSecrets.recaptchaSiteKey)`. **Una clave de reCAPTCHA Enterprise
está atada a una lista de dominios.** El canal de preview de la Tarea 18 tiene un dominio nuevo
(`autodoc-6ef5a--demo-rc-XXXX.web.app`), así que si el enforcement estuviera activo, la demo
fallaría en el canal y no en `live` — el peor momento para descubrirlo.

**Files:** ninguno en el repo; es verificación de consola.

- [ ] **Paso 1: Ver si el enforcement está activo**

Firebase Console → App Check → APIs. Anota, para Firestore / Storage / Authentication, si están
en **Enforced** o **Unenforced**.

- [ ] **Paso 2: Si está en Unenforced (lo esperado)**

Los errores de consola de App Check son ruido, no fallos — ya están en `ERRORES_TOLERADOS`. **No
lo actives antes de la demo.** Anótalo como post-demo (Tarea 20).

- [ ] **Paso 3: Si está en Enforced**

Google Cloud Console → Security → reCAPTCHA Enterprise → la clave de `RECAPTCHA_SITE_KEY` →
Domain list. Añade el dominio del canal de preview **en cuanto lo tengas** (Tarea 18 Paso 2) y
`autodoc-6ef5a.web.app` / `.firebaseapp.com`. Sin esto, el canal da errores de autenticación.

- [ ] **Paso 4: Registrar el hallazgo**

Escribe el resultado en `docs/RUNBOOK_DEMO.md` (Tarea 18) bajo "Riesgos conocidos". Es
información que el presentador necesita si algo falla en vivo.

---

## Tarea 15: Poner una guardia en `deploy_staging`

`deploy_staging` corre en cada push a `staging` y **falla siempre** porque `autodoc-staging` no
existe (`docs/RUNBOOK.md`, "Pendiente 1"). Un job rojo permanente entrena al equipo a ignorar el
rojo — justo lo que no se quiere la semana de una demo.

**Files:**
- Modify: `.github/workflows/ci.yml` (job `deploy_staging`)

- [ ] **Paso 1: Guardia explícita como primer paso del job**

```yaml
      - name: Comprobar que el proyecto de staging existe
        run: |
          if [ -z "${{ secrets.FIREBASE_PROJECT_STAGING }}" ]; then
            echo "::warning::autodoc-staging no esta aprovisionado todavia."
            echo "Ver docs/RUNBOOK.md, 'Pendiente 1'. Se omite el despliegue a staging."
            echo "SKIP_STAGING=true" >> "$GITHUB_ENV"
          fi

      - name: Avisar y salir limpio
        if: env.SKIP_STAGING == 'true'
        run: exit 0
```

Y añade `if: env.SKIP_STAGING != 'true'` a cada paso posterior del job.

- [ ] **Paso 2: Verificar y commitear**

```bash
python -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml')); print('YAML OK')"
git add .github/workflows/ci.yml
git commit -m "ci: deploy_staging avisa en vez de fallar mientras el proyecto no exista"
```

---

## Tarea 16: Limpiar el rastro de QA de producción

El informe del 28-ago (§5) dejó en producción cosas que **saldrían en pantalla durante la demo**:

- ticket de reparación sobre `P376-571`, movido a *En Revisión*
- ticket de reparación sobre `P859-392`, en *Recibido*
- mensaje de chat «Mensaje de prueba QA 28/08» en la conversación con `usuario`

**Files:**
- Create: `docs/qa/rastro-produccion.md`

- [ ] **Paso 1: Abrir el registro de rastro**

```markdown
# Rastro dejado en produccion por la QA

Toda escritura que la QA haga sobre `autodoc-6ef5a` se anota aqui **en el momento**, no despues.

| Fecha | Que se creo/cambio | Donde | Borrado |
|---|---|---|---|
| 2026-08-28 | Ticket de reparacion `P376-571` (En Revision) | Taller Prueba | [ ] |
| 2026-08-28 | Ticket de reparacion `P859-392` (Recibido) | Taller Prueba | [ ] |
| 2026-08-28 | Mensaje «Mensaje de prueba QA 28/08» | Chat con `usuario` | [ ] |
```

- [ ] **Paso 2: Borrar los dos tickets**

Vía la app como `taller1@taller.com`: el botón de cancelar ticket del kanban existe desde
`aa2a640`. Es la forma preferida — deja registro de auditoría.

- [ ] **Paso 3: Borrar el mensaje de chat**

Como `taller1@taller.com`, en la conversación con `usuario`. El borrado real funciona desde
`6.1` del plan de estabilización.

- [ ] **Paso 4: Barrer cuentas `qa.`**

Con el MCP de `firebase` (recomendado) o en Firebase Console → Authentication:

```
lista usuarios cuyo email empiece por "qa." en autodoc-6ef5a
```

El informe dice que las tres de la sesión anterior ya se borraron; **verifícalo**, no lo asumas.

- [ ] **Paso 5: Marcar las casillas y commitear**

```bash
git add docs/qa/rastro-produccion.md
git commit -m "docs(qa): registro del rastro dejado en produccion y su limpieza"
```

---

## Tarea 17: Auditoría de dependencias de los cuatro árboles JS

`analyze_and_test` sólo mira Dart. Hay cuatro proyectos Node sin auditar y uno de ellos,
`functions/`, se despliega a producción.

- [ ] **Paso 1: Auditar los cuatro**

```bash
cd functions   && npm audit --omit=dev  ; cd ..
cd e2e         && npm audit --omit=dev  ; cd ..
cd test_rules  && npm audit --omit=dev  ; cd ..
cd landing-web && pnpm audit --prod     ; cd ..
```

O, si se instaló la skill: `/dependency-audit`.

- [ ] **Paso 2: Criterio de decisión (48 h antes de una demo)**

| Severidad | Acción |
|---|---|
| Critical/High **en `functions/`** (se despliega) | Arreglar ahora si el parche es de versión menor; si exige un mayor, anotar y hacerlo post-demo |
| Critical/High en `e2e/`, `test_rules/` | Anotar. No se despliegan; no tocar antes de la demo |
| Moderate/Low, cualquiera | Anotar. Post-demo |

**No hagas `npm audit fix --force` en ningún árbol esta semana.** Reescribe el lockfile y puede
romper `functions/` de formas que sólo se ven en producción.

- [ ] **Paso 3: Anotar el resultado**

Añade una sección "Auditoría de dependencias 2026-09-02" a `docs/qa/rastro-produccion.md` con la
tabla de hallazgos y la decisión tomada en cada uno.

---

# Fase 4 — Ensayo general

## Tarea 18: Canal de preview, vuelta atrás ensayada y runbook de la demo

Este es el corazón de la parte DevOps. Hoy el camino a producción es: push a `main` → CI
despliega a `live`. Si algo sale mal, la única salida es la consola de Firebase, a mano, con el
público delante.

El patrón que lo arregla: **desplegar primero a un canal de preview**, verificarlo con el mismo
arnés de Playwright apuntado con `E2E_BASE_URL`, y sólo entonces clonarlo a `live`. La vuelta
atrás sale gratis, porque el canal anterior sigue vivo.

**Files:**
- Create: `docs/RUNBOOK_DEMO.md`

**Interfaces:**
- Produce: canal `demo-rc` (candidato) y canal `rollback` (último bueno conocido), ambos en
  `autodoc-6ef5a`, sitio `app`.

- [ ] **Paso 1: Congelar el último bueno conocido en un canal de rescate**

Con el `build/web` que hoy está en `live` (o el que acabas de verificar en la Fase 2):

```bash
firebase hosting:channel:deploy rollback \
  --only app --project production --expires 7d
```

Anota la URL que imprime. **Ésa es la salida de emergencia.**

- [ ] **Paso 2: Compilar y desplegar el candidato**

```bash
flutter clean && flutter pub get
flutter build web --dart-define-from-file=.env
firebase hosting:channel:deploy demo-rc \
  --only app --project production --expires 7d
```

Anota la URL: `https://autodoc-6ef5a--demo-rc-XXXXXXXX.web.app`.

- [ ] **Paso 3: Autorizar el dominio del canal**

Firebase Console → Authentication → Settings → **Authorized domains**: comprueba que el dominio
del canal está. Firebase suele añadirlos solo, pero **verifícalo** — sin él, el login falla y no
hay error legible en pantalla. Si la Tarea 14 encontró App Check en *Enforced*, añade también el
dominio a la lista de la clave de reCAPTCHA Enterprise.

- [ ] **Paso 4: Correr la suite contra el canal**

```bash
cd e2e
E2E_BASE_URL="https://autodoc-6ef5a--demo-rc-XXXXXXXX.web.app" \
  npx playwright test --project=desktop
```

`E2E_BASE_URL` desactiva el `webServer` local (Tarea 3), así que esto prueba **el artefacto
desplegado**, no una copia local. Esperado: mismo verde que en local. Cualquier diferencia entre
local y canal es un problema de configuración de dominio — resuélvelo aquí, no el día de la demo.

- [ ] **Paso 5: Promover a `live`**

```bash
/firebase-deploy-check
```

Esta skill del proyecto es de solo lectura y verifica rama, flavor, diffs pendientes en
`firestore.rules`/`storage.rules` y proyecto destino. **Pásala antes de promover.** Luego:

```bash
firebase hosting:clone \
  autodoc-6ef5a:demo-rc autodoc-6ef5a:live \
  --project production
```

- [ ] **Paso 6: Ensayar la vuelta atrás DE VERDAD**

No lo escribas en el runbook sin haberlo hecho una vez. Ahora, con calma:

```bash
firebase hosting:clone \
  autodoc-6ef5a:rollback autodoc-6ef5a:live --project production
```

Comprueba en el navegador que `live` volvió atrás. Después vuelve a promover el candidato con el
comando del Paso 5. **Cronometra los dos.** Si `hosting:clone` no acepta un canal como origen en
la versión 15.28.2 del CLI, **descúbrelo ahora**: la alternativa es Firebase Console → Hosting →
historial de versiones → "Rollback", que tarda unos 30 s. Anota en el runbook cuál de las dos
funcionó, con el comando o los clics exactos.

- [ ] **Paso 7: Escribir `docs/RUNBOOK_DEMO.md`**

```markdown
# Runbook de la demo — 2026-09-03

## Datos duros

| | |
|---|---|
| URL de la demo | https://autodoc-6ef5a.web.app |
| Canal de rescate | <URL del canal `rollback`> |
| Proyecto Firebase | `autodoc-6ef5a` (**produccion**) |
| Commit desplegado | <sha> |
| Navegador | Chrome, ventana 1440×900, **perfil limpio sin extensiones** |

## Cuentas (tenerlas ya abiertas en tres ventanas antes de empezar)

| Rol | Cuenta | Pantalla de inicio |
|---|---|---|
| Propietario | `nadie@gmail.com` / `hola123` | `/dashboard` |
| Taller | `taller1@taller.com` / `hola123` | `/mechanic_dashboard` |
| Superadmin | `superadmin@autodocsv.com` / `SuperAdmin123` | `/admin/dashboard` |

## Guion (mismo orden que los specs de la Fase 2)

1. Propietario: dashboard → garaje → perfil de vehiculo → alertas → talleres → chat
2. Taller: tablero → buscar placa → kanban → galeria → historial y resenias
3. Admin: panel → usuarios → talleres → verificaciones → resenias → registro

## Vuelta atras (30 s)

<el comando o los clics EXACTOS que funcionaron en el Paso 6, cronometrados>

## Riesgos conocidos y que decir si aparecen

- **App Check**: <resultado de la Tarea 14>. Si sale en consola, es ruido conocido; no se ve
  en pantalla.
- **Arranque**: ~<N> s en frio. Abrir las pestanas antes de empezar y dejarlas cargadas.
- **NO pulsar Aprobar/Rechazar** en `/admin/verificaciones`: es irreversible sobre un taller real.
- **NO confirmar** un ticket de reparacion desde la busqueda de placa: notifica al propietario.

## Plan B

1. Si `live` va mal → vuelta atras (arriba).
2. Si Firebase va mal → servir el bundle local:
   `cd e2e && node scripts/serve-build.js --port=5600` y abrir `http://127.0.0.1:5600`.
   (El backend sigue siendo produccion; esto solo salva un fallo de Hosting.)
3. Si la red va mal → el video del ensayo de la Tarea 19 Paso 4.
```

- [ ] **Paso 8: Commit**

```bash
git add docs/RUNBOOK_DEMO.md
git commit -m "docs(demo): runbook con guion, vuelta atras ensayada y plan B"
```

---

## Tarea 19: Ensayo general y Go / No-Go

**Files:** ninguno — esta tarea produce evidencia, no código.

> **SUB-SKILL REQUERIDA:** `superpowers:verification-before-completion`. Cada casilla de abajo se
> marca **pegando la salida del comando**. Nada de "creo que pasa".

- [ ] **Paso 1: Suite verde en local, dos veces seguidas**

```bash
cd e2e && npx playwright test && npx playwright test
```

Dos pasadas seguidas: la segunda detecta inestabilidad que la primera esconde. Si una pasa y la
otra no, **tienes un test inestable, no un test que pasa** — arréglalo o márcalo `.skip` y
anótalo. Un rojo intermitente en la demo es peor que un test menos.

- [ ] **Paso 2: Suite verde contra el canal desplegado**

```bash
E2E_BASE_URL="<URL del canal demo-rc>" npx playwright test --project=desktop
```

- [ ] **Paso 3: Suites del proyecto**

```bash
cd .. && /test all
```

Esperado: ≥689 tests de Flutter y ≥175 de reglas, verdes. Comparar con la línea base de la
Tarea 1 Paso 2. **Si el número bajó, algo se rompió** aunque todo esté verde.

- [ ] **Paso 4: Ensayo humano cronometrado, grabado**

Recorre el guion del runbook a mano, en el navegador, con el reloj. Graba la pantalla. Ese vídeo
es el Plan B nivel 3 y además revela lo que ningún test ve: cosas que se ven mal, transiciones
lentas, texto cortado.

- [ ] **Paso 5: Revisión de código del diff acumulado**

```bash
/code-review high
```

Sobre la rama entera. Aplica sólo lo que sea de corrección; **rechaza refactorizaciones** a estas
horas.

- [ ] **Paso 6: Tabla Go / No-Go**

| Criterio | Umbral | Resultado |
|---|---|---|
| `regresion-bloqueadores.spec.js` | 3/3 verde | |
| Los tres guiones de demo (desktop) | 3/3 verde | |
| Suite contra el canal desplegado | verde | |
| `flutter test` | ≥ línea base de la Tarea 1 | |
| `test_rules` | ≥175 verde | |
| Vuelta atrás **ensayada**, no sólo escrita | sí | |
| Rastro de producción limpio (Tarea 16) | 3/3 casillas | |
| `docs/RUNBOOK_DEMO.md` completo, sin marcadores `<...>` | sí | |
| Vídeo del ensayo grabado | sí | |

**Regla de No-Go:** cualquier fila de `regresion-bloqueadores` en rojo, o la vuelta atrás sin
ensayar. Todo lo demás es degradación aceptable: se saca del guion y se sigue.

- [ ] **Paso 7: Cerrar la rama**

```bash
git push
gh pr merge --squash
```

---

# Fase 5 — Post-demo (no tocar antes del 2026-09-03)

## Tarea 20: Lo que queda anotado y por qué se aplazó

- [ ] **Crear `autodoc-staging`** (`docs/RUNBOOK.md`, "Pendiente 1"). Requiere facturación.
  Después, poblar datos y configurar los 13 secretos por Environment. Mientras no exista,
  todo se prueba contra producción, que es la deuda de fondo de este plan.
- [ ] **Volver bloqueante `e2e_smoke`** tras 5 ejecuciones verdes (Tarea 12 Paso 6) y añadirlo a
  `needs:` de `deploy_production`.
- [ ] **Instalar `sentry`** e instrumentar `lib/main.dart`. Aplazado por tocar el arranque a 48 h
  de la demo.
- [ ] **Pentest con Strix** (`web-app-penetration-testing`, ya instalada) — contra staging,
  **nunca** contra producción.
- [ ] **Rotar las credenciales E2E** cargadas como secretos de GitHub en la Tarea 12
  (`docs/RUNBOOK.md` §2).
- [ ] **Decidir App Check** (§2.17): activar enforcement con los dominios bien configurados, o
  quitar la activación de `lib/main.dart:147` y dejar de generar ruido en consola.
- [ ] **`dependency-audit`**: cerrar los hallazgos aplazados en la Tarea 17.
- [ ] **`mergify` Test Insights** para la inestabilidad del arnés, ya con historial que analizar.
- [ ] **Hallazgos 🟠 y 🟡 del informe del 28-ago** que sigan abiertos: §7.3 (kilometraje
  incoherente), §7.4 (ejes de gráficas en el perfil del vehículo), §2.11 (imágenes de vehículo
  ya creados sin botón para rebuscar), §7.5 (reservas sin confirmar).

---

## Riesgos de este plan

| Riesgo | Probabilidad | Mitigación |
|---|---|---|
| `storageState({indexedDB:true})` no restaura la sesión de Firebase | Media | Tarea 6 Paso 4: repliegue a login por test, 30 min de tope |
| Los `getByLabel` no encuentran nada en alguna pantalla porque el árbol semántico no se pinta | Media | `enableSemantics` con dos estrategias; si falla en una pantalla concreta, es un hallazgo de accesibilidad real (§2.13), no un fallo del arnés |
| La suite E2E resulta inestable y come el Día 2 | **Alta** | Los specs de demo son el entregable; `regresion-bloqueadores` es la única puerta dura. Si la Fase 2 se atasca, entrega las Tareas 7 y 10 y salta 8, 9, 11 |
| El canal de preview no autentica por dominio | Media | Tareas 14 y 18 Paso 3 lo verifican **antes** del día de la demo |
| `hosting:clone` no acepta canal como origen en el CLI 15.28.2 | Media | Tarea 18 Paso 6 lo prueba de verdad y escribe la alternativa por consola |
| Un build sin `flutter clean` produce un bundle roto | Media | La guardia de `serve-build.js` (Tarea 4) lo detiene en 1 s en vez de en un timeout de 150 s |
| Que la QA ensucie producción durante la propia preparación | Media | Cuarentena de cuentas + ningún spec confirma escrituras + registro de rastro (Tarea 16) |

---

## Autorrevisión del plan

**Cobertura del spec** — hallazgos de `docs/qa/REPORTE_QA_PLAYWRIGHT_2026-08-28.md`:

| Hallazgo | Dónde queda cubierto |
|---|---|
| §2.1 403 de Storage al superadmin | Tarea 9, aserción `storage403` |
| §2.2 buscar placa crea ticket | Tarea 10, cuenta antes/después del kanban |
| §2.3 el año del alta de vehículo | Tarea 10, primer bloque |
| §2.4 burbuja en modo oscuro | **No cubierto por E2E** — es visual; queda en el ensayo humano (Tarea 19 Paso 4) |
| §2.5 alertas que sobreviven al cambio de cuenta | Cubierto de refilón por los `storageState` por rol; deuda anotada |
| §2.7 nombre del vehículo recortado | Tarea 7, paso 2 (`aria-label.length > 3`) |
| §2.12 arranque de 5 s | Tarea 11, presupuesto de arranque |
| §2.13 accesibilidad | Tarea 11, semántica y controles sin nombre |
| §2.14 la URL acompaña a la navegación | Cubierto: todos los `waitForURL`/`toHaveURL` del plan lo verifican de paso |
| §2.15 rol legado `Usuario` | Tarea 9, aserción final |
| §2.17 App Check | Tarea 14 |
| §5 rastro en producción | Tarea 16 |
| §7.2 cerrar servicio sin tareas | Tarea 10, tercer bloque |
| §7.3 alertas contradictorias | Tarea 7, paso 4 |
| §7.4 ejes de gráficas | **No cubierto** — visual; Tarea 20 |
| §7.5 reservas | **No cubierto** — escribiría en datos reales; Tarea 20 |

**Consistencia de nombres:** `waitForEngine` / `enableSemantics` / `gotoApp` /
`collectConsoleErrors` / `login` se definen en la Tarea 5 y se usan con esos mismos nombres en
las Tareas 6–11. `ACCOUNTS.propietario|taller|admin` idem. Los ficheros de sesión
`.auth/{propietario,taller,admin}.json` los produce la Tarea 6 y los consumen las 7–10. El
artefacto `web-bundle` lo produce y consume la Tarea 12.

**Huecos conocidos, dichos a propósito:**

- Los tres flujos que escriben datos reales (registro de usuario, cierre de servicio completo,
  aprobar una verificación) **no se automatizan**. Automatizarlos exige emuladores o staging, y
  ninguno de los dos existe. Se cubren en el ensayo humano de la Tarea 19 Paso 4.
- La Tarea 13 (informe markdown) describe el cambio en prosa en lugar de dar el código: es un
  ajuste de recorrido sobre un fichero existente de 40 líneas que hay que leer antes de tocar.
  Es la única excepción a la regla de "sin marcadores" de este plan, y está señalada.
