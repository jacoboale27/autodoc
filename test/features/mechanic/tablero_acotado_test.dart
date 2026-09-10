import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/models/reparacion_model.dart';
import 'package:autodoc/features/mechanic/data/repositories/reparacion_repository.dart';
import 'package:autodoc/features/mechanic/presentation/providers/reparacion_provider.dart';

import '../../support/fake_functions.dart';
import '../../support/sembrar_reparacion.dart';

/// El stream que alimenta el tablero Kanban y "Mis Servicios", acotado.
///
/// Residual 7.6 de FUNC-02. `watchReparacionesActivas` filtraba por taller y
/// estado pero **no tenía tope**: una colección que crece un ticket por visita,
/// leída entera en cada `attach` del listener. Y como el filtro de estado deja
/// fuera lo cerrado, el tamaño del conjunto depende por completo de que el
/// taller cierre sus tickets — que es justo lo que nadie le obliga a hacer
/// (residual 7.2).
///
/// El tope trae su propio riesgo, y es el que estos tests fijan: recortar sin
/// ordenar deja fuera tickets **arbitrarios** (sin `orderBy`, Firestore ordena
/// por `__name__`, o sea por un id aleatorio), y recortar sin avisar los hace
/// desaparecer del tablero en silencio. Un mecánico que no ve una tarjeta
/// asume que no existe. Así que van juntas las tres cosas: orden por
/// actividad, tope, y una señal de que se llegó al tope.
void main() {
  const idTaller = 't1';

  Future<ReparacionProvider> conTickets(int cuantos) async {
    final db = FakeFirebaseFirestore();
    for (var i = 0; i < cuantos; i += 1) {
      await sembrarReparacion(
        db,
        idVehiculo: 'v$i',
        idTaller: idTaller,
        idPropietario: 'p1',
        placa: 'ABC$i',
        estado: 'recibido',
        // El más antiguo primero: el ticket i tiene i días de antigüedad.
        ahora: DateTime(2026, 1, 1).add(Duration(days: cuantos - i)),
      );
    }
    final provider = ReparacionProvider(
      repository: ReparacionRepository(
        firestore: db,
        functions: FakeFunctions(alLlamar: (_, _) => null),
      ),
    );
    provider.watchTaller(idTaller);
    // El stream entrega en el siguiente turno del event loop.
    await Future<void>.delayed(Duration.zero);
    return provider;
  }

  test('el tablero se acota al tope y trae los MAS RECIENTES', () async {
    final provider = await conTickets(maxTicketsTablero + 5);

    expect(provider.reparaciones, hasLength(maxTicketsTablero));
    // El más reciente es `v0` (ver la siembra). Los que sobran tienen que ser
    // los más viejos, no unos cualesquiera: un tablero que descarta al azar es
    // peor que uno lento.
    expect(provider.reparaciones.first.idVehiculo, 'v0');
    expect(
      provider.reparaciones.map((r) => r.idVehiculo),
      isNot(contains('v${maxTicketsTablero + 4}')),
    );
  });

  test('al llegar al tope, el provider lo dice', () async {
    final provider = await conTickets(maxTicketsTablero + 5);

    expect(
      provider.tableroTruncado,
      isTrue,
      reason:
          'sin esta señal el recorte es invisible: faltan tarjetas y el '
          'mecanico no tiene forma de saberlo',
    );
  });

  test('por debajo del tope no se anuncia recorte alguno', () async {
    final provider = await conTickets(3);

    expect(provider.reparaciones, hasLength(3));
    expect(provider.tableroTruncado, isFalse);
  });
}
