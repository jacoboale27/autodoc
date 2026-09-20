import 'package:flutter/material.dart';
import 'package:autodoc/core/models/reparacion_model.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/widgets/app_card.dart';
import 'package:autodoc/core/widgets/app_dialog_content.dart';

/// Lo que el taller decide en el diálogo de entrega.
enum _DecisionEntrega { entregar, finalizarPrimero }

class ReparacionCard extends StatefulWidget {
  final ReparacionModel reparacion;
  final VoidCallback? onAvanzar;
  final bool esUltimoEstado;

  /// Nombre visible del estado al que lleva [onAvanzar]. Sin esto el botón
  /// decía solo "Avanzar" y el usuario no sabía a dónde.
  final String? siguienteEstadoLabel;

  /// Cancela el ticket. Null oculta la acción por completo (p. ej. si la
  /// pantalla que embebe la tarjeta no quiere ofrecerla). Se ofrece en
  /// cualquier columna, no solo en la primera: a diferencia de "Avanzar",
  /// cancelar no depende de la posición en `estadosReparacion`.
  final VoidCallback? onCancelar;

  /// Entrega el vehículo: lo saca del taller y el ticket del tablero. Null
  /// oculta la acción, que es lo normal salvo en la última columna.
  final VoidCallback? onEntregar;

  /// ¿El servicio de este ticket ya está registrado (y por tanto cobrado)?
  /// `null` (el callback o su resultado) significa «no se sabe», y entonces la
  /// entrega se confirma como siempre: un fallo de red no puede impedirle al
  /// taller registrar que el cliente se llevó el coche.
  final Future<bool?> Function()? comprobarServicioRegistrado;

  /// Lleva a finalizar el servicio de este ticket, que es lo que genera el
  /// cobro. Se ofrece en el diálogo cuando no hay servicio registrado.
  final VoidCallback? onFinalizarServicio;

  const ReparacionCard({
    super.key,
    required this.reparacion,
    this.onAvanzar,
    this.esUltimoEstado = false,
    this.siguienteEstadoLabel,
    this.onCancelar,
    this.onEntregar,
    this.comprobarServicioRegistrado,
    this.onFinalizarServicio,
  });

  @override
  State<ReparacionCard> createState() => _ReparacionCardState();
}

class _ReparacionCardState extends State<ReparacionCard> {
  /// Entregar es irreversible y el diálogo se cierra al confirmar, así que el
  /// segundo toque no viene del mismo botón: viene de REABRIR el diálogo
  /// mientras la primera entrega viaja (patrón de GAPS-07). Esta bandera
  /// cubre también la comprobación previa, que es una ida a la red.
  bool _entregando = false;

  /// Confirma antes de cancelar: es una acción destructiva e irreversible
  /// (el ticket cancelado desaparece del tablero, ver
  /// `ReparacionRepository.cambiarEstado`), así que un toque accidental en
  /// la tarjeta equivocada no debe bastar para perderlo.
  Future<void> _confirmarCancelar(BuildContext context) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancelar ticket'),
        content: AppDialogContent(
          child: Text(
            '¿Seguro que deseas cancelar el ticket de "${widget.reparacion.placa}"? '
            'Esta acción no se puede deshacer.',
          ),
        ),
        actions: [
          AppButton(
            text: 'Volver',
            type: AppButtonType.text,
            size: AppButtonSize.small,
            onPressed: () => Navigator.pop(dialogContext, false),
          ),
          AppButton(
            text: 'Cancelar ticket',
            type: AppButtonType.danger,
            size: AppButtonSize.small,
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );
    if (confirmado == true) widget.onCancelar?.call();
  }

  /// Confirma antes de entregar, por el mismo motivo que
  /// [_confirmarCancelar] y con más razón: entregar es lo que retira el
  /// acceso del taller a la ficha del vehículo (`talleres_vinculados`) y saca
  /// el ticket del tablero, y no hay ninguna acción en la interfaz que lo
  /// deshaga — el repositorio rechaza volver a un estado del pipeline desde
  /// uno terminal. El texto nombra el hecho físico ("se lo llevó"), no el
  /// estado, porque es lo único que el mecánico puede comprobar mirando.
  Future<void> _confirmarEntregar() async {
    if (_entregando) return;
    setState(() => _entregando = true);
    try {
      // `?? true` = si no se puede comprobar, se pregunta lo de siempre.
      final registrado =
          await widget.comprobarServicioRegistrado?.call() ?? true;
      if (!mounted) return;

      final _DecisionEntrega? decision;
      if (registrado) {
        decision = await _preguntarEntrega();
      } else {
        decision = await _preguntarEntregaSinServicio();
      }
      if (!mounted) return;

      switch (decision) {
        case _DecisionEntrega.entregar:
          widget.onEntregar?.call();
        case _DecisionEntrega.finalizarPrimero:
          widget.onFinalizarServicio?.call();
        case null:
          break;
      }
    } finally {
      if (mounted) setState(() => _entregando = false);
    }
  }

  Future<_DecisionEntrega?> _preguntarEntrega() {
    return showDialog<_DecisionEntrega>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Entregar vehículo'),
        content: AppDialogContent(
          child: Text(
            '¿El cliente ya se llevó "${widget.reparacion.placa}"? El ticket '
            'saldrá del tablero y tu taller dejará de tener acceso a la ficha '
            'del vehículo.',
          ),
        ),
        actions: [
          AppButton(
            text: 'Todavía no',
            type: AppButtonType.text,
            size: AppButtonSize.small,
            onPressed: () => Navigator.pop(dialogContext),
          ),
          AppButton(
            text: 'Entregar',
            size: AppButtonSize.small,
            onPressed: () =>
                Navigator.pop(dialogContext, _DecisionEntrega.entregar),
          ),
        ],
      ),
    );
  }

  /// El coche está listo para salir pero nadie registró el servicio, así que
  /// no hay cobro. Entregar ahora revoca el vínculo y saca el ticket del
  /// tablero: después no queda ninguna pantalla desde la que facturarlo, que
  /// es exactamente lo que pasó el 2026-09-19.
  ///
  /// «Entregar sin cobrar» se conserva porque el caso existe: el cliente que
  /// rechaza el presupuesto y se lleva el coche a medias. Lo que no puede
  /// pasar es que ese camino sea el mismo que el de un trabajo terminado.
  Future<_DecisionEntrega?> _preguntarEntregaSinServicio() {
    return showDialog<_DecisionEntrega>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Falta finalizar el servicio'),
        content: AppDialogContent(
          child: Text(
            'El servicio de "${widget.reparacion.placa}" todavía no está '
            'registrado, así que no se ha generado el cobro. Si entregas '
            'ahora, el ticket sale del tablero y tu taller pierde el acceso a '
            'la ficha del vehículo: ya no podrás facturarlo.',
          ),
        ),
        actions: [
          AppButton(
            text: 'Todavía no',
            type: AppButtonType.text,
            size: AppButtonSize.small,
            onPressed: () => Navigator.pop(dialogContext),
          ),
          AppButton(
            text: 'Entregar sin cobrar',
            type: AppButtonType.danger,
            size: AppButtonSize.small,
            onPressed: () =>
                Navigator.pop(dialogContext, _DecisionEntrega.entregar),
          ),
          AppButton(
            text: 'Finalizar servicio',
            size: AppButtonSize.small,
            onPressed: () =>
                Navigator.pop(dialogContext, _DecisionEntrega.finalizarPrimero),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final dias = DateTime.now()
        .difference(widget.reparacion.fechaActualizacion)
        .inDays;

    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.reparacion.placa,
            style: AppTextStyles.titleSmall.copyWith(
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            dias == 0
                ? 'Actualizado hoy'
                : 'Hace $dias ${dias == 1 ? 'día' : 'días'}',
            style: AppTextStyles.bodySmall.copyWith(
              color: colors.textSecondary,
            ),
          ),
          if (!widget.esUltimoEstado &&
              widget.siguienteEstadoLabel != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: AppButton(
                text: 'Avanzar a ${widget.siguienteEstadoLabel}',
                type: AppButtonType.text,
                size: AppButtonSize.small,
                icon: const Icon(Icons.arrow_forward),
                onPressed: widget.onAvanzar,
              ),
            ),
          ],
          if (widget.onEntregar != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: AppButton(
                text: 'Entregar vehículo',
                type: AppButtonType.text,
                size: AppButtonSize.small,
                icon: const Icon(Icons.check_circle_outline),
                // Deshabilitado mientras la entrega viaja: es la primera
                // de las dos capas de GAPS-07 (la otra es `_entregando`, que
                // atrapa los dos toques del MISMO frame).
                onPressed: _entregando ? null : _confirmarEntregar,
              ),
            ),
          ],
          if (widget.onCancelar != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              // Sin icono y sin fondo (a diferencia de "Avanzar"), para que
              // pese menos visualmente aunque use colors.error: es la
              // acción secundaria de la tarjeta, no la sugerida.
              child: AppButton(
                text: 'Cancelar',
                type: AppButtonType.text,
                size: AppButtonSize.small,
                onPressed: () => _confirmarCancelar(context),
                child: Text(
                  'Cancelar',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: colors.error,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
