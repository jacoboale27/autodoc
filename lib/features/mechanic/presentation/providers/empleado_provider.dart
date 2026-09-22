import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:autodoc/core/models/empleado_model.dart';
import 'package:autodoc/core/models/invitacion_empleo_model.dart';
import 'package:autodoc/features/mechanic/data/repositories/empleado_repository.dart';
import 'package:autodoc/core/utils/mensaje_de_error.dart';

/// Qué hizo el servidor al dar de alta un empleado (observaciones del
/// 2026-09-19): con un correo nuevo crea la cuenta; con uno que ya la tiene,
/// reactiva al ex empleado del taller o invita a la persona.
enum ResultadoAltaEmpleado {
  creado,
  reactivado,

  /// Ex empleado que entró por invitación: la cuenta es suya y se reabrió con
  /// SU contraseña, no con la temporal que tecleó el taller.
  reactivadoConSuContrasena,
  invitado,
}

class EmpleadoProvider extends ChangeNotifier {
  final EmpleadoRepository _repository;
  final FirebaseFunctions? _injectedFunctions;
  StreamSubscription<List<EmpleadoModel>>? _sub;
  StreamSubscription<List<InvitacionEmpleoModel>>? _subInvitaciones;

  EmpleadoProvider({
    EmpleadoRepository? repository,
    FirebaseFunctions? functions,
  }) : _repository = repository ?? EmpleadoRepository(),
       _injectedFunctions = functions;

  // Resuelto de forma perezosa (no en el constructor): `FirebaseFunctions.instance`
  // exige `Firebase.initializeApp()`, y `watchTaller`/tests que no llaman
  // `crearEmpleado` no deberian requerirlo.
  FirebaseFunctions get _functions =>
      _injectedFunctions ?? FirebaseFunctions.instance;

  List<EmpleadoModel> _empleados = [];
  List<EmpleadoModel> get empleados => _empleados;

  List<InvitacionEmpleoModel> _invitaciones = [];

  /// Invitaciones del taller todavía sin responder.
  List<InvitacionEmpleoModel> get invitaciones => _invitaciones;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  void watchTaller(String idTaller) {
    _sub?.cancel();
    _sub = _repository
        .watchEmpleados(idTaller)
        .listen(
          (data) {
            _empleados = data;
            notifyListeners();
          },
          onError: (e) {
            _error = mensajeSeguroDeError(e);
            notifyListeners();
          },
        );
    _subInvitaciones?.cancel();
    _subInvitaciones = _repository
        .watchInvitaciones(idTaller)
        .listen(
          (data) {
            _invitaciones = data;
            notifyListeners();
          },
          // Un fallo aquí (p. ej. las reglas sin desplegar todavía) solo deja
          // la lista de pendientes vacía: la de empleados sigue funcionando.
          onError: (e) {
            debugPrint('No se pudieron leer las invitaciones: $e');
            _invitaciones = [];
            notifyListeners();
          },
        );
  }

  /// Da de alta un empleado. Devuelve qué hizo el servidor, o `null` si
  /// falló (el motivo queda en [error]).
  Future<ResultadoAltaEmpleado?> crearEmpleado({
    required String correo,
    required String password,
    required String nombreCompleto,
    required String rol,
    String? telefono,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final callable = _functions.httpsCallable('crearEmpleadoTaller');
      final respuesta = await callable.call({
        'correo': correo,
        'password': password,
        'nombreCompleto': nombreCompleto,
        'rol': rol,
        'telefono': telefono,
      });
      _error = null;
      final datos = respuesta.data;
      final resultado = datos is Map ? datos['resultado'] : null;
      return switch (resultado) {
        'reactivado' => ResultadoAltaEmpleado.reactivado,
        'reactivado_con_su_contrasena' =>
          ResultadoAltaEmpleado.reactivadoConSuContrasena,
        'invitado' => ResultadoAltaEmpleado.invitado,
        // Una versión anterior de la función no manda `resultado`: solo
        // sabía crear.
        _ => ResultadoAltaEmpleado.creado,
      };
    } catch (e) {
      _error = _mensajeDelServidor(e) ?? mensajeSeguroDeError(e);
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Retira una invitación pendiente.
  Future<bool> retirarInvitacion(String idTaller, String idInvitado) async {
    try {
      await _repository.retirarInvitacion(idTaller, idInvitado);
      return true;
    } catch (e) {
      _error = mensajeSeguroDeError(
        e,
        accion: 'No se pudo retirar la invitación',
      );
      notifyListeners();
      return false;
    }
  }

  /// La persona invitada acepta o rechaza la invitación de un taller.
  /// Devuelve `true` si el servidor la resolvió; si no, el motivo queda en
  /// [error].
  Future<bool> responderInvitacion({
    required String idTaller,
    required bool aceptar,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _functions.httpsCallable('responderInvitacionEmpleo').call({
        'idTaller': idTaller,
        'aceptar': aceptar,
      });
      return true;
    } catch (e) {
      _error = _mensajeDelServidor(e) ?? mensajeSeguroDeError(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// El texto que redactó NUESTRO callable para una persona («Ese correo ya
  /// es de un empleado de otro taller.», «Tu cuenta tiene vehículos
  /// registrados…»).
  ///
  /// Solo para estos tres códigos, que en `crearEmpleadoTaller` y
  /// `responderInvitacionEmpleo` salen siempre con un mensaje escrito en
  /// español para quien usa la app (ver `src/empleadosTaller.js`). Con el
  /// genérico, el taller leía «Ese dato ya existe.» sin saber qué dato ni qué
  /// hacer: fue exactamente la queja del 2026-09-19. Cualquier otro código
  /// sigue yendo por `mensajeSeguroDeError`, que no enseña detalle técnico.
  static String? _mensajeDelServidor(Object e) {
    if (e is! FirebaseFunctionsException) return null;
    const conMotivo = {
      'already-exists',
      'failed-precondition',
      // Cupo de invitaciones vivas del taller (2026-09-19). Sin él aquí, el
      // taller leía el genérico y no se enteraba de que el problema tiene
      // arreglo en sus manos: retirar alguna invitación.
      'resource-exhausted',
    };
    if (!conMotivo.contains(e.code)) return null;
    final mensaje = e.message?.trim() ?? '';
    return mensaje.isEmpty ? null : mensaje;
  }

  /// Desactiva a un empleado: revoca su acceso de verdad vía la Cloud
  /// Function `desactivarEmpleadoTaller` (deshabilita su cuenta Auth y fija
  /// `usuarios/{idEmpleado}.estado = 'suspendido'`, con Admin SDK — un
  /// write directo del cliente a Firestore no puede deshabilitar Auth).
  /// También se actualiza `talleres/{idTaller}/empleados/{idEmpleado}.activo`
  /// desde el cliente (vía [EmpleadoRepository.desactivarEmpleado], ya
  /// permitido por firestore.rules) para que el Switch de la UI refleje el
  /// cambio de inmediato sin esperar a que la Cloud Function termine.
  Future<void> desactivar(String idTaller, String idEmpleado) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final callable = _functions.httpsCallable('desactivarEmpleadoTaller');
      await callable.call({'idEmpleado': idEmpleado});
      await _repository.desactivarEmpleado(idTaller, idEmpleado);
      _error = null;
    } catch (e) {
      _error = mensajeSeguroDeError(e);
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _subInvitaciones?.cancel();
    super.dispose();
  }
}
