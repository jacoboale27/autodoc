import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/utils/reserva_acciones.dart';

void main() {
  group('calcularAccionesReserva (invariante: quien propone no resuelve)', () {
    const userIdPropietario = 'user-prop';
    const userIdMecanico = 'user-mec';

    test('en estado pendiente, el proponente (propietario) NO puede aceptar ni cotizar ni rechazar ni reprogramar', () {
      final acciones = calcularAccionesReserva(
        estado: 'pendiente',
        idProponente: userIdPropietario,
        currentUserId: userIdPropietario,
        isMecanico: false,
      );

      expect(acciones.puedeAceptar, isFalse);
      expect(acciones.puedeCotizarYAceptar, isFalse);
      expect(acciones.puedeRechazar, isFalse);
      expect(acciones.puedeReprogramar, isFalse);
      expect(acciones.puedeCancelar, isTrue);
    });

    test('en estado pendiente, la contraparte (mecánico) SI puede cotizar y aceptar, rechazar y reprogramar', () {
      final acciones = calcularAccionesReserva(
        estado: 'pendiente',
        idProponente: userIdPropietario,
        currentUserId: userIdMecanico,
        isMecanico: true,
      );

      expect(acciones.puedeAceptar, isFalse);
      expect(acciones.puedeCotizarYAceptar, isTrue);
      expect(acciones.puedeRechazar, isTrue);
      expect(acciones.puedeReprogramar, isTrue);
      expect(acciones.puedeCancelar, isTrue);
    });

    test('en estado pendiente tras reprogramación del mecánico, el mecánico NO puede resolver', () {
      final acciones = calcularAccionesReserva(
        estado: 'pendiente',
        idProponente: userIdMecanico,
        currentUserId: userIdMecanico,
        isMecanico: true,
      );

      expect(acciones.puedeAceptar, isFalse);
      expect(acciones.puedeCotizarYAceptar, isFalse);
      expect(acciones.puedeRechazar, isFalse);
      expect(acciones.puedeReprogramar, isFalse);
      expect(acciones.puedeCancelar, isTrue);
    });

    test('en estado pendiente tras reprogramación del mecánico, el propietario SI puede aceptar o reprogramar', () {
      final acciones = calcularAccionesReserva(
        estado: 'pendiente',
        idProponente: userIdMecanico,
        currentUserId: userIdPropietario,
        isMecanico: false,
      );

      expect(acciones.puedeAceptar, isTrue);
      expect(acciones.puedeCotizarYAceptar, isFalse);
      expect(acciones.puedeRechazar, isTrue);
      expect(acciones.puedeReprogramar, isTrue);
      expect(acciones.puedeCancelar, isTrue);
    });

    test('en estado confirmada, ambas partes solo pueden cancelar con rastro', () {
      final accionesProp = calcularAccionesReserva(
        estado: 'confirmada',
        idProponente: userIdPropietario,
        currentUserId: userIdPropietario,
        isMecanico: false,
      );
      expect(accionesProp.puedeCancelar, isTrue);
      expect(accionesProp.puedeAceptar, isFalse);

      final accionesMec = calcularAccionesReserva(
        estado: 'confirmada',
        idProponente: userIdPropietario,
        currentUserId: userIdMecanico,
        isMecanico: true,
      );
      expect(accionesMec.puedeCancelar, isTrue);
      expect(accionesMec.puedeAceptar, isFalse);
    });

    test('en estado terminal (rechazada, cancelada, completada), no hay acciones activas', () {
      for (final estado in ['rechazada', 'cancelada', 'cancelada_por_propietario', 'cancelada_por_taller', 'completada']) {
        final acciones = calcularAccionesReserva(
          estado: estado,
          idProponente: userIdPropietario,
          currentUserId: userIdMecanico,
          isMecanico: true,
        );
        expect(acciones.puedeAceptar, isFalse);
        expect(acciones.puedeCotizarYAceptar, isFalse);
        expect(acciones.puedeRechazar, isFalse);
        expect(acciones.puedeReprogramar, isFalse);
        expect(acciones.puedeCancelar, isFalse);
      }
    });

    test('estadoCancelacionSegunRol devuelve sufijo según rol', () {
      expect(estadoCancelacionSegunRol(isMecanico: true), 'cancelada_por_taller');
      expect(estadoCancelacionSegunRol(isMecanico: false), 'cancelada_por_propietario');
    });
  });
}
