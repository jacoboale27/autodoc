import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import 'package:autodoc/core/models/vehicle_model.dart';
import 'package:autodoc/core/providers/auth_session_provider.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/services/push_notification_service.dart';
import 'package:autodoc/features/dashboard/presentation/pages/alerts_screen.dart';
import 'package:autodoc/features/dashboard/presentation/pages/garage_screen.dart';
import 'package:autodoc/features/dashboard/presentation/providers/alert_provider.dart';
import 'package:autodoc/features/dashboard/presentation/providers/vehicle_provider.dart';

import '../../../../helpers/test_helpers.mocks.dart';
import '../../../../support/responsive_harness.dart';
import '../../../../support/shell_harness.dart';
import '../../../../support/vehicle_fixtures.dart';

/// Un F5 sobre `/garage` o `/alerts` monta la pantalla con los providers
/// RECIEN CONSTRUIDOS, sin haber pasado por el dashboard. Eso es lo que estos
/// tests reproducen: no se precarga nada en el provider, se monta la pantalla
/// sola y se afirma que los datos aparecen.
///
/// Antes del arreglo el garaje pintaba «No tienes vehiculos» con tres
/// sembrados y las alertas «Selecciona un vehiculo primero», porque ninguna
/// de las dos pantallas pedia sus datos: solo los leian, y quien los cargaba
/// era el dashboard.

class _FakePush extends Fake implements PushNotificationService {
  @override
  Future<void> updateUserToken(String userId) async {}
}

AuthSessionProvider _sesion() {
  PushNotificationService.setInstanceForTesting(_FakePush());
  // 'test-uid' es el uid que devuelve `FakeProfileProvider`, y tiene que
  // coincidir: es el que llega a `asegurarVehiculosCargados`.
  final auth = MockFirebaseAuth();
  final user = MockUser();
  when(user.uid).thenReturn('test-uid');
  when(auth.idTokenChanges()).thenAnswer((_) => Stream.value(user));
  return AuthSessionProvider(firebaseAuth: auth);
}

/// `VehicleProvider` real —el del arreglo— sobre un servicio de mentira.
///
/// No vale `FakeVehicleProvider` de vehicle_fixtures: ese devuelve la lista
/// ya hecha desde un getter, asi que pasaria igual sin arreglo. Lo que hay
/// que ejercitar es la CARGA.
({
  VehicleProvider provider,
  List<VehicleModel> vehiculos,
  int Function() llamadas,
})
_providerQueCarga() {
  final servicio = MockVehicleService();
  final vehiculos = List.generate(3, fakeVehicle);
  var llamadas = 0;
  when(servicio.getVehiclesByOwner('test-uid')).thenAnswer((_) async {
    llamadas++;
    return vehiculos;
  });
  when(
    servicio.getSharedVehicles('test-uid'),
  ).thenAnswer((_) async => <VehicleModel>[]);
  return (
    provider: VehicleProvider(vehicleService: servicio),
    vehiculos: vehiculos,
    llamadas: () => llamadas,
  );
}

Future<void> _montar(
  WidgetTester tester,
  Widget pantalla, {
  required VehicleProvider vehiculos,
  required AlertProvider alertas,
}) async {
  await pumpAtWidth(
    tester,
    MultiProvider(
      providers: [
        ChangeNotifierProvider<VehicleProvider>.value(value: vehiculos),
        ChangeNotifierProvider<AlertProvider>.value(value: alertas),
        ChangeNotifierProvider<AuthSessionProvider>.value(value: _sesion()),
        ChangeNotifierProvider<UserProfileProvider>.value(
          value: FakeProfileProvider('Propietario'),
        ),
      ],
      child: pantalla,
    ),
    width: 400,
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('el garaje carga sus vehiculos aunque no se pase por el panel', (
    tester,
  ) async {
    final g = _providerQueCarga();

    await _montar(
      tester,
      const GarageScreen(),
      vehiculos: g.provider,
      alertas: AlertProvider(
        firestore: FakeFirebaseFirestore(),
        storage: MockFirebaseStorage(),
      ),
    );

    expect(g.llamadas(), 1, reason: 'la pantalla no pidio sus vehiculos');
    expect(g.provider.vehicles, hasLength(3));
    expect(find.text('No tienes vehículos en tu garaje'), findsNothing);
  });

  testWidgets(
    'las alertas seleccionan vehiculo aunque no se pase por el panel',
    (tester) async {
      final g = _providerQueCarga();

      await _montar(
        tester,
        const AlertsScreen(),
        vehiculos: g.provider,
        alertas: AlertProvider(
          firestore: FakeFirebaseFirestore(),
          storage: MockFirebaseStorage(),
        ),
      );

      expect(g.llamadas(), 1, reason: 'la pantalla no pidio sus vehiculos');
      expect(
        g.provider.selectedVehicle,
        isNotNull,
        reason: 'sin vehiculo seleccionado la pantalla no puede pintar nada',
      );
      expect(find.text('Selecciona un vehículo primero'), findsNothing);
    },
  );

  testWidgets('no se recarga en cada reconstruccion de la pantalla', (
    tester,
  ) async {
    final g = _providerQueCarga();

    await _montar(
      tester,
      const GarageScreen(),
      vehiculos: g.provider,
      alertas: AlertProvider(
        firestore: FakeFirebaseFirestore(),
        storage: MockFirebaseStorage(),
      ),
    );
    expect(g.llamadas(), 1);

    // `didChangeDependencies` vuelve a correr en cada cambio de dependencia
    // (tema, locale, perfil que llega tarde). Sin el memo del provider, cada
    // uno seria otra lectura del garaje entero.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(g.llamadas(), 1);
  });
}
