import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/core/models/user_model.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/widgets/app_empty_state.dart';
import 'package:autodoc/features/chat/presentation/pages/reserva_detail_screen.dart';
import 'package:autodoc/l10n/app_localizations.dart';

// UserProfileProvider real construye un UserService que toca
// FirebaseFirestore.instance en su inicializacion, lo que no existe en un
// widget test sin Firebase.initializeApp(). ReservaDetailScreen solo
// necesita leer userData.rol durante build(), asi que un fake evita esa
// dependencia sin necesitar mocks de Firebase Core.
class _FakeUserProfileProvider extends ChangeNotifier
    implements UserProfileProvider {
  @override
  UserModel? get userData => null;
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
}
