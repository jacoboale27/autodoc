import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:autodoc/core/models/vehicle_model.dart';
import 'package:autodoc/core/utils/ui_utils.dart';
import 'package:autodoc/features/mechanic/presentation/providers/reparacion_provider.dart';

/// Único lugar que decide a dónde lleva tocar un vehículo siendo mecánico:
/// a la ficha pública (sin ticket vigente, A3/B2) o a `InitiateServiceScreen`
/// (ya hay un ticket vigente, en cualquier estado desde `pendiente_recepcion`
/// — `cancelado` cuenta como "no hay ticket": ver
/// `ReparacionProvider.buscarReparacionActiva`).
///
/// "Buscar vehículo" y el chat lo llaman igual: si cada entrada decide por su
/// cuenta, una de las dos se queda atrás — fue exactamente lo que pasó (A3/B2
/// solo se había corregido en `vehicle_search_screen.dart`, y el chat nunca
/// se tocó).
///
/// Usa `ReparacionProvider`, no `ReparacionRepository` directo: es el único
/// provider que `main.dart` registra para este dominio
/// (`ChangeNotifierProvider(create: (_) => ReparacionProvider())`), y es el
/// patrón que ya sigue el resto del módulo (`InitiateServiceScreen`,
/// `ReparacionesKanbanScreen`).
///
/// El `try`/`catch` cubre a los tres puntos que llaman a esta función
/// (`vehicle_search_screen.dart` x2, `vehiculo_chat_card.dart`): antes de
/// esto, un fallo de red o de permisos en la consulta dejaba un tap sin
/// ningún efecto visible — ni snackbar, ni navegación, nada — que se lee
/// como una app rota, sobre todo en un taller con mala señal.
Future<void> abrirVehiculoComoMecanico(
  BuildContext context,
  VehicleModel vehiculo,
  String idTaller,
) async {
  String? idReparacion;
  try {
    idReparacion = await context
        .read<ReparacionProvider>()
        .buscarReparacionActiva(
          idVehiculo: vehiculo.idVehiculo,
          idTaller: idTaller,
        );
  } catch (e) {
    if (!context.mounted) return;
    UiUtils.showErrorSnackbar(
      context,
      'No se pudo comprobar el estado de este vehículo. Revisa tu conexión '
      'e intenta de nuevo.',
    );
    return;
  }

  if (!context.mounted) return;
  if (idReparacion == null) {
    context.go('/vehiculo_publico/${vehiculo.idVehiculo}', extra: vehiculo);
  } else {
    context.go('/initiate_service/$idReparacion', extra: vehiculo);
  }
}
