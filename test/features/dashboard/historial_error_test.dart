import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/features/dashboard/presentation/pages/service_history_screen.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/l10n/app_localizations.dart';

/// UX-04, el sitio que nombra el plan: `service_history_screen.dart:213`
/// pintaba `'Error: ${snapshot.error}'` en medio de la pantalla.
///
/// Dos cosas mal, no una:
///
///   1. **Lo que se ve.** El texto crudo de un `FirebaseException` no es una
///      molestia estetica. El fallo probable aqui es `failed-precondition` por
///      una consulta sin indice —este repo ya se comio uno en produccion, el
///      indice `Servicios` escrito con mayuscula— y ese mensaje trae la
///      consulta entera y un enlace a la consola de Firebase del proyecto.
///   2. **Lo que NO se podia hacer.** No habia reintento. Un `unavailable` por
///      una red que se cayo un segundo dejaba la pantalla muerta hasta salir y
///      volver a entrar.
///
/// El doble tiene que poder VER el defecto — la cicatriz de este repo.
/// `FakeFirebaseFirestore` no falla nunca por si solo, asi que un test escrito
/// sobre el jamas entraria en la rama de error y pasaria sin probar nada. De
/// ahi este doble: hereda de [Fake], asi que cualquier metodo que la pantalla
/// llame y no este aqui abajo revienta en vez de devolver algo plausible. Lo
/// que hay escrito es, literalmente, todo lo que esta pantalla usa de
/// Firestore.

class FirestoreQueFalla extends Fake implements FirebaseFirestore {
  FirestoreQueFalla(this.fallo);

  /// El error que devuelve el stream; `null` = la consulta va bien. Se puede
  /// cambiar entre reintentos para afirmar que reintentar consulta de nuevo.
  Object? fallo;

  /// Cuantas veces se ha pedido el stream. Un reintento que no incremente esto
  /// no esta reintentando nada: solo esta repintando el mismo error.
  int suscripciones = 0;

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Coleccion(this);
}

// `CollectionReference` y `Query` son sealed: el analizador avisa de que no
// deberian implementarse fuera de su libreria, y tiene razon para el codigo de
// produccion. Aqui es deliberado y es la unica forma de que el doble pueda
// FALLAR: `FakeFirebaseFirestore` no devuelve errores nunca, asi que sin esto
// la rama de error de la pantalla no la ejerceria ningun test.
// ignore: subtype_of_sealed_class
class _Coleccion extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _Coleccion(this._db);

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
  }) => _Consulta(_db);
}

// ignore: subtype_of_sealed_class
class _Consulta extends Fake implements Query<Map<String, dynamic>> {
  _Consulta(this._db);

  final FirestoreQueFalla _db;

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) {
    _db.suscripciones += 1;
    final fallo = _db.fallo;
    if (fallo == null) {
      // Se cierra sin emitir: la pantalla acaba en su estado vacio, que es lo
      // que se quiere afirmar — que el error ya no esta.
      return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }
    return Stream<QuerySnapshot<Map<String, dynamic>>>.error(fallo);
  }
}

Widget envolver(FirebaseFirestore db) {
  return MaterialApp(
    theme: AppTheme.light,
    locale: const Locale('es'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: ServiceHistoryScreen(vehiculoId: 'v1', firestore: db),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUp(() async {
    // `ServiceHistoryScreen` construye un `ReviewService()` en el
    // inicializador de campo, y ese llama a `FirebaseFirestore.instance`: sin
    // una app "[DEFAULT]" registrada la pantalla no llega ni a construirse.
    await Firebase.initializeApp();
  });

  testWidgets('un fallo de la consulta no ensena el error tecnico', (
    tester,
  ) async {
    final db = FirestoreQueFalla(
      FirebaseException(
        plugin: 'cloud_firestore',
        code: 'failed-precondition',
        message:
            'The query requires an index. You can create it here: '
            'https://console.firebase.google.com/project/autodoc/firestore/indexes',
      ),
    );

    await tester.pumpWidget(envolver(db));
    await tester.pumpAndSettle();

    expect(find.textContaining('failed-precondition'), findsNothing);
    expect(find.textContaining('console.firebase.google.com'), findsNothing);
    expect(find.textContaining('Error:'), findsNothing);
  });

  testWidgets('ofrece reintentar, y reintentar vuelve a consultar', (
    tester,
  ) async {
    final db = FirestoreQueFalla(
      FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
    );

    await tester.pumpWidget(envolver(db));
    await tester.pumpAndSettle();

    final reintentar = find.text('Reintentar');
    expect(
      reintentar,
      findsOneWidget,
      reason:
          'sin reintento, un fallo de red de un segundo deja la pantalla '
          'muerta hasta salir y volver a entrar',
    );

    final antes = db.suscripciones;
    db.fallo = null; // la red vuelve
    await tester.tap(reintentar);
    await tester.pumpAndSettle();

    expect(
      db.suscripciones,
      greaterThan(antes),
      reason:
          'reintentar tiene que pedir el stream OTRA VEZ; repintar el mismo '
          'snapshot de error daria el mismo verde sin arreglar nada',
    );
    expect(find.text('Reintentar'), findsNothing);
  });
}
