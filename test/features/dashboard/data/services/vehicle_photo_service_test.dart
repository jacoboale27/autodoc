import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/features/dashboard/data/services/vehicle_photo_service.dart';

/// La foto del vehículo es una de las de su galería.
///
/// Esta relación no existía: `foto_url` la rellenaba un buscador de imágenes
/// de terceros (retirado en GAPS-08) y la galería vivía aparte, así que al
/// retirarlo **todos los coches se quedaron con la silueta** aunque su dueño
/// subiera fotos. Lo que se prueba aquí es el puente.
///
/// Storage queda fuera a propósito: los dos `seams` (`subirAStorage`,
/// `borrarDeStorage`) se sobreescriben, porque lo que decide algo es la lógica
/// de portada, no la subida de bytes.
class _ServicioSinStorage extends VehiclePhotoService {
  _ServicioSinStorage(FakeFirebaseFirestore firestore)
    : super(firestore: firestore);

  final borrados = <String>[];

  @override
  Future<void> borrarDeStorage(String url) async {
    borrados.add(url);
  }
}

const _base = 'https://firebasestorage.googleapis.com/v0/b/b/o/vehiculos%2Fv1';
String _urlDe(String id) => '$_base%2Ffotos%2F$id.jpg?alt=media&token=t';

Future<FakeFirebaseFirestore> _conVehiculo({String? fotoUrl}) async {
  final firestore = FakeFirebaseFirestore();
  await firestore.collection('vehiculos').doc('v1').set({
    'id_vehiculo': 'v1',
    'id_propietario': 'u1',
    'placa': 'P001-123',
    'foto_url': ?fotoUrl,
  });
  return firestore;
}

Future<String?> _fotoDelVehiculo(FakeFirebaseFirestore f) async {
  final doc = await f.collection('vehiculos').doc('v1').get();
  return doc.data()?['foto_url'] as String?;
}

void main() {
  group('tieneFoto', () {
    test('una URL de verdad cuenta', () {
      expect(VehiclePhotoService.tieneFoto(_urlDe('a')), isTrue);
    });

    test('null y cadena vacía no cuentan', () {
      expect(VehiclePhotoService.tieneFoto(null), isFalse);
      expect(VehiclePhotoService.tieneFoto(''), isFalse);
    });

    // El caso que importa de verdad: hay vehículos en producción con esta
    // ruta guardada en `foto_url` como si fuera una URL, porque es lo que
    // escribía el buscador retirado cuando no encontraba nada. Tratarla como
    // una foto real los dejaría sin poder adoptar la primera que suba su
    // dueño, o sea con la silueta para siempre.
    test('la ruta del asset NO cuenta como foto', () {
      expect(
        VehiclePhotoService.tieneFoto(VehiclePhotoService.placeholder),
        isFalse,
      );
    });
  });

  group('la primera foto se convierte en la del vehículo', () {
    test('un vehículo sin foto adopta la que se sube', () async {
      final firestore = await _conVehiculo();
      final servicio = _ServicioSinStorage(firestore);

      await servicio.registrarFoto('v1', 'f1', _urlDe('f1'));

      expect(await _fotoDelVehiculo(firestore), _urlDe('f1'));
    });

    test('un vehículo con el placeholder guardado también la adopta', () async {
      final firestore = await _conVehiculo(
        fotoUrl: VehiclePhotoService.placeholder,
      );
      final servicio = _ServicioSinStorage(firestore);

      await servicio.registrarFoto('v1', 'f1', _urlDe('f1'));

      expect(await _fotoDelVehiculo(firestore), _urlDe('f1'));
    });

    // Sustituir la portada en cada subida haría imposible tener una galería
    // sin cambiar la foto del coche cada vez.
    test('la segunda NO desplaza a la primera', () async {
      final firestore = await _conVehiculo();
      final servicio = _ServicioSinStorage(firestore);

      await servicio.registrarFoto('v1', 'f1', _urlDe('f1'));
      await servicio.registrarFoto('v1', 'f2', _urlDe('f2'));

      expect(await _fotoDelVehiculo(firestore), _urlDe('f1'));
    });

    test('la foto queda en la galería en cualquier caso', () async {
      final firestore = await _conVehiculo();
      final servicio = _ServicioSinStorage(firestore);

      await servicio.registrarFoto('v1', 'f1', _urlDe('f1'));

      final galeria = await firestore
          .collection('vehiculos')
          .doc('v1')
          .collection('fotos')
          .get();
      expect(galeria.docs, hasLength(1));
      expect(galeria.docs.first.data()['url'], _urlDe('f1'));
    });
  });

  test('usarComoPrincipal cambia la portada', () async {
    final firestore = await _conVehiculo();
    final servicio = _ServicioSinStorage(firestore);
    await servicio.registrarFoto('v1', 'f1', _urlDe('f1'));
    await servicio.registrarFoto('v1', 'f2', _urlDe('f2'));

    await servicio.usarComoPrincipal('v1', _urlDe('f2'));

    expect(await _fotoDelVehiculo(firestore), _urlDe('f2'));
  });

  group('borrar la portada no deja al vehículo con un enlace muerto', () {
    test('asciende otra foto de la galería', () async {
      final firestore = await _conVehiculo();
      final servicio = _ServicioSinStorage(firestore);
      await servicio.registrarFoto('v1', 'f1', _urlDe('f1'));
      await servicio.registrarFoto('v1', 'f2', _urlDe('f2'));
      expect(await _fotoDelVehiculo(firestore), _urlDe('f1'));

      await servicio.deletePhoto('v1', 'f1', _urlDe('f1'));

      expect(
        await _fotoDelVehiculo(firestore),
        _urlDe('f2'),
        reason:
            'sin esto, foto_url apunta a un objeto que ya no existe y la '
            'vista pública del taller se queda cargando para siempre',
      );
    });

    test('si no queda ninguna, vuelve el placeholder', () async {
      final firestore = await _conVehiculo();
      final servicio = _ServicioSinStorage(firestore);
      await servicio.registrarFoto('v1', 'f1', _urlDe('f1'));

      await servicio.deletePhoto('v1', 'f1', _urlDe('f1'));

      expect(
        VehiclePhotoService.tieneFoto(await _fotoDelVehiculo(firestore)),
        isFalse,
      );
    });

    test('borrar una que NO es la portada la deja en paz', () async {
      final firestore = await _conVehiculo();
      final servicio = _ServicioSinStorage(firestore);
      await servicio.registrarFoto('v1', 'f1', _urlDe('f1'));
      await servicio.registrarFoto('v1', 'f2', _urlDe('f2'));

      await servicio.deletePhoto('v1', 'f2', _urlDe('f2'));

      expect(await _fotoDelVehiculo(firestore), _urlDe('f1'));
    });

    test('el objeto se borra también de Storage', () async {
      final firestore = await _conVehiculo();
      final servicio = _ServicioSinStorage(firestore);
      await servicio.registrarFoto('v1', 'f1', _urlDe('f1'));

      await servicio.deletePhoto('v1', 'f1', _urlDe('f1'));

      expect(servicio.borrados, [_urlDe('f1')]);
    });
  });
}
