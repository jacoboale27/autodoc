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

## 4. Harness E2E: de producción a emuladores

El estado de partida era peor de lo que sugiere el plan. `e2e/playwright.config.js` arrancaba
`flutter run -d web-server --dart-define-from-file=.env`: la suite completa corría **contra el
Firebase de producción**, iniciaba sesión con dos cuentas fijas (`taller1@taller.com`,
`nadie@gmail.com`) y `registro.spec.js` **creaba usuarios reales en cada corrida**. Y no había
forma de redirigirla: no existía una sola llamada a `useAuthEmulator` en `lib/`.

| Evidence ID | Cambio | Artefacto |
|---|---|---|
| `EVID-QA-020` | cableado a emuladores con doble candado: el `--dart-define` **y** `!kReleaseMode` | `lib/core/config/firebase_emulators.dart`, `lib/main.dart` |
| `EVID-QA-021` | credenciales falsas versionadas: el E2E ya no puede alcanzar producción ni con el cableado roto | `e2e/emulator-config.json` |
| `EVID-QA-022` | fixtures por rol sembrados con Admin SDK: propietario A/B, taller aprobado/pendiente, admin, superusuario, cuenta desechable | `e2e/scripts/seed-emulators.js` |
| `EVID-QA-023` | arranque reproducible: emuladores + bundle compilado servido con fallback SPA | `e2e/playwright.config.js`, `scripts/build-web.js`, `scripts/serve-web.js` |
| `EVID-QA-024` | matriz multirol E2E contra el bundle real | `e2e/tests/roles.spec.js`, 13 casos |
| `EVID-QA-025` | prueba del propio harness (proyecto, verificación de correo, seis roles) | `e2e/tests/harness.spec.js`, 3 casos |

**Resultado: 27 pasan, 2 marcadas `fixme`, exit 0** (`cd e2e && npm run build:web && npm test`).

### El candado que funcionó a la primera, en contra

`flutter build web` compila en **release** por defecto, así que `!kReleaseMode` desactivó el
cableado y Auth salió al endpoint real con las claves falsas: `auth/api-key-not-valid`. Es
exactamente el comportamiento que se buscaba —un build de producción no puede quedar apuntando a
un emulador— demostrado en la práctica. El bundle E2E se compila con `--profile`, que es código
compilado igual que release pero con `kReleaseMode` en false.

### Tres trampas que costaron corridas

1. **El SDK importado de gstatic no sirve.** Un `import()` dentro de `page.evaluate` crea su propio
   registro de apps: `getApps()` sale vacío y todo muere con "No Firebase App '[DEFAULT]'". Peor,
   esa copia no heredaría el `useAuthEmulator`, así que hablaría con producción desde dentro de una
   suite que se cree aislada. Lo correcto son los globales `window.firebase_core` / `firebase_auth`
   / `firebase_firestore`, que **son** la instancia de la app.
2. **Esperar a que exista la app no basta.** `getApps()` deja de estar vacío en cuanto corre
   `initializeApp`, que es *antes* del redirect a emuladores. Un `signIn` en esa ventana sale a
   producción. Se espera a `auth.emulatorConfig`, que sólo deja de ser null cuando el redirect ya
   se aplicó. Cuatro rojos intermitentes salieron de aquí.
3. **`getByLabel` no puede funcionar en esta app.** No emite ni un `aria-label`: Flutter web expone
   la semántica como `<flt-semantics role="button">` cuyo rótulo es su texto. Todos los selectores
   de las specs heredadas estaban condenados a expirar, apuntaran a donde apuntaran. Se migraron a
   `getByRole`.

### Hallazgo de accesibilidad, para UX-03

La tarjeta del garaje y la ficha del directorio **se renderizan pero su texto no llega al árbol de
semántica**: CanvasKit lo pinta en el canvas. La placa `E2E-AAA` es legible en el dashboard y no en
el garaje. Para un lector de pantalla, esa lista de vehículos está vacía.

### Lo que queda abierto

- `e2e/tests/registro.spec.js` (2 casos, `fixme`): la pantalla de auth se rehízo en SEC-01/SEC-02 y
  sus rótulos ya no existen; además el llenado de formularios de Flutter web es inestable. Ya no
  toca producción, que era lo urgente. Rehacer el recorrido es trabajo de UX-01/UX-03.
- `reuseExistingServer: true` significa que quien arranque los emuladores a mano debe pararlos: una
  corrida de Playwright que los reutiliza no los cierra al salir.
- Cobertura E2E de Storage y de callables: no incluida.

## 5. Estado de la Definition of Done

| Punto de la DoD | Estado |
|---|---|
| implementación mínima y localizada | cumplido |
| prueba nueva falla antes y pasa después | cumplido en los cinco defectos de autorización; los de cobertura pura se declaran como tales |
| pruebas existentes relevantes pasan | reglas 395/395, Flutter 1140/1140, `analyze` limpio |
| Playwright/emulador donde cruza UI, autorización o persistencia | cumplido: 27 casos contra el bundle real y los emuladores |
| responsive y localización | **no cubierto** — no hay UI nueva en esta tarea; los cuatro viewports son de UX-03 |
| Evidence ID, resultado y artefacto registrados | este documento |
| regresión del workstream ejecutada | cumplida |
| reevaluación del criterio CREA afectado | Roles y BD ganan evidencia ejecutable por rol y por entidad; Seguridad gana cinco huecos cerrados |

Queda fuera el registro por UI (`fixme`, §4) y la cobertura E2E de Storage y callables.
