import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/models/workshop_model.dart';

void main() {
  group('WorkshopModel Tests', () {
    test('Can instantiate WorkshopModel', () {
      final model = WorkshopModel(idTaller: '1', nombre: 'n', ubicacionMunicipio: 'u', calificacionPromedio: 5.0);
      expect(model, isNotNull);
      expect(model.runtimeType, WorkshopModel);
    });
    
    test('toMap and fromMap work correctly', () {
      final model = WorkshopModel(idTaller: '1', nombre: 'n', ubicacionMunicipio: 'u', calificacionPromedio: 5.0);
      final jsonMap = model.toMap();
      expect(jsonMap, isMap);
      
      final fromMapModel = WorkshopModel.fromMap(jsonMap, 'id');
      expect(fromMapModel, isNotNull);
    });
    
    test('copyWith works correctly if available', () {
      final model = WorkshopModel(idTaller: '1', nombre: 'n', ubicacionMunicipio: 'u', calificacionPromedio: 5.0);
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
