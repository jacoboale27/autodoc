# Reseñas y Calificaciones al 100% — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Llevar el sistema de Reseñas y Calificaciones de AutoDoc del 93.0% al 100%: derecho a réplica del taller, reseñas con fotografías, filtros de ordenamiento, y reportar reseña conectado de extremo a extremo al panel de administración.

**Architecture:** El modelo matemático (promedio/total vía Cloud Function `aggregateRatings`) no se toca. Se extiende `ReviewModel` con dos campos nuevos (`fotos`, `respuestaTaller`) y se corrige una inconsistencia real detectada en `firestore.rules`: la regla de `update` en `resenias` solo permite escribir al autor y solo los campos `['comentario', 'estrellas', 'fecha_resenia']` — pero `ReviewService.reportReview()` ya intenta hacer `update({'is_reported': true})` desde el lado del taller/mecánico (`mechanic_reviews_screen.dart`), lo cual **hoy falla silenciosamente con `permission-denied`** salvo que el que reporta sea el propio autor de la reseña. Este plan corrige esa regla como parte del cierre de "Reportar Reseña", y añade una tercera vía de `update` para que el taller pueda escribir `respuesta_taller` sin poder tocar el resto de la reseña. El ordenamiento pasa de client-side (`list.sort`) a opciones explícitas seleccionables por el usuario, manteniendo el cálculo en cliente (colección pequeña por taller, no amerita índices compuestos nuevos).

**Tech Stack:** Flutter, Provider, Cloud Firestore, Firebase Storage (para fotos de reseña, mismo patrón que `subirImagenChat`).

## Global Constraints

- Campos Firestore en snake_case español (`id_taller`, `is_reported`), modelo `ReviewModel` en camelCase con `fromMap`/`toMap` manuales — no introducir `json_serializable`.
- La colección `resenias` es raíz (no subcolección), con id determinístico `'${idServicio}_$userId'` — no cambiar ese esquema.
- El cliente **nunca** escribe `calificacion_promedio`/`total_resenias` — eso lo hace exclusivamente `aggregateRatings` (Cloud Function, Admin SDK). Ninguna tarea de este plan debe tocar esos campos desde Flutter.
- Cualquier cambio a `firestore.rules` en la sección `match /resenias/{reseniaId}` debe preservar las tres garantías existentes: lectura pública, creación solo por el autor con `isOwnFinishedService(...)`, y que nadie pueda reasignar `id_servicio`/`id_taller`/`id_usuario` vía `update`.
- Reutilizar `ReviewService` (`lib/features/reviews/data/services/review_service.dart`) como único punto de acceso a Firestore para reseñas — no crear un repositorio paralelo.
- Las fotos de reseña se suben a Firebase Storage siguiendo el mismo patrón que `ChatProvider.subirImagenChat` (bytes + `SettableMetadata(contentType: 'image/jpeg')`), bajo una ruta nueva centralizada en `StoragePaths`.

---

## File Structure

- `lib/core/models/review_model.dart` — añadir `fotos` (`List<String>`, default `[]`) y `respuestaTaller` (`Map<String, dynamic>?` con `texto`/`fecha`).
- `lib/core/constants/storage_paths.dart` — añadir `reseniaFotos`.
- `firestore.rules` — corregir la regla `update` de `resenias` para permitir: autor (campos de contenido + fotos), taller (`respuesta_taller`), y cualquier autenticado (`is_reported`, solo para marcar `true`).
- `lib/features/reviews/data/services/review_service.dart` — añadir `responderResenia`, `subirFotosResenia`, extender `submitReview` para aceptar `fotos`.
- `lib/core/widgets/review_sheet.dart` — añadir selector de fotos.
- `lib/features/mechanic/presentation/pages/mechanic_reviews_screen.dart` — añadir UI de respuesta del taller y filtros de ordenamiento.
- `lib/features/admin/presentation/pages/admin_resenias_screen.dart` — añadir filtro "solo reportadas" + badge visual.
- `lib/features/dashboard/presentation/pages/workshop_directory_screen.dart` (o la pantalla de perfil público de taller que liste reseñas individuales, si existe una distinta — confirmar en Task 6) — añadir controles de ordenamiento visibles al usuario final.

---

### Task 1: Extender `ReviewModel` con `fotos` y `respuestaTaller`

**Files:**
- Modify: `lib/core/models/review_model.dart`
- Test: `test/core/models/review_model_test.dart`

**Interfaces:**
- Produces: `ReviewModel.fotos` (`List<String>`, default `const []`), `ReviewModel.respuestaTaller` (`Map<String, dynamic>?` con claves `texto` (`String`) y `fecha` (`DateTime`)).

- [ ] **Step 1: Escribir el test que falla**

```dart
// test/core/models/review_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/models/review_model.dart';

void main() {
  test('fromMap/toMap conservan fotos y respuestaTaller', () {
    final ahora = DateTime(2026, 7, 31, 10, 0);
    final model = ReviewModel(
      idResenia: 'r1',
      idUsuario: 'u1',
      idTaller: 't1',
      idServicio: 's1',
      estrellas: 5,
      comentario: 'Excelente servicio',
      fechaResenia: ahora,
      fotos: const ['https://example.com/foto1.jpg'],
      respuestaTaller: {'texto': 'Gracias por tu confianza', 'fecha': ahora},
    );

    final map = model.toMap();
    expect(map['fotos'], ['https://example.com/foto1.jpg']);
    expect(map['respuesta_taller']['texto'], 'Gracias por tu confianza');

    final restored = ReviewModel.fromMap(map, 'r1');
    expect(restored.fotos, ['https://example.com/foto1.jpg']);
    expect(restored.respuestaTaller?['texto'], 'Gracias por tu confianza');
  });

  test('fotos y respuestaTaller son opcionales (retrocompatibilidad con reseñas antiguas)', () {
    final restored = ReviewModel.fromMap({
      'id_usuario': 'u1',
      'id_taller': 't1',
      'id_servicio': 's1',
      'estrellas': 4,
      'fecha_resenia': null,
    }, 'r2');

    expect(restored.fotos, isEmpty);
    expect(restored.respuestaTaller, isNull);
  });
}
```

- [ ] **Step 2: Ejecutar test y verificar que falla**

Run: `flutter test test/core/models/review_model_test.dart`
Expected: FAIL — `fotos`/`respuestaTaller` no existen en el constructor.

- [ ] **Step 3: Extender el modelo**

```dart
// lib/core/models/review_model.dart
class ReviewModel {
  final String idResenia;
  final String idUsuario;
  final String idTaller;
  final String idServicio;
  final int estrellas;
  final String? comentario;
  final DateTime fechaResenia;
  final bool isReported;
  final List<String> fotos;
  final Map<String, dynamic>? respuestaTaller;

  ReviewModel({
    required this.idResenia,
    required this.idUsuario,
    required this.idTaller,
    required this.idServicio,
    required this.estrellas,
    this.comentario,
    required this.fechaResenia,
    this.isReported = false,
    this.fotos = const [],
    this.respuestaTaller,
  });

  ReviewModel copyWith({
    String? idResenia,
    String? idUsuario,
    String? idTaller,
    String? idServicio,
    int? estrellas,
    String? comentario,
    DateTime? fechaResenia,
    bool? isReported,
    List<String>? fotos,
    Map<String, dynamic>? respuestaTaller,
  }) {
    return ReviewModel(
      idResenia: idResenia ?? this.idResenia,
      idUsuario: idUsuario ?? this.idUsuario,
      idTaller: idTaller ?? this.idTaller,
      idServicio: idServicio ?? this.idServicio,
      estrellas: estrellas ?? this.estrellas,
      comentario: comentario ?? this.comentario,
      fechaResenia: fechaResenia ?? this.fechaResenia,
      isReported: isReported ?? this.isReported,
      fotos: fotos ?? this.fotos,
      respuestaTaller: respuestaTaller ?? this.respuestaTaller,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_resenia': idResenia,
      'id_usuario': idUsuario,
      'id_taller': idTaller,
      'id_servicio': idServicio,
      'estrellas': estrellas,
      'comentario': comentario,
      'fecha_resenia': Timestamp.fromDate(fechaResenia),
      'is_reported': isReported,
      'fotos': fotos,
      if (respuestaTaller != null)
        'respuesta_taller': {
          'texto': respuestaTaller!['texto'],
          'fecha': respuestaTaller!['fecha'] is DateTime
              ? Timestamp.fromDate(respuestaTaller!['fecha'] as DateTime)
              : respuestaTaller!['fecha'],
        },
    };
  }

  factory ReviewModel.fromMap(Map<String, dynamic> map, String documentId) {
    Map<String, dynamic>? parseRespuesta(dynamic v) {
      if (v is! Map) return null;
      final fecha = v['fecha'];
      return {
        'texto': (v['texto'] ?? '').toString(),
        'fecha': fecha is Timestamp ? fecha.toDate() : fecha,
      };
    }

    return ReviewModel(
      idResenia: map['id_resenia'] ?? documentId,
      idUsuario: map['id_usuario'] ?? '',
      idTaller: map['id_taller'] ?? '',
      idServicio: map['id_servicio'] ?? '',
      estrellas: map['estrellas'] ?? 5,
      comentario: map['comentario'],
      fechaResenia:
          (map['fecha_resenia'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isReported: map['is_reported'] ?? false,
      fotos: (map['fotos'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      respuestaTaller: parseRespuesta(map['respuesta_taller']),
    );
  }
}
```

- [ ] **Step 4: Ejecutar test y verificar que pasa**

Run: `flutter test test/core/models/review_model_test.dart`
Expected: PASS

- [ ] **Step 5: Correr la suite completa de reseñas para confirmar que no se rompió nada existente**

Run: `flutter test test/core/models/ test/features/reviews/`
Expected: PASS (incluidos los tests preexistentes de `ReviewModel`/`ReviewService`).

- [ ] **Step 6: Commit**

```bash
git add lib/core/models/review_model.dart test/core/models/review_model_test.dart
git commit -m "feat(reviews): add fotos and respuestaTaller fields to ReviewModel"
```

---

### Task 2: Corregir `firestore.rules` — permitir respuesta del taller y reporte de cualquier autenticado

**Files:**
- Modify: `firestore.rules`

**Interfaces:**
- Produces: regla `update` en `match /resenias/{reseniaId}` con tres ramas independientes (autor, taller, reporte).

- [ ] **Step 1: Leer la regla actual completa (líneas 247-271) y confirmar el bug**

`ReviewService.reportReview()` hace `docRef.update({'is_reported': true})` desde `mechanic_reviews_screen.dart` (el taller, no el autor). La regla actual de `update` exige `resource.data.id_usuario == request.auth.uid` — el taller reportando una reseña de otro usuario **nunca** cumple esa condición, así que hoy esa llamada retorna `permission-denied` en producción (silenciada porque `reportReview` no tiene try/catch que lo muestre al usuario — confirmar y documentar en el PR).

- [ ] **Step 2: Reescribir la regla `update`**

```
// El autor puede corregir su texto, puntuacion, fotos y la marca de tiempo
// de edicion (fecha_resenia, que ReviewService.updateReview siempre
// reescribe); no se permite reasignar id_servicio/id_taller/id_usuario.
//
// El taller dueño de la reseña puede escribir unicamente respuesta_taller
// (derecho a réplica), sin poder tocar el contenido original.
//
// Cualquier usuario autenticado puede marcar is_reported=true (reportar),
// pero no puede usar ese mismo update para tocar ningun otro campo, ni
// puede revertirlo a false (solo el admin puede des-reportar, vía delete
// o mediante el propio panel de moderación que solo expone "eliminar").
allow update: if isAuthenticated() && (
  (resource.data.id_usuario == request.auth.uid
    && request.resource.data.diff(resource.data)
         .affectedKeys().hasOnly(['comentario', 'estrellas', 'fecha_resenia', 'fotos']))
  || (resource.data.id_taller == request.auth.uid
    && request.resource.data.diff(resource.data)
         .affectedKeys().hasOnly(['respuesta_taller']))
  || (request.resource.data.diff(resource.data)
        .affectedKeys().hasOnly(['is_reported'])
      && request.resource.data.is_reported == true)
) || isAdmin();
```

- [ ] **Step 3: Verificar reglas con el emulador**

Run: `firebase emulators:start --only firestore` (si el proyecto tiene tests de reglas con `@firebase/rules-unit-testing`, revisa `test/` en busca de un archivo de reglas existente para seguir el mismo patrón; si no existe infraestructura de test de reglas, verifica manualmente desde la consola del emulador: intenta actualizar `is_reported` como un usuario que no es el autor y confirma que ahora se permite, e intenta actualizar `estrellas` como un usuario que no es el autor y confirma que sigue denegado).

- [ ] **Step 4: Commit**

```bash
git add firestore.rules
git commit -m "fix(reviews): allow workshop replies and third-party reporting on reviews"
```

---

### Task 3: `ReviewService.responderResenia` — derecho a réplica del taller

**Files:**
- Modify: `lib/features/reviews/data/services/review_service.dart`
- Test: `test/features/reviews/data/services/review_service_test.dart`

**Interfaces:**
- Produces: `Future<void> responderResenia({required String reviewId, required String tallerId, required String texto})`.

- [ ] **Step 1: Leer `review_service.dart` completo (ya leído íntegramente en la exploración previa) para seguir el estilo exacto de `updateReview`**

- [ ] **Step 2: Escribir el test que falla**

```dart
// test/features/reviews/data/services/review_service_test.dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/features/reviews/data/services/review_service.dart';
import 'package:autodoc/core/constants/firestore_collections.dart';

void main() {
  test('responderResenia guarda texto y fecha en respuesta_taller', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection(FirestoreCollections.resenias).doc('s1_u1').set({
      'id_usuario': 'u1', 'id_taller': 't1', 'id_servicio': 's1', 'estrellas': 5,
      'fecha_resenia': DateTime.now(),
    });

    final service = ReviewService(firestore: firestore);
    await service.responderResenia(reviewId: 's1_u1', tallerId: 't1', texto: 'Gracias por tu confianza');

    final doc = await firestore.collection(FirestoreCollections.resenias).doc('s1_u1').get();
    expect(doc.data()!['respuesta_taller']['texto'], 'Gracias por tu confianza');
  });

  test('responderResenia rechaza texto vacío', () async {
    final firestore = FakeFirebaseFirestore();
    final service = ReviewService(firestore: firestore);

    expect(
      () => service.responderResenia(reviewId: 's1_u1', tallerId: 't1', texto: '  '),
      throwsArgumentError,
    );
  });
}
```

Nota: si `ReviewService` no acepta hoy `FirebaseFirestore` inyectado (usa `FirebaseFirestore.instance` fijo), añade un constructor `ReviewService({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;` como parte de este mismo Task, siguiendo el patrón ya usado en `AdminRepository`/`ReparacionRepository` de los otros planes — es un cambio no disruptivo (parámetro opcional).

- [ ] **Step 3: Ejecutar test y verificar que falla**

Run: `flutter test test/features/reviews/data/services/review_service_test.dart`
Expected: FAIL — `responderResenia` no existe.

- [ ] **Step 4: Implementar el método**

```dart
// lib/features/reviews/data/services/review_service.dart
Future<void> responderResenia({
  required String reviewId,
  required String tallerId,
  required String texto,
}) async {
  final textoLimpio = texto.trim();
  if (textoLimpio.isEmpty) {
    throw ArgumentError('La respuesta no puede estar vacía.');
  }

  final docRef = _resenias.doc(reviewId);
  try {
    await docRef.update({
      'respuesta_taller': {
        'texto': textoLimpio,
        'fecha': FieldValue.serverTimestamp(),
      },
    });
  } on FirebaseException catch (e) {
    if (e.code == 'permission-denied') {
      throw StateError(
        'No se pudo publicar la respuesta: verifica que esta reseña pertenezca a tu taller.',
      );
    }
    rethrow;
  }
}
```

- [ ] **Step 5: Ejecutar test y verificar que pasa**

Run: `flutter test test/features/reviews/data/services/review_service_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/features/reviews/data/services/review_service.dart test/features/reviews/data/services/review_service_test.dart
git commit -m "feat(reviews): add responderResenia for workshop replies"
```

---

### Task 4: UI — mostrar y crear respuesta del taller en `mechanic_reviews_screen.dart`

**Files:**
- Modify: `lib/features/mechanic/presentation/pages/mechanic_reviews_screen.dart`

**Interfaces:**
- Consumes: `ReviewService.responderResenia` (Task 3), `ReviewModel.respuestaTaller` (Task 1).

- [ ] **Step 1: Leer `mechanic_reviews_screen.dart` completo**

Confirma cómo renderiza hoy cada `ReviewModel` en la lista (tarjeta con estrellas + comentario + botón de reportar ya existente) para insertar la respuesta en el mismo lugar sin romper el layout.

- [ ] **Step 2: Añadir el bloque de respuesta bajo cada reseña**

Debajo del comentario de cada reseña, si `review.respuestaTaller != null`, muestra:

```dart
if (review.respuestaTaller != null)
  Container(
    margin: const EdgeInsets.only(top: 8, left: 16),
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: AppColors.primary.withOpacity(0.08),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Respuesta del taller', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
        const SizedBox(height: 4),
        Text(review.respuestaTaller!['texto'] as String),
      ],
    ),
  )
else
  TextButton.icon(
    icon: const Icon(Icons.reply),
    label: const Text('Responder'),
    onPressed: () => _mostrarDialogoResponder(review),
  ),
```

- [ ] **Step 3: Implementar `_mostrarDialogoResponder`**

```dart
Future<void> _mostrarDialogoResponder(ReviewModel review) async {
  final controller = TextEditingController();
  final texto = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Responder a la reseña'),
      content: TextField(
        controller: controller,
        maxLines: 3,
        maxLength: 300,
        decoration: const InputDecoration(hintText: 'Ej. Gracias por tu confianza...'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('Publicar'),
        ),
      ],
    ),
  );

  if (texto == null || texto.trim().isEmpty) return;

  try {
    await _reviewService.responderResenia(
      reviewId: review.idResenia,
      tallerId: review.idTaller,
      texto: texto,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Respuesta publicada')));
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}
```

Usa la misma instancia `_reviewService`/`ReviewService()` ya presente en la pantalla (confirmar en Step 1 si ya existe un campo `final _reviewService = ReviewService();` para no duplicarlo).

- [ ] **Step 4: Verificar manualmente**

Run: `flutter run -d chrome`, como taller, entra a "Reseñas", responde una reseña, confirma que aparece el bloque de respuesta y que ya no se ofrece el botón "Responder" para esa misma reseña (una sola respuesta por reseña, sin edición en esta iteración).

- [ ] **Step 5: Commit**

```bash
git add lib/features/mechanic/presentation/pages/mechanic_reviews_screen.dart
git commit -m "feat(reviews): show and create workshop replies on mechanic reviews screen"
```

---

### Task 5: Reseñas con fotografías

**Files:**
- Modify: `lib/core/constants/storage_paths.dart`
- Modify: `lib/features/reviews/data/services/review_service.dart`
- Modify: `lib/core/widgets/review_sheet.dart`
- Test: `test/features/reviews/data/services/review_service_fotos_test.dart`

**Interfaces:**
- Produces: `StoragePaths.reseniaFotos` (`'resenia_fotos'`).
- Produces: `Future<List<String>> subirFotosResenia(String idServicio, List<XFile> fotos)` → `Future<List<String>>` (URLs).
- Modifica: `submitReview({..., List<String> fotos = const []})`.

- [ ] **Step 1: Añadir la constante de Storage**

```dart
// lib/core/constants/storage_paths.dart
class StoragePaths {
  static const String perfiles = 'perfiles';
  static const String facturas = 'facturas';
  static const String chatAudios = 'chat_audios'; // si el plan de chat ya corrió, esta línea ya existe
  static const String reseniaFotos = 'resenia_fotos';
}
```

- [ ] **Step 2: Escribir el test de `submitReview` con fotos que falla**

```dart
// test/features/reviews/data/services/review_service_fotos_test.dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/features/reviews/data/services/review_service.dart';
import 'package:autodoc/core/constants/firestore_collections.dart';

void main() {
  test('submitReview persiste la lista de fotos si se provee', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection(FirestoreCollections.servicios).doc('s1').set({
      'id_taller': 't1', 'id_vehiculo': 'v1',
    });
    await firestore.collection(FirestoreCollections.vehiculos).doc('v1').set({
      'id_propietario': 'u1',
    });

    final service = ReviewService(firestore: firestore);
    await service.submitReview(
      userId: 'u1', tallerId: 't1', idServicio: 's1', estrellas: 5,
      fotos: const ['https://example.com/foto1.jpg', 'https://example.com/foto2.jpg'],
    );

    final doc = await firestore.collection(FirestoreCollections.resenias).doc('s1_u1').get();
    expect(doc.data()!['fotos'], ['https://example.com/foto1.jpg', 'https://example.com/foto2.jpg']);
  });
}
```

- [ ] **Step 3: Ejecutar test y verificar que falla**

Run: `flutter test test/features/reviews/data/services/review_service_fotos_test.dart`
Expected: FAIL — `submitReview` no acepta el parámetro `fotos`.

- [ ] **Step 4: Extender `submitReview` y añadir `subirFotosResenia`**

En `submitReview`, añade el parámetro `List<String> fotos = const []` a la firma, e inclúyelo al construir `ReviewModel(...)`:

```dart
Future<void> submitReview({
  required String userId,
  required String tallerId,
  required String idServicio,
  required int estrellas,
  String? comentario,
  List<String> fotos = const [],
}) async {
  // ... (validaciones existentes sin cambios)
  final review = ReviewModel(
    idResenia: docRef.id,
    idUsuario: userId,
    idTaller: tallerId,
    idServicio: idServicio,
    estrellas: estrellas,
    comentario: comentario?.trim().isEmpty == true ? null : comentario?.trim(),
    fechaResenia: DateTime.now(),
    fotos: fotos,
  );
  // ... (resto sin cambios)
}
```

Añade el método de subida, calcado de `ChatProvider.subirImagenChat`:

```dart
Future<List<String>> subirFotosResenia(String idServicio, List<XFile> fotos) async {
  final urls = <String>[];
  for (final foto in fotos) {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${urls.length}.jpg';
    final ref = FirebaseStorage.instance
        .ref()
        .child(StoragePaths.reseniaFotos)
        .child(idServicio)
        .child(fileName);
    final bytes = await foto.readAsBytes();
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    urls.add(await ref.getDownloadURL());
  }
  return urls;
}
```

Añade los imports `package:image_picker/image_picker.dart` y `package:firebase_storage/firebase_storage.dart` y `package:autodoc/core/constants/storage_paths.dart` al inicio de `review_service.dart`.

- [ ] **Step 5: Ejecutar test y verificar que pasa**

Run: `flutter test test/features/reviews/data/services/review_service_fotos_test.dart`
Expected: PASS

- [ ] **Step 6: Añadir selector de fotos en `review_sheet.dart`**

Lee `review_sheet.dart` completo (255 líneas) para insertar, entre el selector de estrellas y el campo de comentario, un `Wrap` de miniaturas + botón "Añadir foto" (`image_picker`, `ImageSource.gallery`, límite razonable de 3 fotos). Al confirmar (`_reviewService.submitReview(...)`), primero sube las fotos seleccionadas con `subirFotosResenia(idServicio, fotosSeleccionadas)` y pasa las URLs resultantes al parámetro `fotos` de `submitReview`.

- [ ] **Step 7: Verificar manualmente**

Run: `flutter run -d chrome`, completa un servicio como taller, deja una reseña desde el lado del propietario adjuntando 1-2 fotos, confirma que se suben y se guardan en el documento de la reseña.

- [ ] **Step 8: Commit**

```bash
git add lib/core/constants/storage_paths.dart lib/features/reviews/data/services/review_service.dart lib/core/widgets/review_sheet.dart test/features/reviews/data/services/review_service_fotos_test.dart
git commit -m "feat(reviews): support photo attachments on reviews"
```

---

### Task 6: Filtros de ordenamiento (Más Recientes / Más Altas / Más Bajas)

**Files:**
- Modify: `lib/features/reviews/data/services/review_service.dart`
- Modify: `lib/features/mechanic/presentation/pages/mechanic_reviews_screen.dart`
- Test: `test/features/reviews/data/services/review_sort_test.dart`

**Interfaces:**
- Produces: `enum ReviewSortOrder { recientes, masAltas, masBajas }` y `List<ReviewModel> ordenarResenias(List<ReviewModel> resenias, ReviewSortOrder orden)` (función pura, testeable).

- [ ] **Step 1: Escribir el test que falla**

```dart
// test/features/reviews/data/services/review_sort_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/models/review_model.dart';
import 'package:autodoc/features/reviews/data/services/review_service.dart';

ReviewModel _r(String id, int estrellas, DateTime fecha) => ReviewModel(
      idResenia: id, idUsuario: 'u', idTaller: 't', idServicio: id,
      estrellas: estrellas, fechaResenia: fecha,
    );

void main() {
  final resenias = [
    _r('a', 3, DateTime(2026, 1, 1)),
    _r('b', 5, DateTime(2026, 6, 1)),
    _r('c', 1, DateTime(2026, 3, 1)),
  ];

  test('recientes ordena por fecha descendente', () {
    final result = ordenarResenias(resenias, ReviewSortOrder.recientes);
    expect(result.map((r) => r.idResenia), ['b', 'c', 'a']);
  });

  test('masAltas ordena por estrellas descendente', () {
    final result = ordenarResenias(resenias, ReviewSortOrder.masAltas);
    expect(result.map((r) => r.idResenia), ['b', 'a', 'c']);
  });

  test('masBajas ordena por estrellas ascendente', () {
    final result = ordenarResenias(resenias, ReviewSortOrder.masBajas);
    expect(result.map((r) => r.idResenia), ['c', 'a', 'b']);
  });
}
```

- [ ] **Step 2: Ejecutar test y verificar que falla**

Run: `flutter test test/features/reviews/data/services/review_sort_test.dart`
Expected: FAIL — `ReviewSortOrder`/`ordenarResenias` no existen.

- [ ] **Step 3: Implementar la función pura**

```dart
// lib/features/reviews/data/services/review_service.dart
enum ReviewSortOrder { recientes, masAltas, masBajas }

List<ReviewModel> ordenarResenias(List<ReviewModel> resenias, ReviewSortOrder orden) {
  final copia = List<ReviewModel>.from(resenias);
  switch (orden) {
    case ReviewSortOrder.recientes:
      copia.sort((a, b) => b.fechaResenia.compareTo(a.fechaResenia));
      break;
    case ReviewSortOrder.masAltas:
      copia.sort((a, b) => b.estrellas.compareTo(a.estrellas));
      break;
    case ReviewSortOrder.masBajas:
      copia.sort((a, b) => a.estrellas.compareTo(b.estrellas));
      break;
  }
  return copia;
}
```

- [ ] **Step 4: Ejecutar test y verificar que pasa**

Run: `flutter test test/features/reviews/data/services/review_sort_test.dart`
Expected: PASS

- [ ] **Step 5: Reemplazar el `list.sort` fijo en `watchReviewsForTaller` por el default `recientes`, manteniendo el ordenamiento seleccionable en la UI**

En `review_service.dart`, dentro de `watchReviewsForTaller`, reemplaza el `list.sort((a, b) => b.fechaResenia.compareTo(a.fechaResenia));` existente por `final ordenado = ordenarResenias(list, ReviewSortOrder.recientes); return ordenado;` — mismo comportamiento por defecto, pero ahora reutiliza la función pura testeada en vez de un `sort` inline.

- [ ] **Step 6: Añadir el control de ordenamiento en la UI**

En `mechanic_reviews_screen.dart` (y en la pantalla de perfil público del taller si existe una vista de reseñas para el usuario final — confirma primero si `workshop_directory_screen.dart` lista reseñas individuales o solo el agregado, según lo reportado en la exploración: "solo muestra el agregado"; si es así, este control solo aplica al lado del taller en esta iteración, ya que no hay pantalla pública de reseñas individuales que extender sin crear una nueva — de ser el caso, documenta esa limitación en el PR y deja la creación de una pantalla pública de reseñas fuera de alcance salvo que el usuario lo pida explícitamente), añade un `DropdownButton<ReviewSortOrder>` con las tres opciones etiquetadas "Más Recientes"/"Más Altas"/"Más Bajas", que mantenga el estado local `_orden` y aplique `ordenarResenias(resenias, _orden)` antes de renderizar la lista.

- [ ] **Step 7: Verificar manualmente**

Run: `flutter run -d chrome`, en la pantalla de reseñas del taller, cambia entre los tres criterios y confirma que el orden de la lista cambia sin recargar de Firestore (todo en memoria sobre los datos ya cargados).

- [ ] **Step 8: Commit**

```bash
git add lib/features/reviews/data/services/review_service.dart lib/features/mechanic/presentation/pages/mechanic_reviews_screen.dart test/features/reviews/data/services/review_sort_test.dart
git commit -m "feat(reviews): add sortable review ordering (recent/highest/lowest)"
```

---

### Task 7: Conectar "Reportar Reseña" al panel de administración

**Files:**
- Modify: `lib/features/admin/presentation/pages/admin_resenias_screen.dart`

**Interfaces:**
- Consumes: `ReviewModel.isReported` (ya existía), `AdminProvider.resenias` (ya existe), regla de Firestore corregida (Task 2).

- [ ] **Step 1: Leer `admin_resenias_screen.dart` completo**

Confirma que hoy lista todas las reseñas sin distinguir `isReported` y que el único control es "eliminar" (según la exploración previa).

- [ ] **Step 2: Añadir filtro "Solo reportadas" y badge visual**

Añade un `SwitchListTile` o `FilterChip` en la parte superior: "Mostrar solo reportadas" (`bool _soloReportadas = false`), que filtre `provider.resenias.where((r) => !_soloReportadas || r.isReported).toList()` antes de renderizar. En cada tarjeta de reseña, si `resenia.isReported == true`, añade un `Chip` visual (ej. `Chip(label: Text('Reportada'), backgroundColor: Colors.red.shade100)`) junto a las estrellas, para que el admin la identifique sin tener que activar el filtro.

- [ ] **Step 3: Verificar manualmente el flujo completo**

Run: `flutter run -d chrome`. Como taller, reporta una reseña desde `mechanic_reviews_screen.dart` (botón de bandera ya existente). Como admin, navega a `/admin/resenias`, activa "Solo reportadas" y confirma que la reseña reportada aparece con el badge, y que "eliminar" (ya existente, `AdminProvider.eliminarResenia`) sigue funcionando sobre ella.

- [ ] **Step 4: Commit**

```bash
git add lib/features/admin/presentation/pages/admin_resenias_screen.dart
git commit -m "feat(reviews): surface reported reviews in admin moderation panel"
```

---

## Self-Review Notes

- **Cobertura del spec**: Derecho a réplica (Tasks 2-4), Reseñas con fotos (Task 5), Filtros de ordenamiento (Task 6), Reportar reseña conectado al admin (Tasks 2, 7). Las 4 features del spec están cubiertas.
- **Decisión documentada**: se corrigió `firestore.rules` (Task 2) porque `reportReview()` ya existía en el código pero estaba **rota en producción** por una regla de seguridad demasiado restrictiva — no es una feature nueva sino un bug de integración pre-existente que bloqueaba "Reportar Reseña" de punta a punta.
- **Riesgo a vigilar en ejecución**: Task 6 Step 6 depende de si existe o no una pantalla pública de reseñas individuales (distinta del agregado en `workshop_directory_screen.dart`) — si el ejecutor descubre que sí existe una pantalla así, extenderla con el mismo control de ordenamiento; si no, el alcance de esta tarea se limita al lado del taller como se documenta.
