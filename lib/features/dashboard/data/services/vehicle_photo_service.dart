import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

class VehiclePhotoModel {
  final String id;
  final String url;
  final DateTime timestamp;

  VehiclePhotoModel({
    required this.id,
    required this.url,
    required this.timestamp,
  });

  factory VehiclePhotoModel.fromMap(Map<String, dynamic> map, String id) {
    return VehiclePhotoModel(
      id: id,
      url: map['url'] ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {'url': url, 'timestamp': Timestamp.fromDate(timestamp)};
  }
}

/// Galería de fotos de un vehículo, y la foto que lo representa.
///
/// Las dos cosas viven aquí porque son la misma: **la foto del vehículo es una
/// de las de su galería**, no un campo aparte. Antes no era así —`foto_url` la
/// rellenaba un buscador de imágenes de terceros, retirado en GAPS-08— y el
/// resultado de retirarlo fue que todos los coches se veían con la silueta:
/// la galería existía, pero nada conectaba una cosa con la otra.
class VehiclePhotoService {
  /// Ruta del asset que la app pinta cuando no hay foto. Se guardaba en
  /// `foto_url` como si fuera una URL, así que cuenta como "sin foto".
  static const String placeholder = 'assets/images/default_vehicle.jpg';

  /// Inyectables para poder probar el servicio. Por defecto, las instancias
  /// reales — que tocan Firebase al construirse, de ahí que se resuelvan aquí
  /// y no en un inicializador de campo.
  VehiclePhotoService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    Uuid? uuid,
  }) : _firestoreInyectado = firestore,
       _storageInyectado = storage,
       _uuid = uuid ?? const Uuid();

  final FirebaseFirestore? _firestoreInyectado;
  final FirebaseStorage? _storageInyectado;
  final Uuid _uuid;

  FirebaseFirestore? _firestoreCache;
  FirebaseStorage? _storageCache;

  FirebaseFirestore get _firestore =>
      _firestoreInyectado ?? (_firestoreCache ??= FirebaseFirestore.instance);
  FirebaseStorage get _storage =>
      _storageInyectado ?? (_storageCache ??= FirebaseStorage.instance);

  DocumentReference<Map<String, dynamic>> _vehiculo(String vehicleId) =>
      _firestore.collection('vehiculos').doc(vehicleId);

  CollectionReference<Map<String, dynamic>> _fotos(String vehicleId) =>
      _vehiculo(vehicleId).collection('fotos');

  Stream<List<VehiclePhotoModel>> streamPhotos(String vehicleId) {
    return _fotos(vehicleId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => VehiclePhotoModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  // ---------------------------------------------------------------------
  // INTEGRACION ola-2: aqui conviven DOS caminos para la foto principal.
  //
  // `setMainPhoto` viene de las observaciones del 2026-09-20 (sube y sustituye
  // en un paso) y `usarComoPrincipal` + `subirAStorage`/`registrarFoto` vienen
  // de GAPS-08 (descompuesto, para poder probar la logica de portada sin un
  // doble de Storage, que este repo no tiene decente). Los dos tienen
  // llamadores REALES en las pantallas de su rama, asi que se conservan los
  // dos: retirar uno exige reescribir las pantallas del otro, y eso es una
  // decision de diseno, no una resolucion de conflicto.
  //
  // **Queda anotado como deuda de la integracion**: dos formas de hacer lo
  // mismo sobre el mismo campo (`foto_url`) es justo el patron que este
  // repositorio ya ha pagado varias veces. Unificar es trabajo propio.
  // ---------------------------------------------------------------------

  /// Sube [imageFile] como foto principal del vehículo y devuelve su URL.
  ///
  /// Observación del 2026-09-20: «el propietario debe poder poner la imagen
  /// que quiera como foto principal de su vehículo, por si no le gusta la que
  /// le pone la API». Hasta ahora `foto_url` solo la escribía el alta con la
  /// foto de catálogo del modelo.
  ///
  /// El nombre lleva un identificador nuevo en cada subida, y eso es
  /// deliberado: con un nombre fijo la URL no cambiaría al reemplazarla y el
  /// caché seguiría sirviendo la anterior — el defecto que las fotos del
  /// taller sí tienen por fuerza (allí el nombre lo fijan las reglas).
  ///
  /// [urlAnterior] se borra si era una foto subida por el propietario a este
  /// mismo vehículo; una URL de catálogo (u otra cualquiera) se deja en paz.
  Future<String> setMainPhoto(
    String vehicleId,
    XFile imageFile, {
    String? urlAnterior,
  }) async {
    final ref = _storage.ref().child(
      'vehiculos/$vehicleId/principal/${_uuid.v4()}.jpg',
    );
    final bytes = await imageFile.readAsBytes();
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    final url = await ref.getDownloadURL();

    if (urlAnterior != null && urlAnterior.isNotEmpty) {
      try {
        final anterior = _storage.refFromURL(urlAnterior);
        if (anterior.fullPath.startsWith('vehiculos/$vehicleId/principal/')) {
          await anterior.delete();
        }
      } catch (_) {
        // No era una URL de Storage (la foto de catálogo del alta), o ya no
        // existe. Ninguna de las dos cosas debe tumbar la subida que sí
        // funcionó.
      }
    }
    return url;
  }

  /// ¿Este valor de `foto_url` cuenta como "el vehículo ya tiene foto"?
  ///
  /// La ruta del asset NO cuenta: es lo que el servicio de búsqueda retirado
  /// escribía cuando no encontraba nada, así que hay vehículos en producción
  /// con ese valor guardado y tratarlo como una foto de verdad los dejaría sin
  /// poder adoptar la primera que suba su dueño.
  static bool tieneFoto(String? fotoUrl) =>
      fotoUrl != null && fotoUrl.isNotEmpty && fotoUrl != placeholder;

  /// Sube una foto a la galería y devuelve su URL.
  ///
  /// Si el vehículo no tenía foto, **ésta pasa a ser la suya**. Es lo que hace
  /// que subir la primera foto tenga un efecto visible en el garaje y en el
  /// panel sin que haya que ir a buscar un segundo botón: sin esto, el caso
  /// normal —un coche sin ninguna foto— seguía viéndose con la silueta después
  /// de subirla, que es exactamente el síntoma que había que arreglar.
  ///
  /// A partir de la segunda hay que elegir, y para eso está
  /// [usarComoPrincipal]: sustituir la principal en cada subida haría
  /// imposible tener una galería sin cambiar la portada.
  Future<String> addPhoto(String vehicleId, XFile imageFile) async {
    final photoId = _uuid.v4();
    final url = await subirAStorage(vehicleId, photoId, imageFile);
    await registrarFoto(vehicleId, photoId, url);
    return url;
  }

  /// Sube los bytes y devuelve la URL de descarga.
  ///
  /// Separado de [registrarFoto] para que los tests puedan ejercitar toda la
  /// logica de portada —que es donde estan las decisiones— sin montar un doble
  /// de Firebase Storage, que no tiene uno decente en este repo. Un test
  /// sobreescribe este metodo; produccion usa el de aqui.
  @protected
  Future<String> subirAStorage(
    String vehicleId,
    String photoId,
    XFile imageFile,
  ) async {
    final ref = _storage.ref().child('vehiculos/$vehicleId/fotos/$photoId.jpg');
    final bytes = await imageFile.readAsBytes();
    final metadata = SettableMetadata(contentType: 'image/jpeg');
    await ref.putData(bytes, metadata);
    return ref.getDownloadURL();
  }

  @protected
  Future<void> borrarDeStorage(String url) async {
    await _storage.refFromURL(url).delete();
  }

  /// Anota la foto en la galeria y, si el vehiculo no tenia ninguna, la
  /// convierte en la suya.
  ///
  /// Que la PRIMERA foto ascienda sola es lo que hace que subirla tenga efecto
  /// visible en el garaje y en el panel sin buscar un segundo boton. Sin esto,
  /// el caso normal —un coche sin ninguna foto— seguia viendose con la silueta
  /// despues de subirla, que es justo el sintoma que habia que arreglar.
  ///
  /// A partir de la segunda hay que elegir, y para eso esta
  /// [usarComoPrincipal]: sustituir la portada en cada subida haria imposible
  /// tener una galeria sin cambiarla.
  @visibleForTesting
  Future<void> registrarFoto(
    String vehicleId,
    String photoId,
    String url,
  ) async {
    await _fotos(vehicleId)
        .doc(photoId)
        .set(
          VehiclePhotoModel(
            id: photoId,
            url: url,
            timestamp: DateTime.now(),
          ).toMap(),
        );

    // La promocion va en su propio try: si falla, la foto YA esta en la
    // galeria y perderla seria peor que quedarse sin portada. El dueño
    // siempre puede elegirla a mano despues.
    try {
      final doc = await _vehiculo(vehicleId).get();
      if (!tieneFoto(doc.data()?['foto_url'] as String?)) {
        await _vehiculo(vehicleId).update({'foto_url': url});
      }
    } catch (_) {
      // Sin portada, pero con la foto subida.
    }
  }

  /// Hace de [url] la foto que representa al vehículo.
  ///
  /// No comprueba que la URL esté en la galería porque no hace falta: las
  /// reglas exigen que `foto_url` apunte a `vehiculos/{id}/fotos/` de nuestro
  /// propio Storage (GAPS-08), así que el único origen posible es esta misma
  /// galería.
  Future<void> usarComoPrincipal(String vehicleId, String url) async {
    await _vehiculo(vehicleId).update({'foto_url': url});
  }

  /// Borra una foto de la galería, de Storage, y —si era la portada— deja al
  /// vehículo con otra.
  ///
  /// Sin ese último paso, borrar la foto de portada dejaba `foto_url`
  /// apuntando a un objeto que ya no existe: la ficha se quedaba con un hueco
  /// de carga eterna en móvil y el `errorWidget` solo lo tapa en el widget de
  /// imagen, no en la vista pública del taller, que usa `Image.network` a
  /// pelo. Se asciende la más reciente de las que quedan; si no queda
  /// ninguna, se limpia el campo y vuelve el placeholder.
  Future<void> deletePhoto(String vehicleId, String photoId, String url) async {
    await _fotos(vehicleId).doc(photoId).delete();

    try {
      final doc = await _vehiculo(vehicleId).get();
      if (doc.data()?['foto_url'] == url) {
        final quedan = await _fotos(
          vehicleId,
        ).orderBy('timestamp', descending: true).limit(1).get();
        final sustituta = quedan.docs.isEmpty
            ? null
            : quedan.docs.first.data()['url'] as String?;
        await _vehiculo(vehicleId).update({'foto_url': sustituta ?? ''});
      }
    } catch (_) {
      // El borrado ya ocurrió; no se deshace por no poder recolocar la
      // portada.
    }

    try {
      await borrarDeStorage(url);
    } catch (e) {
      // Ignorar error si no existe en storage
    }
  }
}
