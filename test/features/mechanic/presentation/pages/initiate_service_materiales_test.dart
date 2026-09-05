// test/features/mechanic/presentation/pages/initiate_service_materiales_test.dart
//
// Task 7 (B1) reemplazó el diálogo "Agregar Material" de esta pantalla por
// las mismas filas editables en línea que ya usaba `CotizacionPicker`
// (`CotizacionItemsForm`, en `cotizacion_form.dart`). Ese cambio de mecanismo
// es justo lo que `cotizacion_picker_test.dart` e
// `initiate_service_finalizar_test.dart` no cubren — ninguno de los dos
// tocaba materiales. Estos tests cierran ese hueco: agregar/quitar renglones,
// el atajo "Desde catálogo", y el defecto que abrió la revisión (Fix 1) —
// un renglón con nombre pero cantidad/costo vacíos o inválidos coercionaba en
// silencio a `cantidad: 1, costo: 0` en `_materialesDesdeFilas()` y llegaba
// así al `servicios` del taller.

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:autodoc/core/constants/firestore_collections.dart';
import 'package:autodoc/core/models/vehicle_model.dart';
import 'package:autodoc/core/widgets/app_text_field.dart';
import 'package:autodoc/features/dashboard/presentation/providers/alert_provider.dart';
import 'package:autodoc/features/mechanic/data/repositories/catalogo_repository.dart';
import 'package:autodoc/features/mechanic/presentation/pages/initiate_service_screen.dart';
import 'package:autodoc/features/mechanic/presentation/providers/catalogo_provider.dart';
import 'package:autodoc/features/mechanic/presentation/providers/reparacion_provider.dart';

import '../../../../helpers/test_helpers.mocks.dart';
import '../../../../support/mechanic_harness.dart';
import 'initiate_service_finalizar_test.dart' show AlertProviderSinTareas;

VehicleModel _vehiculoFake() => VehicleModel(
  idVehiculo: 'v1',
  idPropietario: 'p1',
  placa: 'ABC123',
  marca: 'Toyota',
  modelo: 'Corolla',
  anio: 2020,
  kilometrajeActual: 50000,
);

/// Lee el campo "Costo del servicio" (el total combinado, materiales + mano
/// de obra): `_BoxedField` no expone el `labelText` en `InputDecoration`
/// (`AppTextField` lo dibuja como un `Text` aparte, arriba del campo), así
/// que se ubica el `AppTextField` ancestro de esa etiqueta y se lee su
/// `controller` directamente.
String _costoServicioTexto(WidgetTester tester) {
  final campo = tester.widget<AppTextField>(
    find.ancestor(
      of: find.text('Costo del servicio'),
      matching: find.byType(AppTextField),
    ),
  );
  return campo.controller!.text;
}

/// Toca "Agregar renglón" y llena el renglón número [i] (0-based, en el
/// orden en que se van agregando) de `CotizacionItemsForm`. El índice lo
/// decide el llamador —sabe cuántos renglones agregó antes— en vez de
/// inferirlo del árbol de widgets, que es más frágil.
Future<void> _agregarRenglon(
  WidgetTester tester,
  int i, {
  required String nombre,
  String? cantidad,
  String? costo,
}) async {
  await tester.tap(find.text('Agregar renglón'));
  await tester.pumpAndSettle();

  await tester.enterText(find.byKey(Key('cotizacion_item_nombre_$i')), nombre);
  if (cantidad != null) {
    await tester.enterText(
      find.byKey(Key('cotizacion_item_cantidad_$i')),
      cantidad,
    );
  }
  if (costo != null) {
    await tester.enterText(find.byKey(Key('cotizacion_item_costo_$i')), costo);
  }
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  Future<GoRouterlessResult> pumpPantalla(
    WidgetTester tester, {
    AlertProvider? alertProvider,
    CatalogoProvider? catalogoProvider,
  }) async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    final db = FakeFirebaseFirestore();
    await pumpMechanicScreen(
      tester,
      InitiateServiceScreen(
        reparacionId: 'r1',
        vehiculoPrecargado: _vehiculoFake(),
      ),
      width: 1024,
      location: '/initiate_service/r1',
      disableAnimations: true,
      rutasExtra: const [
        '/mechanic_dashboard',
        '/mechanic_reparaciones',
        '/service_finalized',
      ],
      extraProviders: [
        ChangeNotifierProvider<AlertProvider>.value(
          value:
              alertProvider ??
              AlertProviderSinTareas(
                firestore: db,
                storage: MockFirebaseStorage(),
              ),
        ),
        ChangeNotifierProvider<ReparacionProvider>.value(
          value: FakeReparacionProvider(),
        ),
        if (catalogoProvider != null)
          ChangeNotifierProvider<CatalogoProvider>.value(
            value: catalogoProvider,
          ),
      ],
    );
    await tester.pump();
    await tester.pump();
    return GoRouterlessResult(db);
  }

  testWidgets(
    'agregar y quitar renglones de materiales mantiene el total correcto',
    (tester) async {
      await pumpPantalla(tester);

      await _agregarRenglon(
        tester,
        0,
        nombre: 'Filtro de aceite',
        cantidad: '2',
        costo: '15.50',
      );
      expect(_costoServicioTexto(tester), '31.00');

      await _agregarRenglon(
        tester,
        1,
        nombre: 'Aceite 5W30',
        cantidad: '1',
        costo: '9.00',
      );
      expect(_costoServicioTexto(tester), '40.00');

      // Quita el segundo renglón (índice 1): el ícono de eliminar está
      // dentro del contenedor de esa fila.
      final fila1 = find.byKey(const Key('cotizacion_item_row_1'));
      expect(fila1, findsOneWidget);
      await tester.tap(
        find.descendant(of: fila1, matching: find.byIcon(Icons.close)),
      );
      await tester.pump();

      expect(_costoServicioTexto(tester), '31.00');
    },
  );

  testWidgets(
    'agregar desde catálogo crea un renglón con cantidad 1 y el precio del ítem',
    (tester) async {
      final catalogoDb = FakeFirebaseFirestore();
      await catalogoDb
          .collection(FirestoreCollections.talleres)
          .doc('t1')
          .collection('catalogo_servicios')
          .add({'id_taller': 't1', 'nombre': 'Bujía', 'precio': 25.0});

      final catalogoProvider = CatalogoProvider(
        repository: CatalogoRepository(firestore: catalogoDb),
      );

      await pumpPantalla(tester, catalogoProvider: catalogoProvider);
      // `watchTaller('t1')` se dispara en el postFrameCallback de
      // `initState`; deja correr el stream antes de abrir el catálogo.
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Desde catálogo'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bujía'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('cotizacion_item_nombre_0')),
            )
            .controller!
            .text,
        'Bujía',
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('cotizacion_item_cantidad_0')),
            )
            .controller!
            .text,
        '1',
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('cotizacion_item_costo_0')),
            )
            .controller!
            .text,
        '25.00',
      );
      expect(_costoServicioTexto(tester), '25.00');
    },
  );

  testWidgets(
    'un renglón incompleto (nombre sin costo válido) bloquea Finalizar y no '
    'llega a servicios como un material a costo 0',
    (tester) async {
      final resultado = await pumpPantalla(tester);
      final db = resultado.db;

      // Nombre puesto, costo vacío: antes de la Fix 1, `_materialesDesdeFilas`
      // solo descartaba filas con nombre vacío, así que esta llegaba al
      // payload con `costo: 0` sin que nadie lo notara.
      await _agregarRenglon(tester, 0, nombre: 'Pastillas de freno');

      final boton = find.text('FINALIZAR SERVICIO');
      await tester.ensureVisible(boton);
      await tester.tap(boton, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Revisa los materiales'),
        findsOneWidget,
        reason:
            'el Form de materiales debe bloquear el envío y avisar, no '
            'coercionar la fila incompleta a cantidad:1/costo:0 en silencio',
      );
      expect(
        find.byType(InitiateServiceScreen),
        findsOneWidget,
        reason: 'no debe navegar fuera: Finalizar no llegó a ejecutarse',
      );

      final servicios = await db
          .collection(FirestoreCollections.servicios)
          .get();
      expect(
        servicios.docs,
        isEmpty,
        reason:
            'sin materiales válidos, no debe haberse escrito ningún '
            'documento de servicio en absoluto',
      );
    },
  );
}

/// Empaqueta el `FakeFirebaseFirestore` que ve `AlertProvider` en esta
/// pantalla, para poder inspeccionar `servicios` después de Finalizar sin
/// que `pumpPantalla` tenga que devolver un `GoRouter` que estos tests no
/// necesitan (a diferencia de `initiate_service_finalizar_test.dart`).
class GoRouterlessResult {
  GoRouterlessResult(this.db);
  final FakeFirebaseFirestore db;
}
