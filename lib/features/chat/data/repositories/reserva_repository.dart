import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/reserva_model.dart';
import '../../../../core/constants/firestore_collections.dart';

/// Estados en los que una cita sigue viva: el propietario la pidió y nadie la
/// ha rechazado, cancelado ni completado.
const Set<String> estadosReservaVigente = {
  'pendiente',
  'cotizada',
  'confirmada',
};

class ReservaRepository {
  ReservaRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

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

  /// La cita vigente (pendiente, cotizada o confirmada) más reciente entre
  /// este taller y un vehículo, o `null` si no hay ninguna.
  ///
  /// Es lo que desbloquea cotizar desde Buscar Vehículo (observaciones del
  /// 2026-09-18): sin una cita del propietario, el taller solo ve nombre,
  /// placa, kilometraje y fotos del coche. Filtra por `id_mecanico == uid`
  /// porque es la condición con la que `firestore.rules` deja LISTAR citas a
  /// un taller; son dos igualdades, así que no necesita índice compuesto. El
  /// estado se filtra en memoria: un coche acumula pocas citas con un mismo
  /// taller y así no hace falta un `whereIn` (que se ejecuta como N
  /// subconsultas).
  Future<ReservaModel?> reservaVigenteParaVehiculo({
    required String idMecanico,
    required String idVehiculo,
  }) async {
    if (idMecanico.isEmpty || idVehiculo.isEmpty) return null;
    final snap = await _firestore
        .collection(FirestoreCollections.reservas)
        .where('id_mecanico', isEqualTo: idMecanico)
        .where('id_vehiculo', isEqualTo: idVehiculo)
        .limit(20)
        .get();
    final vigentes =
        snap.docs
            .map((d) => ReservaModel.fromMap(d.data(), d.id))
            .where((r) => estadosReservaVigente.contains(r.estado))
            .toList()
          ..sort((a, b) => b.fechaCreacion.compareTo(a.fechaCreacion));
    return vigentes.isEmpty ? null : vigentes.first;
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
