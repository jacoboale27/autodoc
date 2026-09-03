import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:autodoc/core/models/user_model.dart';
import 'package:autodoc/core/models/verificacion_taller_model.dart';
import 'package:autodoc/features/mechanic/data/services/verificacion_service.dart';
import 'package:autodoc/features/profile/data/services/user_service.dart';

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
  final UserService _userService;

  AdminVerificacionProvider({
    VerificacionService? service,
    UserService? userService,
  }) : _service = service ?? VerificacionService(),
       _userService = userService ?? UserService();

  StreamSubscription<List<VerificacionTallerModel>>? _suscripcion;

  List<VerificacionTallerModel> _bandeja = const [];
  List<VerificacionTallerModel> get bandeja => _bandeja;

  bool _cargando = true;
  bool get cargando => _cargando;

  /// Perfil (`usuarios/{uid}`) de cada taller con expediente en la bandeja,
  /// cacheado por uid.
  ///
  /// Hasta 2026-08-28 la pantalla identificaba la solicitud unicamente por el
  /// uid crudo y el administrador aprobaba o rechazaba a ciegas. El nombre,
  /// la especialidad y el correo viven fuera de [VerificacionTallerModel] a
  /// proposito (ver el doc del propio modelo): por eso se resuelven aqui, en
  /// un cache aparte, en vez de mutar el expediente.
  ///
  /// Se lee `usuarios/{uid}` y no `talleres/{uid}` (la proyeccion publica que
  /// usa el directorio) a proposito: `talleres` es de lectura publica y
  /// anonima (`firestore.rules`), y el correo del taller que esta pantalla
  /// necesita mostrar no puede vivir ahi. `usuarios/{uid}` ya es legible por
  /// el administrador y contiene un superconjunto de los mismos campos.
  final Map<String, UserModel?> _identidades = {};

  /// Perfil ya resuelto para `idTaller`, o `null` si todavia no ha llegado
  /// (o el taller no tiene perfil).
  UserModel? identidadDe(String idTaller) => _identidades[idTaller];

  /// Uids cuya resolucion de perfil esta en vuelo ahora mismo.
  ///
  /// `observarBandeja()` es un `.snapshots()` normal, sin `.distinct()`
  /// (Firestore reemite dos veces al suscribirse: cache local y luego
  /// servidor). Sin este set, una segunda reemision que llega mientras la
  /// primera resolucion de un uid todavia no termina lo vuelve a pedir: el
  /// cache (`_identidades`) todavia no tiene la entrada porque el primer
  /// `Future.wait` no ha resuelto, asi que `pendientes` lo calcularia como
  /// "falta" otra vez. Es exactamente el costo de lectura redundante que la
  /// Ruling 20 pedia eliminar, solo que entre emisiones solapadas en vez de
  /// dentro de una sola.
  final Set<String> _enVuelo = {};

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
        unawaited(_hidratarIdentidades(expedientes));
      },
      onError: (Object e) {
        _error = e.toString();
        _cargando = false;
        notifyListeners();
      },
    );
  }

  /// Resuelve el perfil de `usuarios/{uid}` de cada taller nuevo en la
  /// bandeja.
  ///
  /// Concurrente, no secuencial: un `for`+`await` haria una consulta a
  /// Firestore por expediente, una detras de otra. Con `Future.wait` todas
  /// salen a la vez. Y solo por los uids que faltan en el cache Y que no
  /// esten ya en vuelo: cada vez que el stream de `observarBandeja` reemite
  /// (un taller mas que entra a la cola, o simplemente la doble emision
  /// cache+servidor de Firestore), los ya resueltos o ya en camino no vuelven
  /// a pedirse.
  Future<void> _hidratarIdentidades(
    List<VerificacionTallerModel> expedientes,
  ) async {
    final pendientes = expedientes
        .map((e) => e.idTaller)
        .where(
          (uid) => !_identidades.containsKey(uid) && !_enVuelo.contains(uid),
        )
        .toSet();
    if (pendientes.isEmpty) return;

    _enVuelo.addAll(pendientes);
    try {
      final resueltos = await Future.wait(
        pendientes.map((uid) async {
          try {
            return MapEntry(uid, await _userService.getUserData(uid));
          } catch (_) {
            // Un perfil que no se pudo resolver no debe tumbar el resto del
            // lote ni quedar atascado para siempre: al no escribirse en
            // `_identidades`, la proxima reemision del stream lo vuelve a
            // intentar (una vez que salga de `_enVuelo` en el `finally`).
            return null;
          }
        }),
      );

      for (final entrada in resueltos) {
        if (entrada != null) _identidades[entrada.key] = entrada.value;
      }
      notifyListeners();
    } finally {
      _enVuelo.removeAll(pendientes);
    }
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
