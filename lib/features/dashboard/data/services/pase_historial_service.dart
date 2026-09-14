import 'package:cloud_functions/cloud_functions.dart';

/// INNO-01 — cliente de los tres callables del pase temporal de historial.
///
/// **Por que todo pasa por callables y no por Firestore.** La coleccion
/// `tokens_historial` esta cerrada a todo cliente en `firestore.rules`
/// (`allow read, write: if false`), en los dos sentidos y a proposito: un pase
/// es un secreto portador, asi que lo que hay que impedir no es solo
/// fabricarlo, sino poder LISTAR la coleccion y cosechar los pases vivos de
/// otros. La autorizacion real vive en
/// `functions/src/historialCompartido.js`; esta clase no decide nada.
///
/// **El vencimiento nunca se calcula aqui.** El servidor devuelve `expiraEn`
/// ya resuelto contra su propio reloj y lo vuelve a comprobar al canjear. Esta
/// clase lo usa solo para pintar la cuenta atras: si el usuario adelanta el
/// reloj del telefono, la cuenta atras miente pero el pase sigue caducando a
/// su hora.
///
/// Las funciones se inyectan por el mismo motivo que en
/// `PublicProfileService`: mockear `HttpsCallable` de verdad exige encadenar
/// tres dobles que no aportan nada, porque la frontera de seguridad ya esta
/// probada del lado servidor (`functions/test/historial_compartido.test.js`).
class PaseHistorialService {
  final Future<Map<String, dynamic>> Function(String idVehiculo) _crear;
  final Future<Map<String, dynamic>> Function(String token) _leer;
  final Future<void> Function(String token) _revocar;

  PaseHistorialService({
    Future<Map<String, dynamic>> Function(String idVehiculo)? crear,
    Future<Map<String, dynamic>> Function(String token)? leer,
    Future<void> Function(String token)? revocar,
  }) : _crear = crear ?? _crearPorCallable,
       _leer = leer ?? _leerPorCallable,
       _revocar = revocar ?? _revocarPorCallable;

  static Future<Map<String, dynamic>> _crearPorCallable(
    String idVehiculo,
  ) async {
    final r = await FirebaseFunctions.instance
        .httpsCallable('crearPaseHistorial')
        .call<Map<String, dynamic>>({'id_vehiculo': idVehiculo});
    return Map<String, dynamic>.from(r.data);
  }

  static Future<Map<String, dynamic>> _leerPorCallable(String token) async {
    final r = await FirebaseFunctions.instance
        .httpsCallable('leerPaseHistorial')
        .call<Map<String, dynamic>>({'token': token});
    return Map<String, dynamic>.from(r.data);
  }

  static Future<void> _revocarPorCallable(String token) async {
    await FirebaseFunctions.instance.httpsCallable('revocarPaseHistorial').call(
      {'token': token},
    );
  }

  /// Emite un pase para el historial de [idVehiculo]. Solo el propietario.
  Future<PaseHistorial> emitir(String idVehiculo) async {
    final d = await _crear(idVehiculo);
    return PaseHistorial(
      token: d['token'] as String,
      expiraEn: DateTime.fromMillisecondsSinceEpoch(
        (d['expira_en'] as num).toInt(),
      ),
    );
  }

  /// Canjea un pase y devuelve el historial minimo.
  Future<HistorialCompartido> canjear(String token) async {
    final d = await _leer(token);
    return HistorialCompartido.desdeMapa(d);
  }

  /// Anula un pase antes de que caduque. Solo quien lo emitio.
  Future<void> revocar(String token) => _revocar(token);
}

/// Prefijo del payload del QR.
///
/// **Existe para que el escaner no confunda un pase con una placa.**
/// `vehicle_search_screen.dart` ya tenia un escaner que interpreta `rawValue`
/// como placa y lanza una busqueda; sin un prefijo distinguible, escanear un
/// pase buscaria la placa "a3f9..." y no encontraria nada, que es el fallo mas
/// dificil de diagnosticar de los dos.
const String prefijoPaseHistorial = 'autodoc://historial/';

/// Extrae el token de un payload de QR, o `null` si no es un pase.
String? tokenDesdePayloadQr(String? crudo) {
  if (crudo == null) return null;
  final v = crudo.trim();
  if (!v.startsWith(prefijoPaseHistorial)) return null;
  final token = v.substring(prefijoPaseHistorial.length);
  return token.isEmpty ? null : token;
}

class PaseHistorial {
  final String token;
  final DateTime expiraEn;

  const PaseHistorial({required this.token, required this.expiraEn});

  /// Lo que se codifica en el QR.
  String get payloadQr => '$prefijoPaseHistorial$token';
}

class HistorialCompartido {
  final String? placa;
  final String? marca;
  final String? modelo;
  final int? anio;
  final int kilometrajeActual;
  final DateTime expiraEn;
  final List<ServicioCompartido> servicios;

  const HistorialCompartido({
    required this.placa,
    required this.marca,
    required this.modelo,
    required this.anio,
    required this.kilometrajeActual,
    required this.expiraEn,
    required this.servicios,
  });

  factory HistorialCompartido.desdeMapa(Map<String, dynamic> d) {
    final crudos = (d['servicios'] as List<dynamic>? ?? const []);
    return HistorialCompartido(
      placa: d['placa'] as String?,
      marca: d['marca'] as String?,
      modelo: d['modelo'] as String?,
      anio: (d['anio'] as num?)?.toInt(),
      kilometrajeActual: (d['kilometraje_actual'] as num?)?.toInt() ?? 0,
      expiraEn: DateTime.fromMillisecondsSinceEpoch(
        (d['expira_en'] as num?)?.toInt() ?? 0,
      ),
      servicios: crudos
          .map(
            (e) => ServicioCompartido.desdeMapa(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
    );
  }
}

/// Un servicio tal como lo ve quien escanea el QR.
///
/// **No tiene importe, y no es un olvido.** El servidor proyecta con allowlist
/// y deja fuera `costo`, `mano_de_obra`, `materiales` y `foto_factura_url`:
/// una factura es un documento financiero del propietario, y quien mira el
/// historial de un coche que quiza compre no necesita saber lo que se pago
/// para comprobar que el mantenimiento se hizo.
class ServicioCompartido {
  final String? tipoServicio;
  final DateTime? fecha;
  final int? kilometraje;
  final String? descripcion;
  final String? idTaller;

  /// `true` si lo registro el propio propietario, no un taller.
  ///
  /// **La UI TIENE que pintarlo distinto.** `firestore.rules:728-729` deja al
  /// propietario crear servicios sobre su vehiculo con el centinela
  /// `id_taller == 'Manual (Propietario)'`, asi que un vendedor puede
  /// escribirse el historial que quiera y ensenar el QR. Si la pantalla pinta
  /// igual lo auto-declarado y lo registrado por un taller, esta funcionalidad
  /// deja de ser una prueba y pasa a ser la palabra del vendedor con el sello
  /// de AutoDoc encima — que es justo lo que viene a evitar.
  final bool autoDeclarado;

  const ServicioCompartido({
    required this.tipoServicio,
    required this.fecha,
    required this.kilometraje,
    required this.descripcion,
    required this.idTaller,
    required this.autoDeclarado,
  });

  factory ServicioCompartido.desdeMapa(Map<String, dynamic> d) {
    // El servidor normaliza `fecha` a epoch ms (`normalizarFecha`), asi que
    // aqui no hay que saber nada de Timestamps.
    final f = d['fecha'];
    return ServicioCompartido(
      tipoServicio: d['tipo_servicio'] as String?,
      fecha: f is num ? DateTime.fromMillisecondsSinceEpoch(f.toInt()) : null,
      kilometraje: (d['kilometraje_servicio'] as num?)?.toInt(),
      descripcion: d['descripcion'] as String?,
      idTaller: d['id_taller'] as String?,
      // Ante la duda, la etiqueta que NO otorga confianza: mismo fail-safe que
      // el servidor.
      autoDeclarado: d['auto_declarado'] as bool? ?? true,
    );
  }
}

/// Ruta a la que lleva un codigo escaneado, o `null` si no es un pase.
///
/// **Existe como funcion pura para que la pueda ejercer un test.** La decision
/// natural seria escribirla dentro del `onDetect` de `MobileScanner`, y ahi no
/// la puede ver ninguna suite: no hay camara en un test de widgets. El unico
/// escaner de la app (`vehicle_search_screen.dart`) interpreta cualquier
/// `rawValue` como una placa, asi que sin esta bifurcacion un pase escaneado
/// acabaria buscando el vehiculo de placa `autodoc://historial/a3f9...` y
/// diciendo "no encontrado" — el fallo se leeria como que el coche no existe,
/// que es justo el diagnostico equivocado.
///
/// El token se escapa con [Uri.encodeComponent] aunque un token legitimo sea
/// 64 hex y no tenga nada que escapar: lo que entra aqui es lo que alguien
/// haya impreso en un QR. Una barra sin escapar parte la ruta en dos segmentos
/// y `/historial_compartido/:token` deja de casar — pantalla desconocida en
/// vez del mensaje "ese codigo no es un pase".
String? rutaDeEscaneoQr(String? crudo) {
  final token = tokenDesdePayloadQr(crudo);
  if (token == null) return null;
  return '/historial_compartido/${Uri.encodeComponent(token)}';
}
