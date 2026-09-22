import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/models/alert_model.dart';
import 'package:autodoc/core/models/vehicle_model.dart';
import 'package:autodoc/features/dashboard/presentation/providers/alert_provider.dart';

import '../../helpers/test_helpers.mocks.dart';

/// El vencimiento de la **tarjeta de circulacion** genera alerta.
///
/// **Por que existe.** `VehicleModel` tiene `vencimientoTarjeta`, lo persiste,
/// lo parsea y **el usuario lo edita a mano** desde la ficha del vehiculo
/// (`vehicle_profile_screen.dart`, junto al del SOAT y con el mismo aspecto).
/// `_generateSmartAlerts` leia **solo `vencimientoSoat`**.
///
/// O sea: se le pide un dato a la persona, se le guarda, se le deja editar, y
/// no se le avisa jamas. Alguien con la tarjeta venciendo en tres dias tenia
/// **cero** alertas sobre eso. Es un defecto de PRODUCCION, anotado como el
/// gap 1 de `docs/evidencia/IA-01-asistente-de-agenda.md`.
///
/// Ninguna suite podia verlo porque no habia ningun test que afirmara sobre la
/// AUSENCIA de una alerta que nadie habia escrito.
void main() {
  late AlertProvider provider;

  setUp(() {
    provider = AlertProvider(
      firestore: FakeFirebaseFirestore(),
      storage: MockFirebaseStorage(),
    );
  });

  VehicleModel vehiculo({DateTime? tarjeta, DateTime? soat}) => VehicleModel(
    idVehiculo: 'v1',
    idPropietario: 'u1',
    placa: 'ABC123',
    marca: 'Toyota',
    modelo: 'Corolla',
    anio: 2020,
    color: 'Blanco',
    kilometrajeActual: 50000,
    vencimientoTarjeta: tarjeta,
    vencimientoSoat: soat,
  );

  AlertModel? buscar(String tipo) {
    for (final a in provider.alerts) {
      if (a.tipoAlerta == tipo) return a;
    }
    return null;
  }

  /// Mediodia local de dentro de [dias] dias, para que el calculo no dependa
  /// de la hora a la que se corra la suite.
  DateTime enDias(int dias) {
    final hoy = DateTime.now();
    return DateTime(hoy.year, hoy.month, hoy.day + dias, 12);
  }

  group('alerta de tarjeta de circulacion', () {
    test('una tarjeta que vence pronto genera su alerta', () async {
      await provider.fetchAlerts('v1', vehiculo(tarjeta: enDias(3)));

      final alerta = buscar('Tarjeta');
      expect(
        alerta,
        isNotNull,
        reason:
            'La tarjeta de circulacion vence en 3 dias y no se genero ninguna '
            'alerta. Es el dato que la persona teclea en la ficha del '
            'vehiculo y que nunca le avisa.',
      );
      expect(alerta!.idAlerta, 'tarjeta_v1');
      expect(alerta.metadata?['dias_restantes'], 3);
      expect(alerta.metadata?['placa'], 'ABC123');
      expect(alerta.prioridad, AlertPriority.medium);
    });

    test(
      'una tarjeta ya vencida sale como vencida y en prioridad alta',
      () async {
        await provider.fetchAlerts('v1', vehiculo(tarjeta: enDias(-8)));

        final alerta = buscar('Tarjeta');
        expect(alerta, isNotNull);
        expect(alerta!.metadata?['dias_restantes'], -8);
        expect(
          alerta.prioridad,
          AlertPriority.high,
          reason: 'Circular con la tarjeta vencida es una inmovilizacion.',
        );
      },
    );

    test('una tarjeta lejana NO genera alerta', () async {
      // Sin esto, un generador que emitiera la alerta siempre pasaria los dos
      // casos de arriba.
      await provider.fetchAlerts('v1', vehiculo(tarjeta: enDias(90)));
      expect(buscar('Tarjeta'), isNull);
    });

    test('sin fecha de tarjeta no se inventa ninguna alerta', () async {
      await provider.fetchAlerts('v1', vehiculo(tarjeta: null));
      expect(buscar('Tarjeta'), isNull);
    });

    test('la tarjeta y el SOAT conviven, cada una con su alerta', () async {
      await provider.fetchAlerts(
        'v1',
        vehiculo(tarjeta: enDias(2), soat: enDias(5)),
      );

      expect(buscar('Tarjeta'), isNotNull);
      expect(buscar('SOAT'), isNotNull);
      expect(buscar('Tarjeta')!.idAlerta, isNot(buscar('SOAT')!.idAlerta));
    });
  });

  group('el vencimiento se cuenta en dias de calendario', () {
    // `difference(now).inDays` TRUNCA HACIA CERO, y un vencimiento es una
    // FECHA, no un instante: lo que importa es en que DIA cae respecto a hoy,
    // no cuantos periodos de 24 h caben en medio. Los dos casos de abajo son
    // los que distinguen las dos cuentas, y los dos daban mal.
    //
    // Ojo: «vencio hace dos horas» NO es uno de ellos. Un SOAT es valido
    // hasta el final de su dia, asi que hoy a las 12:00 sigue siendo «vence
    // hoy» a las 14:00 — las dos cuentas dan 0 y las dos aciertan. Ese fue mi
    // primer intento de test y afirmaba algo falso.

    test(
      'un vencimiento de AYER por la noche esta vencido, no en 0 dias',
      () async {
        // Ayer a las 23:59. Durante todo el dia de hoy eso esta a menos de 24 h,
        // asi que `inDays` daba **0** y la app decia «por vencer, vence en 0
        // dias» sobre un documento que **ya vencio**. La ventana del defecto
        // dura el dia entero.
        final hoy = DateTime.now();
        final ayerTarde = DateTime(
          hoy.year,
          hoy.month,
          hoy.day,
        ).subtract(const Duration(minutes: 1));

        await provider.fetchAlerts('v1', vehiculo(soat: ayerTarde));

        final alerta = buscar('SOAT');
        expect(alerta, isNotNull);
        expect(
          alerta!.metadata?['dias_restantes'],
          -1,
          reason:
              'Vencio ayer. Contarlo como 0 lo presenta como vigente justo el '
              'dia en que deja de serlo.',
        );
        expect(alerta.prioridad, AlertPriority.high);
      },
    );

    test('un vencimiento de MANANA temprano es manana, no hoy', () async {
      // El espejo: manana a las 00:01 esta a menos de 24 h durante casi todo
      // el dia, asi que `inDays` daba 0 — «vence hoy» sobre algo que vence
      // manana. Mismo error, direccion contraria.
      final hoy = DateTime.now();
      final mananaTemprano = DateTime(hoy.year, hoy.month, hoy.day + 1, 0, 1);

      await provider.fetchAlerts('v1', vehiculo(soat: mananaTemprano));

      expect(buscar('SOAT')!.metadata?['dias_restantes'], 1);
    });
  });
}
