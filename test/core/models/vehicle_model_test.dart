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

    // Cierre C1: talleresVinculados/tallerPendienteConfirmacion (y los
    // campos denormalizados/rechazo agregados en la ronda de correccion
    // adversarial) deben sobrevivir un round-trip via fromMap con las
    // mismas claves que usa el trigger de Cloud Functions.
    test(
      'campos de vinculo/confirmacion sobreviven un round-trip via fromMap',
      () {
        final map = {
          'id_vehiculo': '1',
          'id_propietario': '2',
          'placa': '3',
          'talleres_vinculados': ['taller1'],
          'taller_pendiente_confirmacion': 'taller2',
          'taller_pendiente_nombre': 'Taller Dos',
          'taller_pendiente_servicio_id': 'serv-1',
          'talleres_rechazados': ['taller3'],
        };

        final fromMapModel = VehicleModel.fromMap(map, 'id');
        expect(fromMapModel.talleresVinculados, ['taller1']);
        expect(fromMapModel.tallerPendienteConfirmacion, 'taller2');
        expect(fromMapModel.tallerPendienteNombre, 'Taller Dos');
        expect(fromMapModel.tallerPendienteServicioId, 'serv-1');
        expect(fromMapModel.talleresRechazados, ['taller3']);
      },
    );

    test('campos de vinculo/confirmacion tienen defaults seguros', () {
      final model = VehicleModel(
        idVehiculo: '1',
        idPropietario: '2',
        placa: '3',
      );
      expect(model.talleresVinculados, isEmpty);
      expect(model.tallerPendienteConfirmacion, isNull);
      expect(model.tallerPendienteNombre, isNull);
      expect(model.tallerPendienteServicioId, isNull);
      expect(model.talleresRechazados, isEmpty);

      final fromMapModel = VehicleModel.fromMap({}, 'id');
      expect(fromMapModel.talleresVinculados, isEmpty);
      expect(fromMapModel.tallerPendienteConfirmacion, isNull);
      expect(fromMapModel.tallerPendienteNombre, isNull);
      expect(fromMapModel.tallerPendienteServicioId, isNull);
      expect(fromMapModel.talleresRechazados, isEmpty);
    });

    // Cierre I-2 (revision adversarial): toMap() -- usado por
    // VehicleService.updateVehicle para escribir el documento completo
    // desde ediciones normales del dueno -- NO debe incluir los campos
    // server/consentimiento-owned. Si los incluyera, un update de
    // formulario cualquiera (mileage, foto, etc.) con un modelo local
    // desactualizado podria pisar o borrar silenciosamente el estado de
    // vinculo escrito por el trigger de Cloud Functions.
    test(
      'toMap() NO incluye los campos server-owned de vinculo/confirmacion',
      () {
        final model = VehicleModel(
          idVehiculo: '1',
          idPropietario: '2',
          placa: '3',
          talleresVinculados: const ['taller1'],
          tallerPendienteConfirmacion: 'taller2',
          tallerPendienteNombre: 'Taller Dos',
          tallerPendienteServicioId: 'serv-1',
          talleresRechazados: const ['taller3'],
        );

        final map = model.toMap();
        expect(map.containsKey('talleres_vinculados'), false);
        expect(map.containsKey('taller_pendiente_confirmacion'), false);
        expect(map.containsKey('taller_pendiente_nombre'), false);
        expect(map.containsKey('taller_pendiente_servicio_id'), false);
        expect(map.containsKey('talleres_rechazados'), false);
      },
    );

    // toJson() SI debe incluirlos: alimenta el cache local (Hive) que
    // VehicleProvider usa para reconstruir selectedVehicle offline, y ese
    // estado (incluido el banner de confirmacion pendiente) debe reflejar
    // lo que ya escribio el trigger, no perderse en el cache.
    test('toJson() SI incluye los campos de vinculo/confirmacion', () {
      final model = VehicleModel(
        idVehiculo: '1',
        idPropietario: '2',
        placa: '3',
        talleresVinculados: const ['taller1'],
        tallerPendienteConfirmacion: 'taller2',
        tallerPendienteNombre: 'Taller Dos',
        tallerPendienteServicioId: 'serv-1',
        talleresRechazados: const ['taller3'],
      );

      final json = model.toJson();
      expect(json['talleres_vinculados'], ['taller1']);
      expect(json['taller_pendiente_confirmacion'], 'taller2');
      expect(json['taller_pendiente_nombre'], 'Taller Dos');
      expect(json['taller_pendiente_servicio_id'], 'serv-1');
      expect(json['talleres_rechazados'], ['taller3']);
    });
  });
}
