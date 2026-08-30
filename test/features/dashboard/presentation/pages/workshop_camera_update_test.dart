import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:autodoc/features/dashboard/presentation/pages/workshop_directory_screen.dart';

// `GoogleMapController` (google_maps_flutter 2.17.0) solo se puede construir
// a través de su factory `init()`, que exige un `_GoogleMapState` privado y
// un `GoogleMapsFlutterPlatform.instance.init(id)` con soporte de plataforma
// real: no hay forma de instanciarlo ni de simularlo en un test sin montar
// infraestructura de plataforma para mapas (inexistente en este repo). Por
// eso `workshopCameraUpdate` se extrajo como función pura: no prueba que
// `animateCamera` llegue a invocarse, pero sí que el tap de la tarjeta del
// mapa sigue calculando el destino correcto tras mover el onTap de un
// GestureDetector externo a la propia AppCard.
void main() {
  test(
    'workshopCameraUpdate centra en las coordenadas del taller a zoom 15',
    () {
      final expected = CameraUpdate.newLatLngZoom(
        const LatLng(13.7, -89.2),
        15,
      );

      final update = workshopCameraUpdate({'latitud': 13.7, 'longitud': -89.2});

      expect(update?.toJson(), expected.toJson());
    },
  );

  test('workshopCameraUpdate acepta enteros (num.toDouble)', () {
    final expected = CameraUpdate.newLatLngZoom(const LatLng(13.0, -89.0), 15);

    final update = workshopCameraUpdate({'latitud': 13, 'longitud': -89});

    expect(update?.toJson(), expected.toJson());
  });

  test('workshopCameraUpdate es null si el taller no tiene coordenadas', () {
    expect(workshopCameraUpdate({'latitud': null, 'longitud': null}), isNull);
    expect(workshopCameraUpdate({}), isNull);
    expect(workshopCameraUpdate({'latitud': 13.7}), isNull);
    expect(workshopCameraUpdate({'longitud': -89.2}), isNull);
  });
}
