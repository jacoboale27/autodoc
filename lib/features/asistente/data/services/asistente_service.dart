import 'package:cloud_functions/cloud_functions.dart';

/// IA-01 — cliente del callable `asistenteAutoDoc`.
///
/// **Por que un callable y no Firestore.** Las tres colecciones del asistente
/// (`consultas_ia_control`, `explicaciones_ia`, `configuracion`) estan cerradas
/// al cliente en `firestore.rules`, y no por comodidad: el cupo diario y el
/// interruptor de apagado no pueden vivir donde el cliente los pueda tocar.
/// Toda la autorizacion —rol, estado del taller, taller efectivo— ocurre en
/// `functions/src/agenda.js`, antes de que el modelo vea un solo dato. Esta
/// clase no decide nada y no valida nada que importe.
///
/// **El idioma se PASA, no se infiere.** Es la cicatriz de INNO-01: la app se
/// renderiza en el idioma del navegador, asi que el servidor no puede adivinar
/// en que idioma contestar. Lo manda la pantalla, leido del `Localizations`
/// activo.
///
/// La llamada se inyecta por el mismo motivo que en `PaseHistorialService`:
/// mockear `HttpsCallable` de verdad exige encadenar tres dobles que no
/// aportan nada, porque la frontera de seguridad ya esta probada del lado
/// servidor (`functions/test/asistente.test.js`, 29 casos).
class AsistenteService {
  final Future<Map<String, dynamic>> Function(String pregunta, String idioma)
  _preguntar;

  AsistenteService({
    Future<Map<String, dynamic>> Function(String pregunta, String idioma)?
    preguntar,
  }) : _preguntar = preguntar ?? _preguntarPorCallable;

  static Future<Map<String, dynamic>> _preguntarPorCallable(
    String pregunta,
    String idioma,
  ) async {
    final r = await FirebaseFunctions.instance
        .httpsCallable('asistenteAutoDoc')
        .call<Map<String, dynamic>>({'pregunta': pregunta, 'idioma': idioma});
    return Map<String, dynamic>.from(r.data);
  }

  /// Un turno. No hay historial ni memoria: cada pregunta viaja sola.
  Future<RespuestaAsistente> preguntar(
    String pregunta, {
    required String idioma,
  }) async {
    final d = await _preguntar(pregunta, idioma);
    return RespuestaAsistente.desdeMapa(d);
  }
}

/// Lo que devuelve el callable.
///
/// [intencion] es una de las tres etiquetas del enum cerrado del servidor
/// (`agenda`, `explicar`, `fuera_de_alcance`). La pantalla la usa **solo para
/// decorar** —un icono y un color distintos para el rechazo—, nunca para
/// decidir que pintar: el texto ya viene redactado y localizado desde el
/// servidor, incluido el del rechazo, que es fijo y no pasa por el modelo.
class RespuestaAsistente {
  final String intencion;
  final String texto;

  /// `true` si la respuesta salio de la cache de explicaciones. No se pinta;
  /// existe para que un test pueda afirmar que la segunda pregunta igual no
  /// gasto una llamada al modelo.
  final bool cacheada;

  /// Cuantos compromisos traia el envelope. `null` si la intencion no era
  /// `agenda`; `0` es la agenda vacia, que el servidor contesta con un texto
  /// fijo y sin llamar al modelo.
  final int? items;

  const RespuestaAsistente({
    required this.intencion,
    required this.texto,
    this.cacheada = false,
    this.items,
  });

  /// `true` si el servidor rechazo la pregunta por estar fuera del alcance.
  bool get fueraDeAlcance => intencion == 'fuera_de_alcance';

  factory RespuestaAsistente.desdeMapa(Map<String, dynamic> d) {
    return RespuestaAsistente(
      // Ante la duda, la etiqueta que no promete nada: mismo fail-safe que el
      // servidor, donde cualquier etiqueta que el modelo se invente cae a
      // `fuera_de_alcance`.
      intencion: d['intencion'] as String? ?? 'fuera_de_alcance',
      texto: (d['texto'] as String? ?? '').trim(),
      cacheada: d['cacheada'] as bool? ?? false,
      items: (d['items'] as num?)?.toInt(),
    );
  }
}
