import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/models/vehicle_model.dart';

class VehicleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'Vehiculos';

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
      await _firestore.collection(_collection).doc(vehicle.idVehiculo).set(vehicle.toMap());
    } catch (e) {
      throw 'Error al registrar vehículo: $e';
    }
  }

  Future<void> updateVehicle(VehicleModel vehicle) async {
    try {
      await _firestore.collection(_collection).doc(vehicle.idVehiculo).update(vehicle.toMap());
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
      return VehicleModel.fromMap(snapshot.docs.first.data(), snapshot.docs.first.id);
    } catch (e) {
      throw 'Error al buscar vehículo por placa: $e';
    }
  }
}
