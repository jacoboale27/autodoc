import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/core/providers/auth_session_provider.dart';
import 'package:autodoc/core/widgets/app_card.dart';
import 'package:autodoc/core/widgets/app_grid.dart';
import 'package:autodoc/features/dashboard/presentation/pages/vehicle_profile_screen.dart';
import 'package:autodoc/features/dashboard/presentation/providers/vehicle_provider.dart';

import '../../../../helpers/test_helpers.mocks.dart';
import '../../../../support/responsive_harness.dart';
import '../../../../support/vehicle_fixtures.dart';

// VehicleGalleryWidget (que esta pantalla monta siempre) instancia
// VehiclePhotoService(), y su constructor llama a FirebaseStorage.instance,
// que exige un storageBucket. setupFirebaseCoreMocks() por defecto responde
// con CoreFirebaseOptions sin storageBucket ("no se puede encontrar el
// bucket por defecto"), así que se sustituye por un TestFirebaseCoreHostApi
// propio que sí lo declara.
class _MockFirebaseAppWithStorage implements TestFirebaseCoreHostApi {
  static final _options = CoreFirebaseOptions(
    apiKey: '123',
    appId: '123',
    messagingSenderId: '123',
    projectId: '123',
    storageBucket: 'test.appspot.com',
  );

  @override
  Future<CoreInitializeResponse> initializeApp(
    String appName,
    CoreFirebaseOptions initializeAppRequest,
  ) async {
    return CoreInitializeResponse(
      name: appName,
      options: _options,
      pluginConstants: {},
    );
  }

  @override
  Future<List<CoreInitializeResponse>> initializeCore() async {
    return [
      CoreInitializeResponse(
        name: defaultFirebaseAppName,
        options: _options,
        pluginConstants: {},
      ),
    ];
  }

  @override
  Future<CoreFirebaseOptions> optionsFromResource() async => _options;
}

// _buildExpenseSummary instancia VehicleService() directamente en build()
// (no inyectable) y su constructor toca FirebaseFirestore.instance.
// TestFirebaseCoreHostApi.setUp(...) + Firebase.initializeApp() registran
// una app Firebase "[DEFAULT]" falsa (mismo patrón que
// dashboard_screen_vehicle_fetch_test.dart) para que ese getter no lance.
Future<void> pumpScreen(
  WidgetTester tester,
  double width, {
  Brightness brightness = Brightness.light,
}) async {
  await Firebase.initializeApp();
  final mockAuth = MockFirebaseAuth();
  when(mockAuth.idTokenChanges()).thenAnswer((_) => const Stream.empty());
  final vehicle = fakeVehicle(0);
  await pumpAtWidth(
    tester,
    MultiProvider(
      providers: [
        ChangeNotifierProvider<VehicleProvider>.value(
          value: fakeVehicleProvider(),
        ),
        ChangeNotifierProvider<AuthSessionProvider>.value(
          value: AuthSessionProvider(firebaseAuth: mockAuth),
        ),
      ],
      child: VehicleProfileScreen(
        vehiculoId: vehicle.idVehiculo,
        vehiculoPrecargado: vehicle,
      ),
    ),
    width: width,
    brightness: brightness,
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestFirebaseCoreHostApi.setUp(_MockFirebaseAppWithStorage());

  test('no usa GoogleFonts ni colores literales', () {
    final source = File(
      'lib/features/dashboard/presentation/pages/vehicle_profile_screen.dart',
    ).readAsStringSync();

    expect(source.contains('GoogleFonts.'), isFalse);

    final offenders = <String>[];
    final lines = source.split('\n');
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].trimLeft().startsWith('//')) continue;
      if (lines[i].contains('Colors.transparent')) continue;
      if (RegExp(
        r'Color\(0x[0-9a-fA-F]{8}\)|Colors\.(white|black|grey|red)',
      ).hasMatch(lines[i])) {
        offenders.add('${i + 1}: ${lines[i].trim()}');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('el selector de fecha no fuerza ColorScheme.light', () {
    final source = File(
      'lib/features/dashboard/presentation/pages/vehicle_profile_screen.dart',
    ).readAsStringSync();
    expect(
      source.contains('ColorScheme.light('),
      isFalse,
      reason:
          'forzar ColorScheme.light hace que el date picker salga en '
          'claro con la app en dark mode',
    );
  });

  testWidgets('los detalles técnicos usan AppGrid con 2/2/3 columnas', (
    tester,
  ) async {
    // No 4 a 1440: igual que en garage_screen_test.dart, AppGrid decide por
    // el ancho real del panel (LayoutBuilder), y AppPageBody acota ese
    // panel a maxContentWidth (1200) menos su gutter en `large` (40): a
    // 1440px de viewport el panel real mide 1200 - 2*40 = 1120px, que cae
    // en `expanded` (840-1199), no en `large`. El techo alcanzable es 3
    // columnas en cualquier ancho de viewport.
    for (final (width, expected) in [
      (375.0, 2),
      (768.0, 2),
      (1024.0, 3),
      (1440.0, 3),
    ]) {
      await pumpScreen(tester, width);

      final grid = tester.widget<GridView>(find.byType(GridView).first);
      final columns =
          (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
              .crossAxisCount;
      expect(columns, expected, reason: '$columns columnas a $width px');
    }

    expect(find.byType(AppGrid), findsWidgets);
  });

  test('ninguna sección pone su propio gutter horizontal', () {
    final source = File(
      'lib/features/dashboard/presentation/pages/vehicle_profile_screen.dart',
    ).readAsStringSync();

    final offenders = <String>[];
    final lines = source.split('\n');
    for (var i = 0; i < lines.length; i++) {
      // Los cinco gutters duplicados que este test cierra eran 16/20/24 (o
      // Responsive.padding). El padding horizontal de 8 en la barra
      // superior fija (icon buttons, fuera del AppPageBody desplazable) no
      // es una "sección" de contenido y no forma parte de ese problema.
      if (RegExp(
        r'horizontal:\s*(1[6-9]|2[0-9]|Responsive\.padding)',
      ).hasMatch(lines[i])) {
        offenders.add('${i + 1}: ${lines[i].trim()}');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'el gutter lo pone AppPageBody una sola vez. La pantalla '
          'usaba cinco valores distintos (16/20/24), así que las secciones '
          'no se alineaban entre sí:\n${offenders.join('\n')}',
    );
  });

  testWidgets('las secciones comparten el mismo margen izquierdo', (
    tester,
  ) async {
    await pumpScreen(tester, 1440);

    // Solo las tarjetas fuera de AppGrid: sus celdas reparten varias
    // columnas a lo ancho a propósito (2/2/3/4), así que tienen varios
    // márgenes izquierdos por diseño. Lo que este test cierra es que las
    // secciones de una sola columna (hero, notas, estado de documentación)
    // compartan el mismo gutter, en vez de los cinco valores distintos
    // (16/20/24) de antes.
    final gridCardElements = find
        .descendant(of: find.byType(AppGrid), matching: find.byType(AppCard))
        .evaluate()
        .toSet();

    final cardLefts = <double>{};
    for (final element in find.byType(AppCard).evaluate()) {
      if (gridCardElements.contains(element)) continue;
      final box = element.renderObject as RenderBox;
      // Las tarjetas de "acciones rápidas" también reparten varias columnas
      // a propósito (Row de tres Expanded), igual que la rejilla: solo
      // interesan aquí las tarjetas de ancho completo (una sola columna).
      if (box.size.width < 600) continue;
      cardLefts.add(box.localToGlobal(Offset.zero).dx);
    }

    expect(
      cardLefts.length,
      lessThanOrEqualTo(2),
      reason:
          'las tarjetas fuera de la rejilla arrancan en '
          '${cardLefts.length} márgenes distintos ($cardLefts); como mucho '
          'debería haber uno',
    );
  });

  testWidgets('no desborda a 320px con marca y modelo largos', (tester) async {
    await pumpScreen(tester, 320);
    expectNoOverflow(tester);
  });

  testWidgets('no desborda en ningún ancho de auditoría, en ambos temas', (
    tester,
  ) async {
    for (final brightness in Brightness.values) {
      await forEachAuditWidth(tester, (width) async {
        await pumpScreen(tester, width, brightness: brightness);
        expectNoOverflow(tester);
      });
    }
  });
}
