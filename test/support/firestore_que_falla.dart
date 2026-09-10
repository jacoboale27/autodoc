import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:mockito/mockito.dart';

// `Query` y `CollectionReference` son `sealed` en cloud_firestore: implementarlas
// dispara `subtype_of_sealed_class`. Se silencia por el mismo motivo que en
// `test/helpers/test_helpers.mocks.dart` (donde lo pone mockito al generar):
// es un doble de PRUEBA, no una implementacion alternativa del SDK, y el
// unico camino para que una consulta falle a voluntad — que es justo lo que
// aqui hace falta probar.
// ignore_for_file: subtype_of_sealed_class

/// `FirebaseFirestore` que se comporta como [FakeFirebaseFirestore] salvo en
/// UNA colección, cuyas consultas lanzan.
///
/// Existe porque `FakeFirebaseFirestore` no sabe fallar, y hay defectos que
/// solo se ven cuando una consulta falla: el que motivó esta clase es una
/// consulta compuesta **sin índice declarado**, que en producción muere con
/// `failed-precondition` la primera vez que alguien la ejecuta y en los
/// emuladores no falla nunca (el emulador sirve cualquier consulta sin mirar
/// `firestore.indexes.json`). Un fallo así, si el código lo traga, no se
/// distingue de "no hay resultados" — y esa confusión es justo el defecto.
///
/// Solo implementa lo que las pantallas bajo prueba usan de la colección que
/// falla: `where`, `orderBy`, `limit` y `get`. Encadenar es válido; lo que
/// lanza es el `get`, que es donde Firestore reporta la falta de índice.
class FirestoreQueFalla extends Fake implements FirebaseFirestore {
  FirestoreQueFalla({
    required this.coleccionQueFalla,
    FirebaseFirestore? delegado,
    Object? error,
  }) : _delegado = delegado ?? FakeFirebaseFirestore(),
       error =
           error ??
           FirebaseException(
             plugin: 'cloud_firestore',
             code: 'failed-precondition',
             message:
                 'The query requires an index. You can create it here: ...',
           );

  /// Nombre de la colección cuyas consultas lanzan.
  final String coleccionQueFalla;

  /// Lo que lanza el `get()`.
  final Object error;

  final FirebaseFirestore _delegado;

  /// Cuántas veces se ha intentado la consulta que falla. Deja afirmar que un
  /// botón de reintento vuelve a llamar de verdad al servidor.
  int intentos = 0;

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      path == coleccionQueFalla
      ? _ColeccionQueFalla(this)
      : _delegado.collection(path);
}

class _ColeccionQueFalla extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _ColeccionQueFalla(this._db);

  final FirestoreQueFalla _db;

  @override
  Query<Map<String, dynamic>> where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) => _ConsultaQueFalla(_db);
}

class _ConsultaQueFalla extends Fake implements Query<Map<String, dynamic>> {
  _ConsultaQueFalla(this._db);

  final FirestoreQueFalla _db;

  @override
  Query<Map<String, dynamic>> where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) => this;

  @override
  Query<Map<String, dynamic>> orderBy(
    Object field, {
    bool descending = false,
  }) => this;

  @override
  Query<Map<String, dynamic>> limit(int limit) => this;

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) {
    _db.intentos += 1;
    return Future<QuerySnapshot<Map<String, dynamic>>>.error(_db.error);
  }
}
