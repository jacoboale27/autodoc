import 'package:flutter/material.dart';
import 'package:autodoc/core/theme/app_colors.dart';

/// Estado de la cuenta de un usuario o taller, normalizado.
///
/// El campo `usuarios/{uid}.estado` es texto libre y por historia acumuló DOS
/// vocabularios para decir lo mismo: `AdminService.aprobarUsuario` escribe
/// `'activo'` mientras que `aprobarTaller` y `reactivarTaller` escriben
/// `'aprobado'`. La UI de administración solo reconocía `'activo'`, así que una
/// cuenta ya aprobada se pintaba en rojo y seguía ofreciendo el botón
/// "Aprobar". Este enum es la única traducción de ese texto libre a un estado
/// con significado.
enum EstadoCuenta {
  /// Registrada pero a la espera de que un administrador la habilite.
  /// Un taller nace aquí (ver `profile_setup_screen.dart`) y no puede operar.
  pendiente,

  /// Habilitada. Cubre tanto `'activo'` como `'aprobado'`.
  aprobada,

  /// Bloqueada por un administrador.
  suspendida,

  /// Denegada explícitamente (`AdminService.rechazarTaller`).
  rechazada,
}

/// Estilo visual de un estado de cuenta: color, icono y etiqueta.
///
/// Siempre lleva icono, por el mismo motivo que [AppSeverityStyle]: el color no
/// puede ser el único portador del significado.
@immutable
class EstadoCuentaStyle {
  final Color color;
  final IconData icon;
  final String label;

  const EstadoCuentaStyle({
    required this.color,
    required this.icon,
    required this.label,
  });
}

/// Fuente única de verdad sobre el campo `estado`.
class AppEstadoCuenta {
  AppEstadoCuenta._();

  /// Valores de `estado` que habilitan a un mecánico/taller a usar la app.
  ///
  /// Espejo exacto de `isMecanico()` en `firestore.rules`
  /// (`getUserData().get('estado', 'pendiente') in ['aprobado', 'activo']`).
  /// `app_router.dart` reexporta este conjunto como `estadosMecanicoAprobado`;
  /// si cambia aquí, cambia el guard del router y la pantalla de espera.
  static const Set<String> aprobados = {'aprobado', 'activo'};

  static const Set<String> suspendidos = {'suspendido'};
  static const Set<String> rechazados = {'rechazado', 'denegado'};

  /// Traduce el texto libre de Firestore a un [EstadoCuenta].
  ///
  /// Cualquier valor desconocido —incluido vacío o ausente— se trata como
  /// [EstadoCuenta.pendiente], que es el default conservador: sin acceso hasta
  /// que un administrador se pronuncie. Coincide con el default de
  /// `firestore.rules` y con `UserModel.fromMap`.
  static EstadoCuenta parse(String? estado) {
    final normalizado = (estado ?? '').trim().toLowerCase();
    if (aprobados.contains(normalizado)) return EstadoCuenta.aprobada;
    if (suspendidos.contains(normalizado)) return EstadoCuenta.suspendida;
    if (rechazados.contains(normalizado)) return EstadoCuenta.rechazada;
    return EstadoCuenta.pendiente;
  }

  static bool esAprobada(String? estado) =>
      parse(estado) == EstadoCuenta.aprobada;

  static bool esPendiente(String? estado) =>
      parse(estado) == EstadoCuenta.pendiente;

  static bool esSuspendida(String? estado) =>
      parse(estado) == EstadoCuenta.suspendida;

  /// ¿Tiene sentido ofrecer "Aprobar" para esta cuenta?
  ///
  /// Solo si está pendiente. Una cuenta ya aprobada se reactiva, no se aprueba;
  /// una suspendida se reactiva. Antes esta decisión era
  /// `estado != 'activo' && estado != 'suspendido'`, que dejaba pasar
  /// `'aprobado'` y por eso el menú ofrecía aprobar lo ya aprobado.
  static bool admiteAprobacion(String? estado) => esPendiente(estado);

  /// Estilo del semáforo: ámbar pendiente, verde aprobada, rojo suspendida o
  /// rechazada.
  static EstadoCuentaStyle style(String? estado, AppColors colors) {
    switch (parse(estado)) {
      case EstadoCuenta.aprobada:
        return EstadoCuentaStyle(
          color: colors.success,
          icon: Icons.check_circle_outline,
          label: 'Activo',
        );
      case EstadoCuenta.pendiente:
        return EstadoCuentaStyle(
          color: colors.warning,
          icon: Icons.hourglass_top_outlined,
          label: 'Pendiente',
        );
      case EstadoCuenta.suspendida:
        return EstadoCuentaStyle(
          color: colors.error,
          icon: Icons.block_outlined,
          label: 'Suspendido',
        );
      case EstadoCuenta.rechazada:
        return EstadoCuentaStyle(
          color: colors.error,
          icon: Icons.cancel_outlined,
          label: 'Rechazado',
        );
    }
  }
}
