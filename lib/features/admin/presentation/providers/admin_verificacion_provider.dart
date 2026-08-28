import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:autodoc/core/models/verificacion_taller_model.dart';
import 'package:autodoc/features/mechanic/data/services/verificacion_service.dart';

/// Bandeja de expedientes de verificación para el administrador.
///
/// Aprobar o rechazar aquí resuelve el expediente Y la cuenta del taller en la
/// misma escritura atómica (ver `VerificacionService.aprobar`). Siguen siendo
/// dos campos distintos —`verificaciones.estado_verificacion` es el registro de
/// que un humano revisó, `usuarios.estado` es el permiso real— para que
/// suspender una cuenta más adelante no borre el rastro de que en su día fue
/// verificada. Pero son una sola acción: cuando eran dos, el administrador
/// aprobaba el expediente, daba por hecho que había terminado, y el taller se
/// quedaba fuera sin que nada avisara.
///
/// `tomarCaso` es la excepción y no toca la cuenta: abrir un caso no concede ni
/// retira nada.
class AdminVerificacionProvider extends ChangeNotifier {
  final VerificacionService _service;

  AdminVerificacionProvider({VerificacionService? service})
    : _service = service ?? VerificacionService();

  StreamSubscription<List<VerificacionTallerModel>>? _suscripcion;

  List<VerificacionTallerModel> _bandeja = const [];
  List<VerificacionTallerModel> get bandeja => _bandeja;

  bool _cargando = true;
  bool get cargando => _cargando;

  /// Uid del taller cuyo expediente se está resolviendo ahora mismo, para
  /// poner el spinner solo en esa fila.
  String? _resolviendo;
  String? get resolviendo => _resolviendo;

  String? _error;
  String? get error => _error;

  void escuchar() {
    _suscripcion?.cancel();
    _cargando = true;
    notifyListeners();
    _suscripcion = _service.observarBandeja().listen(
      (expedientes) {
        _bandeja = expedientes;
        _cargando = false;
        _error = null;
        notifyListeners();
      },
      onError: (Object e) {
        _error = e.toString();
        _cargando = false;
        notifyListeners();
      },
    );
  }

  Future<String?> urlDeEvidencia(
    String tallerId,
    DocumentoEvidencia documento,
  ) async {
    try {
      return await _service.urlDeEvidencia(tallerId, documento);
    } catch (_) {
      // Un archivo anotado en el expediente pero ausente en Storage no debe
      // tumbar la pantalla: la tarjeta lo pinta como "no se pudo cargar", que
      // ya es informacion util para el administrador.
      return null;
    }
  }

  Future<bool> tomarCaso(String tallerId, String adminUid) => _ejecutar(
    tallerId,
    () => _service.tomarCaso(tallerId: tallerId, adminUid: adminUid),
  );

  Future<bool> aprobar(String tallerId, String adminUid) => _ejecutar(
    tallerId,
    () => _service.aprobar(tallerId: tallerId, adminUid: adminUid),
  );

  Future<bool> rechazar(String tallerId, String adminUid, String motivo) =>
      _ejecutar(
        tallerId,
        () => _service.rechazar(
          tallerId: tallerId,
          adminUid: adminUid,
          motivo: motivo,
        ),
      );

  Future<bool> _ejecutar(
    String tallerId,
    Future<void> Function() accion,
  ) async {
    _resolviendo = tallerId;
    _error = null;
    notifyListeners();
    try {
      await accion();
      return true;
    } on VerificacionException catch (e) {
      _error = e.mensaje;
      return false;
    } catch (e) {
      _error = 'No se pudo completar la acción. Revisa tu conexión.';
      return false;
    } finally {
      _resolviendo = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _suscripcion?.cancel();
    super.dispose();
  }
}
