// Observaciones del 2026-09-19, punto 1: cuando un coche ya tiene una o más
// cotizaciones aceptadas, buscar su placa tiene que enseñarle al taller el
// PERFIL del coche —datos generales, los servicios que ya le hizo, sus
// cotizaciones— y un botón para mandarle al dueño una cotización extra con
// la pantalla de cotizar de siempre.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:autodoc/core/models/user_model.dart';
import 'package:autodoc/core/models/reparacion_model.dart';
import 'package:autodoc/core/models/vehicle_model.dart';
import 'package:autodoc/features/chat/data/repositories/chat_repository.dart';
import 'package:autodoc/features/chat/data/repositories/reserva_repository.dart';
import 'package:autodoc/features/chat/presentation/pages/nueva_cotizacion_screen.dart';
import 'package:autodoc/features/chat/presentation/providers/chat_provider.dart';
import 'package:autodoc/features/chat/presentation/providers/reserva_provider.dart';
import 'package:autodoc/features/dashboard/presentation/providers/vehicle_provider.dart';
import 'package:autodoc/features/mechanic/presentation/pages/vehicle_public_view_screen.dart';
import 'package:autodoc/features/mechanic/presentation/providers/reparacion_provider.dart';
import 'package:autodoc/l10n/app_localizations.dart';

import '../../../../support/mechanic_harness.dart';
import '../../../../support/responsive_harness.dart';
import '../../../../support/vehicle_fixtures.dart';

VehicleModel _vehiculo() => VehicleModel(
  idVehiculo: 'v1',
  idPropietario: '',
  placa: 'P123456',
  marca: 'Toyota',
  modelo: 'Corolla',
  anio: 2020,
  color: 'Gris',
  kilometrajeActual: 50000,
);

/// Un taller con el perfil completo: cotizar lo exige.
UserModel _tallerCompleto() => UserModel(
  idUsuario: 't1',
  nombreCompleto: 'Taller Escobar',
  correo: 'taller@example.com',
  rol: 'Mecanico',
  fechaRegistro: DateTime(2026, 1, 1),
  estado: 'activo',
  especialidad: 'Mecánica General',
  departamento: 'San Salvador',
  municipio: 'San Salvador',
  latitud: 13.69,
  longitud: -89.19,
);

/// La ficha pública por id, para el caso de recargar la página.
class _VehiculosConFicha extends FakeVehicleProvider {
  _VehiculosConFicha() : super(const []);

  @override
  Future<VehicleModel?> findPublicVehicleById(String idVehiculo) async =>
      _vehiculo();
}

Future<FakeFirebaseFirestore> _conHistoria() async {
  final db = FakeFirebaseFirestore();
  Future<void> cotizacion(
    String id,
    String estado,
    DateTime fecha,
    String material,
  ) => db.collection('cotizaciones').doc(id).set({
    'id_vehiculo': 'v1',
    'id_taller': 't1',
    'id_mecanico': 't1',
    'id_propietario': 'p1',
    'estado': estado,
    'fecha': Timestamp.fromDate(fecha),
    'items': [
      {'material': material, 'cantidad': 1, 'costo': 30},
    ],
    'mano_de_obra': 20,
  });
  await cotizacion('c1', 'aceptada', DateTime(2026, 9, 10), 'Aceite');
  await cotizacion('c2', 'rechazada', DateTime(2026, 9, 5), 'Llantas');
  // De OTRO taller: no es asunto de este.
  await db.collection('cotizaciones').doc('ajena').set({
    'id_vehiculo': 'v1',
    'id_taller': 't2',
    'id_mecanico': 't2',
    'id_propietario': 'p1',
    'estado': 'aceptada',
    'fecha': Timestamp.fromDate(DateTime(2026, 9, 12)),
    'items': [
      {'material': 'Frenos de otro taller', 'cantidad': 1, 'costo': 99},
    ],
  });
  await db.collection('servicios').add({
    'id_vehiculo': 'v1',
    'id_taller': 't1',
    'tipo_servicio': 'Cambio de aceite',
    'fecha': Timestamp.fromDate(DateTime(2026, 6, 1)),
    'kilometraje_servicio': 45000,
    'costo': 45.0,
  });
  return db;
}

Future<GoRouter> _montar(
  WidgetTester tester,
  FakeFirebaseFirestore db, {
  double width = 1280,
  bool precargado = true,
  String estadoTicket = 'recibido',
  String? ticket = 'r1',
  ReparacionModel? ticketCerrado,
}) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }
  final router = await pumpMechanicScreen(
    tester,
    VehiclePublicViewScreen(
      vehiculoId: 'v1',
      vehiculoPrecargado: precargado ? _vehiculo() : null,
      firestore: db,
    ),
    width: width,
    location: '/vehiculo_publico/v1',
    user: _tallerCompleto(),
    disableAnimations: true,
    rutasExtra: const ['/mechanic_search', '/initiate_service/r1'],
    extraProviders: [
      ChangeNotifierProvider<ReservaProvider>(
        create: (_) =>
            ReservaProvider(repository: ReservaRepository(firestore: db)),
      ),
      ChangeNotifierProvider<ChatProvider>(
        create: (_) => ChatProvider(repository: ChatRepository(firestore: db)),
      ),
      ChangeNotifierProvider<ReparacionProvider>.value(
        value: FakeReparacionProvider(reparacionActivaId: ticket)
          ..estadoTicketActivo = estadoTicket
          ..ultimoTicketCerrado = ticketCerrado,
      ),
      ChangeNotifierProvider<VehicleProvider>(
        create: (_) => _VehiculosConFicha(),
      ),
    ],
  );
  await tester.pumpAndSettle();
  return router;
}

/// Un ticket ya entregado, abierto en [fechaCreacion]: lo que el perfil usa
/// para distinguir «nunca hubo ticket» de «ya se entregó».
ReparacionModel _ticketEntregado(
  DateTime fechaCreacion, {
  String estado = estadoReparacionEntregado,
}) => ReparacionModel(
  idReparacion: 'r1',
  idVehiculo: 'v1',
  idTaller: 't1',
  idPropietario: 'p1',
  placa: 'P123456',
  estado: estado,
  fechaCreacion: fechaCreacion,
  fechaActualizacion: fechaCreacion,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  testWidgets('con una cotización aceptada es el perfil completo', (
    tester,
  ) async {
    await _montar(tester, await _conHistoria());

    expect(find.text('Perfil del vehículo'), findsOneWidget);
    // Datos generales.
    expect(find.text('Toyota Corolla'), findsOneWidget);
    expect(find.text('2020'), findsOneWidget);
    expect(find.text('Gris'), findsOneWidget);
    // El servicio en curso y el acceso a él.
    expect(find.text('Servicio en curso'), findsOneWidget);
    expect(find.text('Recibido'), findsOneWidget);
    expect(find.text('Continuar servicio'), findsOneWidget);
    // Sus cotizaciones, con el estado en texto; ninguna de otro taller.
    expect(find.text('ACEPTADA · EN PROCESO'), findsOneWidget);
    expect(find.text('RECHAZADA'), findsOneWidget);
    expect(find.textContaining('Frenos de otro taller'), findsNothing);
    // Los servicios que ya le hizo.
    expect(find.text('Cambio de aceite'), findsOneWidget);
    // Y el botón de la cotización extra.
    expect(find.text('Nueva cotización'), findsOneWidget);
  });

  testWidgets('sin ticket abierto no ofrece recibir ni continuar nada', (
    tester,
  ) async {
    await _montar(tester, await _conHistoria(), ticket: null);

    expect(find.text('Perfil del vehículo'), findsOneWidget);
    expect(find.text('Continuar servicio'), findsNothing);
    expect(find.text('Recibir vehículo'), findsNothing);
    // Hay una aceptada sin ticket: se explica en vez de callarlo.
    expect(find.textContaining('el ticket todavía no se ha abierto'), findsOne);
  });

  testWidgets('un coche entregado sin cobrar ofrece registrar el servicio', (
    tester,
  ) async {
    // Observación del 2026-09-19: se entregó el coche sin finalizar el
    // servicio. Aquí el aviso decía «el ticket todavía no se ha abierto»,
    // que es lo contrario de lo que pasó, y no había ninguna vía para
    // facturar el trabajo.
    final router = await _montar(
      tester,
      await _conHistoria(),
      ticket: null,
      ticketCerrado: _ticketEntregado(DateTime(2026, 9, 1)),
    );

    expect(
      find.textContaining('se entregó sin registrar el servicio'),
      findsOne,
    );
    expect(
      find.textContaining('el ticket todavía no se ha abierto'),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('perfil_vehiculo_registrar_cobro')));
    await tester.pumpAndSettle();
    expect(router.state.uri.toString(), '/initiate_service/r1');
  });

  testWidgets('un ticket CANCELADO no ofrece cobrar: la visita no ocurrió', (
    tester,
  ) async {
    await _montar(
      tester,
      await _conHistoria(),
      ticket: null,
      ticketCerrado: _ticketEntregado(
        DateTime(2026, 9, 1),
        estado: 'cancelado',
      ),
    );

    expect(
      find.byKey(const Key('perfil_vehiculo_registrar_cobro')),
      findsNothing,
    );
  });

  testWidgets('si el servicio SÍ se registró, no se ofrece cobrar de nuevo', (
    tester,
  ) async {
    // El servicio de `_conHistoria` es del 1 de junio; este ticket se abrió
    // antes, así que ese servicio es el suyo y ya está cobrado.
    await _montar(
      tester,
      await _conHistoria(),
      ticket: null,
      ticketCerrado: _ticketEntregado(DateTime(2026, 5, 20)),
    );

    expect(
      find.textContaining('se entregó sin registrar el servicio'),
      findsNothing,
    );
    expect(
      find.byKey(const Key('perfil_vehiculo_registrar_cobro')),
      findsNothing,
    );
  });

  testWidgets('"Nueva cotización" manda una cotización extra por el chat', (
    tester,
  ) async {
    final db = await _conHistoria();
    await _montar(tester, db);

    await tester.tap(find.text('Nueva cotización'));
    await tester.pumpAndSettle();
    expect(find.byType(NuevaCotizacionScreen), findsOneWidget);
    expect(find.textContaining('Beneficio'), findsNothing);

    await tester.enterText(
      find.byKey(const Key('cotizacion_item_nombre_0')),
      'Pastillas de freno',
    );
    await tester.enterText(
      find.byKey(const Key('cotizacion_item_cantidad_0')),
      '1',
    );
    await tester.enterText(
      find.byKey(const Key('cotizacion_item_costo_0')),
      '60',
    );
    await tester.pump();
    final enviar = find.text(
      AppLocalizations.of(
        tester.element(find.byType(NuevaCotizacionScreen)),
      )!.chatGenerateAndSend,
    );
    await tester.ensureVisible(enviar);
    await tester.tap(enviar);
    await tester.pumpAndSettle();

    expect(find.byType(NuevaCotizacionScreen), findsNothing);

    final nuevas = (await db.collection('cotizaciones').get()).docs
        .where((d) => !['c1', 'c2', 'ajena'].contains(d.id))
        .toList();
    expect(nuevas, hasLength(1));
    final nueva = nuevas.single.data();
    expect(nueva['estado'], 'pendiente');
    expect(nueva['id_vehiculo'], 'v1');
    expect(nueva['id_taller'], 't1');
    expect(nueva['id_propietario'], 'p1');
    expect((nueva['vehiculo_resumen'] as Map)['placa'], 'P123456');

    // Viaja por el chat con el dueño: sin conversación previa, se abre una.
    final chats = await db.collection('conversaciones').get();
    expect(chats.docs, hasLength(1));
    expect(chats.docs.single.data()['id_propietario'], 'p1');
    expect(chats.docs.single.data()['id_mecanico'], 't1');
    final mensajes = await chats.docs.single.reference
        .collection('mensajes')
        .get();
    expect(mensajes.docs.single.data()['tipo'], 'cotizacion_card');

    // Y aparece ya en la lista del perfil, esperando respuesta.
    expect(find.text('ESPERANDO RESPUESTA'), findsOneWidget);
  });

  testWidgets('al recargar la página (sin precarga) usa la ficha pública', (
    tester,
  ) async {
    // El taller no puede leer `vehiculos/v1` antes de recibir el coche: en
    // este doble el documento ni existe, igual de inútil.
    await _montar(tester, await _conHistoria(), precargado: false);

    expect(find.text('Toyota Corolla'), findsOneWidget);
    expect(find.text('Perfil del vehículo'), findsOneWidget);
  });

  testWidgets('no desborda en ningún ancho de auditoría', (tester) async {
    for (final width in kAuditWidths) {
      await _montar(tester, await _conHistoria(), width: width);
      expectNoOverflow(tester);
    }
  });
}
