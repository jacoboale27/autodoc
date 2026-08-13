# Análisis de Subcolecciones en Firestore — Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Determinar qué colecciones raíz de Firestore de AutoDoc son candidatas reales a convertirse en subcolecciones de otra colección, documentar pros/contras de cada candidata y producir una recomendación de largo plazo, sin ejecutar ninguna migración.

**Architecture:** Este plan NO modifica código de producción. Es un plan de análisis: cada tarea produce una sección de un documento de arquitectura (`docs/architecture/firestore-subcollections-analysis.md`) a partir de evidencia real del repo (`firestore.rules`, `functions/index.js`, repositorios Dart, tests de reglas). La "prueba" de cada tarea es que la sección quede respaldada por referencias concretas a archivo:línea, no opinión.

**Tech Stack:** Firestore (rules v2), Cloud Functions (Node/Admin SDK), Flutter/Dart repositorios (Clean Architecture, ver `CONVENTIONS.md`).

## Global Constraints

- No se modifica `firestore.rules`, `functions/index.js` ni ningún repositorio Dart en este plan — es solo análisis y documentación.
- Toda afirmación sobre patrones de acceso debe citarse con archivo:línea real (ya verificado en este repo, ver evidencia en cada tarea).
- El documento final vive en `docs/architecture/firestore-subcollections-analysis.md`.

---

### Task 1: Inventario de colecciones raíz y subcolecciones existentes

**Files:**
- Create: `docs/architecture/firestore-subcollections-analysis.md`
- Read: `firestore.rules`, `CONVENTIONS.md`

**Interfaces:**
- Produce: sección `## 1. Inventario actual` en el doc, con la tabla de colecciones que consume la Task 2.

- [ ] **Step 1: Crear el archivo con el encabezado y la tabla de inventario**

Contenido exacto a escribir (ya extraído de `firestore.rules:105-636`):

```markdown
# Análisis de Subcolecciones en Firestore — AutoDoc

Fecha: 2026-08-10

## 1. Inventario actual

### 1.1 Colecciones raíz (14, definidas en `firestore.rules`)

| Colección | Campo(s) de relación | Regla en firestore.rules |
|---|---|---|
| `usuarios` | — (raíz, id = uid) | L106 |
| `talleres` | — (raíz, id = uid del dueño) | L171 |
| `vehiculos` | `id_propietario` | L225 |
| `servicios` | `id_vehiculo`, `id_taller` | L260 |
| `alertas` | `id_vehiculo` | L333 |
| `resenias` | `id_taller`, `id_usuario`, `id_servicio` | L361 |
| `conversaciones` | `id_propietario`, `id_mecanico` | L411 |
| `reservas` | `id_propietario`, `id_mecanico` | L446 |
| `cotizaciones` | `id_propietario`, `id_mecanico` | L481 |
| `mantenimientos` | `id_vehiculo` | L516 |
| `historial_mantenimientos` | `id_vehiculo`, `id_taller` | L543 |
| `admin_logs` | — (auditoría global) | L569 |
| `notificaciones/{userId}/items` | ya anidada bajo `userId` | L580 |
| `reparaciones` | `id_vehiculo`, `id_taller`, `id_propietario` | L609 |

### 1.2 Subcolecciones que YA existen hoy

| Subcolección | Padre | Motivo (según comentarios en `firestore.rules`) |
|---|---|---|
| `talleres/{id}/empleados` | taller | Sub-cuentas de empleado, solo dueño/admin leen (L186-205) |
| `talleres/{id}/catalogo_servicios` | taller | Catálogo propio del taller, lectura pública (L207-221) |
| `conversaciones/{id}/mensajes` | conversación | Mensajes solo visibles a los 2 participantes (L429-442) |
| `cotizaciones/{id}/privado` | cotización | Beneficio por renglón, nunca visible al cliente (L499-510) |
| `notificaciones/{userId}/items` | usuario (vía userId como doc id) | Centro de notificaciones in-app (L580-585) |

Patrón común de las 5 ya existentes: **un solo padre posible, sin necesidad real de consultarlas fuera del contexto de ese padre.**
```

- [ ] **Step 2: Verificar que la tabla es fiel a las reglas actuales**

No hay comando de test — es una verificación manual: reabrir `firestore.rules` y confirmar que las 14 colecciones y las 5 subcolecciones existentes coinciden línea por línea con lo escrito en el Step 1. Si una regla cambió desde la exploración inicial, actualizar la tabla antes de continuar.

- [ ] **Step 3: Commit**

```bash
git add docs/architecture/firestore-subcollections-analysis.md
git commit -m "docs: inventariar colecciones raiz y subcolecciones existentes"
```

---

### Task 2: Identificar candidatas y descartar por patrón de acceso multi-padre

**Files:**
- Modify: `docs/architecture/firestore-subcollections-analysis.md`
- Read: `functions/index.js`, `lib/features/dashboard/presentation/providers/`, `lib/features/mechanic/`, `test_rules/*.test.js`

**Interfaces:**
- Consumes: tabla de la Task 1 (`## 1. Inventario actual`).
- Produce: sección `## 2. Candidatas y descartes` con veredicto por colección, consumida por la Task 3.

- [ ] **Step 1: Buscar evidencia de queries cruzadas (mismo tipo de doc, consultado desde más de un "padre" posible)**

Comandos a correr (documentar el resultado real, no solo el comando):

```bash
grep -rn "where('id_taller'" lib/ functions/
grep -rn "where('id_propietario'" lib/ functions/
grep -rn "where('id_vehiculo'" lib/ functions/
```

Evidencia ya recopilada en la exploración de este plan:
- `reservas` y `cotizaciones`: ambas tienen `id_propietario` **y** `id_mecanico` como posibles dueños de la consulta ("mis reservas" desde el lado dueño de vehículo, "mis reservas" desde el lado taller) — ver `firestore.rules:446-478` y `:481-511`.
- `resenias`: se lee por `id_taller` (directorio público de talleres, `test_rules/talleres-publico.test.js`) y también entra en el flujo de "mis reseñas" por `id_usuario` (`firestore.rules:361-407`) — tres campos de relación (`id_taller`, `id_usuario`, `id_servicio`), ninguno domina.
- `reparaciones`: dashboard kanban del taller filtra por `id_taller` (uso dominante, panel mecánico) pero también se lee por `id_propietario` desde el lado dueño del vehículo — `firestore.rules:609-636`.
- `servicios`: mismo patrón dual, `id_vehiculo` (historial del dueño) e `id_taller` (historial del taller) — `firestore.rules:260-329`.
- `historial_mantenimientos`: filtra por `id_vehiculo` para el dueño pero el create/update exige `id_taller == request.auth.uid` (mecánico vinculado) — `firestore.rules:543-563`. Es decir, también tiene un caso de uso taller-scoped, aunque menos evidente.

- [ ] **Step 2: Escribir la sección de descarte con el veredicto por colección**

Contenido exacto a agregar al documento:

```markdown
## 2. Candidatas y descartes

### 2.1 Descartadas — patrón de acceso multi-padre real

Estas colecciones tienen **más de un "dueño" que las consulta de forma independiente**. Anidarlas bajo cualquiera de los dos padres rompe la consulta del otro lado (habría que reemplazarla por una `collectionGroup` query, perdiendo la ventaja principal de anidar).

| Colección | Padres en competencia | Por qué NO anidar |
|---|---|---|
| `servicios` | `vehiculos` (dueño) / `talleres` (mecánico) | Panel del taller lista servicios propios cruzando muchos vehículos distintos (`firestore.rules:308-312`) |
| `reparaciones` | `vehiculos` (dueño) / `talleres` (kanban del mecánico, uso dominante) | El kanban del taller (`initiate_service_screen.dart`, `cotizacion_chat_card.dart`) necesita listar tickets de TODOS sus vehículos a la vez |
| `reservas` | `usuarios` propietario / `usuarios` mecánico | Ambos lados agendan y consultan "mis reservas" de forma simétrica (`firestore.rules:446-478`) |
| `cotizaciones` | `usuarios` propietario / `usuarios` mecánico | Mismo patrón simétrico que `reservas` (`firestore.rules:481-497`) |
| `resenias` | `talleres` (directorio público) / `usuarios` (mis reseñas) / `servicios` | Necesita ser de lectura pública top-level para el directorio (`allow read: if true`, `firestore.rules:363`); anidar bajo taller rompería "mis reseñas" por usuario |
| `historial_mantenimientos` | `vehiculos` (dueño) / `talleres` (mecánico que registró) | El create/update exige `id_taller == request.auth.uid`, un segundo eje de acceso real (`firestore.rules:550-559`) |

### 2.2 Candidatas reales — un solo padre, sin necesidad de query cruzada

| Colección | Padre único propuesto | Evidencia de acceso single-parent |
|---|---|---|
| `alertas` | `vehiculos/{id}/alertas` | Todas las reglas (read/create/update/delete) filtran exclusivamente por `id_vehiculo`, sin ningún camino de acceso "por taller" (`firestore.rules:333-358`) |
| `mantenimientos` | `vehiculos/{id}/mantenimientos` | Mismo patrón que `alertas`: únicamente `id_vehiculo` en las 4 reglas (`firestore.rules:516-538`) |

### 2.3 Ya no aplica — colecciones raíz de identidad, no relación

`usuarios`, `talleres`, `vehiculos`, `admin_logs`, `notificaciones` no son candidatas: son la raíz de la jerarquía o (en el caso de `admin_logs`) una auditoría global que debe permanecer consultable sin restricción de padre.
```

- [ ] **Step 3: Commit**

```bash
git add docs/architecture/firestore-subcollections-analysis.md
git commit -m "docs: identificar candidatas y descartes por patron de acceso"
```

---

### Task 3: Pros y contras detallados de migrar `alertas` y `mantenimientos`

**Files:**
- Modify: `docs/architecture/firestore-subcollections-analysis.md`
- Read: `functions/index.js:79,184-188,980,985` (triggers que tocan `alertas`/`mantenimientos`), `test/firestore_rules/rules.test.js:160-196`

**Interfaces:**
- Consumes: sección `## 2.2 Candidatas reales` de la Task 2.
- Produce: sección `## 3. Pros y contras — alertas y mantenimientos` consumida por la Task 4 (recomendación final).

- [ ] **Step 1: Escribir la sección de pros/contras**

```markdown
## 3. Pros y contras — `alertas` y `mantenimientos`

### Pros de anidar bajo `vehiculos/{id}/...`

1. **Borrado en cascada más simple.** Hoy, borrar un vehículo requiere una Cloud Function que haga 3 queries `where('id_vehiculo', '==', id)` separadas (una por `alertas`, `mantenimientos`, y potencialmente más). Anidadas, un borrado recursivo de la subcolección cubre el caso con una sola operación por vehículo.
2. **Navegabilidad en la consola de Firebase.** Ver todas las alertas/mantenimientos de un vehículo específico es un side-panel directo en la consola, sin tener que filtrar manualmente una colección plana.
3. **Menos proliferación de índices en colecciones raíz separadas.** Los índices por `id_vehiculo` + orden (p.ej. por fecha) viven hoy en 2 colecciones top-level; anidados, cada subcolección es pequeña y no compite por espacio de índice con el resto de la app.

### Contras de anidar bajo `vehiculos/{id}/...`

1. **No elimina el costo real de la regla de seguridad.** La pertenencia (`isVehicleOwner`) depende del campo `id_propietario` que vive en el documento `vehiculos/{id}`, no de la ruta. Anidar la subcolección NO evita el `get()`/`exists()` extra en las reglas (`isVehicleOwner` ya usa `get()` sobre `vehiculos/{vehiculoId}` incluso hoy con colección plana) — el beneficio de rendimiento en reglas es marginal o nulo.
2. **Migración de datos con script propio.** Requiere un backfill (mismo patrón que `functions/migrate_vehiculos.js`, ya existente en el repo) para mover cada documento de `alertas`/`mantenimientos` a `vehiculos/{id_vehiculo}/alertas/{mismo_id}`, y una ventana de corte para evitar escrituras perdidas durante la migración.
3. **Reescritura de repositorios cliente.** Todo código que hoy hace `.collection('alertas').where('id_vehiculo', '==', id)` (p.ej. `alert_provider_multi_vehicle_test.dart`, `alert_provider_test.dart`) pasa a `.collection('vehiculos').doc(id).collection('alertas')` — cambia la forma de escuchar streams multi-vehículo (`alert_provider_multi_vehicle_test.dart` sugiere que hoy se escuchan alertas de VARIOS vehículos a la vez desde un solo listener, lo cual con subcolecciones exige una `collectionGroup('alertas')` en vez de un listener por vehículo, o N listeners).
4. **Reglas de seguridad nuevas y re-test.** Firestore no hereda reglas del padre (ya documentado explícitamente en `firestore.rules:186-189` para `empleados`) — hay que escribir `match /vehiculos/{vehiculoId}/alertas/{alertaId}` desde cero y volver a correr toda la suite `test/firestore_rules/rules.test.js` + agregar equivalentes en `test_rules/`.
5. **Riesgo de regresión silenciosa.** Cualquier Cloud Function que hoy escriba con Admin SDK a `db.collection('alertas')` (ver `functions/index.js:79`) debe actualizarse en el mismo commit que la migración de datos, o quedará escribiendo a una colección "fantasma" que ya nadie lee.
```

- [ ] **Step 2: Commit**

```bash
git add docs/architecture/firestore-subcollections-analysis.md
git commit -m "docs: pros y contras de anidar alertas y mantenimientos"
```

---

### Task 4: Recomendación final de largo plazo

**Files:**
- Modify: `docs/architecture/firestore-subcollections-analysis.md`

**Interfaces:**
- Consumes: secciones `## 2` y `## 3`.
- Produce: sección final `## 4. Recomendación` — es el entregable que responde la pregunta original del usuario.

- [ ] **Step 1: Escribir la recomendación**

```markdown
## 4. Recomendación

**No se recomienda una migración general de "limpieza" de la estructura ahora mismo.**

Motivo: de las 14 colecciones raíz, 6 tienen un patrón de acceso genuinamente multi-padre (`servicios`, `reparaciones`, `reservas`, `cotizaciones`, `resenias`, `historial_mantenimientos` — ver §2.1) donde anidar bajo cualquiera de los padres posibles rompe la consulta del otro lado y obliga a sustituir queries simples por `collectionGroup` queries más caras y con más índices que mantener. Migrarlas sería cambiar complejidad de un lado (colección plana + `where`) por complejidad de otro (subcolección + `collectionGroup` + reglas duplicadas), sin ganancia neta.

Solo `alertas` y `mantenimientos` (§2.2) son candidatas técnicamente limpias: tienen un único padre real (`vehiculos`) sin ningún caso de uso taller-scoped en las reglas actuales. Aun así, el beneficio principal que ofrecería anidarlas (navegabilidad en consola, borrado en cascada más simple) es marginal frente al costo real (§3): no reduce el costo de las reglas de seguridad (la verificación de dueño sigue requiriendo un `get()` al documento del vehículo, esté la subcolección anidada o no), y sí exige backfill de datos, reescritura de repositorios/providers Dart, reglas nuevas y toda la suite de tests de reglas actualizada.

**Conclusión práctica:**
- Dejar la estructura actual como está. Las 5 subcolecciones que ya existen (`empleados`, `catalogo_servicios`, `mensajes`, `privado`, `notificaciones/items`) están correctamente anidadas porque cumplen el criterio real: un solo padre, sin necesidad de consulta cruzada — y son la guía de cuándo SÍ vale la pena anidar en el futuro.
- Si en algún momento se justifica anidar `alertas`/`mantenimientos` (p.ej. por necesidad real de borrado en cascada masivo, no solo "orden"), tratarlo como un plan de migración propio y acotado — no como parte de una limpieza general — dado el costo real documentado en §3.
- Cualquier colección nueva que se agregue de aquí en adelante debe evaluarse con el mismo criterio de §2: ¿tiene un único padre natural y ningún caso de uso que la consulte cruzando padres? Si sí, anidarla desde el diseño inicial evita esta discusión más adelante.
```

- [ ] **Step 2: Auto-revisión del documento completo**

Releer `docs/architecture/firestore-subcollections-analysis.md` de principio a fin y confirmar:
- Cada afirmación de patrón de acceso tiene una referencia archivo:línea verificable.
- La tabla de §1 y los veredictos de §2 no se contradicen entre sí.
- §4 responde explícitamente las 3 preguntas originales: qué colecciones son candidatas, pros/contras, y si es recomendable a largo plazo.

- [ ] **Step 3: Commit final**

```bash
git add docs/architecture/firestore-subcollections-analysis.md
git commit -m "docs: recomendacion final sobre subcolecciones en Firestore"
```
