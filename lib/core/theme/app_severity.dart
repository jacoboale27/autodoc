import 'package:flutter/material.dart';
import 'package:autodoc/core/models/alert_model.dart';
import 'package:autodoc/core/models/maintenance_task_model.dart';
import 'package:autodoc/core/theme/app_colors.dart';

/// Estilo visual de un nivel de severidad: color, icono y etiqueta.
///
/// Siempre lleva icono. Comunicar severidad solo con color deja fuera a quien
/// no distingue rojo de ámbar, que es alrededor del 8 % de los hombres.
@immutable
class AppSeverityStyle {
  final Color color;
  final IconData icon;
  final String label;

  const AppSeverityStyle({
    required this.color,
    required this.icon,
    required this.label,
  });
}

/// Fuente única del mapeo severidad → estilo en AutoDoc.
///
/// Antes este mapeo estaba escrito cuatro veces en el módulo dashboard, y una
/// de las cuatro (`alerts_screen`, justo la pantalla dedicada a las alertas)
/// usaba `Colors.red` / `Colors.amber[700]` en vez de los tokens de marca.
class AppSeverity {
  AppSeverity._();

  /// Estilo para el estado de una tarea de mantenimiento.
  ///
  /// Las etiquetas se pasan desde fuera para que este fichero no dependa de
  /// `AppLocalizations` y siga siendo testeable sin montar un widget.
  static AppSeverityStyle forStatus(
    MaintenanceStatus status,
    AppColors colors, {
    required String optimalLabel,
    required String preventiveLabel,
    required String criticalLabel,
  }) {
    return switch (status) {
      MaintenanceStatus.critical => AppSeverityStyle(
        color: colors.error,
        icon: Icons.error_rounded,
        label: criticalLabel,
      ),
      MaintenanceStatus.preventive => AppSeverityStyle(
        color: colors.warning,
        icon: Icons.warning_rounded,
        label: preventiveLabel,
      ),
      MaintenanceStatus.optimal => AppSeverityStyle(
        color: colors.secondary,
        icon: Icons.check_circle_rounded,
        label: optimalLabel,
      ),
    };
  }

  /// Estilo para el vencimiento de un documento, según los días que faltan.
  ///
  /// Los tramos (vencido / < 30 días / resto) son los que ya usaba
  /// `vehicle_profile_screen`; aquí solo se centralizan.
  static AppSeverityStyle forExpiry(
    int daysRemaining,
    AppColors colors, {
    required String expiredLabel,
    required String soonLabel,
    required String okLabel,
  }) {
    if (daysRemaining < 0) {
      return AppSeverityStyle(
        color: colors.error,
        icon: Icons.error_outline,
        label: expiredLabel,
      );
    }
    if (daysRemaining < 30) {
      return AppSeverityStyle(
        color: colors.warning,
        icon: Icons.warning_amber_rounded,
        label: soonLabel,
      );
    }
    return AppSeverityStyle(
      color: colors.secondary,
      icon: Icons.verified_user_outlined,
      label: okLabel,
    );
  }

  /// Severidad de una alerta de mantenimiento.
  ///
  /// `initiate_service_screen` pintaba alta y media con distinto color pero
  /// **el mismo icono**: con protanopia eran la misma tarjeta.
  static AppSeverityStyle forAlertPriority(
    AlertPriority prioridad,
    AppColors colors, {
    required String altaLabel,
    required String mediaLabel,
    required String bajaLabel,
  }) => switch (prioridad) {
    AlertPriority.high => AppSeverityStyle(
      color: colors.error,
      icon: Icons.error_rounded,
      label: altaLabel,
    ),
    AlertPriority.medium => AppSeverityStyle(
      color: colors.warning,
      icon: Icons.warning_rounded,
      label: mediaLabel,
    ),
    AlertPriority.low => AppSeverityStyle(
      color: colors.secondary,
      icon: Icons.info_rounded,
      label: bajaLabel,
    ),
  };
}
