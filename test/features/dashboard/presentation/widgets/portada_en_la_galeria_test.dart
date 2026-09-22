import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/features/dashboard/data/services/vehicle_photo_service.dart';
import 'package:autodoc/features/dashboard/presentation/widgets/vehicle_gallery_widget.dart';

import '../../../../support/imagenes_de_red.dart';

/// Elegir cuál de las fotos representa al vehículo.
///
/// La galería ya existía; lo que no existía era la relación con `foto_url`, y
/// por eso al retirar el buscador de imágenes de terceros (GAPS-08) todos los
/// coches se quedaron con la silueta. Sin marca visible de cuál es la portada,
/// "usar como principal" es además un botón del que no se sabe si hace falta
/// pulsarlo.

const _f1 =
    'https://firebasestorage.googleapis.com/v0/b/b/o/'
    'vehiculos%2Fv1%2Ffotos%2Ff1.jpg?alt=media&token=t';
const _f2 =
    'https://firebasestorage.googleapis.com/v0/b/b/o/'
    'vehiculos%2Fv1%2Ffotos%2Ff2.jpg?alt=media&token=t';

class _Servicio extends VehiclePhotoService {
  _Servicio(FakeFirebaseFirestore firestore) : super(firestore: firestore);

  @override
  Future<String> subirAStorage(String v, String p, XFile f) async => _f1;

  @override
  Future<void> borrarDeStorage(String url) async {}
}

List<VehiclePhotoModel> _dosFotos() => [
  VehiclePhotoModel(id: 'f1', url: _f1, timestamp: DateTime(2026, 9, 2)),
  VehiclePhotoModel(id: 'f2', url: _f2, timestamp: DateTime(2026, 9, 1)),
];

Future<FakeFirebaseFirestore> _firestoreCon(String portada) async {
  final f = FakeFirebaseFirestore();
  await f.collection('vehiculos').doc('v1').set({
    'id_vehiculo': 'v1',
    'id_propietario': 'u1',
    'foto_url': portada,
  });
  return f;
}

const _colors = AppColors(
  primary: Colors.blue,
  secondary: Colors.teal,
  surface: Colors.white,
  surfaceContainer: Colors.white,
  error: Colors.red,
  warning: Colors.orange,
  success: Colors.green,
  textPrimary: Colors.black,
  textSecondary: Colors.grey,
  onPrimary: Colors.white,
  onSecondary: Colors.white,
  onError: Colors.white,
  surfaceVariant: Colors.white,
  outline: Colors.grey,
  shimmerBase: Colors.grey,
  shimmerHighlight: Colors.white,
  scrim: Colors.black,
  onScrim: Colors.white,
);

Widget _app(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

/// El visor trae su propio `Scaffold`, asi que no puede ir dentro del scroll
/// de `_app`: un `Scaffold` con altura sin cota revienta en layout.
Widget _pantalla(Widget child) => MaterialApp(home: child);

Widget _galeria({String? portada, VoidCallback? onCambio}) =>
    VehicleGalleryWidget(
      vehicleId: 'v1',
      colors: _colors,
      photos: Stream.value(_dosFotos()),
      fotoPrincipal: portada,
      onPortadaCambiada: onCambio,
    );

void main() {
  testWidgets('la foto que es portada se marca, y solo ella', (tester) async {
    await conImagenesDeRed(() async {
      await tester.pumpWidget(_app(_galeria(portada: _f1)));
      await tester.pump();

      expect(
        find.bySemanticsLabel('Foto principal del vehículo'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Foto de la galería'), findsOneWidget);
    });
  });

  testWidgets('sin portada asignada, ninguna sale marcada', (tester) async {
    await conImagenesDeRed(() async {
      await tester.pumpWidget(_app(_galeria(portada: null)));
      await tester.pump();

      expect(
        find.bySemanticsLabel('Foto principal del vehículo'),
        findsNothing,
      );
      expect(find.bySemanticsLabel('Foto de la galería'), findsNWidgets(2));
    });
  });

  testWidgets('sobre una foto que no es portada se ofrece elegirla', (
    tester,
  ) async {
    await conImagenesDeRed(() async {
      await tester.pumpWidget(_app(_galeria(portada: _f1)));
      await tester.pump();

      await tester.tap(find.bySemanticsLabel('Foto de la galería'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.star_outline), findsOneWidget);
    });
  });

  // La acción NO se pinta sobre la que ya es la portada: un botón que no
  // cambia nada es peor que no tenerlo.
  testWidgets('sobre la portada no se ofrece volver a elegirla', (
    tester,
  ) async {
    await conImagenesDeRed(() async {
      await tester.pumpWidget(_app(_galeria(portada: _f1)));
      await tester.pump();

      await tester.tap(find.bySemanticsLabel('Foto principal del vehículo'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.star_outline), findsNothing);
      expect(find.byIcon(Icons.delete), findsOneWidget);
    });
  });

  testWidgets('el visor cambia la portada de verdad y avisa', (tester) async {
    await conImagenesDeRed(() async {
      final firestore = await _firestoreCon(_f1);
      final servicio = _Servicio(firestore);
      var avisos = 0;

      await tester.pumpWidget(
        _pantalla(
          FullScreenImageViewer(
            foto: VehiclePhotoModel(
              id: 'f2',
              url: _f2,
              timestamp: DateTime(2026, 9, 1),
            ),
            vehicleId: 'v1',
            servicio: servicio,
            onPortadaCambiada: () => avisos++,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.star_outline));
      await tester.pumpAndSettle();

      final doc = await firestore.collection('vehiculos').doc('v1').get();
      expect(doc.data()?['foto_url'], _f2);
      expect(
        avisos,
        1,
        reason:
            'sin el aviso, el garaje sigue enseñando la foto anterior hasta '
            'el siguiente arranque: foto_url vive en el provider, no en el '
            'stream de la galería',
      );
    });
  });
}
