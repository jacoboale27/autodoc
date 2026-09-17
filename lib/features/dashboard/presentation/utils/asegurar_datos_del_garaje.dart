import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/features/dashboard/presentation/providers/alert_provider.dart';
import 'package:autodoc/features/dashboard/presentation/providers/vehicle_provider.dart';

/// Garantiza que el garaje y sus alertas esten cargados, vengas de donde
/// vengas.
///
/// El dashboard llama a `fetchVehicles` al montarse, asi que navegando por
/// las pestañas todo funciona. Lo que no funcionaba era entrar SIN pasar por
/// el: un F5 sobre `/garage` o `/alerts`, o un enlace directo, monta la
/// pantalla con los providers recien construidos. El garaje pintaba «No
/// tienes vehiculos» con tres sembrados y las alertas «Selecciona un vehiculo
/// primero».
///
/// Los dos `asegurar*` son idempotentes, asi que llamar a esto desde cada
/// pantalla no multiplica lecturas: la primera que llegue carga y las demas
/// se enganchan a la misma carga o no hacen nada.
///
/// Sin sesion resuelta todavia no hace nada: no es un fallo, es que
/// `UserProfileProvider` aun no tiene el perfil. La pantalla se reconstruye
/// cuando llegue y el llamador vuelve a pasar por aqui.
/// El trabajo va en un `addPostFrameCallback` y no es adorno: llamarlo desde
/// `didChangeDependencies` lo pone DENTRO de la fase de construccion, y
/// `fetchVehicles` arranca con un `notifyListeners()`. Sin el aplazamiento
/// revienta con «setState() or markNeedsBuild() called during build», que es
/// exactamente lo que paso al escribir el primer test de esto. El dashboard
/// ya usaba este mismo patron por la misma razon.
void asegurarDatosDelGaraje(BuildContext context) {
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    if (!context.mounted) return;

    final uid = context.read<UserProfileProvider>().userData?.idUsuario;
    if (uid == null) return;

    final vehiculos = context.read<VehicleProvider>();
    await vehiculos.asegurarVehiculosCargados(uid);

    if (!context.mounted) return;
    await context.read<AlertProvider>().asegurarAlertasCargadas(
      vehiculos.vehicles,
    );
  });
}
