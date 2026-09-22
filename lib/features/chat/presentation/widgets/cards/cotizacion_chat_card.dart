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
import 'package:autodoc/core/utils/l10n_extension.dart';

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
  /// Bloquea Aceptar/Rechazar mientras la decision anterior sigue en vuelo.
  /// Aceptar una cotizacion abre un ticket de reparacion en el servidor, asi
  /// que repetirla no es un no-op.
  bool _decidiendo = false;
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
    // Guard de reentrada: el `onPressed: null` solo surte efecto en el frame
    // siguiente, asi que dos taps en el mismo frame pasarian los dos.
    if (_decidiendo) return;
    setState(() => _decidiendo = true);
    final chatProvider = context.read<ChatProvider>();
    try {
      await chatProvider.actualizarEstadoCotizacion(cotizacionId, estado);
    } finally {
      if (mounted) setState(() => _decidiendo = false);
    }

    // Si esta cotización nació de una cita agendada (id_reserva), la Cloud
    // Function sincronizarReservaYReparacionAlCotizar (functions/index.js)
    // sincroniza el estado de la reserva y abre el ticket en Reparaciones —
    // no se duplica ese trabajo aquí porque requiere leer `vehiculos` (la
    // placa) con permisos que el cliente no tiene hasta que el taller ya
    // está vinculado (ver firestore.rules match /vehiculos).
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
        if (cotizacion.estado == 'draft') {
          return const SizedBox.shrink();
        }
        if (widget.isMe && _beneficios != null) {
          cotizacion = cotizacion.copyWithBeneficios(_beneficios!);
        }
        return _CotizacionCardBody(
          cotizacion: cotizacion,
          // `error_apertura_ticket` lo escribe `onCotizacionAceptada` cuando
          // la aceptación no puede abrir ningún ticket (la cotización no
          // ancla a un vehículo, el vehículo ya no existe, o el taller no
          // está autorizado). El campo existía desde la ronda anterior y no
          // lo leía nadie: el taller veía «Recibe el vehículo desde "Buscar
          // Vehículo"» sobre una cotización que jamás iba a producir un
          // ticket, y Buscar Vehículo le respondía que necesitaba una
          // cotización aceptada. No va en `CotizacionModel` porque no es
          // dato de la cotización, es el resultado de un trigger.
          errorAperturaTicket:
              (snapshot.data!.data()!['error_apertura_ticket']
                      as Map<String, dynamic>?)?['mensaje']
                  as String?,
          isMe: widget.isMe,
          decidiendo: _decidiendo,
          onAceptar: () => _actualizarEstado('aceptada'),
          onRechazar: () => _actualizarEstado('rechazada'),
        );
      },
    );
  }
}

/// Lo que ve el taller justo después de que el cliente acepta.
///
/// Tiene tres textos porque hay tres finales distintos, y antes solo había
/// uno —«Recibe el vehículo desde "Buscar Vehículo"»— que se mostraba
/// incluso cuando recibir el vehículo era imposible.
class _AvisoTrasAceptar extends StatelessWidget {
  final String? errorAperturaTicket;
  final bool sinVehiculo;
  final AppColors colors;

  const _AvisoTrasAceptar({
    required this.errorAperturaTicket,
    required this.sinVehiculo,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final error = errorAperturaTicket;
    final esProblema = error != null || sinVehiculo;
    final color = esProblema ? colors.error : colors.primary;
    final texto =
        error ??
        (sinVehiculo
            ? 'Esta cotización no está asociada a ningún vehículo, así que '
                  'no abrirá un ticket de servicio. Pídele al cliente que la '
                  'vuelva a solicitar desde su vehículo.'
            : 'El ticket ya está abierto en Reparaciones, en "Por recibir". '
                  'Recibe el vehículo desde ahí para continuar el servicio.');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            esProblema ? Icons.error_outline : Icons.directions_car_outlined,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(texto, style: TextStyle(fontSize: 12, color: color)),
          ),
        ],
      ),
    );
  }
}

class _CotizacionCardBody extends StatelessWidget {
  final CotizacionModel cotizacion;
  final String? errorAperturaTicket;
  final bool isMe;

  /// Con una decision en vuelo, Aceptar y Rechazar dejan de aceptar taps.
  final bool decidiendo;
  final VoidCallback onAceptar;
  final VoidCallback onRechazar;

  const _CotizacionCardBody({
    required this.cotizacion,
    required this.errorAperturaTicket,
    required this.isMe,
    this.decidiendo = false,
    required this.onAceptar,
    required this.onRechazar,
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
          if ((cotizacion.manoDeObra ?? 0) > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Mano de obra', style: TextStyle(fontSize: 13)),
                  ),
                  Text(
                    '\$${cotizacion.manoDeObra!.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
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
                    onPressed: decidiendo ? null : onAceptar,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppButton(
                    text: context.l10n.chatReject,
                    type: AppButtonType.secondary,
                    onPressed: decidiendo ? null : onRechazar,
                  ),
                ),
              ],
            ),
          ],
          if (estado == 'aceptada' && isMe) ...[
            const SizedBox(height: 16),
            _AvisoTrasAceptar(
              errorAperturaTicket: errorAperturaTicket,
              sinVehiculo: (cotizacion.idVehiculo ?? '').isEmpty,
              colors: colors,
            ),
          ],
          // Sin botón de reseña (observaciones del 2026-09-19): un servicio
          // puede cobrar varias cotizaciones, y cada tarjeta traía el suyo. La
          // única forma de reseñar es el aviso de encima de la barra de
          // escribir (`AvisoReseniaChat`).
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
