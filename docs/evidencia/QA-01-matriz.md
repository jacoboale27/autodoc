# QA-01 — Matriz de evidencia

**Rama:** `fix/qa01`, cortada de `integracion/ola-1` (`29ece06`).
**Fecha:** 2026-09-08. **Estado:** parcial — ver §4.

Toda la evidencia sale de los emuladores (`test_rules/` vía `npm test`, que envuelve la suite en
`firebase emulators:exec`). Ninguna corrida toca producción ni cuentas reales.

## 1. Resultados de suite

| Suite | Antes (`integracion/ola-1`) | Después | Comando |
|---|---|---|---|
| Reglas (Jest + emuladores) | 356 / 356, 20 suites | **395 / 395, 23 suites**, exit 0 | `cd test_rules && npm test` |
| Flutter | 1140 / 1140 | **1140 / 1140** | `flutter test` |
| `flutter analyze` | limpio | **limpio** | `flutter analyze` |
| Puertos 8080/9199/4400/4500 al salir | 0 en LISTENING | **0 en LISTENING** | `netstat -ano` |

## 2. Defectos encontrados al construir la matriz

Los cinco primeros son la misma enfermedad: **una regla que autoriza mirando el documento viejo
(`resource.data`) y después no mira lo que el write deja escrito.** El actor pasa el control con
un estado y escribe otro.

| ID | Colección | Defecto | Impacto | Cierre |
|---|---|---|---|---|
| `EVID-QA-001` | `/alertas` | `update` no acotaba campos | el dueño de v1 movía su alerta al vehículo de otra persona | `id_vehiculo` inmutable |
| `EVID-QA-002` | `/mantenimientos` | idem | idem, con el mantenimiento | `id_vehiculo` inmutable |
| `EVID-QA-003` | `/historial_mantenimientos` | idem | el taller reasignaba su entrada a otro vehículo, o la atribuía a otro taller | `id_vehiculo` + `id_taller` inmutables |
| `EVID-QA-004` | `/vehiculos` | `update` del propietario no acotaba campos | el dueño **regalaba** el coche reescribiendo `id_propietario`: aparecía en el panel de la víctima con su historial colgando, y ya no podía deshacerlo | `id_propietario` inmutable |
| `EVID-QA-005` | `/vehiculos` | `talleres_conocidos` documentado como append-only, sin enforcement | vaciarlo con `talleres_vinculados` devolvía el coche al estado walk-in, abriéndolo a **cualquier** mecánico — el agujero de la ronda 6 reabierto desde el lado del propietario | `talleres_conocidos` inmutable |
| `EVID-QA-006` | `/cotizaciones` | `read` desreferenciaba `resource.data` sobre documento inexistente | releer una cotización recién borrada daba `PERMISSION_DENIED` en vez de "no existe" | rama `resource == null`, como ya hacía `/vehiculos` |
| `EVID-QA-007` | `/mensajes` | `resource.data.tipo` sin guarda | un mensaje anterior al campo `tipo` quedaba ineditable para siempre | `.get('tipo','texto')`, el default que ya aplica `MensajeModel.fromMap` |

`EVID-QA-001..005` son de autorización. `006` y `007` son de modo de fallo: la regla denegaba,
pero por error de evaluación, que llega al cliente como un problema de permisos donde solo hay un
documento ausente o un campo heredado.

## 3. Cobertura añadida

| Evidence ID | Qué demuestra | Artefacto |
|---|---|---|
| `EVID-QA-010` | ciclo `create → releer → update → releer → delete → releer` de vehículos, chat (conversación + mensajes), cotización, reserva, reparación, reseña y taller | `test_rules/ciclo_vida_crud.test.js`, 18 casos |
| `EVID-QA-011` | denegación cross-tenant por entidad en ese mismo ciclo (segundo propietario, segundo taller, tercero no participante) | idem |
| `EVID-QA-012` | donde ninguna regla concede `delete` (conversaciones, reservas), la prohibición se afirma en vez de omitirse | idem |
| `EVID-QA-013` | frontera Administrador ↔ Superusuario: hard delete de cuentas y reparto de los roles privilegiados | `test_rules/matriz_roles_superusuario.test.js`, 9 casos |
| `EVID-QA-014` | los siete defectos de arriba, cada uno con su negativo y su control positivo | `test_rules/reasignacion_campos.test.js`, 12 casos |

### Por qué estos verdes sí prueban autorización

El repo ya tiene dos cicatrices de tests que ejercitaban una puerta distinta de la que decían
probar (VER-01 y ROLE-01). El criterio aplicado aquí:

- **Cada negativo va emparejado con un positivo sobre la misma operación.** El `delete` de cuentas
  que el Superusuario consigue es el mismo que el Administrador tiene denegado; si el predicado
  que decidiera fuese otro, ambos caerían del mismo lado.
- **Los cuatro negativos de reasignación deniegan por la línea correcta**, verificado en el log del
  emulador (`L702`, `L1290`, `L1312`) — no por una puerta lateral.
- **Los payloads son los que el cliente produce de verdad.** El primer intento de test de mensajes
  omitía `tipo`, una forma de documento que `MensajeModel.toMap()` nunca genera; se corrigió antes
  de darlo por bueno, y el caso heredado se cubrió aparte.

## 4. Lo que QA-01 todavía NO cubre

El último punto del checklist de §7 — *«Hacer que Playwright arranque sólo emuladores requeridos y
use state aislado por proyecto»* — sigue **abierto**, y el estado de partida es peor de lo que
sugiere el plan:

- `e2e/playwright.config.js:17` arranca `flutter run -d web-server --dart-define-from-file=.env`.
  No levanta ningún emulador: la suite E2E corre **contra el Firebase de producción**.
- `e2e/tests/mecanico.spec.js:15` y `propietario.spec.js:16` inician sesión con cuentas fijas
  (`taller1@taller.com`, `nadie@gmail.com`).
- `e2e/tests/registro.spec.js:12` **crea usuarios nuevos en producción** en cada corrida.
- No hay cobertura E2E de administrador ni de superusuario.

Redirigirlo a emuladores no es configuración: **la app no tiene hoy ninguna vía para apuntar a
emuladores** — no hay una sola llamada a `useAuthEmulator` / `useFirestoreEmulator` /
`useStorageEmulator` en `lib/`. Hace falta añadir ese cableado a `lib/main.dart` detrás de un flag
de compilación que no pueda activarse en un build de release, y solo entonces reescribir la config
y las specs sobre fixtures sembrados por rol.

Hasta que eso se cierre, QA-01 no cumple su Definition of Done.
