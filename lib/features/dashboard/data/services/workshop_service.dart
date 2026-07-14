import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:autodoc/core/constants/firestore_collections.dart';
import 'package:autodoc/core/models/user_model.dart';
import 'package:autodoc/core/utils/role_utils.dart';

class WorkshopService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<UserModel>> getWorkshopsStream() {
    return _firestore
        .collection(FirestoreCollections.usuarios)
        .where('rol', whereIn: mechanicFirestoreRoles)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Future<List<UserModel>> getWorkshops() async {
    final snapshot = await _firestore
        .collection(FirestoreCollections.usuarios)
        .where('rol', whereIn: mechanicFirestoreRoles)
        .get();
    return snapshot.docs
        .map((doc) => UserModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<UserModel?> getWorkshopById(String id) async {
    final doc = await _firestore.collection(FirestoreCollections.usuarios).doc(id).get();
    if (doc.exists) {
      return UserModel.fromMap(doc.data()!, doc.id);
    }
    return null;
  }

  Future<void> updateWorkshopProfile(UserModel workshop) async {
    await _firestore
        .collection(FirestoreCollections.usuarios)
        .doc(workshop.idUsuario)
        .update(workshop.toMap());
  }
}
