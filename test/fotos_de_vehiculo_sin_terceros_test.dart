import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Centinela del gap de propiedad intelectual y privacidad de `foto_url`.
///
/// Ninguna otra suite puede ver esto. Una llamada nueva a un buscador de
/// imagenes compila, analiza limpio y pasa cualquier test de widget: lo unico
/// que cambia es que en `vehiculos.foto_url` acaba un enlace a un servidor
/// que no es nuestro. Y ese campo lo lee todo el que puede ver el vehiculo
/// —el taller vinculado, sus empleados, aquel con quien se comparta, y por la
/// vista publica quien reciba un pase de historial—, asi que cada visita le
/// entrega a ese tercero la IP y el User-Agent del visitante.
///
/// Es el mismo centinela de fondo que `alertas_campos_test.dart` para los
/// campos de alerta: la regla vive en `firestore.rules`, los emuladores la
/// obedecen igual de bien que produccion, y por tanto un agujero aqui solo
/// aparece en produccion.
void main() {
  test(
    'ninguna parte de lib/ busca fotos de vehiculo en servicios de terceros',
    () {
      final prohibidos = <RegExp>[
        RegExp('searchapi', caseSensitive: false),
        RegExp('google_images'),
        RegExp('serpapi', caseSensitive: false),
        RegExp('VehicleImageService'),
        RegExp('VEHICLE_IMAGE_API_KEY'),
      ];

      final infractores = <String>[];
      for (final entidad in Directory('lib').listSync(recursive: true)) {
        if (entidad is! File || !entidad.path.endsWith('.dart')) continue;
        final lineas = entidad.readAsLinesSync();
        for (var i = 0; i < lineas.length; i++) {
          final linea = lineas[i];
          // Los comentarios se saltan a proposito: el codigo retirado dejo
          // explicaciones que NOMBRAN lo retirado, y son justo lo que impide
          // que alguien lo reintroduzca por no saber por que se fue.
          if (linea.trimLeft().startsWith('//')) continue;
          for (final patron in prohibidos) {
            if (patron.hasMatch(linea)) {
              infractores.add('${entidad.path}:${i + 1}: ${linea.trim()}');
            }
          }
        }
      }

      expect(
        infractores,
        isEmpty,
        reason:
            'Una foto de vehiculo tiene que venir del propietario y vivir en '
            'nuestro Storage (VehiclePhotoService). Enlazar la de un tercero es '
            'un problema de propiedad intelectual y una fuga de IP de cada '
            'visitante.\n${infractores.join('\n')}',
      );
    },
  );

  test('firestore.rules acota foto_url en create y en update', () {
    final reglas = File('firestore.rules').readAsStringSync();

    expect(
      reglas.contains('function fotoDeVehiculoValida(vehiculoId)'),
      isTrue,
      reason: 'falta el validador de foto_url',
    );
    // Las dos ramas, y por separado: el create con el validador directo y el
    // update con la version que solo valida si el campo CAMBIA. Comprobar
    // solo que el helper existe dejaria pasar un helper sin cablear, que es
    // exactamente el estado en el que estaba `avisos_pendientes` cuando
    // GAPS-06 lo encontro.
    expect(
      reglas.contains('&& fotoDeVehiculoValida(vehiculoId);'),
      isTrue,
      reason: 'el create de /vehiculos no valida foto_url',
    );
    // Con parentesis de APERTURA detras: la validacion tiene que ir FUERA de
    // la disyuncion de ramas, no dentro de la del propietario. Dentro, el
    // `|| isAdmin()` del final la esquivaba entera. `/resenias` ya la tenia
    // fuera desde FUNC-01; esta asercion es lo que impide que vuelva a
    // meterse dentro sin que nadie se entere.
    expect(
      reglas.contains('fotoDeVehiculoValidaEnUpdate(vehiculoId)'),
      isTrue,
      reason: 'el update de /vehiculos no valida foto_url',
    );
    expect(
      reglas.contains('&& fotoDeVehiculoValidaEnUpdate(vehiculoId))'),
      isFalse,
      reason:
          'la validacion volvio a meterse DENTRO de la rama del propietario '
          '(el parentesis de cierre lo delata), y ahi el `|| isAdmin()` la '
          'esquiva entera',
    );

    // La galeria es el mismo agujero por la puerta de al lado: `url` la elige
    // el cliente y la leen los mismos que `foto_url`.
    expect(
      reglas.contains("'vehiculos%2F' + vehiculoId + '%2Ffotos%2F'"),
      isTrue,
      reason: 'la galeria vehiculos/{id}/fotos no acota su `url`',
    );
  });
}
