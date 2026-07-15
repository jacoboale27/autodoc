import 'package:flutter/material.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/features/chat/data/models/reserva_model.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/features/chat/presentation/providers/reserva_provider.dart';
import 'package:autodoc/core/providers/user_session_provider.dart';
import 'package:intl/intl.dart';

class ReservaDetailScreen extends StatefulWidget {
  final ReservaModel reserva;
  
  const ReservaDetailScreen({super.key, required this.reserva});

  @override
  State<ReservaDetailScreen> createState() => _ReservaDetailScreenState();
}

class _ReservaDetailScreenState extends State<ReservaDetailScreen> {
  bool _isLoading = false;

  Future<void> _cambiarEstado(String nuevoEstado) async {
    setState(() => _isLoading = true);
    try {
      final reservaProvider = context.read<ReservaProvider>();
      if (nuevoEstado == 'confirmada') {
        await reservaProvider.cambiarEstadoReserva(widget.reserva.id, 'confirmada', fechaConfirmada: DateTime.now());
      } else {
        await reservaProvider.cambiarEstadoReserva(widget.reserva.id, nuevoEstado);
      }
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reserva $nuevoEstado exitosamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final userSession = context.watch<UserSessionProvider>();
    final isMecanico = userSession.userData?.rol == 'Mecanico';
    final reserva = widget.reserva;

    final estadoColor = reserva.estado == 'confirmada' 
        ? Colors.green 
        : (reserva.estado == 'rechazada' ? Colors.red : colors.warning);
        
    final estadoTexto = reserva.estado == 'confirmada' 
        ? 'Confirmada' 
        : (reserva.estado == 'rechazada' ? 'Rechazada' : 'Pendiente de Confirmación');

    return Scaffold(
      backgroundColor: isDark ? colors.surfaceContainer : colors.surface,
      appBar: AppBar(
        title: const Text('Detalle de Cita'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
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
                              color: estadoColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              estadoTexto,
                              style: TextStyle(
                                color: estadoColor,
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
                      Text(reserva.tipoServicio.isNotEmpty ? reserva.tipoServicio : 'Mantenimiento General', 
                          style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                      const Divider(height: 32),
                      
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Fecha', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                                const SizedBox(height: 4),
                                Text(DateFormat('EEE, dd MMM yyyy', 'es').format(reserva.fechaHoraPropuesta), 
                                    style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Hora', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                                const SizedBox(height: 4),
                                Text(DateFormat('hh:mm a').format(reserva.fechaHoraPropuesta), 
                                    style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 32),
                      
                      Text('Vehículo ID', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(reserva.idVehiculo, style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                
                if (isMecanico && reserva.estado == 'pendiente') ...[
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () => _cambiarEstado('confirmada'),
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
                      onPressed: () => _cambiarEstado('rechazada'),
                      style: TextButton.styleFrom(
                        foregroundColor: colors.error,
                      ),
                      child: const Text('Rechazar / Reprogramar', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ],
            ),
          ),
    );
  }
}
