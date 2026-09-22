import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/nhtsa_models.dart';

class VehicleApiService {
  static const String baseUrl = 'https://vpic.nhtsa.dot.gov/api/vehicles';

  Future<List<CarMake>> fetchAllMakes() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/getallmakes?format=json'),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> results = data['Results'];
        return results.map((json) => CarMake.fromJson(json)).toList();
      } else {
        throw Exception(
          'Error al cargar marcas: Código de estado ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Fallo de red o error al parsear marcas: $e');
    }
  }

  /// Modelos de la marca de un solo tipo de vehículo de NHTSA
  /// (`motorcycle`, `truck`, `bus`...). Con [tipoNhtsa] `null` son todos.
  Future<List<CarModel>> fetchModelsByMakeAndType(
    String makeName,
    String? tipoNhtsa,
  ) async {
    if (tipoNhtsa == null) return fetchModelsByMake(makeName);
    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/GetModelsForMakeYear/make/'
          '${Uri.encodeComponent(makeName)}/vehicletype/'
          '${Uri.encodeComponent(tipoNhtsa)}?format=json',
        ),
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> results = data['Results'];
        return results.map((json) => CarModel.fromJson(json)).toList();
      }
      throw Exception(
        'Error al cargar modelos: Código de estado ${response.statusCode}',
      );
    } catch (e) {
      throw Exception('Fallo de red o error al parsear modelos: $e');
    }
  }

  Future<List<CarModel>> fetchModelsByMake(String makeName) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/getmodelsformake/${Uri.encodeComponent(makeName)}?format=json',
        ),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> results = data['Results'];
        return results.map((json) => CarModel.fromJson(json)).toList();
      } else {
        throw Exception(
          'Error al cargar modelos: Código de estado ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Fallo de red o error al parsear modelos: $e');
    }
  }
}
