import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/conversacion_model.dart';
import '../models/mensaje_model.dart';
import '../models/cotizacion_model.dart';
import '../../../../core/constants/firestore_collections.dart';

/// Contenido con el que [ChatRepository.deleteMensaje] tumba (borrado
/// lógico) un mensaje de texto.
///
/// Revisión de rama completa (Blocker 6/hallazgo R22): `firestore.rules`
/// (match /mensajes, rama de borrado lógico) compara el `contenido` escrito
/// contra este mismo literal CARÁCTER A CARÁCTER
/// (`request.resource.data.contenido == 'Este mensaje ha sido eliminado'`) —
/// es la única forma en que la regla puede verificar que el borrado lógico
/// no se use como tapadera para reescribir el texto a otra cosa (ver el
/// comentario de esa rama de la regla). Antes de esta constante, el literal
/// vivía repetido y sin vínculo alguno en `chat_repository.dart`,
/// `firestore.rules` y dos archivos de test: una futura pasada de
/// localización que tocara "todo string visible del chat" (Tareas 11/12 ya
/// localizaron cada string vecino) habría cambiado este SIN romper ningún
/// test — `FakeFirebaseFirestore` no evalúa reglas — y el borrado lógico
/// habría empezado a fallar en producción para todos los usuarios.
///
/// NO LOCALIZAR. Si el copy debe cambiar, cambia este valor Y el literal de
/// `firestore.rules` (match /mensajes) EN EL MISMO commit; el test de guardia
/// `test/features/chat/tombstone_literal_test.dart` falla si alguno de los
/// dos se toca sin el otro.
const String kTombstoneMensajeEliminado = 'Este mensaje ha sido eliminado';

class ChatRepository {
  ChatRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Bandeja de conversaciones del usuario, **acotada** (gap 9.2).
  ///
  /// Antes era `where(...)` a secas más un `list.sort(...)` en memoria: traía
  /// la colección entera del usuario en cada `attach` del listener y ordenaba
  /// después. Ordenar en cliente no acota nada — el coste ya se pagó.
  ///
  /// El `orderBy` es parte del tope, no un adorno: recortar sin ordenar deja
  /// fuera conversaciones **arbitrarias**, porque sin él Firestore ordena por
  /// `__name__`, o sea por un id aleatorio.
  ///
  /// **Ese `orderBy` excluye los documentos sin `ultimo_mensaje_ts`**, que es
  /// la trampa que el tablero y el `whereIn` de la ronda 6 ya pagaron con una
  /// pasada de backfill. Aquí NO hace falta, y se comprobó antes de tocar la
  /// consulta: el campo es obligatorio en `ConversacionModel` (no es
  /// nulable, y `toMap` siempre lo escribe), `ChatProvider.crearConversacion`
  /// es el único creador de `lib/`, no hay ningún creador server-side (las
  /// Functions solo leen esta colección) y el modelo nació con el campo en su
  /// primer commit. No existe ni ha existido una conversación sin él.
  Stream<List<ConversacionModel>> streamConversaciones(
    String userId,
    bool isMecanico,
  ) {
    return _firestore
        .collection(FirestoreCollections.conversaciones)
        .where(isMecanico ? 'id_mecanico' : 'id_propietario', isEqualTo: userId)
        .orderBy('ultimo_mensaje_ts', descending: true)
        .limit(maxConversacionesBandeja)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ConversacionModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  /// Mensajes de una conversación, **acotados a los [maxMensajesHilo] más
  /// recientes** (gap 9.3).
  ///
  /// El `limit` cae sobre una consulta ya descendente, así que recorta por el
  /// principio del hilo (lo viejo) y nunca por el final (lo último dicho).
  /// Que se haya llegado al tope se anuncia: ver `ChatProvider.hiloTruncado`.
  Stream<List<MensajeModel>> streamMensajes(String conversacionId) {
    return _firestore
        .collection(FirestoreCollections.conversaciones)
        .doc(conversacionId)
        .collection(FirestoreCollections.mensajes)
        .orderBy('timestamp', descending: true)
        .limit(maxMensajesHilo)
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

  /// Resetea el contador de no leídos y marca como vistos los mensajes del
  /// otro participante, **por lotes acotados** (gap 7.1).
  ///
  /// Antes traía el hilo ENTERO (`.get()` sin `limit`, en cada apertura de la
  /// conversación) y metía todas las escrituras en un solo `WriteBatch`. Un
  /// batch admite **500 operaciones**: con más de 499 mensajes del otro, el
  /// `commit()` fallaba entero y se llevaba por delante el reseteo del
  /// contador, así que la conversación arrastraba su globo rojo para siempre y
  /// cada apertura reintentaba el mismo batch imposible.
  ///
  /// El filtro pasa al SERVIDOR —`id_remitente == el otro` y
  /// `estado != 'visto'`— en vez de traerlo todo y descartar en memoria, así
  /// que se leen solo los mensajes que se van a escribir. Necesita el índice
  /// compuesto `mensajes (id_remitente, estado)`.
  ///
  /// Es una desigualdad y no un `whereIn ['enviado','entregado']` a propósito:
  /// un `in` se ejecuta como N subconsultas con el `limit` aplicado a cada
  /// una, que es exactamente lo que el gap 9.1 acaba de quitar del tablero.
  ///
  /// **Una desigualdad excluye los documentos que no tienen el campo**, la
  /// trampa de siempre. Aquí se comprobó antes de usarla: `estado` está en
  /// `MensajeModel.toMap` desde el primer commit del modelo (`50b8c87`), el
  /// único escritor de la subcolección es `enviarMensaje` —ningún trigger
  /// escribe mensajes, solo los lee— y por tanto no existe ni ha existido un
  /// mensaje sin `estado`. Y el bucle converge aunque lo hubiera: un documento
  /// invisible al filtro nunca es devuelto, así que no puede repetirse.
  ///
  /// El otro participante se resuelve **leyendo la conversación**, no se
  /// recibe como parámetro: en una conversación solo hay dos partes, así que
  /// «los que no son míos» y «los suyos» son el mismo conjunto, pero la
  /// igualdad sí se puede combinar con el filtro de estado. Esa lectura de un
  /// documento sustituye a las N que costaba traerse el hilo entero, y evita
  /// que un llamador pueda equivocarse de uid — si se pasara el propio, se
  /// marcarían como vistos los mensajes de uno mismo.
  ///
  /// Si el uid no es ninguno de los dos participantes no se escribe nada: no
  /// hay contador que resetear ni acuses que dar.
  ///
  /// El bucle es convergente sin cursor: cada vuelta marca como vistos los que
  /// devuelve, y esos dejan de cumplir el filtro. No hace falta paginar con
  /// `startAfter` — que además sería frágil, porque el campo que ordena es el
  /// mismo que se está reescribiendo.
  ///
  /// El reseteo del contador viaja en el PRIMER lote, no suelto: así la
  /// escritura que el usuario nota —el globo que desaparece— sigue siendo
  /// atómica con el primer tramo de acuses, como lo era antes.
  Future<void> marcarComoLeidos(
    String conversacionId,
    bool isMecanico,
    String currentUserId,
  ) async {
    final convRef = _firestore
        .collection(FirestoreCollections.conversaciones)
        .doc(conversacionId);

    final conv = await convRef.get();
    final datos = conv.data();
    if (datos == null) return;
    final idPropietario = (datos['id_propietario'] ?? '').toString();
    final idMecanico = (datos['id_mecanico'] ?? '').toString();
    final String idOtroParticipante;
    if (currentUserId.isNotEmpty && currentUserId == idPropietario) {
      idOtroParticipante = idMecanico;
    } else if (currentUserId.isNotEmpty && currentUserId == idMecanico) {
      idOtroParticipante = idPropietario;
    } else {
      return;
    }
    if (idOtroParticipante.isEmpty) return;

    final mensajes = convRef.collection(FirestoreCollections.mensajes);

    var primerLote = true;
    while (true) {
      final pendientes = await mensajes
          .where('id_remitente', isEqualTo: idOtroParticipante)
          .where('estado', isNotEqualTo: kEstadoMensajeVisto)
          .limit(maxMensajesPorLoteDeLectura)
          .get();

      if (pendientes.docs.isEmpty && !primerLote) return;

      final batch = _firestore.batch();
      if (primerLote) {
        batch.update(convRef, {
          isMecanico ? 'no_leidos_mecanico' : 'no_leidos_propietario': 0,
        });
        primerLote = false;
      }
      for (final doc in pendientes.docs) {
        batch.update(doc.reference, {'estado': kEstadoMensajeVisto});
      }
      await batch.commit();

      // El lote que no se llena es el último: los que acabamos de marcar ya no
      // cumplen el filtro, así que la siguiente vuelta traería lo que quede.
      if (pendientes.docs.length < maxMensajesPorLoteDeLectura) return;
    }
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
    data['estado'] = 'draft';

    // Escrituras secuenciales, no un batch atomico: la regla de
    // cotizaciones/{id}/privado/{docId} usa get() sobre el documento padre
    // para verificar id_mecanico, y get() dentro de un batch/transaccion NO
    // ve otras escrituras del mismo batch — el padre debe existir ANTES de
    // que la regla del hijo pueda leerlo. El padre nace como draft: ni la
    // UI ni las reglas permiten consumirlo antes de confirmar el privado.
    await docRef.set(data);
    // Beneficio por renglon: subcoleccion privada, ver firestore.rules
    // cotizaciones/{id}/privado/{docId} (hallazgo H2).
    try {
      await docRef
          .collection('privado')
          .doc('margen')
          .set(cotizacion.toPrivateMap());
    } catch (_) {
      try {
        await docRef.delete();
      } catch (_) {
        // Si la limpieza falla, el draft sigue oculto y no se puede aceptar.
        // Conservamos el error original de la escritura privada.
      }
      rethrow;
    }
    // La publicacion tambien exige el contrato privado en firestore.rules.
    // Si falla, permanece un draft no consumible con su margen intacto.
    await docRef.update({'estado': 'pendiente'});

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
        .update({'is_deleted': true, 'contenido': kTombstoneMensajeEliminado});
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
