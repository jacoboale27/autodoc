import 'package:flutter/material.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import '../../data/models/mensaje_model.dart';
import 'package:go_router/go_router.dart';

class HistorialChatCard extends StatelessWidget {
  final MensajeModel mensaje;
  final bool isMe;
  final AppColors colors;

  const HistorialChatCard({
    super.key,
    required this.mensaje,
    required this.isMe,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? colors.primary : colors.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.history_edu,
                  color: isMe ? Colors.white : colors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Historial de Vehículo Compartido',
                  style: TextStyle(
                    color: isMe ? Colors.white : colors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                context.push('/dashboard/history/${mensaje.contenido}');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isMe ? Colors.white : colors.primary,
                foregroundColor: isMe ? colors.primary : Colors.white,
              ),
              child: const Text('Ver Historial Completo'),
            ),
          ],
        ),
      ),
    );
  }
}
