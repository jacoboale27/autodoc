import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/features/dashboard/presentation/providers/vehicle_provider.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';

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

    return Container(
      height: 400,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selecciona un Vehículo',
            style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.bold),
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
                  return Center(
                    child: Text(
                      'No tienes vehículos registrados.',
                      style: TextStyle(color: colors.textSecondary),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: vehicles.length,
                  itemBuilder: (context, index) {
                    final vehicle = vehicles[index];
                    return ListTile(
                      leading: Icon(Icons.directions_car, color: colors.primary),
                      title: Text('${vehicle.marca ?? ''} ${vehicle.modelo ?? ''}'),
                      subtitle: Text(vehicle.placa),
                      onTap: () {
                        onSelected({
                          'vehiculo_id': vehicle.idVehiculo,
                          'marca': vehicle.marca ?? '',
                          'modelo': vehicle.modelo ?? '',
                          'anio': vehicle.anio,
                          'placa': vehicle.placa,
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
