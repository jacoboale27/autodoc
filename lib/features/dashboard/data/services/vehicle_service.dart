import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../../core/models/vehicle_model.dart';
import '../../../../core/constants/firestore_collections.dart';

class VehicleService {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final String _collection = FirestoreCollections.vehiculos;

  VehicleService({FirebaseFirestore? firestore, FirebaseFunctions? functions})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _functions = functions ?? FirebaseFunctions.instance;

  Future<List<VehicleModel>> getVehiclesByOwner(String ownerId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('id_propietario', isEqualTo: ownerId)
          .get();

      return snapshot.docs
          .map((doc) => VehicleModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw 'Error al obtener vehículos: $e';
    }
  }

  Future<void> addVehicle(VehicleModel vehicle) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(vehicle.idVehiculo)
          .set(vehicle.toMap());
    } catch (e) {
      throw 'Error al registrar vehículo: $e';
    }
  }

  Future<void> updateVehicle(VehicleModel vehicle) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(vehicle.idVehiculo)
          .update(vehicle.toMap());
    } catch (e) {
      throw 'Error al actualizar vehículo: $e';
    }
  }

  /// Confirma el vínculo permanente de un taller pendiente de confirmación
  /// (cierre del hallazgo C1: ver comentario en
  /// functions/index.js#requestReviewOnServiceComplete). Usa un update
  /// parcial (no `vehicle.toMap()` completo) para no pisar otros campos
  /// que puedan estar cambiando concurrentemente.
  Future<void> confirmarVinculoTaller(
    String vehiculoId,
    String tallerId,
  ) async {
    try {
      await _firestore.collection(_collection).doc(vehiculoId).update({
        'talleres_vinculados': FieldValue.arrayUnion([tallerId]),
        'taller_pendiente_confirmacion': FieldValue.delete(),
        'taller_pendiente_nombre': FieldValue.delete(),
        'taller_pendiente_servicio_id': FieldValue.delete(),
      });
    } catch (e) {
      throw 'Error al confirmar vínculo con el taller: $e';
    }
  }

  /// Rechaza el vínculo pendiente de un taller: el taller no obtiene acceso
  /// permanente al historial del vehículo. Registra `tallerId` en
  /// `talleres_rechazados` (cierre I-1 de la revisión adversarial de la
  /// tarea C1) para que el trigger de Cloud Functions no vuelva a marcar a
  /// ese mismo taller como pendiente sobre este vehículo — sin esto, un
  /// taller rechazado podía crear otro `servicios` falso inmediatamente y
  /// re-armar el banner de confirmación indefinidamente.
  Future<void> rechazarVinculoTaller(String vehiculoId, String tallerId) async {
    try {
      await _firestore.collection(_collection).doc(vehiculoId).update({
        'taller_pendiente_confirmacion': FieldValue.delete(),
        'taller_pendiente_nombre': FieldValue.delete(),
        'taller_pendiente_servicio_id': FieldValue.delete(),
        'talleres_rechazados': FieldValue.arrayUnion([tallerId]),
      });
    } catch (e) {
      throw 'Error al rechazar el vínculo con el taller: $e';
    }
  }

  Future<void> deleteVehicle(String vehicleId) async {
    try {
      final batch = _firestore.batch();

      final vehicleRef = _firestore.collection(_collection).doc(vehicleId);
      batch.delete(vehicleRef);

      final services = await _firestore
          .collection(FirestoreCollections.servicios)
          .where('id_vehiculo', isEqualTo: vehicleId)
          .get();
      for (var doc in services.docs) {
        batch.delete(doc.reference);
      }

      final alerts = await _firestore
          .collection(FirestoreCollections.alertas)
          .where('id_vehiculo', isEqualTo: vehicleId)
          .get();
      for (var doc in alerts.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      throw 'Error al eliminar vehículo: $e';
    }
  }

  /// Busca un vehículo por placa para que un mecánico inicie el primer
  /// servicio a un cliente nuevo. Pasa por la Cloud Function
  /// `buscarVehiculoPorPlaca` en vez de leer `/vehiculos` directamente:
  /// las reglas de seguridad solo permiten leer el documento completo al
  /// propietario o a un taller ya vinculado, así que esta llamada devuelve
  /// únicamente los campos identificatorios necesarios para la pantalla de
  /// inicio de servicio (sin exponer al propietario ni otros datos).
  Future<VehicleModel?> getVehicleByPlate(String plate) async {
    try {
      final result = await _functions
          .httpsCallable('buscarVehiculoPorPlaca')
          .call({'placa': plate});

      final data = result.data as Map?;
      if (data == null) return null;

      return VehicleModel(
        idVehiculo: data['id_vehiculo'] as String,
        idPropietario: '',
        placa: data['placa'] as String? ?? plate,
        marca: data['marca'] as String?,
        modelo: data['modelo'] as String?,
        anio: (data['anio'] as num?)?.toInt(),
        color: data['color'] as String?,
        kilometrajeActual: (data['kilometraje_actual'] as num?)?.toInt() ?? 0,
      );
    } on FirebaseFunctionsException catch (e) {
      throw 'Error al buscar vehículo por placa: ${e.message ?? e.code}';
    } catch (e) {
      throw 'Error al buscar vehículo por placa: $e';
    }
  }

  /// Lee el vehículo completo por id. A diferencia de [getVehicleByPlate]
  /// (que pasa por la Cloud Function callable porque busca un vehículo
  /// TODAVÍA no vinculado a este taller), este lee `/vehiculos/{id}`
  /// directamente: es el mismo patrón que ya usa
  /// `InitiateServiceScreen._cargarVehiculo` para el caso de F5 sobre
  /// `/initiate_service/:reparacionId` (la ruta ya trae el id del vehículo
  /// resuelto por un ticket propio; `firestore.rules:452` permite la
  /// lectura porque el taller de este mecánico ya está en
  /// `talleres_vinculados` para cualquier vehículo con un ticket).
  /// Devuelve `null` si el documento no existe.
  Future<VehicleModel?> getVehicleById(String vehiculoId) async {
    try {
      final doc = await _firestore
          .collection(_collection)
          .doc(vehiculoId)
          .get();
      if (!doc.exists) return null;
      return VehicleModel.fromMap(doc.data()!, doc.id);
    } catch (e) {
      throw 'Error al obtener vehículo: $e';
    }
  }

  Future<List<VehicleModel>> getSharedVehicles(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('shared_with', arrayContains: userId)
          .get();

      return snapshot.docs
          .map((doc) => VehicleModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw 'Error al obtener vehículos compartidos: $e';
    }
  }

  Future<Map<String, dynamic>> getExpenseSummary(String vehicleId) async {
    try {
      final snapshot = await _firestore
          .collection(FirestoreCollections.servicios)
          .where('id_vehiculo', isEqualTo: vehicleId)
          .get();

      double total = 0;
      double totalMesActual = 0;
      final Map<int, double> porMes = {};

      final now = DateTime.now();

      for (int i = 0; i < 6; i++) {
        final mes = DateTime(now.year, now.month - i, 1);
        porMes[mes.month] = 0;
      }

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final costo = (data['costo'] as num?)?.toDouble() ?? 0.0;
        final fecha = (data['fecha'] as Timestamp?)?.toDate();

        total += costo;

        if (fecha != null) {
          if (fecha.year == now.year && fecha.month == now.month) {
            totalMesActual += costo;
          }
          if (porMes.containsKey(fecha.month)) {
            porMes[fecha.month] = (porMes[fecha.month] ?? 0) + costo;
          }
        }
      }

      return {
        'total': total,
        'mes_actual': totalMesActual,
        'promedio': snapshot.docs.isNotEmpty
            ? total / snapshot.docs.length
            : 0.0,
        'por_mes': porMes,
      };
    } catch (e) {
      throw 'Error al obtener resumen de gastos: $e';
    }
  }

  Future<void> addNote(String vehicleId, String note) async {
    try {
      await _firestore.collection(_collection).doc(vehicleId).update({
        'notas': FieldValue.arrayUnion([note]),
      });
    } catch (e) {
      throw 'Error al agregar nota: $e';
    }
  }

  Future<void> removeNote(String vehicleId, String note) async {
    try {
      await _firestore.collection(_collection).doc(vehicleId).update({
        'notas': FieldValue.arrayRemove([note]),
      });
    } catch (e) {
      throw 'Error al eliminar nota: $e';
    }
  }

  Future<Map<String, dynamic>?> getLastVisitedWorkshop(String vehicleId) async {
    try {
      final snapshot = await _firestore
          .collection(FirestoreCollections.servicios)
          .where('id_vehiculo', isEqualTo: vehicleId)
          .orderBy('fecha', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final data = snapshot.docs.first.data();
      final tallerId = data['id_taller'] as String?;
      if (tallerId == null) return null;

      final tallerDoc = await _firestore
          .collection(FirestoreCollections.talleres)
          .doc(tallerId)
          .get();
      if (!tallerDoc.exists) return null;

      return {
        'id_taller': tallerId,
        'nombre': tallerDoc.data()?['nombre'] ?? 'Taller Desconocido',
        'fecha': (data['fecha'] as Timestamp?)?.toDate(),
      };
    } catch (e) {
      throw 'Error al obtener último taller: $e';
    }
  }
}
