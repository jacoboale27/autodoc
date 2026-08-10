import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:autodoc/core/models/reparacion_model.dart';
import 'package:autodoc/features/mechanic/data/repositories/reparacion_repository.dart';

class ReparacionProvider extends ChangeNotifier {
  final ReparacionRepository _repository;
  StreamSubscription<List<ReparacionModel>>? _sub;

  ReparacionProvider({ReparacionRepository? repository})
    : _repository = repository ?? ReparacionRepository();

  List<ReparacionModel> _reparaciones = [];
  List<ReparacionModel> get reparaciones => _reparaciones;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  void watchTaller(String idTaller) {
    _sub?.cancel();
    _isLoading = true;
    notifyListeners();
    _sub = _repository
        .watchReparacionesActivas(idTaller)
        .listen(
          (data) {
            _reparaciones = data;
            _isLoading = false;
            notifyListeners();
          },
          onError: (e) {
            _error = e.toString();
            _isLoading = false;
            notifyListeners();
          },
        );
  }

  Future<String?> iniciar({
    required String idVehiculo,
    required String idTaller,
    required String idPropietario,
    required String placa,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final id = await _repository.iniciarReparacion(
        idVehiculo: idVehiculo,
        idTaller: idTaller,
        idPropietario: idPropietario,
        placa: placa,
      );
      _error = null;
      return id;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Igual que [iniciar], pero primero busca si ya existe un ticket para
  /// este vehículo en este taller (cualquier estado) y lo reutiliza en vez
  /// de crear uno nuevo. `InitiateServiceScreen._onVehiculoListo` llama a
  /// esto cada vez que se (re)entra a la pantalla de servicio de un
  /// vehículo — sin esta comprobación, cada reentrada (recarga, volver
  /// atrás y reabrir) creaba un ticket Kanban duplicado para la misma
  /// visita.
  Future<String?> iniciarOReutilizar({
    required String idVehiculo,
    required String idTaller,
    required String idPropietario,
    required String placa,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final existente = await _repository.buscarReparacionActiva(
        idVehiculo: idVehiculo,
        idTaller: idTaller,
      );
      if (existente != null) {
        _error = null;
        return existente;
      }
      final id = await _repository.iniciarReparacion(
        idVehiculo: idVehiculo,
        idTaller: idTaller,
        idPropietario: idPropietario,
        placa: placa,
      );
      _error = null;
      return id;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Igual que [iniciarOReutilizar], pero para vehículos que llegaron por
  /// "Buscar Vehículo" (búsqueda por placa), donde el cliente no conoce el
  /// `id_propietario` del vehículo (ver
  /// [ReparacionRepository.iniciarOReutilizarPorVehiculo]).
  Future<String?> iniciarOReutilizarPorVehiculo({
    required String idVehiculo,
    required String idTaller,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final id = await _repository.iniciarOReutilizarPorVehiculo(
        idVehiculo: idVehiculo,
        idTaller: idTaller,
      );
      _error = null;
      return id;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> cambiarEstado(String idReparacion, String nuevoEstado) async {
    try {
      await _repository.cambiarEstado(
        idReparacion: idReparacion,
        nuevoEstado: nuevoEstado,
      );
      _error = null;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
