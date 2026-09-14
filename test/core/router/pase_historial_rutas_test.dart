import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/models/user_model.dart';
import 'package:autodoc/core/router/app_router.dart';

/// INNO-01 — quien puede llegar a cada una de las dos rutas del pase.
///
/// **Las dos no se guardan igual, y confundirlas rompe la funcionalidad en una
/// direccion o en la otra:**
///
///   - `/compartir_historial/:vehiculoId` es del propietario. Un taller que
///     llegara ahi veria una pantalla que solo puede terminar en
///     `permission-denied` del servidor.
///   - `/historial_compartido/:token` **no puede estar en ningun conjunto por
///     rol**. El sentido del pase es ensenarselo a alguien que no tiene
///     relacion con el vehiculo: un comprador, que en AutoDoc puede ser
///     propietario de otro coche, un taller, o cualquiera. Meterla en
///     `_ownerRoutes` dejaria al taller que escanea el QR rebotado a su
///     dashboard sin explicacion; meterla en `_mechanicRoutes`, al reves.
///     Lo que acota el riesgo es el token —opaco, caducable, revocable— y no
///     el rol de quien lo canjea.
UserModel _usuario(String rol) => UserModel(
  idUsuario: 'u1',
  correo: 'u1@test.com',
  nombreCompleto: 'Usuario',
  rol: rol,
  fechaRegistro: DateTime(2026, 1, 1),
  estado: 'activo',
);

String? _redirect(String ruta, String rol) => resolveRedirect(
  isLoggedIn: true,
  emailVerified: true,
  userData: _usuario(rol),
  isLoading: false,
  hasAttemptedFetch: true,
  profileError: null,
  currentPath: ruta,
);

void main() {
  group('emitir un pase', () {
    test('el propietario entra', () {
      expect(_redirect('/compartir_historial/v1', 'Propietario'), isNull);
    });

    test('un taller no entra', () {
      expect(
        _redirect('/compartir_historial/v1', 'Taller'),
        '/mechanic_dashboard',
      );
    });

    test('un administrador entra, y la barrera es el servidor', () {
      // Comportamiento heredado del router y deliberado dejarlo como esta: un
      // administrador no esta excluido de NINGUNA ruta de propietario
      // (`resolveRedirect` solo rebota owner->mechanic/admin y
      // mechanic->owner/admin). Cambiarlo aqui seria tocar la guarda de todas
      // las pantallas del propietario por una funcionalidad nueva.
      //
      // No abre un agujero: `crearTokenHistorial` exige
      // `vehiculo.id_propietario == uid` y no mira el rol, asi que el
      // administrador llega a la pantalla y se lleva un `permission-denied`.
      expect(_redirect('/compartir_historial/v1', 'Administrador'), isNull);
    });
  });

  group('canjear un pase', () {
    const ruta = '/historial_compartido/abc123';

    test('el propietario entra', () {
      expect(_redirect(ruta, 'Propietario'), isNull);
    });

    test('un taller entra: es justo a quien se le ensena el QR', () {
      expect(_redirect(ruta, 'Taller'), isNull);
    });

    test('un administrador entra', () {
      expect(_redirect(ruta, 'Administrador'), isNull);
    });

    test('sin sesion no entra', () {
      expect(
        resolveRedirect(
          isLoggedIn: false,
          emailVerified: false,
          userData: null,
          isLoading: false,
          hasAttemptedFetch: true,
          profileError: null,
          currentPath: ruta,
        ),
        '/login',
        reason:
            'el callable exige sesion; llegar a la pantalla sin ella solo '
            'produce un unauthenticated que la persona no puede resolver ahi',
      );
    });

    test('con el correo sin verificar no entra', () {
      expect(
        resolveRedirect(
          isLoggedIn: true,
          emailVerified: false,
          userData: _usuario('Propietario'),
          isLoading: false,
          hasAttemptedFetch: true,
          profileError: null,
          currentPath: ruta,
        ),
        '/verify_email',
        reason: 'SEC-02 va antes que cualquier guarda de rol',
      );
    });
  });
}
