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
