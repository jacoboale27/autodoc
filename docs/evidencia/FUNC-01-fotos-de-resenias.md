# FUNC-01 — Edición completa de reseñas con fotos

**Plan:** `docs/superpowers/plans/2026-09-06-remediation-master-plan-crea-j-10-10.md` §7 (P2).
**Rama:** `fix/func01`, cortada de `integracion/ola-1`.
**Fecha:** 2026-09-10.
**Evidence IDs:** `EVID-FUNC-020..024`.

---

## 1. Qué estaba roto, y por qué no era lo que decía el enunciado

El plan lo describe como «la edición de reseña descarta fotos». La foto no se descartaba: el
sheet **escondía el selector en modo edición** precisamente para que no se pudiera descartar
nada, con un comentario que lo explicaba (`review_sheet.dart`, bloque
`if (_existingReview == null)`). El defecto real era el de más abajo en la pila:

- **`ReviewService.updateReview` no mencionaba `fotos`.** Actualizaba `estrellas`, `comentario`
  y `fecha_resenia` y nada más. No había forma de añadir, quitar ni reemplazar una foto después
  de publicar la reseña. Esconder el selector era la mitigación honesta de esa carencia, no el
  bug.
- **`storage.rules` no dejaba al autor borrar sus propias fotos** (`allow delete: if isAdmin()`).
  Aunque el servicio hubiera querido limpiar un objeto huérfano, habría muerto en
  `permission-denied`. **Sin este cambio, la tarea no se podía cerrar de verdad**: cada foto
  retirada se quedaba para siempre en Storage, pagando cuota y legible por su URL para cualquier
  autenticado.
- **`subirFotosResenia` llamaba a `FirebaseStorage.instance` directamente**, así que no había
  ninguna forma de probar en un test unitario *qué* se sube y *qué* se borra — que es justo el
  contrato de esta tarea.

## 2. Hallazgo colateral: `fotos` era una URL arbitraria en un documento de lectura anónima

Lo destapó el gate del subagente `firestore-rules-reviewer`, y es el hallazgo con más
consecuencias de la tarea.

`resenias` tiene `allow read: if true` — lectura **anónima**, alimenta el directorio público de
talleres y la landing. La rama del autor del `allow update` permitía `fotos` sin validar su
contenido. Hasta FUNC-01 eso era teórico porque el cliente nunca escribía `fotos` en un update;
**FUNC-01 es exactamente el cambio que lo vuelve alcanzable**: ahora el cliente reescribe la
lista entera al editar.

El ataque: un `Propietario` cualquiera con una reseña legítima escribe
`fotos: ["https://atacante.tld/px.png?r=r1"]`. Pasa el `hasOnly`, pasa `id_usuario == uid`. A
partir de ahí, el navegador de **todo el que abra la ficha del taller, incluido el visitante
anónimo**, descarga esa URL: cosecha de IP y User-Agent servida por un tercero. Es letra por
letra la amenaza que ya motivó `esUrlDeStoragePropia` para `foto_perfil_url`
(`firestore.rules:203-228`), aquí con más audiencia. De paso, no había ningún tope de tamaño:
se podía escribir una lista de miles de elementos en un documento público.

Se cierra con `fotosBajoServicio(fotos, idServicio)`, análogo al helper de perfil: ancla el host
de Firebase Storage y el prefijo `resenia_fotos%2F{idServicio}%2F`, y limita a 3 (el
`ReviewService.maxFotos`). Aplicado al `create` y al `update`.

**Detalle que no es opcional:** en un update `request.resource.data` es el documento
*resultante*, así que validar siempre dejaría **ineditables** las reseñas ya publicadas con URLs
heredadas — ni siquiera para corregir el texto. Por eso `fotosDeReseniaValidasEnUpdate()` valida
solo si `fotos` está en `affectedKeys()`. Hay un test que lo fija.

## 3. El contrato nuevo

```dart
Future<List<String>?> updateReview({
  required String reviewId,
  required String tallerId,
  required int estrellas,
  String? comentario,
  List<String>? fotosConservadas,
  List<XFile> fotosNuevas = const [],
})
```

- `fotosConservadas == null` → «no toques las fotos». Mantiene compatible al llamador que solo
  corrige texto. Devuelve `null`, no `[]`: una lista vacía sería indistinguible de «se borraron
  todas».
- Una lista → la reseña se queda **exactamente** con esas, más las de `fotosNuevas`. Lo que
  estaba y no aparece es un borrado deliberado.
- Solo se aceptan URLs que ya estaban en el documento. Sin ese chequeo el llamador podría
  inyectar cualquier URL, que las reglas ya no aceptarían, pero el servicio tampoco debe
  intentarlo.

**Orden de las operaciones**, copiado de `GaleriaService` porque el razonamiento es el mismo:
Storage primero al subir (si falla, el documento no anuncia una foto inexistente); Firestore
primero al borrar, y los huérfanos **después** de que Firestore confirme. Si la escritura
fallara y se hubiera borrado antes, la reseña quedaría apuntando a objetos que ya no existen.
Los fallos del borrado se tragan (`catch (_)`) para que la operación sea idempotente: que el
objeto ya no esté es el estado que se buscaba.

Storage se inyecta con dos typedefs (`SubidorDeFotoResenia`, `BorradorDeFotoResenia`), misma
costura que `GaleriaService`. El borrado parte de la **URL**, no de una ruta, porque es lo que
guarda el documento: `refFromURL` la traduce de vuelta al objeto.

## 4. Cambios

| Archivo | Qué |
|---|---|
| `lib/features/reviews/data/services/review_service.dart` | Contrato de fotos en `updateReview`; costura de Storage; `maxFotos` |
| `lib/core/widgets/review_sheet.dart` | Selector visible al editar; fotos publicadas con quitar; `reviewService`/`selectorDeFoto` inyectables |
| `storage.rules` | `resenia_fotos`: el autor borra lo suyo |
| `firestore.rules` | `fotosBajoServicio` + `fotosDeReseniaValidasEnUpdate`, aplicados a create y update de `resenias` |
| `test/features/reviews/data/services/review_service_fotos_test.dart` | 10 casos de servicio |
| `test/core/widgets/review_sheet_test.dart` | 5 casos de widget (nuevo) |
| `test_rules/storage.test.js` | +6 casos de borrado |
| `test_rules/talleres-publico.test.js` | +7 casos de `fotos` |

## 5. Resultados

| Gate | Antes | Después |
|---|---|---|
| `flutter analyze` | limpio | **`No issues found!`** |
| `flutter test` | 1150 | **1164 / 1164**, exit 0 |
| `test_rules` (`npm test`) | 415 en 24 suites | **426 / 426**, 24 suites, exit 0 |
| `functions` (Mocha) | 173 | **173**, sin tocar |

Los tests se vieron **fallar antes** de cada implementación: los de servicio y widget en
compilación (el contrato no existía); `el propietario del servicio SI puede borrar su propia
foto` contra la regla vieja; y los cuatro negativos de `fotos` (`servidor externo`, `carpeta de
otro servicio`, `mas de 3`, `CREAR con foto externa`) contra `firestore.rules` sin el helper.

## 6. Lo que este trabajo NO cierra

Tres cosas que el revisor de reglas señaló y que se dejan abiertas a propósito, con su razón:

1. **Vehículo fantasma (BAJO).** `vehiculos` permite `create` con ID elegido por el cliente
   (`firestore.rules:525`). Si la víctima borra su vehículo, `onVehicleDelete` borra sus
   servicios de forma **asíncrona**; mientras el documento de `servicios` sobreviva y el de
   `vehiculos` no exista, un taller que conozca el `id_vehiculo` puede recrearlo a su nombre y
   pasar `esPropietarioDelServicio`. Antes eso ya le daba **subir**; ahora le daría además
   **borrar**. El endurecimiento limpio es atar el objeto a quien lo subió
   (`fileName.matches('^' + request.auth.uid + '_')`), pero eso deja **inborrables para su
   autor** todas las fotos ya subidas con el nombre viejo `<millis>_<n>.jpg`: es una migración,
   no un ajuste, y no se mete a última hora en una tarea P2. **Queda anotado como residual.**
2. **Huérfanos al ELIMINAR una reseña (BAJO, higiene).** Nadie borra las fotos cuando se borra
   la reseña: ni `AdminRepository.deleteResenia`, ni la limpieza de cuenta de
   `functions/index.js`, ni `onVehicleDelete`. FUNC-01 va de **editar**, no de eliminar. El sitio
   correcto es un trigger `onDelete` de `resenias` con Admin SDK, que bypasea reglas — candidato
   natural para OPS-01.
3. **Asimetría Firestore/Storage.** Firestore autoriza el update por `resource.data.id_usuario`;
   Storage por propiedad *actual* del vehículo. Divergen solo si el vehículo o el servicio dejan
   de existir: entonces el autor puede seguir editando el documento pero ningún borrado en
   Storage le será concedido. El sentido peligroso —borrar el objeto sin poder editar el
   documento— no es alcanzable. Queda fijado por el test `si el servicio ya no existe, ni el ex
   propietario puede borrar`.

## 7. Nota sobre los tests, y la cicatriz que evitan

El revisor detectó que el negativo `otro usuario NO puede borrar` **no discriminaba**: `owner2`
no tenía ningún vehículo, así que el test habría pasado con una regla tan floja como «es
propietario de cualquier vehículo». Es literalmente la enfermedad de ROLE-01. Corregido: `owner2`
tiene ahora su propio `v2`/`s2`, y se afirma que aun así falla borrando en `resenia_fotos/s1/`.
Eso sí ata el `{idServicio}` de la ruta al documento resuelto.

El test de widget sustituye **solo** el canal de plataforma de `image_picker` (vía
`SelectorDeFotoResenia`, misma costura que `SelectorDeArchivo` en la pantalla de verificación) y
el servicio. Todo lo demás —`_pickFoto`, `_submit`, el estado de fotos publicadas— es el código
real. El fake `implements ReviewService`, así que un cambio de firma lo rompe en compilación en
vez de dejar pasar un verde vacío.
