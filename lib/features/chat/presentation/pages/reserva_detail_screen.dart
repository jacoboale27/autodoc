import 'package:flutter/material.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';

class ReservaDetailScreen extends StatelessWidget {
  // En la implementación real esto recibiría un ReservaModel
  const ReservaDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? colors.surfaceContainer : colors.surface,
      appBar: AppBar(
        title: const Text('Detalle de Cita'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? Colors.white12 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: colors.warning.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Pendiente de Confirmación',
                          style: TextStyle(
                            color: colors.warning,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Icon(Icons.calendar_month, color: colors.primary),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('Servicio', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('Mantenimiento Preventivo', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                  const Divider(height: 32),
                  
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Fecha', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text('Lun, 14 Jul 2026', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Hora', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text('10:00 AM', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  
                  Text('Vehículo', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('Toyota Corolla 2020', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                  Text('P123ABC', style: TextStyle(color: colors.textSecondary)),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.check),
                label: const Text('Aceptar Cita', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  foregroundColor: colors.error,
                ),
                child: const Text('Rechazar / Reprogramar', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
