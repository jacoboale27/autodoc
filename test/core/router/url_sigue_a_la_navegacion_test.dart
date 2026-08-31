// test/core/router/url_sigue_a_la_navegacion_test.dart
//
// Hallazgo §2.14 del recorrido QA del 2026-08-28: al abrir ciertas pantallas
// la barra de direcciones se queda en la ruta anterior, asi que F5 devuelve
// al usuario a la pantalla previa y esas vistas no se pueden enlazar.
//
// Estos tests miran lo unico que un widget test puede mirar de eso: el `uri`
// que el enrutador reporta despues de la interaccion, que es exactamente el
// valor que go_router entrega al navegador para pintar la barra. La
// comprobacion final (abrir, mirar la barra, F5) sigue siendo manual: el
// hallazgo es literalmente sobre el navegador.
//
// Dos causas distintas con el mismo sintoma, una por grupo de tests:
//
//   A. El registro NUNCA navega: `_toggleMode` cambiaba `_isLoginMode` con
//      `setState`, asi que no habia navegacion que pudiera mover la URL. En
//      toda la app no existia ni una llamada que fuera a `/register`.
//
//   B. `context.push` no toca la URL. En go_router 17.2.2,
//      `RouteMatchList.push()` (match.dart:621-632) devuelve
//      `copyWith(matches: ...)`: copia la lista de pantallas y **conserva el
//      `uri` anterior**. `go` en cambio reconstruye la lista desde la URL
//      nueva, asi que la barra la sigue.

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodoc/core/models/user_model.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/features/chat/data/models/conversacion_model.dart';

import '../../support/chat_harness.dart' hide FakeUserProfileProvider;
import '../../support/router_harness.dart';

UserModel _mecanicoPendiente() => UserModel(
  idUsuario: 'uid-1',
  nombreCompleto: 'Taller De Prueba',
  correo: 'taller@autodoc.app',
  rol: 'Mecanico',
  fechaRegistro: DateTime.utc(2024, 3, 15),
  estado: 'pendiente',
);

/// Texto del boton de envio de `AuthScreen`: «Iniciar Sesión» en modo login,
/// «Registrarse» en modo alta. Es la forma estable de comprobar en que modo
/// esta el formulario — el enlace de cambio de modo es un `RichText`, que
/// `find.text` no encuentra.
String _textoDelBotonDeEnvio(WidgetTester tester) {
  final boton = tester.widget<AppButton>(
    find.byKey(const ValueKey('auth-submit')),
  );
  return boton.text;
}

void main() {
  // `ChatScreen` consulta `FirebaseFirestore.instance` en el FutureBuilder de
  // su AppBar (`_futureNombreReceptor`), asi que sin una app Firebase
  // registrada revienta en `build()` — y este test necesita que la pantalla
  // destino construya para poder leer la URL a la que se llego. Mismo patron
  // que `chat_screen_layout_test.dart`: la app falsa evita el crash sincrono;
  // la lectura real falla en async y la captura el propio FutureBuilder.
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  group('Causa A — el registro navega de verdad', () {
    testWidgets('pasar de login a registro lleva la URL a /register', (
      tester,
    ) async {
      final router = await pumpAppAt(tester, '/login');
      expect(urlDe(router), '/login', reason: 'punto de partida');

      await tester.tap(find.byKey(const ValueKey('auth-mode-switch')));
      await tester.pumpAndSettle();

      expect(
        urlDe(router),
        '/register',
        reason:
            'el enlace "¿No tienes cuenta?" cambiaba `_isLoginMode` con '
            'setState y no navegaba, asi que la URL se quedaba en /login y '
            'un F5 devolvia al login',
      );
      // La URL sola no basta: si el enrutador reutilizara el State, la barra
      // cambiaria y el formulario no. Se afirman las dos mitades.
      expect(_textoDelBotonDeEnvio(tester), 'Registrarse');
    });

    testWidgets('volver de registro a login lleva la URL a /login', (
      tester,
    ) async {
      final router = await pumpAppAt(tester, '/register');
      expect(urlDe(router), '/register', reason: 'punto de partida');

      await tester.tap(find.byKey(const ValueKey('auth-mode-switch')));
      await tester.pumpAndSettle();

      expect(urlDe(router), '/login');
    });

    testWidgets('/register entra directamente en el formulario de alta', (
      tester,
    ) async {
      // Guarda de la trampa que este cambio podria haber introducido:
      // `_isLoginMode` solo se lee de `widget.isLogin` en `initState`. Si el
      // enrutador reutilizara el State entre /login y /register, la URL
      // cambiaria pero el formulario no. Se sostiene porque
      // `buildPageWithFadeThrough` fija `key: state.pageKey`, distinta por
      // ruta; este test es lo que hace que siga siendo cierto.
      await pumpAppAt(tester, '/register');

      expect(find.byKey(const ValueKey('auth-mode-switch')), findsOneWidget);
      expect(
        _textoDelBotonDeEnvio(tester),
        'Registrarse',
        reason:
            'entrar por URL a /register tiene que abrir el formulario de '
            'alta, no el de login',
      );
    });
  });

  group('Causa B — push no movia la URL', () {
    testWidgets('abrir una conversacion lleva la URL a /chat/<id>', (
      tester,
    ) async {
      await Firebase.initializeApp();
      final router = await pumpAppAt(
        tester,
        '/chat_list',
        sesionIniciada: true,
        asentarConSettle: false,
        chat: FakeChatProvider(
          conversaciones: [
            ConversacionModel(
              id: 'conv-abc',
              idPropietario: 'u-1',
              idMecanico: 'm1',
              nombrePropietario: 'Usuario De Prueba',
              nombreMecanico: 'Taller Escobar',
              ultimoMensaje: 'Le confirmo la cita.',
              ultimoMensajeTs: DateTime.utc(2026, 8, 11),
            ),
          ],
        ),
      );
      expect(urlDe(router), '/chat_list', reason: 'punto de partida');

      final conversacion = find.text('Taller Escobar');
      await tester.ensureVisible(conversacion);
      await asentarRuta(tester);
      await tester.tap(conversacion);
      await asentarRuta(tester);

      expect(
        urlDe(router),
        '/chat/conv-abc',
        reason:
            'con context.push se abria la conversacion pero la barra seguia '
            'diciendo /chat_list, asi que un F5 devolvia a la lista y la '
            'conversacion no se podia enlazar',
      );
    });

    testWidgets(
      'completar verificacion lleva la URL a /workshop_verification',
      (tester) async {
        final router = await pumpAppAt(
          tester,
          '/mechanic_pending',
          usuario: _mecanicoPendiente(),
          sesionIniciada: true,
        );
        expect(urlDe(router), '/mechanic_pending', reason: 'punto de partida');

        final boton = find.text('Completar verificación');
        await tester.ensureVisible(boton);
        await tester.pumpAndSettle();
        await tester.tap(boton);
        await tester.pumpAndSettle();

        expect(
          urlDe(router),
          '/workshop_verification',
          reason:
              'con context.push la pantalla cambiaba pero el uri seguia siendo '
              'el de /mechanic_pending (go_router match.dart:621-632: push '
              'copia `matches` y conserva `uri`)',
        );
      },
    );
  });
}
