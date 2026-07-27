import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:autodoc/core/constants/firestore_collections.dart';
import 'package:autodoc/core/models/user_model.dart';
import 'package:autodoc/core/utils/role_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    final doc = await _firestore
        .collection(FirestoreCollections.usuarios)
        .doc(id)
        .get();
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

  Future<void> saveFilters({
    double? minRating,
    double? maxDistance,
    String? specialty,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (minRating != null) await prefs.setDouble('wd_min_rating', minRating);
    if (maxDistance != null) {
      await prefs.setDouble('wd_max_distance', maxDistance);
    }
    if (specialty != null) {
      if (specialty.isEmpty) {
        await prefs.remove('wd_specialty');
      } else {
        await prefs.setString('wd_specialty', specialty);
      }
    }
  }

  Future<Map<String, dynamic>> loadFilters() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'minRating': prefs.getDouble('wd_min_rating'),
      'maxDistance': prefs.getDouble('wd_max_distance'),
      'specialty': prefs.getString('wd_specialty'),
    };
  }
}
