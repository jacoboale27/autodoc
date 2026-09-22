import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:autodoc/features/dashboard/presentation/pages/workshop_directory_screen.dart';

// `workshopCameraUpdate` es una función pura: dice a qué punto se mueve el
// mapa al tocar la tarjeta de un taller en la lista. Lo que cubre es ESE
// cálculo (y que un taller sin coordenadas no mueva el mapa a ninguna parte),
// no la mecánica de mover la cámara.
//
// Devolvía un `CameraUpdate` de Google Maps, que ni siquiera se podía
// instanciar en un test sin infraestructura de plataforma. Desde el
// 2026-09-20 el mapa es OpenStreetMap dibujado por Flutter, así que esto es
// ya un `LatLng` corriente y el test no necesita rodeos.
void main() {
  test('workshopCameraUpdate centra en las coordenadas del taller', () {
    final destino = workshopCameraUpdate({'latitud': 13.7, 'longitud': -89.2});

    expect(destino, const LatLng(13.7, -89.2));
  });

  test('workshopCameraUpdate acepta enteros (num.toDouble)', () {
    final destino = workshopCameraUpdate({'latitud': 13, 'longitud': -89});

    expect(destino, const LatLng(13.0, -89.0));
  });

  test('workshopCameraUpdate es null si el taller no tiene coordenadas', () {
    expect(workshopCameraUpdate({'latitud': null, 'longitud': null}), isNull);
    expect(workshopCameraUpdate({}), isNull);
    expect(workshopCameraUpdate({'latitud': 13.7}), isNull);
    expect(workshopCameraUpdate({'longitud': -89.2}), isNull);
  });
}
