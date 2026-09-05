import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:autodoc/core/providers/auth_session_provider.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/features/chat/data/models/conversacion_model.dart';
import 'package:autodoc/features/chat/presentation/pages/chat_screen.dart';
import 'package:autodoc/features/chat/presentation/providers/chat_provider.dart';
import 'package:autodoc/features/chat/presentation/providers/reserva_provider.dart';
import 'package:autodoc/l10n/app_localizations.dart';

import '../../../../support/chat_harness.dart';

/// Tarea 10, C3 — Step 4 del brief: "hacer tocables el avatar y el nombre en
/// chat_screen.dart" y navegar a `/perfil_publico/:userId`.
///
/// Se monta un `GoRouter` real minúsculo (solo las dos rutas que este flujo
/// necesita) en vez del `MaterialApp` con `home:` de `pumpChatWidget`,
/// porque `context.push` exige un `GoRouter` ancestro — `pumpChatWidget` no
/// provee uno y no hace falta tocarlo por esto, ya que ningún otro test de
/// este archivo ejercita esta navegación.
ConversacionModel _conv() => ConversacionModel(
  id: 'c1',
  idPropietario: 'u1',
  idMecanico: 'm1',
  nombrePropietario: 'Ana Pérez',
  nombreMecanico: 'Taller Escobar',
  ultimoMensaje: 'ok',
  ultimoMensajeTs: DateTime(2026, 8, 11),
);

void main() {
  testWidgets('tocar el encabezado navega a /perfil_publico/<receptorId>', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('talleres').doc('m1').set({
      'nombre': 'Taller Escobar Real',
    });

    String? ultimaRuta;
    final router = GoRouter(
      initialLocation: '/chat/c1',
      routes: [
        GoRoute(
          path: '/chat/:id',
          builder: (context, state) =>
              ChatScreen(conversacionId: 'c1', firestore: firestore),
        ),
        GoRoute(
          path: '/perfil_publico/:userId',
          builder: (context, state) {
            ultimaRuta = state.pathParameters['userId'];
            return const Scaffold(body: Text('perfil'));
          },
        ),
      ],
    );

    tester.view.physicalSize = const Size(375, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<UserProfileProvider>.value(
            value: FakeUserProfileProvider(
              user: fakeChatUser(rol: 'Propietario'),
            ),
          ),
          ChangeNotifierProvider<AuthSessionProvider>.value(
            value: _fakeAuthSession(),
          ),
          ChangeNotifierProvider<ChatProvider>.value(
            value: FakeChatProvider(conversaciones: [_conv()]),
          ),
          ChangeNotifierProvider<ReservaProvider>.value(
            value: FakeReservaProvider(),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light,
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const Key('chat_header_perfil_publico')));
    await tester.pumpAndSettle();

    expect(ultimaRuta, 'm1');
    expect(find.text('perfil'), findsOneWidget);
  });
}

AuthSessionProvider _fakeAuthSession() {
  return _FakeAuthSession();
}

class _FakeAuthSession extends ChangeNotifier implements AuthSessionProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  bool get isLoggedIn => true;

  @override
  String get currentUid => 'u1';
}
