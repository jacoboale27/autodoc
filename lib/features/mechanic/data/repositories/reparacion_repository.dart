import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:autodoc/core/constants/firestore_collections.dart';
import 'package:autodoc/core/models/reparacion_model.dart';

class ReparacionRepository {
  final FirebaseFirestore _firestore;

  ReparacionRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<String> iniciarReparacion({
    required String idVehiculo,
    required String idTaller,
    required String idPropietario,
    required String placa,
  }) async {
    final ahora = DateTime.now();
    final docRef = _firestore
        .collection(FirestoreCollections.reparaciones)
        .doc();
    final model = ReparacionModel(
      idReparacion: docRef.id,
      idVehiculo: idVehiculo,
      idTaller: idTaller,
      idPropietario: idPropietario,
      placa: placa,
      estado: 'recibido',
      historialEstados: [
        {'estado': 'recibido', 'timestamp': ahora},
      ],
      fechaCreacion: ahora,
      fechaActualizacion: ahora,
    );
    await docRef.set(model.toMap());
    return docRef.id;
  }

  Future<void> cambiarEstado({
    required String idReparacion,
    required String nuevoEstado,
  }) async {
    if (!estadosReparacion.contains(nuevoEstado)) {
      throw ArgumentError('Estado inválido: $nuevoEstado');
    }
    final docRef = _firestore
        .collection(FirestoreCollections.reparaciones)
        .doc(idReparacion);
    final ahora = DateTime.now();

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      final data = snap.data() as Map<String, dynamic>;

      final estadoActual = (data['estado'] ?? 'recibido').toString();
      final indiceActual = estadosReparacion.indexOf(estadoActual);
      final indiceNuevo = estadosReparacion.indexOf(nuevoEstado);
      if (indiceActual != -1 && indiceNuevo < indiceActual) {
        throw ArgumentError(
          'No se puede retroceder de "$estadoActual" a "$nuevoEstado"',
        );
      }

      final historial = List<Map<String, dynamic>>.from(
        (data['historial_estados'] as List).map(
          (h) => Map<String, dynamic>.from(h as Map),
        ),
      )..add({'estado': nuevoEstado, 'timestamp': Timestamp.fromDate(ahora)});

      tx.update(docRef, {
        'estado': nuevoEstado,
        'historial_estados': historial,
        'fecha_actualizacion': Timestamp.fromDate(ahora),
      });
    });
  }

  Stream<List<ReparacionModel>> watchReparacionesActivas(String idTaller) {
    return _firestore
        .collection(FirestoreCollections.reparaciones)
        .where('id_taller', isEqualTo: idTaller)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => ReparacionModel.fromMap(d.data(), d.id))
              .toList(),
        );
  }
}
