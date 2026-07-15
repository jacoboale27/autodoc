import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/models/review_model.dart';
import '../../../../core/constants/firestore_collections.dart';

class ReviewService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _resenias =>
      _firestore.collection(FirestoreCollections.resenias);

  Future<bool> hasUserReviewedTaller(String userId, String tallerId) async {
    final snapshot = await _resenias
        .where('id_usuario', isEqualTo: userId)
        .where('id_taller', isEqualTo: tallerId)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  Future<ReviewModel?> getUserReviewForTaller(String userId, String tallerId) async {
    final snapshot = await _resenias
        .where('id_usuario', isEqualTo: userId)
        .where('id_taller', isEqualTo: tallerId)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return ReviewModel.fromMap(snapshot.docs.first.data(), snapshot.docs.first.id);
  }

  Future<List<ReviewModel>> getReviewsForTaller(String tallerId) async {
    final snapshot =
        await _resenias.where('id_taller', isEqualTo: tallerId).get();
    return snapshot.docs
        .map((doc) => ReviewModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  Stream<List<ReviewModel>> watchReviewsForTaller(String tallerId) {
    return _resenias.where('id_taller', isEqualTo: tallerId).snapshots().map(
      (snapshot) {
        final list = snapshot.docs
            .map((doc) => ReviewModel.fromMap(doc.data(), doc.id))
            .toList();
        list.sort((a, b) => b.fechaResenia.compareTo(a.fechaResenia));
        return list;
      },
    );
  }

  Future<void> submitReview({
    required String userId,
    required String tallerId,
    required int estrellas,
    String? comentario,
    String? idServicio,
  }) async {
    if (estrellas < 1 || estrellas > 5) {
      throw ArgumentError('La calificación debe estar entre 1 y 5 estrellas.');
    }

    final existing = await hasUserReviewedTaller(userId, tallerId);
    if (existing) {
      throw StateError('Ya dejaste una reseña para este taller.');
    }

    final docRef = _resenias.doc();
    final review = ReviewModel(
      idResenia: docRef.id,
      idUsuario: userId,
      idTaller: tallerId,
      estrellas: estrellas,
      comentario: comentario?.trim().isEmpty == true ? null : comentario?.trim(),
      fechaResenia: DateTime.now(),
    );

    final data = review.toMap();
    if (idServicio != null) {
      data['id_servicio'] = idServicio;
    }

    await docRef.set(data);
    await recalculateTallerRating(tallerId);
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
    
    await docRef.update({
      'estrellas': estrellas,
      'comentario': comentario?.trim().isEmpty == true ? null : comentario?.trim(),
      'fecha_resenia': FieldValue.serverTimestamp(),
    });

    await recalculateTallerRating(tallerId);
  }

  Future<void> recalculateTallerRating(String tallerId) async {
    final reviews = await getReviewsForTaller(tallerId);
    final total = reviews.length;
    final promedio = total == 0
        ? 0.0
        : reviews.map((r) => r.estrellas).reduce((a, b) => a + b) / total;

    await _firestore.collection(FirestoreCollections.talleres).doc(tallerId).update({
      'calificacion_promedio': double.parse(promedio.toStringAsFixed(1)),
      'total_resenias': total,
    });
  }
}
