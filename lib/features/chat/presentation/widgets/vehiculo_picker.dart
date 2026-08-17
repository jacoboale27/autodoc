import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/features/dashboard/presentation/providers/vehicle_provider.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/widgets/app_empty_state.dart';

class VehiculoPicker extends StatelessWidget {
  final String userId;
  final Function(Map<String, dynamic>) onSelected;

  const VehiculoPicker({
    super.key,
    required this.userId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: colors.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Selecciona un Vehículo',
                style: AppTextStyles.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Consumer<VehicleProvider>(
                  builder: (context, vehicleProvider, child) {
                    final vehicles = vehicleProvider.vehicles;

                    if (vehicleProvider.isLoading && vehicles.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (vehicles.isEmpty) {
                      return const AppEmptyState(
                        title: 'No tienes vehículos registrados.',
                        description:
                            'Agrega un vehículo desde tu garaje para poder '
                            'seleccionarlo aquí.',
                        icon: Icons.directions_car_outlined,
                      );
                    }

                    return ListView.builder(
                      controller: scrollController,
                      itemCount: vehicles.length,
                      itemBuilder: (context, index) {
                        final vehicle = vehicles[index];
                        void seleccionar() {
                          onSelected({
                            'vehiculo_id': vehicle.idVehiculo,
                            'marca': vehicle.marca ?? '',
                            'modelo': vehicle.modelo ?? '',
                            'anio': vehicle.anio,
                            'placa': vehicle.placa,
                          });
                          Navigator.pop(context);
                        }

                        return Semantics(
                          label:
                              '${vehicle.marca ?? ''} ${vehicle.modelo ?? ''}, '
                              'placa ${vehicle.placa}',
                          button: true,
                          excludeSemantics: true,
                          onTap: seleccionar,
                          child: ListTile(
                            leading: Icon(
                              Icons.directions_car,
                              color: colors.primary,
                            ),
                            title: Text(
                              '${vehicle.marca ?? ''} ${vehicle.modelo ?? ''}',
                            ),
                            subtitle: Text(vehicle.placa),
                            onTap: seleccionar,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
