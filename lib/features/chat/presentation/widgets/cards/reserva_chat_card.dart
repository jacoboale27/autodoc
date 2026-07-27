import 'package:flutter/material.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/features/chat/presentation/providers/chat_provider.dart';
import 'package:autodoc/features/chat/presentation/providers/reserva_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:autodoc/features/chat/data/models/reserva_model.dart';
import 'package:autodoc/core/utils/l10n_extension.dart';

class ReservaChatCard extends StatelessWidget {
  final Map<String, dynamic> metadata;
  final bool isMe;
  final String mensajeId;
  final String conversacionId;

  const ReservaChatCard({
    super.key,
    required this.metadata,
    required this.isMe,
    required this.mensajeId,
    required this.conversacionId,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final String fechaRaw = metadata['fecha'] ?? '';
    final String hora = metadata['hora'] ?? '';
    final String estado =
        metadata['estado'] ?? 'pendiente'; // pendiente, aceptada, rechazada

    DateTime? fecha;
    if (fechaRaw.isNotEmpty) {
      fecha = DateTime.tryParse(fechaRaw);
    }

    Color badgeColor = Colors.orange;
    String badgeText = 'Pendiente';
    if (estado == 'aceptada') {
      badgeColor = Colors.green;
      badgeText = 'Aceptada';
    } else if (estado == 'rechazada') {
      badgeColor = Colors.red;
      badgeText = 'Rechazada';
    }

    return Container(
      width: 260,
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceContainer : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMe
              ? Colors.white30
              : (isDark ? Colors.white12 : Colors.black12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isMe
                  ? Colors.black12
                  : (isDark ? Colors.black26 : Colors.grey.shade100),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.event,
                      size: 16,
                      color: isMe ? Colors.white : colors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Reserva de Cita',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isMe ? Colors.white : colors.textPrimary,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badgeText,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
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
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: isMe ? Colors.white70 : colors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      fecha != null
                          ? DateFormat('dd MMM yyyy').format(fecha)
                          : 'Fecha sin definir',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isMe ? Colors.white : colors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: isMe ? Colors.white70 : colors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      hora.isNotEmpty ? hora : 'Hora sin definir',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isMe ? Colors.white : colors.textPrimary,
                      ),
                    ),
                  ],
                ),
                if (estado == 'pendiente' && !isMe) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            final newMeta = Map<String, dynamic>.from(metadata);
                            newMeta['estado'] = 'aceptada';
                            context
                                .read<ChatProvider>()
                                .actualizarMetadatosMensaje(
                                  conversacionId,
                                  mensajeId,
                                  newMeta,
                                );
                            final reservaId = metadata['id_reserva'];
                            if (reservaId != null) {
                              context
                                  .read<ReservaProvider>()
                                  .cambiarEstadoReserva(
                                    reservaId,
                                    'confirmada',
                                    fechaConfirmada: DateTime.now(),
                                  );
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.primary,
                            side: BorderSide(color: colors.primary),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            minimumSize: Size.zero,
                          ),
                          child: Text(context.l10n.chatAccept),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            final newMeta = Map<String, dynamic>.from(metadata);
                            newMeta['estado'] = 'rechazada';
                            context
                                .read<ChatProvider>()
                                .actualizarMetadatosMensaje(
                                  conversacionId,
                                  mensajeId,
                                  newMeta,
                                );
                            final reservaId = metadata['id_reserva'];
                            if (reservaId != null) {
                              context
                                  .read<ReservaProvider>()
                                  .cambiarEstadoReserva(reservaId, 'rechazada');
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            minimumSize: Size.zero,
                          ),
                          child: Text(context.l10n.chatReject),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      final reserva = ReservaModel(
                        id: metadata['id_reserva'] ?? 'dummy_id',
                        idConversacion: conversacionId,
                        idPropietario: '',
                        idMecanico: '',
                        idVehiculo:
                            metadata['id_vehiculo'] ?? 'No especificado',
                        idTaller: '',
                        fechaHoraPropuesta: fecha ?? DateTime.now(),
                        tipoServicio:
                            metadata['tipo_servicio'] ?? 'Servicio General',
                        estado: estado,
                        fechaCreacion: DateTime.now(),
                      );
                      context.push('/reserva_detail', extra: reserva);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isMe ? Colors.white : colors.primary,
                      side: BorderSide(
                        color: isMe
                            ? Colors.white70
                            : colors.primary.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(context.l10n.chatViewDetail),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
