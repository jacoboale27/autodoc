import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/models/review_model.dart';
import '../../../../core/constants/firestore_collections.dart';
import '../../../../core/constants/storage_paths.dart';

enum ReviewSortOrder { recientes, masAltas, masBajas }

/// Sube los bytes de una foto de reseña y devuelve su URL de descarga.
///
/// Es un parámetro del servicio, y no una llamada directa a
/// `FirebaseStorage.instance`, por la misma razón que en [GaleriaService]: sin
/// esta costura no hay forma de probar en un test unitario *qué* se sube y
/// *qué* se borra, que es justamente el contrato de esta tarea.
typedef SubidorDeFotoResenia =
    Future<String> Function({
      required String ruta,
      required Uint8List bytes,
      required String contentType,
    });

/// Borra de Storage el objeto al que apunta una URL de descarga.
typedef BorradorDeFotoResenia = Future<void> Function(String url);

/// Función pura y testeable: ordena una lista de reseñas según el criterio
/// dado sin mutar la lista original.
List<ReviewModel> ordenarResenias(
  List<ReviewModel> resenias,
  ReviewSortOrder orden,
) {
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

class ReviewService {
  ReviewService({
    FirebaseFirestore? firestore,
    SubidorDeFotoResenia? subidor,
    BorradorDeFotoResenia? borrador,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _subir = subidor ?? _subirAFirebaseStorage,
       _borrar = borrador ?? _borrarDeFirebaseStorage;

  /// Tope de fotos por reseña. Vive aquí y no en el bottom sheet porque el
  /// límite lo tiene que hacer cumplir el servicio: la UI solo lo refleja.
  static const int maxFotos = 3;

  /// Techo del tope que usa [findReviewableServiceId]. El tope real es
  /// `reseñas previas con ese taller + 1`, casi siempre 1; esta constante solo
  /// impide que crezca sin fin si alguien acumula muchísimas reseñas.
  ///
  /// **No son «50 lecturas».** En un `whereIn` el `limit` se aplica a cada
  /// subconsulta, así que el coste es `tope × tamaño del chunk` (hasta 30). Es
  /// el mismo gap 9.1 que ya se documentó para el tablero. Ver el gap 7.4 de
  /// `docs/evidencia/GAPS-02-drenaje.md`.
  static const int maxServiciosResenables = 50;

  final FirebaseFirestore _firestore;
  final SubidorDeFotoResenia _subir;
  final BorradorDeFotoResenia _borrar;

  CollectionReference<Map<String, dynamic>> get _resenias =>
      _firestore.collection(FirestoreCollections.resenias);

  /// El id del documento de reseña es determinístico (1 reseña por servicio
  /// por usuario), lo que evita reseñas duplicadas para el mismo servicio.
  String _reviewDocId(String userId, String idServicio) =>
      '${idServicio}_$userId';

  Future<ReviewModel?> getUserReviewForService(
    String userId,
    String idServicio,
  ) async {
    final doc = await _resenias.doc(_reviewDocId(userId, idServicio)).get();
    if (!doc.exists) return null;
    return ReviewModel.fromMap(doc.data()!, doc.id);
  }

  Future<List<ReviewModel>> getReviewsForTaller(String tallerId) async {
    final snapshot = await _resenias
        .where('id_taller', isEqualTo: tallerId)
        .get();
    return snapshot.docs
        .map((doc) => ReviewModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  Stream<List<ReviewModel>> watchReviewsForTaller(String tallerId) {
    return _resenias.where('id_taller', isEqualTo: tallerId).snapshots().map((
      snapshot,
    ) {
      final list = snapshot.docs
          .map((doc) => ReviewModel.fromMap(doc.data(), doc.id))
          .toList();
      return ordenarResenias(list, ReviewSortOrder.recientes);
    });
  }

  /// Busca un servicio ya finalizado del usuario con ese taller que todavía
  /// no haya sido reseñado. Devuelve el id_servicio más reciente disponible,
  /// o null si el usuario no tiene ningún servicio finalizado con ese taller
  /// (o ya reseñó todos).
  ///
  /// Sólo mira los más recientes de ese taller por tanda de vehículos: tantos
  /// como reseñas previas haya con él, más uno (ver [maxServiciosResenables]).
  /// Un propietario que superase las [maxServiciosResenables] visitas reseñadas
  /// al mismo taller dejaría de ver ofrecidas las más antiguas, que es un caso
  /// que no se da y cuyo coste alternativo es leer todo su historial en cada
  /// apertura de la ficha.
  Future<String?> findReviewableServiceId(
    String userId,
    String tallerId,
  ) async {
    final vehicleSnap = await _firestore
        .collection(FirestoreCollections.vehiculos)
        .where('id_propietario', isEqualTo: userId)
        .get();
    final vehicleIds = vehicleSnap.docs.map((d) => d.id).toList();
    if (vehicleIds.isEmpty) return null;

    final reviewedSnap = await _resenias
        .where('id_usuario', isEqualTo: userId)
        .where('id_taller', isEqualTo: tallerId)
        .get();
    final reviewedServiceIds = reviewedSnap.docs
        .map((d) => d.data()['id_servicio'] as String?)
        .whereType<String>()
        .toSet();

    // Firestore 'whereIn' admite máximo 30 valores por consulta.
    final tandas = <List<String>>[];
    for (var i = 0; i < vehicleIds.length; i += 30) {
      tandas.add(
        vehicleIds.sublist(
          i,
          i + 30 > vehicleIds.length ? vehicleIds.length : i + 30,
        ),
      );
    }

    // Cada tanda aporta SU candidato; el que se devuelve es el más reciente de
    // todos. Antes se devolvía el primero de la primera tanda que tuviera
    // alguno: dentro de una tanda el orden lo pone el servidor, pero **entre
    // tandas no hay orden ninguno**, así que con más de 30 vehículos la
    // función ofrecía reseñar un servicio viejo teniendo uno nuevo sin
    // reseñar. Hasta 30 vehículos hay una sola tanda, y por eso no se veía.
    //
    // Las tandas van en paralelo: son consultas independientes y el número de
    // lecturas es el mismo, así que serializarlas solo añadía latencia.
    QueryDocumentSnapshot<Map<String, dynamic>>? mejor;
    final resultados = await Future.wait(
      tandas.map(
        (chunk) => _candidatoDeTanda(chunk, tallerId, reviewedServiceIds),
      ),
    );
    for (final candidato in resultados) {
      if (candidato == null) continue;
      if (mejor == null || _fechaDe(candidato).isAfter(_fechaDe(mejor!))) {
        mejor = candidato;
      }
    }
    return mejor?.id;
  }

  static DateTime _fechaDe(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final fecha = doc.data()['fecha'];
    return fecha is Timestamp ? fecha.toDate() : DateTime(0);
  }

  /// El servicio sin reseñar más reciente de una tanda de vehículos, o null.
  Future<QueryDocumentSnapshot<Map<String, dynamic>>?> _candidatoDeTanda(
    List<String> chunk,
    String tallerId,
    Set<String> reviewedServiceIds,
  ) async {
    // El filtro por taller va en el SERVIDOR, no en memoria (gap 7.4 de
    // `GAPS-02-drenaje.md`). Antes esta consulta no tenia ni `id_taller` ni
    // `limit`: traia el historial COMPLETO de servicios del propietario —de
    // todos los talleres, de toda la vida de la cuenta— lo ordenaba en
    // memoria y devolvia como mucho un id. El conjunto pasa a ser "sus
    // servicios con ESTE taller", que es lo unico que la funcion mira.
    //
    // El `orderBy` tambien se baja al servidor: sin el, un `limit` recorta
    // por `__name__` y el tope se llevaria documentos arbitrarios en vez de
    // los mas recientes, que es el defecto que arreglo el tablero Kanban.
    //
    // El tope se calcula, no es fijo, y la razon es el gap 9.1: en un
    // `whereIn` el `limit` se aplica a **cada subconsulta** antes de mezclar,
    // asi que un `limit(50)` con 30 vehiculos lee hasta 1500 documentos para
    // devolver un id. Como lo unico que busca el bucle es el PRIMERO no
    // resenado, y los resenados ya estan en memoria, basta con pedir
    // `resenadas + 1`: entre los `k + 1` mas recientes no pueden estar
    // resenados los `k + 1`. Con el caso normal (ninguna resena previa con
    // ese taller) eso es `limit(1)`.
    final tope = reviewedServiceIds.length + 1 > maxServiciosResenables
        ? maxServiciosResenables
        : reviewedServiceIds.length + 1;
    final serviciosSnap = await _firestore
        .collection(FirestoreCollections.servicios)
        .where('id_vehiculo', whereIn: chunk)
        .where('id_taller', isEqualTo: tallerId)
        .orderBy('fecha', descending: true)
        .limit(tope)
        .get();

    for (final doc in serviciosSnap.docs) {
      if (!reviewedServiceIds.contains(doc.id)) {
        return doc;
      }
    }
    return null;
  }

  Future<void> submitReview({
    required String userId,
    required String tallerId,
    required String idServicio,
    required int estrellas,
    String? comentario,
    List<String> fotos = const [],
  }) async {
    if (estrellas < 1 || estrellas > 5) {
      throw ArgumentError('La calificación debe estar entre 1 y 5 estrellas.');
    }

    final servicioDoc = await _firestore
        .collection(FirestoreCollections.servicios)
        .doc(idServicio)
        .get();
    if (!servicioDoc.exists) {
      throw StateError(
        'No se encontró el servicio. Solo puedes reseñar servicios finalizados.',
      );
    }
    final servicioData = servicioDoc.data()!;
    if (servicioData['id_taller'] != tallerId) {
      throw StateError('Este servicio no corresponde a este taller.');
    }

    final idVehiculo = servicioData['id_vehiculo'] as String?;
    final vehiculoDoc = idVehiculo == null
        ? null
        : await _firestore
              .collection(FirestoreCollections.vehiculos)
              .doc(idVehiculo)
              .get();
    if (vehiculoDoc == null ||
        !vehiculoDoc.exists ||
        vehiculoDoc.data()?['id_propietario'] != userId) {
      throw StateError(
        'Solo puedes reseñar servicios realizados a tus propios vehículos.',
      );
    }

    final docRef = _resenias.doc(_reviewDocId(userId, idServicio));
    final existing = await docRef.get();
    if (existing.exists) {
      throw StateError('Ya dejaste una reseña para este servicio.');
    }

    final review = ReviewModel(
      idResenia: docRef.id,
      idUsuario: userId,
      idTaller: tallerId,
      idServicio: idServicio,
      estrellas: estrellas,
      comentario: comentario?.trim().isEmpty == true
          ? null
          : comentario?.trim(),
      fechaResenia: DateTime.now(),
      fotos: fotos,
    );

    try {
      await docRef.set(review.toMap());
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw StateError(
          'No se pudo guardar la reseña. Asegúrate de que el servicio '
          'corresponde a un vehículo tuyo y que las reglas de seguridad '
          'estén actualizadas.',
        );
      }
      rethrow;
    }
    // La recalculación de calificacion_promedio/total_resenias la hace
    // exclusivamente la Cloud Function aggregateRatings (trigger onWrite de
    // resenias, escribe en 'usuarios' con Admin SDK). El cliente ya no debe
    // ni puede escribirlas: firestore.rules excluye esos campos de lo que
    // isOwner puede tocar en 'usuarios' (ver Task 13 / cierre del merge).
  }

  /// Edita una reseña existente. Devuelve la lista final de URLs de fotos, o
  /// `null` si la llamada no pidió tocarlas (ver [fotosConservadas]): devolver
  /// una lista vacía en ese caso sería indistinguible de «se borraron todas».
  ///
  /// El contrato de fotos es **explícito**, que es el defecto que cierra
  /// FUNC-01: antes esta función no mencionaba `fotos`, así que la única
  /// forma de que editar no las descartara en silencio era esconder el
  /// selector de fotos en modo edición.
  ///
  /// - [fotosConservadas] `null` significa «no toques las fotos» y mantiene
  ///   compatible al llamador que solo corrige texto o estrellas.
  /// - Una lista (aunque sea vacía) significa «la reseña se queda exactamente
  ///   con estas, más las de [fotosNuevas]». Lo que estaba y no aparece ahí es
  ///   un borrado deliberado.
  ///
  /// Solo se aceptan URLs que ya estuvieran en el documento: sin ese chequeo
  /// el llamador podría inyectar en `fotos` cualquier URL arbitraria, que las
  /// reglas de Firestore no pueden distinguir de una legítima (para ellas
  /// `fotos` es una lista de cadenas editable por el autor).
  Future<List<String>?> updateReview({
    required String reviewId,
    required String tallerId,
    required int estrellas,
    String? comentario,
    List<String>? fotosConservadas,
    List<XFile> fotosNuevas = const [],
  }) async {
    if (estrellas < 1 || estrellas > 5) {
      throw ArgumentError('La calificación debe estar entre 1 y 5 estrellas.');
    }

    final docRef = _resenias.doc(reviewId);
    final editaFotos = fotosConservadas != null || fotosNuevas.isNotEmpty;

    List<String> conservadas = const [];
    List<String> huerfanas = const [];
    var fotosFinales = <String>[];

    if (editaFotos) {
      final snapshot = await docRef.get();
      if (!snapshot.exists) {
        throw StateError('La reseña que intentas editar ya no existe.');
      }
      final data = snapshot.data()!;
      final fotosActuales = (data['fotos'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList();
      conservadas = fotosConservadas ?? fotosActuales;

      final ajenas = conservadas.where((u) => !fotosActuales.contains(u));
      if (ajenas.isNotEmpty) {
        throw StateError(
          'No se pueden añadir fotos que no pertenecen a esta reseña.',
        );
      }
      if (conservadas.length + fotosNuevas.length > maxFotos) {
        throw ArgumentError('Una reseña admite como máximo $maxFotos fotos.');
      }

      final idServicio = (data['id_servicio'] ?? '').toString();
      if (idServicio.isEmpty) {
        throw StateError('La reseña no referencia ningún servicio.');
      }

      // Storage primero, igual que GaleriaService.subirFoto: si una subida
      // falla, el documento no queda anunciando una foto inexistente. El fallo
      // en el orden contrario —objeto subido, Firestore sin actualizar— deja un
      // huérfano invisible, que es el mal menor y se corrige reintentando.
      final subidas = fotosNuevas.isEmpty
          ? const <String>[]
          : await subirFotosResenia(idServicio, fotosNuevas);

      fotosFinales = [...conservadas, ...subidas];
      huerfanas = fotosActuales.where((u) => !conservadas.contains(u)).toList();
    }

    try {
      await docRef.update({
        'estrellas': estrellas,
        'comentario': comentario?.trim().isEmpty == true
            ? null
            : comentario?.trim(),
        'fecha_resenia': FieldValue.serverTimestamp(),
        if (editaFotos) 'fotos': fotosFinales,
      });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw StateError(
          'No se pudo actualizar la reseña: no tienes permiso para editarla '
          '(puede que se haya creado con otra cuenta).',
        );
      }
      rethrow;
    }
    // aggregateRatings (Cloud Function) recalcula el promedio en el backend.

    // Los objetos huérfanos se borran DESPUÉS de que Firestore confirme, y
    // nunca antes: si la escritura falla, la reseña sigue apuntando a esas
    // fotos y borrarlas la dejaría rota. Los fallos del borrado se ignoran —
    // que el objeto ya no esté es el estado que se buscaba— para que la
    // operación sea idempotente y reintentable.
    for (final url in huerfanas) {
      try {
        await _borrar(url);
      } catch (_) {}
    }

    return editaFotos ? fotosFinales : null;
  }

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

  Future<void> reportReview(String reviewId) async {
    final docRef = _resenias.doc(reviewId);
    await docRef.update({'is_reported': true});
  }

  Future<List<String>> subirFotosResenia(
    String idServicio,
    List<XFile> fotos,
  ) async {
    final urls = <String>[];
    for (final foto in fotos) {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${urls.length}.jpg';
      final ruta = '${StoragePaths.reseniaFotos}/$idServicio/$fileName';
      final bytes = await foto.readAsBytes();
      urls.add(
        await _subir(ruta: ruta, bytes: bytes, contentType: 'image/jpeg'),
      );
    }
    return urls;
  }

  static Future<String> _subirAFirebaseStorage({
    required String ruta,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final ref = FirebaseStorage.instance.ref().child(ruta);
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    return ref.getDownloadURL();
  }

  /// El documento guarda URLs de descarga, no rutas, así que el borrado parte
  /// de la URL: `refFromURL` la traduce de vuelta al objeto.
  static Future<void> _borrarDeFirebaseStorage(String url) =>
      FirebaseStorage.instance.refFromURL(url).delete();
}
