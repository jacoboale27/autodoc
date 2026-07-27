import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/models/vehicle_model.dart';
import '../../../../core/constants/firestore_collections.dart';

class VehicleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = FirestoreCollections.vehiculos;

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

  Future<void> deleteVehicle(String vehicleId) async {
    try {
      await _firestore.collection(_collection).doc(vehicleId).delete();
    } catch (e) {
      throw 'Error al eliminar vehículo: $e';
    }
  }

  Future<VehicleModel?> getVehicleByPlate(String plate) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('placa', isEqualTo: plate)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return VehicleModel.fromMap(
        snapshot.docs.first.data(),
        snapshot.docs.first.id,
      );
    } catch (e) {
      throw 'Error al buscar vehículo por placa: $e';
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
