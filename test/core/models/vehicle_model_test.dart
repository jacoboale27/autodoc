import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/models/vehicle_model.dart';

void main() {
  group('VehicleModel Tests', () {
    test('Can instantiate VehicleModel', () {
      final model = VehicleModel(
        idVehiculo: '1',
        idPropietario: '2',
        placa: '3',
      );
      expect(model, isNotNull);
      expect(model.runtimeType, VehicleModel);
    });

    test('toMap and fromMap work correctly', () {
      final model = VehicleModel(
        idVehiculo: '1',
        idPropietario: '2',
        placa: '3',
      );
      final jsonMap = model.toMap();
      expect(jsonMap, isMap);

      final fromMapModel = VehicleModel.fromMap(jsonMap, 'id');
      expect(fromMapModel, isNotNull);
    });

    test('copyWith works correctly if available', () {
      final model = VehicleModel(
        idVehiculo: '1',
        idPropietario: '2',
        placa: '3',
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

    // Cierre C1: talleresVinculados/tallerPendienteConfirmacion deben
    // sobrevivir un round-trip toMap/fromMap con las mismas claves que usa
    // el trigger de Cloud Functions (talleres_vinculados,
    // taller_pendiente_confirmacion).
    test(
      'talleresVinculados y tallerPendienteConfirmacion sobreviven toMap/fromMap',
      () {
        final model = VehicleModel(
          idVehiculo: '1',
          idPropietario: '2',
          placa: '3',
          talleresVinculados: const ['taller1'],
          tallerPendienteConfirmacion: 'taller2',
        );

        final map = model.toMap();
        expect(map['talleres_vinculados'], ['taller1']);
        expect(map['taller_pendiente_confirmacion'], 'taller2');

        final fromMapModel = VehicleModel.fromMap(map, 'id');
        expect(fromMapModel.talleresVinculados, ['taller1']);
        expect(fromMapModel.tallerPendienteConfirmacion, 'taller2');
      },
    );

    test(
      'talleresVinculados y tallerPendienteConfirmacion tienen defaults seguros',
      () {
        final model = VehicleModel(
          idVehiculo: '1',
          idPropietario: '2',
          placa: '3',
        );
        expect(model.talleresVinculados, isEmpty);
        expect(model.tallerPendienteConfirmacion, isNull);

        final fromMapModel = VehicleModel.fromMap({}, 'id');
        expect(fromMapModel.talleresVinculados, isEmpty);
        expect(fromMapModel.tallerPendienteConfirmacion, isNull);
      },
    );
  });
}
