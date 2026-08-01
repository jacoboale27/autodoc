import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/models/workshop_model.dart';
import '../../../../core/models/review_model.dart';
import '../../../../core/models/admin_log_model.dart';
import '../../../../core/constants/firestore_collections.dart';

class AdminRepository {
  final FirebaseFirestore? _firestoreOverride;

  /// Se resuelve de forma perezosa (no en el constructor) para no forzar
  /// `FirebaseFirestore.instance` -y por tanto `Firebase.initializeApp()`-
  /// en tests que no pasan un `firestore` explícito.
  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  AdminRepository({FirebaseFirestore? firestore})
    : _firestoreOverride = firestore;

  // Usuarios
  Future<List<UserModel>> getUsuarios({int limit = 100}) async {
    final snapshot = await _firestore
        .collection(FirestoreCollections.usuarios)
        .limit(limit)
        .get();
    return snapshot.docs
        .map((doc) => UserModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<void> updateUsuarioEstado(String uid, String nuevoEstado) async {
    await _firestore.collection(FirestoreCollections.usuarios).doc(uid).update({
      'estado': nuevoEstado,
    });
  }

  Future<void> updateUsuarioRol(String uid, String nuevoRol) async {
    await _firestore.collection(FirestoreCollections.usuarios).doc(uid).update({
      'rol': nuevoRol,
    });
  }

  Future<void> deleteUsuario(String uid) async {
    await _firestore
        .collection(FirestoreCollections.usuarios)
        .doc(uid)
        .delete();
  }

  // Talleres
  Future<List<WorkshopModel>> getTalleres({int limit = 100}) async {
    final snapshot = await _firestore
        .collection(FirestoreCollections.talleres)
        .limit(limit)
        .get();
    return snapshot.docs
        .map((doc) => WorkshopModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<void> updateTallerEstado(String idTaller, String nuevoEstado) async {
    await _firestore
        .collection(FirestoreCollections.talleres)
        .doc(idTaller)
        .update({'estado': nuevoEstado});
  }

  Future<void> deleteTaller(String idTaller) async {
    await _firestore
        .collection(FirestoreCollections.talleres)
        .doc(idTaller)
        .delete();
  }

  // Moderación genérica (usuarios y talleres comparten el campo `estado`)
  /// Suspende cualquier cuenta (usuario o taller) marcando `estado =
  /// 'suspendido'` en la colección indicada. `motivo` no se persiste en el
  /// documento (solo se usa para el log de auditoría, responsabilidad de la
  /// capa de servicio); se mantiene como parámetro requerido para que la
  /// firma documente la intención de la llamada.
  Future<void> suspenderCuenta({
    required String coleccion,
    required String docId,
    required String motivo,
  }) async {
    await _firestore.collection(coleccion).doc(docId).update({
      'estado': 'suspendido',
    });
  }

  /// Reactiva cualquier cuenta (usuario o taller) marcando `estado` de
  /// vuelta al valor "activo" de esa colección. Usuarios usa `'activo'`;
  /// talleres usa `'aprobado'` (ver `AdminService.reactivarTaller`), de ahí
  /// el parámetro `estadoActivo`.
  Future<void> reactivarCuenta({
    required String coleccion,
    required String docId,
    String estadoActivo = 'activo',
  }) async {
    await _firestore.collection(coleccion).doc(docId).update({
      'estado': estadoActivo,
    });
  }

  // Reseñas
  Future<List<ReviewModel>> getResenias({int limit = 100}) async {
    final snapshot = await _firestore
        .collection(FirestoreCollections.resenias)
        .limit(limit)
        .get();
    return snapshot.docs
        .map((doc) => ReviewModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<String?> deleteResenia(String idResenia) async {
    final doc = await _firestore
        .collection(FirestoreCollections.resenias)
        .doc(idResenia)
        .get();
    final idTaller = doc.data()?['id_taller'] as String?;
    await _firestore
        .collection(FirestoreCollections.resenias)
        .doc(idResenia)
        .delete();
    return idTaller;
  }

  // Logs
  Future<void> registrarLog(AdminLogModel log) async {
    await _firestore
        .collection(FirestoreCollections.adminLogs)
        .doc(log.idLog)
        .set(log.toMap());
  }

  Future<List<AdminLogModel>> getLogs({int limit = 50}) async {
    final snapshot = await _firestore
        .collection(FirestoreCollections.adminLogs)
        .orderBy('fecha', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs
        .map((doc) => AdminLogModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  // Métricas (Dashboard)
  Future<int> countCollection(String collectionPath) async {
    final aggregateQuery = await _firestore
        .collection(collectionPath)
        .count()
        .get();
    return aggregateQuery.count ?? 0;
  }
}
