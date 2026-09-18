import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hive/hive.dart';
import '../../../../core/constants/storage_paths.dart';
import '../../data/models/conversacion_model.dart';
import '../../data/models/mensaje_model.dart';
import '../../data/models/cotizacion_model.dart';
import '../../data/repositories/chat_repository.dart';
import 'package:autodoc/core/utils/mensaje_de_error.dart';

class ChatProvider extends ChangeNotifier {
  final ChatRepository _chatRepository;

  ChatProvider({ChatRepository? repository})
    : _chatRepository = repository ?? ChatRepository();

  List<ConversacionModel> _conversaciones = [];
  List<ConversacionModel> get conversaciones => _conversaciones;

  /// `true` cuando la bandeja llegó al tope de [maxConversacionesBandeja] y
  /// por tanto hay conversaciones que NO se están mostrando.
  ///
  /// Se deriva de haber recibido exactamente el tope: es lo único que el
  /// cliente puede saber sin pagar otra consulta. Puede dar un falso positivo
  /// con justo 100 conversaciones y ni una más — un precio ridículo comparado
  /// con recortar en silencio.
  bool get bandejaTruncada =>
      _conversaciones.length >= maxConversacionesBandeja;

  List<MensajeModel> _mensajesActuales = [];
  List<MensajeModel> get mensajesActuales => _mensajesActuales;

  /// `true` cuando el hilo llegó al tope de [maxMensajesHilo]: hay mensajes
  /// MÁS ANTIGUOS que no se están mostrando. Los recientes están todos, que es
  /// de qué lado tiene que caer el recorte.
  bool get hiloTruncado => _mensajesActuales.length >= maxMensajesHilo;

  StreamSubscription? _conversacionesSub;
  StreamSubscription? _mensajesSub;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  /// ¿Ha llegado ya el primer snapshot del stream de conversaciones?
  ///
  /// `isLoading` no sirve para esto: lo comparten los flujos de envío, subida
  /// y cotización, y `inicializarConversaciones` nunca llegaba a tocarlo. El
  /// resultado era que la bandeja pintaba el estado vacío —«No tienes
  /// mensajes aún — Contacta a un taller para iniciar un chat»— durante la
  /// carga, incluso con ocho conversaciones existentes y siendo el usuario un
  /// taller (al que ese consejo ni siquiera le corresponde). Se pobló segundos
  /// después. Un estado vacío que miente es peor que un spinner.
  bool _conversacionesCargadas = false;
  bool get conversacionesCargadas => _conversacionesCargadas;

  int get totalNoLeidosPropietario =>
      _conversaciones.fold(0, (sum, item) => sum + item.noLeidosPropietario);
  int get totalNoLeidosMecanico =>
      _conversaciones.fold(0, (sum, item) => sum + item.noLeidosMecanico);

  // ── Lector de la conversación abierta ──
  //
  // Observaciones del 2026-09-18: «los cheques de los mensajes no aparecen
  // hasta que se refresca el chat». `marcarComoLeidos` solo se llamaba AL
  // ABRIR la conversación, así que con las dos personas dentro, lo que una
  // escribía nunca pasaba a "visto" para la otra hasta que alguna salía y
  // volvía a entrar. Ahora, mientras una conversación está abierta y visible,
  // cada mensaje nuevo del otro se marca como visto en cuanto llega.
  String? _lectorConversacionId;
  String? _lectorUid;
  bool _lectorEsMecanico = false;
  bool _lecturaEnPausa = false;
  bool _marcandoLeidos = false;
  bool _marcarOtraVez = false;

  /// Conversación que el usuario tiene abierta en pantalla, o `null`. La usa
  /// también el aviso de mensajes nuevos para no avisar de lo que ya se ve.
  String? get conversacionAbierta =>
      _lecturaEnPausa ? null : _lectorConversacionId;

  /// Registra que [lectorId] está viendo [conversacionId]: a partir de aquí,
  /// los mensajes del otro participante que lleguen se marcan como vistos.
  void abrirConversacion(
    String conversacionId, {
    required String lectorId,
    required bool lectorEsMecanico,
  }) {
    _lectorConversacionId = conversacionId;
    _lectorUid = lectorId;
    _lectorEsMecanico = lectorEsMecanico;
    _lecturaEnPausa = false;
    _marcarLeidosSiHaceFalta();
  }

  /// La pantalla del chat se cerró: lo que llegue ya no lo está viendo nadie.
  void cerrarConversacion(String conversacionId) {
    if (_lectorConversacionId != conversacionId) return;
    _lectorConversacionId = null;
    _lectorUid = null;
  }

  /// La app pasó a segundo plano (o la pestaña del navegador quedó oculta):
  /// los mensajes que lleguen mientras tanto NO se han visto. Al volver se
  /// marcan los que se acumularon.
  void pausarLectura(bool enPausa) {
    if (_lecturaEnPausa == enPausa) return;
    _lecturaEnPausa = enPausa;
    if (!enPausa) _marcarLeidosSiHaceFalta();
  }

  void _marcarLeidosSiHaceFalta() {
    final conversacionId = _lectorConversacionId;
    final uid = _lectorUid;
    if (conversacionId == null || uid == null || uid.isEmpty) return;
    if (_lecturaEnPausa) return;
    final hayPorVer = _mensajesActuales.any(
      (m) => m.idRemitente != uid && m.estado != kEstadoMensajeVisto,
    );
    if (!hayPorVer) return;
    // Una sola marcación en vuelo: si llegan más mensajes mientras tanto, se
    // repite al terminar en vez de lanzar consultas en paralelo.
    if (_marcandoLeidos) {
      _marcarOtraVez = true;
      return;
    }
    _marcandoLeidos = true;
    marcarComoLeidos(conversacionId, _lectorEsMecanico, uid).whenComplete(() {
      _marcandoLeidos = false;
      if (_marcarOtraVez) {
        _marcarOtraVez = false;
        _marcarLeidosSiHaceFalta();
      }
    });
  }

  @override
  void dispose() {
    _conversacionesSub?.cancel();
    _mensajesSub?.cancel();
    super.dispose();
  }

  /// Vacia el estado por usuario y cancela las suscripciones activas. Se
  /// llama al cerrar sesion: sin cancelar las suscripciones, siguen
  /// escuchando con el uid del usuario saliente y repueblan las listas en
  /// cuanto llegue el siguiente snapshot.
  void clear() {
    _conversacionesSub?.cancel();
    _mensajesSub?.cancel();
    _conversacionesSub = null;
    _mensajesSub = null;
    _conversaciones = [];
    _mensajesActuales = [];
    _error = null;
    _isLoading = false;
    _conversacionesCargadas = false;
    _lectorConversacionId = null;
    _lectorUid = null;
    _lecturaEnPausa = false;
    notifyListeners();
  }

  void inicializarConversaciones(String userId, bool isMecanico) {
    _conversacionesSub?.cancel();
    _error = null;
    _conversacionesCargadas = false;
    _conversacionesSub = _chatRepository
        .streamConversaciones(userId, isMecanico)
        .listen(
          (data) {
            _error = null;
            _conversaciones = data;
            _conversacionesCargadas = true;
            notifyListeners();
          },
          onError: (e) {
            _error = mensajeSeguroDeError(e);
            _conversacionesCargadas = true;
            notifyListeners();
          },
        );
  }

  void inicializarMensajes(String conversacionId) {
    _isLoading = true;
    _error = null;

    // Load from cache first
    try {
      if (Hive.isBoxOpen('mensajes')) {
        final box = Hive.box<MensajeModel>('mensajes');
        final prefix = '${conversacionId}_';
        final cached = box
            .toMap()
            .entries
            .where((e) => e.key.toString().startsWith(prefix))
            .map((e) => e.value)
            .toList();
        if (cached.isNotEmpty) {
          cached.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          _mensajesActuales = cached;
        }
      }
    } catch (e) {
      debugPrint('Error loading cache: $e');
    }

    notifyListeners();

    _mensajesSub?.cancel();
    _mensajesSub = _chatRepository
        .streamMensajes(conversacionId)
        .listen(
          (data) {
            _error = null;
            _mensajesActuales = data;

            // Actualizar cache
            try {
              if (Hive.isBoxOpen('mensajes')) {
                final box = Hive.box<MensajeModel>('mensajes');
                for (final m in data) {
                  box.put('${conversacionId}_${m.id}', m);
                }
              }
            } catch (e) {
              debugPrint('Error saving cache: $e');
            }

            _isLoading = false;
            notifyListeners();
            if (_lectorConversacionId == conversacionId) {
              _marcarLeidosSiHaceFalta();
            }
          },
          onError: (e) {
            _error = mensajeSeguroDeError(e);
            _isLoading = false;
            notifyListeners();
          },
        );
  }

  Future<String> iniciarOCrearConversacion({
    required String idPropietario,
    required String idMecanico,
    required String nombrePropietario,
    required String nombreMecanico,
    String? idVehiculo,
    String? idTaller,
    String? fotoPropietario,
    String? fotoMecanico,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final conversacionExistente = await _chatRepository.buscarConversacion(
        idPropietario: idPropietario,
        idMecanico: idMecanico,
        idVehiculo: idVehiculo,
      );

      if (conversacionExistente != null) {
        _isLoading = false;
        notifyListeners();
        return conversacionExistente.id;
      }

      final nuevaConversacion = ConversacionModel(
        id: '', // Se asigna en el repo
        idPropietario: idPropietario,
        idMecanico: idMecanico,
        nombrePropietario: nombrePropietario,
        nombreMecanico: nombreMecanico,
        idVehiculo: idVehiculo,
        idTaller: idTaller,
        ultimoMensaje: 'Chat iniciado',
        ultimoMensajeTs: DateTime.now(),
        fotoPropietario: fotoPropietario,
        fotoMecanico: fotoMecanico,
      );

      final id = await _chatRepository.crearConversacion(nuevaConversacion);
      _isLoading = false;
      notifyListeners();
      return id;
    } catch (e) {
      _error = mensajeSeguroDeError(e);
      _isLoading = false;
      notifyListeners();
      return '';
    }
  }

  /// Envia un mensaje. Devuelve `true` si llego al servidor.
  ///
  /// **El valor de retorno es la mitad del arreglo, no un detalle.** Antes era
  /// `Future<void>` y el `catch` de abajo se tragaba la excepcion: la pantalla
  /// no tenia forma de distinguir un envio correcto de uno fallido, porque
  /// esperar un `Future<void>` que traga el error completa igual de bien en
  /// los dos casos. Como ademas `chat_screen.dart` limpia el compositor en la
  /// linea siguiente al envio, un fallo de red se llevaba el texto por delante
  /// sin avisar a nadie. Lo levanto H-01 refutando un cargo distinto.
  Future<bool> enviarMensaje({
    required String conversacionId,
    required String contenido,
    required String remitenteId,
    required String receptorId,
    required bool isMecanicoRemitente,
    String tipo = 'texto',
    Map<String, dynamic>? metadata,
    String? urlArchivo,
    int? duracionSegundos,
  }) async {
    try {
      final mensaje = MensajeModel(
        id: '', // Firestore generará el ID
        idRemitente: remitenteId,
        contenido: contenido,
        tipo: tipo,
        metadata: metadata,
        timestamp: DateTime.now(),
        urlArchivo: urlArchivo,
        duracionSegundos: duracionSegundos,
      );

      await _chatRepository.enviarMensaje(
        conversacionId: conversacionId,
        mensaje: mensaje,
        receptorId: receptorId,
        isMecanicoRemitente: isMecanicoRemitente,
      );
      return true;
    } catch (e) {
      _error = mensajeSeguroDeError(e, accion: 'No se pudo enviar el mensaje');
      notifyListeners();
      return false;
    }
  }

  Future<void> marcarComoLeidos(
    String conversacionId,
    bool isMecanico,
    String currentUserId,
  ) async {
    try {
      await _chatRepository.marcarComoLeidos(
        conversacionId,
        isMecanico,
        currentUserId,
      );
    } catch (e) {
      _error = mensajeSeguroDeError(e);
      notifyListeners();
    }
  }

  Future<void> actualizarMetadatosMensaje(
    String conversacionId,
    String mensajeId,
    Map<String, dynamic> metadata,
  ) async {
    try {
      await _chatRepository.actualizarMetadatosMensaje(
        conversacionId,
        mensajeId,
        metadata,
      );
    } catch (e) {
      _error = mensajeSeguroDeError(e);
      notifyListeners();
    }
  }

  Future<String?> crearCotizacion(CotizacionModel cotizacion) async {
    try {
      return await _chatRepository.crearCotizacion(cotizacion);
    } catch (e) {
      _error = mensajeSeguroDeError(e);
      notifyListeners();
      return null;
    }
  }

  /// Crea la cotización y, solo si se creó correctamente, envía el mensaje
  /// `cotizacion_card` que la referencia. Si la creación falla, no se envía
  /// ningún mensaje (antes se enviaba igual con `id_cotizacion: null`, lo
  /// que producía una burbuja en blanco — ver CotizacionChatCard).
  Future<bool> enviarCotizacion({
    required CotizacionModel cotizacion,
    required String conversacionId,
    required String contenido,
    required String remitenteId,
    required String receptorId,
    required bool isMecanicoRemitente,
  }) async {
    final cotizacionId = await crearCotizacion(cotizacion);
    if (cotizacionId == null) {
      _error = 'No se pudo crear la cotización. Intenta de nuevo.';
      notifyListeners();
      return false;
    }

    await enviarMensaje(
      conversacionId: conversacionId,
      contenido: contenido,
      remitenteId: remitenteId,
      receptorId: receptorId,
      isMecanicoRemitente: isMecanicoRemitente,
      tipo: 'cotizacion_card',
      metadata: {'id_cotizacion': cotizacionId, 'estado': 'pendiente'},
    );
    return true;
  }

  Future<List<double>> obtenerBeneficiosCotizacion(String cotizacionId) async {
    try {
      return await _chatRepository.obtenerBeneficiosCotizacion(cotizacionId);
    } catch (e) {
      return const [];
    }
  }

  Future<void> actualizarEstadoCotizacion(String id, String estado) async {
    try {
      await _chatRepository.actualizarEstadoCotizacion(id, estado);
    } catch (e) {
      _error = mensajeSeguroDeError(e);
      notifyListeners();
    }
  }

  Future<String?> subirImagenChat(
    String conversacionId,
    XFile imageFile,
  ) async {
    try {
      _isLoading = true;
      notifyListeners();

      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance
          .ref()
          .child('chat_images')
          .child(conversacionId)
          .child(fileName);
      final bytes = await imageFile.readAsBytes();
      final metadata = SettableMetadata(contentType: 'image/jpeg');
      await ref.putData(bytes, metadata);
      final url = await ref.getDownloadURL();

      _isLoading = false;
      notifyListeners();
      return url;
    } catch (e) {
      _error = mensajeSeguroDeError(e);
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<String?> subirAudioChat(String conversacionId, File audioFile) async {
    try {
      _isLoading = true;
      notifyListeners();

      final fileName = '${DateTime.now().millisecondsSinceEpoch}.m4a';
      final ref = FirebaseStorage.instance
          .ref()
          .child(StoragePaths.chatAudios)
          .child(conversacionId)
          .child(fileName);
      final bytes = await audioFile.readAsBytes();
      final metadata = SettableMetadata(contentType: 'audio/mp4');
      await ref.putData(bytes, metadata);
      final url = await ref.getDownloadURL();

      _isLoading = false;
      notifyListeners();
      return url;
    } catch (e) {
      _error = mensajeSeguroDeError(e);
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Edita el texto de un mensaje propio. Devuelve `false` si no se pudo
  /// (p.ej. las reglas lo rechazan porque no es el autor, o el mensaje no
  /// es de tipo texto — ver `firestore.rules`).
  Future<bool> editarMensaje(
    String conversacionId,
    String mensajeId,
    String nuevoContenido,
  ) async {
    try {
      await _chatRepository.editarMensaje(
        conversacionId,
        mensajeId,
        nuevoContenido,
      );
      return true;
    } catch (e) {
      _error = mensajeSeguroDeError(e);
      notifyListeners();
      return false;
    }
  }

  /// Borra un mensaje. Devuelve `false` si no se pudo.
  ///
  /// Devuelve resultado en vez de `void` porque el unico rastro del fallo era
  /// `_error`, que nadie mira: al usuario le quedaba un mensaje intacto sin
  /// explicacion.
  Future<bool> deleteMensaje(String conversacionId, String mensajeId) async {
    try {
      await _chatRepository.deleteMensaje(conversacionId, mensajeId);
      return true;
    } catch (e) {
      _error = mensajeSeguroDeError(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> setTypingStatus(
    String conversacionId,
    String? typingUserId,
  ) async {
    try {
      await _chatRepository.setTypingStatus(conversacionId, typingUserId);
    } catch (e) {
      _error = mensajeSeguroDeError(e);
      notifyListeners();
    }
  }
}
