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

  /// Inyectable para pruebas de widget, mismo motivo que
  /// [_obtenerPerfilCliente]: la frontera de seguridad real (que el
  /// documento fuente de cada empleado nunca filtre correo/teléfono) ya
  /// está probada del lado servidor
  /// (`functions/test/obtener_empleados_publicos.test.js`), no aquí.
  final Future<List<Map<String, dynamic>>> Function(String idTaller)
  _obtenerEmpleadosPublicosFn;

  PublicProfileService({
    FirebaseFirestore? firestore,
    Future<Map<String, dynamic>?> Function(String clienteId)?
    obtenerPerfilCliente,
    Future<List<Map<String, dynamic>>> Function(String idTaller)?
    obtenerEmpleadosPublicos,
  }) : _firestoreInyectado = firestore,
       _obtenerPerfilCliente = obtenerPerfilCliente ?? _llamarCallable,
       _obtenerEmpleadosPublicosFn =
           obtenerEmpleadosPublicos ?? _llamarCallableEmpleados;

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

  static Future<List<Map<String, dynamic>>> _llamarCallableEmpleados(
    String idTaller,
  ) async {
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('obtenerEmpleadosPublicos')
          .call({'idTaller': idTaller});
      final data = result.data;
      if (data is Map && data['empleados'] is List) {
        return (data['empleados'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
      return const [];
    } catch (_) {
      // Sin taller (idTaller vacío/inválido), sin Firebase inicializado (un
      // widget test que no inyecta este fetcher, p. ej.), o cualquier otro
      // fallo del callable: la sección Empleados degrada a "sin
      // empleados", nunca a un crash de toda la pantalla. Catch amplio
      // deliberado (no solo `FirebaseFunctionsException`, a diferencia de
      // `_llamarCallable` arriba): a diferencia del perfil del cliente
      // -que sin datos muestra "no se pudo cargar"-, un taller sin
      // empleados es un estado normal y frecuente, no un error.
      return const [];
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

  /// Empleados públicos (activos) del taller `idTaller` — Tarea 13, D1.
  ///
  /// Subconjunto acotado desde el servidor (`obtenerEmpleadosPublicos`
  /// callable): `{nombre_completo, rol, activo}`. Nunca `correo` ni
  /// `telefono` — ver `functions/src/obtenerEmpleadosPublicos.js`. Lista
  /// vacía si el taller no tiene empleados publicados o si el callable
  /// falla; nunca lanza.
  Future<List<Map<String, dynamic>>> empleadosPublicos(String idTaller) =>
      _obtenerEmpleadosPublicosFn(idTaller);
}
