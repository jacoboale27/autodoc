import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/core/constants/firestore_collections.dart';
import 'package:autodoc/core/models/vehicle_model.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/utils/role_utils.dart';
import 'package:autodoc/core/utils/ui_utils.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/features/mechanic/presentation/navegacion_vehiculo.dart';

class VehiculoChatCard extends StatelessWidget {
  final Map<String, dynamic> metadata;
  final bool isMe;

  /// Inyectable para pruebas de widget (`FakeFirebaseFirestore`); por
  /// defecto usa la instancia real. Mismo patrón que `CotizacionChatCard`.
  final FirebaseFirestore? firestore;

  const VehiculoChatCard({
    super.key,
    required this.metadata,
    required this.isMe,
    this.firestore,
  });

  /// El mecánico (quien recibe la tarjeta, nunca quien la envía: es el
  /// propietario compartiendo SU vehículo) es el único que puede tocar "Ver
  /// vehículo": es el mismo gating de A3/B2 que "Buscar vehículo"
  /// (`abrirVehiculoComoMecanico`), y esta tarjeta es la otra entrada — sin
  /// pasar por ahí, esta ruta se quedaría atrás igual que le pasó a
  /// `vehicle_search_screen.dart` antes de la Tarea 5.
  Future<void> _verVehiculo(BuildContext context, String idVehiculo) async {
    final tallerId =
        context.read<UserProfileProvider>().userData?.idTallerEfectivo ?? '';
    final DocumentSnapshot<Map<String, dynamic>> doc;
    try {
      doc = await (firestore ?? FirebaseFirestore.instance)
          .collection(FirestoreCollections.vehiculos)
          .doc(idVehiculo)
          .get();
    } catch (e) {
      // Sin este catch, un fallo de red/permisos al leer el vehículo dejaba
      // el tap en "Ver vehículo" sin ningún efecto — ni snackbar, ni
      // navegación — que se lee como un botón roto.
      if (!context.mounted) return;
      UiUtils.showErrorSnackbar(
        context,
        'No se pudo cargar este vehículo. Revisa tu conexión e intenta de '
        'nuevo.',
      );
      return;
    }
    if (!context.mounted) return;
    if (!doc.exists) {
      UiUtils.showErrorSnackbar(context, 'No se encontró este vehículo.');
      return;
    }
    final vehiculo = VehicleModel.fromMap(doc.data()!, doc.id);
    if (!context.mounted) return;
    await abrirVehiculoComoMecanico(context, vehiculo, tallerId);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final String marca = metadata['marca'] ?? 'Marca desconocida';
    final String modelo = metadata['modelo'] ?? 'Modelo desconocido';
    final String anio = metadata['anio']?.toString() ?? 'N/A';
    final String placa = metadata['placa'] ?? 'Sin placa';
    final String? idVehiculo = metadata['id_vehiculo'] as String?;
    final isMecanico = isMechanicRole(
      context.watch<UserProfileProvider>().userData?.rol,
    );
    final mostrarVerVehiculo =
        !isMe && isMecanico && idVehiculo != null && idVehiculo.isNotEmpty;

    final descripcion =
        'Vehículo compartido: $marca $modelo, año $anio, placa $placa';

    final tarjeta = Semantics(
      label: descripcion,
      container: true,
      child: ExcludeSemantics(
        child: Container(
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            color: isMe
                ? colors.primary.withValues(alpha: 0.1)
                : colors.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.outline.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isMe
                      ? colors.primary.withValues(alpha: 0.2)
                      : colors.surfaceContainer,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.directions_car,
                      size: 16,
                      color: isMe ? colors.surface : colors.primary,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Vehículo Compartido',
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isMe ? colors.surface : colors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$marca $modelo',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isMe ? colors.surface : colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Año: $anio',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: isMe
                                  ? colors.surface.withValues(alpha: 0.7)
                                  : colors.textSecondary,
                            ),
                          ),
                        ),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? colors.surface.withValues(alpha: 0.2)
                                  : colors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              placa,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isMe ? colors.surface : colors.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mostrarVerVehiculo) return tarjeta;

    // Fuera de `ExcludeSemantics`: la tarjeta en sí sigue siendo un solo
    // nodo informativo para el lector de pantalla, pero un botón que hace
    // algo no se puede plegar dentro de esa etiqueta — necesita su propio
    // nodo activable, igual que el resto de tarjetas de chat con acciones
    // (`CotizacionChatCard`, `ReservaChatCard`).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        tarjeta,
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: AppButton(
            text: 'Ver vehículo',
            type: AppButtonType.text,
            onPressed: () => _verVehiculo(context, idVehiculo),
          ),
        ),
      ],
    );
  }
}
