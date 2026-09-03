import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/features/chat/data/models/reserva_model.dart';

void main() {
  group('ReservaModel (idProponente y retrocompatibilidad)', () {
    final now = DateTime.now();

    test('fromMap/toMap conservan id_proponente cuando está presente', () {
      final map = {
        'id_conversacion': 'conv-1',
        'id_propietario': 'user-prop',
        'id_mecanico': 'user-mec',
        'id_vehiculo': 'veh-1',
        'id_taller': 'taller-1',
        'id_proponente': 'user-mec',
        'fecha_hora_propuesta': Timestamp.fromDate(now),
        'tipo_servicio': 'Mantenimiento',
        'estado': 'pendiente',
        'fecha_creacion': Timestamp.fromDate(now),
      };

      final model = ReservaModel.fromMap(map, 'res-1');
      expect(model.idProponente, 'user-mec');

      final serialized = model.toMap();
      expect(serialized['id_proponente'], 'user-mec');
    });

    test('fromMap en documento legado sin id_proponente cae en id_propietario', () {
      final mapLegado = {
        'id_conversacion': 'conv-1',
        'id_propietario': 'user-prop-legado',
        'id_mecanico': 'user-mec',
        'id_vehiculo': 'veh-1',
        'id_taller': 'taller-1',
        // 'id_proponente' omitido
        'fecha_hora_propuesta': Timestamp.fromDate(now),
        'tipo_servicio': 'Frenos',
        'estado': 'pendiente',
        'fecha_creacion': Timestamp.fromDate(now),
      };

      final model = ReservaModel.fromMap(mapLegado, 'res-2');
      expect(model.idProponente, 'user-prop-legado');
      expect(model.toMap()['id_proponente'], 'user-prop-legado');
    });

    test('constructor asigna idPropietario a idProponente si se pasa null', () {
      final model = ReservaModel(
        id: 'res-3',
        idConversacion: 'conv-1',
        idPropietario: 'user-prop-default',
        idMecanico: 'user-mec',
        idVehiculo: 'veh-1',
        idTaller: 'taller-1',
        fechaHoraPropuesta: now,
        tipoServicio: 'Cambio de Aceite',
        fechaCreacion: now,
      );

      expect(model.idProponente, 'user-prop-default');
    });
  });
}
