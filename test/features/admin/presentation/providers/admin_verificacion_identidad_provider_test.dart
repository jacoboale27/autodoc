// test/features/admin/presentation/providers/admin_verificacion_identidad_provider_test.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/models/user_model.dart';
import 'package:autodoc/features/admin/presentation/providers/admin_verificacion_provider.dart';
import 'package:autodoc/features/dashboard/data/services/workshop_service.dart';
import 'package:autodoc/features/mechanic/data/services/verificacion_service.dart';

/// Cuenta cuantas resoluciones estan "en vuelo" a la vez, para poder
/// distinguir `Future.wait` (paralelo) de un `for`+`await` secuencial (N+1):
/// secuencial nunca deja que `enVuelo` pase de 1.
class _WorkshopServiceContador extends WorkshopService {
  final Map<String, UserModel> perfiles;
  final Duration retraso;
  int llamadas = 0;
  int enVuelo = 0;
  int maxEnVuelo = 0;

  _WorkshopServiceContador(this.perfiles, {this.retraso = Duration.zero})
    : super(firestore: FakeFirebaseFirestore());

  @override
  Future<UserModel?> getWorkshopById(String id) async {
    llamadas++;
    enVuelo++;
    if (enVuelo > maxEnVuelo) maxEnVuelo = enVuelo;
    if (retraso > Duration.zero) {
      await Future<void>.delayed(retraso);
    } else {
      await Future<void>.delayed(Duration.zero);
    }
    enVuelo--;
    return perfiles[id];
  }
}

void main() {
  late FakeFirebaseFirestore firestore;
  late VerificacionService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = VerificacionService(
      firestore: firestore,
      resolutorDeUrl: (ruta) async => 'https://storage.test/$ruta',
      ahora: () => DateTime.utc(2026, 3, 10),
    );
  });

  Future<void> sembrar(String id, String estado) =>
      firestore.collection('verificaciones').doc(id).set({
        'estado_verificacion': estado,
        'fecha_envio': Timestamp.fromDate(DateTime.utc(2026, 3, 2)),
        'documentos': {
          'fachada': {
            'nombre_archivo': 'fachada.jpg',
            'fecha': Timestamp.fromDate(DateTime.utc(2026, 3, 1)),
          },
        },
      });

  UserModel taller(String id, String nombre, {String? especialidad}) =>
      UserModel(
        idUsuario: id,
        nombreCompleto: nombre,
        correo: '$id@example.com',
        rol: 'Taller',
        fechaRegistro: DateTime.utc(2026, 1, 1),
        especialidad: especialidad,
      );

  test(
    'hidrata el nombre y la especialidad del taller de cada expediente',
    () async {
      await sembrar('HT8Hkxr', 'listo_para_revision');
      final workshopService = _WorkshopServiceContador({
        'HT8Hkxr': taller(
          'HT8Hkxr',
          'Taller Los Pinos',
          especialidad: 'Frenos',
        ),
      });
      final provider = AdminVerificacionProvider(
        service: service,
        workshopService: workshopService,
      );

      provider.escuchar();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final identidad = provider.identidadDe('HT8Hkxr');
      expect(identidad, isNotNull);
      expect(identidad!.nombreCompleto, 'Taller Los Pinos');
      expect(identidad.especialidad, 'Frenos');
    },
  );

  test('un taller sin perfil publico no rompe la hidratacion', () async {
    await sembrar('sin-perfil', 'en_revision');
    final workshopService = _WorkshopServiceContador({});
    final provider = AdminVerificacionProvider(
      service: service,
      workshopService: workshopService,
    );

    provider.escuchar();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(provider.identidadDe('sin-perfil'), isNull);
    expect(provider.bandeja, isNotEmpty);
  });

  test(
    'resuelve las identidades en paralelo, no una por una (sin N+1)',
    () async {
      await sembrar('a', 'listo_para_revision');
      await sembrar('b', 'en_revision');
      await sembrar('c', 'listo_para_revision');
      final workshopService = _WorkshopServiceContador({
        'a': taller('a', 'Taller A'),
        'b': taller('b', 'Taller B'),
        'c': taller('c', 'Taller C'),
      }, retraso: const Duration(milliseconds: 20));
      final provider = AdminVerificacionProvider(
        service: service,
        workshopService: workshopService,
      );

      provider.escuchar();
      await Future<void>.delayed(Duration.zero);
      // Deja que las tres resoluciones concurrentes terminen.
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(workshopService.llamadas, 3);
      expect(
        workshopService.maxEnVuelo,
        greaterThan(1),
        reason:
            'con un for+await secuencial nunca hay mas de una peticion en '
            'vuelo a la vez',
      );
      expect(provider.identidadDe('a')!.nombreCompleto, 'Taller A');
      expect(provider.identidadDe('b')!.nombreCompleto, 'Taller B');
      expect(provider.identidadDe('c')!.nombreCompleto, 'Taller C');
    },
  );

  test(
    'un taller ya resuelto no vuelve a consultarse cuando el stream reemite',
    () async {
      await sembrar('a', 'listo_para_revision');
      final workshopService = _WorkshopServiceContador({
        'a': taller('a', 'Taller A'),
      });
      final provider = AdminVerificacionProvider(
        service: service,
        workshopService: workshopService,
      );

      provider.escuchar();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(workshopService.llamadas, 1);

      // Un segundo expediente entra a la cola: el stream de
      // `observarBandeja` reemite con AMBOS documentos, no solo el nuevo.
      await sembrar('b', 'en_revision');
      workshopService.perfiles['b'] = taller('b', 'Taller B');
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(
        workshopService.llamadas,
        2,
        reason: '"a" ya estaba cacheado; solo "b" debia pedirse de nuevo',
      );
      expect(provider.identidadDe('a')!.nombreCompleto, 'Taller A');
      expect(provider.identidadDe('b')!.nombreCompleto, 'Taller B');
    },
  );
}
