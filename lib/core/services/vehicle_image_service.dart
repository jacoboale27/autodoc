import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/firestore_collections.dart';
import 'package:flutter/foundation.dart';
import 'package:autodoc/config/secrets.dart';

/// Servicio para obtener y gestionar imágenes de vehículos de forma eficiente usando Google Custom Search API.
class VehicleImageService {
  // Configuración de Seguridad: Utiliza constantes para la API_KEY y el SEARCH_ENGINE_ID.
  // Nota: En producción, se recomienda mover estos valores a variables de entorno (.env) o Secret Manager.
  static const String _apiKey = AppSecrets.vehicleImageApiKey;
  
  
  static const String _baseUrl = 'https://www.searchapi.io/api/v1/search';
  static const String _defaultImage = 'assets/images/default_vehicle.png';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Obtiene la imagen de un vehículo de forma eficiente.
  /// 
  /// Lógica de Persistencia:
  /// 1. Verifica primero en Cloud Firestore si el vehículo ya tiene una [foto_url].
  /// 2. Si la tiene, la retorna directamente.
  /// 3. Si NO la tiene, realiza una búsqueda en Google Custom Search API.
  /// 4. Toma el primer resultado, actualiza Firestore y retorna la URL.
  /// 5. En caso de error, retorna una imagen por defecto de los assets.
  Future<String> getVehicleImage({
    required String vehicleId,
    required String brand,
    required String model,
    required int year,
    required String color,
  }) async {
    try {
      // 1. Verificar primero en Cloud Firestore
      final doc = await _firestore.collection(FirestoreCollections.vehiculos).doc(vehicleId).get();
      
      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['foto_url'] != null && (data['foto_url'] as String).isNotEmpty) {
          return data['foto_url'];
        }
      }

      // 2. Si NO la tiene, hace la petición a SearchAPI
      final String? imageUrl = await _fetchFromSearchApi(brand, model, year, color);

      if (imageUrl != null) {
        // 3. Actualiza el documento del vehículo en Firestore SOLO si ya existe
        // Si no existe (vehículo nuevo), el provider se encargará de guardarlo al crear el doc.
        if (vehicleId.isNotEmpty) {
          try {
            await _firestore.collection(FirestoreCollections.vehiculos).doc(vehicleId).update({
              'foto_url': imageUrl,
            });
          } catch (e) {
            // Ignoramos el error si el documento no existe aún
            debugPrint('Nota: No se pudo actualizar Firestore porque el doc no existe aún (es normal para vehículos nuevos)');
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

  /// Realiza la búsqueda optimizada en Google Custom Search API
  Future<String?> _fetchFromSearchApi(String brand, String model, int year, String color) async {
    try {
      // Construcción del Query optimizado para fotos de catálogo
      final String query = "$brand $model $year $color studio background white 1920x1080";
      
      final url = Uri.parse(_baseUrl).replace(queryParameters: {
        'api_key': _apiKey,
        'engine': 'google_images',
        'q': query,
      });

      debugPrint('Realizando búsqueda en SearchApi.io: $query');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Debug: Imprimir las llaves disponibles en la respuesta
        debugPrint('[SearchApi] Response keys: ${data.keys.toList()}');

        // SearchApi.io puede devolver los resultados en 'images' o 'images_results'
        final List? items = data['images'] ?? data['images_results'];
        
        if (items != null && items.isNotEmpty) {
          final firstResult = items[0];
          debugPrint('[SearchApi] Primer resultado encontrado: $firstResult');

          // Intentar extraer la mejor URL disponible
          var rawUrl = firstResult['original'] ?? 
                       firstResult['link'] ?? 
                       firstResult['thumbnail'] ?? 
                       firstResult['source_url'];
          
          String? foundUrl;

          // Si el resultado es un Mapa (como se vio en Firestore), extraemos el link interno
          if (rawUrl is Map) {
            foundUrl = rawUrl['link']?.toString() ?? rawUrl['original']?.toString() ?? rawUrl['thumbnail']?.toString();
          } else if (rawUrl != null) {
            foundUrl = rawUrl.toString();
          }
          
          if (foundUrl != null && foundUrl.startsWith('http')) {
            debugPrint('[SearchApi] URL extraída con éxito: $foundUrl');
            return foundUrl;
          }
        } else {
          debugPrint('[SearchApi] No se encontraron resultados en "images" ni "images_results".');
          debugPrint('[SearchApi] Respuesta completa del servidor: ${response.body}');
        }
      } else {
        debugPrint('[SearchApi] Error de Servidor (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      debugPrint('Error realizando petición a SearchAPI: $e');
    }
    
    return null; // Indica que no se encontró imagen o hubo error
  }
}
