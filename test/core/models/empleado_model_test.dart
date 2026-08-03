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
      fechaCreacion: DateTime(2026, 7, 31),
    );

    expect(model.activo, isTrue);
    expect(model.toMap()['activo'], isTrue);

    final restored = EmpleadoModel.fromMap(model.toMap(), 'e1');
    expect(restored.nombreCompleto, 'Carlos Pérez');
  });
}
