import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/theme/app_estado_cuenta.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/router/app_router.dart'
    show estadosMecanicoAprobado;

/// Regresión de los dos vocabularios de `estado`.
///
/// `AdminService.aprobarUsuario` escribe `'activo'`; `aprobarTaller` y
/// `reactivarTaller` escriben `'aprobado'`. La UI de administración solo
/// reconocía `'activo'`, así que una cuenta aprobada como taller se pintaba en
/// rojo y el menú seguía ofreciendo "Aprobar" sobre algo ya aprobado. Los
/// filtros por estado tampoco la encontraban.
void main() {
  // Paleta construida a mano y no `AppTheme.light.extension<AppColors>()`:
  // AppTheme arma su TextTheme con GoogleFonts, que intenta descargar la fuente
  // y revienta con "There is no current invoker" al ejecutarse fuera de una
  // zona de test. Aquí solo hacen falta los tres colores del semáforo.
  const colors = AppColors(
    primary: AppPalette.lightPrimary,
    secondary: AppPalette.lightSecondary,
    surface: AppPalette.lightSurface,
    surfaceContainer: AppPalette.lightSurfaceContainer,
    error: AppPalette.lightError,
    warning: AppPalette.lightWarning,
    success: AppPalette.lightSuccess,
    textPrimary: AppPalette.lightTextPrimary,
    textSecondary: AppPalette.lightTextSecondary,
    onPrimary: AppPalette.lightOnPrimary,
    onSecondary: AppPalette.lightOnSecondary,
    onError: AppPalette.lightOnError,
    surfaceVariant: AppPalette.lightSurfaceVariant,
    outline: AppPalette.lightOutline,
    shimmerBase: AppPalette.lightShimmerBase,
    shimmerHighlight: AppPalette.lightShimmerHighlight,
  );

  group('parse', () {
    test('los dos sinónimos de aprobada significan lo mismo', () {
      expect(AppEstadoCuenta.parse('activo'), EstadoCuenta.aprobada);
      expect(AppEstadoCuenta.parse('aprobado'), EstadoCuenta.aprobada);
    });

    test('tolera mayúsculas y espacios', () {
      expect(AppEstadoCuenta.parse('  Aprobado '), EstadoCuenta.aprobada);
      expect(AppEstadoCuenta.parse('ACTIVO'), EstadoCuenta.aprobada);
      expect(AppEstadoCuenta.parse('Pendiente'), EstadoCuenta.pendiente);
    });

    test('null, vacío y desconocido son pendiente, no aprobada', () {
      // El default conservador: sin acceso hasta que un admin se pronuncie.
      // Coincide con el default de firestore.rules y de UserModel.fromMap.
      for (final raw in [null, '', '   ', 'loquesea']) {
        expect(
          AppEstadoCuenta.parse(raw),
          EstadoCuenta.pendiente,
          reason: '$raw',
        );
      }
    });

    test('suspendido y rechazado no se confunden con pendiente', () {
      expect(AppEstadoCuenta.parse('suspendido'), EstadoCuenta.suspendida);
      expect(AppEstadoCuenta.parse('rechazado'), EstadoCuenta.rechazada);
    });
  });

  group('admiteAprobacion', () {
    test(
      'NO ofrece aprobar una cuenta ya aprobada por cualquiera de los dos nombres',
      () {
        // Este es el bug reportado: 'aprobado' seguía ofreciendo "Aprobar".
        expect(AppEstadoCuenta.admiteAprobacion('aprobado'), isFalse);
        expect(AppEstadoCuenta.admiteAprobacion('activo'), isFalse);
      },
    );

    test('sí ofrece aprobar una cuenta pendiente', () {
      expect(AppEstadoCuenta.admiteAprobacion('pendiente'), isTrue);
      expect(AppEstadoCuenta.admiteAprobacion(null), isTrue);
    });

    test('no ofrece aprobar una suspendida (esa se reactiva)', () {
      expect(AppEstadoCuenta.admiteAprobacion('suspendido'), isFalse);
    });
  });

  group('semáforo', () {
    test('verde para aprobada por cualquiera de los dos nombres', () {
      expect(AppEstadoCuenta.style('activo', colors).color, colors.success);
      expect(AppEstadoCuenta.style('aprobado', colors).color, colors.success);
    });

    test('ámbar para pendiente', () {
      expect(AppEstadoCuenta.style('pendiente', colors).color, colors.warning);
      expect(AppEstadoCuenta.style(null, colors).color, colors.warning);
    });

    test('rojo para suspendida y rechazada', () {
      expect(AppEstadoCuenta.style('suspendido', colors).color, colors.error);
      expect(AppEstadoCuenta.style('rechazado', colors).color, colors.error);
    });

    test('cada estado lleva icono propio, no solo color', () {
      final iconos = <IconData>{
        for (final e in ['activo', 'pendiente', 'suspendido', 'rechazado'])
          AppEstadoCuenta.style(e, colors).icon,
      };
      expect(
        iconos.length,
        4,
        reason: 'el color no puede ser el único portador del estado',
      );
    });

    test('la etiqueta de los dos sinónimos es la misma', () {
      expect(
        AppEstadoCuenta.style('aprobado', colors).label,
        AppEstadoCuenta.style('activo', colors).label,
      );
    });
  });

  test('el guard del router usa exactamente este conjunto', () {
    // Si divergen, un taller aprobado se queda atrapado en /mechanic_pending o
    // al revés. Son el mismo objeto, no dos listas que hay que sincronizar.
    expect(estadosMecanicoAprobado, same(AppEstadoCuenta.aprobados));
    for (final estado in estadosMecanicoAprobado) {
      expect(AppEstadoCuenta.esAprobada(estado), isTrue, reason: estado);
    }
  });
}
