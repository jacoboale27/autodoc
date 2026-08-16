import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_severity.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/widgets/app_status_badge.dart';
import 'package:autodoc/features/chat/presentation/widgets/chat_card_shell.dart';
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

  /// Inyectable para pruebas de widget (`FakeFirebaseFirestore`); por
  /// defecto usa la instancia real. Mismo precedente que
  /// `ReservaDetailScreen`: sin esto, el `StreamBuilder` de `build()` nunca
  /// emite en un widget test y la tarjeta se queda en el placeholder de
  /// carga.
  final FirebaseFirestore? firestore;

  const CotizacionChatCard({
    super.key,
    required this.metadata,
    required this.isMe,
    required this.mensajeId,
    required this.conversacionId,
    this.firestore,
  });

  @override
  State<CotizacionChatCard> createState() => _CotizacionChatCardState();
}

class _CotizacionChatCardState extends State<CotizacionChatCard> {
  bool _isCheckingReview = false;
  List<double>? _beneficios;

  String? get _cotizacionId => widget.metadata['id_cotizacion'] as String?;

  @override
  void initState() {
    super.initState();
    // Solo el mecanico (emisor de la cotizacion) necesita ver su beneficio;
    // el propietario nunca debe leer cotizaciones/{id}/privado/margen
    // (hallazgo H2), asi que ni siquiera se intenta el fetch para el.
    if (widget.isMe) _cargarBeneficios();
  }

  Future<void> _cargarBeneficios() async {
    final cotizacionId = _cotizacionId;
    if (cotizacionId == null) return;
    final beneficios = await context
        .read<ChatProvider>()
        .obtenerBeneficiosCotizacion(cotizacionId);
    if (!mounted) return;
    setState(() => _beneficios = beneficios);
  }

  Future<void> _actualizarEstado(String estado) async {
    final cotizacionId = _cotizacionId;
    if (cotizacionId == null) return;
    final chatProvider = context.read<ChatProvider>();
    await chatProvider.actualizarEstadoCotizacion(cotizacionId, estado);

    // Si esta cotización nació de una cita agendada (id_reserva), la Cloud
    // Function sincronizarReservaYReparacionAlCotizar (functions/index.js)
    // sincroniza el estado de la reserva y abre el ticket en Reparaciones —
    // no se duplica ese trabajo aquí porque requiere leer `vehiculos` (la
    // placa) con permisos que el cliente no tiene hasta que el taller ya
    // está vinculado (ver firestore.rules match /vehiculos).
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
      stream: (widget.firestore ?? FirebaseFirestore.instance)
          .collection('cotizaciones')
          .doc(cotizacionId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const ChatCardShell(
            icon: Icons.request_quote,
            title: 'Cotización de Servicio',
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        var cotizacion = CotizacionModel.fromMap(
          snapshot.data!.data()!,
          snapshot.data!.id,
        );
        if (widget.isMe && _beneficios != null) {
          cotizacion = cotizacion.copyWithBeneficios(_beneficios!);
        }
        return _CotizacionCardBody(
          cotizacion: cotizacion,
          isMe: widget.isMe,
          isCheckingReview: _isCheckingReview,
          onAceptar: () => _actualizarEstado('aceptada'),
          onRechazar: () => _actualizarEstado('rechazada'),
          onCalificar: () => _calificarServicio(context),
        );
      },
    );
  }
}

class _CotizacionCardBody extends StatelessWidget {
  final CotizacionModel cotizacion;
  final bool isMe;
  final bool isCheckingReview;
  final VoidCallback onAceptar;
  final VoidCallback onRechazar;
  final VoidCallback onCalificar;

  const _CotizacionCardBody({
    required this.cotizacion,
    required this.isMe,
    required this.isCheckingReview,
    required this.onAceptar,
    required this.onRechazar,
    required this.onCalificar,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final estado = cotizacion.estado;

    final severidad = AppSeverity.forReservaEstado(
      estado,
      colors,
      pendienteLabel: 'Pendiente',
      confirmadaLabel: 'En Proceso', // 'aceptada' en cotizaciones
      rechazadaLabel: 'Rechazada',
      cotizadaLabel: 'Servicio Finalizado', // 'finalizada'
    );

    // El beneficio del mecánico nunca se muestra al cliente.
    final beneficioTotal = cotizacion.items.fold<double>(
      0,
      (acc, i) => acc + i.beneficio,
    );

    return ChatCardShell(
      icon: Icons.request_quote,
      title: 'Cotización de Servicio',
      semanticLabel: 'Cotización de servicio, ${severidad.label}',
      trailing: AppStatusBadge(
        text: severidad.label,
        icon: severidad.icon,
        type: _statusTypeDe(estado),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (cotizacion.fechaPropuesta != null) ...[
            Row(
              children: [
                Icon(Icons.event, size: 14, color: colors.textSecondary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    DateFormat(
                      'dd/MM/yyyy hh:mm a',
                    ).format(cotizacion.fechaPropuesta!),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
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
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  Text(
                    '\$${item.subtotal.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Divider(height: 1, color: colors.outline.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colors.textSecondary,
                ),
              ),
              Flexible(
                child: Text(
                  '\$${cotizacion.total.toStringAsFixed(2)}',
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    // Desviación aceptada del brief (que pedía
                    // `colors.secondary` sin ternario): `colors.secondary`
                    // mide ~1,37:1 de contraste sobre `colors.surface`, por
                    // debajo del mínimo AA (4,5:1). Se usa `colors.primary`
                    // en su lugar, que sí cumple AA; `AppPalette` no se tocó.
                    color: colors.primary,
                  ),
                ),
              ),
            ],
          ),
          if (isMe && beneficioTotal > 0) ...[
            const SizedBox(height: 4),
            Semantics(
              label:
                  'Tu beneficio, visible solo para ti: '
                  '\$${beneficioTotal.toStringAsFixed(2)}',
              // Mismo patrón que chat_bubble.dart (ver su comentario junto a
              // `Semantics`), vehiculo_chat_card.dart, imagen_chat_card.dart
              // y audio_chat_card.dart: sin `ExcludeSemantics` el lector de
              // pantalla anuncia el `label` de arriba y LUEGO, por separado,
              // el ícono + "Tu beneficio:" + el monto del contenido hijo —
              // duplicado, no reemplazado.
              child: ExcludeSemantics(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // `Expanded` + `overflow: ellipsis` en el label, igual
                    // que el renglón de `Total:` más arriba: sin esto, un
                    // monto de beneficio de dos cifras hace que el Row entero
                    // (ícono + "Tu beneficio:" + monto) exceda el ancho
                    // disponible de la burbuja y desborde — bug real que
                    // apareció al hacer que este test cargara beneficios
                    // no-cero por primera vez.
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.visibility_off_outlined,
                            size: 12,
                            color: colors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Tu beneficio:',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '\$${beneficioTotal.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (estado == 'pendiente' && !isMe) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    text: context.l10n.chatAccept,
                    type: AppButtonType.primary,
                    onPressed: onAceptar,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppButton(
                    text: context.l10n.chatReject,
                    type: AppButtonType.secondary,
                    onPressed: onRechazar,
                  ),
                ),
              ],
            ),
          ],
          if (estado == 'aceptada' && isMe) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.directions_car_outlined,
                    size: 16,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Recibe el vehículo desde "Buscar Vehículo" para finalizar este servicio.',
                      style: TextStyle(fontSize: 12, color: colors.primary),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (estado == 'finalizada' && !isMe) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                text: 'Calificar Servicio',
                type: AppButtonType.primary,
                isLoading: isCheckingReview,
                icon: const Icon(Icons.star),
                onPressed: isCheckingReview ? null : onCalificar,
              ),
            ),
          ],
        ],
      ),
    );
  }

  AppStatusType _statusTypeDe(String estado) => switch (estado) {
    'aceptada' => AppStatusType.success,
    'rechazada' => AppStatusType.error,
    'finalizada' => AppStatusType.info,
    _ => AppStatusType.warning,
  };
}
