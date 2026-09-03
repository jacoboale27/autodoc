import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'package:autodoc/core/models/estado_verificacion.dart';
import 'package:autodoc/core/models/user_model.dart';
import 'package:autodoc/core/models/verificacion_taller_model.dart';
import 'package:autodoc/features/mechanic/data/services/verificacion_service.dart';

/// Estado de la pantalla de verificacion del taller.
///
/// Deliberadamente no expone ningun `bool puedeEntrar`. El acceso lo decide
/// `usuarios.estado` a traves del enrutador y de firestore.rules; este provider
/// solo describe en que punto del tramite esta el expediente. Ver la nota de
/// [EstadoVerificacion] sobre los dos ejes.
class VerificacionProvider extends ChangeNotifier {
  final VerificacionService _service;

  VerificacionProvider({VerificacionService? service})
    : _service = service ?? VerificacionService();

  VerificacionTallerModel? _expediente;
  VerificacionTallerModel? get expediente => _expediente;

  bool _cargando = false;
  bool get cargando => _cargando;

  /// Slot que se esta subiendo ahora mismo, para poder poner el spinner solo
  /// en su tarjeta y no en las otras dos.
  String? _slotEnCurso;
  String? get slotEnCurso => _slotEnCurso;

  bool _enviando = false;
  bool get enviando => _enviando;

  String? _error;
  String? get error => _error;

  EstadoVerificacion get estado =>
      _expediente?.estado ?? EstadoVerificacion.perfilIncompleto;

  Future<void> cargar(String tallerId) async {
    _cargando = true;
    _error = null;
    notifyListeners();
    try {
      _expediente = await _service.obtener(tallerId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  /// Campos del perfil que todavia bloquean el envio.
  List<String> camposFaltantes(UserModel? perfil) =>
      perfil == null ? const [] : AppEstadoVerificacion.camposFaltantes(perfil);

  /// ¿Se puede pulsar "enviar a revision"?
  ///
  /// Las tres condiciones se evaluan aqui y no solo en el servicio para poder
  /// deshabilitar el boton en vez de dejar que el taller lo pulse y reciba un
  /// error. El servicio las vuelve a comprobar de todas formas: esto es
  /// comodidad, no la garantia.
  bool puedeEnviar(UserModel? perfil) {
    final expediente = _expediente;
    if (expediente == null || perfil == null) return false;
    return AppEstadoVerificacion.puedeTransicionar(
          expediente.estado,
          EstadoVerificacion.listoParaRevision,
        ) &&
        AppEstadoVerificacion.perfilCompleto(perfil) &&
        expediente.tieneEvidenciaMinima;
  }

  /// URL para mostrar en grande un documento ya subido.
  ///
  /// `null` ante cualquier fallo (por ejemplo, el archivo está anotado en el
  /// expediente pero ya no existe en Storage): la pantalla lo trata como "no
  /// se pudo abrir" en vez de tumbarse. Mismo patrón que
  /// `AdminVerificacionProvider.urlDeEvidencia`.
  Future<String?> urlDeEvidencia(
    String tallerId,
    DocumentoEvidencia documento,
  ) async {
    try {
      return await _service.urlDeEvidencia(tallerId, documento);
    } catch (_) {
      return null;
    }
  }

  Future<bool> subirEvidencia({
    required String tallerId,
    required String slot,
    required String nombreOriginal,
    required Uint8List bytes,
  }) async {
    _slotEnCurso = slot;
    _error = null;
    notifyListeners();
    try {
      await _service.subirEvidencia(
        tallerId: tallerId,
        slot: slot,
        nombreOriginal: nombreOriginal,
        bytes: bytes,
      );
      _expediente = await _service.obtener(tallerId);
      return true;
    } on VerificacionException catch (e) {
      _error = e.mensaje;
      return false;
    } catch (e, pila) {
      _error = _mensajeDe(e, pila, 'No se pudo subir el archivo.');
      return false;
    } finally {
      _slotEnCurso = null;
      notifyListeners();
    }
  }

  Future<bool> enviarARevision({
    required String tallerId,
    required UserModel perfil,
  }) async {
    _enviando = true;
    _error = null;
    notifyListeners();
    try {
      await _service.enviarARevision(tallerId: tallerId, perfil: perfil);
      _expediente = await _service.obtener(tallerId);
      return true;
    } on VerificacionException catch (e) {
      _error = e.mensaje;
      return false;
    } catch (e, pila) {
      _error = _mensajeDe(e, pila, 'No se pudo enviar la solicitud.');
      return false;
    } finally {
      _enviando = false;
      notifyListeners();
    }
  }

  /// Traduce un fallo inesperado a algo que se pueda enseñar Y con lo que se
  /// pueda depurar.
  ///
  /// Antes esta rama devolvia siempre «revisa tu conexion», y eso convirtio
  /// un `unauthorized` de Storage —el caso frecuente de verdad— en una pista
  /// falsa: el taller revisa el router y la culpa esta en las reglas, en el
  /// tamano del archivo o en el CORS del bucket. Solo se habla de conexion
  /// cuando el codigo del error dice que fue la conexion.
  static String _mensajeDe(Object e, StackTrace pila, String prefijo) {
    // Al log siempre el error crudo: es lo unico con lo que se depura un
    // fallo que solo ocurre en el dispositivo del usuario.
    debugPrint('[VerificacionProvider] $prefijo $e');
    debugPrintStack(
      stackTrace: pila,
      label: 'VerificacionProvider',
      maxFrames: 8,
    );

    if (e is FirebaseException) {
      switch (e.code) {
        // Storage devuelve 'unauthorized'; Firestore, 'permission-denied'.
        // Los dos significan lo mismo aqui y ninguno de los dos es la red.
        case 'unauthorized':
        case 'permission-denied':
          // Sin mencionar el tamaño: el limite de 5 MB ya lo comprueba
          // `VerificacionService` ANTES de llegar aqui, asi que un rechazo
          // en este punto casi nunca es por peso, y nombrarlo mandaba a
          // encoger fotos que ya cabian de sobra. Lo que de verdad queda es
          // que las reglas desplegadas no autorizan esta ruta.
          return '$prefijo El servidor denegó el permiso. No es tu conexión '
              'ni el peso del archivo: avisa al administrador para que '
              'revise las reglas de seguridad desplegadas.';
        case 'canceled':
          return '$prefijo La subida se canceló.';
        case 'retry-limit-exceeded':
          return '$prefijo Se agotó el tiempo de subida. Revisa tu conexión '
              'e inténtalo otra vez.';
        case 'unavailable':
        case 'deadline-exceeded':
          return '$prefijo No se pudo contactar con el servidor. Revisa tu '
              'conexión.';
        default:
          // El codigo va en el mensaje a proposito: sin el, un fallo de
          // configuracion (bucket mal puesto, CORS del bucket sin los
          // metodos de escritura) es indistinguible de un corte de red y no
          // hay forma de reportarlo.
          return '$prefijo Error de Firebase «${e.code}».';
      }
    }

    return '$prefijo Error inesperado: $e';
  }

  void limpiarError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }
}
