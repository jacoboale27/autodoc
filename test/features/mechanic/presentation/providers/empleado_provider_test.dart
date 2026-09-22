import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:autodoc/features/mechanic/data/repositories/empleado_repository.dart';
import 'package:autodoc/features/mechanic/presentation/providers/empleado_provider.dart';

import '../../../../helpers/test_helpers.mocks.dart';
import '../../../../support/fake_functions.dart';

void main() {
  test('watchTaller puebla empleados desde el repositorio', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = EmpleadoRepository(firestore: firestore);
    await firestore
        .collection('talleres')
        .doc('t1')
        .collection('empleados')
        .doc('e1')
        .set({
          'id_taller_propietario': 't1',
          'nombre_completo': 'A',
          'correo': 'a@x.com',
          'activo': true,
        });

    final provider = EmpleadoProvider(repository: repo);
    provider.watchTaller('t1');
    await Future.delayed(Duration.zero);

    expect(provider.empleados.length, 1);
  });

  test(
    'crearEmpleado transiciona isLoading y expone error cuando el callable falla',
    () async {
      // No hay MockHttpsCallable generado en test_helpers.mocks.dart (solo
      // FirebaseFunctions), asi que se limita la cobertura al camino de error:
      // basta con que httpsCallable() lance para ejercitar el try/catch del
      // provider sin necesitar simular una HttpsCallableResult real.
      final firestore = FakeFirebaseFirestore();
      final repo = EmpleadoRepository(firestore: firestore);
      final mockFunctions = MockFirebaseFunctions();
      when(
        mockFunctions.httpsCallable('crearEmpleadoTaller'),
      ).thenThrow(Exception('network error'));

      final provider = EmpleadoProvider(
        repository: repo,
        functions: mockFunctions,
      );

      final loadingStates = <bool>[];
      provider.addListener(() => loadingStates.add(provider.isLoading));

      final result = await provider.crearEmpleado(
        correo: 'a@x.com',
        password: '123456',
        nombreCompleto: 'A',
        rol: 'Mecanico',
      );

      expect(result, isNull);
      expect(provider.isLoading, false);
      expect(provider.error, isNotNull);
      expect(loadingStates.first, true);
      expect(loadingStates.last, false);
    },
  );

  group('correo que ya tiene cuenta (2026-09-19)', _grupoInvitaciones);
}

// Observaciones del 2026-09-19, punto 4: con un correo que ya tenía cuenta el
// alta fallaba con «Ese dato ya existe». Ahora el servidor dice qué hizo, y
// cuando no puede, POR QUÉ.
void _grupoInvitaciones() {
  EmpleadoProvider conServidor(Object? Function(String, dynamic) alLlamar) =>
      EmpleadoProvider(
        repository: EmpleadoRepository(firestore: FakeFirebaseFirestore()),
        functions: FakeFunctions(alLlamar: alLlamar),
      );

  Future<ResultadoAltaEmpleado?> crear(EmpleadoProvider p) => p.crearEmpleado(
    correo: 'oscar@example.com',
    password: '123456',
    nombreCompleto: 'Oscar Isaac',
    rol: 'Mecanico',
  );

  test('distingue crear, reactivar e invitar', () async {
    expect(
      await crear(conServidor((_, _) => {'idEmpleado': 'e1'})),
      ResultadoAltaEmpleado.creado,
      reason: 'una función anterior no manda `resultado`',
    );
    expect(
      await crear(conServidor((_, _) => {'resultado': 'reactivado'})),
      ResultadoAltaEmpleado.reactivado,
    );
    expect(
      await crear(
        conServidor((_, _) => {'resultado': 'reactivado_con_su_contrasena'}),
      ),
      ResultadoAltaEmpleado.reactivadoConSuContrasena,
      reason: 'a quien entró por invitación no se le cambió la contraseña',
    );
    expect(
      await crear(conServidor((_, _) => {'resultado': 'invitado'})),
      ResultadoAltaEmpleado.invitado,
    );
  });

  test(
    'cuando el servidor no puede, se lee su motivo y no «Ese dato ya existe»',
    () async {
      final p = conServidor(
        (_, _) => throw FirebaseFunctionsException(
          code: 'already-exists',
          message: 'Ese correo ya es de un empleado de otro taller.',
        ),
      );
      expect(await crear(p), isNull);
      expect(p.error, 'Ese correo ya es de un empleado de otro taller.');
    },
  );

  test('el cupo de invitaciones del taller también se lee tal cual', () async {
    // `resource-exhausted` lo redacta `crearEmpleadoTaller` para una persona:
    // con el genérico, el taller no sabría que puede arreglarlo retirando
    // alguna invitación.
    final p = conServidor(
      (_, _) => throw FirebaseFunctionsException(
        code: 'resource-exhausted',
        message:
            'Tu taller tiene 20 invitaciones sin responder. Espera a que las '
            'contesten o retira alguna antes de invitar a más personas.',
      ),
    );
    expect(await crear(p), isNull);
    expect(p.error, contains('20 invitaciones sin responder'));
  });

  test(
    'un error sin motivo redactado sigue sin enseñar detalle técnico',
    () async {
      final p = conServidor(
        (_, _) => throw FirebaseFunctionsException(
          code: 'internal',
          message: 'TypeError: cannot read property x of undefined',
        ),
      );
      expect(await crear(p), isNull);
      expect(p.error, isNot(contains('TypeError')));
    },
  );

  test(
    'responder la invitación llama al callable con el taller y la decisión',
    () async {
      final llamadas = <dynamic>[];
      final p = conServidor((nombre, params) {
        llamadas.add([nombre, params]);
        return {'resultado': 'aceptada'};
      });
      expect(
        await p.responderInvitacion(idTaller: 't1', aceptar: true),
        isTrue,
      );
      expect(llamadas.single, [
        'responderInvitacionEmpleo',
        {'idTaller': 't1', 'aceptar': true},
      ]);
    },
  );

  test(
    'si aceptar no se puede, el motivo del servidor llega a la pantalla',
    () async {
      final p = conServidor(
        (_, _) => throw FirebaseFunctionsException(
          code: 'failed-precondition',
          message: 'Tu cuenta tiene vehículos registrados.',
        ),
      );
      expect(
        await p.responderInvitacion(idTaller: 't1', aceptar: true),
        isFalse,
      );
      expect(p.error, 'Tu cuenta tiene vehículos registrados.');
    },
  );
}
