import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/widgets/navigation/app_bottom_nav.dart';
import 'package:autodoc/core/widgets/navigation/app_nav_rail.dart';
import 'package:autodoc/core/widgets/app_top_nav_bar.dart';

import '../../support/shell_harness.dart';

void main() {
  group('rol Propietario', () {
    testWidgets('compact (375) usa la barra inferior', (tester) async {
      await pumpShell(tester, width: 375, rol: 'Propietario');

      expect(find.byType(AppBottomNav), findsOneWidget);
      expect(find.byType(AppNavRail), findsNothing);
      expect(find.byType(AppTopNavBar), findsNothing);
    });

    testWidgets('medium (768) usa el rail colapsado', (tester) async {
      await pumpShell(tester, width: 768, rol: 'Propietario');

      expect(find.byType(AppNavRail), findsOneWidget);
      expect(
        tester.widget<AppNavRail>(find.byType(AppNavRail)).extended,
        isFalse,
      );
      expect(find.byType(AppBottomNav), findsNothing);
    });

    testWidgets('expanded (1024) usa el rail extendido', (tester) async {
      await pumpShell(tester, width: 1024, rol: 'Propietario');

      expect(find.byType(AppNavRail), findsOneWidget);
      expect(
        tester.widget<AppNavRail>(find.byType(AppNavRail)).extended,
        isTrue,
      );
      expect(find.byType(AppBottomNav), findsNothing);
    });

    testWidgets('large (1440) usa la barra superior', (tester) async {
      await pumpShell(tester, width: 1440, rol: 'Propietario');

      expect(find.byType(AppTopNavBar), findsOneWidget);
      expect(find.byType(AppBottomNav), findsNothing);
      expect(find.byType(AppNavRail), findsNothing);
    });

    testWidgets('exactamente una presentación de nav por ancho', (
      tester,
    ) async {
      for (final width in [
        320.0,
        375.0,
        600.0,
        768.0,
        840.0,
        1024.0,
        1200.0,
        1440.0,
      ]) {
        await pumpShell(tester, width: width, rol: 'Propietario');

        final present = [
          tester.widgetList(find.byType(AppBottomNav)).length,
          tester.widgetList(find.byType(AppNavRail)).length,
          tester.widgetList(find.byType(AppTopNavBar)).length,
        ];

        expect(
          present.where((count) => count > 0).length,
          1,
          reason: 'a $width px hay ${present.where((c) => c > 0).length} navs',
        );
        expect(tester.takeException(), isNull, reason: 'overflow @$width');
      }
    });

    testWidgets('la ruta actual marca el destino correcto', (tester) async {
      await pumpShell(
        tester,
        width: 375,
        rol: 'Propietario',
        location: '/workshop_directory',
      );

      expect(
        tester.widget<AppBottomNav>(find.byType(AppBottomNav)).currentIndex,
        3,
      );
    });
  });

  group('rol Mecanico', () {
    testWidgets('compact y medium usan drawer, no sidebar fijo', (
      tester,
    ) async {
      for (final width in [375.0, 768.0]) {
        await pumpShell(tester, width: width, rol: 'Mecanico');

        // DrawerController no construye su child (el Drawer) mientras está
        // cerrado, así que find.byType(Drawer) no lo encuentra en reposo.
        // La presencia real de la navegación por drawer se verifica en la
        // propiedad drawer del Scaffold.
        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
        expect(scaffold.drawer, isNotNull, reason: 'sin drawer @$width');
        expect(find.byType(AppBottomNav), findsNothing);
      }
    });

    testWidgets('expanded y large usan sidebar fijo, sin drawer', (
      tester,
    ) async {
      for (final width in [1024.0, 1440.0]) {
        await pumpShell(tester, width: width, rol: 'Mecanico');

        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
        expect(scaffold.drawer, isNull, reason: 'drawer @$width');
        expect(tester.takeException(), isNull, reason: 'overflow @$width');
      }
    });
  });
}
