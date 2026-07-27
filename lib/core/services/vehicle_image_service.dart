import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/firestore_collections.dart';
import 'package:flutter/foundation.dart';
import 'package:autodoc/config/secrets.dart';

/// Servicio para obtener y gestionar imágenes de vehículos de concesionario usando SearchAPI.io (Google Images Engine).
class VehicleImageService {
  static String get _searchApiKey => AppSecrets.vehicleImageApiKey;
  static const String _searchApiUrl = 'https://www.searchapi.io/api/v1/search';
  static const String _defaultImage = 'assets/images/default_vehicle.png';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Obtiene la imagen de un vehículo de forma eficiente.
  ///
  /// Lógica de Persistencia:
  /// 1. Verifica primero en Cloud Firestore si el vehículo ya tiene una [foto_url] válida.
  /// 2. Si la tiene y no es la imagen por defecto, la retorna.
  /// 3. Si NO la tiene, realiza la búsqueda de fotos estilo concesionario con fondo sólido en SearchAPI.io.
  /// 4. Actualiza Firestore si es necesario y retorna la URL.
  Future<String> getVehicleImage({
    required String vehicleId,
    required String brand,
    required String model,
    required int year,
    required String color,
  }) async {
    try {
      // 1. Verificar primero en Cloud Firestore
      if (vehicleId.isNotEmpty) {
        final doc = await _firestore
            .collection(FirestoreCollections.vehiculos)
            .doc(vehicleId)
            .get();

        if (doc.exists) {
          final data = doc.data();
          if (data != null &&
              data['foto_url'] != null &&
              (data['foto_url'] as String).isNotEmpty &&
              data['foto_url'] != _defaultImage) {
            return data['foto_url'];
          }
        }
      }

      // 2. Si NO la tiene o tiene la por defecto, hace la búsqueda en SearchAPI.io
      final String? imageUrl = await _fetchFromSearchApi(
        brand,
        model,
        year,
        color,
      );

      if (imageUrl != null && imageUrl.isNotEmpty) {
        // 3. Actualiza el documento del vehículo en Firestore si vehicleId no está vacío
        if (vehicleId.isNotEmpty) {
          try {
            await _firestore
                .collection(FirestoreCollections.vehiculos)
                .doc(vehicleId)
                .update({'foto_url': imageUrl});
          } catch (e) {
            debugPrint(
              'Nota: No se pudo actualizar Firestore porque el doc no existe aún (se guardará al crear el vehículo): $e',
            );
          }
        }
        return imageUrl;
      }

      return _defaultImage;
    } catch (e, stack) {
      debugPrint('Error en VehicleImageService: $e');
      debugPrint('Stacktrace: $stack');
      return _defaultImage;
    }
  }

  /// Realiza la búsqueda de fotos estilo concesionario con fondo sólido usando SearchAPI.io
  Future<String?> _fetchFromSearchApi(
    String brand,
    String model,
    int year,
    String color,
  ) async {
    try {
      final String cleanBrand = brand.trim();
      final String cleanModel = model.trim();
      final String cleanColor = color.trim();

      // Query de búsqueda optimizado para fotos de catálogo / concesionario
      final String query =
          "$cleanBrand $cleanModel $year $cleanColor studio dealership white background"
              .trim();

      final url = Uri.parse(_searchApiUrl).replace(
        queryParameters: {
          'api_key': _searchApiKey,
          'engine': 'google_images',
          'q': query,
        },
      );

      debugPrint(
        '[SearchAPI.io] Realizando búsqueda de foto de concesionario: "$query"',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List? items = data['images'] ?? data['images_results'];

        if (items != null && items.isNotEmpty) {
          for (var item in items) {
            String? candidateUrl;

            // Extraer link según estructura devuelta por SearchAPI.io
            if (item is Map) {
              if (item['original'] != null) {
                if (item['original'] is Map) {
                  candidateUrl = item['original']['link']?.toString();
                } else {
                  candidateUrl = item['original']?.toString();
                }
              }
              candidateUrl ??=
                  item['link']?.toString() ??
                  item['thumbnail']?.toString() ??
                  item['source_url']?.toString();
            }

            if (candidateUrl != null && candidateUrl.startsWith('http')) {
              debugPrint(
                '[SearchAPI.io] ¡Imagen de concesionario obtenida con éxito! URL: $candidateUrl',
              );
              return candidateUrl;
            }
          }
        } else {
          debugPrint(
            '[SearchAPI.io] No se encontraron imágenes para la consulta: $query',
          );
        }
      } else {
        debugPrint(
          '[SearchAPI.io] Error de servidor (${response.statusCode}): ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error en petición a SearchAPI.io: $e');
    }

    return null;
  }
}
