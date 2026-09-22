import 'package:flutter/foundation.dart';
import '../../data/models/reserva_model.dart';
import '../../data/repositories/reserva_repository.dart';
import 'package:autodoc/core/utils/mensaje_de_error.dart';

class ReservaProvider extends ChangeNotifier {
  ReservaProvider({ReservaRepository? repository})
    : _reservaRepository = repository ?? ReservaRepository();

  final ReservaRepository _reservaRepository;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  /// Vacia el estado por usuario. Se llama al cerrar sesion.
  ///
  /// Ya no cancela ninguna suscripcion: este provider dejo de tener stream al
  /// retirarse `inicializarReservasUsuario` (gap 7.2 de GAPS-02). Se conserva
  /// porque `clearUserScopedProviders` lo llama junto a los demas y porque el
  /// error y el flag de carga si son estado por usuario.
  void clear() {
    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  Future<ReservaModel?> obtenerReserva(String reservaId) {
    return _reservaRepository.getReserva(reservaId);
  }

  /// Ver `ReservaRepository.reservaVigenteParaVehiculo`. Lanza si la consulta
  /// falla: quien llama tiene que poder distinguir "no hay cita" de "no se
  /// pudo saber".
  Future<ReservaModel?> reservaVigenteParaVehiculo({
    required String idMecanico,
    required String idVehiculo,
  }) {
    return _reservaRepository.reservaVigenteParaVehiculo(
      idMecanico: idMecanico,
      idVehiculo: idVehiculo,
    );
  }

  Future<String> solicitarReserva(ReservaModel reserva) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final id = await _reservaRepository.crearReserva(reserva);
      _isLoading = false;
      notifyListeners();
      return id;
    } catch (e) {
      _error = mensajeSeguroDeError(e);
      _isLoading = false;
      notifyListeners();
      return '';
    }
  }

  Future<bool> reprogramarReserva(
    String reservaId,
    DateTime nuevaFecha, {
    required String idProponente,
  }) async {
    try {
      await _reservaRepository.reprogramarReserva(
        reservaId,
        nuevaFecha,
        idProponente: idProponente,
      );
      return true;
    } catch (e) {
      _error = mensajeSeguroDeError(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> cambiarEstadoReserva(
    String reservaId,
    String estado, {
    DateTime? fechaConfirmada,
  }) async {
    try {
      await _reservaRepository.actualizarEstadoReserva(
        reservaId,
        estado,
        fechaConfirmada: fechaConfirmada,
      );
    } catch (e) {
      _error = mensajeSeguroDeError(e);
      notifyListeners();
    }
  }
}
