import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/painting.dart';

import 'package:autodoc/config/secrets.dart';
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

/// Olvida una imagen ya descargada.
///
/// Observación del 2026-09-20: «subo una foto, la borro, pongo otra y sigue
/// saliendo la primera». No es Storage: el nombre del objeto es fijo por
/// hueco (`logo.jpg`), así que la URL de la foto NUEVA es carácter por
/// carácter la misma que la de la vieja, y tanto `CachedNetworkImage` como el
/// caché de imágenes de Flutter la sirven de su copia local sin volver a
/// pedirla. Reemplazar el objeto no invalida nada por sí solo.
typedef OlvidadorDeImagen = Future<void> Function(String url);

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
  final OlvidadorDeImagen _olvidar;
  final String _bucket;

  GaleriaService({
    FirebaseFirestore? firestore,
    SubidorDeFoto? subidor,
    BorradorDeFoto? borrador,
    OlvidadorDeImagen? olvidador,
    String? bucket,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _subir = subidor ?? _subirAFirebaseStorage,
       _borrar = borrador ?? _borrarDeFirebaseStorage,
       _olvidar = olvidador ?? _olvidarImagenDescargada,
       _bucket = bucket ?? AppSecrets.firebaseStorageBucket;

  /// Tira la copia local de la foto de ese hueco, si se puede construir su
  /// URL. Se llama al subir y al quitar: las dos operaciones dejan la URL
  /// apuntando a otra cosa (o a nada) sin cambiar ni un carácter.
  Future<void> _olvidarFoto(String tallerId, String nombreArchivo) async {
    final url = GaleriaTaller.urlDe(
      bucket: _bucket,
      idTaller: tallerId,
      nombreArchivo: nombreArchivo,
    );
    if (url == null) return;
    try {
      await _olvidar(url);
    } catch (_) {
      // Un caché que no se pudo limpiar enseña una foto vieja; tumbar por eso
      // la subida que SÍ funcionó sería peor.
    }
  }

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

    // Antes de anunciarla: si la lista se publica primero, la pantalla puede
    // repintar el hueco y volver a meter en caché la foto VIEJA.
    await _olvidarFoto(tallerId, nombreArchivo);

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
    await _olvidarFoto(tallerId, archivo);
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
        .putData(
          bytes,
          SettableMetadata(
            contentType: contentType,
            // Un minuto, y no el año por defecto de Storage: el nombre del
            // objeto se repite en cada reemplazo, así que una caché larga es
            // la foto vieja congelada en el navegador de TODO el que ya la
            // vio. Limpiar el caché local (arriba) arregla al que sube; esto
            // arregla a los demás.
            cacheControl: 'public, max-age=60',
          ),
        );
  }

  static Future<void> _olvidarImagenDescargada(String url) async {
    await CachedNetworkImage.evictFromCache(url);
    PaintingBinding.instance.imageCache.evict(NetworkImage(url));
  }

  static Future<void> _borrarDeFirebaseStorage(String ruta) =>
      FirebaseStorage.instance.ref().child(ruta).delete();
}
