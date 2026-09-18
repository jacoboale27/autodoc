// Observaciones del 2026-09-18 (capturas 4 y 5): la cotización del chat
// tomaba el coche solo de la conversación y nacía sin `id_vehiculo` cuando el
// chat se había abierto desde el directorio de talleres, aunque el cliente ya
// hubiera elegido su coche al agendar la cita.
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/features/chat/data/models/mensaje_model.dart';
import 'package:autodoc/features/chat/data/models/vehiculo_cotizado.dart';

MensajeModel _mensaje(
  String id,
  String tipo,
  Map<String, dynamic>? metadata, {
  bool borrado = false,
}) => MensajeModel(
  id: id,
  idRemitente: 'cli1',
  contenido: '',
  tipo: tipo,
  metadata: metadata,
  timestamp: DateTime(2026, 9, 18),
  isDeleted: borrado,
);

void main() {
  test('sin coche en la conversación, usa el de la cita más reciente', () {
    final v = vehiculoParaCotizarEnChat(
      idVehiculoConversacion: null,
      mensajesRecientesPrimero: [
        _mensaje('m3', 'texto', null),
        _mensaje('m2', 'reserva_card', {
          'id_vehiculo': 'v2',
          'vehiculo': {'marca': 'NISSAN', 'modelo': 'Rogue', 'placa': 'P1'},
        }),
        _mensaje('m1', 'reserva_card', {'id_vehiculo': 'v1'}),
      ],
    );
    expect(v, isNotNull);
    expect(v!.idVehiculo, 'v2');
    expect(v.nombre, 'NISSAN Rogue');
    expect(v.placa, 'P1');
  });

  test('el coche de la conversación manda sobre el de las citas', () {
    final v = vehiculoParaCotizarEnChat(
      idVehiculoConversacion: 'v1',
      mensajesRecientesPrimero: [
        _mensaje('m2', 'reserva_card', {'id_vehiculo': 'v2'}),
        _mensaje('m1', 'reserva_card', {
          'id_vehiculo': 'v1',
          'vehiculo': {'placa': 'P-UNO'},
        }),
      ],
    );
    expect(v!.idVehiculo, 'v1');
    expect(
      v.placa,
      'P-UNO',
      reason: 'el resumen sale de la cita del mismo coche',
    );
  });

  test('una cita antigua sin resumen sigue dando el coche', () {
    final v = vehiculoParaCotizarEnChat(
      idVehiculoConversacion: '',
      mensajesRecientesPrimero: [
        _mensaje('m1', 'reserva_card', {'id_vehiculo': 'v1'}),
      ],
    );
    expect(v!.idVehiculo, 'v1');
    expect(v.nombre, 'Vehículo del cliente');
  });

  test('ignora citas borradas o sin coche', () {
    final v = vehiculoParaCotizarEnChat(
      idVehiculoConversacion: null,
      mensajesRecientesPrimero: [
        _mensaje('m2', 'reserva_card', {'id_vehiculo': 'v9'}, borrado: true),
        _mensaje('m1', 'reserva_card', {'id_vehiculo': ''}),
      ],
    );
    expect(v, isNull);
  });

  test('sin ninguna cita ni coche no hay a qué cotizar', () {
    expect(
      vehiculoParaCotizarEnChat(
        idVehiculoConversacion: null,
        mensajesRecientesPrimero: [_mensaje('m1', 'texto', null)],
      ),
      isNull,
    );
  });

  test('el resumen se lee tolerante y no expone nada del propietario', () {
    final v = VehiculoCotizado.desdeResumen('v1', {
      'marca': 'Toyota',
      'anio': '2020',
      'kilometraje': 1500.0,
      'id_propietario': 'cli1',
    });
    expect(v.anio, 2020);
    expect(v.kilometraje, 1500);
    expect(v.toResumen().containsKey('id_propietario'), isFalse);
  });
}
