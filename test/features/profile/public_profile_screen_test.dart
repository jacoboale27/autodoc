import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/widgets/app_user_avatar.dart';
import 'package:autodoc/features/profile/data/services/public_profile_service.dart';
import 'package:autodoc/features/profile/presentation/pages/public_profile_screen.dart';

import '../../support/entry_harness.dart';

/// Tarea 10, C3 — "ver el perfil del otro desde el chat".
///
/// El brief fija exactamente qué es "público" para cada rol:
/// - Mecánico visto por un cliente: nombre, foto, taller, especialidad,
///   calificación, reseñas.
/// - Cliente visto por un mecánico: nombre, foto, municipio. NUNCA
///   teléfono, DUI, correo ni la lista de vehículos.
///
/// La frontera de seguridad real (que un mecánico no pueda arrancarle esos
/// campos a un cliente por ningún camino, ni siquiera leyendo el documento
/// directo) se prueba del lado servidor:
/// `functions/test/obtener_perfil_publico.test.js` (el subconjunto que
/// devuelve el callable) y `test_rules/perfil_publico.test.js` (que
/// `usuarios/{cliente}` sigue negado de forma directa). Este archivo prueba
/// solo que la pantalla pinta lo que el mecanismo ya filtró — no repite esa
/// prueba de seguridad porque una pantalla no puede probar una frontera que
/// no controla.
void main() {
  group('PublicProfileScreen — mecánico visto por un cliente', () {
    testWidgets(
      'muestra nombre, foto, especialidad, calificación y reseñas de talleres/{uid}',
      (tester) async {
        final firestore = FakeFirebaseFirestore();
        await firestore.collection('talleres').doc('mec1').set({
          'nombre': 'Taller Escobar',
          'foto_perfil_url': 'https://x/taller.jpg',
          'especialidad': 'Frenos',
          'calificacion_promedio': 4.5,
          'total_resenias': 2,
        });
        await firestore.collection('resenias').doc('r1').set({
          'id_taller': 'mec1',
          'estrellas': 5,
          'comentario': 'Excelente servicio',
        });

        await pumpEntry(
          tester,
          PublicProfileScreen(userId: 'mec1', firestore: firestore),
          profile: FakeUserProfileProvider(
            userData: testUser(rol: 'Propietario'),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Taller Escobar'), findsWidgets);
        expect(find.text('Frenos'), findsOneWidget);
        expect(find.text('4.5'), findsOneWidget);
        expect(find.text('(2 reseñas)'), findsOneWidget);
        expect(find.text('Excelente servicio'), findsOneWidget);
        final avatar = tester.widget<AppUserAvatar>(find.byType(AppUserAvatar));
        expect(avatar.urlFoto, 'https://x/taller.jpg');
      },
    );

    testWidgets(
      'un taller sin documento publicado muestra el estado vacío, no un crash',
      (tester) async {
        final firestore = FakeFirebaseFirestore();

        await pumpEntry(
          tester,
          PublicProfileScreen(userId: 'fantasma', firestore: firestore),
          profile: FakeUserProfileProvider(
            userData: testUser(rol: 'Propietario'),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('No se pudo cargar este perfil.'), findsOneWidget);
      },
    );
  });

  group('PublicProfileScreen — cliente visto por un mecánico', () {
    testWidgets(
      'muestra solo nombre, foto y municipio; nunca teléfono/DUI/correo/vehículos',
      (tester) async {
        // El fetcher inyectado sustituye al callable real
        // (`obtenerPerfilPublico`): la pantalla nunca decide qué campos
        // vienen, solo pinta lo que este servicio le entregue — igual que en
        // producción, donde ese subconjunto lo decide el servidor
        // (`functions/src/obtenerPerfilPublico.js`), no la UI.
        final service = PublicProfileService(
          obtenerPerfilCliente: (userId) async {
            expect(userId, 'cli1');
            return {
              'nombre': 'Cliente Real',
              'foto_perfil_url': 'https://x/cliente.jpg',
              'municipio': 'San Salvador',
            };
          },
        );

        await pumpEntry(
          tester,
          PublicProfileScreen(userId: 'cli1', publicProfileService: service),
          profile: FakeUserProfileProvider(userData: testUser(rol: 'Mecanico')),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Cliente Real'), findsWidgets);
        expect(find.text('San Salvador'), findsOneWidget);
        // El brief explícitamente prohíbe estos campos en la vista del
        // cliente — si algún día aparecieran en el mapa que devuelve el
        // fetcher, esta pantalla no tiene ningún widget que los busque ni
        // los muestre.
        expect(find.textContaining('DUI'), findsNothing);
        expect(find.textContaining('correo'), findsNothing);
        expect(find.textContaining('teléfono'), findsNothing);
      },
    );

    testWidgets(
      'sin conversación compartida (callable niega el acceso) muestra el estado vacío',
      (tester) async {
        final service = PublicProfileService(
          obtenerPerfilCliente: (userId) async => null,
        );

        await pumpEntry(
          tester,
          PublicProfileScreen(userId: 'extrano', publicProfileService: service),
          profile: FakeUserProfileProvider(userData: testUser(rol: 'Taller')),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('No se pudo cargar este perfil.'), findsOneWidget);
      },
    );

    testWidgets(
      'un cliente sin municipio (dato anterior a esta tarea) no rompe el layout',
      (tester) async {
        final service = PublicProfileService(
          obtenerPerfilCliente: (userId) async => {'nombre': 'Cliente Viejo'},
        );

        await pumpEntry(
          tester,
          PublicProfileScreen(userId: 'cli2', publicProfileService: service),
          profile: FakeUserProfileProvider(userData: testUser(rol: 'Mecanico')),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Cliente Viejo'), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('PublicProfileScreen — perfil público del taller (Tarea 13, D1)', () {
    testWidgets(
      'un taller completo muestra ubicación, galería, catálogo y empleados',
      (tester) async {
        final firestore = FakeFirebaseFirestore();
        await firestore.collection('talleres').doc('mec2').set({
          'nombre': 'Taller Completo',
          'especialidad': 'Motores',
          'calificacion_promedio': 4.0,
          'total_resenias': 0,
          'direccion': 'Calle Principal #123',
          'departamento': 'San Salvador',
          'ubicacion': const GeoPoint(13.6929, -89.2182),
          'galeria': ['logo.webp', 'local-1.jpg'],
        });
        await firestore
            .collection('talleres')
            .doc('mec2')
            .collection('catalogo_servicios')
            .doc('item1')
            .set({'nombre': 'Cambio de aceite', 'precio': 25.0});

        final empleadosSolicitados = <String>[];
        final service = PublicProfileService(
          firestore: firestore,
          obtenerEmpleadosPublicos: (idTaller) async {
            empleadosSolicitados.add(idTaller);
            return [
              {
                'nombre_completo': 'Juan Pérez',
                'rol': 'Mecanico',
                'activo': true,
              },
            ];
          },
        );

        await pumpEntry(
          tester,
          PublicProfileScreen(
            userId: 'mec2',
            firestore: firestore,
            publicProfileService: service,
            storageBucket: 'bucket-de-prueba.appspot.com',
          ),
          profile: FakeUserProfileProvider(
            userData: testUser(rol: 'Propietario'),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(empleadosSolicitados, ['mec2']);

        // Ubicación: dirección + departamento, y el botón para abrir Maps
        // porque el documento sí trae `ubicacion` (GeoPoint).
        expect(
          find.byKey(const Key('perfil_publico_ubicacion')),
          findsOneWidget,
        );
        expect(find.text('Calle Principal #123, San Salvador'), findsOneWidget);
        expect(
          find.byKey(const Key('perfil_publico_abrir_mapa')),
          findsOneWidget,
        );

        // Galería: dos archivos válidos -> dos imágenes.
        expect(find.byKey(const Key('perfil_publico_galeria')), findsOneWidget);

        // Catálogo: el item sembrado en la subcolección pública.
        expect(
          find.byKey(const Key('perfil_publico_catalogo')),
          findsOneWidget,
        );
        expect(find.text('Cambio de aceite'), findsOneWidget);
        expect(find.text('\$25.00'), findsOneWidget);

        // Empleados: exactamente lo que devolvió el callable (allowlist),
        // nunca correo/teléfono (que ni siquiera llegan a este mapa).
        expect(
          find.byKey(const Key('perfil_publico_empleados')),
          findsOneWidget,
        );
        expect(find.text('Juan Pérez'), findsOneWidget);
        expect(find.text('Mecanico'), findsOneWidget);
      },
    );

    testWidgets(
      'un taller anterior a esta tarea (sin galería/ubicación/catálogo/empleados) no rompe el layout',
      (tester) async {
        final firestore = FakeFirebaseFirestore();
        await firestore.collection('talleres').doc('mec3').set({
          'nombre': 'Taller Viejo',
          'especialidad': 'General',
        });

        final service = PublicProfileService(
          firestore: firestore,
          obtenerEmpleadosPublicos: (idTaller) async => const [],
        );

        await pumpEntry(
          tester,
          PublicProfileScreen(
            userId: 'mec3',
            firestore: firestore,
            publicProfileService: service,
          ),
          profile: FakeUserProfileProvider(
            userData: testUser(rol: 'Propietario'),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Taller Viejo'), findsWidgets);
        expect(find.byKey(const Key('perfil_publico_ubicacion')), findsNothing);
        expect(find.byKey(const Key('perfil_publico_galeria')), findsNothing);
        expect(find.byKey(const Key('perfil_publico_catalogo')), findsNothing);
        expect(find.byKey(const Key('perfil_publico_empleados')), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'la sección Empleados nunca pinta correo ni teléfono aunque el fetcher los devuelva',
      (tester) async {
        // El fetcher inyectado sustituye al callable real
        // (`obtenerEmpleadosPublicos`), que es la frontera de seguridad
        // real (ver functions/test/obtener_empleados_publicos.test.js). Si
        // por error algún día ese fetcher trajera de más, esta pantalla no
        // tiene ningún widget que busque ni pinte esos campos.
        final firestore = FakeFirebaseFirestore();
        await firestore.collection('talleres').doc('mec4').set({
          'nombre': 'Taller Con Empleado',
        });

        final service = PublicProfileService(
          firestore: firestore,
          obtenerEmpleadosPublicos: (idTaller) async => [
            {
              'nombre_completo': 'Empleado Filtrado',
              'rol': 'Mecanico',
              'activo': true,
              'correo': 'empleado@test.com',
              'telefono': '7000-0000',
            },
          ],
        );

        await pumpEntry(
          tester,
          PublicProfileScreen(
            userId: 'mec4',
            firestore: firestore,
            publicProfileService: service,
          ),
          profile: FakeUserProfileProvider(
            userData: testUser(rol: 'Propietario'),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Empleado Filtrado'), findsOneWidget);
        expect(find.textContaining('empleado@test.com'), findsNothing);
        expect(find.textContaining('7000-0000'), findsNothing);
      },
    );
  });
}
