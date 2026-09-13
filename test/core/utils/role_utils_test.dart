import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/utils/role_utils.dart';

/// Regresión de los tres criterios de rol que no coincidían entre sí.
///
/// `_normalizeRole` (router) mapeaba `'taller'` a taller, `isMechanicRole` no,
/// y `MainScaffold` comparaba `rol == 'Mecanico'` exacto. Una cuenta guardada
/// como `'Taller'` era taller para el router (que la mandaba a
/// `/mechanic_dashboard`) y propietario para el shell (que le montaba la
/// navegación de propietario). Ahora los tres delegan aquí.
void main() {
  group('appRoleOf', () {
    test('reconoce las dos formas canonicas de una cuenta de taller', () {
      for (final rol in ['Mecanico', 'Taller']) {
        expect(
          appRoleOf(rol),
          AppRole.mechanic,
          reason: '$rol debería ser una cuenta de taller',
        );
      }
    });

    test(
      'reconoce las tres formas canonicas de una cuenta de administración',
      () {
        for (final rol in ['admin', 'Administrador', 'Superusuario']) {
          expect(appRoleOf(rol), AppRole.admin, reason: rol);
        }
      },
    );

    test(
      'ROLE-01: NO tolera variantes de caja/acento — firestore.rules compara '
      'literales exactos (isAdmin(): [Administrador, admin, Superusuario]; '
      'isMecanico(): rol in [Mecanico, Taller]). Antes appRoleOf normalizaba '
      'a minusculas y sin acentos, así que una cuenta guardada como '
      "'mecanico' o 'Mecánico' se veía como mecánico en la UI mientras "
      'firestore.rules la trataba como sin rol (falla cerrado, pero es una '
      'divergencia de contrato). Ahora cualquier variante no canónica cae a '
      'owner, igual que lo haría el backend.',
      () {
        for (final rol in [
          'mecanico',
          'MECANICO',
          'Mecánico',
          'mecánico',
          'taller',
          'TALLER',
          'administrador',
          'ADMINISTRADOR',
          'superusuario',
          'SUPERUSUARIO',
          'Súperusuario',
          ' Mecanico',
          'Mecanico ',
          'Admin',
          'ADMIN',
        ]) {
          expect(
            appRoleOf(rol),
            AppRole.owner,
            reason:
                '"$rol" no es un literal exacto de firestore.rules: debe '
                'caer a owner (fails closed), no a mechanic/admin',
          );
        }
      },
    );

    test('propietario y cualquier valor desconocido caen en owner', () {
      for (final rol in [
        'Propietario',
        'propietario',
        '',
        '   ',
        'inventado',
      ]) {
        expect(appRoleOf(rol), AppRole.owner, reason: '"$rol"');
      }
      expect(appRoleOf(null), AppRole.owner);
    });
  });

  group('isMechanicRole', () {
    test('acepta Taller, que antes rechazaba', () {
      expect(isMechanicRole('Taller'), isTrue);
      expect(isMechanicRole('Mecanico'), isTrue);
    });

    test('no acepta propietario ni administrador', () {
      expect(isMechanicRole('Propietario'), isFalse);
      expect(isMechanicRole('Administrador'), isFalse);
      expect(isMechanicRole(null), isFalse);
    });
  });

  test('mechanicFirestoreRoles cubre lo mismo que isMechanicRole', () {
    // Si divergen, las consultas `whereIn` dejan fuera en silencio a parte de
    // los talleres. Es el mismo par de valores que acepta isMecanico() en
    // firestore.rules.
    for (final rol in mechanicFirestoreRoles) {
      expect(isMechanicRole(rol), isTrue, reason: rol);
    }
    expect(mechanicFirestoreRoles, containsAll(['Mecanico', 'Taller']));
  });
}
