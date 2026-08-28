import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/firestore_collections.dart';
import 'package:flutter/foundation.dart';
import 'package:autodoc/config/secrets.dart';

/// Servicio para obtener imágenes de vehículos estilo concesionario usando
/// SearchAPI.io (engine `google_images`).
class VehicleImageService {
  static const String _searchApiUrl = 'https://www.searchapi.io/api/v1/search';
  static const String _defaultImage = 'assets/images/default_vehicle.jpg';

  /// Cuantos enlaces se comprueban antes de rendirse. Se validan en paralelo,
  /// asi que subirlo cuesta ancho de banda, no tiempo de espera.
  static const int _maxCandidatos = 6;

  /// Por candidato. El total no se suma porque van en paralelo.
  static const Duration _timeoutValidacion = Duration(seconds: 5);

  /// La key se inyecta para poder probar el servicio: por defecto sale de
  /// [AppSecrets], que la resuelve en tiempo de compilacion y por tanto llega
  /// vacia a `flutter test`.
  VehicleImageService({String? apiKey})
    : _apiKey = apiKey ?? AppSecrets.vehicleImageApiKey;

  final String _apiKey;

  /// Perezoso a proposito: `FirebaseFirestore.instance` lanza si Firebase no
  /// esta inicializado, y construir el servicio no deberia exigirlo cuando la
  /// busqueda no va a tocar Firestore (vehicleId vacio).
  FirebaseFirestore? _firestoreCache;
  FirebaseFirestore get _firestore =>
      _firestoreCache ??= FirebaseFirestore.instance;

  /// Obtiene la imagen de un vehículo de forma eficiente.
  ///
  /// Lógica de Persistencia:
  /// 1. Verifica primero en Cloud Firestore si el vehículo ya tiene una [foto_url] válida.
  /// 2. Si la tiene y no es la imagen por defecto, la retorna.
  /// 3. Si NO la tiene, busca fotos estilo concesionario con fondo sólido en SearchAPI.io.
  /// 4. Actualiza Firestore si es necesario y retorna la URL.
  Future<String> getVehicleImage({
    required String vehicleId,
    required String brand,
    required String model,
    required int year,
    required String color,
  }) async {
    try {
      // 1. Verificar primero en Cloud Firestore.
      //
      // Este paso es un ATAJO, no un requisito, y por eso lleva su propio
      // try/catch. El llamador principal es VehicleProvider.addVehicle(), que
      // pide la imagen ANTES de escribir el vehiculo, asi que aqui el
      // documento todavia no existe. Y leer un documento inexistente de
      // /vehiculos no devuelve "no existe": la regla evalua
      // `resource.data.id_propietario` sobre un `resource` nulo, lo que es un
      // error de evaluacion y por tanto un PERMISSION_DENIED.
      //
      // Cuando esa excepcion se propagaba al catch exterior, la funcion
      // devolvia _defaultImage sin haber llamado nunca a la busqueda: ningun
      // vehiculo nuevo obtenia jamas su foto, y en Firestore quedaba
      // 'assets/images/default_vehicle.jpg' como si la busqueda no hubiera
      // encontrado nada. Aislarlo aqui hace que un fallo de lectura degrade a
      // "no hay atajo, busca" en vez de a "no hay imagen".
      if (vehicleId.isNotEmpty) {
        try {
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
        } catch (e) {
          debugPrint(
            'Nota: no se pudo consultar la foto ya guardada del vehiculo '
            '(normal si aun no existe en Firestore); se continua con la '
            'busqueda: $e',
          );
        }
      }

      // 2. Si NO la tiene o tiene la por defecto, busca en SearchAPI.io
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

  /// Busca en SearchAPI.io y devuelve el primer enlace de imagen utilizable,
  /// o `null` si no hay ninguno.
  Future<String?> _fetchFromSearchApi(
    String brand,
    String model,
    int year,
    String color,
  ) async {
    // La key entra por --dart-define (String.fromEnvironment se resuelve en
    // COMPILACION, no en ejecucion): si se arranca sin
    // `--dart-define-from-file=.env` vale '' y SearchAPI responde 401. Sin
    // este aviso el sintoma es indistinguible de "no hay resultados".
    if (_apiKey.isEmpty) {
      debugPrint(
        '[SearchAPI.io] VEHICLE_IMAGE_API_KEY vacia: la app se compilo sin '
        '--dart-define-from-file=.env. No se buscara imagen.',
      );
      return null;
    }

    try {
      final String query =
          '${brand.trim()} ${model.trim()} $year ${color.trim()} '
                  'studio dealership white background'
              .trim();

      final url = Uri.parse(_searchApiUrl).replace(
        queryParameters: {
          'api_key': _apiKey,
          'engine': 'google_images',
          'q': query,
        },
      );

      debugPrint('[SearchAPI.io] Buscando foto de concesionario: "$query"');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List? items = data['images'] ?? data['images_results'];

        if (items == null || items.isEmpty) {
          debugPrint('[SearchAPI.io] Sin imagenes para la consulta: $query');
          return null;
        }

        final candidatos = _extraerCandidatos(items);
        if (candidatos.isEmpty) {
          debugPrint('[SearchAPI.io] Ningun resultado traia un enlace usable.');
          return null;
        }

        final elegido = await _primerCandidatoServible(candidatos);
        if (elegido == null) {
          debugPrint(
            '[SearchAPI.io] Los ${candidatos.length} enlaces candidatos '
            'existen pero ninguno se puede mostrar (anti-hotlink o sin CORS). '
            'Se usa la imagen por defecto.',
          );
          return null;
        }

        debugPrint('[SearchAPI.io] Imagen obtenida y verificada: $elegido');
        return elegido;
      }

      if (response.statusCode == 401) {
        debugPrint(
          '[SearchAPI.io] 401: la VEHICLE_IMAGE_API_KEY no es valida o ha '
          'caducado. Revisala en el panel de searchapi.io.',
        );
      } else {
        debugPrint(
          '[SearchAPI.io] Error ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error en peticion a SearchAPI.io: $e');
    }

    return null;
  }

  /// Aplana los resultados a una lista ordenada de URLs candidatas, sin
  /// repetidos. `original` va primero por resolucion, pero apunta al sitio de
  /// origen; `thumbnail` lo sirve un CDN y suele ser el que sobrevive.
  List<String> _extraerCandidatos(List items) {
    final vistas = <String>{};
    final candidatos = <String>[];

    void anadir(Object? valor) {
      if (candidatos.length >= _maxCandidatos) return;
      final url = valor?.toString();
      if (url == null || !url.startsWith('http')) return;
      if (vistas.add(url)) candidatos.add(url);
    }

    for (final item in items) {
      if (item is! Map) continue;
      final original = item['original'];
      anadir(original is Map ? original['link'] : original);
      anadir(item['link']);
      anadir(item['thumbnail']);
      anadir(item['source_url']);
      if (candidatos.length >= _maxCandidatos) break;
    }

    return candidatos;
  }

  /// Devuelve el primer candidato (en orden de preferencia) que de verdad se
  /// puede pintar, o `null` si ninguno.
  ///
  /// Existe porque guardar el primer enlace `http` sin comprobarlo era la causa
  /// de "el vehiculo tiene foto_url pero no se ve": los buscadores de imagenes
  /// devuelven enlaces al sitio de origen, y muchos de esos sitios responden
  /// 403 a una descarga directa (anti-hotlink) o no mandan cabecera CORS.
  ///
  /// Se comprueban todos a la vez para que la espera sea la del mas lento y no
  /// la suma: esto corre dentro de `addVehicle`, con el usuario mirando.
  Future<String?> _primerCandidatoServible(List<String> candidatos) async {
    final resultados = await Future.wait(candidatos.map(_sePuedeMostrar));
    for (var i = 0; i < candidatos.length; i++) {
      if (resultados[i]) return candidatos[i];
    }
    return null;
  }

  /// Un HEAD basta: solo interesan el codigo, el tipo y la cabecera CORS.
  Future<bool> _sePuedeMostrar(String url) async {
    try {
      final r = await http.head(Uri.parse(url)).timeout(_timeoutValidacion);

      if (r.statusCode != 200) return false;

      final tipo = r.headers['content-type'] ?? '';
      if (!tipo.startsWith('image/')) return false;

      // La URL se guarda en Firestore y la leen TODAS las plataformas, asi que
      // no vale con que funcione donde se creo el vehiculo: si se valida desde
      // Android sin exigir CORS, la web se queda sin poder pintarla. En web el
      // navegador ya habria bloqueado la peticion, asi que llegar aqui es
      // prueba suficiente.
      if (!kIsWeb && !r.headers.containsKey('access-control-allow-origin')) {
        return false;
      }

      return true;
    } catch (_) {
      // Timeout, DNS, TLS, CORS en web... da igual cual: no se puede mostrar.
      return false;
    }
  }
}
