# AutoDoc — Guía para Claude Code

## ⚠️ Prioridad actual del equipo — S1: subida de PDF del taller

**Antes de tomar cualquier otra tarea, esta es la que va primero.** Está descrita en
`docs/superpowers/plans/2026-09-02-hallazgos-uso-real.md`, sección **«Anexo — Tareas de
seguimiento surgidas al ejecutar el Bloque A» → S1** (y los dos residuales de PDF de S6).

El taller **no puede subir su NIT en PDF**: la pantalla usa
`ImagePicker().pickImage(source: gallery)`, que no selecciona PDF, aunque `storage.rules` ya
admite PDF para el slot `nit`, el lado del administrador ya sabe mostrarlo, y `file_picker`
ya está en `pubspec.yaml` sin usar. El NIT es el documento más determinante para aprobar un
taller.

**Trampa que hay que tener presente:** toda la rama PDF del lado del taller es hoy
*inalcanzable en producción*. Su test pasa solo porque inyecta un `XFile` que el picker real
nunca puede devolver. **La suite reporta verde sobre un flujo que nadie puede ejercer.** Trata
esa rama como código de primera ejecución y ese test como NO verificado.

El resto del anexo (S2–S6) y los Bloques B–G del mismo plan son el trabajo pendiente que
sigue. Antes de empezar cualquiera de ellos, avisa en el equipo para no duplicar esfuerzo:
S1 ya está asignada.

## Flujo de trabajo obligatorio para cada petición

1. **Contexto del proyecto**: usa **graphify** (`/graphify`, o las skills `graphify` instaladas) como fuente principal de contexto del código — grafo de conocimiento ya construido en `graphify-out/graph.json` (3977 nodos, 5400 edges). Si el grafo no responde lo suficiente, complementa buscando directamente en el código (Grep/Glob/Read).
2. **Superpowers**: usa las skills de `superpowers` (brainstorming, TDD, debugging sistemático, subagent-driven development, code review) según corresponda al tipo de tarea.
3. **find-skills**: antes de improvisar una solución, usa `find-skills` para revisar si ya existe una skill relevante instalada o disponible en las marketplaces configuradas.

Ver también `CONVENTIONS.md` para arquitectura (Clean Architecture + Provider), reglas de Firestore/roles, y estilo de código.

## Skills/plugins instalados (scope: user)

- `claude-code-setup@claude-plugins-official` — recomendador de automatizaciones.
- `superpowers@claude-plugins-official` — brainstorming, TDD, debugging, code review, subagentes.
- `andrej-karpathy-skills@karpathy-skills` — guías de comportamiento (pensar antes de codear, simplicidad, cambios quirúrgicos, criterios de éxito claros).
- `find-skills@easier-life-skills` — descubrimiento de skills relevantes para el repo activo.
- `graphify` (CLI vía `uv tool install graphifyy` + skill en `~/.claude/skills/graphify/`) — grafo de conocimiento del código, `/graphify` para re-indexar.

## Automatizaciones locales del proyecto (`.claude/`)

- Hooks: bloqueo de edición de `.env`/credenciales, auto-`dart format` post-edición.
- Subagentes: `firestore-rules-reviewer`, `functions-perf-reviewer`.
- Slash command: `/test [unit|rules|integration|all]`.
- Skill: `firebase-deploy-check`.
