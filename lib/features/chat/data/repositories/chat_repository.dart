import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/conversacion_model.dart';
import '../models/mensaje_model.dart';
import '../models/cotizacion_model.dart';
import '../../../../core/constants/firestore_collections.dart';

class ChatRepository {
  ChatRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  // Obtener stream de conversaciones de un usuario
  Stream<List<ConversacionModel>> streamConversaciones(
    String userId,
    bool isMecanico,
  ) {
    return _firestore
        .collection(FirestoreCollections.conversaciones)
        .where(isMecanico ? 'id_mecanico' : 'id_propietario', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => ConversacionModel.fromMap(doc.data(), doc.id))
              .toList();
          list.sort((a, b) => b.ultimoMensajeTs.compareTo(a.ultimoMensajeTs));
          return list;
        });
  }

  // Obtener stream de mensajes de una conversación
  Stream<List<MensajeModel>> streamMensajes(String conversacionId) {
    return _firestore
        .collection(FirestoreCollections.conversaciones)
        .doc(conversacionId)
        .collection(FirestoreCollections.mensajes)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MensajeModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  // Crear nueva conversación
  Future<String> crearConversacion(ConversacionModel conversacion) async {
    final docRef = _firestore
        .collection(FirestoreCollections.conversaciones)
        .doc();
    final data = conversacion.toMap();
    data['id'] = docRef.id;
    await docRef.set(data);
    return docRef.id;
  }

  // Buscar conversación existente entre dos usuarios (y opcionalmente sobre un vehículo)
  Future<ConversacionModel?> buscarConversacion({
    required String idPropietario,
    required String idMecanico,
    String? idVehiculo,
  }) async {
    Query query = _firestore
        .collection(FirestoreCollections.conversaciones)
        .where('id_propietario', isEqualTo: idPropietario)
        .where('id_mecanico', isEqualTo: idMecanico);

    if (idVehiculo != null) {
      query = query.where('id_vehiculo', isEqualTo: idVehiculo);
    }

    final snapshot = await query.limit(1).get();

    if (snapshot.docs.isNotEmpty) {
      return ConversacionModel.fromMap(
        snapshot.docs.first.data() as Map<String, dynamic>,
        snapshot.docs.first.id,
      );
    }
    return null;
  }

  // Enviar mensaje
  Future<void> enviarMensaje({
    required String conversacionId,
    required MensajeModel mensaje,
    required String receptorId,
    required bool isMecanicoRemitente,
  }) async {
    final batch = _firestore.batch();

    // 1. Agregar mensaje
    final msgRef = _firestore
        .collection(FirestoreCollections.conversaciones)
        .doc(conversacionId)
        .collection(FirestoreCollections.mensajes)
        .doc();
    batch.set(msgRef, mensaje.toMap());

    // 2. Actualizar conversación (último mensaje y contadores)
    final convRef = _firestore
        .collection(FirestoreCollections.conversaciones)
        .doc(conversacionId);

    Map<String, dynamic> updateData = {
      'ultimo_mensaje': mensaje.contenido,
      'ultimo_mensaje_ts': Timestamp.fromDate(mensaje.timestamp),
    };

    if (isMecanicoRemitente) {
      updateData['no_leidos_propietario'] = FieldValue.increment(1);
    } else {
      updateData['no_leidos_mecanico'] = FieldValue.increment(1);
    }

    batch.update(convRef, updateData);

    await batch.commit();
  }

  // Marcar mensajes como leídos
  Future<void> marcarComoLeidos(
    String conversacionId,
    bool isMecanico,
    String currentUserId,
  ) async {
    final convRef = _firestore
        .collection(FirestoreCollections.conversaciones)
        .doc(conversacionId);

    final batch = _firestore.batch();

    // 1. Resetear contador de la conversación
    batch.update(convRef, {
      isMecanico ? 'no_leidos_mecanico' : 'no_leidos_propietario': 0,
    });

    // 2. Actualizar estado de los mensajes no leídos del otro usuario a 'visto'
    final unreadMsgs = await _firestore
        .collection(FirestoreCollections.conversaciones)
        .doc(conversacionId)
        .collection(FirestoreCollections.mensajes)
        .where('id_remitente', isNotEqualTo: currentUserId)
        .get();

    for (var doc in unreadMsgs.docs) {
      final data = doc.data();
      if (data['estado'] != 'visto') {
        batch.update(doc.reference, {'estado': 'visto'});
      }
    }

    await batch.commit();
  }

  // Actualizar metadatos de un mensaje
  Future<void> actualizarMetadatosMensaje(
    String conversacionId,
    String mensajeId,
    Map<String, dynamic> metadata,
  ) async {
    await _firestore
        .collection(FirestoreCollections.conversaciones)
        .doc(conversacionId)
        .collection(FirestoreCollections.mensajes)
        .doc(mensajeId)
        .update({'metadata': metadata});
  }

  // Crear cotización
  Future<String> crearCotizacion(CotizacionModel cotizacion) async {
    final docRef = _firestore.collection('cotizaciones').doc();
    final data = cotizacion.toMap();
    data['id_cotizacion'] = docRef.id; // o id, dependiendo de la convención

    // Dos escrituras secuenciales, no un batch atomico: la regla de
    // cotizaciones/{id}/privado/{docId} usa get() sobre el documento padre
    // para verificar id_mecanico, y get() dentro de un batch/transaccion NO
    // ve otras escrituras del mismo batch — el padre debe existir ANTES de
    // que la regla del hijo pueda leerlo. Riesgo residual aceptado: si la
    // segunda escritura falla, queda una cotizacion publica sin su margen
    // privado; obtenerBeneficiosCotizacion ya devuelve [] con seguridad en
    // ese caso (sin excepcion, sin fuga de datos).
    await docRef.set(data);
    // Beneficio por renglon: subcoleccion privada, ver firestore.rules
    // cotizaciones/{id}/privado/{docId} (hallazgo H2).
    await docRef
        .collection('privado')
        .doc('margen')
        .set(cotizacion.toPrivateMap());

    return docRef.id;
  }

  // Beneficio por renglon de una cotizacion (solo el mecanico dueño puede
  // leerlo, ver firestore.rules).
  Future<List<double>> obtenerBeneficiosCotizacion(String cotizacionId) async {
    final doc = await _firestore
        .collection('cotizaciones')
        .doc(cotizacionId)
        .collection('privado')
        .doc('margen')
        .get();
    if (!doc.exists) return const [];
    final raw = doc.data()?['beneficios'] as List?;
    if (raw == null) return const [];
    return raw.map((e) => (e as num).toDouble()).toList();
  }

  // Actualizar estado de la cotización
  Future<void> actualizarEstadoCotizacion(String id, String estado) async {
    await _firestore.collection('cotizaciones').doc(id).update({
      'estado': estado,
    });
  }

  // Editar el texto de un mensaje propio (Tarea 11b, C4). Las reglas
  // (`firestore.rules`, subcolección `mensajes`) acotan esta escritura al
  // autor y solo a `contenido`/`editado` — ver informe de Tarea 11.
  Future<void> editarMensaje(
    String conversacionId,
    String mensajeId,
    String nuevoContenido,
  ) async {
    await _firestore
        .collection(FirestoreCollections.conversaciones)
        .doc(conversacionId)
        .collection(FirestoreCollections.mensajes)
        .doc(mensajeId)
        .update({'contenido': nuevoContenido, 'editado': true});
  }

  // Delete message
  Future<void> deleteMensaje(String conversacionId, String mensajeId) async {
    await _firestore
        .collection(FirestoreCollections.conversaciones)
        .doc(conversacionId)
        .collection(FirestoreCollections.mensajes)
        .doc(mensajeId)
        .update({
          'is_deleted': true,
          'contenido': 'Este mensaje ha sido eliminado',
        });
  }

  // Set typing status
  Future<void> setTypingStatus(
    String conversacionId,
    String? typingUserId,
  ) async {
    await _firestore
        .collection(FirestoreCollections.conversaciones)
        .doc(conversacionId)
        .update({'typing_id': typingUserId});
  }
}
