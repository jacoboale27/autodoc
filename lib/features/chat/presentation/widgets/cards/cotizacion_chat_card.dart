import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/features/chat/presentation/providers/chat_provider.dart';
import 'package:autodoc/features/chat/data/models/cotizacion_model.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/features/reviews/data/services/review_service.dart';
import 'package:autodoc/core/widgets/review_sheet.dart';
import 'package:autodoc/core/utils/l10n_extension.dart';
import 'package:autodoc/core/utils/ui_utils.dart';

class CotizacionChatCard extends StatefulWidget {
  final Map<String, dynamic> metadata;
  final bool isMe;
  final String mensajeId;
  final String conversacionId;

  const CotizacionChatCard({
    super.key,
    required this.metadata,
    required this.isMe,
    required this.mensajeId,
    required this.conversacionId,
  });

  @override
  State<CotizacionChatCard> createState() => _CotizacionChatCardState();
}

class _CotizacionChatCardState extends State<CotizacionChatCard> {
  bool _isFinalizing = false;
  bool _isCheckingReview = false;

  String? get _cotizacionId => widget.metadata['id_cotizacion'] as String?;

  Future<void> _actualizarEstado(String estado) async {
    final cotizacionId = _cotizacionId;
    if (cotizacionId == null) return;
    await context.read<ChatProvider>().actualizarEstadoCotizacion(
      cotizacionId,
      estado,
    );
  }

  Future<void> _finalizarServicio() async {
    final cotizacionId = _cotizacionId;
    if (cotizacionId == null) return;

    setState(() => _isFinalizing = true);
    final provider = context.read<ChatProvider>();
    final success = await provider.finalizarServicioDesdeCotizacion(
      cotizacionId,
    );

    if (!mounted) return;

    if (success) {
      UiUtils.showSuccessSnackbar(
        context,
        'Servicio finalizado. El cliente ya puede dejar su reseña.',
      );
    } else {
      UiUtils.showErrorSnackbar(
        context,
        provider.error?.replaceFirst('StateError: ', '') ??
            'No se pudo finalizar el servicio.',
      );
    }
    if (mounted) setState(() => _isFinalizing = false);
  }

  Future<void> _calificarServicio(BuildContext context) async {
    if (_isCheckingReview) return;
    final userId = context.read<UserProfileProvider>().userData?.idUsuario;
    if (userId == null) return;

    final provider = context.read<ChatProvider>();
    final conversacion = provider.conversaciones
        .where((c) => c.id == widget.conversacionId)
        .firstOrNull;

    final tallerId = conversacion?.idTaller ?? conversacion?.idMecanico;
    if (tallerId == null || tallerId.isEmpty) {
      UiUtils.showErrorSnackbar(
        context,
        'No se pudo identificar el taller de esta conversación.',
      );
      return;
    }

    setState(() => _isCheckingReview = true);
    String? idServicio;
    String? errorMessage;
    try {
      idServicio = await ReviewService().findReviewableServiceId(
        userId,
        tallerId,
      );
    } catch (e) {
      errorMessage = e.toString().replaceFirst('StateError: ', '');
    }
    if (mounted) setState(() => _isCheckingReview = false);
    if (!context.mounted) return;

    if (errorMessage != null) {
      UiUtils.showErrorSnackbar(context, errorMessage);
      return;
    }

    if (idServicio == null) {
      UiUtils.showErrorSnackbar(
        context,
        'No se encontró un servicio disponible para reseñar.',
      );
      return;
    }

    final result = await showReviewBottomSheet(
      context,
      tallerId: tallerId,
      tallerNombre: conversacion?.nombreMecanico ?? 'Taller',
      idServicio: idServicio,
    );

    if (result == true && context.mounted) {
      UiUtils.showSuccessSnackbar(context, '¡Gracias por enviar tu reseña!');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cotizacionId = _cotizacionId;
    if (cotizacionId == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('cotizaciones')
          .doc(cotizacionId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox(
            width: 280,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        final cotizacion = CotizacionModel.fromMap(
          snapshot.data!.data()!,
          snapshot.data!.id,
        );
        return _CotizacionCardBody(
          cotizacion: cotizacion,
          isMe: widget.isMe,
          isFinalizing: _isFinalizing,
          isCheckingReview: _isCheckingReview,
          onAceptar: () => _actualizarEstado('aceptada'),
          onRechazar: () => _actualizarEstado('rechazada'),
          onFinalizar: _finalizarServicio,
          onCalificar: () => _calificarServicio(context),
        );
      },
    );
  }
}

class _CotizacionCardBody extends StatelessWidget {
  final CotizacionModel cotizacion;
  final bool isMe;
  final bool isFinalizing;
  final bool isCheckingReview;
  final VoidCallback onAceptar;
  final VoidCallback onRechazar;
  final VoidCallback onFinalizar;
  final VoidCallback onCalificar;

  const _CotizacionCardBody({
    required this.cotizacion,
    required this.isMe,
    required this.isFinalizing,
    required this.isCheckingReview,
    required this.onAceptar,
    required this.onRechazar,
    required this.onFinalizar,
    required this.onCalificar,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final estado = cotizacion.estado;

    Color badgeColor = Colors.orange;
    String badgeText = 'Pendiente';
    if (estado == 'aceptada') {
      badgeColor = Colors.green;
      badgeText = 'En Proceso';
    } else if (estado == 'rechazada') {
      badgeColor = Colors.red;
      badgeText = 'Rechazada';
    } else if (estado == 'finalizada') {
      badgeColor = Colors.blue;
      badgeText = 'Servicio Finalizado';
    }

    // El beneficio del mecánico nunca se muestra al cliente.
    final beneficioTotal = cotizacion.items.fold<double>(
      0,
      (acc, i) => acc + i.beneficio,
    );

    return Container(
      width: 300,
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
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.request_quote,
                        size: 16,
                        color: isMe ? Colors.white : colors.primary,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Cotización de Servicio',
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isMe ? Colors.white : colors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
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
                if (cotizacion.fechaPropuesta != null) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.event,
                        size: 14,
                        color: isMe ? Colors.white70 : colors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        DateFormat(
                          'dd/MM/yyyy hh:mm a',
                        ).format(cotizacion.fechaPropuesta!),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isMe ? Colors.white : colors.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                ...cotizacion.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            '${item.material} x${item.cantidad.toStringAsFixed(item.cantidad % 1 == 0 ? 0 : 1)}',
                            style: TextStyle(
                              color: isMe ? Colors.white : colors.textPrimary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Text(
                          '\$${item.subtotal.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: isMe
                                ? Colors.white70
                                : colors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Divider(height: 1, color: Colors.black12),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isMe ? Colors.white70 : colors.textSecondary,
                      ),
                    ),
                    Text(
                      '\$${cotizacion.total.toStringAsFixed(2)}',
                      style: AppTextStyles.titleLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isMe ? Colors.white : colors.secondary,
                      ),
                    ),
                  ],
                ),
                if (isMe && beneficioTotal > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.visibility_off_outlined,
                            size: 12,
                            color: Colors.white54,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Tu beneficio:',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '\$${beneficioTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
                if (estado == 'pendiente' && !isMe) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onAceptar,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.primary,
                            side: BorderSide(color: colors.primary),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          child: Text(context.l10n.chatAccept),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onRechazar,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          child: Text(context.l10n.chatReject),
                        ),
                      ),
                    ],
                  ),
                ],
                if (estado == 'aceptada' && isMe) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: isFinalizing ? null : onFinalizar,
                      icon: isFinalizing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_circle_outline, size: 18),
                      label: Text(
                        isFinalizing ? 'Finalizando...' : 'Finalizar Servicio',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
                if (estado == 'finalizada' && !isMe) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: isCheckingReview ? null : onCalificar,
                      icon: isCheckingReview
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.star, size: 18),
                      label: const Text('Calificar Servicio'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
