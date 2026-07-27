import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/models/vehicle_model.dart';
import '../../../../core/services/vehicle_image_service.dart';
import '../../data/services/vehicle_service.dart';

class VehicleProvider with ChangeNotifier {
  final VehicleService _vehicleService;
  final VehicleImageService _imageService;

  VehicleProvider({VehicleService? vehicleService, VehicleImageService? imageService})
      : _vehicleService = vehicleService ?? VehicleService(),
        _imageService = imageService ?? VehicleImageService() {
    _initCache();
  }

  List<VehicleModel> _vehicles = [];
  VehicleModel? _selectedVehicle;
  bool _isLoading = false;
  String? _error;
  final List<VehicleModel> _recentSearches = [];

  List<VehicleModel> get vehicles => _vehicles;
  VehicleModel? get selectedVehicle => _selectedVehicle;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<VehicleModel> get recentSearches => _recentSearches;

  Future<Box?> _getCacheBox() async {
    try {
      if (Hive.isBoxOpen('offline_cache')) {
        return Hive.box('offline_cache');
      }
      if (Hive.homePath == null) {
        return null;
      }
      return await Hive.openBox('offline_cache');
    } catch (e) {
      debugPrint("Hive box 'offline_cache' not available: $e");
      return null;
    }
  }

  Future<void> _initCache() async {
    final cached = await _loadCachedVehicles();
    if (cached.isNotEmpty && _vehicles.isEmpty) {
      _vehicles = cached;
      try {
        _selectedVehicle = _vehicles.firstWhere((v) => v.isPrimary);
      } catch (_) {
        _selectedVehicle = _vehicles.first;
      }
      notifyListeners();
    }
  }

  Future<void> _cacheVehicles(List<VehicleModel> vehiculos) async {
    try {
      final box = await _getCacheBox();
      if (box == null) return;
      final jsonList = vehiculos.map((v) => v.toJson()).toList();
      await box.put('user_vehicles', jsonList);
    } catch (e) {
      debugPrint("Error caching vehicles to Hive: $e");
    }
  }

  Future<List<VehicleModel>> _loadCachedVehicles() async {
    try {
      final box = await _getCacheBox();
      if (box == null) return [];
      final cachedData = box.get('user_vehicles');
      if (cachedData != null && cachedData is List) {
        return cachedData
            .map((item) => VehicleModel.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
      }
    } catch (e) {
      debugPrint("Error reading cached vehicles from Hive: $e");
    }
    return [];
  }

  void addRecentSearch(VehicleModel vehicle) {
    _recentSearches.removeWhere((v) => v.placa == vehicle.placa);
    _recentSearches.insert(0, vehicle);
    if (_recentSearches.length > 5) {
      _recentSearches.removeLast();
    }
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  Future<void> fetchVehicles(String ownerId) async {
    _setLoading(true);
    _setError(null);
    try {
      final owned = await _vehicleService.getVehiclesByOwner(ownerId);
      final shared = await _vehicleService.getSharedVehicles(ownerId);
      
      // Merge: owned first, then shared (avoiding duplicates)
      final allIds = owned.map((v) => v.idVehiculo).toSet();
      final merged = [...owned];
      for (var v in shared) {
        if (!allIds.contains(v.idVehiculo)) {
          merged.add(v);
        }
      }
      _vehicles = merged;

      if (_vehicles.isNotEmpty) {
        try {
          _selectedVehicle = _vehicles.firstWhere((v) => v.isPrimary);
        } catch (_) {
          _selectedVehicle = _vehicles.first;
        }
      } else {
        _selectedVehicle = null;
      }
      
      await _cacheVehicles(_vehicles);

      _setLoading(false);
    } catch (e) {
      final cached = await _loadCachedVehicles();
      if (cached.isNotEmpty) {
        _vehicles = cached;
        if (_vehicles.isNotEmpty) {
          try {
            _selectedVehicle = _vehicles.firstWhere((v) => v.isPrimary);
          } catch (_) {
            _selectedVehicle = _vehicles.first;
          }
        }
      } else {
        _setError(e.toString());
      }
      _setLoading(false);
    }
  }

  Future<bool> addVehicle(VehicleModel vehicle) async {
    _setLoading(true);
    _setError(null);
    try {
      // If it's the first vehicle, make it primary automatically
      if (_vehicles.isEmpty) {
        vehicle = vehicle.copyWith(isPrimary: true);
      } else if (vehicle.isPrimary) {
        // If adding a primary, demote the current primary (if exists)
        await _demoteCurrentPrimary(vehicle.idPropietario);
      }

      // Obtener imagen automáticamente antes de guardar
      final imageUrl = await _imageService.getVehicleImage(
        vehicleId: vehicle.idVehiculo,
        brand: vehicle.marca ?? '',
        model: vehicle.modelo ?? '',
        year: vehicle.anio ?? 0,
        color: vehicle.color ?? '',
      );
      
      vehicle = vehicle.copyWith(fotoUrl: imageUrl);

      await _vehicleService.addVehicle(vehicle);
      await fetchVehicles(vehicle.idPropietario);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<bool> updateVehicle(VehicleModel vehicle) async {
    _setLoading(true);
    _setError(null);
    try {
      if (vehicle.isPrimary) {
        await _demoteCurrentPrimary(vehicle.idPropietario, excludeId: vehicle.idVehiculo);
      }
      await _vehicleService.updateVehicle(vehicle);
      await fetchVehicles(vehicle.idPropietario);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  /// Marca un vehículo como principal en Firestore y degrada el anterior.
  Future<bool> setAsPrimary(VehicleModel vehicle) async {
    if (vehicle.isPrimary) return true;

    _setLoading(true);
    _setError(null);
    try {
      await _demoteCurrentPrimary(vehicle.idPropietario, excludeId: vehicle.idVehiculo);
      await _vehicleService.updateVehicle(vehicle.copyWith(isPrimary: true));
      await fetchVehicles(vehicle.idPropietario);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<void> _demoteCurrentPrimary(String ownerId, {String? excludeId}) async {
    final currentPrimary = _vehicles.where((v) => v.isPrimary && v.idVehiculo != excludeId).toList();
    for (var v in currentPrimary) {
      await _vehicleService.updateVehicle(v.copyWith(isPrimary: false));
    }
  }

  void selectVehicle(VehicleModel vehicle) {
    _selectedVehicle = vehicle;
    notifyListeners();
  }

  Future<bool> deleteVehicle(String vehicleId, String ownerId) async {
    _setLoading(true);
    _setError(null);
    try {
      final wasPrimary = _vehicles.any((v) => v.idVehiculo == vehicleId && v.isPrimary);
      await _vehicleService.deleteVehicle(vehicleId);
      await fetchVehicles(ownerId);

      // Si se eliminó el principal, promover el primero restante del dueño
      if (wasPrimary && _vehicles.isNotEmpty) {
        final owned = _vehicles.where((v) => v.idPropietario == ownerId).toList();
        if (owned.isNotEmpty && !owned.any((v) => v.isPrimary)) {
          await _vehicleService.updateVehicle(owned.first.copyWith(isPrimary: true));
          await fetchVehicles(ownerId);
        }
      }

      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<void> updateVehicleMileage(String vehicleId, int newMileage) async {
    _setLoading(true);
    try {
      if (_selectedVehicle != null && _selectedVehicle!.idVehiculo == vehicleId) {
        final updatedVehicle = _selectedVehicle!.copyWith(kilometrajeActual: newMileage);
        await _vehicleService.updateVehicle(updatedVehicle);
        await fetchVehicles(_selectedVehicle!.idPropietario);
      }
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  Future<VehicleModel?> findVehicleByPlate(String plate) async {
    _setLoading(true);
    _setError(null);
    try {
      final vehicle = await _vehicleService.getVehicleByPlate(plate);
      if (vehicle == null) {
        _setError("No se encontró el vehículo con placa $plate");
      }
      _setLoading(false);
      return vehicle;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return null;
    }
  }

  void clearVehicles() {
    _vehicles = [];
    _selectedVehicle = null;
    _recentSearches.clear();
    _error = null;
    _isLoading = false;
    _clearHiveCache();
    notifyListeners();
  }

  Future<void> _clearHiveCache() async {
    try {
      final box = await _getCacheBox();
      if (box == null) return;
      await box.delete('user_vehicles');
    } catch (e) {
      debugPrint("Error clearing Hive vehicles cache: $e");
    }
  }
}
