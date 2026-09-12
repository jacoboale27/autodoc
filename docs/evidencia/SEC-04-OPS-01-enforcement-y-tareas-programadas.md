# SEC-04 / OPS-01 — Enforcement de App Check y tareas programadas

Rama `fix/sec04-ops01`, cortada de `integracion/ola-1` (`dd4958e`).
Evidencia `EVID-OPS-001..012`.

Dos tareas que comparten superficie —`functions/`— y por eso van juntas, en
commits separados. SEC-04 es el §7 «SEC-04 / OPS-01 / QA-02» del plan
maestro; QA-02 ya estaba cerrada desde la ola 2.

---

## Lo que hay que saber sin leer el resto

1. **App Check estaba a medias, y la mitad que faltaba era la que protege.**
   El cliente firma desde hace meses (`lib/main.dart:183`: reCAPTCHA
   Enterprise en web, Play Integrity en Android, DeviceCheck en iOS) y
   **ningún servidor comprobaba la firma**. Cero ocurrencias de `context.app`
   en todo `functions/`. Un cliente que firma y un servidor que no verifica no
   es media protección: es ninguna, porque el atacante simplemente no firma.

2. **Y la trampa es que la consola miente sobre la cobertura.** Este repo usa
   Cloud Functions **v1**, donde el enforcement de App Check **no tiene
   interruptor**. Para Firestore y Storage basta activarlo en la consola de
   Firebase; para las Functions v1 hay que mirar `context.app` en el código,
   función por función. Alguien que activara App Check en la consola vería el
   producto «protegido» mientras los doce callables seguían aceptando
   cualquier llamada. El runbook ya lo había detectado y lo dejaba como deuda
   con dueño ausente.

3. **El barrido de alertas mandaba el mismo push todos los días, para
   siempre.** Es el defecto más visible para un usuario real de todos los que
   quedaban abiertos. Nada marcaba la alerta como avisada, y `estado` solo
   sale de `Pendiente` cuando el propietario la cierra a mano desde la app
   (`alert_provider.dart:304`). Un SOAT vencido que su dueño no cierre —el
   caso normal, porque la gente renueva el SOAT y se olvida de la app— le
   manda una notificación diaria indefinidamente. Es exactamente la clase de
   notificación que hace que se desactiven todas las notificaciones de la app.

4. **El recordatorio de citas leía la colección entera cada día**, y encima
   avisaba del día equivocado. Sin cota de fecha en la consulta: filtraba
   `estado == 'confirmada'` y paginaba todo, descartando en memoria. Una
   reserva confirmada de hace dos años se seguía leyendo a diario. Y «mañana»
   se calculaba en UTC: Colombia es UTC-5, así que una cita a las 20:00 de
   Bogotá cae al día siguiente en UTC y su recordatorio salía descolocado —
   justo las citas de tarde, que son la mayoría.

5. **El respaldo no fallaba cuando le faltaba configuración: exportaba a una
   ruta basura.** `client.databasePath(undefined, '(default)')` construye
   `projects/undefined/databases/(default)` sin protestar y el bucket salía
   como `gs://undefined-backups`. El error que llegaba después hablaba de un
   recurso inexistente, no de la variable que faltaba. Un respaldo puede
   llevar meses sin hacerse así sin que nadie lo note — y es la única copia de
   seguridad que tiene el proyecto.

6. **Dos de las cuatro tareas programadas se tragaban sus errores** con un
   `console.error` y devolvían normalmente. Cloud Scheduler las veía correctas
   y no reintentaba: un barrido roto era indistinguible de un día sin trabajo
   que hacer.

---

## SEC-04 — el enforcement (`6f5c172`)

### Qué se implementó

`functions/src/appCheck.js`, y una llamada `exigirAppCheck(context, '<nombre>')`
como primera línea de los **12** `functions.https.onCall` de `index.js`.

Firebase ya valida el token antes de que llegue el `context`: si `context.app`
está presente, el token era auténtico. Lo que faltaba —y es lo único que hace
este módulo— es **decidir qué hacer cuando no está**.

### Por qué el modo por defecto es `monitor` y no `enforce`

Una llamada sin token no es solo un atacante. Es también un build web al que
le faltó `RECAPTCHA_SITE_KEY`, un móvil con Play Integrity caído, o una
versión vieja en caché. Encender el rechazo de golpe expulsa a usuarios
legítimos, y el síntoma —llamadas que fallan sin patrón— es de los más
difíciles de atribuir.

El runbook ya exigía dos fases (monitorización, y enforcement solo si el
porcentaje de tokens válidos supera el 98 %), así que el código tiene que
poder estar en la primera. `APP_CHECK_ENFORCEMENT=enforce` es un paso de
runbook, no un valor por defecto.

Un valor **no reconocido** cae a `monitor`. Es la decisión con más
consecuencia del módulo: caer a `off` sería inseguro en silencio, y caer a
`enforce` por una errata de configuración dejaría fuera a la aplicación
entera.

Hay un efecto secundario que conviene tener presente: con `enforce` por
defecto, **la suite de E2E dejaría de pasar entera**, porque el emulador de
Functions no emite tokens de App Check. Que el rechazo sea observable desde el
emulador es lo que lo hace verificable; que esté apagado por defecto es lo que
mantiene la suite útil.

### El mensaje de rechazo es opaco a propósito

`failed-precondition` con «No se pudo verificar la aplicación». No nombra App
Check, ni el proveedor, ni la variable de configuración. Un mensaje que
explique qué falta le está diciendo al atacante exactamente contra qué está
chocando. El detalle útil queda en el log del servidor, con el callable y el
uid.

### El centinela, y por qué cuenta bloques y no ocurrencias

En v1 la protección es una línea de código dentro de cada `onCall`. Eso
significa que **un callable nuevo nace sin protección y nadie se entera** —
que es exactamente cómo se llegó al estado que SEC-04 arregla.

`functions/test/app_check_cobertura.test.js` corta el entrypoint en un bloque
por `exports.` y exige que todo bloque con un `onCall` tenga su
`exigirAppCheck`. Contar `onCall` y contar `exigirAppCheck` y comparar los dos
números daría el mismo resultado aunque un callable llevara dos
comprobaciones y otro ninguna: es el error que ya cometió la primera versión
del centinela de FUNC-02, que miraba solo el cuerpo de cada `exports.` y
pasaba por casualidad.

El primero de sus tres tests comprueba que **el corte encuentra los callables
que hay**. Sin él, los otros dos podrían estar recorriendo una lista vacía y
pasando por eso.

El tercero exige que cada callable se registre con su **propio** nombre. No es
seguridad: es que en la fase de monitorización el log es lo único que dice qué
callable está perdiendo tokens, y un copiar-pegar que deje el nombre del
anterior lo envenena justo cuando hay que usarlo.

### Un test existente cargaba `index.js` de una forma que había que respetar

`functions/test/security_functions.test.js` no hace `require('../index.js')`:
lee el fuente, **recorta un trozo por posición de texto** y lo evalúa en un
sandbox de `vm` con un conjunto acotado de globales. Los `require` de la
cabecera no entran en ese recorte, así que el guard nuevo llegaba como
`ReferenceError` y tumbaba once tests de SEC-01/SEC-03.

Se inyecta en el sandbox **el guard de verdad**, no un doble: así esos tests
siguen corriendo contra el mismo código que producción.

### La deuda que esto cierra

El runbook tenía una entrada abierta y sin dueño: `buscarPropietarioPorCorreo`
como oráculo `correo -> (uid, nombre_completo)` sin límite de tasa, cuyo
cierre se difería explícitamente a «cuando exista enforcement de App Check».
Estaba **doblemente desactualizada**: SEC-03 ya había rehecho el contrato del
callable (ahora crea una solicitud con código aleatorio y guarda el correo
hasheado, con límite de intentos por uid), y SEC-04 añade la mitad que
faltaba. La entrada se reescribió; no se borró, porque la condición que queda
—que solo rechaza en `enforce`— importa.

---

## OPS-01 — las tareas programadas (`fe8875e`, `b5ec904`, `ac59c7e`)

Cuatro funciones programadas, `pubsub.schedule('every 24 hours')` las cuatro.
Solo una, `caducarVinculosDeTalleresInactivos`, tenía su lógica extraída y
probada (de FUNC-02). Las otras tres estaban inline en `index.js` y **sin un
solo test**. Las tres se extrajeron siguiendo ese mismo patrón: módulo en
`functions/src/`, doble en memoria en el test.

### `checkAlertsDaily` → `src/alertasVencidas.js`

El arreglo del push diario son dos escalones, `por_vencer` y `vencida`, y cada
uno se avisa una vez: dos notificaciones en la vida de una alerta.

Dos detalles que no son obvios y que están probados:

- **Un envío fallido NO consume el escalón.** Si lo consumiera, un token
  muerto o un corte de red se llevaría el aviso por delante para siempre.
- **Sin `fcmToken` no había push y tampoco entrada en el centro de
  notificaciones.** El push es el transporte; el centro de notificaciones es
  el registro duradero. Perder el registro porque el transporte no está
  disponible es al revés de como debería ser. Ahora el registro se escribe
  igual.

**La consulta de esta función NO se acotó por fecha**, al contrario que la de
recordatorios, y es deliberado: `fecha_limite` convive en `Timestamp` y en
cadena ISO heredada —el código inline ya manejaba las dos— y Firestore ordena
por **tipo** antes que por valor. Una cota sobre `Timestamp` dejaría fuera, en
silencio, todas las alertas con fecha de texto. Es el mismo fallo que el
`orderBy` que excluye documentos sin el campo, que este proyecto ya se ha
comido dos veces. Acotarla exige antes un backfill que normalice el tipo:
queda como gap.

`ultimo_aviso` y `fecha_ultimo_aviso` son contabilidad del servidor y quedan
**cerrados al cliente** en `firestore.rules`. Se atan por `affectedKeys()` y no
por valor: atar el valor deja pasar un `FieldValue.delete()`, que es
exactamente cómo se esquivó una regla equivalente en la tanda de drenaje
anterior. Los cuatro negativos son rojos sin ese acotado y el control positivo
—el propietario sigue pudiendo editar el resto de su alerta— se mantiene
verde; comprobado revirtiendo la regla y volviendo a correr la suite.

### `sendReservationReminders` → `src/recordatoriosReserva.js`

La cota de fecha va ahora en el servidor, con su índice compuesto nuevo
`reservas (estado ASC, fecha_hora_propuesta ASC)`, declarado en
`firestore.indexes.json` y registrado en el inventario del centinela
`test/firestore_indices_test.dart`. **El centinela hizo su trabajo**: al añadir
el índice sin registrar la consulta lo marcó como huérfano, y al cambiar el
número de `.where(` de `functions/` avisó de que había una consulta nueva que
podía necesitar índice.

La zona horaria es un desfase fijo de −300 minutos y no una librería de zonas:
Colombia no tiene horario de verano desde 1993, y arrastrar `tzdata` a un
entrypoint que ya paga arranque en frío por treinta funciones no compensa. Si
algún día hay usuarios fuera de Colombia el supuesto deja de valer; está
anotado en el módulo y en el runbook.

Un tercer defecto, más pequeño: **un token FCM muerto abortaba el barrido
entero**, porque el error subía hasta el `catch` de fuera del bucle. El
propietario que desinstaló la app dejaba sin recordatorio a todas las citas
que vinieran después ese día.

**El doble de prueba registra los filtros que recibe la consulta.** Es
deliberado: un barrido sin cota devuelve exactamente los mismos documentos que
uno acotado con los fixtures de un test, así que sin esa aserción el test
daría verde sobre el defecto que dice cubrir.

### `scheduledFirestoreExport` → `src/exportacionFirestore.js`

Falla en la validación, antes de llamar al cliente, y el mensaje nombra la
variable que falta. El bucket se puede fijar con `FIRESTORE_BACKUP_BUCKET`
para que staging y producción no compartan destino, igual que ya hacen con las
claves.

Lo que ningún test puede cubrir va al runbook, en su sección nueva: que el
bucket exista y esté en la misma región, que la cuenta de servicio tenga
`roles/datastore.importExportAdmin`, y que haya política de ciclo de vida —
sin la tercera, una copia completa diaria se acumula indefinidamente y el
coste crece sin techo.

### Las cuatro relanzan el error

Dos de ellas lo tragaban con un `console.error` y devolvían normalmente. Cloud
Scheduler no reintenta lo que no falla, así que un barrido roto era
indistinguible de un día sin trabajo. Ahora se relanza.

---

## Runbook

`docs/RUNBOOK.md` tiene tres secciones nuevas o reescritas:

- **App Check — verificación reproducible**: los cuatro pasos, con la tabla
  fechada por entorno que hay que rellenar. El orden no es negociable: staging
  entero antes que producción, y las métricas antes que cualquier `Enforce`.
- **Respaldo de Firestore — prerrequisitos**: los tres requisitos externos con
  sus comandos y su tabla de verificación. Incluye la advertencia que más
  vale: un respaldo que nunca se ha restaurado no está demostrado.
- **Tareas programadas**: qué corre, en qué módulo, y qué hay que operar para
  cada una.

Y la entrada de deuda de `buscarPropietarioPorCorreo`, reescrita.

---

## Gates

| Gate | Resultado |
|---|---|
| `flutter analyze` | _(pendiente de rellenar)_ |
| `flutter test` | _(pendiente de rellenar)_ |
| `functions` (Mocha) | **260 passing** (218 antes) |
| `test_rules` (Jest + emuladores) | _(pendiente de rellenar)_ |
| Centinela de índices | **4 / 4** |
| E2E de la app | _(pendiente de rellenar)_ |
| E2E de la landing | no se relanzó: ninguno de los cuatro commits toca `landing-web/` |

Los dos revisores del proyecto **sí aplican** aquí y se pasaron: el cambio
toca `firestore.rules`, `functions/index.js` y `firestore.indexes.json`.

---

## Gaps abiertos

| # | Qué | Por qué se deja |
|---|---|---|
| 1 | **El paso 2 de la verificación de App Check es manual.** No hay spec que ejerza el rechazo de punta a punta contra el emulador de Functions con `APP_CHECK_ENFORCEMENT=enforce`. | Lo automatizado es el paso 1, a nivel de unidad, que sí prueba el rechazo. El de punta a punta exige meter el emulador de Functions en una suite que hoy no lo levanta, y con `enforce` puesto **toda** la suite fallaría: hace falta una config aparte. |
| 2 | **La consulta de `alertasVencidas` sigue barriendo todas las pendientes.** No se acotó por fecha por la convivencia de `Timestamp` y cadena en `fecha_limite`. | Acotarla sin normalizar antes dejaría fuera en silencio las alertas heredadas. El backfill es una tarea con su propio riesgo y su propio centinela, no un ajuste. |
| 3 | **Cada alerta notificada hace un `update` suelto**, no un batch. | Con el dedup nuevo el volumen de escrituras cae de «todas las pendientes cada día» a «dos por alerta en toda su vida», así que el batch compra mucho menos que antes. Merece medirse antes de complicarlo. |
| 4 | **Los siete triggers de notificación siguen sin test.** OPS-01 nombra «cron/backup/notificaciones»; se cubrieron las cuatro programadas y el respaldo, no los `onCreate`/`onUpdate` que mandan push. | Son siete y ninguno tiene la lógica separada del acceso a Firestore: extraerlos es una tanda propia, del tamaño de esta. Inventariados en el reconocimiento de esta tarea. |
| 5 | **El recordatorio de reserva no escribe en el centro de notificaciones**, solo manda push — al revés que el de alertas, que ahora sí. | Es una inconsistencia real, no una decisión. Se deja porque cambia el contenido que ve el usuario y merece decidirse con el criterio de producto, no de paso. |
| 6 | **El texto de los recordatorios no dice la hora de la cita** («a la hora acordada»). | Functions no tiene ARB ni localización; meter texto localizado en el servidor es una decisión de arquitectura que no cabe en esta tarea. |
| 7 | **`checkAlertsDaily` no vuelve a avisar si el usuario mueve la fecha límite hacia el futuro y luego vuelve a acercarse.** El escalón anotado no se limpia. | Alcanzable pero raro, y limpiarlo bien exige comparar contra la fecha además del escalón. Anotado para que conste que es una elección. |
