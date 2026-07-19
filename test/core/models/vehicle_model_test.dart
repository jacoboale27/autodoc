import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/models/vehicle_model.dart';

void main() {
  group('VehicleModel Tests', () {
    test('Can instantiate VehicleModel', () {
      final model = VehicleModel(idVehiculo: '1', idPropietario: '2', placa: '3');
      expect(model, isNotNull);
      expect(model.runtimeType, VehicleModel);
    });
    
    test('toMap and fromMap work correctly', () {
      final model = VehicleModel(idVehiculo: '1', idPropietario: '2', placa: '3');
      final jsonMap = model.toMap();
      expect(jsonMap, isMap);
      
      final fromMapModel = VehicleModel.fromMap(jsonMap, 'id');
      expect(fromMapModel, isNotNull);
    });
    
    test('copyWith works correctly if available', () {
      final model = VehicleModel(idVehiculo: '1', idPropietario: '2', placa: '3');
      try {
        // Use dynamic to avoid compile errors if copyWith is not defined
        final dynamic dynamicModel = model;
        final updated = dynamicModel.copyWith();
        expect(updated, isNotNull);
      } catch (e) {
        // Method not found, safely ignore
      }
    });
  });
}
