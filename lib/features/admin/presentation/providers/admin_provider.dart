import 'package:flutter/material.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/models/workshop_model.dart';
import '../../../../core/models/review_model.dart';
import '../../../../core/models/admin_log_model.dart';
import '../../../../core/utils/role_utils.dart';
import '../../data/services/admin_service.dart';

class AdminProvider with ChangeNotifier {
  final AdminService _adminService;

  AdminProvider({AdminService? adminService})
    : _adminService = adminService ?? AdminService();

  List<UserModel> _usuarios = [];
  List<WorkshopModel> _talleres = [];
  List<ReviewModel> _resenias = [];
  List<AdminLogModel> _logs = [];

  bool _isLoading = false;
  String? _error;
  String? _successMessage;

  List<UserModel> get usuarios => _usuarios;
  List<UserModel> get mecanicos =>
      _usuarios.where((u) => isMechanicRole(u.rol)).toList();
  List<WorkshopModel> get talleres => _talleres;

  String nombreUsuario(String id) {
    for (final u in _usuarios) {
      if (u.idUsuario == id) return u.nombreCompleto;
    }
    return 'Usuario';
  }

  String nombreTaller(String id) {
    for (final u in mecanicos) {
      if (u.idUsuario == id) return u.nombreCompleto;
    }
    for (final t in _talleres) {
      if (t.idTaller == id) return t.nombre;
    }
    return 'Mecánico';
  }

  List<ReviewModel> get resenias => _resenias;
  List<AdminLogModel> get logs => _logs;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get successMessage => _successMessage;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    _successMessage = null;
    notifyListeners();
  }

  void _setSuccess(String message) {
    _successMessage = message;
    _error = null;
    notifyListeners();
  }

  void clearMessages() {
    _error = null;
    _successMessage = null;
    notifyListeners();
  }

  // Cargar todos los datos principales
  Future<void> fetchAllData() async {
    _setLoading(true);
    _setError(null);
    try {
      final futures = await Future.wait([
        _adminService.fetchUsuarios(),
        _adminService.fetchTalleres(),
        _adminService.fetchResenias(),
      ]);

      _usuarios = futures[0] as List<UserModel>;
      _talleres = futures[1] as List<WorkshopModel>;
      _resenias = futures[2] as List<ReviewModel>;
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // --- USUARIOS ---

  Future<void> fetchUsuarios() async {
    _setLoading(true);
    try {
      _usuarios = await _adminService.fetchUsuarios();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> aprobarUsuario(String adminUid, String targetUid) async {
    _setLoading(true);
    try {
      await _adminService.aprobarUsuario(adminUid, targetUid);
      _setSuccess('Usuario aprobado correctamente');
      await fetchUsuarios();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> suspenderUsuario(
    String adminUid,
    String targetUid,
    String motivo,
  ) async {
    _setLoading(true);
    try {
      await _adminService.suspenderUsuario(adminUid, targetUid, motivo);
      _setSuccess('Usuario suspendido correctamente');
      await fetchUsuarios();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> reactivarUsuario(String adminUid, String targetUid) async {
    _setLoading(true);
    try {
      await _adminService.reactivarUsuario(adminUid, targetUid);
      _setSuccess('Usuario reactivado correctamente');
      await fetchUsuarios();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> cambiarRolUsuario(
    String adminUid,
    String targetUid,
    String nuevoRol,
  ) async {
    _setLoading(true);
    try {
      await _adminService.cambiarRolUsuario(adminUid, targetUid, nuevoRol);
      _setSuccess('Rol cambiado a $nuevoRol correctamente');
      await fetchUsuarios();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // --- TALLERES ---

  Future<void> aprobarTaller(String adminUid, String idTaller) async {
    _setLoading(true);
    try {
      await _adminService.aprobarTaller(adminUid, idTaller);
      _setSuccess('Taller aprobado correctamente');
      _talleres = await _adminService.fetchTalleres();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> rechazarTaller(
    String adminUid,
    String idTaller,
    String motivo,
  ) async {
    _setLoading(true);
    try {
      await _adminService.rechazarTaller(adminUid, idTaller, motivo: motivo);
      _setSuccess('Taller rechazado');
      _talleres = await _adminService.fetchTalleres();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> suspenderTaller(
    String adminUid,
    String idTaller,
    String motivo,
  ) async {
    _setLoading(true);
    try {
      await _adminService.suspenderTaller(adminUid, idTaller, motivo);
      _setSuccess('Taller suspendido');
      _talleres = await _adminService.fetchTalleres();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> reactivarTaller(String adminUid, String idTaller) async {
    _setLoading(true);
    try {
      await _adminService.reactivarTaller(adminUid, idTaller);
      _setSuccess('Taller reactivado');
      _talleres = await _adminService.fetchTalleres();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // --- RESEÑAS ---

  Future<void> eliminarResenia(
    String adminUid,
    String idResenia,
    String motivo,
  ) async {
    _setLoading(true);
    try {
      await _adminService.eliminarResenia(adminUid, idResenia, motivo);
      // aggregateRatings (Cloud Function) recalcula el promedio en el backend
      // automáticamente al detectar el borrado de la reseña.
      _setSuccess('Reseña eliminada');
      _resenias = await _adminService.fetchResenias();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> descartarReporte(String adminUid, String idResenia) async {
    _setLoading(true);
    try {
      await _adminService.descartarReporte(adminUid, idResenia);
      _setSuccess('Reporte descartado');
      _resenias = await _adminService.fetchResenias();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // --- LOGS ---

  Future<void> fetchLogs() async {
    _setLoading(true);
    try {
      _logs = await _adminService.fetchLogs();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // --- SUPERUSUARIO ---

  Future<bool> crearUsuario({
    required String nombreCompleto,
    required String correo,
    required String rol,
  }) async {
    _setLoading(true);
    try {
      final passwordTemporal = await _adminService.crearUsuarioComoSuperUser(
        nombreCompleto: nombreCompleto,
        correo: correo,
        rol: rol,
      );
      _setSuccess('Usuario creado. Contraseña temporal: $passwordTemporal');
      await fetchUsuarios();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> eliminarUsuarioPermanente(String uid) async {
    _setLoading(true);
    try {
      await _adminService.eliminarUsuarioPermanente(uid);
      _setSuccess('Cuenta eliminada permanentemente');
      await fetchUsuarios();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }
}
