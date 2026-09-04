// test/core/models/reparacion_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/models/reparacion_model.dart';

void main() {
  test('fromMap/toMap conservan estado e historial', () {
    final ahora = DateTime(2026, 7, 31, 9, 0);
    final model = ReparacionModel(
      idReparacion: 'r1',
      idVehiculo: 'v1',
      idTaller: 't1',
      idPropietario: 'p1',
      placa: 'P123-456',
      estado: 'en_revision',
      historialEstados: [
        {'estado': 'recibido', 'timestamp': ahora},
      ],
      fechaCreacion: ahora,
      fechaActualizacion: ahora,
    );

    final map = model.toMap();
    expect(map['estado'], 'en_revision');
    expect(map['id_vehiculo'], 'v1');

    final restored = ReparacionModel.fromMap(map, 'r1');
    expect(restored.estado, 'en_revision');
    expect(restored.historialEstados.length, 1);
  });

  test('estadosReparacion define el orden fijo del Kanban', () {
    // 'pendiente_recepcion' abre la lista desde A4b: el ticket nace ahí
    // cuando el cliente acepta la cotización, con el vehículo todavía fuera
    // del taller, y "Recibir vehículo" es la transición a 'recibido'.
    expect(estadosReparacion, [
      'pendiente_recepcion',
      'recibido',
      'en_revision',
      'esperando_repuestos',
      'listo_para_entrega',
    ]);
  });
}
