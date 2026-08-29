import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/models/reserva_model.dart';
import '../../data/repositories/reserva_repository.dart';

class ReservaProvider extends ChangeNotifier {
  final ReservaRepository _reservaRepository = ReservaRepository();

  List<ReservaModel> _reservas = [];
  List<ReservaModel> get reservas => _reservas;

  StreamSubscription? _reservasSub;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  @override
  void dispose() {
    _reservasSub?.cancel();
    super.dispose();
  }

  /// Vacia el estado por usuario y cancela la suscripcion activa. Se llama
  /// al cerrar sesion: sin cancelarla, sigue escuchando con el uid del
  /// usuario saliente y repuebla la lista en cuanto llegue el siguiente
  /// snapshot.
  void clear() {
    _reservasSub?.cancel();
    _reservasSub = null;
    _reservas = [];
    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  /// Siembra [_reservas] directamente para tests.
  ///
  /// A diferencia de [ChatProvider]/[AlertProvider]/
  /// [NotificationCenterProvider], [ReservaRepository] no acepta un
  /// `FirebaseFirestore` inyectado (usa `FirebaseFirestore.instance`
  /// directo), asi que no hay forma de sembrar este provider contra un
  /// `FakeFirebaseFirestore` a traves de su API publica real sin ampliar el
  /// alcance de esta tarea a esa clase.
  @visibleForTesting
  void debugSeedReservas(List<ReservaModel> reservas) {
    _reservas = reservas;
    notifyListeners();
  }

  void inicializarReservasUsuario(String userId, {bool isMecanico = false}) {
    _isLoading = true;
    notifyListeners();

    _reservasSub?.cancel();
    _reservasSub = _reservaRepository
        .streamReservasUsuario(userId, isMecanico: isMecanico)
        .listen(
          (data) {
            _reservas = data;
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

  Future<ReservaModel?> obtenerReserva(String reservaId) {
    return _reservaRepository.getReserva(reservaId);
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
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return '';
    }
  }

  Future<bool> reprogramarReserva(String reservaId, DateTime nuevaFecha) async {
    try {
      await _reservaRepository.reprogramarReserva(reservaId, nuevaFecha);
      return true;
    } catch (e) {
      _error = e.toString();
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
      _error = e.toString();
      notifyListeners();
    }
  }
}
