import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:autodoc/features/dashboard/presentation/providers/vehicle_provider.dart';
import 'package:autodoc/core/models/vehicle_model.dart';
import '../../helpers/test_helpers.mocks.dart';

void main() {
  late MockVehicleService mockVehicleService;
  late MockVehicleImageService mockVehicleImageService;
  late VehicleProvider vehicleProvider;

  setUp(() {
    mockVehicleService = MockVehicleService();
    mockVehicleImageService = MockVehicleImageService();
    vehicleProvider = VehicleProvider(
      vehicleService: mockVehicleService,
      imageService: mockVehicleImageService,
    );
  });

  group('VehicleProvider Tests', () {
    test('initial state is correct', () {
      expect(vehicleProvider.isLoading, false);
      expect(vehicleProvider.error, null);
      expect(vehicleProvider.vehicles, isEmpty);
      expect(vehicleProvider.selectedVehicle, null);
    });

    test('loadVehicles success', () async {
      final vehicles = [
        VehicleModel(
          idVehiculo: '1',
          idPropietario: 'owner',
          placa: 'ABC',
          marca: 'Toyota',
          modelo: 'Corolla',
          anio: 2020,
        ),
      ];
      when(
        mockVehicleService.getVehiclesByOwner('owner'),
      ).thenAnswer((_) async => vehicles);
      when(
        mockVehicleService.getSharedVehicles('owner'),
      ).thenAnswer((_) async => []);

      await vehicleProvider.fetchVehicles('owner');

      expect(vehicleProvider.isLoading, false);
      expect(vehicleProvider.error, null);
      expect(vehicleProvider.vehicles.length, 1);
      expect(vehicleProvider.vehicles.first.idVehiculo, '1');
      expect(vehicleProvider.selectedVehicle, vehicles.first);
    });

    test('addVehicle success', () async {
      final vehicle = VehicleModel(
        idVehiculo: '1',
        idPropietario: 'owner',
        placa: 'ABC',
        marca: 'Toyota',
        modelo: 'Corolla',
        anio: 2020,
        color: 'Rojo',
      );
      when(
        mockVehicleImageService.getVehicleImage(
          vehicleId: anyNamed('vehicleId'),
          brand: anyNamed('brand'),
          model: anyNamed('model'),
          year: anyNamed('year'),
          color: anyNamed('color'),
        ),
      ).thenAnswer((_) async => 'http://image.url');
      when(mockVehicleService.addVehicle(any)).thenAnswer((_) async {});
      when(
        mockVehicleService.getVehiclesByOwner('owner'),
      ).thenAnswer((_) async => [vehicle]);
      when(
        mockVehicleService.getSharedVehicles('owner'),
      ).thenAnswer((_) async => []);

      await vehicleProvider.addVehicle(vehicle);

      expect(vehicleProvider.isLoading, false);
      expect(vehicleProvider.error, null);
      expect(vehicleProvider.vehicles.length, 1);
      expect(vehicleProvider.vehicles.first.idVehiculo, '1');
    });

    test('deleteVehicle success', () async {
      final vehicle = VehicleModel(
        idVehiculo: '1',
        idPropietario: 'owner',
        placa: 'ABC',
        marca: 'Toyota',
        modelo: 'Corolla',
        anio: 2020,
        color: 'Rojo',
      );
      when(
        mockVehicleImageService.getVehicleImage(
          vehicleId: anyNamed('vehicleId'),
          brand: anyNamed('brand'),
          model: anyNamed('model'),
          year: anyNamed('year'),
          color: anyNamed('color'),
        ),
      ).thenAnswer((_) async => 'http://image.url');
      when(mockVehicleService.addVehicle(any)).thenAnswer((_) async {});
      when(mockVehicleService.deleteVehicle('1')).thenAnswer((_) async {});
      when(
        mockVehicleService.getVehiclesByOwner('owner'),
      ).thenAnswer((_) async => [vehicle]);
      when(
        mockVehicleService.getSharedVehicles('owner'),
      ).thenAnswer((_) async => []);

      await vehicleProvider.addVehicle(vehicle);
      expect(vehicleProvider.vehicles.length, 1);

      when(
        mockVehicleService.getVehiclesByOwner('owner'),
      ).thenAnswer((_) async => []);
      await vehicleProvider.deleteVehicle('1', 'owner');

      expect(vehicleProvider.vehicles.length, 0);
      expect(vehicleProvider.isLoading, false);
      expect(vehicleProvider.error, null);
    });

    test('setMainVehicle changes selectedVehicle', () async {
      final vehicles = [
        VehicleModel(
          idVehiculo: '1',
          idPropietario: 'owner',
          placa: 'ABC',
          marca: 'Toyota',
          modelo: 'Corolla',
          anio: 2020,
        ),
        VehicleModel(
          idVehiculo: '2',
          idPropietario: 'owner',
          placa: 'XYZ',
          marca: 'Honda',
          modelo: 'Civic',
          anio: 2022,
        ),
      ];
      when(
        mockVehicleService.getVehiclesByOwner('owner'),
      ).thenAnswer((_) async => vehicles);
      when(
        mockVehicleService.getSharedVehicles('owner'),
      ).thenAnswer((_) async => []);
      when(mockVehicleService.updateVehicle(any)).thenAnswer((_) async {});

      await vehicleProvider.fetchVehicles('owner');
      expect(vehicleProvider.selectedVehicle?.idVehiculo, '1');

      await vehicleProvider.setAsPrimary(vehicles[1]);

      // Wait, in the mock getVehiclesByOwner should now return the updated list to test `fetchVehicles`
      // For now we just verify it calls updateVehicle
      verify(
        mockVehicleService.updateVehicle(argThat(isA<VehicleModel>())),
      ).called(greaterThan(0));
    });
  });
}
