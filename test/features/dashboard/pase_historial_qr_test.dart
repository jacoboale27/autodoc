import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/features/dashboard/data/services/pase_historial_service.dart';

/// INNO-01 — el escaner tiene que DISTINGUIR el payload.
///
/// `vehicle_search_screen.dart` ya traia un escaner que interpreta cualquier
/// `rawValue` como una placa y lanza una busqueda. Sin esta decision, escanear
/// un pase buscaria la placa `autodoc://historial/a3f9...`, no encontraria
/// nada y diria "vehiculo no encontrado" — que es el fallo mas dificil de
/// diagnosticar de los dos, porque la pantalla se comporta como si el QR
/// estuviera bien y fuera el coche el que no existe.
///
/// Por eso la decision vive en una funcion pura y no dentro del `onDetect`:
/// dentro del callback de `MobileScanner` no la puede ejercer ningun test —
/// no hay camara en una suite de widgets.
void main() {
  const token =
      'a3f9c1d2e4b50617a8b9c0d1e2f30415a6b7c8d9e0f102132435465768798a0b1';

  group('tokenDesdePayloadQr', () {
    test('extrae el token de un payload con el prefijo', () {
      expect(tokenDesdePayloadQr('$prefijoPaseHistorial$token'), token);
    });

    test('ignora espacios alrededor', () {
      expect(tokenDesdePayloadQr('  $prefijoPaseHistorial$token \n'), token);
    });

    test('devuelve null para una placa', () {
      expect(tokenDesdePayloadQr('ABC123'), isNull);
    });

    test('devuelve null para el prefijo sin token', () {
      expect(tokenDesdePayloadQr(prefijoPaseHistorial), isNull);
    });

    test('devuelve null para null', () {
      expect(tokenDesdePayloadQr(null), isNull);
    });
  });

  group('rutaDeEscaneoQr', () {
    test('un pase lleva a la pantalla de historial compartido', () {
      expect(
        rutaDeEscaneoQr('$prefijoPaseHistorial$token'),
        '/historial_compartido/$token',
      );
    });

    test('una placa no lleva a ninguna ruta: la busqueda sigue su camino', () {
      expect(rutaDeEscaneoQr('E2E-AAA'), isNull);
    });

    test('el token viaja escapado', () {
      // Un token valido es 64 hex, asi que nada que escapar; pero el escaner
      // recibe lo que le pongan delante. Si un payload trae una barra y se
      // concatena en crudo, go_router lo parte en dos segmentos y la ruta deja
      // de existir — pantalla en blanco en vez de "ese codigo no es un pase".
      final ruta = rutaDeEscaneoQr('${prefijoPaseHistorial}a/b');
      expect(ruta, isNotNull);
      expect(ruta, isNot(contains('a/b')));
      expect(ruta, '/historial_compartido/${Uri.encodeComponent('a/b')}');
    });
  });

  test('el payload del pase se construye con el prefijo', () {
    final pase = PaseHistorial(
      token: token,
      expiraEn: DateTime.fromMillisecondsSinceEpoch(0),
    );
    expect(pase.payloadQr, '$prefijoPaseHistorial$token');
    expect(tokenDesdePayloadQr(pase.payloadQr), token);
  });
}
