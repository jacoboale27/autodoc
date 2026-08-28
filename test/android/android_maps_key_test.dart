import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// El manifest de Android recibe su clave de Maps desde el .env de la raiz
/// (ver android/app/build.gradle.kts). Ese .env lo comparten dos consumidores
/// con necesidades distintas: web lo lee via --dart-define-from-file y
/// necesita la clave *Browser*, mientras que Android necesita la clave
/// *Android*. Si gradle se queda con la linea GOOGLE_MAPS_API_KEY= a secas,
/// se lleva la de web y el mapa nativo deja de cargar.
void main() {
  // Solo el codigo: una mencion en prosa a un nombre de clave no dice nada
  // sobre que clave acaba en el manifest.
  final gradle = File(
    'android/app/build.gradle.kts',
  ).readAsLinesSync().where((l) => !l.trimLeft().startsWith('//')).join('\n');

  test('gradle busca la clave especifica de Android antes que la generica', () {
    final androidLookup = gradle.indexOf('GOOGLE_MAPS_API_KEY_ANDROID');
    expect(
      androidLookup,
      greaterThan(-1),
      reason:
          'gradle no busca GOOGLE_MAPS_API_KEY_ANDROID en el .env, asi que se '
          'llevaria al manifest la clave Browser que usa el build de web',
    );

    final genericLookup = RegExp(
      r'GOOGLE_MAPS_API_KEY(?!_ANDROID)',
    ).firstMatch(gradle)?.start;
    expect(
      genericLookup,
      isNotNull,
      reason: 'debe seguir cayendo a GOOGLE_MAPS_API_KEY si no hay la Android',
    );
    expect(
      androidLookup,
      lessThan(genericLookup!),
      reason: 'la clave Android tiene que ganar; la generica es el fallback',
    );
  });

  test('sigue habiendo fallback a la variable de entorno para CI', () {
    // En CI no hay .env; el workflow rellena GOOGLE_MAPS_API_KEY con el valor
    // de GOOGLE_MAPS_API_KEY_ANDROID (ci.yml). Sin este fallback el APK sale
    // con el placeholder vacio.
    expect(gradle.contains('System.getenv("GOOGLE_MAPS_API_KEY")'), isTrue);
  });
}
