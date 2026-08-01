# AutoDoc — Guía para Claude Code

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
