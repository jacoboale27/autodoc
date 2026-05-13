import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/models/workshop_model.dart';
import '../../../../core/models/review_model.dart';
import '../../../../core/models/admin_log_model.dart';

class AdminRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Usuarios
  Future<List<UserModel>> getUsuarios() async {
    final snapshot = await _firestore.collection('Usuarios').get();
    return snapshot.docs.map((doc) => UserModel.fromMap(doc.data(), doc.id)).toList();
  }

  Future<void> updateUsuarioEstado(String uid, String nuevoEstado) async {
    await _firestore.collection('Usuarios').doc(uid).update({'estado': nuevoEstado});
  }

  Future<void> updateUsuarioRol(String uid, String nuevoRol) async {
    await _firestore.collection('Usuarios').doc(uid).update({'rol': nuevoRol});
  }

  Future<void> deleteUsuario(String uid) async {
    await _firestore.collection('Usuarios').doc(uid).delete();
  }

  // Talleres
  Future<List<WorkshopModel>> getTalleres() async {
    final snapshot = await _firestore.collection('Talleres').get();
    return snapshot.docs.map((doc) => WorkshopModel.fromMap(doc.data(), doc.id)).toList();
  }

  Future<void> updateTallerEstado(String idTaller, String nuevoEstado) async {
    await _firestore.collection('Talleres').doc(idTaller).update({'estado': nuevoEstado});
  }

  Future<void> deleteTaller(String idTaller) async {
    await _firestore.collection('Talleres').doc(idTaller).delete();
  }

  // Reseñas
  Future<List<ReviewModel>> getResenias() async {
    final snapshot = await _firestore.collection('Resenias').get();
    return snapshot.docs.map((doc) => ReviewModel.fromMap(doc.data(), doc.id)).toList();
  }

  Future<void> deleteResenia(String idResenia) async {
    await _firestore.collection('Resenias').doc(idResenia).delete();
  }

  // Logs
  Future<void> registrarLog(AdminLogModel log) async {
    await _firestore.collection('admin_logs').doc(log.idLog).set(log.toMap());
  }

  // Métricas (Dashboard)
  Future<int> countCollection(String collectionPath) async {
    final aggregateQuery = await _firestore.collection(collectionPath).count().get();
    return aggregateQuery.count ?? 0;
  }
}
