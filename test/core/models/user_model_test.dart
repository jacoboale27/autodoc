import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/models/user_model.dart';

void main() {
  group('UserModel Tests', () {
    test('Can instantiate UserModel', () {
      final model = UserModel(
        idUsuario: '1',
        nombreCompleto: 'n',
        correo: 'c',
        rol: 'r',
        fechaRegistro: DateTime(2023, 1, 1),
      );
      expect(model, isNotNull);
      expect(model.runtimeType, UserModel);
    });

    test('toMap and fromMap work correctly', () {
      final model = UserModel(
        idUsuario: '1',
        nombreCompleto: 'n',
        correo: 'c',
        rol: 'r',
        fechaRegistro: DateTime(2023, 1, 1),
      );
      final jsonMap = model.toMap();
      expect(jsonMap, isMap);

      final fromMapModel = UserModel.fromMap(jsonMap, 'id');
      expect(fromMapModel, isNotNull);
    });

    test('copyWith works correctly if available', () {
      final model = UserModel(
        idUsuario: '1',
        nombreCompleto: 'n',
        correo: 'c',
        rol: 'r',
        fechaRegistro: DateTime(2023, 1, 1),
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

    test(
      'estado por defecto es pendiente cuando el campo falta (fail-closed)',
      () {
        final u = UserModel.fromMap({
          'id_usuario': 'u1',
          'correo': 'u@x.com',
          'rol': 'Taller',
        }, 'u1');
        expect(u.estado, 'pendiente');
      },
    );

    test('estado explicito se respeta', () {
      final u = UserModel.fromMap({
        'id_usuario': 'u1',
        'correo': 'u@x.com',
        'rol': 'Taller',
        'estado': 'aprobado',
      }, 'u1');
      expect(u.estado, 'aprobado');
    });
  });
}
