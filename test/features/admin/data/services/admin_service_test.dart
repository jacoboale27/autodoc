import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/features/admin/data/services/admin_service.dart';
import 'package:autodoc/features/admin/data/repositories/admin_repository.dart';
import 'package:autodoc/core/constants/firestore_collections.dart';
import 'package:mockito/mockito.dart';

import '../../../../helpers/test_helpers.mocks.dart';

/// Repositorio dummy: watchDashboardMetrics() no lo usa, pero el
/// constructor de [AdminService] instancia un [AdminRepository] real por
/// defecto (que a su vez toca `FirebaseFirestore.instance`) si no se le
/// pasa uno explícito. Se evita así requerir Firebase.initializeApp() en
/// este test unitario.
class _DummyAdminRepository implements AdminRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'watchDashboardMetrics agrega usuariosPorMes y talleresPorMes',
    () async {
      final firestore = FakeFirebaseFirestore();
      final now = DateTime.now();

      await firestore.collection(FirestoreCollections.usuarios).add({
        'nombre_completo': 'Ana',
        'rol': 'Propietario',
        'fecha_registro': Timestamp.fromDate(now),
      });
      await firestore.collection(FirestoreCollections.usuarios).add({
        'nombre_completo': 'Taller X',
        'rol': 'Mecanico',
        'fecha_registro': Timestamp.fromDate(now),
      });

      final service = AdminService(
        firestore: firestore,
        repository: _DummyAdminRepository(),
      );
      // watchDashboardMetrics() combina varios listeners independientes
      // (usuarios, talleres, servicios, usuariosPorMes/talleresPorMes...)
      // que emiten en momentos distintos sobre el mismo stream; se espera
      // a la primera emisión donde el listener de usuariosPorMes/
      // talleresPorMes ya corrió (se inicializa con 6 claves en 0, nunca
      // queda vacío una vez que emite) en vez de tomar la primerísima
      // emisión del stream con `.first`, que podría venir de otro listener.
      final metrics = await service.watchDashboardMetrics().firstWhere(
        (m) => (m['usuariosPorMes'] as Map<String, int>).isNotEmpty,
      );

      final key = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      expect(metrics['usuariosPorMes'], isA<Map<String, int>>());
      expect(metrics['usuariosPorMes'][key], greaterThanOrEqualTo(1));
      expect(metrics['talleresPorMes'][key], greaterThanOrEqualTo(1));
    },
  );

  test(
    'watchDashboardMetrics.serviciosPorMes usa claves de mes con '
    'padding de 2 digitos (mismo formato que usuariosPorMes/talleresPorMes)',
    () async {
      final firestore = FakeFirebaseFirestore();
      final now = DateTime.now();

      await firestore.collection(FirestoreCollections.servicios).add({
        'fecha': Timestamp.fromDate(now),
      });

      final service = AdminService(
        firestore: firestore,
        repository: _DummyAdminRepository(),
      );
      final metrics = await service.watchDashboardMetrics().firstWhere(
        (m) => (m['serviciosPorMes'] as Map<String, int>).isNotEmpty,
      );

      final paddedKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      final serviciosPorMes = metrics['serviciosPorMes'] as Map<String, int>;

      expect(
        serviciosPorMes.containsKey(paddedKey),
        isTrue,
        reason:
            'serviciosPorMes debe usar el mismo formato de clave '
            '(zero-padded, p.ej. "2026-07") que usuariosPorMes/'
            'talleresPorMes; una inconsistencia aqui ya causo que el '
            'grafico de tendencia de servicios mostrara 0 para los meses '
            '1-9 (ver commit c8db6bb).',
      );
      expect(serviciosPorMes[paddedKey], greaterThanOrEqualTo(1));
    },
  );

  group('Suspension/reactivacion/aprobacion de talleres (regresion)', () {
    // talleres/{uid} es una proyeccion de solo lectura de usuarios/{uid}
    // mantenida por la Cloud Function publishTallerProfile. Estos tests
    // usan un AdminRepository real (no un dummy) contra FakeFirebaseFirestore
    // para confirmar que AdminService escribe 'estado' en usuarios/{uid} y
    // NUNCA en talleres/{uid} directamente, ya que esa escritura quedaria
    // silenciosamente revertida en el siguiente write a usuarios (y de
    // cualquier forma no restringe el acceso real, que depende de
    // usuarios/{uid}.estado via firestore.rules).
    late FakeFirebaseFirestore firestore;
    late AdminService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = AdminService(
        firestore: firestore,
        repository: AdminRepository(firestore: firestore),
      );
    });

    Future<void> seedTaller(String uid) async {
      await firestore.collection(FirestoreCollections.usuarios).doc(uid).set({
        'nombre_completo': 'Taller X',
        'rol': 'Mecanico',
        'estado': 'activo',
      });
      // Proyeccion pre-existente en talleres, como la dejaria
      // publishTallerProfile tras un write anterior en usuarios.
      await firestore.collection(FirestoreCollections.talleres).doc(uid).set({
        'nombre': 'Taller X',
        'estado': 'activo',
      });
    }

    test('suspenderTaller escribe estado en usuarios/{uid}', () async {
      await seedTaller('taller1');

      await service.suspenderTaller('admin1', 'taller1', 'Falta de pagos');

      final usuarioDoc = await firestore
          .collection(FirestoreCollections.usuarios)
          .doc('taller1')
          .get();
      expect(usuarioDoc.data()!['estado'], 'suspendido');

      final tallerDoc = await firestore
          .collection(FirestoreCollections.talleres)
          .doc('taller1')
          .get();
      expect(
        tallerDoc.data()!['estado'],
        'activo',
        reason:
            'talleres/{uid} es de solo lectura; AdminService no debe '
            'modificarlo directamente (lo hace publishTallerProfile).',
      );
    });

    test('reactivarTaller escribe estado=aprobado en usuarios/{uid}', () async {
      await seedTaller('taller1');
      await firestore
          .collection(FirestoreCollections.usuarios)
          .doc('taller1')
          .update({'estado': 'suspendido'});

      await service.reactivarTaller('admin1', 'taller1');

      final usuarioDoc = await firestore
          .collection(FirestoreCollections.usuarios)
          .doc('taller1')
          .get();
      expect(usuarioDoc.data()!['estado'], 'aprobado');
    });

    test('aprobarTaller escribe estado=aprobado en usuarios/{uid}', () async {
      await firestore
          .collection(FirestoreCollections.usuarios)
          .doc('taller2')
          .set({
            'nombre_completo': 'Taller Y',
            'rol': 'Mecanico',
            'estado': 'pendiente',
          });

      await service.aprobarTaller('admin1', 'taller2');

      final usuarioDoc = await firestore
          .collection(FirestoreCollections.usuarios)
          .doc('taller2')
          .get();
      expect(usuarioDoc.data()!['estado'], 'aprobado');
    });

    test('rechazarTaller escribe estado=rechazado en usuarios/{uid}', () async {
      await firestore
          .collection(FirestoreCollections.usuarios)
          .doc('taller3')
          .set({
            'nombre_completo': 'Taller Z',
            'rol': 'Mecanico',
            'estado': 'pendiente',
          });

      await service.rechazarTaller('admin1', 'taller3');

      final usuarioDoc = await firestore
          .collection(FirestoreCollections.usuarios)
          .doc('taller3')
          .get();
      expect(usuarioDoc.data()!['estado'], 'rechazado');
    });
  });

  group('Superusuario', () {
    test('crearUsuarioComoSuperUser lanza cuando el callable falla', () async {
      final mockFunctions = MockFirebaseFunctions();
      when(
        mockFunctions.httpsCallable('superUserCreateAccount'),
      ).thenThrow(Exception('network error'));

      final service = AdminService(
        functions: mockFunctions,
        repository: _DummyAdminRepository(),
      );

      expect(
        () => service.crearUsuarioComoSuperUser(
          nombreCompleto: 'A',
          correo: 'a@x.com',
          rol: 'Propietario',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('eliminarUsuarioPermanente lanza cuando el callable falla', () async {
      final mockFunctions = MockFirebaseFunctions();
      when(
        mockFunctions.httpsCallable('superUserDeleteAccount'),
      ).thenThrow(Exception('network error'));

      final service = AdminService(
        functions: mockFunctions,
        repository: _DummyAdminRepository(),
      );

      expect(
        () => service.eliminarUsuarioPermanente('uid1'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
