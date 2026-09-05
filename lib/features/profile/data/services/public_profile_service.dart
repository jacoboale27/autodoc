import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:autodoc/core/constants/firestore_collections.dart';

/// Resuelve el perfil PUBLICO de "el otro" (Tarea 10, C3 — "ver el perfil
/// del otro desde el chat"), con el subconjunto de campos acotado por el rol
/// de quien mira:
///
/// - **Mecánico visto por un cliente**: nombre, foto, taller, especialidad,
///   calificación (las reseñas se consultan aparte, ver
///   `PublicProfileScreen`).
/// - **Cliente visto por un mecánico**: nombre, foto, municipio — nunca
///   teléfono, DUI, correo ni la lista de vehículos.
///
/// Dos mecanismos distintos a propósito, no por descuido:
///
/// - El mecánico ya tiene una proyección PUBLICA y de lectura anónima en
///   `talleres/{uid}` (`functions/src/publishTallerProfile.js`, mantenida
///   por un trigger de Firestore). Es gratis, siempre está ahí y no
///   necesita ningún round-trip a Cloud Functions — así que este servicio
///   la reutiliza en vez de construir nada nuevo para ese caso.
/// - El cliente NO tiene equivalente, y no debería tenerlo por
///   denormalización estática: lo que un mecánico puede ver de un cliente
///   depende de si YA tienen una conversación real (una relación entre
///   llamante y objetivo, que un documento público no puede expresar por sí
///   solo). Eso solo se puede decidir del lado servidor en el momento de la
///   consulta — de ahí el callable `obtenerPerfilPublico`
///   (`functions/index.js` + `functions/src/obtenerPerfilPublico.js`), que
///   además es la frontera real de seguridad: `usuarios/{userId}` sigue
///   cerrado en `firestore.rules` a `isOwner(userId) || isAdmin()`, así que
///   ni este servicio ni la UI deciden qué campos se filtran — el callable
///   sí, con Admin SDK, verificando primero que exista esa conversación.
class PublicProfileService {
  // Nullable y resuelto perezosamente en [perfilMecanico]: construir este
  // servicio para el caso "cliente" (que nunca toca Firestore) no debe
  // exigir `Firebase.initializeApp()` — de ahí que NO se resuelva
  // `FirebaseFirestore.instance` en el constructor.
  final FirebaseFirestore? _firestoreInyectado;

  /// Inyectable para pruebas de widget: un fake puede devolver el
  /// subconjunto ya resuelto sin necesidad de simular `HttpsCallable`
  /// (mockearlo de verdad exige encadenar dobles de
  /// `FirebaseFunctions`/`HttpsCallable`/`HttpsCallableResult` que no
  /// aportan nada aquí, porque la frontera de seguridad real ya está
  /// probada del lado servidor —
  /// `functions/test/obtener_perfil_publico.test.js`—, no en este widget).
  final Future<Map<String, dynamic>?> Function(String clienteId)
  _obtenerPerfilCliente;

  PublicProfileService({
    FirebaseFirestore? firestore,
    Future<Map<String, dynamic>?> Function(String clienteId)?
    obtenerPerfilCliente,
  }) : _firestoreInyectado = firestore,
       _obtenerPerfilCliente = obtenerPerfilCliente ?? _llamarCallable;

  static Future<Map<String, dynamic>?> _llamarCallable(String clienteId) async {
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('obtenerPerfilPublico')
          .call({'userId': clienteId});
      final data = result.data;
      if (data is Map) return Map<String, dynamic>.from(data);
      return null;
    } on FirebaseFunctionsException {
      // 'permission-denied' (sin conversación compartida), 'not-found', o
      // cualquier otro fallo del callable: sin perfil que mostrar, no un
      // crash de la pantalla.
      return null;
    }
  }

  /// Perfil público del mecánico/taller `uid`, visto por un cliente.
  /// Lectura anónima directa de `talleres/{uid}`; `null` si no existe (uid
  /// inválido, o cuenta que nunca se publicó al directorio).
  Future<Map<String, dynamic>?> perfilMecanico(String uid) async {
    final firestore = _firestoreInyectado ?? FirebaseFirestore.instance;
    final doc = await firestore
        .collection(FirestoreCollections.talleres)
        .doc(uid)
        .get();
    return doc.exists ? doc.data() : null;
  }

  /// Perfil público del cliente `uid`, visto por el mecánico autenticado.
  /// `null` si el callable niega el acceso (sin conversación compartida) o
  /// si el usuario no existe.
  Future<Map<String, dynamic>?> perfilCliente(String uid) =>
      _obtenerPerfilCliente(uid);
}
