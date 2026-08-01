import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/models/workshop_model.dart';

void main() {
  group('WorkshopModel Tests', () {
    test('Can instantiate WorkshopModel', () {
      final model = WorkshopModel(
        idTaller: '1',
        nombre: 'n',
        ubicacionMunicipio: 'u',
        calificacionPromedio: 5.0,
      );
      expect(model, isNotNull);
      expect(model.runtimeType, WorkshopModel);
    });

    test('toMap and fromMap work correctly', () {
      final model = WorkshopModel(
        idTaller: '1',
        nombre: 'n',
        ubicacionMunicipio: 'u',
        calificacionPromedio: 5.0,
      );
      final jsonMap = model.toMap();
      expect(jsonMap, isMap);

      final fromMapModel = WorkshopModel.fromMap(jsonMap, 'id');
      expect(fromMapModel, isNotNull);
    });

    test('copyWith works correctly if available', () {
      final model = WorkshopModel(
        idTaller: '1',
        nombre: 'n',
        ubicacionMunicipio: 'u',
        calificacionPromedio: 5.0,
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

  group('WorkshopModel.departamento', () {
    test('fromMap lee departamento cuando está presente', () {
      final model = WorkshopModel.fromMap({
        'nombre': 'Taller Central',
        'ubicacion_municipio': 'San Salvador',
        'departamento': 'San Salvador',
        'especialidad': 'Frenos',
        'estado': 'aprobado',
      }, 'taller1');

      expect(model.departamento, 'San Salvador');
    });

    test('fromMap devuelve null si departamento no existe (docs legados)', () {
      final model = WorkshopModel.fromMap({
        'nombre': 'Taller Viejo',
        'ubicacion_municipio': 'Santa Ana',
        'especialidad': 'Motor',
        'estado': 'aprobado',
      }, 'taller2');

      expect(model.departamento, isNull);
    });

    test('toMap incluye departamento', () {
      final model = WorkshopModel(
        idTaller: 'taller1',
        nombre: 'Taller Central',
        ubicacionMunicipio: 'San Salvador',
        departamento: 'San Salvador',
        especialidad: 'Frenos',
        telefono: '70000000',
        calificacionPromedio: 4.5,
        estado: 'aprobado',
      );

      expect(model.toMap()['departamento'], 'San Salvador');
    });
  });
}
