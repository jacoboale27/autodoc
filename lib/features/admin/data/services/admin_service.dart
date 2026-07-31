import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/models/workshop_model.dart';
import '../../../../core/models/review_model.dart';
import '../../../../core/models/admin_log_model.dart';
import '../repositories/admin_repository.dart';
import '../../../../core/constants/firestore_collections.dart';

class AdminService {
  final AdminRepository _repository;

  AdminService({AdminRepository? repository})
    : _repository = repository ?? AdminRepository();
  final _uuid = const Uuid();

  Future<void> _logAction(
    String adminUid,
    String accion,
    String modulo,
    String referenciaId,
    String detalle,
  ) async {
    final log = AdminLogModel(
      idLog: _uuid.v4(),
      adminUid: adminUid,
      accion: accion,
      modulo: modulo,
      referenciaId: referenciaId,
      detalle: detalle,
      fecha: DateTime.now(),
    );
    await _repository.registrarLog(log);
  }

  // Usuarios
  Future<List<UserModel>> fetchUsuarios() async {
    return await _repository.getUsuarios();
  }

  /// Aprueba una cuenta de mecanico/taller que esta en `estado == 'pendiente'`
  /// (o sin el campo `estado`), habilitando su acceso via `isMecanico()` en
  /// `firestore.rules`. Usa `'activo'` (no `'aprobado'`) para converger en un
  /// unico valor "aprobado" real; `'aprobado'` sigue siendo aceptado por las
  /// reglas solo por retrocompatibilidad con datos migrados.
  Future<void> aprobarUsuario(String adminUid, String targetUid) async {
    await _repository.updateUsuarioEstado(targetUid, 'activo');
    await _logAction(
      adminUid,
      'APROBAR_USUARIO',
      'Usuarios',
      targetUid,
      'Cuenta de mecanico aprobada',
    );
  }

  Future<void> suspenderUsuario(
    String adminUid,
    String targetUid,
    String motivo,
  ) async {
    await _repository.updateUsuarioEstado(targetUid, 'suspendido');
    await _logAction(
      adminUid,
      'SUSPENDER_USUARIO',
      'Usuarios',
      targetUid,
      motivo,
    );
  }

  Future<void> reactivarUsuario(String adminUid, String targetUid) async {
    await _repository.updateUsuarioEstado(targetUid, 'activo');
    await _logAction(
      adminUid,
      'REACTIVAR_USUARIO',
      'Usuarios',
      targetUid,
      'Reactivación de cuenta',
    );
  }

  Future<void> cambiarRolUsuario(
    String adminUid,
    String targetUid,
    String nuevoRol,
  ) async {
    await _repository.updateUsuarioRol(targetUid, nuevoRol);
    await _logAction(
      adminUid,
      'CAMBIAR_ROL',
      'Usuarios',
      targetUid,
      'Cambio a rol: $nuevoRol',
    );
  }

  // Talleres
  Future<List<WorkshopModel>> fetchTalleres() async {
    return await _repository.getTalleres();
  }

  Future<void> aprobarTaller(String adminUid, String idTaller) async {
    await _repository.updateTallerEstado(idTaller, 'aprobado');
    await _logAction(
      adminUid,
      'APROBAR_TALLER',
      'Talleres',
      idTaller,
      'Taller verificado y aprobado',
    );
  }

  Future<void> rechazarTaller(String adminUid, String idTaller) async {
    await _repository.updateTallerEstado(idTaller, 'rechazado');
    await _logAction(
      adminUid,
      'RECHAZAR_TALLER',
      'Talleres',
      idTaller,
      'Taller rechazado',
    );
  }

  Future<void> suspenderTaller(
    String adminUid,
    String idTaller,
    String motivo,
  ) async {
    await _repository.updateTallerEstado(idTaller, 'suspendido');
    await _logAction(
      adminUid,
      'SUSPENDER_TALLER',
      'Talleres',
      idTaller,
      motivo,
    );
  }

  Future<void> reactivarTaller(String adminUid, String idTaller) async {
    await _repository.updateTallerEstado(idTaller, 'aprobado');
    await _logAction(
      adminUid,
      'REACTIVAR_TALLER',
      'Talleres',
      idTaller,
      'Taller reactivado',
    );
  }

  // Reseñas
  Future<List<ReviewModel>> fetchResenias() async {
    return await _repository.getResenias();
  }

  Future<String?> eliminarResenia(
    String adminUid,
    String idResenia,
    String motivo,
  ) async {
    final idTaller = await _repository.deleteResenia(idResenia);
    await _logAction(
      adminUid,
      'ELIMINAR_RESENIA',
      'Resenias',
      idResenia,
      motivo,
    );
    return idTaller;
  }

  // Logs
  Future<List<AdminLogModel>> fetchLogs({int limit = 50}) async {
    return await _repository.getLogs(limit: limit);
  }

  // Métricas
  Stream<Map<String, dynamic>> watchDashboardMetrics() {
    late StreamController<Map<String, dynamic>> controller;
    final List<StreamSubscription> subscriptions = [];

    Map<String, dynamic> metrics = {
      'usuarios': 0,
      'talleres': 0,
      'vehiculos': 0,
      'servicios': 0,
      'alertas': 0,
      'resenias': 0,
      'serviciosPorMes': <String, int>{},
    };

    void updateMetrics() {
      if (!controller.isClosed) {
        controller.add(Map.from(metrics));
      }
    }

    void startListening() {
      final fs = FirebaseFirestore.instance;

      subscriptions.add(
        fs.collection(FirestoreCollections.usuarios).snapshots().listen((snap) {
          metrics['usuarios'] = snap.size;
          updateMetrics();
        }),
      );
      subscriptions.add(
        fs.collection(FirestoreCollections.talleres).snapshots().listen((snap) {
          metrics['talleres'] = snap.size;
          updateMetrics();
        }),
      );
      subscriptions.add(
        fs.collection(FirestoreCollections.vehiculos).snapshots().listen((
          snap,
        ) {
          metrics['vehiculos'] = snap.size;
          updateMetrics();
        }),
      );
      subscriptions.add(
        fs.collection(FirestoreCollections.alertas).snapshots().listen((snap) {
          metrics['alertas'] = snap.size;
          updateMetrics();
        }),
      );
      subscriptions.add(
        fs.collection(FirestoreCollections.resenias).snapshots().listen((snap) {
          metrics['resenias'] = snap.size;
          updateMetrics();
        }),
      );
      subscriptions.add(
        fs.collection(FirestoreCollections.servicios).snapshots().listen((
          snap,
        ) {
          metrics['servicios'] = snap.size;
          updateMetrics();
        }),
      );

      final now = DateTime.now();
      final seisMesesAtras = DateTime(now.year, now.month - 5, 1);

      subscriptions.add(
        fs
            .collection(FirestoreCollections.servicios)
            .where(
              'fecha',
              isGreaterThanOrEqualTo: Timestamp.fromDate(seisMesesAtras),
            )
            .snapshots()
            .listen((snap) {
              final Map<String, int> serviciosPorMes = {};
              for (int i = 0; i < 6; i++) {
                final mes = DateTime(now.year, now.month - i, 1);
                serviciosPorMes['${mes.year}-${mes.month}'] = 0;
              }

              for (var doc in snap.docs) {
                final data = doc.data();
                if (data['fecha'] != null) {
                  final date = (data['fecha'] as Timestamp).toDate();
                  final key = '${date.year}-${date.month}';
                  if (serviciosPorMes.containsKey(key)) {
                    serviciosPorMes[key] = (serviciosPorMes[key] ?? 0) + 1;
                  }
                }
              }

              metrics['serviciosPorMes'] = serviciosPorMes;
              updateMetrics();
            }),
      );
    }

    void stopListening() {
      for (var sub in subscriptions) {
        sub.cancel();
      }
      subscriptions.clear();
    }

    controller = StreamController<Map<String, dynamic>>(
      onListen: startListening,
      onCancel: stopListening,
    );

    return controller.stream;
  }
}
