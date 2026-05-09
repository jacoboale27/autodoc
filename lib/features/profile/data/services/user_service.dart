import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../../../../core/models/user_model.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'Usuarios';

  Future<UserModel?> getUserData(String userId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(userId).get();
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      throw 'Error al obtener datos del usuario: $e';
    }
  }

  Future<void> updateUserData(UserModel user) async {
    try {
      await _firestore.collection(_collection).doc(user.idUsuario).set(user.toMap(), SetOptions(merge: true));
    } catch (e) {
      throw 'Error al actualizar perfil: $e';
    }
  }

  Future<void> createUserData(UserModel user) async {
    try {
      await _firestore.collection(_collection).doc(user.idUsuario).set(user.toMap());
    } catch (e) {
      throw 'Error al crear perfil: $e';
    }
  }

  Future<String> uploadProfilePhoto(String userId, File imageFile) async {
    try {
      final ref = FirebaseStorage.instance.ref().child('perfiles').child('$userId.jpg');
      await ref.putFile(imageFile);
      return await ref.getDownloadURL();
    } catch (e) {
      throw 'Error al subir foto: $e';
    }
  }
}
