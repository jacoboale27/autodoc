import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/core/models/user_model.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/features/chat/data/models/mensaje_model.dart';
import 'package:autodoc/features/chat/data/repositories/chat_repository.dart';
import 'package:autodoc/features/chat/presentation/pages/chat_screen.dart';
import 'package:autodoc/features/chat/presentation/providers/chat_provider.dart';
import 'package:autodoc/l10n/app_localizations.dart';

// UserProfileProvider real construye un UserService que toca
// FirebaseFirestore.instance en su inicializacion, lo que no existe en un
// widget test sin Firebase.initializeApp(). ChatScreen solo necesita leer
// userData.idUsuario/rol durante build()/initState(), asi que un fake evita
// esa dependencia sin necesitar mocks de Firebase Core. Mismo patron que
// reserva_detail_screen_test.dart.
class _FakeUserProfileProvider extends ChangeNotifier
    implements UserProfileProvider {
  final UserModel _user;
  _FakeUserProfileProvider(this._user);

  @override
  UserModel? get userData => _user;
  @override
  bool get isLoading => false;
  @override
  bool get hasAttemptedFetch => true;
  @override
  String? get fetchedUserId => _user.idUsuario;
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

// setTypingStatus también se sobreescribe: ChatScreen la dispara desde
// dispose() (vía `_controller` listener y el propio dispose), y el fallback
// de Mockito para un método no stubbeado lanza sincrónicamente al intentar
// devolver `null` para un `Future<void>` no anulable — eso hace que
// ChatProvider.setTypingStatus lo capture y llame notifyListeners() en medio
// del unmount, lo cual el framework rechaza ("widget tree was locked").
// ChatRepository real toca FirebaseFirestore.instance ya en su constructor
// (campo `final _firestore = FirebaseFirestore.instance;`), lo que no existe
// en un widget test sin Firebase.initializeApp(). No podemos "extends
// ChatRepository" (el constructor real seguiría corriendo); usamos el mismo
// patron de Mockito con `implements` (sin invocar el constructor real) que
// chat_provider_test.dart, pero sobreescribiendo directamente los métodos que
// ChatScreen dispara desde su ciclo de vida (streamMensajes,
// marcarComoLeidos) en vez de stubbear con when()/verify(): Mockito manual
// (sin build_runner) no genera valores dummy para retornos no anulables como
// Future<void>, así que when()/verify() lanzan un TypeError al invocar el
// método real durante el registro del stub.
class FakeChatRepository extends Mock implements ChatRepository {
  bool marcarComoLeidosCalled = false;
  String? capturedConversacionId;
  bool? capturedIsMecanico;
  String? capturedUserId;

  @override
  Stream<List<MensajeModel>> streamMensajes(String conversacionId) {
    return Stream.value([]);
  }

  @override
  Future<void> marcarComoLeidos(
    String conversacionId,
    bool isMecanico,
    String currentUserId,
  ) async {
    marcarComoLeidosCalled = true;
    capturedConversacionId = conversacionId;
    capturedIsMecanico = isMecanico;
    capturedUserId = currentUserId;
  }

  @override
  Future<void> setTypingStatus(
    String conversacionId,
    String? typingUserId,
  ) async {}
}

void main() {
  testWidgets('ChatScreen marca mensajes como leídos al abrir', (tester) async {
    final fakeChatRepository = FakeChatRepository();

    final chatProvider = ChatProvider(repository: fakeChatRepository);
    addTearDown(chatProvider.dispose);

    final user = UserModel(
      idUsuario: 'user-1',
      nombreCompleto: 'Propietario de prueba',
      correo: 'propietario@test.com',
      rol: 'Propietario',
      fechaRegistro: DateTime(2026, 1, 1),
    );

    Widget buildApp(Widget home) => MultiProvider(
      providers: [
        ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
        ChangeNotifierProvider<UserProfileProvider>.value(
          value: _FakeUserProfileProvider(user),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    );

    await tester.pumpWidget(
      buildApp(const ChatScreen(conversacionId: 'conv-1')),
    );

    // Deja correr el addPostFrameCallback del initState y la resolución
    // asíncrona de marcarComoLeidos.
    await tester.pumpAndSettle();

    expect(fakeChatRepository.marcarComoLeidosCalled, isTrue);
    expect(fakeChatRepository.capturedConversacionId, 'conv-1');
    expect(fakeChatRepository.capturedIsMecanico, isFalse);
    expect(fakeChatRepository.capturedUserId, 'user-1');

    // Desmonta ChatScreen explícitamente mientras los providers ancestro
    // siguen montados (mismo MultiProvider, solo se reemplaza `home`): si
    // dejamos que el framework de test derribe todo el árbol de una vez al
    // cerrar, ChatScreen.dispose() —que lee context.read<ChatProvider>()—
    // puede ejecutarse con su ancestro ya desactivado en ese unmount masivo
    // y lanzar "Looking up a deactivated widget's ancestor is unsafe".
    // Desmontar aquí, con los providers todavía en pie, reproduce el ciclo
    // de vida real (Navigator.pop) en vez de ese caso límite del cierre de
    // test.
    await tester.pumpWidget(buildApp(const SizedBox()));
  });
}
