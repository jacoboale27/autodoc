import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/models/estado_verificacion.dart';
import 'package:autodoc/core/models/verificacion_taller_model.dart';
import 'package:autodoc/features/admin/presentation/providers/admin_verificacion_provider.dart';
import 'package:autodoc/features/dashboard/data/services/workshop_service.dart';
import 'package:autodoc/features/mechanic/data/services/verificacion_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late VerificacionService service;
  late AdminVerificacionProvider provider;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = VerificacionService(
      firestore: firestore,
      resolutorDeUrl: (ruta) async => 'https://storage.test/$ruta',
      ahora: () => DateTime.utc(2026, 3, 10),
    );
    // `WorkshopService()` sin argumentos toca `FirebaseFirestore.instance` en
    // su propio constructor (aunque este test nunca llegue a invocar
    // `getWorkshopById`), y este archivo no inicializa Firebase: hace falta
    // la misma instancia fake para que el provider se pueda construir aqui.
    provider = AdminVerificacionProvider(
      service: service,
      workshopService: WorkshopService(firestore: firestore),
    );
  });

  Future<void> sembrar(String id, String estado, {DateTime? fechaEnvio}) =>
      firestore.collection('verificaciones').doc(id).set({
        'estado_verificacion': estado,
        if (fechaEnvio != null) 'fecha_envio': Timestamp.fromDate(fechaEnvio),
        'documentos': {
          'fachada': {
            'nombre_archivo': 'fachada.jpg',
            'fecha': Timestamp.fromDate(DateTime.utc(2026, 3, 1)),
          },
        },
      });

  group('bandeja', () {
    test('lista pendientes y abiertos, y omite los ya resueltos', () async {
      await sembrar(
        'a',
        'listo_para_revision',
        fechaEnvio: DateTime.utc(2026, 3, 2),
      );
      await sembrar('b', 'en_revision', fechaEnvio: DateTime.utc(2026, 3, 1));
      await sembrar('c', 'aprobada', fechaEnvio: DateTime.utc(2026, 2, 1));
      await sembrar('d', 'rechazada', fechaEnvio: DateTime.utc(2026, 2, 2));

      provider.escuchar();
      await Future<void>.delayed(Duration.zero);

      expect(provider.bandeja.map((e) => e.idTaller), ['b', 'a']);
      expect(provider.cargando, isFalse);
    });
  });

  group('resolución', () {
    test('un caso no se puede resolver sin tomarlo antes', () async {
      await sembrar('a', 'listo_para_revision');

      final ok = await provider.aprobar('a', 'admin-9');

      expect(ok, isFalse);
      expect(provider.error, isNotNull);
      expect(provider.resolviendo, isNull);
      expect(
        (await service.obtener('a')).estado,
        EstadoVerificacion.listoParaRevision,
      );
    });

    test('tomar y aprobar deja constancia de quién revisó', () async {
      await sembrar('a', 'listo_para_revision');

      expect(await provider.tomarCaso('a', 'admin-9'), isTrue);
      expect(await provider.aprobar('a', 'admin-9'), isTrue);

      final expediente = await service.obtener('a');
      expect(expediente.estado, EstadoVerificacion.aprobada);
      expect(expediente.revisadoPor, 'admin-9');
    });

    test('rechazar sin motivo falla y no cambia el estado', () async {
      await sembrar('a', 'en_revision');

      final ok = await provider.rechazar('a', 'admin-9', '   ');

      expect(ok, isFalse);
      expect(
        (await service.obtener('a')).estado,
        EstadoVerificacion.enRevision,
      );
    });

    test('rechazar con motivo lo guarda para que el taller lo lea', () async {
      await sembrar('a', 'en_revision');

      expect(
        await provider.rechazar('a', 'admin-9', 'El rótulo no es legible'),
        isTrue,
      );

      final expediente = await service.obtener('a');
      expect(expediente.estado, EstadoVerificacion.rechazada);
      expect(expediente.motivoRechazo, 'El rótulo no es legible');
    });
  });

  group('urlDeEvidencia', () {
    test('la ruta se deriva del uid y del nombre canónico del slot', () async {
      final documento = DocumentoEvidencia(
        slot: 'fachada',
        nombreArchivo: 'fachada.jpg',
        fecha: DateTime.utc(2026, 3, 1),
      );

      expect(
        await provider.urlDeEvidencia('taller-1', documento),
        'https://storage.test/verificaciones/taller-1/fachada.jpg',
      );
    });

    test('un archivo ausente en Storage no tumba la pantalla', () async {
      final roto = AdminVerificacionProvider(
        service: VerificacionService(
          firestore: firestore,
          resolutorDeUrl: (_) async => throw Exception('object-not-found'),
        ),
        workshopService: WorkshopService(firestore: firestore),
      );

      expect(
        await roto.urlDeEvidencia(
          'taller-1',
          DocumentoEvidencia(
            slot: 'fachada',
            nombreArchivo: 'fachada.jpg',
            fecha: DateTime.utc(2026, 3, 1),
          ),
        ),
        isNull,
      );
    });
  });
}
