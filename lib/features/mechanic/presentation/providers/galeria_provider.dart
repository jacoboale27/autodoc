import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'package:autodoc/core/models/galeria_taller.dart';
import 'package:autodoc/features/mechanic/data/services/galeria_service.dart';

/// Estado de la pantalla de galería comercial del taller.
class GaleriaProvider extends ChangeNotifier {
  final GaleriaService _service;

  GaleriaProvider({GaleriaService? service})
    : _service = service ?? GaleriaService();

  GaleriaTaller _galeria = const GaleriaTaller();
  GaleriaTaller get galeria => _galeria;

  bool _cargando = false;
  bool get cargando => _cargando;

  /// Hueco sobre el que se está trabajando ahora mismo, para poner el spinner
  /// solo en esa tarjeta.
  String? _slotEnCurso;
  String? get slotEnCurso => _slotEnCurso;

  String? _error;
  String? get error => _error;

  Future<void> cargar(String tallerId) async {
    _cargando = true;
    _error = null;
    notifyListeners();
    try {
      _galeria = await _service.obtener(tallerId);
    } catch (e) {
      _error = 'No se pudo cargar la galería.';
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  Future<bool> subirFoto({
    required String tallerId,
    required String slot,
    required String nombreOriginal,
    required Uint8List bytes,
  }) => _ejecutar(
    slot,
    () => _service.subirFoto(
      tallerId: tallerId,
      slot: slot,
      nombreOriginal: nombreOriginal,
      bytes: bytes,
    ),
  );

  Future<bool> quitarFoto({required String tallerId, required String slot}) =>
      _ejecutar(
        slot,
        () => _service.quitarFoto(tallerId: tallerId, slot: slot),
      );

  Future<bool> _ejecutar(
    String slot,
    Future<GaleriaTaller> Function() accion,
  ) async {
    _slotEnCurso = slot;
    _error = null;
    notifyListeners();
    try {
      _galeria = await accion();
      return true;
    } on GaleriaException catch (e) {
      _error = e.mensaje;
      return false;
    } catch (e, pila) {
      debugPrint('[GaleriaProvider] $e');
      debugPrintStack(stackTrace: pila, label: 'GaleriaProvider', maxFrames: 8);
      // Un rechazo de permisos aqui casi siempre significa que la cuenta dejo
      // de estar aprobada (storage.rules exige esTallerAprobado), asi que el
      // mensaje lo dice en vez de hablar de permisos. Pero SOLO en ese caso:
      // dar esa explicacion ante cualquier fallo mandaba a mirar el estado de
      // la cuenta cuando el problema era otro, y sin el codigo del error no
      // quedaba forma de saber cual.
      if (e is FirebaseException) {
        _error = switch (e.code) {
          'unauthorized' || 'permission-denied' =>
            'No se pudo guardar el cambio. Si tu cuenta fue suspendida, no '
                'puedes publicar fotos.',
          'canceled' => 'La subida se canceló.',
          'retry-limit-exceeded' || 'unavailable' || 'deadline-exceeded' =>
            'No se pudo contactar con el servidor. Revisa tu conexión.',
          _ => 'No se pudo guardar el cambio. Error de Firebase «${e.code}».',
        };
      } else {
        _error = 'No se pudo guardar el cambio. Error inesperado: $e';
      }
      return false;
    } finally {
      _slotEnCurso = null;
      notifyListeners();
    }
  }
}
