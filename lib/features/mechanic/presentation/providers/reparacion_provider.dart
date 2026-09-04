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

  @Deprecated('El ticket lo crea onCotizacionAceptada; usa recibirVehiculo')
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
  @Deprecated('El ticket lo crea onCotizacionAceptada; usa recibirVehiculo')
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
  @Deprecated('El ticket lo crea onCotizacionAceptada; usa recibirVehiculo')
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

  /// Marca la llegada física del vehículo al taller y devuelve el id del
  /// ticket junto con si esta llamada lo movió a `recibido` recién ahora, o
  /// `null` si no hay ninguno que recibir.
  ///
  /// El ticket ya no se crea aquí: nace cuando el cliente acepta la
  /// cotización (Cloud Function `onCotizacionAceptada`), en
  /// `pendiente_recepcion`. Si no aparece ninguno para este vehículo+taller es
  /// justamente el caso que A3/B2 quiere impedir —recibir un vehículo sin
  /// cotización aceptada— y se responde con un error accionable en vez de
  /// abrir un ticket por la puerta de atrás.
  ///
  /// `recibidoAhora` en el resultado distingue "acabo de recibirlo" de "ya
  /// estaba recibido" (hallazgo 2 de la revisión de la Tarea 4): sin esto la
  /// pantalla no puede saber si de verdad transicionó algo, y podía anunciar
  /// "vehículo recibido" cuando [ReparacionRepository.buscarReparacionActiva]
  /// —sin orden ni filtro de estado— resolvió un ticket legado ya recibido en
  /// vez del ticket nuevo que de verdad está esperando en el tablero.
  @Deprecated(
    'La Tarea 5 mueve esta busqueda a abrirVehiculoComoMecanico, antes de '
    'entrar a InitiateServiceScreen: la ruta /initiate_service/:reparacionId '
    'ya conoce el id del ticket, asi que la pantalla no necesita volver a '
    'buscarlo por vehiculo+taller. Usa buscarReparacionActiva (para decidir '
    'a donde navegar) y recibirVehiculoPorId (para la transicion) por '
    'separado.',
  )
  Future<({String idReparacion, bool recibidoAhora})?> recibirVehiculo({
    required String idVehiculo,
    required String idTaller,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final idReparacion = await _repository.buscarReparacionActiva(
        idVehiculo: idVehiculo,
        idTaller: idTaller,
      );
      if (idReparacion == null) {
        _error =
            'Este vehículo no tiene una cotización aceptada en tu taller, '
            'así que todavía no hay nada que recibir.';
        return null;
      }
      final recibidoAhora = await _repository.recibirVehiculo(
        idReparacion: idReparacion,
      );
      _error = null;
      return (idReparacion: idReparacion, recibidoAhora: recibidoAhora);
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Busca si ya existe un ticket de reparación para este vehículo en este
  /// taller (cualquier estado). Es el único método que
  /// `abrirVehiculoComoMecanico` (`navegacion_vehiculo.dart`, Tarea 5) usa
  /// para decidir entre la vista pública del vehículo (A3/B2, sin ticket) y
  /// `InitiateServiceScreen` (ticket ya abierto).
  Future<String?> buscarReparacionActiva({
    required String idVehiculo,
    required String idTaller,
  }) {
    return _repository.buscarReparacionActiva(
      idVehiculo: idVehiculo,
      idTaller: idTaller,
    );
  }

  /// Marca la llegada física del vehículo para un ticket ya conocido. Desde
  /// la Tarea 5 la ruta `/initiate_service/:reparacionId` siempre trae el id
  /// del ticket (lo resolvió `abrirVehiculoComoMecanico` antes de navegar
  /// aquí), así que a diferencia de [recibirVehiculo] no hace falta volver a
  /// buscarlo por vehículo+taller.
  ///
  /// Devuelve lo mismo que [ReparacionRepository.recibirVehiculo]: `true` si
  /// esta llamada transicionó el ticket a `recibido`, `false` si ya estaba
  /// ahí o más adelante (no-op), o `null` si falló (p. ej. el ticket está
  /// `cancelado`, o no existe).
  Future<bool?> recibirVehiculoPorId(String idReparacion) async {
    _isLoading = true;
    notifyListeners();
    try {
      final recibidoAhora = await _repository.recibirVehiculo(
        idReparacion: idReparacion,
      );
      _error = null;
      return recibidoAhora;
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

  /// Cancela un ticket. Existe porque el tablero solo ofrecía "Avanzar": un
  /// ticket abierto por error (p. ej. una placa mal tecleada) no había forma
  /// de retirarlo desde la interfaz. Reutiliza [cambiarEstado] (que ya
  /// delega en el repositorio, guarda el error y notifica), así que aquí
  /// solo hace falta traducir la excepción a un booleano para la UI.
  Future<bool> cancelar(String idReparacion) async {
    try {
      await cambiarEstado(idReparacion, 'cancelado');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Vacia el estado por usuario y **cancela la suscripcion viva por
  /// taller**. Se llama al cerrar sesion (`clearUserScopedProviders`): sin
  /// esto, el stream del taller saliente sigue emitiendo y el siguiente
  /// usuario que entre sin recargar la pagina ve sus reparaciones.
  void clear() {
    _sub?.cancel();
    _sub = null;
    _reparaciones = [];
    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
