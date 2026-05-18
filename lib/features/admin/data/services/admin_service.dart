import 'package:uuid/uuid.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/models/workshop_model.dart';
import '../../../../core/models/review_model.dart';
import '../../../../core/models/admin_log_model.dart';
import '../repositories/admin_repository.dart';

class AdminService {
  final AdminRepository _repository = AdminRepository();
  final _uuid = const Uuid();

  Future<void> _logAction(String adminUid, String accion, String modulo, String referenciaId, String detalle) async {
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

  Future<void> suspenderUsuario(String adminUid, String targetUid, String motivo) async {
    await _repository.updateUsuarioEstado(targetUid, 'suspendido');
    await _logAction(adminUid, 'SUSPENDER_USUARIO', 'Usuarios', targetUid, motivo);
  }

  Future<void> reactivarUsuario(String adminUid, String targetUid) async {
    await _repository.updateUsuarioEstado(targetUid, 'activo');
    await _logAction(adminUid, 'REACTIVAR_USUARIO', 'Usuarios', targetUid, 'Reactivación de cuenta');
  }
  
  Future<void> cambiarRolUsuario(String adminUid, String targetUid, String nuevoRol) async {
    await _repository.updateUsuarioRol(targetUid, nuevoRol);
    await _logAction(adminUid, 'CAMBIAR_ROL', 'Usuarios', targetUid, 'Cambio a rol: $nuevoRol');
  }

  // Talleres
  Future<List<WorkshopModel>> fetchTalleres() async {
    return await _repository.getTalleres();
  }

  Future<void> aprobarTaller(String adminUid, String idTaller) async {
    await _repository.updateTallerEstado(idTaller, 'aprobado');
    await _logAction(adminUid, 'APROBAR_TALLER', 'Talleres', idTaller, 'Taller verificado y aprobado');
  }

  Future<void> rechazarTaller(String adminUid, String idTaller) async {
    await _repository.updateTallerEstado(idTaller, 'rechazado');
    await _logAction(adminUid, 'RECHAZAR_TALLER', 'Talleres', idTaller, 'Taller rechazado');
  }

  Future<void> suspenderTaller(String adminUid, String idTaller, String motivo) async {
    await _repository.updateTallerEstado(idTaller, 'suspendido');
    await _logAction(adminUid, 'SUSPENDER_TALLER', 'Talleres', idTaller, motivo);
  }

  // Reseñas
  Future<List<ReviewModel>> fetchResenias() async {
    return await _repository.getResenias();
  }

  Future<String?> eliminarResenia(String adminUid, String idResenia, String motivo) async {
    final idTaller = await _repository.deleteResenia(idResenia);
    await _logAction(adminUid, 'ELIMINAR_RESENIA', 'Resenias', idResenia, motivo);
    return idTaller;
  }

  // Logs
  Future<List<AdminLogModel>> fetchLogs({int limit = 50}) async {
    return await _repository.getLogs(limit: limit);
  }

  // Métricas
  Future<Map<String, int>> fetchDashboardMetrics() async {
    final totalUsuarios = await _repository.countCollection('Usuarios');
    final totalTalleres = await _repository.countCollection('Talleres');
    final totalVehiculos = await _repository.countCollection('Vehiculos');
    final totalServicios = await _repository.countCollection('Servicios');
    final totalAlertas = await _repository.countCollection('Alertas');
    final totalResenias = await _repository.countCollection('Resenias');

    return {
      'usuarios': totalUsuarios,
      'talleres': totalTalleres,
      'vehiculos': totalVehiculos,
      'servicios': totalServicios,
      'alertas': totalAlertas,
      'resenias': totalResenias,
    };
  }
}
