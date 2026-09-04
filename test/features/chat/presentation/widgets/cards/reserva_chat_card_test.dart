import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/core/models/user_model.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/core/widgets/app_status_badge.dart';
import 'package:autodoc/l10n/app_localizations.dart';
import 'package:autodoc/features/chat/presentation/widgets/chat_bubble.dart';
import 'package:autodoc/features/chat/presentation/widgets/chat_card_shell.dart';
import 'package:autodoc/features/chat/presentation/widgets/cards/reserva_chat_card.dart';
import '../../../../../support/chat_harness.dart';
import '../../../../../support/contrast.dart';
import '../../../../../support/responsive_harness.dart';

// UserProfileProvider real construye un UserService que toca
// FirebaseFirestore.instance en su inicializacion, lo que no existe en un
// widget test sin Firebase.initializeApp(). ReservaChatCard solo necesita
// leer userData.rol durante build(), asi que un fake evita esa dependencia
// sin necesitar mocks de Firebase Core (mismo patron que
// reserva_detail_screen_test.dart).
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

/// Regression test for the "Ver detalle" bug: the card used to call
/// `context.push('/reserva_detail', extra: id)`, but the only registered
/// app route is `/reserva_detail/:reservaId` (reads the id from the path,
/// not from `extra`). That mismatch made go_router fall through to its
/// not-found handler.
///
/// This test uses a minimal GoRouter (only the routes ReservaChatCard can
/// navigate to) rather than the full `createAppRouter` from
/// `app_router_test.dart`, since ReservaChatCard doesn't need auth/profile
/// redirect logic — it just needs its real `onPressed` callback exercised
/// and the resulting location observed.
void main() {
  testWidgets(
    'Tapping "Ver detalle" navigates to /reserva_detail/<id>, not the bare path',
    (tester) async {
      String? lastMatchedLocation;

      final router = GoRouter(
        initialLocation: '/chat',
        routes: [
          GoRoute(
            path: '/chat',
            // The card must live inside a route's builder (not
            // MaterialApp.router's top-level `builder`), because that
            // top-level `builder` sits above the Router in the widget tree
            // and GoRouter.of(context)/context.push would not find the
            // GoRouter InheritedWidget from there.
            builder: (context, state) => Scaffold(
              body: ChangeNotifierProvider<UserProfileProvider>.value(
                value: _FakeUserProfileProvider(),
                child: const ReservaChatCard(
                  metadata: {
                    'id_reserva': 'r1',
                    'estado': 'confirmada',
                    'fecha': '2026-08-03T10:00:00.000',
                    'hora': '10:00',
                  },
                  isMe: false,
                  mensajeId: 'm1',
                  conversacionId: 'c1',
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/reserva_detail/:reservaId',
            builder: (context, state) {
              lastMatchedLocation = state.uri.toString();
              return Text('detail:${state.pathParameters['reservaId']}');
            },
          ),
        ],
        // Any navigation that doesn't match a route (e.g. the old buggy
        // '/reserva_detail' with no id segment) ends up here instead.
        errorBuilder: (context, state) {
          lastMatchedLocation = 'ERROR:${state.uri}';
          return const Text('not-found');
        },
      );

      // El filtro de FlutterError.onError que vivía aquí tragaba un
      // desbordamiento de 118 px del Row de cabecera, causado por el ancho
      // fijo de 260 px sin hijos flexibles. La Fase 6 lo eliminó
      // estructuralmente (ChatCardShell), así que el test ya no necesita
      // tapar nada: cualquier desbordamiento debe hacerlo fallar.

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light,
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ver detalle'));
      await tester.pumpAndSettle();

      expect(
        lastMatchedLocation,
        '/reserva_detail/r1',
        reason:
            'Expected navigation to the id-scoped route, but got '
            '"$lastMatchedLocation" — a bare /reserva_detail push (with '
            'extra instead of a path segment) matches no route and falls '
            'through to errorBuilder.',
      );
    },
  );

  testWidgets('la cabecera no desborda con el estado de etiqueta más larga', (
    tester,
  ) async {
    // 'Cotización Enviada' es la etiqueta más larga de los cuatro estados.
    await pumpChatWidget(
      tester,
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: ChatBubble(
          isMe: false,
          child: ReservaChatCard(
            metadata: {
              'id_reserva': 'r1',
              'estado': 'cotizada',
              'fecha': '2026-08-20T10:00:00.000',
              'hora': '10:00 AM',
            },
            isMe: false,
            mensajeId: 'm1',
            conversacionId: 'c1',
          ),
        ),
      ),
      width: 320,
    );
    expectNoOverflow(tester);
  });

  testWidgets('no desborda en ningún ancho auditado, en ambos temas y roles', (
    tester,
  ) async {
    for (final width in kAuditWidths) {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        for (final rol in ['Propietario', 'Mecanico']) {
          await pumpChatWidget(
            tester,
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: ChatBubble(
                isMe: false,
                child: ReservaChatCard(
                  metadata: {
                    'id_reserva': 'r1',
                    'estado': 'pendiente',
                    'fecha': '2026-08-20T10:00:00.000',
                    'hora': '10:00 AM',
                  },
                  isMe: false,
                  mensajeId: 'm1',
                  conversacionId: 'c1',
                ),
              ),
            ),
            width: width,
            brightness: brightness,
            user: fakeChatUser(rol: rol),
          );
          expectNoOverflow(tester);
        }
      }
    }
  });

  testWidgets('el contenido es legible cuando el mensaje es propio', (
    tester,
  ) async {
    await pumpChatWidget(
      tester,
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: ChatBubble(
          isMe: true,
          child: ReservaChatCard(
            metadata: {
              'id_reserva': 'r1',
              'estado': 'confirmada',
              'fecha': '2026-08-20T10:00:00.000',
              'hora': '10:00 AM',
            },
            isMe: true,
            mensajeId: 'm1',
            conversacionId: 'c1',
          ),
        ),
      ),
      width: 375,
    );
    final context = tester.element(find.byType(ChatCardShell));
    final colors = context.appColors;
    final fecha = tester.widget<Text>(find.text('20 ago 2026'));
    final color =
        fecha.style?.color ??
        DefaultTextStyle.of(
          tester.element(find.text('20 ago 2026')),
        ).style.color!;
    expect(
      contrastRatio(color, colors.surface),
      greaterThanOrEqualTo(4.5),
      reason:
          'Con isMe=true la fecha se pintaba blanca sobre tarjeta '
          'blanca: 1,00:1.',
    );
  });

  testWidgets(
    'la tarjeta dice "te propusieron" cuando la reserva pendiente la propuso la contraparte',
    (tester) async {
      await pumpChatWidget(
        tester,
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: ChatBubble(
            isMe: false,
            child: ReservaChatCard(
              metadata: {
                'id_reserva': 'r1',
                'estado': 'pendiente',
                'fecha': '2026-08-20T10:00:00.000',
                'hora': '10:00 AM',
              },
              isMe: false,
              mensajeId: 'm1',
              conversacionId: 'c1',
            ),
          ),
        ),
        width: 375,
      );
      expect(find.text('Te propusieron esta fecha'), findsOneWidget);
      expect(find.text('Aceptar'), findsOneWidget); // correcto, no es un bug
    },
  );

  testWidgets(
    'la tarjeta dice "propusiste" y no ofrece Aceptar cuando la reserva pendiente la propuso el propio usuario',
    (tester) async {
      await pumpChatWidget(
        tester,
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: ChatBubble(
            isMe: true,
            child: ReservaChatCard(
              metadata: {
                'id_reserva': 'r1',
                'estado': 'pendiente',
                'fecha': '2026-08-20T10:00:00.000',
                'hora': '10:00 AM',
              },
              isMe: true,
              mensajeId: 'm1',
              conversacionId: 'c1',
            ),
          ),
        ),
        width: 375,
      );
      expect(
        find.text('Propusiste esta fecha — espera respuesta'),
        findsOneWidget,
      );
      expect(find.text('Aceptar'), findsNothing);
    },
  );

  testWidgets('el estado se pinta con AppStatusBadge', (tester) async {
    await pumpChatWidget(
      tester,
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: ChatBubble(
          isMe: false,
          child: ReservaChatCard(
            metadata: {'id_reserva': 'r1', 'estado': 'rechazada'},
            isMe: false,
            mensajeId: 'm1',
            conversacionId: 'c1',
          ),
        ),
      ),
      width: 375,
    );
    final badge = tester.widget<AppStatusBadge>(find.byType(AppStatusBadge));
    expect(badge.type, AppStatusType.error);
  });
}
