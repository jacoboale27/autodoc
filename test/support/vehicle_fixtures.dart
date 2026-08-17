// test/support/vehicle_fixtures.dart
import 'package:autodoc/core/models/vehicle_model.dart';
import 'package:autodoc/features/dashboard/presentation/providers/vehicle_provider.dart';

import '../helpers/test_helpers.mocks.dart';

VehicleModel fakeVehicle(int index) => VehicleModel(
  idVehiculo: 'v$index',
  idPropietario: 'u1',
  placa: 'P00$index-123',
  marca: 'Toyota',
  modelo: 'Corolla',
  anio: 2019 + index,
  color: 'Blanco',
  kilometrajeActual: 50000 + index * 1000,
);

/// Provider de vehículos con datos fijos, sin tocar Firestore.
///
/// `VehicleProvider()` por defecto crea `VehicleService()` y
/// `VehicleImageService()`, y ambas tocan `FirebaseFirestore.instance` en su
/// propio inicializador de campo — lanza sin `Firebase.initializeApp()`. Se
/// inyectan los mocks ya generados para `vehicle_provider_test.dart` en vez
/// de instanciar las clases reales.
class FakeVehicleProvider extends VehicleProvider {
  FakeVehicleProvider(this._vehicles)
    : super(
        vehicleService: MockVehicleService(),
        imageService: MockVehicleImageService(),
      );
  final List<VehicleModel> _vehicles;

  @override
  List<VehicleModel> get vehicles => _vehicles;

  @override
  VehicleModel? get selectedVehicle =>
      _vehicles.isEmpty ? null : _vehicles.first;

  @override
  bool get isLoading => false;
}

FakeVehicleProvider fakeVehicleProvider({int count = 4}) =>
    FakeVehicleProvider(List.generate(count, fakeVehicle));
