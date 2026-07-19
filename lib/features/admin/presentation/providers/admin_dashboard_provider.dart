import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/services/admin_service.dart';

class AdminDashboardProvider with ChangeNotifier {
  final AdminService _adminService = AdminService();

  Map<String, dynamic> _metrics = {
    'usuarios': 0,
    'talleres': 0,
    'vehiculos': 0,
    'servicios': 0,
    'alertas': 0,
    'resenias': 0,
    'serviciosPorMes': <String, int>{},
  };
  bool _isLoading = false;
  String? _error;
  
  StreamSubscription<Map<String, dynamic>>? _subscription;

  Map<String, dynamic> get metrics => _metrics;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void fetchMetrics() {
    _isLoading = true;
    _error = null;
    notifyListeners();

    _subscription?.cancel();
    
    try {
      _subscription = _adminService.watchDashboardMetrics().listen(
        (newMetrics) {
          _metrics = newMetrics;
          _isLoading = false;
          notifyListeners();
        },
        onError: (e) {
          _error = e.toString();
          _isLoading = false;
          notifyListeners();
        },
      );
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
