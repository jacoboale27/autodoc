import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'package:autodoc/core/models/galeria_taller.dart';

/// Se lanza cuando el archivo elegido no sirve para la galeria.
class GaleriaException implements Exception {
  final String mensaje;
  const GaleriaException(this.mensaje);

  @override
  String toString() => mensaje;
}

/// Sube los bytes de una foto de galeria a Storage.
typedef SubidorDeFoto =
    Future<void> Function({
      required String ruta,
      required Uint8List bytes,
      required String contentType,
    });

/// Borra un objeto de Storage.
typedef BorradorDeFoto = Future<void> Function(String ruta);

/// Gestiona la galeria comercial de un taller: `talleres_fotos/{uid}/` en
/// Storage y el campo `usuarios/{uid}.galeria` en Firestore.
///
/// El campo de Firestore es la lista de la verdad: lo que no este ahi no se
/// pinta, aunque el objeto siga en Storage. Por eso el orden de las
/// operaciones importa y esta comentado en cada una.
class GaleriaService {
  final FirebaseFirestore _firestore;
  final SubidorDeFoto _subir;
  final BorradorDeFoto _borrar;

  GaleriaService({
    FirebaseFirestore? firestore,
    SubidorDeFoto? subidor,
    BorradorDeFoto? borrador,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _subir = subidor ?? _subirAFirebaseStorage,
       _borrar = borrador ?? _borrarDeFirebaseStorage;

  DocumentReference<Map<String, dynamic>> _doc(String tallerId) =>
      _firestore.collection('usuarios').doc(tallerId);

  Future<GaleriaTaller> obtener(String tallerId) async {
    final snapshot = await _doc(tallerId).get();
    return GaleriaTaller.fromLista(snapshot.data()?['galeria']);
  }

  /// Sube una foto al hueco `slot` y la publica en la galeria.
  ///
  /// [nombreOriginal] solo sirve para deducir la extension; el objeto se
  /// guarda siempre como `{slot}.{extension}`, que es lo unico que aceptan las
  /// reglas de Storage. Volver a subir el mismo hueco sobrescribe.
  Future<GaleriaTaller> subirFoto({
    required String tallerId,
    required String slot,
    required String nombreOriginal,
    required Uint8List bytes,
  }) async {
    if (!GaleriaTaller.slotsPermitidos.contains(slot)) {
      throw GaleriaException('«$slot» no es un hueco de la galería.');
    }

    final extension = _extensionDe(nombreOriginal);
    if (!GaleriaTaller.extensionesPermitidas.contains(extension)) {
      throw GaleriaException(
        'Solo se aceptan imágenes '
        '(${GaleriaTaller.extensionesPermitidas.join(', ')}).',
      );
    }

    final nombreArchivo = '$slot.$extension';
    final galeriaActual = await obtener(tallerId);

    // Storage primero: si la subida falla, la galeria no queda anunciando una
    // foto que no existe. El fallo en el orden contrario (objeto subido, lista
    // sin actualizar) se corrige reintentando y no deja hueco roto en la ficha.
    await _subir(
      ruta: GaleriaTaller.rutaDe(tallerId, nombreArchivo),
      bytes: bytes,
      contentType: _contentTypeDe(extension),
    );

    // Cambiar de extension en el mismo hueco (logo.jpg -> logo.png) deja un
    // objeto huerfano en Storage, porque sobrescribir solo funciona si el
    // nombre coincide. Se borra explicitamente: no hay Cloud Function que
    // limpie detras, y un huerfano ocupa cuota facturable para siempre.
    final anterior = galeriaActual.archivoDe(slot);
    if (anterior != null && anterior != nombreArchivo) {
      await _borrarIgnorandoAusencia(tallerId, anterior);
    }

    final actualizada = galeriaActual.conArchivo(nombreArchivo);
    await _doc(
      tallerId,
    ).set({'galeria': actualizada.toLista()}, SetOptions(merge: true));
    return actualizada;
  }

  /// Quita una foto de la galeria y borra su objeto.
  Future<GaleriaTaller> quitarFoto({
    required String tallerId,
    required String slot,
  }) async {
    final galeriaActual = await obtener(tallerId);
    final archivo = galeriaActual.archivoDe(slot);
    if (archivo == null) return galeriaActual;

    // Firestore primero, al reves que al subir: lo que decide si una foto se
    // ve es la lista, asi que quitarla de ahi ya la retira de la ficha. Si el
    // borrado en Storage fallara despues, queda un objeto invisible —cuota
    // desperdiciada— y no una ficha apuntando a un objeto que ya no existe.
    final actualizada = galeriaActual.sinSlot(slot);
    await _doc(
      tallerId,
    ).set({'galeria': actualizada.toLista()}, SetOptions(merge: true));

    await _borrarIgnorandoAusencia(tallerId, archivo);
    return actualizada;
  }

  Future<void> _borrarIgnorandoAusencia(
    String tallerId,
    String nombreArchivo,
  ) async {
    try {
      await _borrar(GaleriaTaller.rutaDe(tallerId, nombreArchivo));
    } catch (_) {
      // Que el objeto ya no este es el estado que se buscaba. Un fallo aqui no
      // debe deshacer un cambio en la lista que ya es correcto.
    }
  }

  static String _extensionDe(String nombre) {
    final punto = nombre.lastIndexOf('.');
    if (punto == -1 || punto == nombre.length - 1) return '';
    final extension = nombre.substring(punto + 1).toLowerCase();
    // `jpeg` y `jpg` son el mismo formato; se normaliza para que el nombre
    // canonico no dependa de como se llamase el archivo original.
    return extension == 'jpeg' ? 'jpg' : extension;
  }

  static String _contentTypeDe(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  static Future<void> _subirAFirebaseStorage({
    required String ruta,
    required Uint8List bytes,
    required String contentType,
  }) async {
    await FirebaseStorage.instance
        .ref()
        .child(ruta)
        .putData(bytes, SettableMetadata(contentType: contentType));
  }

  static Future<void> _borrarDeFirebaseStorage(String ruta) =>
      FirebaseStorage.instance.ref().child(ruta).delete();
}
