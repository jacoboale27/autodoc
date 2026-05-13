import 'package:flutter/material.dart';
import '../../../../core/models/workshop_model.dart';

class TallerAdminCard extends StatelessWidget {
  final WorkshopModel taller;
  final VoidCallback onAprobar;
  final VoidCallback onRechazar;
  final VoidCallback onSuspender;

  const TallerAdminCard({
    super.key,
    required this.taller,
    required this.onAprobar,
    required this.onRechazar,
    required this.onSuspender,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = taller.estado == 'aprobado'
        ? Colors.green
        : taller.estado == 'suspendido'
            ? Colors.red
            : taller.estado == 'rechazado'
                ? Colors.grey
                : Colors.orange;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    taller.nombre,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                _buildStatusChip(taller.estado, statusColor),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildInfoChip(Icons.build_circle_outlined, taller.especialidad ?? 'General'),
                _buildInfoChip(Icons.location_on_outlined, taller.ubicacionMunicipio ?? 'S.S.'),
                _buildInfoChip(Icons.phone_outlined, taller.telefono ?? 'N/A'),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (taller.estado == 'pendiente') ...[
                  TextButton(
                    onPressed: onRechazar,
                    style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
                    child: const Text('Rechazar'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: onAprobar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Aprobar Taller'),
                  ),
                ] else if (taller.estado == 'aprobado') ...[
                  OutlinedButton.icon(
                    onPressed: onSuspender,
                    icon: const Icon(Icons.block_flipped, size: 18),
                    label: const Text('Suspender'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ] else if (taller.estado == 'suspendido') ...[
                  ElevatedButton.icon(
                    onPressed: onAprobar,
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Reactivar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String estado, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        estado.toUpperCase(),
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey[800]),
          ),
        ],
      ),
    );
  }
}
