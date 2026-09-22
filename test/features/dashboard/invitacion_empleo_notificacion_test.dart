// Observaciones del 2026-09-19, punto 4: «al mecánico no le deja invitar a
// una persona como mecánico». Con un correo que ya tiene cuenta, el taller
// ahora INVITA, y la invitación le llega a esa persona a sus notificaciones
// con dos respuestas. Aquí se prueba ese extremo: que se pueda aceptar y
// rechazar desde la notificación, y que cada respuesta llegue al servidor
// una sola vez.
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:autodoc/core/models/app_notification_model.dart';
import 'package:autodoc/core/providers/notification_center_provider.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/theme/app_theme.dart';
import 'package:autodoc/features/dashboard/presentation/pages/notifications_screen.dart';
import 'package:autodoc/features/mechanic/data/repositories/empleado_repository.dart';
import 'package:autodoc/features/mechanic/presentation/providers/empleado_provider.dart';
import 'package:autodoc/l10n/app_localizations.dart';

import '../../support/fake_functions.dart';
import '../../support/shell_harness.dart';

final _invitacion = AppNotification(
  id: 'n1',
  tipo: 'invitacion_empleo',
  titulo: 'Te invitaron a trabajar en un taller',
  body: 'Taller Escobar te invitó a unirte a su taller como mecánico.',
  timestamp: DateTime(2026, 9, 19),
  metadata: const {
    'id_taller': 't1',
    'nombre_taller': 'Taller Escobar',
    'rol': 'Mecanico',
  },
);

class _Notificaciones extends NotificationCenterProvider {
  _Notificaciones() : super(firestore: FakeFirebaseFirestore());

  final borradas = <String>[];

  @override
  List<AppNotification> get notifications =>
      borradas.contains(_invitacion.id) ? const [] : [_invitacion];

  @override
  Future<void> deleteNotification(String userId, String notificationId) async {
    borradas.add(notificationId);
    notifyListeners();
  }
}

Future<
  ({List<dynamic> llamadas, _Notificaciones notificaciones, GoRouter router})
>
_montar(WidgetTester tester, {Object? Function()? respuesta}) async {
  tester.view.physicalSize = const Size(800, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final llamadas = <dynamic>[];
  final notificaciones = _Notificaciones();
  final empleados = EmpleadoProvider(
    repository: EmpleadoRepository(firestore: FakeFirebaseFirestore()),
    functions: FakeFunctions(
      alLlamar: (nombre, params) {
        llamadas.add([nombre, params]);
        return respuesta?.call() ?? {'resultado': 'ok'};
      },
    ),
  );
  final router = GoRouter(
    initialLocation: '/notifications',
    routes: [
      GoRoute(
        path: '/notifications',
        builder: (_, _) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/mechanic_dashboard',
        builder: (_, _) => const Scaffold(body: Text('panel del taller')),
      ),
    ],
  );
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<NotificationCenterProvider>.value(
          value: notificaciones,
        ),
        ChangeNotifierProvider<UserProfileProvider>.value(
          value: FakeProfileProvider('Propietario'),
        ),
        ChangeNotifierProvider<EmpleadoProvider>.value(value: empleados),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (llamadas: llamadas, notificaciones: notificaciones, router: router);
}

void main() {
  testWidgets('la invitación trae Aceptar y Rechazar', (tester) async {
    await _montar(tester);
    expect(find.text('Te invitaron a trabajar en un taller'), findsOneWidget);
    expect(find.byKey(const Key('invitacion_aceptar_n1')), findsOneWidget);
    expect(find.byKey(const Key('invitacion_rechazar_n1')), findsOneWidget);
  });

  testWidgets('rechazar avisa al servidor una vez y quita la notificación', (
    tester,
  ) async {
    final m = await _montar(tester);
    final rechazar = find.byKey(const Key('invitacion_rechazar_n1'));
    await tester.tap(rechazar);
    await tester.tap(rechazar, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(m.llamadas, [
      [
        'responderInvitacionEmpleo',
        {'idTaller': 't1', 'aceptar': false},
      ],
    ]);
    expect(m.notificaciones.borradas, ['n1']);
    expect(find.text('Rechazaste la invitación.'), findsOneWidget);
    expect(m.router.routeInformationProvider.value.uri.path, '/notifications');
  });

  testWidgets('aceptar pide confirmación: cancelar no manda nada', (
    tester,
  ) async {
    final m = await _montar(tester);
    await tester.tap(find.byKey(const Key('invitacion_aceptar_n1')));
    await tester.pumpAndSettle();
    expect(find.text('Unirte al taller'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(m.llamadas, isEmpty);
    expect(m.notificaciones.borradas, isEmpty);
  });

  testWidgets('aceptar y confirmar une la cuenta al taller y abre su panel', (
    tester,
  ) async {
    final m = await _montar(tester);
    await tester.tap(find.byKey(const Key('invitacion_aceptar_n1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unirme'));
    await tester.pumpAndSettle();

    expect(m.llamadas, [
      [
        'responderInvitacionEmpleo',
        {'idTaller': 't1', 'aceptar': true},
      ],
    ]);
    expect(m.notificaciones.borradas, ['n1']);
    expect(find.text('panel del taller'), findsOneWidget);
  });

  testWidgets(
    'si el servidor se niega, se lee su motivo y la invitación sigue',
    (tester) async {
      final m = await _montar(
        tester,
        respuesta: () => throw FirebaseFunctionsException(
          code: 'failed-precondition',
          message:
              'Tu cuenta tiene vehículos registrados, y una cuenta de taller no '
              'puede verlos.',
        ),
      );
      await tester.tap(find.byKey(const Key('invitacion_aceptar_n1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unirme'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Tu cuenta tiene vehículos'), findsOneWidget);
      expect(m.notificaciones.borradas, isEmpty);
      expect(find.byKey(const Key('invitacion_aceptar_n1')), findsOneWidget);
    },
  );
}
