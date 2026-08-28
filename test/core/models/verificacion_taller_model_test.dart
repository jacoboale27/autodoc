import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/models/estado_verificacion.dart';
import 'package:autodoc/core/models/verificacion_taller_model.dart';

/// Compara dos [DateTime] por el instante que representan, ignorando si uno
/// esta en UTC y el otro en local.
///
/// Hace falta porque `Timestamp.toDate()` siempre devuelve zona local y el
/// `==` de `DateTime` exige que coincida ademas el flag `isUtc`, asi que
/// `DateTime.utc(2026, 3, 1)` y su equivalente local NO son `==` aunque sean
/// el mismo momento.
Matcher isAtSameInstant(DateTime esperado) => predicate<DateTime?>(
  (real) => real != null && real.isAtSameMomentAs(esperado),
  'el mismo instante que $esperado',
);

Map<String, dynamic> documentoCrudo(String nombreArchivo, {DateTime? fecha}) =>
    {
      'nombre_archivo': nombreArchivo,
      'fecha': Timestamp.fromDate(fecha ?? DateTime.utc(2026, 3, 1)),
    };

void main() {
  group('VerificacionTallerModel.fromMap', () {
    test('lee un expediente resuelto completo', () {
      final map = <String, dynamic>{
        'id_taller': 'taller-1',
        'estado_verificacion': 'rechazada',
        'fecha_envio': Timestamp.fromDate(DateTime.utc(2026, 3, 1)),
        'fecha_revision': Timestamp.fromDate(DateTime.utc(2026, 3, 2)),
        'motivo_rechazo': 'La foto del rótulo no es legible',
        'revisado_por': 'admin-9',
        'documentos': {'fachada': documentoCrudo('fachada.jpg')},
      };

      final verificacion = VerificacionTallerModel.fromMap(map, 'taller-1');

      expect(verificacion.idTaller, 'taller-1');
      expect(verificacion.estado, EstadoVerificacion.rechazada);
      // `Timestamp.toDate()` devuelve la fecha en zona LOCAL, y el `==` de
      // DateTime compara tambien el flag `isUtc`: el instante es el mismo pero
      // los objetos no son iguales. Se compara el instante, que es lo que
      // importa, igual que hace `UserModel.parseDate`.
      expect(
        verificacion.fechaEnvio,
        isAtSameInstant(DateTime.utc(2026, 3, 1)),
      );
      expect(
        verificacion.fechaRevision,
        isAtSameInstant(DateTime.utc(2026, 3, 2)),
      );
      expect(verificacion.motivoRechazo, 'La foto del rótulo no es legible');
      expect(verificacion.revisadoPor, 'admin-9');
      expect(verificacion.documentos.keys, ['fachada']);
      expect(verificacion.documentos['fachada']!.nombreArchivo, 'fachada.jpg');
    });

    test(
      'un documento inexistente arranca en perfilIncompleto, no explota',
      () {
        final verificacion = VerificacionTallerModel.fromMap(
          {},
          'taller-nuevo',
        );

        expect(verificacion.idTaller, 'taller-nuevo');
        expect(verificacion.estado, EstadoVerificacion.perfilIncompleto);
        expect(verificacion.fechaEnvio, isNull);
        expect(verificacion.fechaRevision, isNull);
        expect(verificacion.motivoRechazo, isNull);
        expect(verificacion.revisadoPor, isNull);
        expect(verificacion.documentos, isEmpty);
      },
    );

    test('cae al documentId cuando id_taller no viaja en el payload', () {
      final verificacion = VerificacionTallerModel.fromMap({
        'estado_verificacion': 'en_revision',
      }, 'doc-id');

      expect(verificacion.idTaller, 'doc-id');
    });

    test('descarta slots de documento con nombre desconocido', () {
      // Storage solo acepta los 3 nombres fijos (ver storage.rules); un slot
      // fuera de esa lista solo puede venir de un write manipulado.
      final verificacion = VerificacionTallerModel.fromMap({
        'documentos': {
          'nit': documentoCrudo('nit.pdf'),
          'lo_que_sea': documentoCrudo('lo_que_sea.jpg'),
        },
      }, 'taller-1');

      expect(verificacion.documentos.keys, ['nit']);
    });
  });

  group('validacion del nombre de archivo (seguridad)', () {
    // `documentos` lo escribe el propio taller y la pantalla del admin lo
    // convierte en una ruta de Storage que lee con permisos de admin. Un
    // nombre no validado seria un salto de ruta hacia cualquier objeto del
    // bucket.
    test('rechaza un salto de ruta disfrazado de nombre de archivo', () {
      final verificacion = VerificacionTallerModel.fromMap({
        'documentos': {
          'fachada': documentoCrudo('../../perfiles/otra-victima.jpg'),
        },
      }, 'taller-1');

      expect(verificacion.documentos, isEmpty);
    });

    test('rechaza un nombre que no corresponde a su propio slot', () {
      final verificacion = VerificacionTallerModel.fromMap({
        'documentos': {'fachada': documentoCrudo('nit.pdf')},
      }, 'taller-1');

      expect(verificacion.documentos, isEmpty);
    });

    test('el PDF solo vale para el NIT, no para las fotos', () {
      expect(VerificacionTallerModel.esNombreValido('nit', 'nit.pdf'), isTrue);
      expect(
        VerificacionTallerModel.esNombreValido('fachada', 'fachada.pdf'),
        isFalse,
      );
      expect(
        VerificacionTallerModel.esNombreValido('rotulo', 'rotulo.pdf'),
        isFalse,
      );
    });

    test('rechaza una entrada sin fecha o mal formada', () {
      final verificacion = VerificacionTallerModel.fromMap({
        'documentos': {
          'fachada': {'nombre_archivo': 'fachada.jpg'},
          'rotulo': 'esto no es un mapa',
        },
      }, 'taller-1');

      expect(verificacion.documentos, isEmpty);
    });

    test('la ruta de Storage se deriva del uid, no de nada que venga en el '
        'payload', () {
      final documento = DocumentoEvidencia(
        slot: 'fachada',
        nombreArchivo: 'fachada.jpg',
        fecha: DateTime.utc(2026, 3, 1),
      );

      expect(
        documento.rutaEn('taller-1'),
        'verificaciones/taller-1/fachada.jpg',
      );
    });
  });

  group('VerificacionTallerModel.toMap', () {
    test('serializa fechas como Timestamp y omite los nulos', () {
      final verificacion = VerificacionTallerModel(
        idTaller: 'taller-1',
        estado: EstadoVerificacion.listoParaRevision,
        fechaEnvio: DateTime.utc(2026, 3, 1),
      );

      final map = verificacion.toMap();

      expect(map['id_taller'], 'taller-1');
      expect(map['estado_verificacion'], 'listo_para_revision');
      expect(map['fecha_envio'], isA<Timestamp>());
      expect(
        (map['fecha_envio'] as Timestamp).toDate(),
        isAtSameInstant(DateTime.utc(2026, 3, 1)),
      );
      expect(map.containsKey('fecha_revision'), isFalse);
      expect(map.containsKey('motivo_rechazo'), isFalse);
      expect(map.containsKey('revisado_por'), isFalse);
    });

    test('el viaje de ida y vuelta conserva el expediente', () {
      final original = VerificacionTallerModel(
        idTaller: 'taller-1',
        estado: EstadoVerificacion.aprobada,
        fechaEnvio: DateTime.utc(2026, 3, 1),
        fechaRevision: DateTime.utc(2026, 3, 4),
        revisadoPor: 'admin-9',
        documentos: {
          'rotulo': DocumentoEvidencia(
            slot: 'rotulo',
            nombreArchivo: 'rotulo.webp',
            fecha: DateTime.utc(2026, 3, 1),
          ),
        },
      );

      final ida = VerificacionTallerModel.fromMap(original.toMap(), 'taller-1');

      expect(ida.estado, original.estado);
      expect(ida.fechaEnvio, isAtSameInstant(original.fechaEnvio!));
      expect(ida.fechaRevision, isAtSameInstant(original.fechaRevision!));
      expect(ida.revisadoPor, original.revisadoPor);
      expect(ida.documentos.keys, original.documentos.keys);
      expect(ida.documentos['rotulo']!.nombreArchivo, 'rotulo.webp');
      expect(
        ida.documentos['rotulo']!.fecha,
        isAtSameInstant(original.documentos['rotulo']!.fecha),
      );
    });
  });

  group('slots de documento', () {
    test('son exactamente los tres que aceptan las reglas de Storage', () {
      expect(VerificacionTallerModel.slotsPermitidos, {
        'nit',
        'fachada',
        'rotulo',
      });
    });

    test('faltanDocumentos mientras no esté la fachada', () {
      const sinNada = VerificacionTallerModel(
        idTaller: 'taller-1',
        estado: EstadoVerificacion.perfilIncompleto,
      );
      expect(sinNada.tieneEvidenciaMinima, isFalse);
      expect(sinNada.slotsFaltantes, ['nit', 'fachada', 'rotulo']);

      final conFachada = sinNada.copyWith(
        documentos: {
          'fachada': DocumentoEvidencia(
            slot: 'fachada',
            nombreArchivo: 'fachada.jpg',
            fecha: DateTime.utc(2026, 3, 1),
          ),
        },
      );
      expect(conFachada.tieneEvidenciaMinima, isTrue);
      expect(conFachada.slotsFaltantes, ['nit', 'rotulo']);
    });
  });

  group('copyWith', () {
    test('sustituye solo lo indicado', () {
      final base = VerificacionTallerModel(
        idTaller: 'taller-1',
        estado: EstadoVerificacion.enRevision,
        fechaEnvio: DateTime.utc(2026, 3, 1),
      );

      final resuelto = base.copyWith(
        estado: EstadoVerificacion.rechazada,
        motivoRechazo: 'Dirección no coincide',
      );

      expect(resuelto.estado, EstadoVerificacion.rechazada);
      expect(resuelto.motivoRechazo, 'Dirección no coincide');
      expect(resuelto.idTaller, 'taller-1');
      expect(resuelto.fechaEnvio, DateTime.utc(2026, 3, 1));
    });

    test('limpiarMotivoRechazo borra el motivo al reenviar', () {
      // Sin esto, un taller rechazado que corrige y reenvia arrastraria el
      // motivo del rechazo anterior: copyWith con null no puede distinguir
      // "no lo toques" de "borralo".
      const rechazado = VerificacionTallerModel(
        idTaller: 'taller-1',
        estado: EstadoVerificacion.rechazada,
        motivoRechazo: 'Dirección no coincide',
      );

      final reenviado = rechazado.copyWith(
        estado: EstadoVerificacion.listoParaRevision,
        limpiarMotivoRechazo: true,
      );

      expect(reenviado.motivoRechazo, isNull);
      expect(reenviado.estado, EstadoVerificacion.listoParaRevision);
    });
  });

  group('reapertura: por que un taller ya aprobado volvio a la cola', () {
    Map<String, dynamic> conReapertura(dynamic valor) => {
      'id_taller': 'taller-1',
      'estado_verificacion': 'listo_para_revision',
      'reapertura': valor,
    };

    test('se lee la fecha y los campos que escribio la Cloud Function', () {
      final modelo = VerificacionTallerModel.fromMap(
        conReapertura({
          'fecha': Timestamp.fromDate(DateTime.utc(2026, 8, 27)),
          'campos': ['Dirección', 'Municipio'],
        }),
        'taller-1',
      );

      expect(
        modelo.reapertura!.fecha,
        isAtSameInstant(DateTime.utc(2026, 8, 27)),
      );
      expect(modelo.reapertura!.campos, ['Dirección', 'Municipio']);
      expect(modelo.esReRevision, isTrue);
    });

    test('un expediente normal no es una re-revision', () {
      final modelo = VerificacionTallerModel.fromMap({
        'estado_verificacion': 'listo_para_revision',
      }, 'taller-1');

      expect(modelo.reapertura, isNull);
      expect(modelo.esReRevision, isFalse);
    });

    test('esReRevision solo vale mientras el expediente sigue en la cola', () {
      // El campo `reapertura` sobrevive a la siguiente aprobacion —queda como
      // historia—, pero un expediente ya resuelto no debe seguir pintando el
      // aviso de "cambios en revisión".
      final modelo = VerificacionTallerModel.fromMap({
        'estado_verificacion': 'aprobada',
        'reapertura': {
          'fecha': Timestamp.fromDate(DateTime.utc(2026, 8, 27)),
          'campos': ['Dirección'],
        },
      }, 'taller-1');

      expect(modelo.reapertura, isNotNull);
      expect(modelo.esReRevision, isFalse);
    });

    test('una reapertura mal formada se descarta en vez de pintarse vacia', () {
      // Un aviso sin fecha o sin campos no le dice nada al administrador, y
      // es peor que no enseñar nada: sugiere que hay algo que mirar sin decir
      // que.
      final basura = [
        null,
        'reabierto',
        {'campos': <String>[]},
        {'fecha': Timestamp.fromDate(DateTime.utc(2026, 8, 27))},
        {
          'fecha': null,
          'campos': ['Dirección'],
        },
        {
          'fecha': Timestamp.fromDate(DateTime.utc(2026, 8, 27)),
          'campos': ['  ', ''],
        },
        {
          'fecha': Timestamp.fromDate(DateTime.utc(2026, 8, 27)),
          'campos': 'Dirección',
        },
      ];

      for (final valor in basura) {
        final modelo = VerificacionTallerModel.fromMap(
          conReapertura(valor),
          'taller-1',
        );
        expect(modelo.reapertura, isNull, reason: '$valor');
        expect(modelo.esReRevision, isFalse, reason: '$valor');
      }
    });

    test('toMap no serializa la reapertura', () {
      // Solo la escribe la Cloud Function con SDK de Admin. Si viajara en el
      // payload del cliente, un taller podria fabricar o borrar el motivo por
      // el que su expediente volvio a la cola.
      final modelo = VerificacionTallerModel.fromMap(
        conReapertura({
          'fecha': Timestamp.fromDate(DateTime.utc(2026, 8, 27)),
          'campos': ['Dirección'],
        }),
        'taller-1',
      );

      expect(modelo.toMap().containsKey('reapertura'), isFalse);
    });
  });
}
