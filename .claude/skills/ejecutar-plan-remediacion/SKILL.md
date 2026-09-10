---
name: ejecutar-plan-remediacion
description: Orquesta la ejecucion del plan maestro de remediacion CREA J 2026 (docs/superpowers/plans/2026-09-06-remediation-master-plan-crea-j-10-10.md) y de cualquier plan largo de AutoDoc con tareas ID'd, gates de evidencia y Definition of Done. Usar al empezar o retomar una tarea del plan (VER-01, SEC-0x, ROLE-01, DATA-01, QA-0x, UX-0x, FUNC-0x, OPS-01, H-01, FINAL-01), cuando el usuario diga "sigamos con el plan" / "que toca ahora", o al planificar como repartir trabajo largo entre agentes. NO usar para cambios sueltos fuera del plan.
---

# Ejecutar el plan de remediacion

Plan: `docs/superpowers/plans/2026-09-06-remediation-master-plan-crea-j-10-10.md`.
Baseline 64/100, objetivo 10/10 rubrica CREA J 2026. El plan manda: sus §12 (orden), su
Definition of Done y sus gates estan por encima de esta skill. Aqui solo esta **como
orquestarlo**.

## Estado (actualizar al cerrar cada tarea)

Hechos: **SEC-01, SEC-02, SEC-03, DATA-01, VER-01, ROLE-01, QA-02, QA-01, UX-01, UX-02,
FUNC-01, FUNC-02** (a 2026-09-10). Siguiente por orden §12: **UX-03/04**, luego SEC-04,
OPS-01, H-01, INNO-01, FINAL-01.

**Pero antes de UX-03/04 va la tanda de drenaje de gaps**, planificada en
`docs/evidencia/GAPS-02-plan-de-drenaje.md` (rama `fix/gaps-02`, tres lotes). Drenar los gaps
que deja una tarea no es opcional ni es «cuando haya hueco»: es parte de cerrarla.

Nada esta fusionado a `main` (`1265d23`). **Las 12 viven en `integracion/ola-1`.** FUNC-02
entro el 2026-09-10 (`58f5dd9`, sin conflictos), y encima va `fix/landing-crash`, que no es
del plan pero si trabajo real sobre la landing.

**`fix/gaps-func02` ya esta fusionada** (`67046ce`, sin conflictos): no era una tarea del plan
sino el drenaje de los nueve residuales que FUNC-02 habia dejado anotados. Evidencia en
`docs/evidencia/GAPS-FUNC-02-cierre-de-residuales.md`, con nueve gaps NUEVOS en su §9 — que
son los que drena la tanda `fix/gaps-02`. Ya no queda ninguna rama `fix/*` sin fusionar.

**Leccion del drenaje de residuales, y es la que mas vale de esta ronda:** documentar un gap
no lo cierra. Al abrirlos, DOS de los nueve estaban descritos al reves —un «indice muerto»
que era el indice vivo mal escrito, y un «mensaje equivocado» que en realidad hacia guardar
importes distintos de los que el cliente aprobo— y cerrarlos destapo seis defectos mas de la
misma familia. La anotacion sirve para no perderlos; leerla como si fuera un diagnostico
firme es lo que los mantiene vivos. **Al cerrar una tarea, abre rama para sus residuales
antes de pasar a la siguiente del plan.**

**Los emuladores NO detectan una consulta sin indice compuesto:** sirven cualquier consulta
sin mirar `firestore.indexes.json`, asi que ese fallo solo aparece en produccion. Lo vigila
`test/firestore_indices_test.dart`; si añades una consulta con `orderBy` o con dos `where`,
ese centinela te va a parar, y con razon.

**Leccion de FUNC-02, aplicable a cualquier retirada de codigo muerto:** antes de dar por
muerto un metodo, mira QUIEN lo sostiene. Los seis retirados no tenian consumidor en `lib/`;
los sostenian sus propios tests. Y el gemelo server-side (`iniciarReparacionPorVehiculo`)
seguia **desplegado e invocable** pese a no tener llamador: retirar el export no retira el
endpoint, hace falta `firebase functions:delete`.

Cifras al dia con `fix/gaps-func02`: `flutter analyze` limpio, `flutter test`
**1180 / 1180**, Functions **197**, reglas **426/426** en 24 suites, E2E de la app
**32 pasan y 2 `fixme`**, E2E de la landing **20/20** (no se relanzo: la landing no se toca),
puertos libres al salir.

Corta siempre de `integracion/ola-1`, no de las `fix/*`. Detalle de ramas y de las trampas
de test encontradas: `CLAUDE.md` y `AGENTS.md`.

**Un worktree nuevo no trae dependencias y el error no lo dice** (el build de la landing
muere con `Cannot find module 'next-intl/plugin'`, que solo significa que falta
`pnpm install`). Siembra: `flutter pub get`, `functions/npm ci`, `test_rules/npm ci`,
`e2e/npm ci`, `landing-web/pnpm install`.

`AGENTS.md` en la raiz repite este estado para los workers de Codex. **Si cierras una tarea,
actualiza los dos.**

## Las tres reglas que no se negocian

1. **Orden §12 y gates de evidencia.** No empezar una tarea dependiente sin el gate de la
   anterior cerrado. El grafo de dependencias esta en §4: `VER-01 + SEC-01..03 + ROLE-01 -> QA-01
   -> H-01 -> FINAL-01`.
2. **TDD real, no decorativo.** La DoD exige "prueba nueva falla antes y pasa despues". Corre la
   prueba y **veala fallar** antes de implementar. Este repo ya tiene la cicatriz: el test del PDF
   del taller pasa inyectando un `XFile` que el picker real nunca devuelve — verde sobre un flujo
   que nadie puede ejercer. Usa `superpowers:test-driven-development`.
3. **Nada contra produccion.** Emuladores y fixtures efimeros. Sin cuentas reales, sin
   `firebase deploy`.

## Quien hace que: subagentes de Claude vs workers de Codex

Hay **dos** pools de agentes y no son intercambiables. Lo que decide no es la dificultad de la
subtarea, sino de que presupuesto sale y cuanto contexto del proyecto necesita.

| | Subagente de Claude (`Agent`) | Worker de Codex (`codex exec`) |
|---|---|---|
| Presupuesto | Tu misma cuenta y contexto | **Cuota aparte** (suscripcion ChatGPT) |
| Contexto | Hereda lo que le escribas; mismas herramientas, hooks y permisos del repo | Frio salvo `AGENTS.md`; sin hooks del proyecto |
| Escribe/corre tests | Si, con las salvaguardas del repo | Solo `-p builder`, y en worktree aparte |
| Confianza en su salida | Alta, pero sigue siendo un reporte | Reporte de otro modelo: **verificar siempre** |

La razon de usar Codex no es que sea mejor, es que **gasta de otra bolsa**. Cuando el cuello de
botella es tu propio contexto o tu cuota, el fan-out a Codex es ancho de banda gratis; cuando lo
que hace falta es criterio sobre las convenciones del repo, va un subagente de Claude.

**Reparto por defecto:**

- **Reconocimiento masivo y barato** (inventariar consumidores, mapear que tests existen, resumir
  reglas) -> **Codex `-p worker`** en fan-out. Es volumen de lectura, no criterio.
- **Busqueda amplia dentro de la conversacion en curso** -> subagente **`Explore`**, que devuelve
  la conclusion sin volcarte los archivos.
- **Revision de `firestore.rules`** -> subagente **`firestore-rules-reviewer`** (ownership, bypass
  de roles, IDOR). Obligatorio en ROLE-01, SEC-03 y QA-01, y en cualquier tarea que toque las
  reglas.
- **Revision de `functions/index.js` o `firestore.indexes.json`** -> subagente
  **`functions-perf-reviewer`** (N+1, batching, queries sin indice). Aplica a SEC-01, SEC-03,
  DATA-01 y OPS-01.
- **Disenar el ataque de una tarea grande antes de tocar codigo** -> subagente **`Plan`**, o
  `superpowers:brainstorming` si aun no esta claro el que.
- **Implementar con TDD** -> **tu**, en el hilo principal. No se delega (ver "Cuando NO delegar").

Los dos revisores del proyecto son de solo lectura (`Read, Grep, Glob, Bash`) y estan pensados
para correr **despues** de implementar y **antes** de dar la tarea por cerrada: son parte del gate
de evidencia, no una opinion opcional.

## Como repartir el trabajo

El §12 es sequencial, asi que **el paralelismo no sale de saltarse el orden**. Sale de dos sitios:

**a) Dentro de una tarea: separar investigar de implementar.**
La parte cara de cada tarea del plan es el reconocimiento — que archivos toca, quien consume que,
que tests existen. Eso es lectura pura y N preguntas independientes: es exactamente el caso de
`delegate-to-codex`. La implementacion y el TDD se quedan contigo.

Patron por tarea del plan:

1. Lee la ficha de la tarea en §7 (areas, checklist, aceptacion, evidencia).
2. **Fan-out de reconocimiento** con `codex exec -p worker` en background, una llamada por
   pregunta independiente. Ejemplo para VER-01:
   - "Inventaria los consumidores de `ImagePicker` en `lib/features/**` con ruta:linea y di cual
     corresponde al slot `nit`. Tabla, max 15 lineas."
   - "Resume que exige `storage.rules` para el slot `nit`: MIME, tamano, path, quien escribe.
     Max 15 lineas."
   - "Lista los tests que tocan `workshop_verification_screen` y di cual inyecta un XFile
     directamente. Ruta:linea. Max 10 lineas."
3. **Verifica lo que devuelvan** abriendo los archivos que citen. Son reportes, no hechos.
4. Implementa tu con TDD, en pasos pequenos.
5. **Revision especializada** antes de cerrar: si tocaste `firestore.rules` lanza
   `firestore-rules-reviewer`; si tocaste `functions/index.js` o `firestore.indexes.json` lanza
   `functions-perf-reviewer`. Si tocaste ambos, los dos en paralelo en el mismo bloque de tool
   calls.
6. Cierra la DoD: pruebas nuevas y existentes, emulador/Playwright si cruza UI/autorizacion/
   persistencia, Evidence ID registrado, regresion del workstream, y reevaluar el criterio CREA.

**b) Entre workstreams independientes.** §5 define A..G. Las ramas del grafo §4 que no se cruzan
(p.ej. el bloque UX-01..04 frente al bloque de datos) pueden ir en paralelo **si** el usuario
quiere abrir varios frentes. Ahi si conviene `-p builder` con **un git worktree por frente**
(`.claude/worktrees/` ya existe). Nunca dos escritores en el mismo arbol.

## Cuando NO delegar

- La implementacion de SEC-*, ROLE-01 y DATA-01: son la barrera de autorizacion y la atomicidad
  de datos. Un worker en frio no debe escribir eso.
- Cualquier cosa cuyo criterio de aceptacion dependa de lo hablado en esta conversacion.
- Repetir la auditoria: §Restricciones lo prohibe explicitamente. La evidencia base ya esta en
  `docs/AUDITORIA_CREA_J_2026_CODEX.md`.

## Contexto que el plan da por sabido

- Rubrica y gaps por criterio: §2 y §3.1.
- Riesgos de regresion por tipo de cambio: §9. Consultalo **antes** de tocar auth, reglas,
  cotizacion/ticket, Storage del NIT o router/hosting.
- Playwright minimo obligatorio: §8.
- INNO-01 solo se decide despues de H-01, y solo si el mock judge no concede 20/20 en
  creatividad. No adelantarlo.
