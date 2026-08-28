import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:autodoc/core/models/estado_verificacion.dart';

/// Un archivo de evidencia ya subido a Storage.
///
/// Guarda el nombre de archivo, no solo la fecha, porque la pantalla del
/// administrador reconstruye la ruta de Storage (`verificaciones/{uid}/{nombre}`)
/// para pedir la URL en el momento de mirarla. La alternativa —persistir la
/// download URL en Firestore— es peor: esa URL lleva un token que sirve a
/// cualquiera que la tenga, saltandose las reglas de Storage, y quedaria
/// escrita en un documento que tambien lee el propio taller.
class DocumentoEvidencia {
  /// Slot al que pertenece: `nit`, `fachada` o `rotulo`.
  final String slot;

  /// Nombre del objeto en Storage, siempre `{slot}.{extension}`.
  final String nombreArchivo;

  /// Cuando se subio.
  final DateTime fecha;

  const DocumentoEvidencia({
    required this.slot,
    required this.nombreArchivo,
    required this.fecha,
  });

  /// Ruta completa del objeto en Storage.
  String rutaEn(String tallerId) => 'verificaciones/$tallerId/$nombreArchivo';

  Map<String, dynamic> toMap() => {
    'nombre_archivo': nombreArchivo,
    'fecha': Timestamp.fromDate(fecha),
  };
}

/// Por que un expediente ya aprobado volvio a la cola.
///
/// Lo escribe `functions/src/reabrirVerificacion.js` con SDK de Admin cuando
/// un taller aprobado cambia datos que un humano habia contrastado. Sin este
/// registro el administrador abre la bandeja, se encuentra un taller que el
/// mismo aprobo y no tiene forma de saber que mirar.
class ReaperturaVerificacion {
  /// Cuando se reabrio.
  final DateTime fecha;

  /// Etiquetas legibles de los campos que cambiaron, tal y como las genera
  /// `CAMPOS_DE_IDENTIDAD` en la Cloud Function.
  final List<String> campos;

  const ReaperturaVerificacion({required this.fecha, required this.campos});
}

/// Expediente de verificacion de un taller: documento `verificaciones/{uid}`.
///
/// ## Por que vive fuera de `usuarios`
///
/// `publishTallerProfile` proyecta campos de `usuarios/{uid}` a
/// `talleres/{uid}`, que es de lectura **publica y anonima**
/// (`allow read: if true` en firestore.rules). Cualquier campo nuevo en
/// `usuarios` esta a un descuido de `CAMPOS_PUBLICOS` de acabar publicado.
///
/// Aqui viajan datos que no pueden salir jamas: el motivo de un rechazo, quien
/// reviso, y el rastro de documentos de identidad del negocio. Ponerlos en una
/// coleccion que el proyector ni mira convierte esa fuga en estructuralmente
/// imposible, en vez de en una lista que hay que acordarse de mantener.
class VerificacionTallerModel {
  /// Uid del taller. Es tambien el id del documento: un expediente por taller.
  final String idTaller;

  final EstadoVerificacion estado;

  /// Cuando el expediente paso a [EstadoVerificacion.listoParaRevision].
  final DateTime? fechaEnvio;

  /// Cuando un administrador lo resolvio (aprobada o rechazada).
  final DateTime? fechaRevision;

  /// Por que se rechazo. Sin esto el taller no sabe que corregir.
  final String? motivoRechazo;

  /// Uid del administrador que resolvio el expediente.
  final String? revisadoPor;

  /// Evidencia subida, indexada por slot.
  ///
  /// Los slots son fijos a proposito: las reglas de Storage no pueden CONTAR
  /// archivos, pero si restringir el nombre, asi que un whitelist de 3 nombres
  /// da un tope duro de 3 documentos sin contador, sin Cloud Function y sin
  /// limpieza de huerfanos (resubir sobrescribe).
  final Map<String, DocumentoEvidencia> documentos;

  /// Presente solo mientras el expediente esta en la cola por una re-revision,
  /// no por un envio del taller.
  final ReaperturaVerificacion? reapertura;

  /// Extensiones aceptadas por slot. Debe coincidir con el `matches()` del
  /// bloque `verificaciones/{tallerId}/{fileName}` de `storage.rules`.
  ///
  /// El PDF solo vale para el NIT, que es lo unico que llega razonablemente
  /// como escaneo; fachada y rotulo son fotos.
  static const Map<String, Set<String>> extensionesPorSlot = {
    'nit': {'jpg', 'jpeg', 'png', 'webp', 'pdf'},
    'fachada': {'jpg', 'jpeg', 'png', 'webp'},
    'rotulo': {'jpg', 'jpeg', 'png', 'webp'},
  };

  /// Nombres de slot aceptados.
  static Set<String> get slotsPermitidos => extensionesPorSlot.keys.toSet();

  /// Slot cuya ausencia bloquea la revision. La foto de fachada es la unica
  /// evidencia que ata el expediente a un local fisico; el NIT y el rotulo
  /// refuerzan, pero no sustituyen.
  static const String slotObligatorio = 'fachada';

  /// ¿Es `nombreArchivo` un nombre legitimo para `slot`?
  ///
  /// Esto NO es cosmetico. `documentos` lo escribe el propio taller (ver el
  /// `esWriteDeTaller()` de firestore.rules, que gobierna el estado pero no
  /// mira dentro de este mapa), y la pantalla del administrador usa el nombre
  /// para construir una ruta de Storage que va a leer con permisos de
  /// administrador. Sin esta validacion, un taller podria escribir
  /// `../../otra/cosa.jpg` y hacer que el panel de administracion fuese a
  /// buscar un objeto arbitrario del bucket. Se exige igualdad exacta contra
  /// `{slot}.{extension}`, no un `matches` laxo: asi no hay nada que escapar.
  static bool esNombreValido(String slot, String nombreArchivo) {
    final extensiones = extensionesPorSlot[slot];
    if (extensiones == null) return false;
    return extensiones.any((ext) => nombreArchivo == '$slot.$ext');
  }

  const VerificacionTallerModel({
    required this.idTaller,
    required this.estado,
    this.fechaEnvio,
    this.fechaRevision,
    this.motivoRechazo,
    this.revisadoPor,
    this.documentos = const {},
    this.reapertura,
  });

  /// ¿Esta en la cola porque un taller ya aprobado cambio datos verificados?
  ///
  /// La distincion importa en las dos pantallas: al taller hay que decirle que
  /// sigue operando, y al administrador, que esto no es un alta.
  bool get esReRevision =>
      reapertura != null && estado == EstadoVerificacion.listoParaRevision;

  /// ¿Hay al menos la evidencia minima para que un administrador pueda mirar?
  bool get tieneEvidenciaMinima => documentos.containsKey(slotObligatorio);

  /// Slots que el taller todavia no ha subido, en orden estable para pintarlos
  /// como checklist.
  List<String> get slotsFaltantes => extensionesPorSlot.keys
      .where((slot) => !documentos.containsKey(slot))
      .toList(growable: false);

  VerificacionTallerModel copyWith({
    String? idTaller,
    EstadoVerificacion? estado,
    DateTime? fechaEnvio,
    DateTime? fechaRevision,
    String? motivoRechazo,
    String? revisadoPor,
    Map<String, DocumentoEvidencia>? documentos,
    ReaperturaVerificacion? reapertura,

    /// Borra [motivoRechazo] en lugar de conservarlo.
    ///
    /// `copyWith(motivoRechazo: null)` no puede expresar esto: null significa
    /// "no lo toques". Sin esta bandera, un taller rechazado que corrige y
    /// reenvia arrastraria para siempre el motivo del rechazo anterior.
    bool limpiarMotivoRechazo = false,
  }) {
    return VerificacionTallerModel(
      idTaller: idTaller ?? this.idTaller,
      estado: estado ?? this.estado,
      fechaEnvio: fechaEnvio ?? this.fechaEnvio,
      fechaRevision: fechaRevision ?? this.fechaRevision,
      motivoRechazo: limpiarMotivoRechazo
          ? null
          : (motivoRechazo ?? this.motivoRechazo),
      revisadoPor: revisadoPor ?? this.revisadoPor,
      documentos: documentos ?? this.documentos,
      reapertura: reapertura ?? this.reapertura,
    );
  }

  /// Serializa el expediente SIN [reapertura], a proposito.
  ///
  /// Una reapertura solo la escribe la Cloud Function con SDK de Admin. Si
  /// esta clave viajara en el payload del cliente, un taller podria fabricar o
  /// borrar el motivo por el que su expediente volvio a la cola, que es
  /// justamente lo unico que el administrador tiene para saber que mirar.
  Map<String, dynamic> toMap() {
    return {
      'id_taller': idTaller,
      'estado_verificacion': AppEstadoVerificacion.serializar(estado),
      if (fechaEnvio != null) 'fecha_envio': Timestamp.fromDate(fechaEnvio!),
      if (fechaRevision != null)
        'fecha_revision': Timestamp.fromDate(fechaRevision!),
      if (motivoRechazo != null) 'motivo_rechazo': motivoRechazo,
      if (revisadoPor != null) 'revisado_por': revisadoPor,
      'documentos': documentos.map(
        (slot, documento) => MapEntry(slot, documento.toMap()),
      ),
    };
  }

  factory VerificacionTallerModel.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    final documentos = <String, DocumentoEvidencia>{};
    final crudos = map['documentos'];
    if (crudos is Map) {
      crudos.forEach((slot, valor) {
        final documento = _parseDocumento(slot.toString(), valor);
        if (documento != null) documentos[documento.slot] = documento;
      });
    }

    final rawId = map['id_taller'];
    final id = (rawId != null && rawId.toString().isNotEmpty)
        ? rawId.toString()
        : documentId;

    return VerificacionTallerModel(
      idTaller: id,
      estado: AppEstadoVerificacion.parse(
        map['estado_verificacion'] as String?,
      ),
      fechaEnvio: _parseFecha(map['fecha_envio']),
      fechaRevision: _parseFecha(map['fecha_revision']),
      motivoRechazo: map['motivo_rechazo'] as String?,
      revisadoPor: map['revisado_por'] as String?,
      documentos: documentos,
      reapertura: _parseReapertura(map['reapertura']),
    );
  }

  /// Una reapertura sin fecha no se puede ordenar ni fechar en pantalla, y una
  /// sin campos no dice nada: en ambos casos vale mas no pintar nada que
  /// pintar un aviso vacio.
  static ReaperturaVerificacion? _parseReapertura(dynamic valor) {
    if (valor is! Map) return null;

    final fecha = _parseFecha(valor['fecha']);
    if (fecha == null) return null;

    final crudos = valor['campos'];
    if (crudos is! List) return null;

    final campos = crudos
        .map((campo) => campo.toString().trim())
        .where((campo) => campo.isNotEmpty)
        .toList(growable: false);
    if (campos.isEmpty) return null;

    return ReaperturaVerificacion(fecha: fecha, campos: campos);
  }

  static DateTime? _parseFecha(dynamic valor) {
    if (valor == null) return null;
    if (valor is Timestamp) return valor.toDate();
    if (valor is DateTime) return valor;
    if (valor is String) return DateTime.tryParse(valor);
    if (valor is int) return DateTime.fromMillisecondsSinceEpoch(valor);
    return null;
  }

  /// Devuelve `null` —descartando la entrada— ante cualquier cosa que no sea
  /// una evidencia bien formada. Un slot o un nombre de archivo fuera de la
  /// lista solo puede venir de un write manipulado, y no debe llegar a que la
  /// pantalla del administrador lo convierta en una ruta de Storage.
  static DocumentoEvidencia? _parseDocumento(String slot, dynamic valor) {
    if (!slotsPermitidos.contains(slot)) return null;
    if (valor is! Map) return null;

    final nombreArchivo = valor['nombre_archivo']?.toString();
    if (nombreArchivo == null || !esNombreValido(slot, nombreArchivo)) {
      return null;
    }

    final fecha = _parseFecha(valor['fecha']);
    if (fecha == null) return null;

    return DocumentoEvidencia(
      slot: slot,
      nombreArchivo: nombreArchivo,
      fecha: fecha,
    );
  }
}
