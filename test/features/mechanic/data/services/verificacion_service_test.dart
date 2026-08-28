import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/models/estado_verificacion.dart';
import 'package:autodoc/core/theme/app_estado_cuenta.dart';
import 'package:autodoc/core/models/user_model.dart';
import 'package:autodoc/features/mechanic/data/services/verificacion_service.dart';

/// Registra las subidas en memoria en lugar de tocar Firebase Storage.
///
/// Es la contrapartida de la costura `SubidorDeEvidencia`: lo que interesa
/// verificar es que se sube a la ruta correcta y con el content-type correcto,
/// no que Storage funcione.
class SubidorEspia {
  final List<({String ruta, String contentType, int bytes})> subidas = [];
  Object? errorAlSubir;

  Future<void> call({
    required String ruta,
    required Uint8List bytes,
    required String contentType,
  }) async {
    if (errorAlSubir != null) throw errorAlSubir!;
    subidas.add((ruta: ruta, contentType: contentType, bytes: bytes.length));
  }
}

UserModel tallerCompleto({String? telefono = '+503 7777-8888'}) => UserModel(
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
  late SubidorEspia subidor;
  late VerificacionService service;

  final ahora = DateTime.utc(2026, 3, 10, 12);

  setUp(() {
    firestore = FakeFirebaseFirestore();
    subidor = SubidorEspia();
    service = VerificacionService(
      firestore: firestore,
      subidor: subidor.call,
      ahora: () => ahora,
    );
  });

  Future<void> sembrarExpediente(Map<String, dynamic> datos) async {
    await firestore.collection('verificaciones').doc('taller-1').set(datos);
  }

  Map<String, dynamic> fachadaSubida() => {
    'fachada': {
      'nombre_archivo': 'fachada.jpg',
      'fecha': Timestamp.fromDate(DateTime.utc(2026, 3, 1)),
    },
  };

  group('obtener', () {
    test('un taller sin expediente sale como perfilIncompleto vacío', () async {
      final expediente = await service.obtener('taller-1');

      expect(expediente.idTaller, 'taller-1');
      expect(expediente.estado, EstadoVerificacion.perfilIncompleto);
      expect(expediente.documentos, isEmpty);
    });
  });

  group('subirEvidencia', () {
    test('sube a la ruta canónica y anota el slot en el expediente', () async {
      await service.subirEvidencia(
        tallerId: 'taller-1',
        slot: 'fachada',
        nombreOriginal: 'IMG_0042.JPEG',
        bytes: Uint8List.fromList([1, 2, 3]),
      );

      // El nombre original no manda: el objeto se guarda siempre como
      // {slot}.{extension}, que es lo unico que aceptan las reglas de Storage.
      expect(
        subidor.subidas.single.ruta,
        'verificaciones/taller-1/fachada.jpg',
      );
      expect(subidor.subidas.single.contentType, 'image/jpeg');

      final expediente = await service.obtener('taller-1');
      expect(expediente.documentos['fachada']!.nombreArchivo, 'fachada.jpg');
      expect(expediente.tieneEvidenciaMinima, isTrue);
    });

    test('acepta PDF para el NIT con su content-type', () async {
      await service.subirEvidencia(
        tallerId: 'taller-1',
        slot: 'nit',
        nombreOriginal: 'registro fiscal.pdf',
        bytes: Uint8List.fromList([1]),
      );

      expect(subidor.subidas.single.ruta, 'verificaciones/taller-1/nit.pdf');
      expect(subidor.subidas.single.contentType, 'application/pdf');
    });

    test('rechaza un PDF como foto de fachada', () async {
      await expectLater(
        service.subirEvidencia(
          tallerId: 'taller-1',
          slot: 'fachada',
          nombreOriginal: 'local.pdf',
          bytes: Uint8List.fromList([1]),
        ),
        throwsA(isA<VerificacionException>()),
      );

      expect(subidor.subidas, isEmpty);
    });

    test('rechaza un slot que no existe', () async {
      await expectLater(
        service.subirEvidencia(
          tallerId: 'taller-1',
          slot: 'lo_que_sea',
          nombreOriginal: 'x.jpg',
          bytes: Uint8List.fromList([1]),
        ),
        throwsA(isA<VerificacionException>()),
      );
    });

    test('si falla Storage no deja el expediente mintiendo', () async {
      subidor.errorAlSubir = Exception('sin red');

      await expectLater(
        service.subirEvidencia(
          tallerId: 'taller-1',
          slot: 'fachada',
          nombreOriginal: 'x.jpg',
          bytes: Uint8List.fromList([1]),
        ),
        throwsA(isA<Exception>()),
      );

      final expediente = await service.obtener('taller-1');
      expect(expediente.documentos, isEmpty);
    });

    test('resubir el mismo slot sobrescribe en vez de acumular', () async {
      for (final nombre in ['a.jpg', 'b.png']) {
        await service.subirEvidencia(
          tallerId: 'taller-1',
          slot: 'rotulo',
          nombreOriginal: nombre,
          bytes: Uint8List.fromList([1]),
        );
      }

      final expediente = await service.obtener('taller-1');
      expect(expediente.documentos.keys, ['rotulo']);
      expect(expediente.documentos['rotulo']!.nombreArchivo, 'rotulo.png');
    });

    test('subir un slot no borra los otros', () async {
      await sembrarExpediente({'documentos': fachadaSubida()});

      await service.subirEvidencia(
        tallerId: 'taller-1',
        slot: 'nit',
        nombreOriginal: 'nit.png',
        bytes: Uint8List.fromList([1]),
      );

      final expediente = await service.obtener('taller-1');
      expect(expediente.documentos.keys, containsAll(['fachada', 'nit']));
    });
  });

  group('enviarARevision', () {
    test('sella la fecha de envío y pasa a listoParaRevision', () async {
      await sembrarExpediente({'documentos': fachadaSubida()});

      await service.enviarARevision(
        tallerId: 'taller-1',
        perfil: tallerCompleto(),
      );

      final expediente = await service.obtener('taller-1');
      expect(expediente.estado, EstadoVerificacion.listoParaRevision);
      expect(expediente.fechaEnvio!.isAtSameMomentAs(ahora), isTrue);
    });

    test('se niega si falta un campo del perfil y dice cuál', () async {
      await sembrarExpediente({'documentos': fachadaSubida()});

      await expectLater(
        service.enviarARevision(
          tallerId: 'taller-1',
          perfil: tallerCompleto(telefono: ''),
        ),
        throwsA(
          isA<VerificacionException>().having(
            (e) => e.mensaje,
            'mensaje',
            contains('Teléfono'),
          ),
        ),
      );

      final expediente = await service.obtener('taller-1');
      expect(expediente.estado, EstadoVerificacion.perfilIncompleto);
    });

    test(
      'se niega sin la foto de fachada aunque el perfil esté completo',
      () async {
        await expectLater(
          service.enviarARevision(
            tallerId: 'taller-1',
            perfil: tallerCompleto(),
          ),
          throwsA(
            isA<VerificacionException>().having(
              (e) => e.mensaje,
              'mensaje',
              contains('fachada'),
            ),
          ),
        );
      },
    );

    test('un reenvío tras rechazo borra el motivo y los datos de la '
        'resolución anterior', () async {
      // Sin esto el taller seguiria viendo para siempre por que le rechazaron
      // la version que acaba de corregir. Ademas firestore.rules deniega un
      // write del taller cuyo documento RESULTANTE tenga esas claves, asi que
      // deben borrarse de verdad, no ponerse a null.
      await sembrarExpediente({
        'estado_verificacion': 'rechazada',
        'motivo_rechazo': 'La foto del rótulo no es legible',
        'revisado_por': 'admin-9',
        'fecha_revision': Timestamp.fromDate(DateTime.utc(2026, 3, 5)),
        'documentos': fachadaSubida(),
      });

      await service.enviarARevision(
        tallerId: 'taller-1',
        perfil: tallerCompleto(),
      );

      final crudo =
          (await firestore.collection('verificaciones').doc('taller-1').get())
              .data()!;

      expect(crudo.containsKey('motivo_rechazo'), isFalse);
      expect(crudo.containsKey('revisado_por'), isFalse);
      expect(crudo.containsKey('fecha_revision'), isFalse);
      expect(crudo['estado_verificacion'], 'listo_para_revision');
    });

    test(
      'no se puede reenviar un expediente que ya está en revisión',
      () async {
        await sembrarExpediente({
          'estado_verificacion': 'en_revision',
          'documentos': fachadaSubida(),
        });

        await expectLater(
          service.enviarARevision(
            tallerId: 'taller-1',
            perfil: tallerCompleto(),
          ),
          throwsA(isA<VerificacionException>()),
        );
      },
    );
  });

  group('resolución del administrador', () {
    Future<void> ponerEnRevision() async {
      await sembrarExpediente({
        'estado_verificacion': 'listo_para_revision',
        'documentos': fachadaSubida(),
      });
      await service.tomarCaso(tallerId: 'taller-1', adminUid: 'admin-9');
    }

    test('un caso solo se resuelve después de tomarlo', () async {
      await sembrarExpediente({
        'estado_verificacion': 'listo_para_revision',
        'documentos': fachadaSubida(),
      });

      // Resolver en caliente saltaria el paso que impide que dos
      // administradores trabajen el mismo expediente a la vez.
      await expectLater(
        service.aprobar(tallerId: 'taller-1', adminUid: 'admin-9'),
        throwsA(isA<VerificacionException>()),
      );

      await service.tomarCaso(tallerId: 'taller-1', adminUid: 'admin-9');
      await service.aprobar(tallerId: 'taller-1', adminUid: 'admin-9');

      final expediente = await service.obtener('taller-1');
      expect(expediente.estado, EstadoVerificacion.aprobada);
      expect(expediente.revisadoPor, 'admin-9');
    });

    test('aprobar abre la cuenta del taller en la misma escritura', () async {
      // El bug que esto cierra: cuando eran dos acciones, el admin aprobaba el
      // expediente, daba por hecho que habia terminado, y el taller no entraba
      // nunca porque nadie habia tocado usuarios.estado.
      await firestore.collection('usuarios').doc('taller-1').set({
        'rol': 'Taller',
        'estado': 'pendiente',
      });
      await ponerEnRevision();

      await service.aprobar(tallerId: 'taller-1', adminUid: 'admin-9');

      final usuario =
          (await firestore.collection('usuarios').doc('taller-1').get())
              .data()!;
      expect(usuario['estado'], AppEstadoCuenta.valorAprobado);
      expect(
        AppEstadoCuenta.esAprobada(usuario['estado'] as String),
        isTrue,
        reason: 'debe caer en el mismo conjunto que lee isMecanico()',
      );
      // Y no arrasa el resto del documento.
      expect(usuario['rol'], 'Taller');
    });

    test('aprobar deja la entrada de auditoria firmada por el admin', () async {
      await ponerEnRevision();

      await service.aprobar(tallerId: 'taller-1', adminUid: 'admin-9');

      final logs = await firestore.collection('admin_logs').get();
      final log = logs.docs.single.data();
      expect(log['accion'], 'APROBAR_VERIFICACION');
      expect(log['referencia_id'], 'taller-1');
      // firestore.rules exige que admin_uid coincida con el llamante.
      expect(log['admin_uid'], 'admin-9');
    });

    test('una transicion ilegal no toca NADA', () async {
      // Si la validacion se hiciera despues de empezar a escribir, un rechazo
      // invalido podria dejar la cuenta cerrada con el expediente intacto.
      await firestore.collection('usuarios').doc('taller-1').set({
        'estado': 'pendiente',
      });
      await sembrarExpediente({
        'estado_verificacion': 'listo_para_revision',
        'documentos': fachadaSubida(),
      });

      await expectLater(
        service.aprobar(tallerId: 'taller-1', adminUid: 'admin-9'),
        throwsA(isA<VerificacionException>()),
      );

      expect(
        (await firestore.collection('usuarios').doc('taller-1').get())
            .data()!['estado'],
        'pendiente',
      );
      expect((await firestore.collection('admin_logs').get()).docs, isEmpty);
    });

    test(
      'rechazar deja la cuenta en rechazado, pero NO expulsa al taller',
      () async {
        // 'rechazado' esta fuera de AppEstadoCuenta.aprobados, asi que el taller
        // queda retenido en el onboarding y puede corregir y reenviar. Si esto
        // dejase la cuenta aprobada, un rechazo no serviria de nada.
        await firestore.collection('usuarios').doc('taller-1').set({
          'estado': 'pendiente',
        });
        await ponerEnRevision();

        await service.rechazar(
          tallerId: 'taller-1',
          adminUid: 'admin-9',
          motivo: 'La fachada no deja ver el rótulo',
        );

        final estado =
            (await firestore.collection('usuarios').doc('taller-1').get())
                    .data()!['estado']
                as String;
        expect(estado, AppEstadoCuenta.valorRechazado);
        expect(AppEstadoCuenta.esAprobada(estado), isFalse);
      },
    );

    test('rechazar guarda el motivo y quién revisó', () async {
      await ponerEnRevision();

      await service.rechazar(
        tallerId: 'taller-1',
        adminUid: 'admin-9',
        motivo: '  La dirección no coincide con la fachada  ',
      );

      final expediente = await service.obtener('taller-1');
      expect(expediente.estado, EstadoVerificacion.rechazada);
      expect(
        expediente.motivoRechazo,
        'La dirección no coincide con la fachada',
      );
      expect(expediente.revisadoPor, 'admin-9');
      expect(expediente.fechaRevision!.isAtSameMomentAs(ahora), isTrue);
    });

    test('no se puede rechazar sin motivo', () async {
      await ponerEnRevision();

      for (final motivo in ['', '   ']) {
        await expectLater(
          service.rechazar(
            tallerId: 'taller-1',
            adminUid: 'admin-9',
            motivo: motivo,
          ),
          throwsA(isA<VerificacionException>()),
        );
      }

      final expediente = await service.obtener('taller-1');
      expect(expediente.estado, EstadoVerificacion.enRevision);
    });

    test('aprobar limpia el motivo de un rechazo anterior', () async {
      await sembrarExpediente({
        'estado_verificacion': 'rechazada',
        'motivo_rechazo': 'Faltaba el rótulo',
        'documentos': fachadaSubida(),
      });

      // rechazada -> listo_para_revision -> en_revision -> aprobada
      await service.enviarARevision(
        tallerId: 'taller-1',
        perfil: tallerCompleto(),
      );
      await service.tomarCaso(tallerId: 'taller-1', adminUid: 'admin-9');
      await service.aprobar(tallerId: 'taller-1', adminUid: 'admin-9');

      final expediente = await service.obtener('taller-1');
      expect(expediente.motivoRechazo, isNull);
    });

    test('un administrador no toma un expediente ya aprobado', () async {
      // La re-revisión no empieza aquí. Un expediente aprobado vuelve a la
      // COLA, y solo la reabre la Cloud Function cuando el taller cambia
      // datos verificados (functions/src/reabrirVerificacion.js). Si un
      // administrador pudiera saltar de 'aprobada' a 'en_revision' con un
      // clic, tendría en la mano una forma de retirar una verificación
      // concedida sin que nada la hubiera puesto en duda.
      await sembrarExpediente({
        'estado_verificacion': 'aprobada',
        'documentos': fachadaSubida(),
      });

      await expectLater(
        service.tomarCaso(tallerId: 'taller-1', adminUid: 'admin-9'),
        throwsA(isA<VerificacionException>()),
      );

      final expediente = await service.obtener('taller-1');
      expect(expediente.estado, EstadoVerificacion.aprobada);
    });

    test('un expediente reabierto se toma y se resuelve como cualquier '
        'otro', () async {
      // Es el estado en el que la Cloud Function deja el expediente: en la
      // cola, sin dueño y con el motivo escrito. A partir de ahí el flujo del
      // administrador es exactamente el mismo que en un alta.
      await sembrarExpediente({
        'estado_verificacion': 'listo_para_revision',
        'documentos': fachadaSubida(),
        'reapertura': {
          'fecha': Timestamp.fromDate(DateTime.utc(2026, 8, 27)),
          'campos': ['Dirección'],
        },
      });

      final reabierto = await service.obtener('taller-1');
      expect(reabierto.esReRevision, isTrue);

      await service.tomarCaso(tallerId: 'taller-1', adminUid: 'admin-9');
      await service.aprobar(tallerId: 'taller-1', adminUid: 'admin-9');

      final resuelto = await service.obtener('taller-1');
      expect(resuelto.estado, EstadoVerificacion.aprobada);
      // Y la cuenta sigue habilitada: la re-revisión nunca la cerró.
      final usuario = await firestore
          .collection('usuarios')
          .doc('taller-1')
          .get();
      expect(usuario.data()!['estado'], AppEstadoCuenta.valorAprobado);
    });
  });

  group('observarBandeja', () {
    test('trae los pendientes y los abiertos, más antiguo primero', () async {
      final coleccion = firestore.collection('verificaciones');
      await coleccion.doc('nuevo').set({
        'estado_verificacion': 'listo_para_revision',
        'fecha_envio': Timestamp.fromDate(DateTime.utc(2026, 3, 9)),
      });
      await coleccion.doc('viejo').set({
        'estado_verificacion': 'listo_para_revision',
        'fecha_envio': Timestamp.fromDate(DateTime.utc(2026, 3, 1)),
      });
      // Un caso abierto y sin resolver NO puede desaparecer de la bandeja: si
      // no, nadie volveria a mirarlo nunca.
      await coleccion.doc('abierto').set({
        'estado_verificacion': 'en_revision',
        'fecha_envio': Timestamp.fromDate(DateTime.utc(2026, 3, 5)),
      });
      await coleccion.doc('resuelto').set({
        'estado_verificacion': 'aprobada',
        'fecha_envio': Timestamp.fromDate(DateTime.utc(2026, 2, 1)),
      });

      final bandeja = await service.observarBandeja().first;

      expect(bandeja.map((e) => e.idTaller), ['viejo', 'abierto', 'nuevo']);
    });
  });
}
