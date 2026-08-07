import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:autodoc/core/models/service_record_model.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/core/constants/firestore_collections.dart';
import 'package:autodoc/features/dashboard/presentation/pages/service_history_screen.dart';
import 'package:autodoc/l10n/app_localizations.dart';

// ServiceHistoryScreen fuente sus datos en vivo desde
// FirebaseFirestore.instance dentro de un StreamBuilder (no de un provider
// inyectado como asumia el borrador de este plan -- no existe ningun
// VehicleProvider.serviceHistoryFor). Se le agrega un parametro `firestore`
// opcional (mismo patron ya usado en ReservaDetailScreen) para poder
// inyectar un FakeFirebaseFirestore en el test sin tocar
// FirebaseFirestore.instance real.
//
// _buildReviewAction (llamado para registros no manuales) lee
// FirebaseAuth.instance.currentUser, lo que exige que exista una app
// Firebase "[DEFAULT]" registrada; setupFirebaseCoreMocks() +
// Firebase.initializeApp() cubren eso sin necesitar un usuario autenticado
// real (currentUser sera null y ese widget se omite).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  testWidgets('tapping a service card opens a details dialog with its data', (
    tester,
  ) async {
    await Firebase.initializeApp();
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final firestore = FakeFirebaseFirestore();
    final record = ServiceRecordModel(
      idServicio: 's1',
      idVehiculo: 'v1',
      idTaller: 'Manual (Propietario)',
      tipoServicio: 'Cambio de aceite',
      fecha: DateTime(2026, 1, 15),
      kilometrajeServicio: 45000,
      costo: 60.0,
      descripcion: 'Aceite sintético 5W-30',
    );
    await firestore
        .collection(FirestoreCollections.servicios)
        .doc('s1')
        .set(record.toMap());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ServiceHistoryScreen(vehiculoId: 'v1', firestore: firestore),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cambio de aceite'), findsWidgets);

    await tester.tap(find.text('Cambio de aceite').first);
    await tester.pumpAndSettle();

    // La descripcion tambien se muestra en la propia tarjeta (debajo del
    // dialogo, que es un overlay), asi que aparece dos veces en el arbol.
    expect(find.text('Aceite sintético 5W-30'), findsNWidgets(2));
    expect(find.text('Cerrar'), findsOneWidget);
    expect(find.text('Descripción'), findsOneWidget);
  });
}
