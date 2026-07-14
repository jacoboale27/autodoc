import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../data/models/conversacion_model.dart';
import '../../data/models/mensaje_model.dart';
import '../../data/models/cotizacion_model.dart';
import '../../data/repositories/chat_repository.dart';

class ChatProvider extends ChangeNotifier {
  final ChatRepository _chatRepository = ChatRepository();
  
  List<ConversacionModel> _conversaciones = [];
  List<ConversacionModel> get conversaciones => _conversaciones;

  List<MensajeModel> _mensajesActuales = [];
  List<MensajeModel> get mensajesActuales => _mensajesActuales;

  StreamSubscription? _conversacionesSub;
  StreamSubscription? _mensajesSub;
  
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  
  String? _error;
  String? get error => _error;

  int get totalNoLeidosPropietario => _conversaciones.fold(0, (sum, item) => sum + item.noLeidosPropietario);
  int get totalNoLeidosMecanico => _conversaciones.fold(0, (sum, item) => sum + item.noLeidosMecanico);

  @override
  void dispose() {
    _conversacionesSub?.cancel();
    _mensajesSub?.cancel();
    super.dispose();
  }

  void inicializarConversaciones(String userId, bool isMecanico) {
    _conversacionesSub?.cancel();
    _error = null;
    _conversacionesSub = _chatRepository.streamConversaciones(userId, isMecanico).listen(
      (data) {
        _error = null;
        _conversaciones = data;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        notifyListeners();
      },
    );
  }

  void inicializarMensajes(String conversacionId) {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    _mensajesSub?.cancel();
    _mensajesSub = _chatRepository.streamMensajes(conversacionId).listen(
      (data) {
        _error = null;
        _mensajesActuales = data;
        _isLoading = false;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
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
      );

      final id = await _chatRepository.crearConversacion(nuevaConversacion);
      _isLoading = false;
      notifyListeners();
      return id;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return '';
    }
  }

  Future<void> enviarMensaje({
    required String conversacionId,
    required String contenido,
    required String remitenteId,
    required String receptorId,
    required bool isMecanicoRemitente,
    String tipo = 'texto',
    Map<String, dynamic>? metadata,
    String? urlArchivo,
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
      );

      await _chatRepository.enviarMensaje(
        conversacionId: conversacionId,
        mensaje: mensaje,
        receptorId: receptorId,
        isMecanicoRemitente: isMecanicoRemitente,
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> marcarComoLeidos(String conversacionId, bool isMecanico, String currentUserId) async {
    try {
      await _chatRepository.marcarComoLeidos(conversacionId, isMecanico, currentUserId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> actualizarMetadatosMensaje(String conversacionId, String mensajeId, Map<String, dynamic> metadata) async {
    try {
      await _chatRepository.actualizarMetadatosMensaje(conversacionId, mensajeId, metadata);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<String?> crearCotizacion(CotizacionModel cotizacion) async {
    try {
      return await _chatRepository.crearCotizacion(cotizacion);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<void> actualizarEstadoCotizacion(String id, String estado) async {
    try {
      await _chatRepository.actualizarEstadoCotizacion(id, estado);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<String?> subirImagenChat(String conversacionId, File imageFile) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance
          .ref()
          .child('chat_images')
          .child(conversacionId)
          .child(fileName);
      await ref.putFile(imageFile);
      final url = await ref.getDownloadURL();
      
      _isLoading = false;
      notifyListeners();
      return url;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }
  Future<void> deleteMensaje(String conversacionId, String mensajeId) async {
    try {
      await _chatRepository.deleteMensaje(conversacionId, mensajeId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> setTypingStatus(String conversacionId, String? typingUserId) async {
    try {
      await _chatRepository.setTypingStatus(conversacionId, typingUserId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
}
