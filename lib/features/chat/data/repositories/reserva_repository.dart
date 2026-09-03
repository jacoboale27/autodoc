import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/reserva_model.dart';
import '../../../../core/constants/firestore_collections.dart';

class ReservaRepository {
  ReservaRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  // Obtener reservas de un usuario
  Stream<List<ReservaModel>> streamReservasUsuario(
    String userId, {
    bool isMecanico = false,
  }) {
    return _firestore
        .collection(FirestoreCollections.reservas)
        .where(isMecanico ? 'id_mecanico' : 'id_propietario', isEqualTo: userId)
        .orderBy('fecha_hora_propuesta', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ReservaModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  // Obtener reserva por ID
  Future<ReservaModel?> getReserva(String reservaId) async {
    final doc = await _firestore
        .collection(FirestoreCollections.reservas)
        .doc(reservaId)
        .get();
    if (doc.exists) {
      return ReservaModel.fromMap(doc.data()!, doc.id);
    }
    return null;
  }

  // Crear nueva reserva
  Future<String> crearReserva(ReservaModel reserva) async {
    final docRef = _firestore.collection(FirestoreCollections.reservas).doc();
    await docRef.set(reserva.toMap());
    return docRef.id;
  }

  // Reprogramar: propone una nueva fecha/hora y vuelve a dejarla pendiente
  Future<void> reprogramarReserva(
    String reservaId,
    DateTime nuevaFecha, {
    required String idProponente,
  }) async {
    await _firestore
        .collection(FirestoreCollections.reservas)
        .doc(reservaId)
        .update({
          'fecha_hora_propuesta': Timestamp.fromDate(nuevaFecha),
          'id_proponente': idProponente,
          'estado': 'pendiente',
        });
  }

  // Actualizar estado de reserva
  Future<void> actualizarEstadoReserva(
    String reservaId,
    String estado, {
    DateTime? fechaConfirmada,
  }) async {
    Map<String, dynamic> data = {'estado': estado};
    if (fechaConfirmada != null) {
      data['fecha_hora_confirmada'] = Timestamp.fromDate(fechaConfirmada);
    }
    await _firestore
        .collection(FirestoreCollections.reservas)
        .doc(reservaId)
        .update(data);
  }
}
