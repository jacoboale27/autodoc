import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:autodoc/core/constants/firestore_collections.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/core/models/user_model.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/widgets/app_empty_state.dart';
import 'package:autodoc/features/chat/presentation/pages/reserva_detail_screen.dart';
import 'package:autodoc/l10n/app_localizations.dart';

// UserProfileProvider real construye un UserService que toca
// FirebaseFirestore.instance en su inicializacion, lo que no existe en un
// widget test sin Firebase.initializeApp(). ReservaDetailScreen solo
// necesita leer userData.rol/idUsuario durante build(), asi que un fake
// evita esa dependencia sin necesitar mocks de Firebase Core.
class _FakeUserProfileProvider extends ChangeNotifier
    implements UserProfileProvider {
  _FakeUserProfileProvider([this.userData]);

  @override
  final UserModel? userData;
  @override
  bool get isLoading => false;
  @override
  bool get hasAttemptedFetch => true;
  @override
  String? get fetchedUserId => null;
  @override
  String? get error => null;
  @override
  bool hasAttemptedFetchFor(String userId) => true;
  @override
  Future<void> fetchUserData(String userId) async {}
  @override
  Future<bool> updateProfile(
    UserModel updatedUser, {
    XFile? imageFile,
    bool isNewUser = false,
  }) async => true;
  @override
  void clearUserData() {}
}

// Cubre C-03 / Importante 1 de la revision de la Tarea 12: antes, esta
// pantalla casteaba `state.extra` a un `ReservaModel` no nulable, asi que
// una recarga o un enlace directo sin `extra` producia una pantalla en
// blanco. Ahora recibe solo el id y carga el documento en vivo desde
// Firestore; este test verifica que, aun cuando el documento no existe,
// nunca se renderiza una pantalla vacia -- se muestra un mensaje explicito.
void main() {
  testWidgets('muestra un mensaje explicito (no una pantalla en blanco) si la '
      'reserva no existe en Firestore', (tester) async {
    final firestore = FakeFirebaseFirestore();
    // Deliberadamente no se crea ningun documento 'no-existe'.

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ChangeNotifierProvider<UserProfileProvider>.value(
          value: _FakeUserProfileProvider(),
          child: ReservaDetailScreen(
            reservaId: 'no-existe',
            firestore: firestore,
          ),
        ),
      ),
    );

    // Deja que se resuelva la carga asincrona (doc.get() del fake).
    await tester.pumpAndSettle();

    expect(find.byType(AppEmptyState), findsOneWidget);
    expect(find.byType(Text), findsWidgets);
  });

  // Cubre Bloque C / Tarea C3 (hallazgo #4): quien propone la fecha vigente
  // no debe poder resolver su propia propuesta desde esta pantalla.
  testWidgets(
    'el proponente no ve "Aceptar Cita" en una reserva pendiente que él mismo propuso',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection(FirestoreCollections.reservas).doc('r1').set({
        'id_conversacion': 'c1',
        'id_propietario': 'owner-1',
        'id_mecanico': 'mec-1',
        'id_vehiculo': 'v1',
        'id_taller': 'mec-1',
        'id_proponente': 'owner-1',
        'fecha_hora_propuesta': DateTime(2026, 9, 10, 10, 0),
        'tipo_servicio': 'Frenos',
        'estado': 'pendiente',
        'fecha_creacion': DateTime(2026, 9, 1),
      });

      final propietario = UserModel(
        idUsuario: 'owner-1',
        nombreCompleto: 'Dueño de prueba',
        correo: 'owner@test.com',
        rol: 'Propietario',
        fechaRegistro: DateTime(2026, 1, 1),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ChangeNotifierProvider<UserProfileProvider>.value(
            value: _FakeUserProfileProvider(propietario),
            child: ReservaDetailScreen(reservaId: 'r1', firestore: firestore),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Aceptar Cita'), findsNothing);
      expect(find.text('Reprogramar'), findsNothing);
      expect(find.text('Rechazar'), findsNothing);
      // El proponente conserva la posibilidad de cancelar con rastro.
      expect(find.byType(AppButton), findsOneWidget);
    },
  );

  testWidgets(
    'la contraparte SI ve "Aceptar Cita" cuando no es quien propuso',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection(FirestoreCollections.reservas).doc('r1').set({
        'id_conversacion': 'c1',
        'id_propietario': 'owner-1',
        'id_mecanico': 'mec-1',
        'id_vehiculo': 'v1',
        'id_taller': 'mec-1',
        'id_proponente': 'mec-1',
        'fecha_hora_propuesta': DateTime(2026, 9, 10, 10, 0),
        'tipo_servicio': 'Frenos',
        'estado': 'pendiente',
        'fecha_creacion': DateTime(2026, 9, 1),
      });

      final propietario = UserModel(
        idUsuario: 'owner-1',
        nombreCompleto: 'Dueño de prueba',
        correo: 'owner@test.com',
        rol: 'Propietario',
        fechaRegistro: DateTime(2026, 1, 1),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ChangeNotifierProvider<UserProfileProvider>.value(
            value: _FakeUserProfileProvider(propietario),
            child: ReservaDetailScreen(reservaId: 'r1', firestore: firestore),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Aceptar Cita'), findsOneWidget);
      expect(find.text('Reprogramar'), findsOneWidget);
      expect(find.text('Rechazar'), findsOneWidget);
    },
  );
}
