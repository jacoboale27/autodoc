import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';

import 'package:autodoc/core/models/vehicle_model.dart';
import 'package:autodoc/core/providers/notification_center_provider.dart';
import 'package:autodoc/core/providers/session_reset.dart';
import 'package:autodoc/features/chat/data/models/reserva_model.dart';
import 'package:autodoc/features/chat/data/repositories/chat_repository.dart';
import 'package:autodoc/features/chat/presentation/providers/chat_provider.dart';
import 'package:autodoc/features/chat/presentation/providers/reserva_provider.dart';
import 'package:autodoc/features/dashboard/presentation/providers/alert_provider.dart';

import '../../helpers/test_helpers.mocks.dart';

/// Espera a que [predicate] sea verdadero escuchando [provider], en vez de
/// asumir cuantos microtasks tarda `fake_cloud_firestore` en emitir el
/// primer snapshot de un stream recien suscrito.
Future<void> _waitUntil(
  Listenable provider,
  bool Function() predicate, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  if (predicate()) return;
  final completer = Completer<void>();
  void listener() {
    if (predicate() && !completer.isCompleted) completer.complete();
  }

  provider.addListener(listener);
  try {
    await completer.future.timeout(timeout);
  } finally {
    provider.removeListener(listener);
  }
}

void main() {
  // ReservaProvider() (sin inyeccion de repositorio disponible, ver mas
  // abajo) toca FirebaseFirestore.instance en su propio inicializador de
  // campo, lo que lanza sin una app de Firebase registrada.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
  });

  test('clearUserScopedProviders vacia todos los providers con estado por '
      'usuario y cancela sus suscripciones activas', () async {
    await Firebase.initializeApp();
    final fakeFirestore = FakeFirebaseFirestore();

    // --- AlertProvider: fetchAlerts es un fetch puntual (Future), no un
    // stream; se siembra esperando su propio Future. ---
    final vehicle = VehicleModel(
      idVehiculo: 'v1',
      idPropietario: 'owner-1',
      placa: 'ABC-123',
      marca: 'Toyota',
      modelo: 'Corolla',
      kilometrajeActual: 10000,
    );
    await fakeFirestore.collection('alertas').add({
      'id_vehiculo': 'v1',
      'estado': 'Pendiente',
      'titulo': 'SOAT vencido',
      'descripcion': 'Tu SOAT vencio hace 5 dias',
    });
    final alertas = AlertProvider(
      firestore: fakeFirestore,
      storage: MockFirebaseStorage(),
    );
    await alertas.fetchAlerts('v1', vehicle);
    expect(
      alertas.alerts,
      isNotEmpty,
      reason: 'sanity check: la siembra debe quedar cargada',
    );

    // --- ChatProvider: streamConversaciones es un stream real contra
    // FakeFirebaseFirestore, inyectado via ChatRepository. ---
    await fakeFirestore.collection('conversaciones').add({
      'id_propietario': 'owner-1',
      'id_mecanico': 'mec-1',
      'nombre_propietario': 'Owner',
      'nombre_mecanico': 'Taller',
      'ultimo_mensaje': 'Hola',
      'ultimo_mensaje_ts': Timestamp.fromDate(DateTime(2026, 1, 1)),
    });
    final chat = ChatProvider(
      repository: ChatRepository(firestore: fakeFirestore),
    );
    chat.inicializarConversaciones('owner-1', false);
    await _waitUntil(chat, () => chat.conversaciones.isNotEmpty);

    // --- NotificationCenterProvider: mismo patron de stream. ---
    await fakeFirestore
        .collection('notificaciones')
        .doc('owner-1')
        .collection('items')
        .add({
          'tipo': 'sistema',
          'titulo': 'Bienvenido',
          'body': 'Gracias por registrarte',
          'leida': false,
          'timestamp': Timestamp.fromDate(DateTime(2026, 1, 1)),
        });
    final notis = NotificationCenterProvider(firestore: fakeFirestore);
    notis.initialize('owner-1');
    await _waitUntil(notis, () => notis.notifications.isNotEmpty);

    // --- ReservaProvider: ReservaRepository (a diferencia de
    // ChatRepository/AlertProvider/NotificationCenterProvider) no acepta
    // un FirebaseFirestore inyectado: usa `FirebaseFirestore.instance`
    // directo en su propio campo. No hay forma honesta de sembrarlo
    // contra un fake sin ampliar el alcance de esta tarea a esa clase, asi
    // que este es el unico de los cuatro providers que usa un seed
    // @visibleForTesting en vez de su API publica real.
    final reservas = ReservaProvider();
    reservas.debugSeedReservas([
      ReservaModel(
        id: 'r1',
        idConversacion: 'c1',
        idPropietario: 'owner-1',
        idMecanico: 'mec-1',
        idVehiculo: 'v1',
        idTaller: 'taller-1',
        fechaHoraPropuesta: DateTime(2026, 1, 1),
        tipoServicio: 'Cambio de aceite',
        fechaCreacion: DateTime(2026, 1, 1),
      ),
    ]);
    expect(
      reservas.reservas,
      isNotEmpty,
      reason: 'sanity check: la siembra debe quedar cargada',
    );

    clearUserScopedProviders(
      alertas: alertas,
      chat: chat,
      reservas: reservas,
      notificaciones: notis,
    );

    expect(alertas.alerts, isEmpty);
    expect(chat.conversaciones, isEmpty);
    expect(reservas.reservas, isEmpty);
    expect(notis.notifications, isEmpty);

    // La limpieza no vale solo por vaciar la lista una vez: si la
    // suscripcion del usuario saliente sigue viva, el siguiente snapshot
    // la vuelve a poblar igual. Se agregan documentos nuevos despues de
    // clear() y se comprueba que NO llegan.
    await fakeFirestore.collection('conversaciones').add({
      'id_propietario': 'owner-1',
      'id_mecanico': 'mec-1',
      'nombre_propietario': 'Owner',
      'nombre_mecanico': 'Taller',
      'ultimo_mensaje': 'Otro mensaje tras cerrar sesion',
      'ultimo_mensaje_ts': Timestamp.fromDate(DateTime(2026, 1, 2)),
    });
    await fakeFirestore
        .collection('notificaciones')
        .doc('owner-1')
        .collection('items')
        .add({
          'tipo': 'sistema',
          'titulo': 'Otra',
          'body': 'Otra notificacion tras cerrar sesion',
          'leida': false,
          'timestamp': Timestamp.fromDate(DateTime(2026, 1, 2)),
        });
    // Deja correr los microtasks pendientes: si la suscripcion seguia
    // viva, este es el momento en que repoblaria las listas.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(
      chat.conversaciones,
      isEmpty,
      reason:
          'clear() debe cancelar _conversacionesSub, no solo vaciar la '
          'lista una vez',
    );
    expect(
      notis.notifications,
      isEmpty,
      reason:
          'clear() debe cancelar _subscription, no solo vaciar la lista '
          'una vez',
    );
  });

  test('clear() es seguro de llamar dos veces seguidas, incluso sin haber '
      'iniciado ninguna suscripcion', () async {
    await Firebase.initializeApp();

    final alertas = AlertProvider(
      firestore: FakeFirebaseFirestore(),
      storage: MockFirebaseStorage(),
    );
    final chat = ChatProvider(
      repository: ChatRepository(firestore: FakeFirebaseFirestore()),
    );
    final reservas = ReservaProvider();
    final notis = NotificationCenterProvider(
      firestore: FakeFirebaseFirestore(),
    );

    expect(() => alertas.clear(), returnsNormally);
    expect(() => alertas.clear(), returnsNormally);
    expect(() => chat.clear(), returnsNormally);
    expect(() => chat.clear(), returnsNormally);
    expect(() => reservas.clear(), returnsNormally);
    expect(() => reservas.clear(), returnsNormally);
    expect(() => notis.clear(), returnsNormally);
    expect(() => notis.clear(), returnsNormally);
  });
}
