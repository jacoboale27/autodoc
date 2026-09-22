import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:autodoc/core/models/vehicle_model.dart';

/// A dónde lleva tocar un vehículo siendo mecánico: a su perfil
/// (`VehiclePublicViewScreen`, ruta `/vehiculo_publico/:id`).
///
/// "Buscar vehículo" y la tarjeta de vehículo del chat lo llaman igual: si
/// cada entrada decidiera por su cuenta, una de las dos se quedaría atrás —
/// fue exactamente lo que pasó (A3/B2 solo se había corregido en
/// `vehicle_search_screen.dart`, y el chat nunca se tocó).
///
/// Hasta el 2026-09-19 esta función miraba si había un ticket vigente y, si
/// lo había, saltaba directo a `InitiateServiceScreen`. Las observaciones de
/// ese día pidieron otra cosa: al buscar la placa de un coche con
/// cotizaciones aceptadas, el taller tiene que ver el PERFIL del coche (sus
/// datos, los servicios que ya le hizo, sus cotizaciones y el botón para
/// mandarle otra). Qué enseña ese perfil —solo la ficha pública, la ficha con
/// cita, o el perfil completo con el acceso al servicio en curso— lo decide
/// ahora la propia pantalla, que es la que carga esa relación.
///
/// [idTaller] se conserva por compatibilidad con los llamadores.
Future<void> abrirVehiculoComoMecanico(
  BuildContext context,
  VehicleModel vehiculo,
  String idTaller,
) async {
  // `go` y no `push`: la URL tiene que seguir a la pantalla para que un F5
  // no deje al taller a medias (en go_router 17 `push` conserva el `uri`).
  context.go('/vehiculo_publico/${vehiculo.idVehiculo}', extra: vehiculo);
}
