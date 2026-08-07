import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/models/empleado_model.dart';

void main() {
  test('fromMap/toMap conservan activo por defecto en true', () {
    final model = EmpleadoModel(
      idEmpleado: 'e1',
      idTallerPropietario: 't1',
      nombreCompleto: 'Carlos Pérez',
      correo: 'carlos@example.com',
      telefono: '70000000',
      rol: 'Mecanico',
      fechaCreacion: DateTime(2026, 7, 31),
    );

    expect(model.activo, isTrue);
    expect(model.toMap()['activo'], isTrue);

    final restored = EmpleadoModel.fromMap(model.toMap(), 'e1');
    expect(restored.nombreCompleto, 'Carlos Pérez');
  });

  test('toMap/fromMap preservan el campo rol', () {
    final model = EmpleadoModel(
      idEmpleado: 'e1',
      idTallerPropietario: 't1',
      nombreCompleto: 'Juan Pérez',
      correo: 'juan@taller.com',
      rol: 'Mecanico',
      fechaCreacion: DateTime(2026, 1, 1),
    );

    final map = model.toMap();
    expect(map['rol'], 'Mecanico');

    final roundTripped = EmpleadoModel.fromMap(map, 'e1');
    expect(roundTripped.rol, 'Mecanico');
  });

  test(
    'fromMap usa un rol por defecto si el documento no lo trae (datos legacy)',
    () {
      final legacyMap = {
        'id_taller_propietario': 't1',
        'nombre_completo': 'Legacy Empleado',
        'correo': 'legacy@taller.com',
        'activo': true,
        'fecha_creacion': Timestamp.fromDate(DateTime(2025, 1, 1)),
      };

      final model = EmpleadoModel.fromMap(legacyMap, 'e-legacy');
      expect(model.rol, 'Mecanico');
    },
  );
}
