import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:autodoc/core/providers/notification_center_provider.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/features/chat/presentation/providers/chat_provider.dart';
import 'package:autodoc/features/chat/presentation/providers/reserva_provider.dart';
import 'package:autodoc/features/dashboard/presentation/providers/alert_provider.dart';
import 'package:autodoc/features/dashboard/presentation/providers/vehicle_provider.dart';

/// Vacia todo el estado que pertenece a **un** usuario.
///
/// Hasta 2026-08-28 `_signOut` solo llamaba a `AuthProvider.signOut()` y
/// navegaba: los providers seguian en memoria con los datos del usuario
/// saliente hasta la siguiente recarga completa de la pagina.
void clearUserScopedProviders({
  required AlertProvider alertas,
  required ChatProvider chat,
  required ReservaProvider reservas,
  required NotificationCenterProvider notificaciones,
  VehicleProvider? vehiculos,
  UserProfileProvider? perfil,
}) {
  alertas.clear();
  chat.clear();
  reservas.clear();
  notificaciones.clear();
  vehiculos?.clearVehicles();
  perfil?.clearUserData();
}

/// Azucar para llamarlo desde una pantalla.
void clearSessionFrom(BuildContext context) {
  clearUserScopedProviders(
    alertas: context.read<AlertProvider>(),
    chat: context.read<ChatProvider>(),
    reservas: context.read<ReservaProvider>(),
    notificaciones: context.read<NotificationCenterProvider>(),
    vehiculos: context.read<VehicleProvider>(),
    perfil: context.read<UserProfileProvider>(),
  );
}
