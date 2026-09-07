// Ronda 6 — el propietario ve y retira el acceso de los talleres a su
// vehículo.
//
// `talleres_vinculados` decide quién puede leer la ficha, la galería, las
// alertas y el historial del coche. Antes de esto el titular solo podía
// CONCEDERLO (banner de `taller_pendiente_confirmacion`) y no existía ninguna
// pantalla donde verlo ni forma de retirarlo.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:autodoc/core/models/vehicle_model.dart';
import 'package:autodoc/features/dashboard/presentation/providers/vehicle_provider.dart';
import 'package:autodoc/features/dashboard/presentation/widgets/talleres_con_acceso_card.dart';

import '../../../../helpers/test_helpers.mocks.dart';
import '../../../../support/responsive_harness.dart';

VehicleModel vehiculoCon(List<String> talleres) => VehicleModel(
  idVehiculo: 'v1',
  idPropietario: 'u1',
  placa: 'P123-456',
  marca: 'Toyota',
  modelo: 'Corolla',
  anio: 2020,
  color: 'Blanco',
  kilometrajeActual: 1000,
  talleresVinculados: talleres,
);

/// Provider que registra las revocaciones en vez de tocar Firestore.
class _SpyVehicleProvider extends VehicleProvider {
  _SpyVehicleProvider({this.exito = true})
    : super(
        vehicleService: MockVehicleService(),
        imageService: MockVehicleImageService(),
      );

  final bool exito;
  final List<({String vehiculo, String taller})> revocaciones = [];

  @override
  Future<bool> revocarAccesoTaller(String vehiculoId, String tallerId) async {
    revocaciones.add((vehiculo: vehiculoId, taller: tallerId));
    return exito;
  }
}

Future<void> _pumpCard(
  WidgetTester tester,
  VehicleModel vehiculo,
  _SpyVehicleProvider provider, {
  Future<Map<String, dynamic>?> Function(String uid)? resolver,
}) async {
  await pumpAtWidth(
    tester,
    ChangeNotifierProvider<VehicleProvider>.value(
      value: provider,
      child: SingleChildScrollView(
        child: TalleresConAccesoCard(
          vehicle: vehiculo,
          resolverTaller:
              resolver ?? (uid) async => {'nombre_taller': 'Taller $uid'},
        ),
      ),
    ),
    width: 800,
    disableAnimations: true,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sin talleres vinculados lo dice explícitamente', (tester) async {
    final provider = _SpyVehicleProvider();
    await _pumpCard(tester, vehiculoCon(const []), provider);

    expect(find.text('Talleres con acceso'), findsOneWidget);
    expect(find.text('Sin accesos activos'), findsOneWidget);
    expect(find.text('Retirar'), findsNothing);
  });

  testWidgets('lista los talleres con acceso por su nombre, no por su uid', (
    tester,
  ) async {
    final provider = _SpyVehicleProvider();
    await _pumpCard(tester, vehiculoCon(const ['uid-a', 'uid-b']), provider);

    expect(find.text('Taller uid-a'), findsOneWidget);
    expect(find.text('Taller uid-b'), findsOneWidget);
    expect(find.text('Retirar'), findsNWidgets(2));
  });

  testWidgets(
    'un taller sin perfil público SIGUE apareciendo: el acceso existe igual',
    (tester) async {
      // Nunca se oculta una entrada por no poder resolver su nombre — lo que
      // el propietario necesita saber es que ese acceso está concedido.
      final provider = _SpyVehicleProvider();
      await _pumpCard(
        tester,
        vehiculoCon(const ['uid-fantasma']),
        provider,
        resolver: (_) async => null,
      );

      expect(find.text('Taller sin perfil público'), findsOneWidget);
      expect(find.text('Retirar'), findsOneWidget);
    },
  );

  testWidgets('una lectura que falla tampoco esconde el acceso', (
    tester,
  ) async {
    final provider = _SpyVehicleProvider();
    await _pumpCard(
      tester,
      vehiculoCon(const ['uid-a']),
      provider,
      resolver: (_) async => throw Exception('permission-denied'),
    );

    expect(find.text('Taller sin perfil público'), findsOneWidget);
  });

  testWidgets('retirar pide confirmación antes de revocar', (tester) async {
    final provider = _SpyVehicleProvider();
    await _pumpCard(tester, vehiculoCon(const ['uid-a']), provider);

    await tester.tap(find.text('Retirar'));
    await tester.pumpAndSettle();

    expect(find.text('Retirar acceso'), findsWidgets);
    expect(find.textContaining('Taller uid-a'), findsWidgets);
    expect(provider.revocaciones, isEmpty);
  });

  testWidgets('"Volver" en la confirmación no revoca nada', (tester) async {
    final provider = _SpyVehicleProvider();
    await _pumpCard(tester, vehiculoCon(const ['uid-a']), provider);

    await tester.tap(find.text('Retirar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Volver'));
    await tester.pumpAndSettle();

    expect(provider.revocaciones, isEmpty);
  });

  testWidgets('confirmar revoca ese taller y solo ese', (tester) async {
    final provider = _SpyVehicleProvider();
    await _pumpCard(tester, vehiculoCon(const ['uid-a', 'uid-b']), provider);

    await tester.tap(find.text('Retirar').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sí, retirar'));
    await tester.pumpAndSettle();

    expect(provider.revocaciones, [(vehiculo: 'v1', taller: 'uid-a')]);
  });

  testWidgets('si la revocación falla se avisa en vez de callar', (
    tester,
  ) async {
    final provider = _SpyVehicleProvider(exito: false);
    await _pumpCard(tester, vehiculoCon(const ['uid-a']), provider);

    await tester.tap(find.text('Retirar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sí, retirar'));
    await tester.pump();

    expect(find.byType(SnackBar), findsOneWidget);
  });
}
