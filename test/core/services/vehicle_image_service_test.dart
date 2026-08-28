import 'dart:convert';

import 'package:autodoc/core/services/vehicle_image_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Cubre la busqueda contra SearchAPI.io (engine `google_images`) y, sobre
/// todo, la validacion de los enlaces antes de guardarlos.
///
/// Se pasa `vehicleId: ''` en todos los casos: con id vacio el servicio no toca
/// Firestore ni para leer ni para escribir, asi que la busqueda queda aislada y
/// no hace falta inicializar Firebase.
void main() {
  const defaultImage = 'assets/images/default_vehicle.jpg';

  /// Respuesta de una imagen que si se puede pintar: 200, tipo imagen y CORS.
  http.Response imagenOk() => http.Response(
    '',
    200,
    headers: {'content-type': 'image/jpeg', 'access-control-allow-origin': '*'},
  );

  Future<String> buscar(
    http.Client Function() clientFactory, {
    String apiKey = 'key-de-prueba',
  }) {
    return http.runWithClient(
      () => VehicleImageService(apiKey: apiKey).getVehicleImage(
        vehicleId: '',
        brand: 'Toyota',
        model: 'Corolla',
        year: 2020,
        color: 'rojo',
      ),
      clientFactory,
    );
  }

  /// Monta un cliente que responde la busqueda con [cuerpo] y delega los HEAD
  /// de validacion en [validar].
  http.Client Function() clienteCon(
    Map<String, dynamic> cuerpo, {
    http.Response Function(Uri url)? validar,
    void Function(http.BaseRequest req)? espia,
  }) {
    return () => MockClient((request) async {
      espia?.call(request);
      if (request.method == 'HEAD') {
        return (validar ?? (_) => imagenOk())(request.url);
      }
      return http.Response(jsonEncode(cuerpo), 200);
    });
  }

  test('devuelve el primer enlace verificado que trae la respuesta', () async {
    Uri? busqueda;
    final url = await buscar(
      clienteCon(
        {
          'images': [
            {
              'original': {'link': 'https://cdn.example.com/corolla.jpg'},
            },
            {
              'original': {'link': 'https://cdn.example.com/otro.jpg'},
            },
          ],
        },
        espia: (req) {
          if (req.method == 'GET') busqueda = req.url;
        },
      ),
    );

    expect(url, 'https://cdn.example.com/corolla.jpg');
    // engine=google_images no es opcional: sin el, SearchAPI hace busqueda web.
    expect(busqueda!.queryParameters['engine'], 'google_images');
    expect(busqueda!.queryParameters['api_key'], 'key-de-prueba');
    expect(
      busqueda!.queryParameters['q'],
      contains('Toyota Corolla 2020 rojo'),
    );
    expect(busqueda!.host, 'www.searchapi.io');
  });

  test('salta el enlace protegido contra hotlink y usa el siguiente', () async {
    final url = await buscar(
      clienteCon(
        {
          'images': [
            {
              'original': {'link': 'https://protegido.example.com/foto.jpg'},
              'thumbnail': 'https://cdn.example.com/thumb.jpg',
            },
          ],
        },
        // Caso real: el sitio de origen responde 403 a la descarga directa.
        validar: (url) => url.host == 'protegido.example.com'
            ? http.Response('', 403)
            : imagenOk(),
      ),
    );

    expect(url, 'https://cdn.example.com/thumb.jpg');
  });

  test('descarta el enlace que no manda cabecera CORS', () async {
    final url = await buscar(
      clienteCon(
        {
          'images': [
            {
              'original': {'link': 'https://sin-cors.example.com/foto.jpg'},
              'thumbnail': 'https://cdn.example.com/thumb.jpg',
            },
          ],
        },
        // Se sirve bien, pero la web no podria pintarlo.
        validar: (url) => url.host == 'sin-cors.example.com'
            ? http.Response('', 200, headers: {'content-type': 'image/jpeg'})
            : imagenOk(),
      ),
    );

    expect(url, 'https://cdn.example.com/thumb.jpg');
  });

  test('descarta lo que no es una imagen', () async {
    final url = await buscar(
      clienteCon(
        {
          'images': [
            {'link': 'https://example.com/pagina.html'},
          ],
        },
        validar: (_) => http.Response(
          '',
          200,
          headers: {
            'content-type': 'text/html',
            'access-control-allow-origin': '*',
          },
        ),
      ),
    );

    expect(url, defaultImage);
  });

  test('si ningun candidato se puede mostrar, cae a la por defecto', () async {
    final url = await buscar(
      clienteCon({
        'images': [
          {'link': 'https://a.example.com/1.jpg'},
          {'link': 'https://b.example.com/2.jpg'},
        ],
      }, validar: (_) => http.Response('', 403)),
    );

    expect(url, defaultImage);
  });

  test('acepta `original` cuando viene como cadena, no como mapa', () async {
    final url = await buscar(
      clienteCon({
        'images': [
          {'original': 'https://cdn.example.com/plano.jpg'},
        ],
      }),
    );

    expect(url, 'https://cdn.example.com/plano.jpg');
  });

  test('lee tambien la clave alternativa `images_results`', () async {
    final url = await buscar(
      clienteCon({
        'images_results': [
          {'link': 'https://cdn.example.com/alt.jpg'},
        ],
      }),
    );

    expect(url, 'https://cdn.example.com/alt.jpg');
  });

  test('devuelve la imagen por defecto cuando no hay resultados', () async {
    final url = await buscar(clienteCon({}));

    expect(url, defaultImage);
  });

  test('degrada a la imagen por defecto si la key no es valida', () async {
    final url = await buscar(
      () => MockClient((_) async => http.Response('Unauthorized', 401)),
    );

    expect(url, defaultImage);
  });

  test('degrada a la imagen por defecto al agotarse la cuota', () async {
    final url = await buscar(
      () => MockClient((_) async => http.Response('quota exceeded', 429)),
    );

    expect(url, defaultImage);
  });

  test('sin key no llega a llamar a la API', () async {
    var llamadas = 0;
    final url = await buscar(
      () => MockClient((_) async {
        llamadas++;
        return http.Response(jsonEncode({}), 200);
      }),
      apiKey: '',
    );

    expect(url, defaultImage);
    expect(llamadas, 0, reason: 'no debe gastar cuota sin key');
  });
}
