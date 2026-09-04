import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:autodoc/core/models/vehicle_model.dart';
import 'package:autodoc/features/mechanic/presentation/providers/reparacion_provider.dart';

/// Único lugar que decide a dónde lleva tocar un vehículo siendo mecánico:
/// a la ficha pública (sin ticket aceptado, A3/B2) o a `InitiateServiceScreen`
/// (ya hay un ticket, en cualquier estado desde `pendiente_recepcion`).
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
Future<void> abrirVehiculoComoMecanico(
  BuildContext context,
  VehicleModel vehiculo,
  String idTaller,
) async {
  final idReparacion = await context
      .read<ReparacionProvider>()
      .buscarReparacionActiva(
        idVehiculo: vehiculo.idVehiculo,
        idTaller: idTaller,
      );

  if (!context.mounted) return;
  if (idReparacion == null) {
    context.go('/vehiculo_publico/${vehiculo.idVehiculo}', extra: vehiculo);
  } else {
    context.go('/initiate_service/$idReparacion', extra: vehiculo);
  }
}
