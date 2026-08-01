import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/models/review_model.dart';
import '../../../../core/constants/firestore_collections.dart';

class ReviewService {
  ReviewService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

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
      list.sort((a, b) => b.fechaResenia.compareTo(a.fechaResenia));
      return list;
    });
  }

  /// Busca un servicio ya finalizado del usuario con ese taller que todavía
  /// no haya sido reseñado. Devuelve el id_servicio más reciente disponible,
  /// o null si el usuario no tiene ningún servicio finalizado con ese taller
  /// (o ya reseñó todos).
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
    for (var i = 0; i < vehicleIds.length; i += 30) {
      final chunk = vehicleIds.sublist(
        i,
        i + 30 > vehicleIds.length ? vehicleIds.length : i + 30,
      );
      final serviciosSnap = await _firestore
          .collection(FirestoreCollections.servicios)
          .where('id_vehiculo', whereIn: chunk)
          .get();

      final docs = serviciosSnap.docs.toList()
        ..sort((a, b) {
          final tsA = a.data()['fecha'] as Timestamp?;
          final tsB = b.data()['fecha'] as Timestamp?;
          if (tsA == null || tsB == null) return 0;
          return tsB.compareTo(tsA);
        });

      for (final doc in docs) {
        final docTaller = doc.data()['id_taller'] as String?;
        if (docTaller == tallerId && !reviewedServiceIds.contains(doc.id)) {
          return doc.id;
        }
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

  Future<void> updateReview({
    required String reviewId,
    required String tallerId,
    required int estrellas,
    String? comentario,
  }) async {
    if (estrellas < 1 || estrellas > 5) {
      throw ArgumentError('La calificación debe estar entre 1 y 5 estrellas.');
    }

    final docRef = _resenias.doc(reviewId);

    try {
      await docRef.update({
        'estrellas': estrellas,
        'comentario': comentario?.trim().isEmpty == true
            ? null
            : comentario?.trim(),
        'fecha_resenia': FieldValue.serverTimestamp(),
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
}
