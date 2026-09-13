# Auditoría CREA J 2026 — segunda ronda, desde cero

**Fecha:** 2026-09-13. **Rama:** `hardening/h-01`, sobre `integracion/ola-1` (`c5be109`).
**Encargo:** el §7 del plan de remediación pide repetir la auditoría adversarial *desde cero*,
con un abogado del diablo nuevo y un juez independiente, **sin arrastrar la nota anterior**.

## 0. Cómo se hizo, y por qué así

Dos evaluadores, **ninguno informado de la puntuación previa** y ninguno de ellos yo:

| Papel | Quién | Encargo |
|---|---|---|
| Abogado del diablo | agente externo (modelo distinto), solo lectura | construir el caso más fuerte posible **contra** la nota máxima, un cargo por criterio, cada uno con `ruta:línea` o se descarta |
| Juez independiente | agente externo (otro modelo distinto), solo lectura | puntuar los seis criterios desde cero, tratando `docs/evidencia/` como **afirmación del equipo y no como prueba**, verificando al menos una por criterio |

Los dos arrancan en frío y no comparten contexto conmigo ni entre sí. Esa separación es lo que
hace que el ejercicio valga: **encontraron cosas distintas**. El agujero de Storage lo vio solo
el abogado; el juez no lo vio. Y de los cinco cargos del abogado, **uno era falso** — que es la
razón por la que ninguno se acepta sin reproducirlo.

**Advertencia sobre el alcance del juez, en sus propias palabras:** pudo correr las 276 pruebas
de Functions, pero **no** las de reglas ni las E2E (le faltaba el binario de Firebase) y Flutter
no completó en su entorno. Su nota se apoya en lectura de código más una suite. Los números de
suite de este informe salen de mis corridas, no de las suyas.

## 1. Veredicto

**Juez independiente: 85 / 100.** Sin P0 demostrados; tres P1.

| Criterio | Máximo | Nota | Lo que el juez pidió para subirla |
|---|---:|---:|---|
| Amigabilidad | 20 | 17 | guardas idempotentes y E2E móvil sobre pantallas Flutter reales |
| Roles | 10 | 9 | correr la matriz UI→callable→reglas contra emuladores en ese checkout |
| Seguridad | 20 | 16 | evidencia de `APP_CHECK_ENFORCEMENT=enforce` desplegado |
| Base de datos | 10 | 8 | prueba directa de duplicación de reservas |
| Funcionalidad | 20 | 18 | integración emulada de los siete triggers sin prueba |
| Creatividad | 20 | 17 | un guion multirol reproducible de extremo a extremo |

Dos de sus seis peticiones son **de entorno, no de producto**: correr las reglas y las E2E, que
aquí sí corren y están en el §3. Eso significa que la nota es un **suelo**, no un techo: un juez
con las suites ejecutables vería acreditado lo que él marcó como «implementado sin prueba».

## 2. Los cinco cargos, y qué pasó con cada uno

Ninguno se aceptó por venir de un auditor. Cada uno se reprodujo primero.

### 2.1 CONFIRMADO y cerrado — un taller suspendido conservaba las facturas

**Cargo:** `storage.rules` considera mecánico a una cuenta por su `rol`, sin mirar `estado`, al
revés que `firestore.rules`.

**Lo que encontré al reproducirlo.** La asimetría está documentada a propósito en el propio
archivo… pero la razón que da cubre el **expediente de verificación**, que se sube justo cuando
la cuenta todavía no está aprobada. No cubre `facturas/{vehicleId}`, que autoriza con
`isVinculadoAlVehiculo()` → el `isMecanico()` laxo.

Consecuencia real: un taller **ya vinculado** a un vehículo que después pierde la habilitación
sigue **leyendo y escribiendo las facturas** de ese coche, mientras Firestore le deniega la misma
operación. Reproducido en rojo con control positivo antes de tocar nada.

**Por qué no lo veía nadie:** `test_rules/storage.test.js:17` siembra **siempre**
`estado: 'activo'`. El caso no existía en la suite.

**Cerrado:** `isVinculadoAlVehiculo()` usa ahora `esTallerAprobado()`. El expediente de
verificación sigue con el laxo, que es donde hace falta. Cubierto por
`test_rules/storage_taller_suspendido.test.js` (2 negativos + 1 control positivo).

### 2.2 CONFIRMADO y cerrado — citar a un mecánico con el que no hablas

**Cargo:** crear una reserva solo exigía «asígnate a ti mismo en tu propio campo». Sin relación
previa, cualquier cuenta autenticada creaba una cita con `id_mecanico` = víctima, y
`onReservaCreada` confía en ese campo para **notificarle**.

**Estado previo:** el comentario de la propia regla lo reconocía como riesgo residual conocido.
O sea: estaba anotado, no cerrado — la regla que este proyecto lleva cuatro tandas aprendiendo.

**Primer intento, y por qué no bastaba.** Até la cita a su conversación, dando por hecho que esa
relación era de fiar porque crear una conversación se endureció en el hallazgo C2. **El gate de
revisión de reglas lo tumbó:** ese endurecimiento cubrió la rama del *mecánico*; la del
*propietario* no comprobaba nada sobre `id_mecanico`. O sea que el atacante se fabricaba la
relación él mismo y mi arreglo solo le costaba **una escritura más**.

**Cerrado de verdad:** un propietario solo puede abrir chat con un **taller aprobado**
(`esMecanicoAprobado(uid)`, un helper que mira a la contraparte y no al llamante), y la cita
sigue exigiendo su conversación. Cubierto por `test_rules/reservas_relacion_previa.test.js`:
cuatro ataques —incluido el completo en dos pasos— y **tres** controles positivos, porque el
flujo real permite proponer a cualquiera de los dos participantes y abrir chat desde el
directorio, y un acotado pasado de frenada rompería la mitad del recorrido.

**Efecto colateral que vale la pena:** puso rojo el ciclo de vida de reservas de
`ciclo_vida_crud.test.js`, cuya siembra creaba una cita **sin conversación** — una forma que la
app no genera nunca. Se corrigió la siembra, no la regla.

### 2.3 CONFIRMADO y cerrado — recargar la página en una tarea revienta la app

**Cargo:** `/task_config` y `/task_complete` leen `state.extra` con un cast incondicional.

**Lo que encontré:** es peor que entrar por URL. `extra` **no sobrevive a un refresh**, así que
basta con estar en la pantalla y pulsar F5:

```
_TypeError: type 'Null' is not a subtype of type 'MaintenanceTask' in type cast
_TypeError: type 'Null' is not a subtype of type 'Map<String, dynamic>' in type cast
```

Pantalla rota sin salida — el mismo callejón que UX-02 cerró para el error de arranque y el 404,
en dos rutas que se le escaparon.

**Cerrado:** un `redirect` por ruta devuelve a `/alerts`, que es la pantalla que empuja ambas, y
en `/task_complete` mira **dentro** del mapa: llega con `extra` puesto pero sin sus claves y el
cast reventaría igual, una línea más abajo. Cubierto por
`test/core/router/task_routes_sin_extra_test.dart`.

### 2.4 REFUTADO — el doble clic en «Enviar» del chat

**Cargo:** dos clics rápidos crean dos mensajes idénticos.

**No es cierto.** `_enviarMensaje` vacía el campo de texto de forma **síncrona** justo después de
lanzar el envío (`chat_screen.dart:245`), y la función sale antes de nada si el texto está vacío
(`:235`). El segundo clic no encuentra nada que enviar.

**Pero comprobarlo destapó otro defecto, distinto del acusado:** el envío es *fire-and-forget* y
el texto ya se borró. **Si falla, la persona pierde lo que escribió y no ve ningún error.**
Anotado en el §4; no se arregla a ciegas.

### 2.5 ANOTADO — lecturas sin cota en el panel del mecánico

**Cargo:** el dashboard descarga todo el historial de servicios sin `limit` ni filtro temporal, y
abre una segunda consulta completa para el gráfico.

Es real y pertenece a una familia ya inventariada (los barridos N+1 y los cuatro streams sin tope
del panel del mecánico, §7 de `GAPS-04-drenaje.md`). El juez levantó lo mismo en el cron de
alertas. **Es la deuda de capacidad de más peso que le queda al producto** y merece su propia
tanda, no un parche suelto.

## 3. Cifras reales de suite

Lo que el juez no pudo ejecutar, ejecutado:

| Gate | Resultado |
|---|---|
| `flutter analyze` | ver §5 de `docs/evidencia/H-01-hardening.md` |
| `flutter test` | ver §5 |
| Cloud Functions | **276 passing** |
| Reglas (emuladores) | **465 / 465**, 28 suites, exit 0 |
| E2E de la landing | **42 / 42** |
| E2E de la app (en serie) | **37 / 37**, cero `fixme` |

## 4. Defectos abiertos hoy

**P0: ninguno.** Los tres confirmados por esta ronda están cerrados con prueba.

**P1, con su razón de seguir abiertos:**

| # | Defecto | Por qué sigue abierto |
|---|---|---|
| 1 | **App Check queda en `monitor` por defecto**, así que los doce callables aceptan llamadas sin token mientras no se despliegue `APP_CHECK_ENFORCEMENT=enforce` | Es **deliberado y documentado**: con `enforce` la suite E2E entera deja de pasar, porque el emulador de Functions no emite tokens. Es un paso de runbook, no un olvido. Lo que no existe todavía es evidencia de que ese paso se haya dado en un proyecto real — y no puede existir aquí: el plan prohíbe desplegar |
| 2 | **Seis formularios sin defensa contra doble envío** (recuperar contraseña, Google Auth, editar kilometraje, crear y reprogramar reserva, responder reseña) | De los siete que señaló el inventario, el único con consecuencia demostrada era el de reserva, y su parte visible se cerró. Los otros no se han reproducido uno a uno, y este repo lleva cuatro tandas demostrando que la anotación no es un diagnóstico |
| 3 | **Lecturas sin cota** en el panel del mecánico y en el barrido diario de alertas | Deuda de capacidad, no de corrección. Tanda propia |
| 4 | **Un envío de chat que falla pierde el texto sin avisar** (§2.4) | Descubierto al refutar un cargo; no se arregla a ciegas |

## 5. Lo que este ejercicio dice del método, más allá de la nota

**Dos auditores independientes encontraron conjuntos distintos.** El agujero de Storage lo vio
solo el abogado del diablo; el juez, que puntuó Seguridad con 16/20, no lo detectó. Un solo
evaluador habría dejado ese defecto vivo con buena nota encima.

**Uno de cada cinco cargos era falso.** Y el falso venía con cita de `ruta:línea`, igual que los
verdaderos. La cita hace el cargo *comprobable*, no *cierto*.

**Refutar un cargo dio un defecto que nadie había pedido.** El chat no duplica mensajes, pero
pierde el texto si el envío falla. Verificar en serio paga aunque el cargo caiga.

**Y el gate de revisión tumbó uno de mis propios arreglos.** El de reservas parecía cerrado y
solo encarecía el ataque en una escritura, porque me apoyé en una relación que el atacante podía
fabricarse. Es la cuarta tanda seguida en que los revisores encuentran lo que las suites propias
no ven — y esta vez lo que no veían era mi parche, no el defecto original.

**Y la regla de siempre, ahora por quinta vez:** los tres defectos confirmados estaban **anotados
o documentados** en el propio repositorio —la asimetría de Storage en un comentario, el riesgo de
reservas en la propia regla— y ninguno estaba cerrado. Anotar no cierra.
