import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Centinela: toda pantalla que cierre sesion **con datos cargados** tiene que
/// limpiar los providers.
///
/// **Por que existe.** `session_reset.dart` nacio porque cerrar sesion sin
/// limpiar deja al siguiente usuario los datos del anterior: alertas, chats,
/// reservas, vehiculos y, en el caso del taller, una suscripcion viva que sigue
/// emitiendo. El arreglo fue `clearSessionFrom`, y `session_reset_test.dart`
/// prueba que esa funcion hace su trabajo.
///
/// Lo que NINGUNA suite probaba es que las pantallas la llamen. Ese test
/// ejercita las salidas que alguien recordo cablear; una nueva que naciera
/// manana sin la llamada pasaria inadvertida. Este archivo cierra ese hueco
/// leyendo el codigo, que es la unica forma de verlo.
///
/// Mismo patron que el centinela de App Check (SEC-04), que corta el entrypoint
/// por bloques en vez de contar ocurrencias.
void main() {
  test('cada pantalla que hace signOut limpia tambien los providers', () {
    final raiz = Directory('${Directory.current.path}/lib/features');
    final infractores = <String>[];

    for (final entidad in raiz.listSync(recursive: true)) {
      if (entidad is! File || !entidad.path.endsWith('.dart')) continue;
      final fuente = entidad.readAsStringSync();

      if (!fuente.contains('.signOut()')) continue;
      final ruta = entidad.path.split(Platform.pathSeparator).join('/');
      final relativa = ruta.split('/lib/').last;

      if (_exentas.containsKey(relativa)) continue;

      // El provider que implementa el cierre y el servicio que habla con
      // Firebase no tienen context del que limpiar.
      if (relativa.endsWith('auth_provider.dart') ||
          relativa.endsWith('auth_service.dart')) {
        continue;
      }

      if (!fuente.contains('clearSessionFrom')) {
        infractores.add(relativa);
      }
    }

    expect(
      infractores,
      isEmpty,
      reason:
          'Estas pantallas cierran sesion sin llamar a clearSessionFrom, asi '
          'que el siguiente usuario hereda alertas, chats, reservas y '
          'vehiculos del anterior, y el stream del taller saliente sigue '
          'emitiendo. Anade la llamada ANTES del signOut, como hacen las '
          'demas. Si la pantalla no puede tener datos cargados, documentala '
          'en `_exentas` con la razon — pero lee antes el comentario de ahi: '
          'la exencion se gana demostrando que el router impide llegar con '
          'datos, no suponiendolo.',
    );
  });

  test('cada exencion sigue existiendo', () {
    for (final relativa in _exentas.keys) {
      expect(
        File('${Directory.current.path}/lib/$relativa').existsSync(),
        isTrue,
        reason:
            'La exencion de `$relativa` apunta a un archivo que ya no existe. '
            'Una exencion huerfana es una regla relajada sin que nadie lo '
            'decidiera: borrala.',
      );
    }
  });
}

/// Pantallas que cierran sesion y **no** necesitan limpiar, con su razon.
///
/// Una exencion aqui no es «es incomodo de probar»: es que el router garantiza
/// que a esa pantalla no se puede llegar con datos de usuario cargados. Si esa
/// garantia cambia, la exencion deja de valer.
const _exentas = <String, String>{
  'features/auth/presentation/pages/email_verification_screen.dart':
      'Gate de correo sin verificar. El redirect del router manda a '
      '/verify_email a TODA sesion no verificada (app_router.dart:246-250) '
      'y no deja pasar a ninguna pantalla que cargue datos, asi que los '
      'providers con estado por usuario estan vacios cuando se llega aqui. '
      'Ademas una cuenta verificada no puede volver a estar sin verificar, '
      'asi que no hay camino desde una sesion con datos. Se intento anadir '
      'la llamada igualmente, por uniformidad, y el coste no lo justifica: '
      '`clearSessionFrom` lee los SIETE providers del contexto, y este test '
      'de pantalla declara explicitamente que no instancia servicios de '
      'datos. Forzarlos ahi rompia dos casos y tapaba el gate real.',
};
