import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/models/user_model.dart';
import 'package:autodoc/core/router/app_router.dart';

/// IA-01 — `/asistente` es la unica ruta que sirve a los dos roles.
///
/// **Por que hace falta un test y no basta con "no esta en ningun conjunto".**
/// `resolveRedirect` decide por conjuntos: una ruta que aparezca en
/// `_ownerRoutes` deja fuera a todos los talleres, y una que aparezca en
/// `_mechanicRoutes` deja fuera a todos los propietarios. Los dos conjuntos
/// son privados y estan a 700 lineas del `GoRoute`, asi que el dia que alguien
/// ordene alfabeticamente o "complete" una de las listas, la mitad de los
/// usuarios acabaria rebotando a su home sin ningun error — un fallo que no
/// rompe nada y que nadie relaciona con la lista que toco.
///
/// El lado negativo importa igual: un taller **sin aprobar** no puede llegar.
/// No porque la pantalla haga algo, sino porque `agenda.js` le responderia
/// `permission-denied`, y retenerlo antes en `/mechanic_pending` es lo que
/// evita ensenarle una pantalla que solo puede fallar.
UserModel _usuario(String rol, {String estado = 'activo'}) => UserModel(
  idUsuario: 'u1',
  correo: 'u1@test.com',
  nombreCompleto: 'Usuario',
  rol: rol,
  fechaRegistro: DateTime(2026, 1, 1),
  estado: estado,
);

String? _redirect(UserModel usuario) => resolveRedirect(
  isLoggedIn: true,
  emailVerified: true,
  userData: usuario,
  isLoading: false,
  hasAttemptedFetch: true,
  profileError: null,
  currentPath: '/asistente',
);

void main() {
  test('el propietario puede abrir el asistente', () {
    expect(_redirect(_usuario('Propietario')), isNull);
  });

  test('el taller aprobado puede abrir el asistente', () {
    // Su agenda son las citas confirmadas, no los vencimientos: mismo
    // callable, otra rama de `construirAgenda`.
    expect(_redirect(_usuario('Mecanico')), isNull);
    expect(_redirect(_usuario('Taller', estado: 'aprobado')), isNull);
  });

  test('el taller sin aprobar se queda en su sala de espera', () {
    expect(
      _redirect(_usuario('Mecanico', estado: 'pendiente')),
      '/mechanic_pending',
    );
    expect(
      _redirect(_usuario('Taller', estado: 'suspendido')),
      '/mechanic_pending',
    );
  });

  test('el administrador tambien pasa', () {
    // No tiene vehiculos ni taller, asi que `construirAgenda` le devolvera la
    // rama de propietario con cero items y un texto fijo. Es una respuesta
    // pobre, pero es una respuesta: rebotarlo aqui seria una pantalla en
    // blanco sin motivo.
    expect(_redirect(_usuario('Administrador')), isNull);
  });
}
