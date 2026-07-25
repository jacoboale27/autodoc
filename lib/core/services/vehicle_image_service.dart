import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/firestore_collections.dart';
import 'package:flutter/foundation.dart';
import 'package:autodoc/config/secrets.dart';

/// Servicio para obtener y gestionar imágenes de vehículos de forma eficiente usando Google Custom Search API.
class VehicleImageService {
  static const String _apiKey = AppSecrets.googleCustomSearchApiKey;
  static const String _cx = AppSecrets.googleCustomSearchCx;
  static const String _baseUrl = 'https://www.googleapis.com/customsearch/v1';
  static const String _defaultImage = 'assets/images/default_vehicle.png';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Obtiene la imagen de un vehículo de forma eficiente.
  /// 
  /// Lógica de Persistencia:
  /// 1. Verifica primero en Cloud Firestore si el vehículo ya tiene una [foto_url].
  /// 2. Si la tiene, la retorna directamente.
  /// 3. Si NO la tiene, realiza una búsqueda en Google Custom Search API optimizada para fotos de concesionario.
  /// 4. Toma el primer resultado válido, actualiza Firestore y retorna la URL.
  /// 5. En caso de error, retorna una imagen por defecto.
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
        final doc = await _firestore.collection(FirestoreCollections.vehiculos).doc(vehicleId).get();
        
        if (doc.exists) {
          final data = doc.data();
          if (data != null && data['foto_url'] != null && (data['foto_url'] as String).isNotEmpty) {
            return data['foto_url'];
          }
        }
      }

      // 2. Si NO la tiene, hace la petición a Google Custom Search API
      final String? imageUrl = await _fetchFromGoogleCustomSearchApi(brand, model, year, color);

      if (imageUrl != null) {
        // 3. Actualiza el documento del vehículo en Firestore solo si vehicleId no está vacío
        if (vehicleId.isNotEmpty) {
          try {
            await _firestore.collection(FirestoreCollections.vehiculos).doc(vehicleId).update({
              'foto_url': imageUrl,
            });
          } catch (e) {
            debugPrint('Nota: No se pudo actualizar Firestore porque el doc no existe aún: $e');
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

  /// Realiza la búsqueda optimizada en Google Custom Search API para fotos de concesionario con fondo sólido.
  Future<String?> _fetchFromGoogleCustomSearchApi(String brand, String model, int year, String color) async {
    try {
      // Query parametrizado para fotos estilo concesionario / estudio con fondo sólido
      final String query = "$brand $model $year $color dealership studio photo solid background";
      
      final url = Uri.parse(_baseUrl).replace(queryParameters: {
        'key': _apiKey,
        'cx': _cx,
        'q': query,
        'searchType': 'image',
        'imgType': 'photo',
        'num': '5',
      });

      debugPrint('[Google Custom Search API] Realizando búsqueda de foto estilo concesionario: "$query"');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List? items = data['items'];
        
        if (items != null && items.isNotEmpty) {
          for (var item in items) {
            final String? link = item['link']?.toString();
            if (link != null && (link.startsWith('http://') || link.startsWith('https://'))) {
              debugPrint('[Google Custom Search API] Imagen de concesionario encontrada: $link');
              return link;
            }
          }
        } else {
          debugPrint('[Google Custom Search API] No se encontraron elementos en la búsqueda.');
        }
      } else {
        debugPrint('[Google Custom Search API] Respuesta de error (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      debugPrint('Error en petición a Google Custom Search API: $e');
    }
    
    return null;
  }
}
