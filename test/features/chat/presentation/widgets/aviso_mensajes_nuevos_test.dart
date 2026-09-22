// Observaciones del 2026-09-18 (Inge): «Agregar notificaciones de mensajes en
// pantalla». En la web un mensaje nuevo no avisaba de ninguna forma si no se
// estaba en la lista de chats.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/features/chat/data/repositories/chat_repository.dart';
import 'package:autodoc/features/chat/presentation/providers/chat_provider.dart';
import 'package:autodoc/features/chat/presentation/widgets/aviso_mensajes_nuevos.dart';

import '../../../../support/chat_harness.dart';

Future<void> _sembrarConversacion(FakeFirebaseFirestore db, String id) {
  return db.collection('conversaciones').doc(id).set({
    'id': id,
    'id_propietario': 'u1',
    'id_mecanico': 'm1',
    'nombre_propietario': 'Ana Pérez',
    'nombre_mecanico': 'Taller Escobar',
    'ultimo_mensaje': 'Chat iniciado',
    'ultimo_mensaje_ts': Timestamp.fromDate(DateTime(2026, 9, 18, 9)),
    'no_leidos_propietario': 0,
    'no_leidos_mecanico': 0,
  });
}

Future<void> _llegaMensaje(FakeFirebaseFirestore db, String id, String texto) {
  return db.collection('conversaciones').doc(id).update({
    'ultimo_mensaje': texto,
    'ultimo_mensaje_ts': Timestamp.fromDate(DateTime(2026, 9, 18, 10)),
    'no_leidos_propietario': FieldValue.increment(1),
  });
}

/// La entrada/salida del aviso es un `AnimatedSwitcher`: el hijo saliente
/// sigue en el árbol hasta un frame DESPUÉS de terminar su animación.
Future<void> _asentar(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump();
}

void main() {
  late FakeFirebaseFirestore db;
  late ChatProvider chat;
  late List<String> abiertas;

  Future<void> montar(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<UserProfileProvider>.value(
            value: FakeUserProfileProvider(user: fakeChatUser(id: 'u1')),
          ),
          ChangeNotifierProvider<ChatProvider>.value(value: chat),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => AvisoMensajesNuevos(
            onAbrirConversacion: abiertas.add,
            duracion: const Duration(seconds: 3),
            child: child!,
          ),
          home: const Scaffold(body: Text('otra pantalla')),
        ),
      ),
    );
    // Primer frame: abre la bandeja; segundo: llega la primera lectura.
    await tester.pump();
    await tester.pump();
  }

  setUp(() async {
    db = FakeFirebaseFirestore();
    await _sembrarConversacion(db, 'c1');
    chat = ChatProvider(repository: ChatRepository(firestore: db));
    abiertas = [];
  });

  testWidgets('abre la bandeja sola y avisa de un mensaje nuevo', (
    tester,
  ) async {
    await montar(tester);
    expect(find.byKey(const Key('aviso_mensaje_nuevo')), findsNothing);

    await _llegaMensaje(db, 'c1', '¿A qué hora paso por el carro?');
    await _asentar(tester);

    expect(find.byKey(const Key('aviso_mensaje_nuevo')), findsOneWidget);
    expect(find.text('Taller Escobar'), findsOneWidget);
    expect(find.text('¿A qué hora paso por el carro?'), findsOneWidget);

    await tester.tap(find.text('¿A qué hora paso por el carro?'));
    await _asentar(tester);
    expect(abiertas, ['c1']);
    expect(find.byKey(const Key('aviso_mensaje_nuevo')), findsNothing);
  });

  testWidgets('se oculta solo pasado un rato', (tester) async {
    await montar(tester);
    await _llegaMensaje(db, 'c1', 'Hola');
    await _asentar(tester);
    expect(find.byKey(const Key('aviso_mensaje_nuevo')), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await _asentar(tester);
    expect(find.byKey(const Key('aviso_mensaje_nuevo')), findsNothing);
  });

  testWidgets('no avisa de la conversación que ya se tiene abierta', (
    tester,
  ) async {
    await montar(tester);
    chat.abrirConversacion('c1', lectorId: 'u1', lectorEsMecanico: false);

    await _llegaMensaje(db, 'c1', 'Hola');
    await _asentar(tester);

    expect(find.byKey(const Key('aviso_mensaje_nuevo')), findsNothing);
  });

  testWidgets('lo que ya estaba sin leer al entrar no se anuncia', (
    tester,
  ) async {
    await db.collection('conversaciones').doc('c1').update({
      'no_leidos_propietario': 3,
      'ultimo_mensaje': 'viejo',
    });
    await montar(tester);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('aviso_mensaje_nuevo')), findsNothing);
  });

  testWidgets('la insignia cuenta los mensajes sin leer', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<UserProfileProvider>.value(
            value: FakeUserProfileProvider(user: fakeChatUser(id: 'u1')),
          ),
          ChangeNotifierProvider<ChatProvider>.value(value: chat),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: IconoConMensajesSinLeer(
              route: '/chat_list',
              icono: Icon(Icons.chat),
            ),
          ),
        ),
      ),
    );
    chat.inicializarConversacionesSiHaceFalta('u1', false);
    await tester.pump();
    expect(find.byType(Badge), findsNothing);

    await _llegaMensaje(db, 'c1', 'Hola');
    await _llegaMensaje(db, 'c1', 'Hola otra vez');
    await tester.pump();
    expect(find.byType(Badge), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });
}
