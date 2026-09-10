import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/constants/firestore_collections.dart';
import 'package:autodoc/core/models/reparacion_model.dart';
import 'package:autodoc/features/mechanic/data/repositories/reparacion_repository.dart';
import 'package:autodoc/features/mechanic/presentation/providers/reparacion_provider.dart';

import '../../support/fake_functions.dart';
import '../../support/sembrar_reparacion.dart';

/// FUNC-02 — regresión del **único** flujo de apertura de un servicio.
///
/// El flujo oficial es: el cliente acepta la cotización → el trigger
/// `onCotizacionAceptada` abre el ticket en `pendiente_recepcion` (Admin SDK,
/// del lado servidor) → el mecánico llega a la pantalla del vehículo, donde
/// `abrirVehiculoComoMecanico` consulta `buscarReparacionActiva` para decidir
/// si hay algo que abrir → si lo hay, "Recibir vehículo" llama a
/// `recibirVehiculoPorId`, que pasa por el callable `recibirVehiculoDelTicket`.
///
/// Este archivo lo fija de punta a punta desde el cliente, y sobre todo fija
/// lo que ya NO puede pasar: hasta FUNC-02 el cliente tenía tres métodos más
/// (`iniciar`, `iniciarOReutilizar`, `iniciarOReutilizarPorVehiculo`) que
/// abrían el ticket por su cuenta. Ninguno tenía consumidor, pero seguían
/// compilando dentro de la app. El equivalente server-side —el callable
/// `iniciarReparacionPorVehiculo`, que además abría el ticket ya en
/// `recibido`— se retira en `functions/`, y su ausencia la vigila
/// `functions/test/apertura_unica_ticket.test.js`.
///
/// La siembra imita al trigger a propósito (`estado: 'pendiente_recepcion'`),
/// no al cliente: el cliente ya no tiene forma de crear un ticket, y
/// `firestore.rules` cierra `allow create` de `/reparaciones` con `if false`.
void main() {
  const idVehiculo = 'v1';
  const idTaller = 't1';

  /// Cuenta los documentos de `reparaciones`, para poder afirmar que el
  /// cliente no creó ninguno por el camino.
  Future<int> contarTickets(FakeFirebaseFirestore db) async =>
      (await db.collection(FirestoreCollections.reparaciones).get())
          .docs
          .length;

  ReparacionProvider construir(
    FakeFirebaseFirestore db,
    FakeFunctions functions,
  ) => ReparacionProvider(
    repository: ReparacionRepository(firestore: db, functions: functions),
  );

  test(
    'cotizacion aceptada -> ticket pendiente_recepcion -> recepcion explicita',
    () async {
      final db = FakeFirebaseFirestore();
      // Lo que deja escrito `onCotizacionAceptada`.
      final idTicket = await sembrarReparacion(
        db,
        idVehiculo: idVehiculo,
        idTaller: idTaller,
        idPropietario: 'p1',
        placa: 'ABC123',
        estado: 'pendiente_recepcion',
      );

      final functions = FakeFunctions(
        alLlamar: (_, _) => {'recibido_ahora': true},
      );
      final provider = construir(db, functions);

      // 1. La pantalla del vehículo decide si hay algo que abrir.
      final encontrado = await provider.buscarReparacionActiva(
        idVehiculo: idVehiculo,
        idTaller: idTaller,
      );
      expect(encontrado, idTicket);

      // 2. "Recibir vehículo" es una acción explícita del taller, y viaja por
      //    el servidor: mover el ticket y otorgar el vínculo con el vehículo
      //    son una sola escritura atómica que el cliente no puede hacer.
      final recibido = await provider.recibirVehiculoPorId(idTicket);
      expect(recibido, isTrue);
      expect(functions.llamadas.single.nombre, 'recibirVehiculoDelTicket');
      expect(functions.llamadas.single.parametros, {'id_reparacion': idTicket});

      // 3. Nada de esto creó un ticket nuevo.
      expect(await contarTickets(db), 1);
    },
  );

  test(
    'sin cotizacion aceptada no hay ticket, y el cliente no puede abrirlo',
    () async {
      final db = FakeFirebaseFirestore();
      final functions = FakeFunctions(
        alLlamar: (nombre, _) =>
            fail('no debe llamarse ningun callable, y menos $nombre'),
      );
      final provider = construir(db, functions);

      final encontrado = await provider.buscarReparacionActiva(
        idVehiculo: idVehiculo,
        idTaller: idTaller,
      );

      expect(encontrado, isNull);
      // El corazón de FUNC-02: no hay salida alternativa. Antes, la pantalla
      // podía llamar a `iniciar*` justo aquí y seguir adelante.
      expect(await contarTickets(db), 0);
      expect(functions.llamadas, isEmpty);
    },
  );

  test(
    'un ticket cancelado no vuelve a abrir la pantalla de servicio',
    () async {
      final db = FakeFirebaseFirestore();
      await sembrarReparacion(
        db,
        idVehiculo: idVehiculo,
        idTaller: idTaller,
        idPropietario: 'p1',
        placa: 'ABC123',
        estado: 'cancelado',
      );
      final functions = FakeFunctions(alLlamar: (_, _) => fail('sin llamadas'));

      final encontrado = await construir(
        db,
        functions,
      ).buscarReparacionActiva(idVehiculo: idVehiculo, idTaller: idTaller);

      // Hace falta una cotización nueva; reabrirlo por la puerta de atrás era
      // justo lo que hacía el callable retirado.
      expect(encontrado, isNull);
      expect(await contarTickets(db), 1);
    },
  );

  test(
    'una visita ya entregada sigue abriendo la pantalla (asimetria conocida)',
    () async {
      // El caso que hacia explotable al callable retirado: la cotizacion se
      // queda en 'aceptada' para siempre, asi que con la visita ya cerrada
      // seguia bastando para abrir un ticket NUEVO, darlo por recibido y
      // recuperar el vinculo con el vehiculo que `revocarVinculoAlCerrarTicket`
      // habia revocado al entregar el coche. Eso ya no se puede provocar: no
      // queda ninguna via, ni de cliente ni de servidor, que cree un ticket.
      //
      // Lo que este test fija es el estado REAL de la compuerta, no el que
      // seria deseable: `ReparacionProvider.buscarReparacionActiva` excluye
      // `cancelado` y NADA MAS, asi que un ticket ya `entregado` sigue abriendo
      // la pantalla de servicio completa. `estadosReparacionCerrados` incluye
      // los dos, de modo que la compuerta y la definicion de "cerrado" del
      // repositorio no coinciden.
      //
      // No se corrige aqui a proposito: cambiar la compuerta toca la lista de
      // Mis Servicios y los tickets legados anteriores a A4b, y merece su
      // propia evidencia. Queda anotado como residual de FUNC-02. Si alguien
      // estrecha la compuerta, este test es el que debe cambiar, y a conciencia.
      final db = FakeFirebaseFirestore();
      final idTicket = await sembrarReparacion(
        db,
        idVehiculo: idVehiculo,
        idTaller: idTaller,
        idPropietario: 'p1',
        placa: 'ABC123',
        estado: 'entregado',
      );
      final functions = FakeFunctions(alLlamar: (_, _) => fail('sin llamadas'));

      final encontrado = await construir(
        db,
        functions,
      ).buscarReparacionActiva(idVehiculo: idVehiculo, idTaller: idTaller);

      expect(encontrado, idTicket);
      expect(estadosReparacionCerrados, contains('entregado'));
      // Lo que si esta garantizado: abrir esa pantalla no crea nada.
      expect(await contarTickets(db), 1);
    },
  );

  test('recibir dos veces no anuncia una recepcion que no ocurrio', () async {
    final db = FakeFirebaseFirestore();
    final idTicket = await sembrarReparacion(
      db,
      idVehiculo: idVehiculo,
      idTaller: idTaller,
      idPropietario: 'p1',
      placa: 'ABC123',
      estado: 'recibido',
    );
    final functions = FakeFunctions(
      alLlamar: (_, _) => {'recibido_ahora': false},
    );

    final recibido = await construir(
      db,
      functions,
    ).recibirVehiculoPorId(idTicket);

    expect(recibido, isFalse);
  });
}
