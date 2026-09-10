import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/models/vehicle_model.dart';
import 'package:autodoc/features/mechanic/presentation/pages/initiate_service_screen.dart';

import '../../../../support/firestore_que_falla.dart';
import '../../../../support/mechanic_harness.dart';

/// La consulta de "¿hay una cotización aceptada para este vehículo?" de
/// `InitiateServiceScreen`, y qué pasa cuando FALLA.
///
/// Residual 7.4 de FUNC-02, y resultó ser peor de lo anotado. La consulta es
/// compuesta (`id_vehiculo ==`, `estado ==`, `orderBy fecha DESC`) y su índice
/// **no estaba declarado** en `firestore.indexes.json`: en producción eso es
/// `failed-precondition` la primera vez que un mecánico abre la pantalla. Y
/// vivía en un `.then(...)` **sin `catchError`**, así que el fallo era mudo.
///
/// Lo anotado era "la pantalla dice que no hay cotización aceptada". La
/// consecuencia real es mayor: con `_hasApprovedQuote` en `false` la pantalla
/// no pinta el banner de la cotización aprobada sino el **formulario manual
/// de materiales y mano de obra**. El mecánico vuelve a teclear a mano lo que
/// el cliente ya aceptó, y ese importe tecleado es el que acaba en
/// `servicios` — divergente del de la cotización, que además se queda sin
/// marcar como usada. Un fallo de infraestructura acaba escribiendo datos
/// distintos de los que el cliente aprobó, sin un solo mensaje de error.
///
/// El índice ya está declarado (lo vigila `test/firestore_indices_test.dart`).
/// Estos tests cubren la otra mitad: que un fallo de la consulta se vea, no
/// se disfrace de "no hay cotización", y se pueda reintentar.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  VehicleModel vehiculoFake() => VehicleModel(
    idVehiculo: 'v1',
    idPropietario: 'p1',
    placa: 'ABC123',
    marca: 'Toyota',
    modelo: 'Corolla',
    anio: 2020,
    kilometrajeActual: 50000,
  );

  Future<void> montar(WidgetTester tester, FirebaseFirestore firestore) async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    await pumpMechanicScreen(
      tester,
      InitiateServiceScreen(
        reparacionId: 'r1',
        vehiculoPrecargado: vehiculoFake(),
        firestore: firestore,
      ),
      width: 1024,
      location: '/initiate_service/r1',
      disableAnimations: true,
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'si la consulta de la cotizacion falla, NO se pinta el formulario manual',
    (tester) async {
      final db = FirestoreQueFalla(coleccionQueFalla: 'cotizaciones');

      await montar(tester, db);

      expect(db.intentos, 1, reason: 'la pantalla debe consultar al montar');
      // Lo que NO debe pasar: presentar el formulario manual como si se
      // supiera que no hay cotización aceptada. No se sabe.
      expect(
        find.text('Materiales / repuestos'),
        findsNothing,
        reason:
            'un fallo de la consulta no es "no hay cotizacion": ofrecer el '
            'formulario manual invita a re-teclear un importe que ya existe '
            'aprobado, y ese es el que se guarda en `servicios`',
      );
      expect(find.textContaining('No se pudo comprobar'), findsOneWidget);
    },
  );

  testWidgets('el reintento vuelve a consultar de verdad', (tester) async {
    final db = FirestoreQueFalla(coleccionQueFalla: 'cotizaciones');

    await montar(tester, db);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(db.intentos, 2);
  });

  testWidgets('con la consulta rota, Finalizar se niega a guardar', (
    tester,
  ) async {
    // Ocultar el formulario manual no basta: el botón de finalizar vive fuera
    // de ese bloque y sigue en pantalla. Sin este guard se guardaría un
    // `servicios` con cero materiales y cero mano de obra sobre un vehículo
    // que quizá tiene una cotización aprobada de verdad — y la validación de
    // materiales no lo detiene, porque sin `Form` montado
    // `_materialesFormKey.currentState` es `null` y el guard existente
    // resuelve a `true`.
    //
    // La afirmación mira lo ESCRITO, no lo pintado: la primera versión de
    // este test buscaba el texto "No se pudo comprobar" y pasaba en verde sin
    // el guard, porque ese texto ya estaba en pantalla — es el banner de
    // error. Una aserción que se cumple igual antes y después del arreglo no
    // prueba nada.
    final interno = FakeFirebaseFirestore();
    final db = FirestoreQueFalla(
      coleccionQueFalla: 'cotizaciones',
      delegado: interno,
    );

    await montar(tester, db);
    // El boton vive al final de una columna larga: sin `ensureVisible` el tap
    // cae fuera del viewport, `onPressed` no se ejecuta y el test "pasa" sin
    // haber pulsado nada.
    await tester.ensureVisible(find.text('FINALIZAR SERVICIO'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('FINALIZAR SERVICIO'));
    // `pumpAndSettle` no sirve aqui: con las animaciones desactivadas se come
    // los 4 s que el snackbar esta en pantalla y lo encuentra ya retirado.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      (await interno.collection('servicios').get()).docs,
      isEmpty,
      reason:
          'sin saber si hay cotizacion aprobada, guardar el servicio escribe '
          'un importe que puede no ser el que el cliente acepto',
    );
    expect(find.textContaining('sin saber si el cliente'), findsOneWidget);
  });

  testWidgets(
    'con una cotizacion aceptada, la pantalla pinta el banner y no el formulario',
    (tester) async {
      // Primera cobertura real de esta consulta: hasta ahora la pantalla usaba
      // `FirebaseFirestore.instance` y ningún test podía sembrarla.
      final db = FakeFirebaseFirestore();
      await db.collection('cotizaciones').add({
        'id_vehiculo': 'v1',
        'id_taller': 't1',
        'estado': 'aceptada',
        'fecha': Timestamp.fromDate(DateTime(2026, 9, 1)),
        'items': <Map<String, dynamic>>[],
        'mano_de_obra': 100.0,
      });

      await montar(tester, db);

      expect(
        find.textContaining('El cliente aprobó una cotización'),
        findsOneWidget,
      );
      expect(find.text('Materiales / repuestos'), findsNothing);
    },
  );
}
