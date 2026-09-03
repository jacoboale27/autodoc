// test/features/admin/presentation/providers/admin_verificacion_identidad_provider_test.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/models/user_model.dart';
import 'package:autodoc/features/admin/presentation/providers/admin_verificacion_provider.dart';
import 'package:autodoc/features/mechanic/data/services/verificacion_service.dart';
import 'package:autodoc/features/profile/data/services/user_service.dart';

/// Cuenta cuantas resoluciones estan "en vuelo" a la vez, para poder
/// distinguir `Future.wait` (paralelo) de un `for`+`await` secuencial (N+1):
/// secuencial nunca deja que `enVuelo` pase de 1.
class _UserServiceContador extends UserService {
  final Map<String, UserModel> perfiles;
  final Duration retraso;
  int llamadas = 0;
  int enVuelo = 0;
  int maxEnVuelo = 0;

  _UserServiceContador(this.perfiles, {this.retraso = Duration.zero})
    : super(firestore: FakeFirebaseFirestore());

  @override
  Future<UserModel?> getUserData(String userId) async {
    llamadas++;
    enVuelo++;
    if (enVuelo > maxEnVuelo) maxEnVuelo = enVuelo;
    if (retraso > Duration.zero) {
      await Future<void>.delayed(retraso);
    } else {
      await Future<void>.delayed(Duration.zero);
    }
    enVuelo--;
    return perfiles[userId];
  }
}

/// Deja cada resolucion "colgada" hasta que el test decide completarla, para
/// poder forzar deliberadamente una segunda reemision del stream MIENTRAS la
/// primera resolucion de un uid sigue en vuelo (el escenario real: Firestore
/// reemite dos veces al suscribirse, cache local y luego servidor).
class _UserServiceControlable extends UserService {
  final List<String> llamadas = [];
  final Map<String, Completer<UserModel?>> _pendientes = {};

  _UserServiceControlable() : super(firestore: FakeFirebaseFirestore());

  @override
  Future<UserModel?> getUserData(String userId) {
    llamadas.add(userId);
    final completer = Completer<UserModel?>();
    _pendientes[userId] = completer;
    return completer.future;
  }

  void completar(String id, UserModel? perfil) {
    _pendientes.remove(id)!.complete(perfil);
  }

  void fallar(String id, Object error) {
    _pendientes.remove(id)!.completeError(error);
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

  test('hidrata el nombre, la especialidad y el correo del taller de cada '
      'expediente', () async {
    await sembrar('HT8Hkxr', 'listo_para_revision');
    final userService = _UserServiceContador({
      'HT8Hkxr': taller('HT8Hkxr', 'Taller Los Pinos', especialidad: 'Frenos'),
    });
    final provider = AdminVerificacionProvider(
      service: service,
      userService: userService,
    );

    provider.escuchar();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final identidad = provider.identidadDe('HT8Hkxr');
    expect(identidad, isNotNull);
    expect(identidad!.nombreCompleto, 'Taller Los Pinos');
    expect(identidad.especialidad, 'Frenos');
    // El hallazgo #11 que cierra esta tarea: el correo debe llegar con la
    // identidad, no solo el nombre y la especialidad que ya se pintaban.
    expect(identidad.correo, isNotEmpty);
    expect(identidad.correo, 'HT8Hkxr@example.com');
  });

  test('un taller sin perfil publico no rompe la hidratacion', () async {
    await sembrar('sin-perfil', 'en_revision');
    final userService = _UserServiceContador({});
    final provider = AdminVerificacionProvider(
      service: service,
      userService: userService,
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
      final userService = _UserServiceContador({
        'a': taller('a', 'Taller A'),
        'b': taller('b', 'Taller B'),
        'c': taller('c', 'Taller C'),
      }, retraso: const Duration(milliseconds: 20));
      final provider = AdminVerificacionProvider(
        service: service,
        userService: userService,
      );

      provider.escuchar();
      await Future<void>.delayed(Duration.zero);
      // Deja que las tres resoluciones concurrentes terminen.
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(userService.llamadas, 3);
      expect(
        userService.maxEnVuelo,
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
      final userService = _UserServiceContador({'a': taller('a', 'Taller A')});
      final provider = AdminVerificacionProvider(
        service: service,
        userService: userService,
      );

      provider.escuchar();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(userService.llamadas, 1);

      // Un segundo expediente entra a la cola: el stream de
      // `observarBandeja` reemite con AMBOS documentos, no solo el nuevo.
      await sembrar('b', 'en_revision');
      userService.perfiles['b'] = taller('b', 'Taller B');
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(
        userService.llamadas,
        2,
        reason: '"a" ya estaba cacheado; solo "b" debia pedirse de nuevo',
      );
      expect(provider.identidadDe('a')!.nombreCompleto, 'Taller A');
      expect(provider.identidadDe('b')!.nombreCompleto, 'Taller B');
    },
  );

  test('un uid en vuelo no se vuelve a pedir si el stream reemite antes de que '
      'la primera resolucion termine', () async {
    await sembrar('a', 'listo_para_revision');
    final userService = _UserServiceControlable();
    final provider = AdminVerificacionProvider(
      service: service,
      userService: userService,
    );

    provider.escuchar();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    // La resolucion de 'a' esta en vuelo (el completer no se ha resuelto
    // todavia): esto es justo la ventana que una segunda emision (cache +
    // servidor, o cualquier reemision no relacionada) puede pisar.
    expect(userService.llamadas, ['a']);

    await firestore.collection('verificaciones').doc('a').update({
      'fecha_envio': Timestamp.fromDate(DateTime.utc(2026, 3, 3)),
    });
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(
      userService.llamadas,
      ['a'],
      reason:
          '"a" seguia en vuelo cuando el stream reemitio; no debia '
          'volver a pedirse una segunda vez',
    );

    userService.completar('a', taller('a', 'Taller A'));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(provider.identidadDe('a')!.nombreCompleto, 'Taller A');
  });

  test(
    'un fallo al resolver no bloquea reintentos futuros para ese uid',
    () async {
      await sembrar('a', 'listo_para_revision');
      final userService = _UserServiceControlable();
      final provider = AdminVerificacionProvider(
        service: service,
        userService: userService,
      );

      provider.escuchar();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(userService.llamadas, ['a']);

      userService.fallar('a', Exception('boom'));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(
        provider.identidadDe('a'),
        isNull,
        reason: 'un fallo no debe dejar una entrada falsa en el cache',
      );

      // El stream reemite; como el intento anterior fallo (y salio de
      // "en vuelo" en el finally), 'a' debe poder pedirse de nuevo.
      await firestore.collection('verificaciones').doc('a').update({
        'fecha_envio': Timestamp.fromDate(DateTime.utc(2026, 3, 4)),
      });
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(userService.llamadas, ['a', 'a']);

      userService.completar('a', taller('a', 'Taller A'));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(provider.identidadDe('a')!.nombreCompleto, 'Taller A');
    },
  );
}
