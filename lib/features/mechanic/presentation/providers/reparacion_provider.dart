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

  /// `true` cuando el tablero llegó al tope de [maxTicketsTablero] y por tanto
  /// hay tickets vivos que NO se están mostrando.
  ///
  /// Se deriva de haber recibido exactamente el tope: es lo único que el
  /// cliente puede saber sin pagar otra consulta. Puede dar un falso positivo
  /// si el taller tiene justo 200 tickets abiertos y ni uno más, que es un
  /// precio ridículo comparado con recortar en silencio.
  bool get tableroTruncado => _reparaciones.length >= maxTicketsTablero;

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

  /// Busca si ya existe un ticket **vigente** de reparación para este
  /// vehículo en este taller. Es el único método que
  /// `abrirVehiculoComoMecanico` (`navegacion_vehiculo.dart`, Tarea 5) usa
  /// para decidir entre la vista pública del vehículo (A3/B2, sin ticket) y
  /// `InitiateServiceScreen` (ticket ya abierto).
  ///
  /// "Vigente" es el complemento de [estadosReparacionCerrados]: antes de la
  /// revisión de la Tarea 5, esta consulta era solo UN insumo dentro de
  /// `InitiateServiceScreen` (para el botón "Recibir vehículo", que sí
  /// rechaza un ticket cerrado en [ReparacionRepository.recibirVehiculo]);
  /// ahora es la ÚNICA puerta de entrada a toda la pantalla. Sin este filtro,
  /// un ticket cerrado abría igual el formulario completo de
  /// materiales/cotización/finalizar — justo lo que A3/B2 prohíbe ("sin
  /// cotización aceptada vigente, nada de eso"). Un ticket `recibido`
  /// (incluido uno legado, anterior a A4b, que llega aquí sin `estado` y
  /// cuenta como abierto) sigue contando como vigente.
  ///
  /// **La compuerta excluía solo `cancelado`.** Un ticket ya `entregado`
  /// abría la pantalla entera, y era un callejón sin salida: al entregar, el
  /// vínculo con el vehículo ya se revocó, `firestore.rules` deniega la
  /// lectura de la ficha y la pantalla muere en un error genérico. No era una
  /// fuga —el servidor rechaza recibir un ticket cerrado y las reglas hacen
  /// inmutable un ticket cerrado— pero mandaba al mecánico a un error en vez
  /// de a la ficha pública, que es donde puede pedir una cotización nueva.
  /// Residual 7.1 de FUNC-02, cerrado aquí.
  ///
  /// Usar la constante y no el literal es el punto: [estadosReparacionCerrados]
  /// es el espejo en el cliente de `ESTADOS_TICKET_CERRADO`
  /// (`functions/src/aceptarCotizacion.js`), o sea la misma definición de
  /// "cerrado" que usa el servidor para decidir si abre un ticket NUEVO. La
  /// compuerta y el creador ya no pueden discrepar.
  ///
  /// [ReparacionRepository.buscarReparacionActiva] en sí sigue sin filtrar
  /// por estado a propósito: prefiere el abierto y cae al más reciente si
  /// todos están cerrados. El filtro de "vigente" vive aquí, en el único
  /// método pensado para gating, y en ningún otro sitio. "Mis Servicios" no
  /// pasa por aquí: se pinta desde `watchReparacionesActivas`, cuya igualdad
  /// `abierto == true` ya deja fuera `entregado` y `cancelado`.
  Future<String?> buscarReparacionActiva({
    required String idVehiculo,
    required String idTaller,
  }) async {
    final idReparacion = await _repository.buscarReparacionActiva(
      idVehiculo: idVehiculo,
      idTaller: idTaller,
    );
    if (idReparacion == null) return null;
    final reparacion = await _repository.obtenerReparacion(idReparacion);
    if (reparacion == null ||
        estadosReparacionCerrados.contains(reparacion.estado)) {
      return null;
    }
    return idReparacion;
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

  /// Marca que el coche salió del taller: transición a
  /// [estadoReparacionEntregado], el estado terminal.
  ///
  /// Es la contraparte de [recibirVehiculoPorId]: aquella marca la llegada
  /// física del coche y otorga el vínculo al vehículo, esta marca la salida y
  /// lo revoca (trigger `revocarVinculoAlCerrarTicket`). Entre las dos está
  /// todo lo que el taller puede hacer con el coche.
  ///
  /// Devuelve `true` si se entregó. Un `false` deja el motivo en [error]: el
  /// repositorio rechaza entregar un coche que no está en el taller (ver
  /// [ReparacionRepository.cambiarEstado]), que es lo que pasa si se toca dos
  /// veces el botón antes de que el tablero se refresque.
  Future<bool> entregar(String idReparacion) async {
    try {
      await cambiarEstado(idReparacion, estadoReparacionEntregado);
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
