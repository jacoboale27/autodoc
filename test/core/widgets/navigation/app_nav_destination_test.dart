import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/widgets/navigation/app_nav_destination.dart';

void main() {
  group('AppNavDestinations.owner', () {
    test('respeta el límite de 5 destinos de una bottom nav', () {
      expect(AppNavDestinations.owner.length, lessThanOrEqualTo(5));
    });

    test('conserva el orden actual de pestañas', () {
      expect(AppNavDestinations.owner.map((d) => d.route).toList(), [
        '/dashboard',
        '/garage',
        '/chat_list',
        '/workshop_directory',
        '/user_profile',
      ]);
    });

    test('todo destino tiene label y semanticLabel no vacíos', () {
      for (final destination in AppNavDestinations.owner) {
        expect(destination.label, isNotEmpty, reason: destination.route);
        expect(
          destination.semanticLabel,
          isNotEmpty,
          reason: destination.route,
        );
      }
    });

    test('el icono seleccionado difiere del de reposo', () {
      for (final destination in AppNavDestinations.owner) {
        expect(
          destination.selectedIcon,
          isNot(destination.icon),
          reason: '${destination.route}: el estado activo no se distingue',
        );
      }
    });
  });

  group('indexForLocation', () {
    test('resuelve cada ruta exacta a su índice', () {
      for (var i = 0; i < AppNavDestinations.owner.length; i++) {
        expect(
          AppNavDestinations.indexForLocation(
            AppNavDestinations.owner[i].route,
          ),
          i,
        );
      }
    });

    test('resuelve sub-rutas al destino padre', () {
      expect(AppNavDestinations.indexForLocation('/garage/123'), 1);
      expect(
        AppNavDestinations.indexForLocation('/chat_list?filter=abiertas'),
        2,
      );
    });

    test('una ruta desconocida cae al primer destino', () {
      expect(AppNavDestinations.indexForLocation('/ruta_inexistente'), 0);
      expect(AppNavDestinations.indexForLocation(''), 0);
    });

    test('no confunde prefijos parciales de otra ruta', () {
      // '/user_profile_setup' no debe resolverse a '/user_profile'.
      expect(AppNavDestinations.indexForLocation('/user_profile_setup'), 0);
    });
  });
}
