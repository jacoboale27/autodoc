# Asistente de agenda con IA (Gemini) — plan de implementación

**Fecha:** 2026-09-19 · **Rama propuesta:** `feat/asistente-agenda`
**Origen:** petición directa del usuario, no es una tarea del plan maestro de remediación.
**Alcance temporal:** 5 días · **Presupuesto:** plan Claude $20 + Codex (cuota limitada).

> **Lee el §1 antes que nada.** Cuatro de los siete hallazgos harían que el asistente diera
> respuestas **falsas por construcción**, y ninguno se ve desde fuera del código.

---

## 0. ⚠️ URGENTE, antes de tocar nada: `.firebaserc` está invertido y sin commitear

El árbol de trabajo tiene este cambio **sin commitear**:

```diff
-    "default": "autodoc-staging",
+    "default": "autodoc-6ef5a",
```

**Esto invierte la advertencia que `CLAUDE.md` da como permanente.** Ese documento dice:

> `.firebaserc` tiene `"default": "autodoc-staging"`, así que **todo `firebase deploy` sin
> `--project` va a staging**.

**Hoy es falso.** Con el árbol actual, **todo `firebase deploy` sin `--project` va a PRODUCCIÓN.**

Es exactamente la clase de defecto del incidente del 2026-09-13: la condición peligrosa no vive
en el código que las suites miran, sino en la configuración del despliegue. Un `firebase deploy`
tecleado de memoria, confiando en lo que dice `CLAUDE.md`, ahora publica en producción.

**Acciones, en este orden:**

1. **Decidir y commitear** el valor de `default`. El usuario ha confirmado que **toda la demo
   vive en producción** y que staging no se ha usado nunca, así que apuntar el default a
   producción es defendible — pero entonces **`CLAUDE.md` y `AGENTS.md` deben corregirse en el
   mismo commit**, o el siguiente worker (humano o agente) actuará sobre información falsa.
2. Mientras tanto, y para siempre: **`--project production` o `--project staging` explícito en
   todo despliegue**. Nunca el implícito. El default es una red de seguridad, no una interfaz.

---

## 1. Diagnóstico — lo que el código dice y la app no

Siete hallazgos, medidos sobre el árbol del 2026-09-19. Los cinco primeros son sobre alertas;
los dos últimos aparecieron al evaluar el rol de taller.

### 1.1 `vencimientoTarjeta` no genera ninguna alerta — **defecto de producción**

`VehicleModel` tiene `vencimientoTarjeta` (`lib/core/models/vehicle_model.dart:12`), se persiste
(`:123`), se parsea (`:177`) y **el usuario lo edita a mano**
(`lib/features/dashboard/presentation/pages/vehicle_profile_screen.dart:978`).

`AlertProvider._generateSmartAlerts` **solo lee `vencimientoSoat`**. La tarjeta no aparece.

> Le pides un dato al usuario, se lo guardas, y no le avisas jamás. Un usuario con la tarjeta de
> propiedad venciendo en 3 días tiene **cero** alertas sobre eso.

Es el argumento más fuerte a favor de esta feature, y **decide la arquitectura**: la agenda se
construye desde los **campos crudos del vehículo**, no desde la lista de alertas.

### 1.2 Tres tipos de alerta son incondicionales y **sin fecha**

`llantas_`, `fluidos_` y `luces_` (`alert_provider.dart:232`, `:252`, `:264`) se emiten para
**todos los vehículos, siempre**, sin ninguna condición, con `fechaLimite: null`.

Un asistente que lea la lista de alertas para responder *"¿qué tengo en los próximos días?"*
contesta con tres recordatorios permanentes disfrazados de vencimientos inminentes, **por cada
coche del garaje**.

### 1.3 Hay una **fecha inventada** en el modelo, y el propio código lo dice

```dart
fechaLimite: DateTime.now().add(
  const Duration(days: 15),
), // Aproximado para la UI
```

Las alertas de mantenimiento son **por kilometraje**, no por fecha. Ese `+15 días` es relleno
para que la UI tenga algo que ordenar.

> **Este es el campo más peligroso del repo para dárselo a un modelo.** Un LLM lo afirmará como
> un hecho: *"tu cambio de aceite vence el 4 de octubre"*. Un asistente que inventa una fecha de
> mantenimiento destruye la confianza en todo lo demás que dice.

**Regla dura del plan:** el mantenimiento se expresa **siempre en kilómetros**, nunca en días.
El campo `fechaLimite` de las alertas de tipo `Mantenimiento` **no entra jamás en el envelope**.

### 1.4 La alerta de SOAT **no existe** hasta los 15 días

```dart
if (daysToExpire <= 15) {   // antes de eso, no hay objeto AlertModel
```

SOAT venciendo en 40 días → lista vacía → el asistente responde *"no tienes nada próximo"*.
Correcto sobre las alertas, **falso sobre la realidad del usuario**.

> **La idea central de todo este plan:** la pregunta del usuario no es sobre *alertas*, es sobre
> los **compromisos de su vehículo**. `AlertModel` es un artefacto de UI con una ventana de 15
> días horneada dentro. Responder desde ahí es responder otra pregunta.

### 1.5 Las alertas no cargan su propio texto visible

`task_inconsistente_` nace con `descripcion: ''`, y el comentario lo explica: *"El texto visible
se arma en la pantalla que la muestra (l10n): el provider no tiene BuildContext/locale."*

Las descripciones que sí existen están **hardcodeadas en español** dentro del provider
(*"Tu SOAT vence en $daysToExpire días."*). Enviar `AlertModel` al servidor manda objetos sin
texto, o con texto sin traducir — que enlaza con los **274 literales** todavía pendientes.

### 1.6 El panel del taller **no consulta `reservas` en absoluto**

```
grep -rn "reservas" lib/features/mechanic/   →  0 resultados
```

`mechanic_dashboard_screen.dart` existe, pero **el taller no tiene ninguna vista de sus citas
próximas**. Es el mismo hallazgo que §1.1, del otro lado del producto: el dato existe, nadie lo
muestra. Justifica por sí solo la intención `agenda` para el rol taller.

### 1.7 No existe índice para la agenda de ninguno de los dos roles

El único índice de `reservas` es `(estado, fecha_hora_propuesta)`, creado en SEC-04/OPS-01 para
el **barrido global** de recordatorios. Las dos consultas de este plan necesitan índices nuevos
(§6.2). Los emuladores sirven cualquier consulta sin mirar `firestore.indexes.json`, así que
**sin el índice esto solo falla en producción** — el centinela `test/firestore_indices_test.dart`
es quien lo atrapa.

---

## 2. Arquitectura elegida

### 2.1 Enrutamiento por intención cerrada

Un asistente con caja de texto abierta sobre datos de usuario es un *confused deputy*: el
callable corre con **Admin SDK**, donde `firestore.rules` **no aplica** (la lección de
`iniciarReparacionPorVehiculo` en FUNC-02). El modelo nunca debe elegir qué leer.

```
Pregunta del usuario
   │
   ├─[1] CLASIFICAR ──→ el modelo devuelve UNA etiqueta de un enum cerrado.
   │                     No texto libre, no nombres de colección, no consultas.
   │
   ├─[2] EJECUTAR ─────→ el SERVIDOR corre la consulta determinista de esa intención.
   │                     ◄── TODA la autorización ocurre AQUÍ, antes de que el modelo vea nada.
   │
   └─[3] REDACTAR ─────→ el modelo convierte el envelope en prosa.
                         No puede inventar datos: solo tiene el envelope.
```

El modelo hace **dos trabajos acotados**: elegir una etiqueta y redactar. No hay function
calling, no hay tool use, no hay RAG, no hay vector DB.

### 2.2 Las intenciones

| Intención | Pregunta tipo | Rol | Caché |
|---|---|---|---|
| `agenda` | *"¿qué tengo en los próximos días?"* | propietario **y taller** | No (por usuario, temporal) |
| `explicar` | *"¿qué es el SOAT y qué pasa si vence?"* | ambos | **Sí, global** |
| `estado` | *"¿cómo está mi carro?"* | propietario | No |
| `historial` | *"¿qué le han hecho a mi carro?"* | propietario | Por vehículo — **stretch** |
| `fuera_de_alcance` | *"¿por qué suena el motor?"* | — | — |

`fuera_de_alcance` es lo que mata el diagnóstico por síntomas de forma **explícita y testeable**,
en vez de confiar en que el prompt se porte bien. Es una etiqueta del enum, con su propio test.

### 2.3 El envelope de `agenda`, por rol

**Propietario** — sus vehículos (`id_propietario == uid` ∪ `sharedWith` contiene `uid`):

| Fuente | Campo | Cómo viaja en el envelope |
|---|---|---|
| `vehiculos` | `vencimiento_soat` | `{tipo:'soat', dias_restantes: 40}` ← **precalculado** |
| `vehiculos` | `vencimiento_tarjeta` | `{tipo:'tarjeta', dias_restantes: 3}` ← 🎁 hoy invisible |
| `reservas` | `fecha_hora_propuesta`, estado `confirmada` | `{tipo:'cita', dias_restantes: 2, hora:'10:00'}` |
| `mantenimientos` | graduado contra `kilometraje_actual` | `{tipo:'mantenimiento', km_restantes: 1200}` |

**Taller** — resuelto por `idTallerEfectivo` (§2.4):

| Fuente | Campo | Cómo viaja |
|---|---|---|
| `reservas` | `id_taller == tallerEfectivo`, estado `confirmada` | `{tipo:'cita', dias_restantes, hora, placa, tipo_servicio}` |

### 2.4 ⚠️ Resolución de rol: el callable debe replicar lo que hacen las reglas

Como el callable corre con Admin SDK, **tiene que reimplementar dos predicados a mano**:

1. **`actuaPorTaller`** (`firestore.rules:214`): el taller efectivo es
   `uid` **o** `usuarios/{uid}.id_taller_propietario`. Los **empleados actúan por su taller** —
   el equivalente en cliente es `UserModel.idTallerEfectivo` (`lib/core/models/user_model.dart:49`).
   Si el callable solo mira `uid == id_taller`, **ningún empleado ve la agenda**.

2. **`isMecanico`** (`firestore.rules:45-49`) exige
   `estado in ['aprobado', 'activo']`. Un taller `pendiente` **no** debe recibir agenda. Esto
   enlaza con el Pendiente 0 del runbook de H-01: hay talleres de producción que podrían no
   tener el campo `estado`. El callable usa el mismo default defensivo: `get('estado','pendiente')`.

**Los dos predicados llevan test propio, positivo y negativo.** Es exactamente la trampa que
ROLE-01 documentó: un test de autorización que apunta a un predicado que no es el que decide.

### 2.5 Por qué callable y no el SDK `firebase_ai` en el cliente

Google recomienda `firebase_ai` (Firebase AI Logic) porque la clave se queda en el servidor y
App Check protege el endpoint. **Aquí no sirve**, por tres razones medidas:

1. **App Check está en `monitor` a propósito.** `CLAUDE.md`: con `enforce`, *"la suite E2E entera
   dejaría de pasar: el emulador de Functions no emite tokens"*. Firebase AI Logic **fuerza App
   Check desde julio de 2026**. El camino "seguro por defecto" de Google depende del interruptor
   que este repo tiene deliberadamente apagado.
2. **El callable nº 35 es lo más barato que existe en este repo.** Ya hay 34, más
   `exigirAppCheck`, más el centinela que corta el entrypoint por bloques `exports.`, más los dos
   subagentes-gate. Un patrón nuevo es lo más caro.
3. **La sanitización y la cuota tienen que ser server-side igualmente.** Con `firebase_ai` las
   harías dos veces.

---

## 3. Fase 0 — Preparación · **BLOQUEANTE** · medio día

### 3.1 Resolver `.firebaserc` (§0) y corregir `CLAUDE.md` + `AGENTS.md`

Criterio de cierre: `git diff .firebaserc` vacío, y los dos documentos dicen la verdad sobre a
qué proyecto apunta el default.

### 3.2 Clave de Gemini en Secret Manager — **del proyecto de producción**

La demo vive en **producción** (`autodoc-6ef5a`). Staging nunca se ha usado.

```bash
# La clave sale de Google AI Studio.
firebase functions:secrets:set GEMINI_API_KEY --project production
```

- **Nunca** en un `.env` versionado, **nunca** en el bundle del cliente.
- El hook de `.claude/` ya bloquea la edición de `.env`/credenciales: no lo esquives.
- Si quieres el endpoint también en staging, es un `secrets:set` aparte. No es obligatorio.

### 3.3 Spike, **timebox 2 horas**

Un callable mínimo que llame a Gemini y devuelva texto. Nada más: sin cuota, sin envelope, sin UI.

> **Si a las 2 horas no responde, se aborta el plan.** Pierdes medio día, no cinco. Es el único
> punto de salida barato que tiene este trabajo.

### 3.4 Fixtures de demo (Codex, en paralelo)

Sembrar en **emuladores** un juego de datos que **espeje** los vehículos de demo de producción:
SOAT y tarjeta poblados a distintas distancias (3, 12, 40, 200 días y uno vencido), un vehículo
con `kilometraje_actual < task.ultimoKm` (el caso inconsistente del §1.3), y citas confirmadas
para un taller a 1, 2 y 9 días.

> **El desarrollo va contra emuladores, siempre.** Producción es solo el destino del despliegue.

---

## 4. Fase 1 — `construirAgenda()` determinista, **sin IA** · día 1

**Esta fase es el seguro de todo el plan.** Es código determinista y testeable que vale por sí
solo: si la cuota se agota el día 3 —como ya pasó en GAPS-06 y GAPS-07— no te quedas con cero,
te quedas con una feature real que además tapa el agujero de §1.1 y §1.6.

`functions/src/agenda.js`, exportando `construirAgenda(uid, { ahora, ventanaDias })`.

### 4.1 Reglas invariantes

1. **Toda aritmética de fechas ocurre aquí, en JS.** El envelope lleva `dias_restantes` como
   entero. El modelo **nunca** recibe una fecha cruda para que la reste.
2. **El mantenimiento viaja en `km_restantes`, jamás en días.** (§1.3)
3. **`ahora` se inyecta.** Sin eso ningún test puede afirmar sobre vencimientos — la cicatriz del
   reloj inyectable de INNO-01.
4. **Nada de `AlertModel`.** Campos crudos de `vehiculos`, `reservas` y `mantenimientos`.
5. **Zona horaria:** Colombia es UTC-5. El barrido de citas de SEC-04/OPS-01 ya se equivocó una
   vez calculando "mañana" en UTC y descolocando las citas de tarde. `dias_restantes` se calcula
   sobre el día **local**, no sobre UTC.

### 4.2 Orden de los tests (TDD, rojo primero)

1. Propietario sin vehículos → agenda vacía, no error.
2. SOAT a 40 días → **aparece** (§1.4: la app no lo mostraría).
3. `vencimiento_tarjeta` a 3 días → **aparece** (§1.1: hoy no existe en ninguna parte).
4. SOAT vencido hace 10 días → `dias_restantes: -10`, no se omite.
5. Vehículo compartido (`sharedWith`) → entra. Vehículo ajeno → **no entra**.
6. Cita `confirmada` a 2 días → entra. Cita `pendiente`/`cancelada` → **no entra**.
7. Mantenimiento por vencer → `km_restantes`, y el envelope **no contiene ninguna fecha**.
8. `kilometraje_actual < task.ultimoKm` → marcado `inconsistente`, no como "faltan 40.000 km".
9. **Taller dueño** (`uid == id_taller`) → sus citas confirmadas.
10. **Taller empleado** (`id_taller_propietario`) → las citas **del taller dueño** (§2.4).
11. **Taller con `estado: 'pendiente'`** → denegado. **Taller sin campo `estado`** → denegado.
12. Ventana: cita a 9 días con `ventanaDias: 7` → fuera.

Gate: `cd functions && npm test` verde.

---

## 5. Fase 2 — El callable `asistenteAutoDoc` · día 2

`functions/index.js` + `functions/src/asistente.js`.

### 5.1 Estructura

```js
exports.asistenteAutoDoc = functions.https.onCall(async (data, context) => {
  exigirAppCheck(context, 'asistenteAutoDoc');   // obligatorio: centinela por bloques exports.
  // 1. auth
  // 2. kill switch  (§5.5)
  // 3. cuota transaccional por uid  (§5.2)
  // 4. clasificar intención  → enum cerrado  (§5.3)
  // 5. construirAgenda() / caché de explicaciones  → envelope YA autorizado
  // 6. redactar  (§5.4)
});
```

### 5.2 Cuota — **clona `solicitudes_landing_control`, no diseñes nada**

UX-01 ya dejó un contador transaccional con TTL, revisado, testeado y en el runbook. Se clona a
`consultas_ia_control`, con **uid** en vez de hash de IP.

- **10 consultas/día por usuario**, **200/día global** con corte duro.
- Free tier de Gemini Flash: ~1.500 req/día y 10 RPM. El corte global va **por debajo** a
  propósito.
- La colección se cierra al cliente **por los dos lados** en las reglas (§6.1), y hace falta
  **política TTL** — no se configura desde `firestore.indexes.json` (§9).

### 5.3 Clasificador — enum cerrado

- El modelo devuelve **una** de: `agenda | explicar | estado | historial | fuera_de_alcance`.
- **Cualquier respuesta que no esté en el enum → `fuera_de_alcance`.** No se reintenta, no se
  interpreta, no se parsea con heurística.
- `fuera_de_alcance` responde con un texto fijo y localizado, **sin llamar al redactor**: ahorra
  una llamada y hace el rechazo determinista.

### 5.4 Redactor — el envelope y nada más

- Recibe el envelope **ya autorizado y ya calculado**. No recibe el `uid`, ni IDs de documento,
  ni texto escrito por terceros.
- Prompt con instrucción explícita: *no inventes datos que no estén en el envelope; si falta un
  dato, dilo*.
- **El idioma se pasa como parámetro** desde el cliente (locale activo), no se infiere. Es la
  cicatriz de INNO-01: la app se renderiza en inglés cuando el navegador lo está.

### 5.5 Kill switch

Flag en Firestore que apaga la feature **sin desplegar**. 20 líneas. Es tu seguro para el día de
la demo, y es la lección del 2026-09-13 aplicada: el interruptor no puede requerir un build.

### 5.6 Cliente del modelo **inyectado**

Es el patrón de VER-01 (`FilePickerPlatform.instance`) y de FUNC-02 (inyectar Firestore, que puso
13 tests en rojo de golpe al hacerlo).

**Los tests-gate afirman sobre la petición construida y el manejo de la respuesta, nunca sobre la
prosa del modelo:**

1. El prompt enviado **no contiene** texto escrito por terceros.
2. El prompt **no contiene** ninguna fecha de mantenimiento (§1.3).
3. Una etiqueta inventada por el modelo → `fuera_de_alcance`.
4. Un 429 del proveedor → `resource-exhausted`, con su mensaje propio.
5. La 11ª consulta del día → cortada **antes** de llamar al modelo.
6. Kill switch activo → cortado antes de todo.
7. `explicar` dos veces → **una sola** llamada al modelo (caché, §6.1).
8. Taller `pendiente` → denegado **antes** de construir envelope.

---

## 6. Fase 3 — Reglas, índices y gates · día 3

### 6.1 Reglas

- `consultas_ia_control/{uid}` → **cerrada al cliente por ambos lados** (ni lectura ni escritura).
  Solo Admin SDK.
- `explicaciones_ia/{hash}` → lectura autenticada, escritura **solo** Admin SDK.
- Ojo con la lección de GAPS-05: **`allow write` cubre create, update *y* delete.** Escribe los
  verbos por separado.

### 6.2 Índices nuevos (2)

```
reservas (id_propietario ASC, estado ASC, fecha_hora_propuesta ASC)
reservas (id_taller      ASC, estado ASC, fecha_hora_propuesta ASC)
```

El centinela `test/firestore_indices_test.dart` cruza inventario e índices **en las dos
direcciones**: si añades la consulta sin el índice, rompe. Déjalo romper primero.

### 6.3 Gates obligatorios — **no son opinión**

```
firestore-rules-reviewer     ← toca firestore.rules
functions-perf-reviewer      ← toca functions/index.js
```

El historial es inapelable: en GAPS-04 los revisores encontraron **siete** defectos que las
suites propias no veían; en SEC-04/OPS-01, **tres**, uno de ellos una denegación de servicio.
En GAPS-06 el gate tumbó el arreglo del propio autor.

**Atención especial del `functions-perf-reviewer`:** el N+1. `construirAgenda` para un propietario
con varios vehículos no debe leer `mantenimientos` vehículo por vehículo. Y el `whereIn` aplica
el `limit` **por subconsulta** (gap 9.1, repetido tres tandas seguidas).

---

## 7. Fase 4 — Cliente Flutter · día 4

- Entrada: campo de texto en `/alerts` (propietario) y en `mechanic_dashboard_screen.dart`
  (taller). Una sola pantalla de conversación de **un turno** — sin historial, sin memoria.
- **ARB desde la primera línea**, `es` y `en`. Cero literales nuevos sin traducir: hay **274**
  pendientes y esta feature no añade el 275.
- **`mensajeDeAsistente` propio.** No reutilices `mensajeDeError`: manda `deadline-exceeded` a
  *"revisa tu conexión"* y `permission-denied` a *"vuelve a iniciar sesión"*. Aquí
  `resource-exhausted` significa **"agotaste tus 10 consultas de hoy"**, y **no merece botón de
  reintentar** (patrón `paseMereceReintento` de INNO-01).
- **Doble envío: las dos capas.** `onPressed: null` solo surte efecto **en el frame siguiente**
  (GAPS-07): hace falta también el guard de reentrada. Y cuidado con lo que se construye dentro
  de `build` — un `setState` lo recrea.
- Estados a pintar, todos: cargando, respuesta, vacío, error con mensaje localizado, cuota
  agotada, fuera de alcance, kill switch apagado.

---

## 8. Fase 5 — E2E, evals y evidencia · día 5

- **E2E Playwright en serie (`--workers=1`).** En paralelo no es reproducible y su rojo no es
  señal (contención del emulador Java). `getByRole`, no `getByLabel`. Clic previo
  (`page.mouse.click(10,10)`) para que Flutter construya el árbol de semántica.
- **Evals golden, manuales, una corrida.** 15-20 preguntas con su envelope fijo. Se revisan a
  mano y el resultado va al documento de evidencia. No entra en los gates automáticos: es
  evidencia, como el resto del proyecto.
- **Documento de evidencia:** `docs/evidencia/IA-01-asistente-de-agenda.md`, con §Gaps al final.
- **Drenaje de gaps.** El historial dice que cada tanda genera entre 9 y 15. Reserva el tiempo.

---

## 9. Runbook de despliegue — pasos nuevos

Al `docs/RUNBOOK.md`, **en este orden**:

1. `firebase functions:secrets:set GEMINI_API_KEY --project production` (§3.2).
2. `firebase deploy --only firestore:indexes --project production` — **antes** que las funciones.
   Sin los dos índices del §6.2, la agenda falla **solo en producción**.
3. **Política TTL de `consultas_ia_control`** — se crea en consola, no desde
   `firestore.indexes.json`. Sin ella la colección crece sin límite.
4. `firebase deploy --only firestore:rules --project production`.
5. `firebase deploy --only functions:asistenteAutoDoc --project production`.
6. Crear el documento del **kill switch** en estado **encendido** y verificar que apaga.
7. `APP_CHECK_ENFORCEMENT` llega por archivos `.env` **por proyecto**, no por un ajuste de
   consola. El default sigue siendo `monitor`, deliberadamente (§2.5).
8. **Hosting:** `flutter clean` no es opcional, y la guarda `predeploy`
   (`scripts/verificar_bundle_web.js`) debe pasar. Siempre `--project` explícito.

---

## 10. Lo que queda fuera, y por qué

| Fuera | Motivo |
|---|---|
| Diagnóstico por síntomas | Consejo de seguridad vehicular. Responsabilidad legal. Es `fuera_de_alcance`, con test. |
| Traducción de jerga del mecánico | El input es texto libre escrito por un tercero → superficie de prompt injection. |
| Multi-turno con memoria | Multiplica cuota y superficie. Un turno, sin historial. |
| Streaming de tokens | Complica la UI y los tests. No aporta a la demo. |
| RAG / vector DB | El envelope de un usuario cabe en ~2.000 tokens. Es complejidad inventada. |
| `firebase_ai` en cliente | §2.5. |
| Escrituras por el asistente | **Solo lectura.** Nada de "agéndame la cita". Es otro plan. |

---

## 11. Definition of Done

- [ ] `.firebaserc` resuelto y commiteado; `CLAUDE.md` y `AGENTS.md` corregidos (§0).
- [ ] `flutter analyze` → `No issues found!`
- [ ] `flutter test` ≥ **1301** (base actual), exit 0, **salida capturada a fichero, nunca por `tail`**.
- [ ] `cd functions && npm test` verde, incluido el centinela de App Check.
- [ ] `cd test_rules && npm test` verde (vía `npm test`, nunca `npx jest` a pelo).
- [ ] `test/firestore_indices_test.dart` verde con los dos índices nuevos.
- [ ] E2E de la app **en serie**, verde, **cero `fixme`**, puertos libres al salir.
- [ ] `firestore-rules-reviewer` y `functions-perf-reviewer` pasados, hallazgos cerrados o anotados.
- [ ] Cero literales nuevos sin traducir (es/en).
- [ ] Evals golden corridos y revisados a mano.
- [ ] `docs/evidencia/IA-01-asistente-de-agenda.md` escrito, con §Gaps.
- [ ] Runbook actualizado con los 8 pasos del §9.
- [ ] Kill switch verificado **en los dos sentidos**.
- [ ] **El defecto de `vencimientoTarjeta` (§1.1) anotado como hallazgo propio**, arreglado o con
      su razón para no arreglarlo. No se cierra por estar de camino.

---

## 12. Reparto y presupuesto

**La regla, sacada de dos muertes de cuota registradas** (GAPS-06 y GAPS-07, donde *"los tres
workers murieron sin escribir su informe"* dejando *"cero implementación útil"*):

> **Codex hace reconocimiento y redacción** — rinde aunque muera a mitad, porque deja un informe.
> **Claude hace implementación TDD, en serie** — si muere a mitad, deja código roto.

| Día | Claude (TDD, serie) | Codex (paralelo, desechable) |
|---|---|---|
| 0 | §3.1 `.firebaserc`, §3.3 spike 2h | §3.4 fixtures; medir `vencimiento_*` poblados |
| 1 | §4 `construirAgenda()` completo | — |
| 2 | §5 callable, cuota, clasificador | Borrador del documento de evidencia |
| 3 | §6 reglas, índices, gates | — |
| 4 | §7 cliente Flutter, ARB | Barrido de literales sin traducir |
| 5 | §8 E2E, evals, drenaje | Redacción final de evidencia y runbook |

**Los días 1-3 no se delegan.** Son TDD y tocan reglas.

### Confianza

| Alcance | Confianza en 5 días |
|---|---|
| `agenda` (2 roles) + `explicar` + `fuera_de_alcance` | **~85%** |
| \+ `estado` | ~75% |
| \+ `historial` (candidato B completo) | **~60%** |

`historial` es **stretch del día 5**. Depende del pase QR de INNO-01 y su envelope necesita
filtrar las descripciones libres escritas por talleres (injection). Si va apretado se corta sin
tocar nada más: es una etiqueta menos en el enum.
