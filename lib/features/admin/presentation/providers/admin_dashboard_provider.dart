import 'package:flutter/material.dart';
import '../../data/services/admin_service.dart';

class AdminDashboardProvider with ChangeNotifier {
  final AdminService _adminService = AdminService();

  Map<String, int> _metrics = {
    'usuarios': 0,
    'talleres': 0,
    'vehiculos': 0,
    'servicios': 0,
    'alertas': 0,
    'resenias': 0,
  };
  bool _isLoading = false;
  String? _error;

  Map<String, int> get metrics => _metrics;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchMetrics() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _metrics = await _adminService.fetchDashboardMetrics();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
