import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'package:uuid/uuid.dart';

import 'package:autodoc/core/models/admin_log_model.dart';
import 'package:autodoc/core/models/estado_verificacion.dart';
import 'package:autodoc/core/theme/app_estado_cuenta.dart';
import 'package:autodoc/core/models/user_model.dart';
import 'package:autodoc/core/models/verificacion_taller_model.dart';

/// Se lanza cuando se intenta una transicion que la maquina de estados no
/// permite, o cuando faltan requisitos para avanzar.
///
/// Existe para que la UI pueda distinguir "esto no se puede hacer todavia" de
/// un fallo de red, y para que el motivo llegue en un texto que se puede
/// enseñar tal cual.
class VerificacionException implements Exception {
  final String mensaje;
  const VerificacionException(this.mensaje);

  @override
  String toString() => mensaje;
}

/// Sube los bytes de un archivo de evidencia a Storage.
///
/// Es una costura inyectable: no hay un mock de `firebase_storage` en las
/// dependencias del proyecto, asi que sacar la subida del servicio deja toda
/// la logica de estados y de Firestore verificable con `FakeFirebaseFirestore`
/// y reduce la parte no testeable a esta unica funcion.
typedef SubidorDeEvidencia =
    Future<void> Function({
      required String ruta,
      required Uint8List bytes,
      required String contentType,
    });

/// Devuelve una URL con la que se puede pintar un objeto de Storage.
///
/// Segunda costura inyectable, por el mismo motivo que [SubidorDeEvidencia].
typedef ResolutorDeUrl = Future<String> Function(String ruta);

/// Lee y escribe el expediente `verificaciones/{uid}` y su evidencia.
///
/// Las transiciones se validan aqui ADEMAS de en firestore.rules, y no en
/// lugar de. Las reglas son la frontera de seguridad —impiden que un taller se
/// autoapruebe— pero son una mala capa de producto: solo saben decir
/// `permission-denied`. Este servicio da el motivo concreto ("te falta la foto
/// de fachada") antes de gastar un viaje al servidor.
class VerificacionService {
  final FirebaseFirestore _firestore;
  final SubidorDeEvidencia _subir;

  /// Reloj inyectable: los tests necesitan fechas deterministas y las
  /// transiciones sellan `fecha_envio` / `fecha_revision`.
  final DateTime Function() _ahora;

  final ResolutorDeUrl _resolverUrl;

  VerificacionService({
    FirebaseFirestore? firestore,
    SubidorDeEvidencia? subidor,
    ResolutorDeUrl? resolutorDeUrl,
    DateTime Function()? ahora,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _subir = subidor ?? _subirAFirebaseStorage,
       _resolverUrl = resolutorDeUrl ?? _urlDeFirebaseStorage,
       _ahora = ahora ?? DateTime.now;

  /// URL para mostrar un archivo de evidencia.
  ///
  /// La ruta se deriva SIEMPRE del uid del taller y del nombre canonico del
  /// slot, nunca de nada que venga suelto en el documento: ver
  /// `VerificacionTallerModel.esNombreValido`, que descarta al leer cualquier
  /// nombre que no sea exactamente `{slot}.{extension}`. Sin eso, un taller
  /// podria escribir un nombre con `../` y hacer que el panel de
  /// administracion fuese a leer un objeto arbitrario del bucket con permisos
  /// de administrador.
  ///
  /// La URL se pide en el momento de mirar y no se persiste: lleva un token
  /// que sirve a cualquiera que lo tenga, saltandose las reglas de Storage.
  Future<String> urlDeEvidencia(String tallerId, DocumentoEvidencia documento) {
    return _resolverUrl(documento.rutaEn(tallerId));
  }

  static const String coleccion = 'verificaciones';

  /// Tope de tamano por archivo de evidencia. Espejo exacto del `< 5 * 1024 *
  /// 1024` de `esImagenValida()`/`esFacturaValida()` en `storage.rules`.
  ///
  /// Se comprueba aqui ADEMAS de en las reglas por el mismo motivo que las
  /// transiciones: las reglas son la frontera de seguridad, pero solo saben
  /// devolver `unauthorized`, y un `unauthorized` por tamano es
  /// indistinguible de uno por cuenta sin permiso. El chequeo importa sobre
  /// todo en web, donde `image_picker` ignora `maxWidth`/`imageQuality` (ver
  /// `image_picker_for_web`): la foto viaja al tamano original y una camara
  /// de movil se pasa de 5 MB sin esfuerzo.
  static const int maxBytesEvidencia = 5 * 1024 * 1024;

  /// Mensaje que ve el taller cuando un archivo de evidencia supera
  /// [maxBytesEvidencia].
  ///
  /// Publico y estatico para que `WorkshopVerificationScreen` pueda rechazar
  /// el mismo archivo ANTES de previsualizarlo, con el mismo texto, en vez de
  /// una segunda variante que pudiera desincronizarse de esta.
  static String mensajeArchivoDemasiadoGrande(int bytesLength) {
    final megas = (bytesLength / (1024 * 1024)).toStringAsFixed(1);
    return 'Ese archivo pesa $megas MB y el limite es 5 MB. Haz la foto con '
        'menos resolucion o recortala antes de subirla.';
  }

  final _uuid = const Uuid();

  DocumentReference<Map<String, dynamic>> _doc(String tallerId) =>
      _firestore.collection(coleccion).doc(tallerId);

  /// Expediente actual. Un taller sin documento todavia no ha empezado el
  /// tramite, y se representa como un expediente vacio en
  /// [EstadoVerificacion.perfilIncompleto] en vez de como `null`: asi la UI no
  /// tiene que distinguir "no existe" de "recien empezado", que se pintan igual.
  Future<VerificacionTallerModel> obtener(String tallerId) async {
    final snapshot = await _doc(tallerId).get();
    return VerificacionTallerModel.fromMap(snapshot.data() ?? {}, tallerId);
  }

  Stream<VerificacionTallerModel> observar(String tallerId) {
    return _doc(tallerId).snapshots().map(
      (snapshot) =>
          VerificacionTallerModel.fromMap(snapshot.data() ?? {}, tallerId),
    );
  }

  /// Expedientes que esperan a un administrador, mas antiguos primero.
  ///
  /// Se incluye [EstadoVerificacion.enRevision] a proposito: si un
  /// administrador abre un caso y no lo resuelve, sin esto el expediente
  /// desapareceria de todas las bandejas y nadie volveria a mirarlo.
  Stream<List<VerificacionTallerModel>> observarBandeja() {
    return _firestore
        .collection(coleccion)
        .where(
          'estado_verificacion',
          whereIn: [
            AppEstadoVerificacion.serializar(
              EstadoVerificacion.listoParaRevision,
            ),
            AppEstadoVerificacion.serializar(EstadoVerificacion.enRevision),
          ],
        )
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map(
                    (doc) =>
                        VerificacionTallerModel.fromMap(doc.data(), doc.id),
                  )
                  .toList()
                ..sort(_porAntiguedadDeEnvio),
        );
  }

  /// Ordena por `fecha_envio` ascendente. Se ordena en cliente y no con un
  /// `orderBy` porque combinarlo con el `whereIn` exigiria un indice compuesto
  /// nuevo, y la bandeja de revision es por naturaleza una lista corta.
  static int _porAntiguedadDeEnvio(
    VerificacionTallerModel a,
    VerificacionTallerModel b,
  ) {
    final fechaA = a.fechaEnvio;
    final fechaB = b.fechaEnvio;
    if (fechaA == null && fechaB == null) {
      return a.idTaller.compareTo(b.idTaller);
    }
    if (fechaA == null) return 1;
    if (fechaB == null) return -1;
    return fechaA.compareTo(fechaB);
  }

  // --- Lado del taller ---

  /// Sube un archivo de evidencia y lo registra en el expediente.
  ///
  /// [nombreOriginal] solo se usa para deducir la extension; el objeto se
  /// guarda siempre como `{slot}.{extension}`, que es lo unico que aceptan las
  /// reglas de Storage. Volver a subir el mismo slot sobrescribe: no hay
  /// huerfanos que limpiar.
  ///
  /// Rechaza si el expediente ya esta `listoParaRevision` o `enRevision`,
  /// igual que `enviarARevision` valida su propia transicion. `firestore.rules`
  /// gobierna `estado` pero no mira dentro de `documentos` (ver el comentario
  /// de `VerificacionTallerModel.esNombreValido`), asi que sin este chequeo el
  /// invariante "no cambiar la evidencia bajo los pies del administrador que
  /// la esta revisando" vivia solo en un boton deshabilitado de la UI: un
  /// cliente con script, o un segundo llamador futuro de este servicio, lo
  /// atraviesa directo.
  Future<void> subirEvidencia({
    required String tallerId,
    required String slot,
    required String nombreOriginal,
    required Uint8List bytes,
  }) async {
    final expediente = await obtener(tallerId);
    if (expediente.estado == EstadoVerificacion.listoParaRevision ||
        expediente.estado == EstadoVerificacion.enRevision) {
      throw const VerificacionException(
        'Tu solicitud ya está en revisión. No puedes cambiar la evidencia '
        'hasta que un administrador la resuelva.',
      );
    }

    final extension = _extensionDe(nombreOriginal);
    final permitidas = VerificacionTallerModel.extensionesPorSlot[slot];

    if (permitidas == null) {
      throw VerificacionException('«$slot» no es un documento del expediente.');
    }
    if (!permitidas.contains(extension)) {
      throw VerificacionException(
        'Ese archivo no vale para este documento. Formatos aceptados: '
        '${permitidas.join(', ')}.',
      );
    }

    if (bytes.lengthInBytes >= maxBytesEvidencia) {
      throw VerificacionException(
        mensajeArchivoDemasiadoGrande(bytes.lengthInBytes),
      );
    }

    final nombreArchivo = '$slot.$extension';
    final documento = DocumentoEvidencia(
      slot: slot,
      nombreArchivo: nombreArchivo,
      fecha: _ahora(),
    );

    // Storage primero: si la subida falla, el expediente no queda diciendo que
    // hay un archivo que en realidad no existe. El fallo en el otro orden
    // (archivo subido, expediente sin anotar) se corrige reintentando.
    await _subir(
      ruta: documento.rutaEn(tallerId),
      bytes: bytes,
      contentType: _contentTypeDe(extension),
    );

    await _doc(tallerId).set({
      'id_taller': tallerId,
      'documentos': {slot: documento.toMap()},
    }, SetOptions(merge: true));
  }

  /// Envia o reenvia el expediente a revision.
  ///
  /// Comprueba las tres cosas por separado para poder decir cual falla: que la
  /// transicion sea legal, que el perfil este completo y que exista la
  /// evidencia minima.
  Future<void> enviarARevision({
    required String tallerId,
    required UserModel perfil,
  }) async {
    final expediente = await obtener(tallerId);

    if (!AppEstadoVerificacion.puedeTransicionar(
      expediente.estado,
      EstadoVerificacion.listoParaRevision,
    )) {
      throw VerificacionException(
        expediente.estado == EstadoVerificacion.listoParaRevision
            ? 'Tu solicitud ya está enviada. Un administrador la revisará.'
            : 'Tu solicitud ya está en revisión.',
      );
    }

    final faltantes = AppEstadoVerificacion.camposFaltantes(perfil);
    if (faltantes.isNotEmpty) {
      throw VerificacionException(
        'Antes de enviar completa: ${faltantes.join(', ')}.',
      );
    }

    if (!expediente.tieneEvidenciaMinima) {
      throw const VerificacionException(
        'Falta la foto de la fachada del taller: es lo que permite comprobar '
        'que el local existe.',
      );
    }

    // El motivo del rechazo anterior se borra: si no, el taller seguiria
    // viendo para siempre por que le rechazaron la version que acaba de
    // corregir. El campo va con FieldValue.delete() y no con null porque
    // firestore.rules mira si la CLAVE existe en el documento resultante.
    await _doc(tallerId).set({
      'id_taller': tallerId,
      'estado_verificacion': AppEstadoVerificacion.serializar(
        EstadoVerificacion.listoParaRevision,
      ),
      'fecha_envio': Timestamp.fromDate(_ahora()),
      'motivo_rechazo': FieldValue.delete(),
      'revisado_por': FieldValue.delete(),
      'fecha_revision': FieldValue.delete(),
    }, SetOptions(merge: true));
  }

  // --- Lado del administrador ---

  /// Marca el expediente como abierto por un administrador.
  ///
  /// Existe como paso propio para que dos administradores no resuelvan el
  /// mismo caso a la vez, y es tambien la puerta de la re-revision: un
  /// expediente ya aprobado vuelve aqui cuando el taller cambia datos
  /// publicos.
  Future<void> tomarCaso({
    required String tallerId,
    required String adminUid,
  }) async {
    await _transicionAdmin(
      tallerId: tallerId,
      adminUid: adminUid,
      destino: EstadoVerificacion.enRevision,
    );
  }

  /// Aprueba el expediente Y habilita la cuenta del taller, en una sola
  /// escritura atomica.
  ///
  /// ## Por que van juntos
  ///
  /// Son dos campos con dos significados distintos —`estado_verificacion` es
  /// el expediente, `usuarios.estado` es la cerradura— y siguen siendo dos
  /// campos a proposito: si mañana se suspende la cuenta, cambia la cerradura
  /// y el expediente sigue diciendo que un humano la verifico el dia X. Pero
  /// que sean dos campos no obliga a que sean dos ACCIONES.
  ///
  /// Cuando eran dos, el modo de fallo era este: el administrador revisaba la
  /// evidencia, aprobaba el expediente, daba por hecho que habia terminado, y
  /// el taller no entraba nunca porque nadie le habia abierto la puerta. Nada
  /// avisaba a nadie.
  ///
  /// Van en un [WriteBatch] y no en dos escrituras seguidas porque a mitad de
  /// camino la divergencia es peor que el fallo entero: un expediente aprobado
  /// con la cuenta cerrada es exactamente el bug que esto viene a cerrar.
  Future<void> aprobar({
    required String tallerId,
    required String adminUid,
  }) async {
    await _resolver(
      tallerId: tallerId,
      adminUid: adminUid,
      destino: EstadoVerificacion.aprobada,
      estadoCuenta: AppEstadoCuenta.valorAprobado,
      accionLog: 'APROBAR_VERIFICACION',
      detalleLog: 'Expediente verificado y cuenta habilitada',
    );
  }

  /// Rechaza el expediente dejando constancia del porque, y deja la cuenta en
  /// `rechazado`.
  ///
  /// El motivo es obligatorio y no puede ser un espacio en blanco: un rechazo
  /// sin motivo deja al taller reenviando lo mismo una y otra vez, que es
  /// trabajo repetido para el propio administrador.
  ///
  /// Un rechazo NO es terminal: `rechazado` sigue fuera de
  /// [AppEstadoCuenta.aprobados], asi que el taller queda retenido en el
  /// onboarding —no expulsado— y puede corregir y reenviar. Las reglas de
  /// `verificaciones` y de Storage autorizan al taller por su uid y su rol,
  /// nunca por su estado, precisamente para que ese camino de vuelta exista.
  Future<void> rechazar({
    required String tallerId,
    required String adminUid,
    required String motivo,
  }) async {
    final limpio = motivo.trim();
    if (limpio.isEmpty) {
      throw const VerificacionException(
        'Escribe el motivo del rechazo: es lo único que le dice al taller qué '
        'corregir.',
      );
    }

    await _resolver(
      tallerId: tallerId,
      adminUid: adminUid,
      destino: EstadoVerificacion.rechazada,
      estadoCuenta: AppEstadoCuenta.valorRechazado,
      motivo: limpio,
      accionLog: 'RECHAZAR_VERIFICACION',
      detalleLog: limpio,
    );
  }

  /// Mueve SOLO el expediente. Lo usa [tomarCaso]: abrir un caso no concede ni
  /// retira nada, asi que no tiene por que tocar la cuenta.
  Future<void> _transicionAdmin({
    required String tallerId,
    required String adminUid,
    required EstadoVerificacion destino,
  }) async {
    await _validarTransicion(tallerId, destino);

    await _doc(tallerId).set({
      'id_taller': tallerId,
      'estado_verificacion': AppEstadoVerificacion.serializar(destino),
      'revisado_por': adminUid,
      'fecha_revision': Timestamp.fromDate(_ahora()),
    }, SetOptions(merge: true));
  }

  /// Resuelve el expediente y la cuenta a la vez, mas la entrada de auditoria.
  ///
  /// Las tres escrituras van en el mismo lote: expediente, cerradura y log.
  /// El log se construye con [AdminLogModel] y no a mano para que la forma del
  /// documento tenga una sola definicion, la misma que usa `AdminService`, y
  /// se firma con `adminUid` porque `firestore.rules` exige que `admin_uid`
  /// coincida con el llamante.
  Future<void> _resolver({
    required String tallerId,
    required String adminUid,
    required EstadoVerificacion destino,
    required String estadoCuenta,
    required String accionLog,
    required String detalleLog,
    String? motivo,
  }) async {
    await _validarTransicion(tallerId, destino);

    final ahora = _ahora();
    final lote = _firestore.batch();

    lote.set(_doc(tallerId), {
      'id_taller': tallerId,
      'estado_verificacion': AppEstadoVerificacion.serializar(destino),
      'revisado_por': adminUid,
      'fecha_revision': Timestamp.fromDate(ahora),
      // Un rechazo escribe el motivo; una aprobacion borra el que quedara de
      // una vuelta anterior, para que un taller ya aprobado no siga
      // arrastrando por que se le rechazo en su dia.
      'motivo_rechazo': motivo ?? FieldValue.delete(),
    }, SetOptions(merge: true));

    // `set(merge:true)` y no `update()`: en un lote, `update()` sobre un
    // documento inexistente hace fallar el lote entero. Si el doc de usuario
    // faltase, un merge lo trataria como create y las reglas lo denegarian
    // igual, que es el resultado correcto pero sin llevarse por delante el
    // resto.
    lote.set(_firestore.collection('usuarios').doc(tallerId), {
      'estado': estadoCuenta,
    }, SetOptions(merge: true));

    final log = AdminLogModel(
      idLog: _uuid.v4(),
      adminUid: adminUid,
      accion: accionLog,
      modulo: 'Verificacion',
      referenciaId: tallerId,
      detalle: detalleLog,
      fecha: ahora,
    );
    lote.set(_firestore.collection('admin_logs').doc(log.idLog), log.toMap());

    await lote.commit();
  }

  Future<void> _validarTransicion(
    String tallerId,
    EstadoVerificacion destino,
  ) async {
    final expediente = await obtener(tallerId);
    if (!AppEstadoVerificacion.puedeTransicionar(expediente.estado, destino)) {
      throw VerificacionException(
        'No se puede pasar de «${AppEstadoVerificacion.serializar(expediente.estado)}» '
        'a «${AppEstadoVerificacion.serializar(destino)}».',
      );
    }
  }

  // --- Utilidades ---

  static String _extensionDe(String nombre) {
    final punto = nombre.lastIndexOf('.');
    if (punto == -1 || punto == nombre.length - 1) return '';
    var extension = nombre.substring(punto + 1).toLowerCase();
    // `jpeg` y `jpg` son el mismo formato; se normaliza para no tener que
    // duplicar el nombre de archivo canonico segun como se llamase el original.
    if (extension == 'jpeg') extension = 'jpg';
    return extension;
  }

  static String _contentTypeDe(String extension) {
    switch (extension) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  static Future<String> _urlDeFirebaseStorage(String ruta) {
    return FirebaseStorage.instance.ref().child(ruta).getDownloadURL();
  }

  static Future<void> _subirAFirebaseStorage({
    required String ruta,
    required Uint8List bytes,
    required String contentType,
  }) async {
    await FirebaseStorage.instance
        .ref()
        .child(ruta)
        .putData(bytes, SettableMetadata(contentType: contentType));
  }
}
