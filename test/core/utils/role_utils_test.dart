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
    test('reconoce las dos formas de una cuenta de taller', () {
      for (final rol in [
        'Mecanico',
        'mecanico',
        'MECANICO',
        'Taller',
        'taller',
      ]) {
        expect(
          appRoleOf(rol),
          AppRole.mechanic,
          reason: '$rol debería ser una cuenta de taller',
        );
      }
    });

    test('tolera acentos', () {
      // 'Mecánico' con tilde es como lo teclea cualquiera y como puede haber
      // quedado en cuentas creadas desde el panel de administración. Antes caía
      // al default y la cuenta se comportaba como propietario.
      expect(appRoleOf('Mecánico'), AppRole.mechanic);
      expect(appRoleOf('mecánico'), AppRole.mechanic);
    });

    test('reconoce las tres formas de una cuenta de administración', () {
      for (final rol in ['admin', 'Administrador', 'Superusuario']) {
        expect(appRoleOf(rol), AppRole.admin, reason: rol);
      }
    });

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
