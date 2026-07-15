import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

class VehiclePhotoModel {
  final String id;
  final String url;
  final DateTime timestamp;

  VehiclePhotoModel({required this.id, required this.url, required this.timestamp});

  factory VehiclePhotoModel.fromMap(Map<String, dynamic> map, String id) {
    return VehiclePhotoModel(
      id: id,
      url: map['url'] ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}

class VehiclePhotoService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();

  Stream<List<VehiclePhotoModel>> streamPhotos(String vehicleId) {
    return _firestore
        .collection('vehiculos')
        .doc(vehicleId)
        .collection('fotos')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => VehiclePhotoModel.fromMap(doc.data(), doc.id)).toList());
  }

  Future<void> addPhoto(String vehicleId, File imageFile) async {
    final photoId = _uuid.v4();
    final ref = _storage.ref().child('vehiculos/$vehicleId/fotos/$photoId.jpg');
    
    await ref.putFile(imageFile);
    final url = await ref.getDownloadURL();

    await _firestore
        .collection('vehiculos')
        .doc(vehicleId)
        .collection('fotos')
        .doc(photoId)
        .set(VehiclePhotoModel(id: photoId, url: url, timestamp: DateTime.now()).toMap());
  }

  Future<void> deletePhoto(String vehicleId, String photoId, String url) async {
    await _firestore.collection('vehiculos').doc(vehicleId).collection('fotos').doc(photoId).delete();
    try {
      await _storage.refFromURL(url).delete();
    } catch (e) {
      // Ignorar error si no existe en storage
    }
  }
}
