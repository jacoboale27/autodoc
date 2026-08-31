// test/features/mechanic/presentation/widgets/mechanic_sidebar_logout_test.dart
//
// `clearSessionFrom` (lib/core/providers/session_reset.dart) existe para
// vaciar TODO el estado por usuario al cerrar sesion -- el mecanismo del
// hallazgo QA §5: sin el, el siguiente usuario que entra sin recargar la
// pagina ve los datos del anterior, y las suscripciones del uid saliente
// siguen vivas.
//
// Estaba cableado solo en 2 de las 6 salidas de sesion de la app. Esta es la
// del rol taller: el unico logout normal de ese rol.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:autodoc/core/models/vehicle_model.dart';
import 'package:autodoc/features/auth/presentation/providers/auth_provider.dart';
import 'package:autodoc/features/chat/data/repositories/chat_repository.dart';
import 'package:autodoc/features/chat/data/repositories/reserva_repository.dart';
import 'package:autodoc/features/chat/presentation/providers/chat_provider.dart';
import 'package:autodoc/features/chat/presentation/providers/reserva_provider.dart';
import 'package:autodoc/features/dashboard/presentation/providers/alert_provider.dart';
import 'package:autodoc/features/mechanic/data/repositories/reparacion_repository.dart';
import 'package:autodoc/features/mechanic/presentation/providers/reparacion_provider.dart';
import 'package:autodoc/features/mechanic/presentation/widgets/mechanic_sidebar.dart';

import '../../../../helpers/test_helpers.mocks.dart';
import '../../../../support/mechanic_harness.dart';

/// `AuthProvider.signOut()` real cae en `FirebaseAuth.instance`. Aqui solo
/// interesa lo que pasa con los providers por usuario, no el cierre real.
///
/// **Implementa** en vez de extender: `AuthProvider()` real construye
/// `AuthService`, que hace `FirebaseAuth.instance` en el inicializador de
/// su campo y lanza sin `Firebase.initializeApp()`. Mismo patron que
/// `FakeUserProfileProvider` en `mechanic_harness.dart`.
class _FakeAuthProvider extends ChangeNotifier implements AuthProvider {
  bool signedOut = false;

  @override
  Future<void> signOut() async {
    signedOut = true;
  }

  @override
  bool get isLoading => false;
  @override
  String? get error => null;
  @override
  bool get needsEmailVerification => false;
  @override
  bool get isEmailPasswordUser => true;
  @override
  Future<bool> signIn(String emailOrUsername, String password) async => true;
  @override
  Future<bool> signInWithGoogle() async => true;
  @override
  Future<bool> register(String email, String password) async => true;
  @override
  Future<bool> sendPasswordReset(String email) async => true;
  @override
  Future<bool> sendEmailVerification() async => true;
  @override
  Future<bool> refreshEmailVerificationStatus() async => true;
  @override
  Future<bool> deleteAccount() async => true;
  @override
  Future<bool> verifyPassword(String password) async => true;
  @override
  Future<void> clearError() async {}
  @override
  Future<void> reloadUser() async {}
}

void main() {
  testWidgets('el logout de MechanicSidebar vacia los providers por usuario', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();

    // --- AlertProvider sembrado (fetch puntual, deterministico). ---
    await firestore.collection('alertas').add({
      'id_vehiculo': 'v1',
      'estado': 'Pendiente',
      'titulo': 'SOAT vencido',
    });
    await firestore.collection('mantenimientos').add({
      'id_vehiculo': 'v1',
      'nombre': 'Cambio de Aceite',
      'ultimo_km': 9000,
      'fecha_ultimo_servicio': Timestamp.fromDate(DateTime(2026, 1, 1)),
      'frecuencia_km': 5000,
      'frecuencia_meses': 6,
    });
    final alertas = AlertProvider(
      firestore: firestore,
      storage: MockFirebaseStorage(),
    );
    await alertas.fetchAlerts(
      'v1',
      VehicleModel(
        idVehiculo: 'v1',
        idPropietario: 'owner-1',
        placa: 'ABC-123',
        marca: 'Toyota',
        modelo: 'Corolla',
        kilometrajeActual: 10000,
      ),
    );
    expect(alertas.alerts, isNotEmpty, reason: 'sanity: siembra cargada');

    // --- ReparacionProvider: suscripcion viva por taller. ---
    await firestore.collection('reparaciones').add({
      'id_vehiculo': 'v1',
      'id_taller': 't1',
      'id_propietario': 'owner-1',
      'placa': 'ABC-123',
      'estado': 'recibido',
      'fecha_creacion': Timestamp.fromDate(DateTime(2026, 1, 1)),
      'fecha_actualizacion': Timestamp.fromDate(DateTime(2026, 1, 1)),
    });
    final reparaciones = ReparacionProvider(
      repository: ReparacionRepository(
        firestore: firestore,
        functions: MockFirebaseFunctions(),
      ),
    );
    reparaciones.watchTaller('t1');
    await tester.pump(const Duration(milliseconds: 50));

    final auth = _FakeAuthProvider();

    await pumpMechanicScreen(
      tester,
      const Scaffold(body: MechanicSidebar()),
      width: 1280,
      extraProviders: [
        // Los ultimos de la lista quedan mas adentro en el arbol, asi que
        // `context.read<T>()` desde la barra encuentra estos y no los del
        // harness.
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider<AlertProvider>.value(value: alertas),
        ChangeNotifierProvider<ReparacionProvider>.value(value: reparaciones),
        ChangeNotifierProvider<ChatProvider>(
          create: (_) =>
              ChatProvider(repository: ChatRepository(firestore: firestore)),
        ),
        ChangeNotifierProvider<ReservaProvider>(
          create: (_) => ReservaProvider(
            repository: ReservaRepository(firestore: firestore),
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(
      reparaciones.reparaciones,
      isNotEmpty,
      reason: 'sanity: la suscripcion del taller esta viva',
    );

    await tester.tap(find.text('Cerrar Sesión'));
    await tester.pump();

    expect(auth.signedOut, isTrue, reason: 'sanity: el logout se ejecuto');
    expect(
      alertas.alerts,
      isEmpty,
      reason:
          'el logout del taller debe llamar a clearSessionFrom: si no, el '
          'siguiente usuario ve las alertas del anterior (hallazgo QA §5)',
    );
    expect(
      reparaciones.reparaciones,
      isEmpty,
      reason:
          'ReparacionProvider mantiene una suscripcion viva por taller y '
          'tiene que entrar en clearUserScopedProviders',
    );
  });
}
