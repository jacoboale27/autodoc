import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:autodoc/core/constants/firestore_collections.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/widgets/app_status_badge.dart';
import 'package:autodoc/features/chat/presentation/pages/reserva_detail_screen.dart';
import '../../../../support/chat_harness.dart';
import '../../../../support/responsive_harness.dart';

Future<FakeFirebaseFirestore> _conReserva({String estado = 'pendiente'}) async {
  final db = FakeFirebaseFirestore();
  await db.collection(FirestoreCollections.reservas).doc('r1').set({
    'id_conversacion': 'c1',
    'id_propietario': 'u1',
    'id_mecanico': 'm1',
    'id_vehiculo': 'v1',
    'id_taller': 'm1',
    // Propuesta por el mecánico: el usuario de prueba (propietario 'u1') no
    // es el proponente, así que sí ve los botones de acción (invariante del
    // hallazgo #4: quien propone no resuelve).
    'id_proponente': 'm1',
    'fecha_hora_propuesta': DateTime(2026, 8, 20, 10, 30),
    'tipo_servicio': 'Cambio de aceite y filtros',
    'estado': estado,
    'fecha_creacion': DateTime(2026, 8, 11),
  });
  return db;
}

void main() {
  testWidgets('no desborda en ningún ancho auditado', (tester) async {
    final db = await _conReserva();
    for (final width in kAuditWidths) {
      await pumpChatWidget(
        tester,
        ReservaDetailScreen(reservaId: 'r1', firestore: db),
        width: width,
        user: fakeChatUser(),
      );
      await tester.pumpAndSettle();
      expectNoOverflow(tester);
    }
  });

  testWidgets('acota el contenido a 720 px en pantallas grandes', (
    tester,
  ) async {
    final db = await _conReserva();
    await pumpChatWidget(
      tester,
      ReservaDetailScreen(reservaId: 'r1', firestore: db),
      width: 1440,
      user: fakeChatUser(),
    );
    await tester.pumpAndSettle();
    final ancho = tester.getSize(find.byType(SingleChildScrollView)).width;
    expect(ancho, lessThanOrEqualTo(720));
  });

  testWidgets('el estado usa AppStatusBadge, no un chip de color crudo', (
    tester,
  ) async {
    for (final estado in ['pendiente', 'confirmada', 'rechazada', 'cotizada']) {
      final db = await _conReserva(estado: estado);
      await pumpChatWidget(
        tester,
        ReservaDetailScreen(reservaId: 'r1', firestore: db),
        width: 375,
        user: fakeChatUser(),
      );
      await tester.pumpAndSettle();
      expect(
        find.byType(AppStatusBadge),
        findsOneWidget,
        reason: 'estado=$estado',
      );
    }
  });

  testWidgets('los cuatro botones de acción son AppButton', (tester) async {
    final db = await _conReserva();
    await pumpChatWidget(
      tester,
      ReservaDetailScreen(reservaId: 'r1', firestore: db),
      width: 375,
      user: fakeChatUser(),
    );
    await tester.pumpAndSettle();
    // Aceptar cita / Reprogramar / Rechazar / Cancelar
    expect(find.byType(AppButton), findsNWidgets(4));
    expect(find.byType(ElevatedButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
  });
}
