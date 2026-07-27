import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/models/user_model.dart';
import 'package:autodoc/core/constants/firestore_collections.dart';
import 'package:autodoc/core/constants/storage_paths.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = FirestoreCollections.usuarios;

  Future<UserModel?> getUserData(String userId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(userId).get();
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data()!, doc.id);
      }

      // Fallback query if document ID isn't directly the Auth UID
      final query = await _firestore
          .collection(_collection)
          .where('id_usuario', isEqualTo: userId)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        return UserModel.fromMap(query.docs.first.data(), query.docs.first.id);
      }

      return null;
    } catch (e) {
      throw 'Error al obtener datos del usuario: $e';
    }
  }

  Future<void> updateUserData(UserModel user) async {
    try {
      final updateData = user.toMap();
      updateData.remove('rol');
      await _firestore
          .collection(_collection)
          .doc(user.idUsuario)
          .set(updateData, SetOptions(merge: true));
    } catch (e) {
      throw 'Error al actualizar perfil: $e';
    }
  }

  Future<void> createUserData(UserModel user) async {
    try {
      final doc = await _firestore
          .collection(_collection)
          .doc(user.idUsuario)
          .get();
      if (doc.exists) {
        final updateData = user.toMap();
        updateData.remove('rol');
        await _firestore
            .collection(_collection)
            .doc(user.idUsuario)
            .set(updateData, SetOptions(merge: true));
      } else {
        await _firestore
            .collection(_collection)
            .doc(user.idUsuario)
            .set(user.toMap());
      }
    } catch (e) {
      throw 'Error al crear perfil: $e';
    }
  }

  Future<String> uploadProfilePhoto(String userId, XFile imageFile) async {
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child(StoragePaths.perfiles)
          .child('$userId.jpg');
      final bytes = await imageFile.readAsBytes();
      final metadata = SettableMetadata(contentType: 'image/jpeg');
      await ref.putData(bytes, metadata);
      return await ref.getDownloadURL();
    } catch (e) {
      throw 'Error al subir foto: $e';
    }
  }

  Future<void> addFavoriteWorkshop(String userId, String tallerId) async {
    try {
      await _firestore.collection(_collection).doc(userId).update({
        'talleres_favoritos': FieldValue.arrayUnion([tallerId]),
      });
    } catch (e) {
      throw 'Error al agregar favorito: $e';
    }
  }

  Future<void> removeFavoriteWorkshop(String userId, String tallerId) async {
    try {
      await _firestore.collection(_collection).doc(userId).update({
        'talleres_favoritos': FieldValue.arrayRemove([tallerId]),
      });
    } catch (e) {
      throw 'Error al quitar favorito: $e';
    }
  }
}
