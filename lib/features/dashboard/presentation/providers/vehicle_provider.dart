import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/models/vehicle_model.dart';
import '../../data/services/vehicle_service.dart';
import 'package:autodoc/core/utils/mensaje_de_error.dart';

class VehicleProvider with ChangeNotifier {
  final VehicleService _vehicleService;

  VehicleProvider({VehicleService? vehicleService})
    : _vehicleService = vehicleService ?? VehicleService() {
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
      return null;
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
            .map(
              (item) =>
                  VehicleModel.fromJson(Map<String, dynamic>.from(item as Map)),
            )
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

  /// uid cuyo garaje ya esta en memoria, y la carga en vuelo si la hay.
  ///
  /// Los usa [asegurarVehiculosCargados]; ver alli por que existen.
  String? _cargadoPara;
  String? _ownerEnCurso;
  Future<void>? _cargaEnCurso;

  /// Carga el garaje de [ownerId] solo si nadie lo ha cargado ya.
  ///
  /// Existe porque `/garage` y `/alerts` no cargaban nada: se limitaban a
  /// LEER `vehicles` y `selectedVehicle`, y el unico sitio que llamaba a
  /// [fetchVehicles] al entrar era el dashboard. Mientras se navegue por las
  /// pestañas eso funciona —se pasa por el dashboard primero—, pero un F5 o
  /// un enlace directo monta la pantalla con el provider recien construido:
  /// el garaje salia con «No tienes vehiculos» teniendo tres, y las alertas
  /// con «Selecciona un vehiculo primero». Es la misma familia que el F5 de
  /// `/task_config` que cerro H-01.
  ///
  /// El memo NO esta dentro de [fetchVehicles] a proposito. Ahi tambien se
  /// marca, para que venir del dashboard no cueste una segunda lectura, pero
  /// si el memo VIVIERA solo ahi cualquier subclase que sobreescriba
  /// `fetchVehicles` sin llamar a `super` —los espias de los tests lo
  /// hacen— dejaria este metodo sin memoria y recargando en cada entrada.
  ///
  /// Se memoriza el INTENTO, no el exito, y eso importa. La primera version
  /// solo marcaba el memo cuando `_error` era null, con la idea razonable de
  /// que un fallo se debe poder reintentar. En un widget test se vio lo que
  /// eso significa de verdad: `fetchVehicles` termina con `notifyListeners()`,
  /// un `context.watch` reconstruye la pantalla, `didChangeDependencies`
  /// vuelve a correr y llama otra vez aqui — y como el fallo no se habia
  /// memorizado, se pedia de nuevo. Bucle infinito de lecturas contra
  /// Firestore mientras el error persista, que es justo cuando el backend
  /// menos lo aguanta.
  ///
  /// Reintentar sigue siendo posible, pero tiene que pedirlo algo: una
  /// llamada directa a [fetchVehicles] —el dashboard hace una en cada
  /// entrada— o un cambio de sesion, que pasa por [clearVehicles].
  Future<void> asegurarVehiculosCargados(String ownerId) {
    if (_cargadoPara == ownerId) return Future.value();

    final enCurso = _cargaEnCurso;
    if (enCurso != null && _ownerEnCurso == ownerId) return enCurso;

    _ownerEnCurso = ownerId;
    _cargadoPara = ownerId;
    final futuro = fetchVehicles(ownerId).whenComplete(() {
      if (_ownerEnCurso == ownerId) {
        _ownerEnCurso = null;
        _cargaEnCurso = null;
      }
    });
    _cargaEnCurso = futuro;
    return futuro;
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

      _cargadoPara = ownerId;
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
        _setError(mensajeSeguroDeError(e));
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

      // Un vehiculo nace SIN foto, y el placeholder neutro de
      // `VehicleImageWidget` cubre ese hueco.
      //
      // Aqui habia una llamada a `VehicleImageService`, que buscaba en
      // SearchAPI.io (engine `google_images`) una foto "estilo concesionario"
      // de la marca y el modelo y guardaba ESE enlace en `foto_url`. Retirada,
      // por dos motivos que se refuerzan:
      //
      //  - Propiedad intelectual: lo que devolvia eran fotos de terceros
      //    raspadas de Google Imagenes (catalogos de concesionario, bancos de
      //    imagen), servidas desde el CDN de su dueño. AutoDoc no tiene
      //    licencia sobre ninguna, y las pintaba como si fueran el coche de la
      //    persona.
      //  - Privacidad, y es el mismo agujero que FUNC-01 cerro en
      //    `resenias.fotos`: `foto_url` la lee todo el que puede ver la ficha
      //    del vehiculo —el taller vinculado, la vista publica, quien reciba
      //    un pase de historial—, asi que un enlace a un servidor ajeno le
      //    entrega a ese tercero la IP y el User-Agent de cada visitante.
      //
      // Quien quiera la foto de su coche la sube: `VehiclePhotoService` ya
      // existe y escribe en `vehiculos/{id}/fotos/` de nuestro propio Storage.
      // `firestore.rules` exige ahora que `foto_url` salga de ahi.
      await _vehicleService.addVehicle(vehicle);
      await fetchVehicles(vehicle.idPropietario);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(mensajeSeguroDeError(e));
      _setLoading(false);
      return false;
    }
  }

  Future<bool> updateVehicle(VehicleModel vehicle) async {
    _setLoading(true);
    _setError(null);
    try {
      if (vehicle.isPrimary) {
        await _demoteCurrentPrimary(
          vehicle.idPropietario,
          excludeId: vehicle.idVehiculo,
        );
      }
      await _vehicleService.updateVehicle(vehicle);
      await fetchVehicles(vehicle.idPropietario);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(mensajeSeguroDeError(e));
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
      await _demoteCurrentPrimary(
        vehicle.idPropietario,
        excludeId: vehicle.idVehiculo,
      );
      await _vehicleService.updateVehicle(vehicle.copyWith(isPrimary: true));
      await fetchVehicles(vehicle.idPropietario);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(mensajeSeguroDeError(e));
      _setLoading(false);
      return false;
    }
  }

  Future<void> _demoteCurrentPrimary(
    String ownerId, {
    String? excludeId,
  }) async {
    final currentPrimary = _vehicles
        .where((v) => v.isPrimary && v.idVehiculo != excludeId)
        .toList();
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
      final wasPrimary = _vehicles.any(
        (v) => v.idVehiculo == vehicleId && v.isPrimary,
      );
      await _vehicleService.deleteVehicle(vehicleId);
      await fetchVehicles(ownerId);

      // Si se eliminó el principal, promover el primero restante del dueño
      if (wasPrimary && _vehicles.isNotEmpty) {
        final owned = _vehicles
            .where((v) => v.idPropietario == ownerId)
            .toList();
        if (owned.isNotEmpty && !owned.any((v) => v.isPrimary)) {
          await _vehicleService.updateVehicle(
            owned.first.copyWith(isPrimary: true),
          );
          await fetchVehicles(ownerId);
        }
      }

      _setLoading(false);
      return true;
    } catch (e) {
      _setError(mensajeSeguroDeError(e));
      _setLoading(false);
      return false;
    }
  }

  Future<void> updateVehicleMileage(String vehicleId, int newMileage) async {
    _setLoading(true);
    try {
      if (_selectedVehicle != null &&
          _selectedVehicle!.idVehiculo == vehicleId) {
        final updatedVehicle = _selectedVehicle!.copyWith(
          kilometrajeActual: newMileage,
        );
        await _vehicleService.updateVehicle(updatedVehicle);
        await fetchVehicles(_selectedVehicle!.idPropietario);
      }
      _setLoading(false);
    } catch (e) {
      _setError(mensajeSeguroDeError(e));
      _setLoading(false);
    }
  }

  /// Confirma el vínculo permanente de un taller pendiente de confirmación
  /// sobre el vehículo indicado (cierre del hallazgo C1). Tras confirmar,
  /// refresca el vehículo seleccionado desde Firestore.
  Future<bool> confirmarVinculoTaller(
    String vehiculoId,
    String tallerId,
  ) async {
    _setLoading(true);
    _setError(null);
    try {
      await _vehicleService.confirmarVinculoTaller(vehiculoId, tallerId);
      if (_selectedVehicle != null &&
          _selectedVehicle!.idVehiculo == vehiculoId) {
        await fetchVehicles(_selectedVehicle!.idPropietario);
      }
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(mensajeSeguroDeError(e));
      _setLoading(false);
      return false;
    }
  }

  /// Rechaza el vínculo pendiente de un taller sobre el vehículo indicado.
  /// Tras rechazar, refresca el vehículo seleccionado desde Firestore.
  Future<bool> rechazarVinculoTaller(String vehiculoId, String tallerId) async {
    _setLoading(true);
    _setError(null);
    try {
      await _vehicleService.rechazarVinculoTaller(vehiculoId, tallerId);
      if (_selectedVehicle != null &&
          _selectedVehicle!.idVehiculo == vehiculoId) {
        await fetchVehicles(_selectedVehicle!.idPropietario);
      }
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(mensajeSeguroDeError(e));
      _setLoading(false);
      return false;
    }
  }

  /// El propietario retira el acceso de un taller a la ficha del vehículo.
  ///
  /// Contraparte de [confirmarVinculoTaller]: aquella concede, esta retira.
  /// Ver `VehicleService.revocarAccesoTaller` para por qué el consentimiento
  /// tiene que ser revocable por su titular.
  Future<bool> revocarAccesoTaller(String vehiculoId, String tallerId) async {
    _setLoading(true);
    _setError(null);
    try {
      await _vehicleService.revocarAccesoTaller(vehiculoId, tallerId);
      // Se refresca por `id_propietario` del vehículo tocado y no del
      // seleccionado: esta acción se puede lanzar desde la ficha de cualquier
      // vehículo de la lista, no solo del que esté "seleccionado".
      final tocado = _vehicles
          .where((v) => v.idVehiculo == vehiculoId)
          .firstOrNull;
      if (tocado != null) {
        await fetchVehicles(tocado.idPropietario);
      }
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(mensajeSeguroDeError(e));
      _setLoading(false);
      return false;
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
      _setError(mensajeSeguroDeError(e));
      _setLoading(false);
      return null;
    }
  }

  /// Busca un vehículo por id — a diferencia de [findVehicleByPlate], que
  /// puede resolver a un vehículo distinto si la placa está duplicada o
  /// desactualizada en datos legados, el id es la clave exacta que ya trae
  /// el ticket (`ReparacionModel.idVehiculo`). `VehicleSearchScreen`
  /// (A4a, "Mis servicios") la usa por eso en vez de buscar por placa.
  ///
  /// Devuelve `null` SOLO cuando el vehículo no existe, y **relanza** si la
  /// lectura falla. Antes devolvía `null` en los dos casos, y quien llamaba
  /// no podía decir si el propietario había borrado el coche o si las reglas
  /// le estaban negando la ficha — dos situaciones con salidas distintas
  /// para el taller. La revisión adversarial encontró las dos filas de "Mis
  /// Servicios" reales cayendo cada una por un motivo diferente y las dos
  /// con el mismo mensaje genérico (o con ninguno).
  Future<VehicleModel?> findVehicleById(String idVehiculo) async {
    _setLoading(true);
    _setError(null);
    try {
      final vehicle = await _vehicleService.getVehicleById(idVehiculo);
      if (vehicle == null) {
        _setError("No se encontró el vehículo con id $idVehiculo");
      }
      _setLoading(false);
      return vehicle;
    } catch (e) {
      _setError(mensajeSeguroDeError(e));
      _setLoading(false);
      rethrow;
    }
  }

  /// La ficha pública de un vehículo por id, la misma que devuelve la
  /// búsqueda por placa (ver `VehicleService.getPublicVehicleById`). No toca
  /// `isLoading` ni `error`: la usa el perfil del vehículo del taller como
  /// respaldo al recargar la página, y no debe repintar a nadie más.
  /// Relanza si la llamada falla.
  Future<VehicleModel?> findPublicVehicleById(String idVehiculo) =>
      _vehicleService.getPublicVehicleById(idVehiculo);

  void clearVehicles() {
    _vehicles = [];
    _selectedVehicle = null;
    // Sin esto, el siguiente usuario que entre sin recargar la pagina se
    // encontraria el memo del anterior y `asegurarVehiculosCargados` no
    // pediria nada.
    _cargadoPara = null;
    _ownerEnCurso = null;
    _cargaEnCurso = null;
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
