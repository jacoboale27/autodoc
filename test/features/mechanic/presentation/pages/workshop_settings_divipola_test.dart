import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/constants/divipola_sv.dart';
import 'package:autodoc/core/models/user_model.dart';
import 'package:autodoc/features/mechanic/presentation/pages/workshop_settings_screen.dart';

import '../../../../support/mechanic_harness.dart';

void main() {
  group('WorkshopSettingsScreen - Divipola y Municipios Huérfanos', () {
    testWidgets('todos los 14 departamentos de divipolaSv están en el dropdown', (
      tester,
    ) async {
      await pumpMechanicScreen(
        tester,
        const WorkshopSettingsScreen(),
        width: 1440,
        location: '/workshop_settings',
        disableAnimations: true,
      );
      await tester.pumpAndSettle();

      // El segundo dropdown es Departamento (el primero es Especialidad)
      final deptDropdown = find.byType(DropdownButtonFormField<String>).at(1);
      expect(deptDropdown, findsOneWidget);

      // Desplegar el dropdown
      await tester.tap(deptDropdown);
      await tester.pumpAndSettle();

      // El menú desplegable (gracias a menuMaxHeight) crea un ListView con scroll.
      // Confirmamos que los departamentos son alcanzables haciendo drag en el menú.
      final menuScrollable = find.byType(Scrollable).last;
      for (final dept in divipolaSv.keys) {
        await tester.dragUntilVisible(
          find.text(dept),
          menuScrollable,
          const Offset(0, -40),
        );
        expect(
          find.text(dept),
          findsWidgets,
          reason: 'El departamento $dept debe ser alcanzable en el dropdown',
        );
      }
    });

    testWidgets(
      'seleccionar un departamento actualiza los municipios correspondientes',
      (tester) async {
        await pumpMechanicScreen(
          tester,
          const WorkshopSettingsScreen(),
          width: 1440,
          location: '/workshop_settings',
          disableAnimations: true,
        );
        await tester.pumpAndSettle();

        // Seleccionar San Salvador
        final deptDropdown = find.byType(DropdownButtonFormField<String>).at(1);
        await tester.tap(deptDropdown);
        await tester.pumpAndSettle();

        await tester.tap(find.text('San Salvador').last);
        await tester.pumpAndSettle();

        // Abrir el dropdown de Municipio (el tercer dropdown)
        final muniDropdown = find.byType(DropdownButtonFormField<String>).at(2);
        await tester.tap(muniDropdown);
        await tester.pumpAndSettle();

        // Verificar los 5 municipios de San Salvador según reforma 2023
        final expectedMunis = divipolaSv['San Salvador']!;
        for (final muni in expectedMunis) {
          expect(
            find.text(muni).hitTestable(),
            findsWidgets,
            reason: 'Municipio $muni de San Salvador debe estar disponible',
          );
        }
      },
    );

    testWidgets(
      'municipio huérfano (pre-reforma) no rompe el dropdown y muestra aviso no bloqueante',
      (tester) async {
        // Usuario con San Salvador y "Soyapango" (distrito pre-reforma 2023)
        final userConMuniAntiguo = UserModel(
          idUsuario: 'taller-123',
          nombreCompleto: 'Taller San Salvador',
          correo: 'taller@ejemplo.com',
          rol: 'Mecanico',
          departamento: 'San Salvador',
          municipio: 'Soyapango',
          ubicacionMunicipio: 'Soyapango',
          especialidad: 'Mecánica General',
          telefono: '7788-9900',
          latitud: 13.69,
          longitud: -89.19,
          fechaRegistro: DateTime(2026, 1, 1),
        );

        await pumpMechanicScreen(
          tester,
          const WorkshopSettingsScreen(),
          user: userConMuniAntiguo,
          width: 1440,
          location: '/workshop_settings',
          disableAnimations: true,
        );
        await tester.pumpAndSettle();

        // Debe mostrar el aviso no bloqueante sobre la reforma de 2023
        expect(
          find.textContaining('Soyapango'),
          findsOneWidget,
          reason: 'El aviso debe mencionar el municipio huérfano guardado',
        );
        expect(
          find.textContaining('2023'),
          findsOneWidget,
          reason:
              'El aviso debe explicar que se debe a la reforma territorial de 2023',
        );

        // El dropdown de municipio no debe crashear
        final muniDropdown = find.byType(DropdownButtonFormField<String>).at(2);
        expect(muniDropdown, findsOneWidget);
      },
    );
  });
}
