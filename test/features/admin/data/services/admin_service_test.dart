import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/features/admin/data/services/admin_service.dart';
import 'package:autodoc/features/admin/data/repositories/admin_repository.dart';
import 'package:autodoc/core/constants/firestore_collections.dart';

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
}
