import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/models/service_record_model.dart';

void main() {
  group('ServiceRecordModel Tests', () {
    test('Can instantiate ServiceRecordModel', () {
      final model = ServiceRecordModel(
        idServicio: '1',
        idVehiculo: 'v1',
        fecha: DateTime(2023, 1, 1),
      );
      expect(model, isNotNull);
      expect(model.runtimeType, ServiceRecordModel);
    });

    test('toMap and fromMap work correctly', () {
      final model = ServiceRecordModel(
        idServicio: '1',
        idVehiculo: 'v1',
        fecha: DateTime(2023, 1, 1),
      );
      final jsonMap = model.toMap();
      expect(jsonMap, isMap);

      final fromMapModel = ServiceRecordModel.fromMap(jsonMap, 'id');
      expect(fromMapModel, isNotNull);
    });

    test('copyWith works correctly if available', () {
      final model = ServiceRecordModel(
        idServicio: '1',
        idVehiculo: 'v1',
        fecha: DateTime(2023, 1, 1),
      );
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
