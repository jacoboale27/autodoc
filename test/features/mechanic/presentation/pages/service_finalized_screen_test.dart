// Observaciones del 2026-09-19 (captura: «No se pudo enviar la solicitud de
// reseña. Inténtalo de nuevo en un momento.»). La solicitud buscaba la
// conversación de ESE vehículo y, si no existía —lo normal cuando el cliente
// escribió desde el directorio, sin coche—, intentaba CREAR otra, que las
// reglas no dejan al taller.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:autodoc/features/chat/data/repositories/chat_repository.dart';
import 'package:autodoc/features/chat/presentation/providers/chat_provider.dart';
import 'package:autodoc/features/mechanic/presentation/pages/service_finalized_screen.dart';

import '../../../../support/mechanic_harness.dart';

const _args = ServiceFinalizedArgs(
  idPropietario: 'p1',
  idVehiculo: 'v1',
  tallerId: 't1',
  tallerNombre: 'Taller Escobar',
  rutaContinuar: '/mechanic_dashboard',
);

Future<FakeFirebaseFirestore> _montar(
  WidgetTester tester, {
  bool conConversacion = true,
  String? idTallerPropietario,
}) async {
  final db = FakeFirebaseFirestore();
  if (conConversacion) {
    // Abierta desde el directorio: SIN vehículo.
    await db.collection('conversaciones').doc('c1').set({
      'id': 'c1',
      'id_propietario': 'p1',
      'id_mecanico': 't1',
      'nombre_propietario': 'Oscar',
      'nombre_mecanico': 'Taller Escobar',
      'ultimo_mensaje': 'Hola',
      'ultimo_mensaje_ts': Timestamp.fromDate(DateTime(2026, 9, 19)),
    });
  }
  await pumpMechanicScreen(
    tester,
    const ServiceFinalizedScreen(args: _args),
    width: 1024,
    location: '/service_finalized',
    user: fakeTaller(
      id: idTallerPropietario == null ? 't1' : 'empleado1',
      idTallerPropietario: idTallerPropietario,
    ),
    disableAnimations: true,
    rutasExtra: const ['/mechanic_dashboard'],
    extraProviders: [
      ChangeNotifierProvider<ChatProvider>(
        create: (_) => ChatProvider(repository: ChatRepository(firestore: db)),
      ),
    ],
  );
  await tester.pump();
  return db;
}

Future<void> _pedir(WidgetTester tester) async {
  await tester.tap(find.text('Enviar solicitud de reseña'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('usa la conversación que ya hay, aunque no sea de ese coche', (
    tester,
  ) async {
    final db = await _montar(tester);
    await _pedir(tester);

    final mensajes = await db
        .collection('conversaciones')
        .doc('c1')
        .collection('mensajes')
        .get();
    expect(mensajes.docs.map((d) => d.data()['tipo']), ['review_card']);
    final conversaciones = await db.collection('conversaciones').get();
    expect(conversaciones.docs, hasLength(1), reason: 'no crea otra');
    expect(find.text('Solicitud enviada'), findsOneWidget);
  });

  testWidgets('sin conversación con el cliente lo dice y no crea ninguna', (
    tester,
  ) async {
    final db = await _montar(tester, conConversacion: false);
    await _pedir(tester);

    expect(
      find.textContaining('todavía no tiene un chat contigo'),
      findsOneWidget,
    );
    expect((await db.collection('conversaciones').get()).docs, isEmpty);
    expect(find.text('Enviar solicitud de reseña'), findsOneWidget);
  });

  testWidgets(
    'un empleado no ve el botón: el chat es de la cuenta del taller',
    (tester) async {
      await _montar(tester, idTallerPropietario: 't1');
      expect(find.text('Enviar solicitud de reseña'), findsNothing);
      expect(find.byKey(const Key('resenia_solo_taller')), findsOneWidget);
    },
  );
}
