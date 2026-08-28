import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/constants/firestore_collections.dart';
import 'package:autodoc/core/theme/app_estado_cuenta.dart';
import 'package:autodoc/features/dashboard/data/services/workshop_service.dart';

/// El directorio publico de talleres filtraba por `estado == 'aprobado'`,
/// pero `AdminService.aprobarUsuario` escribe `'activo'` y solo
/// `aprobarTaller` escribe `'aprobado'` (ver admin_service.dart:69 y :145).
/// Resultado: un taller aprobado desde la pantalla de Usuarios quedaba
/// invisible en el directorio para siempre.
///
/// El vocabulario valido es [AppEstadoCuenta.aprobados], el mismo conjunto
/// que usan `isMecanico()` en firestore.rules y el guard del router.
void main() {
  late FakeFirebaseFirestore firestore;
  late WorkshopService service;

  /// Siembra un taller en la coleccion publica `talleres`, tal y como la
  /// proyecta la Cloud Function publishTallerProfile.
  Future<void> seedTaller({
    required String id,
    required String estado,
    double calificacion = 0.0,
  }) {
    return firestore.collection(FirestoreCollections.talleres).doc(id).set({
      'id_taller': id,
      'nombre': 'Taller $id',
      'estado': estado,
      'calificacion_promedio': calificacion,
      'total_resenias': 0,
    });
  }

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = WorkshopService(firestore: firestore);
  });

  group('WorkshopService - filtro de estado del directorio publico', () {
    test('incluye los talleres aprobados con AMBOS vocabularios', () async {
      await seedTaller(id: 'via-talleres', estado: 'aprobado', calificacion: 5);
      await seedTaller(id: 'via-usuarios', estado: 'activo', calificacion: 4);

      final talleres = await service.getWorkshops();

      expect(
        talleres.map((t) => t.idUsuario),
        containsAll(<String>['via-talleres', 'via-usuarios']),
        reason:
            'aprobarUsuario escribe "activo" y aprobarTaller escribe '
            '"aprobado": ambos son cuentas habilitadas y deben listarse.',
      );
    });

    test('excluye pendiente, rechazado y suspendido', () async {
      await seedTaller(id: 'ok', estado: 'activo', calificacion: 5);
      await seedTaller(id: 'pendiente', estado: 'pendiente');
      await seedTaller(id: 'rechazado', estado: 'rechazado');
      await seedTaller(id: 'suspendido', estado: 'suspendido');

      final ids = (await service.getWorkshops()).map((t) => t.idUsuario);

      expect(ids, <String>['ok']);
    });

    test(
      'el stream aplica exactamente el mismo filtro que getWorkshops',
      () async {
        await seedTaller(
          id: 'via-talleres',
          estado: 'aprobado',
          calificacion: 5,
        );
        await seedTaller(id: 'via-usuarios', estado: 'activo', calificacion: 4);
        await seedTaller(id: 'pendiente', estado: 'pendiente');

        final talleres = await service.getWorkshopsStream().first;

        expect(
          talleres.map((t) => t.idUsuario),
          containsAll(<String>['via-talleres', 'via-usuarios']),
        );
        expect(talleres.map((t) => t.idUsuario), isNot(contains('pendiente')));
      },
    );

    test('el filtro se deriva de AppEstadoCuenta.aprobados, sin literales '
        'duplicados', () {
      expect(AppEstadoCuenta.aprobados, {'aprobado', 'activo'});
    });
  });
}
