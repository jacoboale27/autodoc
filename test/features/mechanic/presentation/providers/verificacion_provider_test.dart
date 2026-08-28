import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/models/estado_verificacion.dart';
import 'package:autodoc/core/models/user_model.dart';
import 'package:autodoc/features/mechanic/data/services/verificacion_service.dart';
import 'package:autodoc/features/mechanic/presentation/providers/verificacion_provider.dart';

UserModel taller({String? telefono = '+503 7777-8888'}) => UserModel(
  idUsuario: 'taller-1',
  nombreCompleto: 'Taller El Buen Motor',
  correo: 'taller@example.com',
  rol: 'Taller',
  fechaRegistro: DateTime(2026, 1, 1),
  telefono: telefono,
  especialidad: 'Frenos',
  departamento: 'San Salvador',
  municipio: 'Soyapango',
  latitud: 13.69,
  longitud: -89.19,
  estado: 'pendiente',
);

void main() {
  late FakeFirebaseFirestore firestore;
  late VerificacionProvider provider;
  late List<String> rutasSubidas;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    rutasSubidas = [];
    provider = VerificacionProvider(
      service: VerificacionService(
        firestore: firestore,
        subidor:
            ({
              required String ruta,
              required Uint8List bytes,
              required String contentType,
            }) async => rutasSubidas.add(ruta),
        ahora: () => DateTime.utc(2026, 3, 10),
      ),
    );
  });

  Future<void> sembrar(Map<String, dynamic> datos) =>
      firestore.collection('verificaciones').doc('taller-1').set(datos);

  Map<String, dynamic> conFachada() => {
    'documentos': {
      'fachada': {
        'nombre_archivo': 'fachada.jpg',
        'fecha': Timestamp.fromDate(DateTime.utc(2026, 3, 1)),
      },
    },
  };

  test('un taller sin expediente arranca en perfilIncompleto', () async {
    await provider.cargar('taller-1');

    expect(provider.estado, EstadoVerificacion.perfilIncompleto);
    expect(provider.cargando, isFalse);
    expect(provider.error, isNull);
  });

  group('puedeEnviar', () {
    test('exige perfil completo Y evidencia mínima', () async {
      await provider.cargar('taller-1');
      // Perfil completo pero sin evidencia.
      expect(provider.puedeEnviar(taller()), isFalse);

      await sembrar(conFachada());
      await provider.cargar('taller-1');
      // Evidencia pero perfil incompleto.
      expect(provider.puedeEnviar(taller(telefono: '')), isFalse);
      // Las dos cosas.
      expect(provider.puedeEnviar(taller()), isTrue);
    });

    test('no deja reenviar un expediente ya enviado', () async {
      await sembrar({
        'estado_verificacion': 'listo_para_revision',
        ...conFachada(),
      });
      await provider.cargar('taller-1');

      expect(provider.puedeEnviar(taller()), isFalse);
    });

    test('sí deja reenviar uno rechazado', () async {
      await sembrar({'estado_verificacion': 'rechazada', ...conFachada()});
      await provider.cargar('taller-1');

      expect(provider.puedeEnviar(taller()), isTrue);
    });

    test('sin perfil cargado no se puede enviar', () async {
      await sembrar(conFachada());
      await provider.cargar('taller-1');

      expect(provider.puedeEnviar(null), isFalse);
    });
  });

  test(
    'subir evidencia refresca el expediente y no deja spinner colgado',
    () async {
      await provider.cargar('taller-1');

      final ok = await provider.subirEvidencia(
        tallerId: 'taller-1',
        slot: 'fachada',
        nombreOriginal: 'foto.jpg',
        bytes: Uint8List.fromList([1]),
      );

      expect(ok, isTrue);
      expect(rutasSubidas, ['verificaciones/taller-1/fachada.jpg']);
      expect(provider.slotEnCurso, isNull);
      expect(provider.expediente!.tieneEvidenciaMinima, isTrue);
    },
  );

  test(
    'un archivo no válido deja un error legible, no una excepción',
    () async {
      await provider.cargar('taller-1');

      final ok = await provider.subirEvidencia(
        tallerId: 'taller-1',
        slot: 'fachada',
        nombreOriginal: 'local.pdf',
        bytes: Uint8List.fromList([1]),
      );

      expect(ok, isFalse);
      expect(provider.error, contains('Formatos aceptados'));
      expect(provider.slotEnCurso, isNull);
    },
  );

  test('enviar a revisión avanza el estado', () async {
    await sembrar(conFachada());
    await provider.cargar('taller-1');

    final ok = await provider.enviarARevision(
      tallerId: 'taller-1',
      perfil: taller(),
    );

    expect(ok, isTrue);
    expect(provider.estado, EstadoVerificacion.listoParaRevision);
    expect(provider.enviando, isFalse);
  });

  test('un archivo de más de 5 MB se rechaza antes de tocar Storage', () async {
    await provider.cargar('taller-1');

    final ok = await provider.subirEvidencia(
      tallerId: 'taller-1',
      slot: 'fachada',
      nombreOriginal: 'foto.jpg',
      bytes: Uint8List(5 * 1024 * 1024),
    );

    expect(ok, isFalse);
    expect(provider.error, contains('5 MB'));
    expect(
      rutasSubidas,
      isEmpty,
      reason:
          'storage.rules lo iba a denegar igual, pero con un '
          '«unauthorized» que no dice por qué',
    );
  });

  group('mensajes de error de un fallo inesperado', () {
    /// Provider cuyo subidor falla con [fallo], para fijar el texto que ve el
    /// taller ante cada clase de error.
    VerificacionProvider conSubidorQueFalla(Object fallo) =>
        VerificacionProvider(
          service: VerificacionService(
            firestore: firestore,
            subidor:
                ({
                  required String ruta,
                  required Uint8List bytes,
                  required String contentType,
                }) async => throw fallo,
            ahora: () => DateTime.utc(2026, 3, 10),
          ),
        );

    Future<String?> errorAlSubir(Object fallo) async {
      final p = conSubidorQueFalla(fallo);
      await p.cargar('taller-1');
      await p.subirEvidencia(
        tallerId: 'taller-1',
        slot: 'fachada',
        nombreOriginal: 'foto.jpg',
        bytes: Uint8List.fromList([1]),
      );
      return p.error;
    }

    test('un rechazo de Storage NO se presenta como fallo de red', () async {
      final error = await errorAlSubir(
        FirebaseException(plugin: 'firebase_storage', code: 'unauthorized'),
      );

      expect(error, isNotNull);
      expect(
        error,
        isNot(contains('Revisa tu conexión')),
        reason:
            'mandar a mirar la red ante un unauthorized fue lo que hizo '
            'perder el rastro: el problema está en las reglas desplegadas',
      );
      expect(error, contains('No es tu conexión'));
      expect(
        error,
        contains('permiso'),
        reason:
            'y tampoco debe culpar al peso: el límite de 5 MB ya se '
            'comprueba antes de salir a la red',
      );
      expect(error, isNot(contains('MB')));
    });

    test('un timeout de subida sí habla de la conexión', () async {
      final error = await errorAlSubir(
        FirebaseException(
          plugin: 'firebase_storage',
          code: 'retry-limit-exceeded',
        ),
      );

      expect(error, contains('conexión'));
    });

    test(
      'un código desconocido llega al mensaje, para poder reportarlo',
      () async {
        final error = await errorAlSubir(
          FirebaseException(
            plugin: 'firebase_storage',
            code: 'object-not-found',
          ),
        );

        expect(error, contains('object-not-found'));
      },
    );

    test('un error que no es de Firebase no se disfraza de red', () async {
      final error = await errorAlSubir(StateError('boom'));

      expect(error, contains('boom'));
      expect(error, isNot(contains('conexión')));
    });
  });

  test('enviar con el perfil incompleto dice qué falta', () async {
    await sembrar(conFachada());
    await provider.cargar('taller-1');

    final ok = await provider.enviarARevision(
      tallerId: 'taller-1',
      perfil: taller(telefono: ''),
    );

    expect(ok, isFalse);
    expect(provider.error, contains('Teléfono'));
    expect(provider.estado, EstadoVerificacion.perfilIncompleto);
  });
}
