import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/utils/maps_availability.dart';

void main() {
  group('isMapUnavailable', () {
    test('en web sin API key el mapa no puede cargar', () {
      expect(isMapUnavailable(isWeb: true, apiKey: ''), isTrue);
    });

    test('en web con API key el mapa carga', () {
      expect(
        isMapUnavailable(isWeb: true, apiKey: 'AIzaSyDjcLVHFY52kFBRImZ7HGB'),
        isFalse,
      );
    });

    test('una key en blanco cuenta como ausente', () {
      // Un secreto mal configurado (espacios, salto de linea suelto) llega
      // como cadena no vacia pero igual de inservible que una vacia.
      expect(isMapUnavailable(isWeb: true, apiKey: '   \n'), isTrue);
    });

    test('fuera de web una key vacia no significa mapa roto', () {
      // En Android/iOS la key viaja en el manifest y en el Info.plist, no por
      // --dart-define, asi que AppSecrets la ve vacia y el mapa funciona igual.
      expect(isMapUnavailable(isWeb: false, apiKey: ''), isFalse);
    });
  });
}
