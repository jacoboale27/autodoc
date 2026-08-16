import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/features/chat/data/models/conversacion_model.dart';
import 'package:autodoc/features/chat/data/models/mensaje_model.dart';
import 'package:autodoc/features/chat/presentation/pages/chat_screen.dart';
import 'package:autodoc/features/chat/presentation/widgets/chat_bubble.dart';
import '../../../../support/chat_harness.dart';
import '../../../../support/responsive_harness.dart';

MensajeModel _msg(String texto, {String de = 'u1'}) => MensajeModel(
  id: 'm-$texto'.substring(0, 8),
  idRemitente: de,
  contenido: texto,
  tipo: 'texto',
  timestamp: DateTime(2026, 8, 11),
  estado: 'visto',
);

ConversacionModel _conv() => ConversacionModel(
  id: 'c1',
  idPropietario: 'u1',
  idMecanico: 'm1',
  nombrePropietario: 'Ana Pérez',
  nombreMecanico: 'Taller Escobar',
  ultimoMensaje: 'ok',
  ultimoMensajeTs: DateTime(2026, 8, 11),
  noLeidosPropietario: 0,
  noLeidosMecanico: 0,
);

FakeChatProvider _provider() => FakeChatProvider(
  conversaciones: [_conv()],
  mensajes: [
    _msg(
      'Hola, necesito una revisión completa de frenos, y también '
      'cambio de aceite y filtro de aire si es posible el jueves.',
    ),
    _msg('Claro, le confirmo disponibilidad.', de: 'm1'),
  ],
);

void main() {
  // ChatScreen consulta FirebaseFirestore.instance.collection('usuarios')
  // en el FutureBuilder del AppBar cuando hay un receptorId no vacío (ver
  // _futureNombreReceptor). setupFirebaseCoreMocks() + Firebase.initializeApp()
  // registran una app Firebase "[DEFAULT]" falsa por canal de método para que
  // ese getter no lance síncronamente en build(); la llamada real a `.get()`
  // que dispara después solo genera un error async capturado por el propio
  // FutureBuilder, no un crash de build. Mismo patrón que
  // dashboard_screen_vehicle_fetch_test.dart.
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  testWidgets('las burbujas usan ChatBubble', (tester) async {
    await Firebase.initializeApp();
    await pumpChatWidget(
      tester,
      const ChatScreen(conversacionId: 'c1'),
      width: 375,
      chatProvider: _provider(),
      user: fakeChatUser(),
    );
    expect(find.byType(ChatBubble), findsNWidgets(2));
  });

  testWidgets('a 1440 px ninguna burbuja supera el ancho de lectura', (
    tester,
  ) async {
    await Firebase.initializeApp();
    await pumpChatWidget(
      tester,
      const ChatScreen(conversacionId: 'c1'),
      width: 1440,
      chatProvider: _provider(),
      user: fakeChatUser(),
    );
    for (final element in find.byType(ChatBubble).evaluate()) {
      expect(
        tester.getSize(find.byElementPredicate((e) => e == element)).width,
        lessThanOrEqualTo(AppBreakpoints.maxReadingWidth),
      );
    }
  });

  testWidgets('no desborda en ningún ancho auditado, en ambos temas', (
    tester,
  ) async {
    await Firebase.initializeApp();
    for (final width in kAuditWidths) {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        await pumpChatWidget(
          tester,
          const ChatScreen(conversacionId: 'c1'),
          width: width,
          brightness: brightness,
          chatProvider: _provider(),
          user: fakeChatUser(),
        );
        expectNoOverflow(tester);
      }
    }
  });

  testWidgets('cada mensaje se anuncia con su autor', (tester) async {
    await Firebase.initializeApp();
    await pumpChatWidget(
      tester,
      const ChatScreen(conversacionId: 'c1'),
      width: 375,
      chatProvider: _provider(),
      user: fakeChatUser(),
    );
    expect(find.bySemanticsLabel(RegExp(r'^Tú:')), findsWidgets);
    expect(find.bySemanticsLabel(RegExp(r'^Taller Escobar:')), findsWidgets);
  });

  testWidgets('un rebuild del provider no relanza la consulta del receptor', (
    tester,
  ) async {
    await Firebase.initializeApp();
    final provider = _provider();
    await pumpChatWidget(
      tester,
      const ChatScreen(conversacionId: 'c1'),
      width: 375,
      chatProvider: provider,
      user: fakeChatUser(),
    );
    // Se compara la identidad del `Future` (no un conteo de widgets, que
    // resulta ambiguo con FutureBuilder<Object?>): si se construyera dentro
    // de build(), cada notificación del provider (incluido el estado
    // "escribiendo", que cambia cada 2 s) dispararía un get() nuevo a
    // Firestore, y el future dejaría de ser `identical()` entre builds.
    final state = tester.state(find.byType(ChatScreen));
    final futureInicial = (state as dynamic).nombreReceptorFuture;
    provider.notifyListeners();
    await tester.pump();
    expect(
      identical((state as dynamic).nombreReceptorFuture, futureInicial),
      isTrue,
    );
  });
}
