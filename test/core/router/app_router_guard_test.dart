import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/models/user_model.dart';
import 'package:autodoc/core/router/app_router.dart';

// `fechaRegistro` es obligatorio en el constructor de UserModel
// (lib/core/models/user_model.dart:25).
UserModel _user(String uid, String rol, {String estado = 'activo'}) =>
    UserModel(
      idUsuario: uid,
      correo: '$uid@test.com',
      nombreCompleto: 'Usuario $uid',
      rol: rol,
      fechaRegistro: DateTime(2026, 1, 1),
      estado: estado,
    );

String? _redirect({
  required String currentPath,
  UserModel? userData,
  bool isLoggedIn = true,
  bool hasAttemptedFetch = true,
  bool isLoading = false,
}) => resolveRedirect(
  isLoggedIn: isLoggedIn,
  userData: userData,
  isLoading: isLoading,
  hasAttemptedFetch: hasAttemptedFetch,
  profileError: null,
  currentPath: currentPath,
);

void main() {
  group('guarda del router durante la carga de perfil', () {
    test(
      'no permite una ruta protegida mientras el perfil aun no se ha leido',
      () {
        expect(
          _redirect(currentPath: '/dashboard', hasAttemptedFetch: false),
          '/?redirect=%2Fdashboard',
          reason:
              'debe retener en el splash preservando el destino, no descartarlo ni '
              'renderizar la pantalla del rol equivocado',
        );
      },
    );

    test('no permite una ruta de mecanico mientras el perfil carga', () {
      expect(
        _redirect(currentPath: '/mechanic_dashboard', hasAttemptedFetch: false),
        '/?redirect=%2Fmechanic_dashboard',
      );
    });

    test('permite quedarse en el splash mientras carga', () {
      expect(_redirect(currentPath: '/', hasAttemptedFetch: false), isNull);
    });

    test(
      'preserva una ruta con id (deep link) como redirect en vez de descartarla',
      () {
        expect(
          _redirect(
            currentPath: '/vehicle_profile/abc',
            hasAttemptedFetch: false,
          ),
          '/?redirect=%2Fvehicle_profile%2Fabc',
          reason:
              'la Tarea 12 habilito estas rutas por id; retenerlas en un "/" '
              'fijo rompe F5 y los deep links de notificaciones push en frio',
        );
      },
    );
  });

  group('guarda de rutas admin', () {
    test('un taller NO puede acceder a /admin/seed', () {
      expect(
        _redirect(
          currentPath: '/admin/seed',
          userData: _user('uid-t', 'Taller'),
        ),
        '/mechanic_dashboard',
      );
    });

    test('un propietario NO puede acceder a /admin/seed', () {
      expect(
        _redirect(
          currentPath: '/admin/seed',
          userData: _user('uid-o', 'Propietario'),
        ),
        '/dashboard',
      );
    });

    test('un admin SI puede acceder a /admin/seed', () {
      expect(
        _redirect(
          currentPath: '/admin/seed',
          userData: _user('uid-a', 'Administrador'),
        ),
        isNull,
      );
    });
  });

  group('separacion de roles', () {
    test('un taller NO puede acceder al dashboard de propietario', () {
      expect(
        _redirect(
          currentPath: '/dashboard',
          userData: _user('uid-t', 'Taller'),
        ),
        '/mechanic_dashboard',
      );
    });

    test('un propietario NO puede acceder al panel de taller', () {
      expect(
        _redirect(
          currentPath: '/mechanic_dashboard',
          userData: _user('uid-o', 'Propietario'),
        ),
        '/dashboard',
      );
    });
  });

  group('mecanico pendiente de aprobacion', () {
    test('un mecanico pendiente es enviado a /mechanic_pending', () {
      expect(
        _redirect(
          currentPath: '/mechanic_dashboard',
          userData: _user('uid-t', 'Taller', estado: 'pendiente'),
        ),
        '/mechanic_pending',
      );
    });

    test('un mecanico pendiente puede permanecer en /mechanic_pending', () {
      expect(
        _redirect(
          currentPath: '/mechanic_pending',
          userData: _user('uid-t', 'Taller', estado: 'pendiente'),
        ),
        isNull,
      );
    });

    test('un taller sin aprobar puede editar su perfil y armar su '
        'expediente', () {
      // Son las dos unicas rutas, ademas de la de espera, que funcionan de
      // verdad sin aprobacion: /workshop_settings escribe en usuarios/{uid}
      // (autorizado por isOwner) y /workshop_verification en
      // verificaciones/{uid}. Sin esto la pantalla de espera no lleva a
      // ninguna parte y el administrador nunca recibe evidencia que revisar.
      for (final ruta in ['/workshop_settings', '/workshop_verification']) {
        expect(
          _redirect(
            currentPath: ruta,
            userData: _user('uid-t', 'Taller', estado: 'pendiente'),
          ),
          isNull,
          reason: '$ruta debe seguir accesible sin aprobacion',
        );
      }
    });

    test('la galeria comercial NO esta en las rutas de onboarding', () {
      // Publicar escaparate en una ruta de lectura publica es exactamente lo
      // que la aprobacion viene a autorizar, asi que /workshop_gallery se
      // queda fuera del onboarding. storage.rules lo exige por su lado con
      // esTallerAprobado(); esto solo evita ofrecer una pantalla que iba a
      // fallar de todas formas.
      expect(
        _redirect(
          currentPath: '/workshop_gallery',
          userData: _user('uid-t', 'Taller', estado: 'pendiente'),
        ),
        '/mechanic_pending',
      );
      expect(
        _redirect(
          currentPath: '/workshop_gallery',
          userData: _user('uid-t', 'Taller', estado: 'activo'),
        ),
        isNull,
      );
    });

    test('el resto del panel de taller sigue cerrado sin aprobacion', () {
      // Abrirlo no daria acceso: cada consulta pasa por isMecanico() en
      // firestore.rules, que exige estado in ['aprobado','activo'], asi que
      // el dashboard se pintaria roto en vez de bloqueado.
      for (final ruta in [
        '/mechanic_dashboard',
        '/mechanic_search',
        '/mechanic_reparaciones',
        '/mechanic/empleados',
      ]) {
        expect(
          _redirect(
            currentPath: ruta,
            userData: _user('uid-t', 'Taller', estado: 'pendiente'),
          ),
          '/mechanic_pending',
          reason: '$ruta no funciona sin aprobacion',
        );
      }
    });

    test('un taller suspendido tampoco entra por la puerta del onboarding', () {
      // Una suspension no es un registro a medias: no debe reabrir el tramite.
      // Se comprueba que al menos se le retiene en la pantalla de espera.
      expect(
        _redirect(
          currentPath: '/mechanic_dashboard',
          userData: _user('uid-t', 'Taller', estado: 'suspendido'),
        ),
        '/mechanic_pending',
      );
    });

    test(
      'un mecanico suspendido es enviado a /mechanic_pending, no dejado pasar',
      () {
        // `suspenderUsuario` (admin_service.dart) escribe estado:'suspendido'.
        // El enrutador usaba una lista de BLOQUEO ({'pendiente','pending'})
        // que dejaba pasar 'suspendido' a /mechanic_dashboard aunque
        // isMecanico() en firestore.rules le niegue toda lectura ahi.
        expect(
          _redirect(
            currentPath: '/mechanic_dashboard',
            userData: _user('uid-t', 'Taller', estado: 'suspendido'),
          ),
          '/mechanic_pending',
        );
      },
    );
  });

  group('rutas de chat con parametro', () {
    test('/reserva_detail/:id sigue permitido para ambos roles', () {
      expect(
        _redirect(
          currentPath: '/reserva_detail/r1',
          userData: _user('uid-t', 'Taller'),
        ),
        isNull,
      );
      expect(
        _redirect(
          currentPath: '/reserva_detail/r1',
          userData: _user('uid-o', 'Propietario'),
        ),
        isNull,
      );
    });
  });
}
