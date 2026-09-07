import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:mockito/mockito.dart';
import 'package:autodoc/features/admin/data/services/admin_auth_service.dart';
import '../../helpers/test_helpers.mocks.dart'
    show MockFirebaseFirestore, MockCollectionReference, MockDocumentReference;

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

    test('ROLE-01: rechaza rol guardado como "administrador" en minuscula — '
        'firestore.rules isAdmin() compara literales EXACTOS '
        "([Administrador, admin, Superusuario]); 'administrador' en minuscula "
        'NO esta en esa lista, asi que aunque el cliente lo dejara pasar aqui '
        'todo intento real de leer/escribir como admin lo rechazaria el '
        'backend. Antes este servicio hacia su propio '
        "`rol.trim().toLowerCase()` y aceptaba 'administrador'/'superusuario' "
        'en minuscula, una divergencia de contrato con las reglas.', () async {
      final auth = MockFirebaseAuth(
        mockUser: MockUser(uid: 'uid-casi-admin', email: 'c@x.com'),
      );
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('usuarios').doc('uid-casi-admin').set({
        'id_usuario': 'uid-casi-admin',
        'correo': 'c@x.com',
        'rol': 'administrador',
      });

      final service = AdminAuthService(auth: auth, firestore: firestore);
      final result = await service.loginAsAdmin('c@x.com', 'password123');

      expect(
        result,
        isNull,
        reason: "'administrador' en minuscula no es un rol canonico",
      );
      expect(auth.currentUser, isNull);
    });

    test(
      'devuelve el UserModel y mantiene la sesion si SI es administrador',
      () async {
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
      },
    );

    test(
      'cierra la sesion cuando la autenticacion tiene exito pero la consulta '
      'a Firestore lanza una excepcion (p. ej. sin conexion o '
      'PERMISSION_DENIED)',
      () async {
        // Firebase Auth SI autentica con exito (credenciales validas).
        final auth = MockFirebaseAuth(
          mockUser: MockUser(uid: 'uid-admin', email: 'a@x.com'),
        );

        // Pero la consulta a Firestore lanza una excepcion generica en vez
        // de devolver un snapshot -- esto exercita el `catch (_)` generico
        // de loginAsAdmin, que NO llamaba a signOut() antes de esta
        // correccion.
        final firestore = MockFirebaseFirestore();
        final collection = MockCollectionReference<Map<String, dynamic>>();
        final docRef = MockDocumentReference<Map<String, dynamic>>();
        when(firestore.collection('usuarios')).thenReturn(collection);
        when(collection.doc('uid-admin')).thenReturn(docRef);
        when(docRef.get()).thenThrow(Exception('network-error'));

        final service = AdminAuthService(auth: auth, firestore: firestore);
        final result = await service.loginAsAdmin('a@x.com', 'password123');

        expect(result, isNull);
        expect(
          auth.currentUser,
          isNull,
          reason:
              'una excepcion tras autenticar con exito no debe dejar '
              'sesion viva',
        );
      },
    );
  });
}
