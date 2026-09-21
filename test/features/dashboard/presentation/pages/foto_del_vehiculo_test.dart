import 'dart:typed_data';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import 'package:autodoc/core/models/vehicle_model.dart';
import 'package:autodoc/core/providers/auth_session_provider.dart';
import 'package:autodoc/features/dashboard/data/services/vehicle_photo_service.dart';
import 'package:autodoc/features/dashboard/presentation/pages/vehicle_profile_screen.dart';
import 'package:autodoc/features/dashboard/presentation/providers/vehicle_provider.dart';

import '../../../../helpers/test_helpers.mocks.dart';
import '../../../../support/responsive_harness.dart';
import '../../../../support/vehicle_fixtures.dart';

/// La foto del vehículo tiene que poder ponerla su dueño.
///
/// GAPS-08 retiró el buscador de imágenes de terceros que rellenaba `foto_url`
/// solo, y con eso **todos los coches se quedaron con la silueta**: la galería
/// existía pero nada la conectaba con la foto del vehículo. Estos tests cubren
/// el puente por el lado de la pantalla; la lógica de portada está en
/// `vehicle_photo_service_test.dart`.

const _url =
    'https://firebasestorage.googleapis.com/v0/b/b/o/'
    'vehiculos%2Fv0%2Ffotos%2Ff1.jpg?alt=media&token=t';

/// `XFile` que no toca el disco: `readAsBytes` es lo único que el servicio
/// llama, y un fichero de verdad haría el test dependiente del sistema.
class _FotoFalsa extends XFile {
  _FotoFalsa() : super('foto.jpg');
  @override
  Future<Uint8List> readAsBytes() async => Uint8List.fromList([1, 2, 3]);
}

/// Servicio real sobre un Firestore falso, con Storage sustituido por el
/// seam: lo que se prueba es que la pantalla LLAME al camino correcto, no la
/// subida de bytes.
class _ServicioDePrueba extends VehiclePhotoService {
  _ServicioDePrueba(FakeFirebaseFirestore firestore)
    : super(firestore: firestore);

  int subidas = 0;

  @override
  Future<String> subirAStorage(
    String vehicleId,
    String photoId,
    XFile imageFile,
  ) async {
    subidas++;
    return _url;
  }

  @override
  Future<void> borrarDeStorage(String url) async {}
}

Future<FakeFirebaseFirestore> _firestoreCon({String? fotoUrl}) async {
  final f = FakeFirebaseFirestore();
  await f.collection('vehiculos').doc('v0').set({
    'id_vehiculo': 'v0',
    'id_propietario': 'u1',
    'placa': 'P000-123',
    'foto_url': ?fotoUrl,
  });
  return f;
}

Future<_ServicioDePrueba> _montarFicha(
  WidgetTester tester, {
  required VehicleModel vehiculo,
  required FakeFirebaseFirestore firestore,
  Future<XFile?> Function()? seleccionar,
}) async {
  final servicio = _ServicioDePrueba(firestore);
  final mockAuth = MockFirebaseAuth();
  when(mockAuth.idTokenChanges()).thenAnswer((_) => const Stream.empty());

  // El resumen de gastos se construye en cada `build` de la ficha; sin este
  // stub, el MissingStubError tumba la pantalla entera antes de pintar nada.
  final vehicleService = MockVehicleService();
  when(vehicleService.getExpenseSummary(any)).thenAnswer((_) async => {});

  await pumpAtWidth(
    tester,
    MultiProvider(
      providers: [
        ChangeNotifierProvider<VehicleProvider>.value(
          value: FakeVehicleProvider([vehiculo]),
        ),
        ChangeNotifierProvider<AuthSessionProvider>.value(
          value: AuthSessionProvider(firebaseAuth: mockAuth),
        ),
      ],
      child: VehicleProfileScreen(
        vehiculoId: vehiculo.idVehiculo,
        vehiculoPrecargado: vehiculo,
        vehicleService: vehicleService,
        // Galería vacía e inyectada: sin este seam la pantalla abre un stream
        // contra Firestore real.
        galleryPhotos: Stream.value(const <VehiclePhotoModel>[]),
        photoService: servicio,
        seleccionarFoto: seleccionar ?? () async => _FotoFalsa(),
      ),
    ),
    width: 400,
  );
  await tester.pump();
  return servicio;
}

void main() {
  testWidgets('sin foto, la ficha invita a añadir una', (tester) async {
    final vehiculo = fakeVehicle(0);
    await _montarFicha(
      tester,
      vehiculo: vehiculo,
      firestore: await _firestoreCon(),
    );

    expect(find.text('Añade una foto de tu vehículo'), findsOneWidget);
  });

  // El placeholder guardado como si fuera una URL es lo que dejó el buscador
  // retirado cuando no encontraba nada. Si la ficha lo tratara como una foto
  // de verdad, esos vehículos se quedarían sin ninguna vía para poner la suya.
  testWidgets('con el placeholder guardado, también invita', (tester) async {
    final vehiculo = fakeVehicle(
      0,
    ).copyWith(fotoUrl: VehiclePhotoService.placeholder);
    await _montarFicha(
      tester,
      vehiculo: vehiculo,
      firestore: await _firestoreCon(fotoUrl: VehiclePhotoService.placeholder),
    );

    expect(find.text('Añade una foto de tu vehículo'), findsOneWidget);
  });

  testWidgets('con foto, la invitación desaparece', (tester) async {
    final vehiculo = fakeVehicle(0).copyWith(fotoUrl: _url);
    await _montarFicha(
      tester,
      vehiculo: vehiculo,
      firestore: await _firestoreCon(fotoUrl: _url),
    );

    expect(find.text('Añade una foto de tu vehículo'), findsNothing);
  });

  testWidgets('tocar la invitación sube la foto y la deja como portada', (
    tester,
  ) async {
    final firestore = await _firestoreCon();
    final servicio = await _montarFicha(
      tester,
      vehiculo: fakeVehicle(0),
      firestore: firestore,
    );

    await tester.tap(find.text('Añade una foto de tu vehículo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(servicio.subidas, 1);
    final doc = await firestore.collection('vehiculos').doc('v0').get();
    expect(
      doc.data()?['foto_url'],
      _url,
      reason:
          'subir la primera foto tiene que dejar el coche con foto; si no, '
          'la silueta sigue ahí después de subirla',
    );
  });

  testWidgets('dos taps seguidos suben una sola vez', (tester) async {
    var llamadas = 0;
    final servicio = await _montarFicha(
      tester,
      vehiculo: fakeVehicle(0),
      firestore: await _firestoreCon(),
      seleccionar: () async {
        llamadas++;
        // Deja la primera subida en vuelo el tiempo suficiente para que el
        // segundo tap encuentre el guard puesto. `onTap: null` por sí solo no
        // basta: solo surte efecto en el frame siguiente.
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return _FotoFalsa();
      },
    );

    final invitacion = find.text('Añade una foto de tu vehículo');
    await tester.tap(invitacion);
    await tester.tap(invitacion);
    await tester.pump(const Duration(milliseconds: 500));

    expect(llamadas, 1);
    expect(servicio.subidas, 1);
  });
}
