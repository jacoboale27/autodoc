import 'package:flutter/material.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/models/workshop_model.dart';
import '../../../../core/models/review_model.dart';
import '../../data/services/admin_service.dart';

class AdminProvider with ChangeNotifier {
  final AdminService _adminService = AdminService();

  List<UserModel> _usuarios = [];
  List<WorkshopModel> _talleres = [];
  List<ReviewModel> _resenias = [];

  bool _isLoading = false;
  String? _error;

  List<UserModel> get usuarios => _usuarios;
  List<WorkshopModel> get talleres => _talleres;
  List<ReviewModel> get resenias => _resenias;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
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

  Future<void> suspenderUsuario(String adminUid, String targetUid, String motivo) async {
    _setLoading(true);
    try {
      await _adminService.suspenderUsuario(adminUid, targetUid, motivo);
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
      await fetchUsuarios();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> aprobarTaller(String adminUid, String idTaller) async {
    _setLoading(true);
    try {
      await _adminService.aprobarTaller(adminUid, idTaller);
      _talleres = await _adminService.fetchTalleres();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> rechazarTaller(String adminUid, String idTaller) async {
    _setLoading(true);
    try {
      await _adminService.rechazarTaller(adminUid, idTaller);
      _talleres = await _adminService.fetchTalleres();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> suspenderTaller(String adminUid, String idTaller, String motivo) async {
    _setLoading(true);
    try {
      await _adminService.suspenderTaller(adminUid, idTaller, motivo);
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
      await _adminService.aprobarTaller(adminUid, idTaller);
      _talleres = await _adminService.fetchTalleres();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> eliminarResenia(String adminUid, String idResenia, String motivo) async {
    _setLoading(true);
    try {
      await _adminService.eliminarResenia(adminUid, idResenia, motivo);
      _resenias = await _adminService.fetchResenias();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }
}
