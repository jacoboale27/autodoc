// Ronda 6: el tablero gana una salida.
//
// Hasta aquí `estadosReparacion` terminaba en `listo_para_entrega` y ningún
// ticket salía nunca del Kanban: el taller acumulaba en pantalla su historia
// completa. Estas pruebas cubren las dos acciones de las columnas extremas,
// que son las dos que tienen efectos fuera del propio ticket.
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:provider/provider.dart';

import 'package:autodoc/features/mechanic/data/repositories/reparacion_repository.dart';
import 'package:autodoc/features/mechanic/presentation/pages/reparaciones_kanban_screen.dart';
import 'package:autodoc/features/mechanic/presentation/providers/reparacion_provider.dart';

import '../../../../helpers/test_helpers.mocks.dart';
import '../../../../support/mechanic_harness.dart';

Future<FakeFirebaseFirestore> sembrarTicket(String estado) async {
  final firestore = FakeFirebaseFirestore();
  await firestore.collection('reparaciones').doc('r1').set({
    'id_vehiculo': 'v1',
    'id_taller': 't1',
    'id_propietario': 'p1',
    'placa': 'ABC123',
    'estado': estado,
    'historial_estados': <Map<String, dynamic>>[],
    'fecha_creacion': DateTime(2026, 8, 1),
    'fecha_actualizacion': DateTime(2026, 8, 5),
  });
  return firestore;
}

Future<void> pumpKanban(
  WidgetTester tester,
  FakeFirebaseFirestore firestore,
) async {
  await pumpMechanicScreen(
    tester,
    const ReparacionesKanbanScreen(idTaller: 't1'),
    width: 1440,
    height: 1000,
    location: '/mechanic_reparaciones',
    disableAnimations: true,
    extraProviders: [
      ChangeNotifierProvider(
        create: (_) => ReparacionProvider(
          repository: ReparacionRepository(
            firestore: firestore,
            functions: MockFirebaseFunctions(),
          ),
        ),
      ),
    ],
  );
  await tester.pumpAndSettle();
}

/// El tablero se desplaza en horizontal cuando las cinco columnas no caben en
/// el ancho util (el sidebar del taller se lleva su parte), asi que la ultima
/// columna nace fuera de pantalla: sin `ensureVisible` el tap cae al vacio.
Future<void> tocar(WidgetTester tester, String texto) async {
  final finder = find.text(texto);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<String?> estadoDe(FakeFirebaseFirestore firestore) async {
  final doc = await firestore.collection('reparaciones').doc('r1').get();
  return doc.data()?['estado'] as String?;
}

void main() {
  testWidgets(
    'la última columna ofrece entregar el vehículo, con confirmación',
    (tester) async {
      final firestore = await sembrarTicket('listo_para_entrega');
      await pumpKanban(tester, firestore);

      expect(find.text('ABC123'), findsOneWidget);
      await tocar(tester, 'Entregar vehículo');

      // El diálogo nombra el hecho físico, no el estado: es lo único que el
      // mecánico puede comprobar mirando al patio.
      expect(find.textContaining('ya se llevó'), findsOneWidget);
      await tocar(tester, 'Entregar');

      expect(await estadoDe(firestore), 'entregado');
      // Y el ticket sale del tablero: eso es lo que este estado existe para
      // conseguir.
      expect(find.text('ABC123'), findsNothing);
    },
  );

  testWidgets('cerrar la confirmación con "Todavía no" no entrega nada', (
    tester,
  ) async {
    final firestore = await sembrarTicket('listo_para_entrega');
    await pumpKanban(tester, firestore);

    await tocar(tester, 'Entregar vehículo');
    await tocar(tester, 'Todavía no');

    expect(await estadoDe(firestore), 'listo_para_entrega');
    expect(find.text('ABC123'), findsOneWidget);
  });

  testWidgets(
    'las columnas intermedias TAMBIÉN ofrecen entregar: el coche ya está '
    'dentro',
    (tester) async {
      // El cliente que se lleva el coche a medias (rechaza el presupuesto, se
      // lo lleva a otro taller) es un caso real, y el repositorio siempre lo
      // permitió: `estadosVehiculoEnTaller` incluye las cuatro columnas. La
      // interfaz solo lo ofrecía en la última, así que la única salida era
      // «Cancelar» — que cierra igual, pero le notifica al propietario
      // "Cancelado" sobre una visita que sí ocurrió.
      final firestore = await sembrarTicket('en_revision');
      await pumpKanban(tester, firestore);

      expect(find.text('ABC123'), findsOneWidget);
      await tocar(tester, 'Entregar vehículo');
      await tocar(tester, 'Entregar');

      expect(await estadoDe(firestore), 'entregado');
      expect(find.text('ABC123'), findsNothing);
    },
  );

  testWidgets('"Por recibir" NO ofrece entregar: el coche no ha llegado', (
    tester,
  ) async {
    // `pendiente_recepcion` es el único estado abierto en el que el coche NO
    // está en el taller. Entregar lo que no se tiene no significa nada, y
    // como entregar revoca el vínculo y saca el ticket del tablero sin vuelta
    // atrás, no se ofrece siquiera.
    final firestore = await sembrarTicket('pendiente_recepcion');
    await pumpKanban(tester, firestore);

    expect(find.text('ABC123'), findsOneWidget);
    expect(find.text('Entregar vehículo'), findsNothing);
  });

  testWidgets(
    'avanzar desde "Por recibir" no escribe el estado a mano: la recepción '
    'pasa por el servidor',
    (tester) async {
      // Recibir el vehículo es también lo que otorga el vínculo al coche
      // (`recibirVehiculoDelTicket`, una sola escritura atómica). Este botón
      // llamaba directo a `cambiarEstado`: el ticket quedaba en `recibido`
      // SIN vínculo, así que parecía recibido y la ficha del coche no abría
      // para nadie del taller, sin ningún error a la vista.
      //
      // `MockFirebaseFunctions` no tiene stub del callable, así que la
      // llamada falla — y eso basta: lo que se comprueba es que el estado NO
      // se movió por la vía directa.
      final firestore = await sembrarTicket('pendiente_recepcion');
      await pumpKanban(tester, firestore);

      await tocar(tester, 'Avanzar a Recibido');

      expect(await estadoDe(firestore), 'pendiente_recepcion');
    },
  );

  testWidgets('avanzar entre columnas del pipeline sigue siendo directo', (
    tester,
  ) async {
    final firestore = await sembrarTicket('recibido');
    await pumpKanban(tester, firestore);

    await tocar(tester, 'Avanzar a En Revisión');

    expect(await estadoDe(firestore), 'en_revision');
  });
}
