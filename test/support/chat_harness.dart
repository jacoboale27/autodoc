// test/support/chat_harness.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/core/models/user_model.dart';
import 'package:autodoc/core/providers/auth_session_provider.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/l10n/app_localizations.dart';
import 'package:autodoc/features/chat/data/models/conversacion_model.dart';
import 'package:autodoc/features/chat/data/models/mensaje_model.dart';
import 'package:autodoc/features/chat/presentation/providers/chat_provider.dart';
import 'package:autodoc/features/chat/presentation/providers/reserva_provider.dart';

import '../helpers/test_helpers.mocks.dart';

/// `AuthSessionProvider()` por defecto cae en `FirebaseAuth.instance`, que
/// lanza sin `Firebase.initializeApp()`; se inyecta un `MockFirebaseAuth`
/// con un stream vacío, igual que en `garage_screen_test.dart`.
///
/// `ConversacionesListScreen` lee `context.watch<AuthSessionProvider>()`
/// para inicializar la suscripción de conversaciones — un provider que este
/// harness no registraba hasta ahora porque ningún test previo montaba esa
/// pantalla completa.
AuthSessionProvider _fakeAuthSessionProvider() {
  final mockAuth = MockFirebaseAuth();
  when(mockAuth.idTokenChanges()).thenAnswer((_) => const Stream.empty());
  return AuthSessionProvider(firebaseAuth: mockAuth);
}

/// **Implementa** en vez de extender, y no es preferencia de estilo:
/// `UserProfileProvider` inicializa `final UserService _userService =
/// UserService()` en la declaración del campo, y `UserService` hace
/// `FirebaseFirestore.instance` en la suya. Extender la clase real ejecuta
/// ambos inicializadores y lanza en un widget test sin `Firebase.initializeApp()`.
///
/// Es el mismo patrón que ya usan `reserva_chat_card_test.dart` y
/// `reserva_detail_screen_test.dart` en este repositorio; aquí solo se
/// centraliza para no reescribirlo en cada tarea.
class FakeUserProfileProvider extends ChangeNotifier
    implements UserProfileProvider {
  FakeUserProfileProvider({this.user});
  final UserModel? user;

  @override
  UserModel? get userData => user;
  @override
  bool get isLoading => false;
  @override
  bool get hasAttemptedFetch => true;
  @override
  String? get fetchedUserId => user?.idUsuario;
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

/// Doble de `ChatProvider`. Solo expone lo que la capa de presentación lee
/// durante `build()`; todo lo demás son no-ops que devuelven éxito.
///
/// `noSuchMethod` se usa aquí como red de seguridad para los miembros que la
/// presentación no lee en `build()` (envío de mensajes, cotizaciones, subida
/// de archivos, etc.) — no para los que sí, que están todos con `@override`
/// explícito arriba. Con `implements` explícito, añadir un miembro nuevo que
/// la presentación empiece a leer y este harness no cubra sigue siendo un
/// fallo de compilación si se declara `@override`, no un fallo silencioso en
/// runtime.
class FakeChatProvider extends ChangeNotifier implements ChatProvider {
  FakeChatProvider({
    List<ConversacionModel>? conversaciones,
    List<MensajeModel>? mensajes,
    this.isLoading = false,
    this.error,
  }) : _conversaciones = conversaciones ?? const [],
       _mensajes = mensajes ?? const [];

  final List<ConversacionModel> _conversaciones;
  final List<MensajeModel> _mensajes;

  @override
  final bool isLoading;
  @override
  final String? error;

  @override
  List<ConversacionModel> get conversaciones => _conversaciones;
  @override
  List<MensajeModel> get mensajesActuales => _mensajes;

  /// Registro de llamadas, para poder afirmar que la UI **no** dispara
  /// trabajo de red de más (ver Task 11, el `FutureBuilder` en `build`).
  final List<String> llamadas = [];

  @override
  void inicializarMensajes(String conversacionId) =>
      llamadas.add('inicializarMensajes:$conversacionId');
  @override
  void inicializarConversaciones(String userId, bool isMecanico) =>
      llamadas.add('inicializarConversaciones:$userId:$isMecanico');
  @override
  Future<void> marcarComoLeidos(
    String conversacionId,
    bool isMecanico,
    String userId,
  ) async => llamadas.add('marcarComoLeidos:$conversacionId');
  @override
  Future<void> setTypingStatus(String conversacionId, String? userId) async =>
      llamadas.add('setTypingStatus:$conversacionId:$userId');

  /// Sin beneficios por defecto: `CotizacionChatCard._cargarBeneficios()`
  /// (Task 10) lo llama en `initState()` cuando `isMe` es verdadero, y sin
  /// este `@override` caía en el `noSuchMethod` genérico, que lanza
  /// `NoSuchMethodError` porque el tipo de retorno declarado es
  /// `Future<List<double>>`, no `dynamic`.
  @override
  Future<List<double>> obtenerBeneficiosCotizacion(String cotizacionId) async {
    llamadas.add('obtenerBeneficiosCotizacion:$cotizacionId');
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Doble de `ReservaProvider`, con la misma política que `FakeChatProvider`.
class FakeReservaProvider extends ChangeNotifier implements ReservaProvider {
  FakeReservaProvider({this.error});
  @override
  final String? error;
  @override
  bool get isLoading => false;

  final List<String> llamadas = [];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    llamadas.add(invocation.memberName.toString());
    return null;
  }
}

UserModel fakeChatUser({
  String id = 'u1',
  String nombre = 'Ana Pérez',
  String rol = 'Propietario',
}) => UserModel(
  idUsuario: id,
  nombreCompleto: nombre,
  correo: 'ana@example.com',
  rol: rol,
  fechaRegistro: DateTime(2026, 1, 1),
  estado: 'activo',
);

/// Factory de [ConversacionModel] con valores por defecto razonables para
/// tests: dos participantes distintos, sin mensajes sin leer y un timestamp
/// fijo (para que las aserciones de formateo de fecha sean deterministas).
ConversacionModel fakeConversacion({
  String id = 'c1',
  String idPropietario = 'u1',
  String idMecanico = 'm1',
  String nombrePropietario = 'Ana Pérez',
  String nombreMecanico = 'Taller Escobar',
  String? idTaller,
  String? idVehiculo,
  String ultimoMensaje = 'Hola, ¿cómo va la reparación?',
  DateTime? ultimoMensajeTs,
  int noLeidosPropietario = 0,
  int noLeidosMecanico = 0,
  String estado = 'activo',
  String? typingId,
}) => ConversacionModel(
  id: id,
  idPropietario: idPropietario,
  idMecanico: idMecanico,
  nombrePropietario: nombrePropietario,
  nombreMecanico: nombreMecanico,
  idTaller: idTaller,
  idVehiculo: idVehiculo,
  ultimoMensaje: ultimoMensaje,
  ultimoMensajeTs: ultimoMensajeTs ?? DateTime(2026, 1, 1, 10),
  noLeidosPropietario: noLeidosPropietario,
  noLeidosMecanico: noLeidosMecanico,
  estado: estado,
  typingId: typingId,
);

/// Factory de [MensajeModel] con valores por defecto razonables para tests.
MensajeModel fakeMensaje({
  String id = 'msg1',
  String idRemitente = 'u1',
  String contenido = 'Hola',
  String tipo = 'texto',
  Map<String, dynamic>? metadata,
  DateTime? timestamp,
  String estado = 'enviado',
  String? urlArchivo,
  bool isDeleted = false,
  int? duracionSegundos,
}) => MensajeModel(
  id: id,
  idRemitente: idRemitente,
  contenido: contenido,
  tipo: tipo,
  metadata: metadata,
  timestamp: timestamp ?? DateTime(2026, 1, 1, 10),
  estado: estado,
  urlArchivo: urlArchivo,
  isDeleted: isDeleted,
  duracionSegundos: duracionSegundos,
);

/// Monta [widget] con el tema de AutoDoc, l10n en español y los tres
/// providers que el módulo lee, en un viewport de [width] × [height].
///
/// El `locale` fijo en `es` no es cosmético: el módulo formatea fechas con
/// `DateFormat('dd MMM yyyy', 'es')` y sin la delegación cargada esas
/// llamadas lanzan `LocaleDataException`.
Future<void> pumpChatWidget(
  WidgetTester tester,
  Widget widget, {
  required double width,
  double height = 900,
  Brightness brightness = Brightness.light,
  UserModel? user,
  FakeChatProvider? chatProvider,
  FakeReservaProvider? reservaProvider,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<UserProfileProvider>.value(
          value: FakeUserProfileProvider(user: user),
        ),
        ChangeNotifierProvider<AuthSessionProvider>.value(
          value: _fakeAuthSessionProvider(),
        ),
        ChangeNotifierProvider<ChatProvider>.value(
          value: chatProvider ?? FakeChatProvider(),
        ),
        ChangeNotifierProvider<ReservaProvider>.value(
          value: reservaProvider ?? FakeReservaProvider(),
        ),
      ],
      child: MaterialApp(
        theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: widget),
      ),
    ),
  );
  await tester.pump();
}
