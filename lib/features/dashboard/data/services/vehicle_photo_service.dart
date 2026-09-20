import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

class VehiclePhotoModel {
  final String id;
  final String url;
  final DateTime timestamp;

  VehiclePhotoModel({
    required this.id,
    required this.url,
    required this.timestamp,
  });

  factory VehiclePhotoModel.fromMap(Map<String, dynamic> map, String id) {
    return VehiclePhotoModel(
      id: id,
      url: map['url'] ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {'url': url, 'timestamp': Timestamp.fromDate(timestamp)};
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
        .map(
          (snap) => snap.docs
              .map((doc) => VehiclePhotoModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  /// Sube [imageFile] como foto principal del vehículo y devuelve su URL.
  ///
  /// Observación del 2026-09-20: «el propietario debe poder poner la imagen
  /// que quiera como foto principal de su vehículo, por si no le gusta la que
  /// le pone la API». Hasta ahora `foto_url` solo la escribía el alta con la
  /// foto de catálogo del modelo.
  ///
  /// El nombre lleva un identificador nuevo en cada subida, y eso es
  /// deliberado: con un nombre fijo la URL no cambiaría al reemplazarla y el
  /// caché seguiría sirviendo la anterior — el defecto que las fotos del
  /// taller sí tienen por fuerza (allí el nombre lo fijan las reglas).
  ///
  /// [urlAnterior] se borra si era una foto subida por el propietario a este
  /// mismo vehículo; una URL de catálogo (u otra cualquiera) se deja en paz.
  Future<String> setMainPhoto(
    String vehicleId,
    XFile imageFile, {
    String? urlAnterior,
  }) async {
    final ref = _storage.ref().child(
      'vehiculos/$vehicleId/principal/${_uuid.v4()}.jpg',
    );
    final bytes = await imageFile.readAsBytes();
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    final url = await ref.getDownloadURL();

    if (urlAnterior != null && urlAnterior.isNotEmpty) {
      try {
        final anterior = _storage.refFromURL(urlAnterior);
        if (anterior.fullPath.startsWith('vehiculos/$vehicleId/principal/')) {
          await anterior.delete();
        }
      } catch (_) {
        // No era una URL de Storage (la foto de catálogo del alta), o ya no
        // existe. Ninguna de las dos cosas debe tumbar la subida que sí
        // funcionó.
      }
    }
    return url;
  }

  Future<void> addPhoto(String vehicleId, XFile imageFile) async {
    final photoId = _uuid.v4();
    final ref = _storage.ref().child('vehiculos/$vehicleId/fotos/$photoId.jpg');

    final bytes = await imageFile.readAsBytes();
    final metadata = SettableMetadata(contentType: 'image/jpeg');
    await ref.putData(bytes, metadata);
    final url = await ref.getDownloadURL();

    await _firestore
        .collection('vehiculos')
        .doc(vehicleId)
        .collection('fotos')
        .doc(photoId)
        .set(
          VehiclePhotoModel(
            id: photoId,
            url: url,
            timestamp: DateTime.now(),
          ).toMap(),
        );
  }

  Future<void> deletePhoto(String vehicleId, String photoId, String url) async {
    await _firestore
        .collection('vehiculos')
        .doc(vehicleId)
        .collection('fotos')
        .doc(photoId)
        .delete();
    try {
      await _storage.refFromURL(url).delete();
    } catch (e) {
      // Ignorar error si no existe en storage
    }
  }
}
