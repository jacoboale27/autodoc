import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:autodoc/features/admin/data/services/admin_auth_service.dart';

void main() {
  group('AdminAuthService.loginAsAdmin', () {
    test(
      'cierra la sesion cuando el usuario autentica pero NO es administrador',
      () async {
        final auth = MockFirebaseAuth(
          mockUser: MockUser(uid: 'uid-propietario', email: 'p@x.com'),
        );
        final firestore = FakeFirebaseFirestore();
        await firestore.collection('usuarios').doc('uid-propietario').set({
          'id_usuario': 'uid-propietario',
          'correo': 'p@x.com',
          'rol': 'Propietario',
        });

        final service = AdminAuthService(auth: auth, firestore: firestore);
        final result = await service.loginAsAdmin('p@x.com', 'password123');

        expect(result, isNull, reason: 'no es administrador');
        expect(
          auth.currentUser,
          isNull,
          reason: 'un login administrativo fallido no debe dejar sesion viva',
        );
      },
    );

    test('devuelve el UserModel y mantiene la sesion si SI es administrador', () async {
      final auth = MockFirebaseAuth(
        mockUser: MockUser(uid: 'uid-admin', email: 'a@x.com'),
      );
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('usuarios').doc('uid-admin').set({
        'id_usuario': 'uid-admin',
        'correo': 'a@x.com',
        'rol': 'Administrador',
        'nombre_completo': 'Admin',
      });

      final service = AdminAuthService(auth: auth, firestore: firestore);
      final result = await service.loginAsAdmin('a@x.com', 'password123');

      expect(result, isNotNull);
      expect(auth.currentUser, isNotNull);
    });
  });
}
