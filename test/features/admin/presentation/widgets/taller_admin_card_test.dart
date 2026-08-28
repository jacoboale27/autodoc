// test/features/admin/presentation/widgets/taller_admin_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/models/workshop_model.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/features/admin/presentation/widgets/taller_admin_card.dart';
import 'package:autodoc/l10n/app_localizations.dart';

WorkshopModel _taller(String estado) => WorkshopModel(
  idTaller: 't1',
  nombre: 'Taller El Buen Motor',
  ubicacionMunicipio: 'Soyapango',
  departamento: 'San Salvador',
  especialidad: 'Frenos',
  telefono: '+503 7777-8888',
  calificacionPromedio: 4.5,
  estado: estado,
);

Future<Map<String, int>> pumpCard(WidgetTester tester, String estado) async {
  final pulsaciones = <String, int>{
    'reactivar': 0,
    'rechazar': 0,
    'suspender': 0,
    'expediente': 0,
  };

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: TallerAdminCard(
            taller: _taller(estado),
            onReactivar: () => pulsaciones['reactivar'] = 1,
            onRechazar: () => pulsaciones['rechazar'] = 1,
            onSuspender: () => pulsaciones['suspender'] = 1,
            onVerExpediente: () => pulsaciones['expediente'] = 1,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return pulsaciones;
}

void main() {
  testWidgets('un taller pendiente lleva al expediente, no ofrece aprobar', (
    tester,
  ) async {
    final pulsaciones = await pumpCard(tester, 'pendiente');

    expect(
      find.text('Ver expediente'),
      findsOneWidget,
      reason:
          'aprobar desde aquí escribía usuarios.estado sin mirar una '
          'sola foto de la evidencia',
    );

    await tester.tap(find.text('Ver expediente'));
    await tester.pump();
    expect(pulsaciones['expediente'], 1);
  });

  testWidgets('un taller con estado «activo» cuenta como aprobado', (
    tester,
  ) async {
    // `VerificacionService.aprobar` escribe 'activo'
    // (`AppEstadoCuenta.valorAprobado`), no 'aprobado'. Comparando el texto
    // crudo, un taller recién aprobado desde la bandeja volvía a la tarjeta
    // con el chip naranja y los botones de una cuenta pendiente.
    await pumpCard(tester, 'activo');

    expect(find.text('ACTIVO'), findsOneWidget);
    expect(find.text('Ver expediente'), findsNothing);
    expect(find.byIcon(Icons.block_flipped), findsOneWidget);
  });

  testWidgets('«aprobado» sigue reconociéndose, por datos ya migrados', (
    tester,
  ) async {
    await pumpCard(tester, 'aprobado');

    expect(find.text('ACTIVO'), findsOneWidget);
    expect(find.byIcon(Icons.block_flipped), findsOneWidget);
  });

  testWidgets('un taller suspendido se reactiva, no se «aprueba»', (
    tester,
  ) async {
    final pulsaciones = await pumpCard(tester, 'suspendido');

    expect(find.text('SUSPENDIDO'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.check_circle_outline));
    await tester.pump();
    expect(pulsaciones['reactivar'], 1);
    expect(pulsaciones['expediente'], 0);
  });
}
