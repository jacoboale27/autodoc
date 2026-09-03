# Hallazgos del uso real (2026-09-02) — Plan de implementación

> **Para trabajadores agénticos:** SUB-SKILL REQUERIDA: usa `superpowers:subagent-driven-development`
> (recomendado) o `superpowers:executing-plans` para implementar este plan tarea a tarea.
> Los pasos usan sintaxis de casilla (`- [ ]`) para el seguimiento.
> Antes de tocar código, usa `graphify` (`graphify-out/graph.json`) para ubicar los consumidores
> de cada símbolo que cambies. Las estimaciones de este plan asumen que no lo haces a ciegas.

**Goal:** Cerrar los 11 hallazgos del recorrido manual del 2026-09-02 sin romper la suite existente
y **sin deshacer ninguna de las tres decisiones de seguridad ya tomadas** que estos hallazgos rozan
(H1/H2 de cotizaciones, la no-exposición de `id_propietario` en la búsqueda por placa, y la
publicidad anónima de `talleres/{uid}`).

**Architecture:** Siete bloques. A–B son solo cliente y no dependen de nada (`flutter test`).
C–F tocan reglas de Firestore/Storage o Cloud Functions y exigen `cd test_rules && npm test` +
`firebase deploy`. G es migración de datos con ventana de mantenimiento. El orden **no** es el
orden en que se reportaron los hallazgos: está ordenado por dependencia y por riesgo de reapertura
de verificaciones.

**Tech Stack:** Flutter 3.11+ / Dart 3.11 · Firebase (Auth, Firestore, Storage, Functions) ·
Provider · GoRouter · Jest + `@firebase/rules-unit-testing` para reglas.

**Spec:** conversación de hallazgos del 2026-09-02. Las referencias `#N` son el número con el que
se reportó cada hallazgo.

## Decisiones tomadas antes de escribir este plan

Cuatro sugerencias se discutieron y se resolvieron **en contra de su formulación literal**. Están
aquí para que nadie las "arregle" de vuelta a lo que se pidió:

| # | Se pidió | Se hace | Por qué |
|---|---|---|---|
| #6 | `unitario + beneficio = total`, ambos visibles | Beneficio **privado**, panel calculado solo para el mecánico | Con ambos visibles el cliente deriva el margen por resta. Deshace el hallazgo H2 (`firestore.rules:721-732`). |
| #7 | Prohibir placa duplicada + flujo de verificación | **Solo Fase 1**: búsqueda determinista + bloqueo intra-propietario + aviso inter-propietario | Unicidad dura sin flujo de transferencia deja fuera al comprador legítimo de un carro usado. Fases 2–3 quedan fuera de alcance. |
| #8 | Nombre y contacto del propietario al buscar la placa | Contacto **solo con relación existente** (ticket / `talleres_vinculados`) | `functions/index.js:733` documenta que `buscarVehiculoPorPlaca` omite `id_propietario` a propósito. Las placas son públicas en la calle: exponerlo convierte cualquier cuenta Taller en un oráculo placa→PII. |
| #9 | Arreglar el scroll de los dropdowns | **No es scroll**: faltan 6 de 14 departamentos en los datos. Se completa a 14 depts + 44 municipios (reforma 2023) | `workshop_settings_screen.dart:46` tiene 8 departamentos hardcodeados. Falla idéntico en móvil. |

## Restricciones globales

- **Idioma de la UI**: todo texto visible va en `lib/l10n/app_es.arb` **y** `app_en.arb`. Nunca
  literales en pantalla salvo que ya existan en ese archivo.
- **Colores**: prohibido `Colors.*` en widgets. Siempre `context.appColors` / `Theme.of(context)`
  (`CONVENTIONS.md` §2.1).
- **Estado**: la lógica vive en providers; las páginas no llaman a Firebase (`CONVENTIONS.md` §1).
- **Verificación por tarea**: `flutter analyze` limpio y `flutter test` en verde antes de commit.
- **Reglas**: `cd test_rules && npm test` antes de cualquier `firebase deploy`.
- **Regla de oro de este plan**: ningún cambio de UI que dependa de una restricción de autorización
  se da por terminado sin el test de reglas correspondiente. **Un botón oculto no es un permiso
  denegado.**

## ⚠️ Riesgo transversal: reapertura masiva de verificaciones

`functions/src/reabrirVerificacion.js:29-39` define `CAMPOS_DE_IDENTIDAD`, que incluye
`especialidad`, `departamento` y `municipio`. Cualquier escritura sobre esos campos en
`usuarios/{uid}` de un taller **aprobado** devuelve su expediente a la cola de revisión y lo marca
como re-revisión.

Esto afecta a los Bloques B (divipola) y D (multi-especialidad):

- La **migración** de datos (Bloque G) usa Admin SDK y debe verificarse en emulador antes de correr
  en producción, o el admin se encuentra la bandeja con todos los talleres del país de golpe.
- El **cambio de divipola** (Bloque B) puede dejar a talleres con un municipio que ya no existe en
  la lista nueva. Si la pantalla los fuerza a re-elegir, cada uno que guarde reabre su expediente.
  Mitigación en la tarea B3.

**Antes de empezar el Bloque D o G, leer `functions/src/reabrirVerificacion.js` completo.**

## Mapa de ficheros

| Fichero | Responsabilidad | Bloque |
|---|---|---|
| `lib/core/widgets/app_image_viewer.dart` *(nuevo)* | Visor a pantalla completa con zoom | A |
| `lib/features/admin/presentation/pages/admin_verificaciones_screen.dart` | `_Evidencia` abre el visor; correo del taller | A |
| `lib/features/admin/presentation/providers/admin_verificacion_provider.dart` | Hidratar identidad desde `usuarios`, no `talleres` | A |
| `lib/features/mechanic/presentation/pages/workshop_verification_screen.dart` | Previsualización antes de subir | A |
| `lib/core/constants/divipola_sv.dart` *(nuevo)* | 14 departamentos + 44 municipios, compartido | B |
| `lib/features/mechanic/presentation/pages/workshop_settings_screen.dart` | Consume divipola compartida; multi-especialidad | B, D |
| `lib/features/chat/presentation/pages/reserva_detail_screen.dart` | "Quien propone no resuelve" | C |
| `lib/features/chat/data/models/reserva_model.dart` | `idProponente`, estados de cancelación | C |
| `firestore.rules` | Transiciones de reserva; margen privado del servicio | C, F |
| `functions/index.js` | `buscarVehiculoPorPlaca` determinista; contacto con gate | E |
| `storage.rules` | Ruta nueva `recepciones/{idReparacion}/` | E |
| `lib/core/models/user_model.dart`, `workshop_model.dart` | `especialidades: List<String>` | D |
| `functions/src/migrarEspecialidades.js` *(nuevo)* | Migración one-shot | G |

---

## Bloque A — La bandeja del administrador (#2, #10, #11)

**Por qué va primero:** son los tres hallazgos que impiden que el administrador haga su trabajo hoy,
no dependen de ninguna decisión pendiente, y no tocan reglas. Es un día de trabajo y desbloquea a
una persona real.

### Tarea A1 — Visor de evidencia a pantalla completa (#2)

**Estado actual:** `admin_verificaciones_screen.dart:412` define `_Evidencia` como una miniatura de
140×110 dentro de un `ClipRRect`, **sin ningún `GestureDetector` ni `InkWell`**. No hay forma de
ampliarla.

**Trampa que no se reportó:** `_esPdf` (línea 418) hace que los PDF se rendericen como un
`Icons.picture_as_pdf_outlined` y nada más. El NIT —el documento más determinante para aprobar un
taller— es justamente el que llega como PDF (`storage.rules` solo admite PDF en el slot `nit`).
**Arreglar solo las imágenes deja a medias el caso de uso principal.**

- [ ] Escribir el test de widget: dado un `_Evidencia` con un documento de imagen, un tap abre una
      ruta que contiene un `InteractiveViewer`. Debe fallar.
- [ ] Crear `lib/core/widgets/app_image_viewer.dart`: página a pantalla completa con
      `InteractiveViewer` (zoom + pan), fondo `colors.scrim`, botón de cierre, y `Semantics` con el
      nombre del slot. **Recibe la URL ya resuelta, no la resuelve él.**
- [ ] Envolver la miniatura de `_Evidencia` en un `InkWell` que abra el visor. Reutilizar el
      `FutureBuilder` existente: no pedir la URL dos veces.
- [ ] **PDF:** el tap sobre un PDF abre la URL en el navegador (`url_launcher`) en vez del visor.
      No añadir un renderizador de PDF embebido: es una dependencia grande para un caso que el
      navegador ya resuelve. Confirmar si `url_launcher` ya está en `pubspec.yaml`.
- [ ] Textos a `app_es.arb` / `app_en.arb`.
- [ ] `flutter test` verde.

**Éxito:** el admin abre la fachada a pantalla completa con zoom, y el NIT en PDF se abre en una
pestaña. Ambos desde la bandeja, sin salir a la consola de Firebase.

### Tarea A2 — Correo del taller en la bandeja (#11)

**Trampa:** el instinto es añadir `correo` al perfil que ya se hidrata. **No hacerlo.**
`AdminVerificacionProvider._hidratarIdentidades` resuelve desde `WorkshopService` →
`talleres/{uid}`, y `firestore.rules:265` dice `allow read: if true` — **lectura pública y
anónima**. Publicar el correo ahí lo expone a internet. El doc de `VerificacionTallerModel` ya
advierte exactamente de este fallo ("cualquier campo nuevo está a un descuido de acabar publicado").

**La vía correcta:** `firestore.rules:163` ya permite `allow read: if isOwner(userId) || isAdmin()`
sobre `usuarios/{userId}`, y `UserModel.correo` ya existe. El admin puede leer ese documento hoy.

- [ ] Test de provider: `identidadDe(uid)` devuelve un `UserModel` con `correo` no vacío, partiendo
      de un fake de `usuarios/{uid}`. Debe fallar.
- [ ] Cambiar la fuente de `_hidratarIdentidades` de `WorkshopService` a una lectura de
      `usuarios/{uid}`. **Conservar el `_enVuelo` y el `Future.wait` tal cual**: son la mitigación
      de la Ruling 20 y no hay que tocarlos.
- [ ] Renderizar el correo bajo el nombre en la tarjeta, con `SelectableText` (el admin lo va a
      copiar) y `overflow: ellipsis`.
- [ ] Verificar que `talleres/{uid}` **no** gana ningún campo nuevo en este cambio.
- [ ] `flutter test` verde.

**Éxito:** el correo aparece en la tarjeta del expediente y `talleres/{uid}` sigue sin exponer PII.

### Tarea A3 — Previsualización antes de subir (#10)

**Estado actual:** `workshop_verification_screen.dart:70` hace `ImagePicker().pickImage(...)` y
sube. El taller nunca ve lo que mandó; la única señal es el nombre del archivo (línea 346).

- [ ] Test de widget: tras seleccionar un archivo, el slot muestra una miniatura antes de confirmar.
- [ ] Mostrar la imagen seleccionada (bytes locales, `Image.memory`) en el slot, con botón "Cambiar"
      y "Confirmar y subir". Para PDF, nombre + tamaño + icono (no hay preview local barato).
- [ ] Un documento **ya subido** también debe abrirse en el `AppImageViewer` de A1. Es el mismo
      componente: reutilizarlo, no duplicarlo.
- [ ] Textos a los `.arb`.
- [ ] `flutter test` verde.

**Éxito:** el taller ve la foto antes de subirla y puede volver a mirar la que ya subió.

**Commit del bloque A** y despliegue de hosting. No requiere `firebase deploy` de reglas.

---

## Bloque B — Datos geográficos completos (#9)

**Diagnóstico corregido:** no es un problema de scroll. `_elSalvadorDivipola`
(`workshop_settings_screen.dart:46-101`) es un `static const` privado con **8 de los 14
departamentos** (faltan Chalatenango, Cuscatlán, San Vicente, Cabañas, Morazán y La Unión) y un
subconjunto arbitrario de municipios. Falla idéntico en móvil.

Además, al estar dentro de una pantalla, ni el directorio de talleres ni los filtros del admin
comparten la fuente.

**Esquema acordado:** 14 departamentos + 44 municipios de la reforma territorial de 2023.

### Tarea B1 — Extraer y completar la fuente de datos

- [x] Test puro: `divipolaSv` tiene exactamente 14 claves; la suma de municipios es 44; ningún
      municipio aparece en dos departamentos.
- [x] Crear `lib/core/constants/divipola_sv.dart` con la estructura completa. Documentar en el
      encabezado la fuente y la fecha del esquema (reforma 2023), igual que hace
      `especialidades_taller.dart` con su propio racional.
- [x] Borrar `_elSalvadorDivipola` de `workshop_settings_screen.dart` y consumir la constante nueva.
- [x] `flutter test` verde.

### Tarea B2 — Verificar si además había un problema de altura

Con 14 y 44 en vez de 8 y 9, hay que confirmar que el síntoma reportado no era *también* un
problema de scroll.

- [x] Test de widget con la lista completa a 1440×900: los 14 departamentos son alcanzables.
- [x] Si el menú se corta, añadir `menuMaxHeight` a `_DropdownField`
      (`workshop_settings_screen.dart:729`). **Si no se corta, no añadir nada** y anotarlo en el
      registro de ejecución: era solo el dato faltante.
- [x] `flutter test` verde.

### Tarea B3 — Talleres con municipio huérfano

Un taller aprobado guardado con un municipio que no está en la lista nueva verá el dropdown vacío,
y al re-elegir dispara `reabrirVerificacion` (`municipio` está en `CAMPOS_DE_IDENTIDAD`).

- [x] Test: `_DropdownField` con un `value` fuera de `items` no revienta y no fuerza `null`.
      (`initialValue: items.contains(value) ? value : null` ya parece cubrirlo — confirmarlo con un
      test en vez de asumirlo.)
- [x] Mostrar un aviso no bloqueante cuando el municipio guardado no está en la lista nueva: "tu
      municipio cambió de nombre con la reforma de 2023; al actualizarlo, tu perfil volverá a
      revisión". Explícito, no sorpresa.
- [x] Anotar cuántos talleres quedan en este estado (consulta puntual, no automatización).

**Éxito:** los 14 departamentos y sus 44 municipios están disponibles en móvil y desktop, desde una
única fuente compartida, y nadie reabre su expediente sin saberlo.

**Commit del bloque B.**

---

## Bloque C — Reservas: quién puede resolver qué (#4)

**Bug confirmado:** `reserva_detail_screen.dart:410-445`. Con `estado == 'pendiente'`:

- si `!isMecanico` → se pinta "Aceptar cita" → `_cambiarEstado('confirmada')`, **sobre su propia
  solicitud**;
- "Reprogramar" y "Rechazar" se muestran a ambas partes **sin ninguna condición**.

`reserva_chat_card.dart:234` **sí** lo hace bien (`if (estado == 'pendiente' && !isMe)`). La misma
reserva se comporta distinto según desde dónde se abra.

**La regla correcta NO es "solo el mecánico acepta".** `firestore.rules:683-685` permite crear la
reserva a cualquiera de los dos, deliberadamente, porque el mecánico también propone fechas desde el
chat. Codificar "solo el mecánico acepta" rompe ese flujo.

**Invariante a implementar:** *quien propone la fecha vigente no la resuelve.*

**Sobre cancelar:** no se le quita al propietario. Un propietario que no puede cancelar produce un
no-show, que para el taller es peor que una cancelación con aviso. Lo que se añade es **rastro**.

### Tarea C1 — `idProponente` en el modelo

`ReservaModel` no guarda quién propuso. Sin ese dato la invariante no es computable, y
`reprogramarReserva` (que devuelve el estado a `pendiente`) **invierte** a quién le toca resolver.

- [x] Test de modelo: `fromMap`/`toMap` conservan `id_proponente`; un documento legado sin el campo
      cae en `idPropietario` (comportamiento previo, no rompe nada existente).
- [x] Añadir `idProponente` a `ReservaModel`.
- [x] `ReservaRepository.reprogramarReserva` debe escribir `id_proponente = quien reprograma` junto
      a la fecha y el estado. **Este es el punto que hace que la reprogramación funcione:** si el
      mecánico reprograma, pasa a ser el proponente y le toca al propietario aceptar.
- [x] `flutter test` verde.

### Tarea C2 — Regla de Firestore: transiciones, no solo campos

`firestore.rules:692-699` acota **qué campos** se tocan pero **no quién ni a qué estado**. Cualquiera
de los dos puede escribir `estado: 'confirmada'` desde un cliente modificado. Arreglar solo la UI no
arregla nada.

- [x] En `test_rules/`, tests que fallen: (a) el proponente no puede pasar su propia reserva a
      `confirmada`; (b) la contraparte sí; (c) ambos pueden pasar a `cancelada_por_*` **con su
      propio sufijo** y no con el del otro; (d) reprogramar exige reescribir `id_proponente` con el
      uid propio.
- [x] Extender el `allow update` de `reservas` con esas condiciones. **Añadir `id_proponente` a la
      lista de `affectedKeys` permitidos** — si no, la reprogramación queda denegada por la propia
      regla que la protege. **Nota de ejecución:** la primera versión de esta regla gateaba la
      transición de `estado` mirando si `'estado'` aparecía en `diff().affectedKeys()`, pero
      `diff()` no cuenta un campo como afectado si el valor nuevo es igual al viejo — y reprogramar
      reescribe `estado: 'pendiente'` sobre una reserva que **ya estaba** `'pendiente'`. Eso dejaba
      pasar la reprogramación sin exigir `id_proponente` propio, bypaseando toda la regla. El test
      "reprogramar exige reescribir id_proponente con el uid propio" lo capturó en rojo antes del
      fix; la regla ahora detecta el flujo de reprogramar por `'fecha_hora_propuesta' in
      affectedKeys()` en vez de por `estado`.
- [x] `cd test_rules && npm test` verde (227/227).

### Tarea C3 — UI coherente en las dos pantallas

- [x] Test de widget: `ReservaDetailScreen` en estado `pendiente` con el usuario actual como
      proponente **no** muestra "Aceptar". Debe fallar hoy.
- [x] Aplicar la condición en `reserva_detail_screen.dart:410`, con la misma forma que el chat card.
- [x] "Rechazar" y "Reprogramar" también quedan detrás de la condición.
- [x] Añadir el estado `cancelada_por_propietario` / `cancelada_por_taller` con rastro de autor (vía
      `estadoCancelacionSegunRol`), consumido por el nuevo botón "Cancelar" en ambas pantallas.
      Mapeados en `_statusTypeDe` de **las dos** pantallas junto al `cancelada` plano preexistente,
      que se conserva por compatibilidad con datos/tests legados en vez de eliminarse (no había
      necesidad funcional de borrarlo: nada en la app lo vuelve a escribir).
- [x] **Extraer la decisión** ("¿qué botones ve este uid en este estado?") a una función pura en
      `lib/core/utils/reserva_acciones.dart`, consumida por ambas pantallas.
- [x] Textos a los `.arb` (`chatCancelAppointment`, `chatConfirmCancelAppointment`,
      `chatCancelledStatus`).
- [x] `flutter test` verde (998/998).

**Éxito:** nadie resuelve su propia propuesta desde ninguna de las dos pantallas **ni desde un
cliente modificado**, y el motivo de cancelación queda registrado con autor.

**Commit + `firebase deploy --only firestore:rules`.**

---

## Bloque D — Multi-especialidad (#1)

**Blast radius verificado:** `especialidad` es `String?` en `UserModel:14` y `WorkshopModel:6`, y lo
consumen `admin_talleres_screen.dart` (filtro: 65-67, 493-495, 568), `taller_admin_card.dart:81`,
`mecanico_admin_card.dart:89`, `dashboard_screen.dart:1013`, `workshop_directory_screen.dart:220`,
`estado_verificacion.dart:145` (completitud) y `mechanic_profile_utils.dart:14,26` (gate de perfil).
Más `functions/src/publishTallerProfile.js` (proyección pública) y `reabrirVerificacion.js:33`.

**Objeción de producto que se acepta parcialmente:** sin límite, todo taller marca las 12 y el
filtro del directorio deja de discriminar. Se impone **máximo 4** y una **principal**. La principal
es la que se muestra donde hoy hay una sola línea (tarjetas del admin, directorio) — así el 80% de
la UI no cambia.

### Tarea D1 — Modelo con lista + principal

- [ ] Tests de modelo: `UserModel`/`WorkshopModel` serializan `especialidades: List<String>` y
      `especialidad_principal: String?`; un documento legado con solo `especialidad` se lee como
      lista de un elemento con esa misma como principal (retrocompatible en lectura).
- [ ] Añadir ambos campos, conservando el getter `especialidad` como **deprecated** que devuelve la
      principal. Esto deja compilando a los 8 consumidores mientras se migran uno a uno.
- [ ] `flutter test` verde.

### Tarea D2 — Selector con tope

- [ ] Test de widget: se pueden marcar hasta 4 especialidades; la quinta queda deshabilitada con
      motivo visible; la primera marcada es la principal por defecto y se puede cambiar.
- [ ] Sustituir el `_DropdownField` de "Especialidad" (`workshop_settings_screen.dart:487`) por un
      selector múltiple (`FilterChip` en `Wrap`) + selector de principal entre las marcadas.
- [ ] `estado_verificacion.dart:145` y `mechanic_profile_utils.dart` pasan a exigir
      `especialidades.isNotEmpty` en vez de `especialidad != null`.
- [ ] Textos a los `.arb`.
- [ ] `flutter test` verde.

### Tarea D3 — Consumidores: filtro, búsqueda y proyección pública

- [ ] Test: el filtro del admin por "Frenos" devuelve un taller cuyas especialidades **contienen**
      "Frenos" aunque su principal sea otra.
- [ ] `admin_talleres_screen.dart:65-67`: `t.especialidad != especialidad` → `contains`. El origen
      de opciones (línea 493) pasa a ser la constante `especialidadesTaller`, no los valores
      presentes en los datos — hoy un filtro solo se ofrece si alguien ya lo usó.
- [ ] `workshop_directory_screen.dart:220`: buscar sobre la lista completa.
- [ ] Tarjetas (`taller_admin_card`, `mecanico_admin_card`, `dashboard_screen`): mostrar la
      principal + "+N" cuando hay más. **No listar las cuatro**: rompe el layout de la tarjeta.
- [ ] `publishTallerProfile.js`: añadir `especialidades` y `especialidad_principal` a
      `CAMPOS_PUBLICOS`. **Son públicos por diseño** (el directorio los usa) — a diferencia del
      correo de A2.
- [ ] `flutter test` verde.

**Éxito:** un taller declara hasta 4 especialidades, el filtro las encuentra por cualquiera, y
ninguna pantalla muestra un hueco.

**Commit. El despliegue espera al Bloque G** (migración), o los talleres existentes quedan con lista
vacía y fallan el gate de perfil completo.

---

## Bloque E — Autorización: placa, contacto y fotos de ingreso (#7, #8, #5)

Este bloque no se despliega sin pasar por el subagente `firestore-rules-reviewer`.

### Tarea E1 — Búsqueda por placa determinista (#7, Fase 1)

**El bug que no se diagnosticó bien:** `functions/index.js:1122` hace
`.where('placa','==',placa).limit(1)` **sin `orderBy`**. Firestore ordena por document ID (UUIDs
aleatorios): el vehículo devuelto es **arbitrario y puede cambiar entre búsquedas**. No es "el
primero creado".

- [ ] Test (o prueba manual documentada): con dos vehículos de la misma placa, la búsqueda devuelve
      siempre el mismo, y es el de fecha de registro más antigua.
- [ ] Añadir `.orderBy(...)` al query. **Verificar antes** qué campo de fecha existe realmente en
      los documentos de `vehiculos`; si no hay ninguno, usar el ID como criterio estable y anotarlo.
      Añadir el índice compuesto a `firestore.indexes.json` si hace falta.
- [ ] Cambiar `limit(1)` por `limit(2)` y devolver un flag `duplicado: true` cuando hay más de uno,
      **sin** exponer el segundo vehículo.
- [ ] En `vehicle_search_screen.dart`, avisar cuando llega `duplicado: true`: "hay más de un
      vehículo registrado con esta placa; se muestra el registro más antiguo".

### Tarea E2 — Bloqueo de placa duplicada en el mismo propietario (#7, Fase 1)

Bloqueo intra-propietario, que es el caso que sí es siempre un error. Inter-propietario **solo
advierte**: puede ser una venta legítima.

- [ ] Test de provider: `addVehicle` con una placa que el mismo propietario ya tiene falla con un
      error específico.
- [ ] Chequeo en `VehicleProvider`/`VehicleService` contra los vehículos del propietario (ya están
      en memoria; no requiere query nueva). Mensaje claro nombrando el vehículo que ya la usa.
- [ ] Inter-propietario: **no bloquear**. Registrar el intento en `admin_logs` para tener el dato
      antes de decidir la Fase 2.
- [ ] Textos a los `.arb`.
- [ ] `flutter test` verde.

> **Fuera de alcance, declarado:** colección centinela `placas/{placa}`, transferencia de propiedad
> y flujo de disputa con admin. Requieren un plan propio. Este bloque hace el síntoma determinista y
> recoge datos; **no cierra el agujero**.

### Tarea E3 — Contacto del propietario con gate de relación (#8)

**No** se toca `buscarVehiculoPorPlaca`: sigue sin devolver `id_propietario`
(`functions/index.js:733`). El contacto se resuelve **aparte**, y solo si ya hay relación.

- [ ] Test: un mecánico sin relación con el vehículo recibe `permission-denied`; uno con
      `talleres_vinculados` o con una `reparacion` abierta de su taller recibe nombre y teléfono.
- [ ] Nuevo callable `obtenerContactoPropietarioVehiculo(idVehiculo)` en `functions/index.js`,
      modelado sobre `obtenerUsuariosCompartidos` (línea 1152): exige rol `Mecanico`/`Taller` **y**
      (`talleres_vinculados.hasAny([uid])` **o** existe `reparaciones` abierta de su taller para ese
      vehículo). Devuelve `{nombre, telefono}` — **no** el correo ni el uid.
- [ ] Mostrarlo en `_VehicleHeaderCard` (`initiate_service_screen.dart:1297`), la pantalla donde el
      mecánico ya tiene el ticket abierto. **No** en `vehicle_search_screen`.
- [ ] **No persistir** el contacto en `reparaciones` ni en ningún documento del taller: se resuelve
      en cada carga. Persistirlo es lo que haría que el taller conserve el PII tras perder el
      vínculo.
- [ ] `flutter test` + test de función verdes.

### Tarea E4 — Fotos del estado de ingreso (#5)

**Obstáculo:** `storage.rules`, bloque `vehiculos/{vehicleId}/{allPaths=**}`, tiene
`allow write: if ... && (isVehicleOwner(vehicleId) || isAdmin())`. **El mecánico no puede escribir
ahí.** Y en un walk-in tampoco es `isVinculadoAlVehiculo`, porque el vínculo ahora lo confirma el
propietario (`firestore.rules:490-503`).

**Requisito que no se pidió pero define el diseño:** estas fotos existen para una disputa por daños.
Si solo el taller las sube, solo el taller las ve, y el taller puede sobrescribirlas, **no prueban
nada**. Necesitan ser visibles para el propietario y no sobrescribibles.

- [ ] Tests de reglas que fallen: (a) el mecánico del taller dueño del ticket puede escribir en
      `recepciones/{idReparacion}/{slot}.jpg`; (b) otro mecánico no; (c) el propietario del vehículo
      del ticket **puede leer**; (d) nadie puede sobrescribir un slot ya escrito.
- [ ] Añadir `match /recepciones/{idReparacion}/{fileName}` a `storage.rules`, con `esImagenValida()`
      y nombres de slot fijos (`ingreso-[1-6]`) — mismo patrón y mismo racional que `verificaciones/`
      y `talleres_fotos/`: las reglas de Storage no pueden contar archivos, y fijar los nombres es
      el único tope duro sin contador ni Cloud Function.
- [ ] Autorizar contra `reparaciones/{idReparacion}` (`id_taller`, `id_propietario`), **no** contra
      el vehículo: es lo único que existe en un walk-in.
- [ ] UI en `initiate_service_screen.dart`, tras "Recibir vehículo": grid de slots, cámara/galería,
      previsualización. **Reutilizar el `AppImageViewer` de A1.**
- [ ] Timestamp de servidor en el metadata del objeto; el nombre del slot **no** es la prueba.
- [ ] Hacer las fotos visibles al propietario desde el detalle del servicio.
- [ ] Textos a los `.arb`.
- [ ] `cd test_rules && npm test` + `flutter test` verdes.

**Antes de desplegar: pasar `firestore.rules` y `storage.rules` por `firestore-rules-reviewer`, y
`functions/index.js` por `functions-perf-reviewer` (E1 añade un `orderBy`).**

**Commit + `firebase deploy --only firestore:rules,storage,functions`.**

---

## Bloque F — Cotización, ticket y beneficio (#3, #6)

### Tarea F1 — El vehículo de la cotización deja de fallar en silencio (#3)

**Estado actual:** `chat_screen.dart:811-814` toma el `idVehiculo` de la conversación. Si la
conversación no tiene vehículo, la cotización se crea con `idVehiculo: null` y **nadie se entera**.
`vehiculo_picker.dart` ya existe y ya se usa en el chat para otra cosa.

- [ ] Test: `CotizacionPicker` sin vehículo resoluble no permite enviar.
- [ ] `CotizacionPicker` recibe el vehículo como parámetro obligatorio y lo muestra en la cabecera
      (placa + marca/modelo). Si la conversación no lo tiene, abrir `VehiculoPicker` **antes** del
      formulario, no después.
- [ ] Aplicar en los tres puntos de uso: `chat_screen.dart:802`, `reserva_detail_screen.dart:166`,
      `reserva_chat_card.dart:116`.
- [ ] `flutter test` verde.

### Tarea F2 — Decidir el enganche cotización → ticket (#3, segunda mitad)

**Esto no está definido y no se implementa a ciegas.** Hoy los tickets nacen de
`iniciarReparacionPorVehiculo` (server-side, flujo de placa). Preguntas abiertas:

- ¿El ticket se abre al **enviar** la cotización o al **aceptarla** el propietario?
- ¿Qué pasa si el propietario acepta y nunca llega?
- ¿Se duplica con el ticket del walk-in si el cliente llega sin avisar?

- [ ] **Documentar la decisión antes de escribir código.** Recomendación de partida: el ticket se
      abre **al aceptar**, en estado `pendiente_ingreso`, y `iniciarReparacionPorVehiculo` lo
      **reutiliza** si ya existe para ese vehículo+taller (ya tiene lógica de "abre o reutiliza"),
      en vez de crear uno nuevo.
- [ ] Implementar solo después de esa decisión.

### Tarea F3 — Beneficio visible al mecánico en Iniciar Servicio (#6)

**Lo que ya existe:** `CotizacionItem.beneficio` con doc explícito ("solo debe mostrarse al
mecánico"), guardado en `cotizaciones/{id}/privado/margen` por el hallazgo H2
(`firestore.rules:721-732`), y el `CotizacionPicker` ya lo pide con la etiqueta "solo tú lo ves".

**Lo que falta y es el hallazgo real:** `initiate_service_screen.dart:297-308` calcula
`totalMateriales + manoDeObra` y **no tiene campo de beneficio en absoluto**. Los materiales se
guardan como `{nombre, cantidad, precioUnitario}` (líneas 1058, 1122). El mecánico está a ciegas.

**Lo que NO se hace:** sumar el beneficio al total visible. Con el detalle unitario y el total a la
vista, el cliente deriva el margen por resta.

- [ ] Test: añadir un material con beneficio actualiza el margen del mecánico y **no** cambia el
      total que se le cobra al cliente.
- [ ] Añadir `beneficio` al mapa de material del diálogo
      (`initiate_service_screen.dart:1068-1124`), con la misma etiqueta e icono `visibility_off`
      que usa `CotizacionPicker`. La coherencia visual entre las dos pantallas es lo que le enseña
      al mecánico que ese campo es privado.
- [ ] Nuevo panel bajo el desglose, **solo para el mecánico**: `Total a cobrar` /
      `Tu beneficio estimado` / `Costo real de materiales`. Etiquetado explícitamente como privado.
- [ ] `_updateTotalCost` **no cambia de fórmula**: el total al cliente sigue siendo
      `materiales + mano de obra`.
- [ ] **Persistencia:** el beneficio va a una subcolección privada del servicio, con el mismo patrón
      que `cotizaciones/{id}/privado/margen`. Añadir la regla y su test. **Nunca** en el documento
      de `servicios`, que el propietario lee.
- [ ] Textos a los `.arb`.
- [ ] `cd test_rules && npm test` + `flutter test` verdes.

**Commit + despliegue de reglas.**

---

## Bloque G — Migración de especialidades (solo tras D)

- [ ] Leer `functions/src/reabrirVerificacion.js` completo antes de escribir nada.
- [ ] Crear `functions/src/migrarEspecialidades.js` (one-shot, Admin SDK, mismo patrón que
      `backfillTalleres.js`): para cada `usuarios/{uid}` con rol taller/mecánico y `especialidad`
      no vacía, escribir `especialidades: [especialidad]` y `especialidad_principal: especialidad`.
- [ ] **Crítico:** la migración no debe disparar `reabrirVerificacion`. Como el valor de
      `especialidad` **no cambia** (solo se añaden campos nuevos), el
      `normalizar(previo[campo]) === normalizar(actual[campo])` de la línea 84 debería dejarla
      pasar. **Verificarlo en el emulador antes de correrla en producción** — si no es así, añadir
      un flag de bypass.
- [ ] Ensayo en emulador con al menos un taller aprobado. Confirmar que la bandeja de verificaciones
      sigue vacía después.
- [ ] Correr en producción fuera de horario. Anotar el conteo antes/después.
- [ ] Solo entonces, desplegar el Bloque D.

---

## Orden de ejecución y puntos de despliegue

| Bloque | Despliegue | Tamaño | Dependencias |
|---|---|---|---|
| A — bandeja admin (#2 #10 #11) | hosting | ~1 día | ninguna |
| B — divipola (#9) | hosting | ~1 día | ninguna |
| C — reservas (#4) | rules + hosting | ~2 días | ninguna |
| E1+E2 — placa Fase 1 (#7) | functions | ~1 día | ninguna |
| E3 — contacto con gate (#8) | functions | ~1 día | ninguna |
| E4 — fotos de ingreso (#5) | storage rules | ~3 días | revisor de reglas obligatorio |
| F1 — vehículo en cotización (#3) | hosting | ~1 día | ninguna |
| F2 — decisión de ticket (#3) | nada | ~0.5 día | **bloquea la 2ª mitad de #3** |
| F3 — beneficio (#6) | rules + hosting | ~2 días | ninguna |
| D — multi-especialidad (#1) | espera a G | ~3 días | ⚠ requiere migración |
| G — migración | script one-shot | ~1 día | ⚠ ventana de mantenimiento |

A, B, C, E1, E2, E3, F1 y F3 son **independientes entre sí**: candidatos a
`superpowers:dispatching-parallel-agents` si se ejecutan con agentes.

## Criterios de aceptación global

- [ ] `flutter analyze` limpio.
- [ ] `flutter test` verde, sin tests borrados ni marcados `skip`.
- [ ] `cd test_rules && npm test` verde.
- [ ] `firestore.rules` y `storage.rules` revisados por `firestore-rules-reviewer`.
- [ ] `functions/index.js` revisado por `functions-perf-reviewer`.
- [ ] Ninguna cadena visible fuera de `app_es.arb` / `app_en.arb`.
- [ ] **Ninguna de las tres decisiones de seguridad tocadas queda revertida:**
      - `talleres/{uid}` no gana campos con PII (A2, D3).
      - `buscarVehiculoPorPlaca` sigue sin devolver `id_propietario` (E3).
      - El beneficio del mecánico sigue siendo no derivable desde la vista del cliente (F3).

## Lo que este plan NO hace

Declarado para que no se confunda con un olvido:

- **Unicidad dura de placas, transferencia de propiedad y flujo de disputa** (#7, Fases 2-3).
- **Renderizado embebido de PDF** (A1 abre en el navegador).
- **Rate-limiting / App Check** sobre los callables. Sigue siendo la Fase E, Tarea 14 del plan
  anterior, y es el cierre real de varios de estos vectores (incluido el oráculo de E3).
- **La segunda mitad de #3** (cotización → ticket automático) hasta que F2 defina el flujo.

---

## Anexo — Tareas de seguimiento surgidas al ejecutar el Bloque A

Registradas al cerrar el Bloque A (rama `bloque-a-bandeja-admin`, `388cad9..79ec27a`).
Ninguna bloquea la fusion; todas salieron de revisiones con evidencia y estan
deliberadamente fuera del alcance que ejecutamos.

### S1 — El taller NO puede subir un NIT en PDF por la app (prioridad alta)

`workshop_verification_screen.dart` usa `ImagePicker().pickImage(source: gallery)`, que no
puede seleccionar PDF. `file_picker: ^12.0.0-beta.7` YA esta en `pubspec.yaml:84` pero no se
usa en esa pantalla. Mientras tanto `storage.rules` admite PDF explicitamente para el slot
`nit`, y el Bloque A construyo el manejo de PDF del lado del administrador. El NIT es el
documento mas determinante para aprobar un taller.

**Consecuencia que descubrio la revision final y que hay que tener presente al abordarlo:**
toda la rama PDF del lado del taller es hoy inalcanzable en produccion — `esPdf`, la rama de
icono de la miniatura, la cadena `tallerVerifArchivoPendientePdf` y la rama `url_launcher` de
`_verEvidencia`. El test que la cubre pasa solo porque inyecta un `XFile` que el picker real
nunca puede devolver. **La suite reporta verde sobre un flujo que no se puede ejercer.**
Cuando se aborde esta tarea, ese test debe releerse como NO verificado y esa rama tratarse
como codigo de primera ejecucion, no como codigo ya probado.

### S2 — Consolidar los visores a pantalla completa

El Bloque A creo `lib/core/widgets/app_image_viewer.dart`, pero quedan dos visores ad-hoc
previos: `imagen_chat_card.dart:105` (`Dialog` + `Hero` + boton de cierre) y
`service_history_screen.dart:814`. No es un reemplazo directo: `AppImageViewer` necesita
primero un enganche `Hero` y una variante de presentacion en dialogo.

### S3 — Par de tokens translucido `overlayScrim`

`no_hardcoded_colors_test.dart` mantiene `imagen_chat_card.dart` y `voice_record_button.dart`
fuera de `kTokenizedPaths`. Los tokens `scrim`/`onScrim` que anadio el Bloque A NO los
desbloquean: esos archivos necesitan `Colors.black54`/`black87`, TRANSLUCIDOS, mientras
`AppPalette.lightScrim` es opaco `#0F172A`. Migrarlos tal cual convertiria un HUD
semitransparente en un bloque solido. Hace falta un par translucido aparte.

### S4 — Localizar los mensajes de `VerificacionException` y el resto de la pantalla del taller

El mensaje de rechazo por 5 MB llega a la UI en espanol tambien con locale EN: sale de
`VerificacionService.mensajeArchivoDemasiadoGrande`, que es una cadena en el servicio. No es
regresion (ya salia asi por `provider.error`), pero choca con la restriccion de textos.
Junto a esto quedan sin traducir en `workshop_verification_screen.dart`: `_etiquetas`,
`'opcional'` y `'Solicitud enviada...'`.

### S5 — Partir `workshop_verification_screen.dart`

Paso de 487 a ~700 lineas. La costura ya esta dibujada: `_tarjetaSlot`, `_miniaturaSlot` y
`_descripcionSlot` reciben los mismos cuatro argumentos y no tocan otro estado — son un
`_SlotCard` sin extraer, junto con `_ArchivoPendiente`. Es refactor, no arreglo.

### S6 — Residuales menores de la revision final

- `_abrirPdf` se dispara con `unawaited`, asi que una `PlatformException` de
  `canLaunchUrl`/`launchUrl` escapa a la zona en vez de ser fallo de UI. Un `try/catch` que
  enrute al snackbar `adminVerificacionAbrirDocumentoError` lo cierra.
- La clave `tallerVerifArchivoPendientePdf` se usa ya para imagenes y PDF: el nombre miente.
  Renombrarla a algo neutro de formato.
- Al abrir la bandeja siguen costando dos `getDownloadURL` por documento, porque Firestore
  reemite (cache y luego servidor) y `DocumentoEvidencia` no define `==` por valor. Es el
  lado seguro del Ruling 8 a proposito: darle igualdad por valor halvaria las llamadas pero
  reabriria el escenario de token caducado. El parpadeo en cada accion del admin, que era la
  sustancia del hallazgo, si desaparecio.
- Los cuatro harnesses de test (`chat_`, `entry_`, `mechanic_`, `shell_harness.dart`) rodean
  a mano el problema que el Bloque A ya resolvio al hacer `UserService` inyectable. Se pueden
  simplificar.
