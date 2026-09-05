import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/features/chat/data/models/conversacion_model.dart';

void main() {
  Map<String, dynamic> baseMap() => {
    'id_propietario': 'p1',
    'id_mecanico': 'm1',
    'nombre_propietario': 'Ana',
    'nombre_mecanico': 'Taller Escobar',
    'ultimo_mensaje': 'Hola',
    'ultimo_mensaje_ts': Timestamp.fromDate(DateTime(2026, 1, 1)),
  };

  test('fromMap lee foto_propietario y foto_mecanico cuando existen', () {
    final map = baseMap()
      ..['foto_propietario'] = 'https://x/p.jpg'
      ..['foto_mecanico'] = 'https://x/m.jpg';

    final conv = ConversacionModel.fromMap(map, 'c1');

    expect(conv.fotoPropietario, 'https://x/p.jpg');
    expect(conv.fotoMecanico, 'https://x/m.jpg');
  });

  test('fromMap devuelve null para las fotos en un documento ya existente '
      'sin esos campos (dato de produccion previo a esta funcionalidad)', () {
    final conv = ConversacionModel.fromMap(baseMap(), 'c1');

    expect(conv.fotoPropietario, isNull);
    expect(conv.fotoMecanico, isNull);
  });

  test('toMap solo escribe las fotos cuando estan presentes', () {
    final sinFotos = ConversacionModel(
      id: 'c1',
      idPropietario: 'p1',
      idMecanico: 'm1',
      nombrePropietario: 'Ana',
      nombreMecanico: 'Taller Escobar',
      ultimoMensaje: 'Hola',
      ultimoMensajeTs: DateTime(2026, 1, 1),
    );
    expect(sinFotos.toMap().containsKey('foto_propietario'), isFalse);
    expect(sinFotos.toMap().containsKey('foto_mecanico'), isFalse);

    final conFotos = ConversacionModel(
      id: 'c1',
      idPropietario: 'p1',
      idMecanico: 'm1',
      nombrePropietario: 'Ana',
      nombreMecanico: 'Taller Escobar',
      ultimoMensaje: 'Hola',
      ultimoMensajeTs: DateTime(2026, 1, 1),
      fotoPropietario: 'https://x/p.jpg',
      fotoMecanico: 'https://x/m.jpg',
    );
    expect(conFotos.toMap()['foto_propietario'], 'https://x/p.jpg');
    expect(conFotos.toMap()['foto_mecanico'], 'https://x/m.jpg');
  });
}
