import 'package:flutter/material.dart';

import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_radius.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/utils/ui_utils.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/widgets/review_sheet.dart';
import 'package:autodoc/features/reviews/data/services/review_service.dart';

/// Busca el servicio que se puede reseñar (ver
/// `ReviewService.findReviewableServiceId`).
typedef BuscarServicioResenable =
    Future<String?> Function(String userId, String tallerId);

/// Abre la hoja de reseña y dice si se envió.
typedef AbrirResenia =
    Future<bool?> Function(
      BuildContext context, {
      required String tallerId,
      required String tallerNombre,
      required String idServicio,
    });

/// La ÚNICA forma de reseñar al taller desde el chat.
///
/// Observaciones del 2026-09-19: cada tarjeta de cotización finalizada traía
/// su propio botón «Calificar Servicio», y como un servicio puede cobrar
/// varias cotizaciones a la vez, el chat se llenaba de botones que llevaban
/// a lo mismo. Ahora hay uno, encima de la barra de escribir, y solo aparece
/// cuando `ReviewService` dice que hay algo que reseñar: el servicio más
/// reciente con ese taller, si aún no tiene reseña. Enviada la reseña, se
/// retira hasta el siguiente servicio.
///
/// Se vuelve a consultar cuando cambia [revision] (la pantalla le pasa el
/// número de mensajes: la solicitud de reseña del taller llega como uno).
class AvisoReseniaChat extends StatefulWidget {
  final String userId;
  final String tallerId;
  final String tallerNombre;
  final int revision;
  final BuscarServicioResenable? buscarResenable;
  final AbrirResenia? abrirResenia;

  const AvisoReseniaChat({
    super.key,
    required this.userId,
    required this.tallerId,
    required this.tallerNombre,
    this.revision = 0,
    this.buscarResenable,
    this.abrirResenia,
  });

  @override
  State<AvisoReseniaChat> createState() => _AvisoReseniaChatState();
}

class _AvisoReseniaChatState extends State<AvisoReseniaChat> {
  Future<String?>? _consulta;

  /// Guard de reentrada (GAPS-07): abrir la hoja dos veces sería poder
  /// enviar dos reseñas del mismo servicio a la vez.
  bool _abriendo = false;

  /// Servicios ya reseñados en esta pantalla. La nueva consulta tarda un
  /// instante, y hasta que vuelve el aviso seguiría ofreciendo el mismo
  /// servicio: un toque más en ese hueco abría otra vez la hoja.
  final Set<String> _yaReseniados = {};

  @override
  void initState() {
    super.initState();
    _consultar();
  }

  @override
  void didUpdateWidget(covariant AvisoReseniaChat oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision ||
        oldWidget.userId != widget.userId ||
        oldWidget.tallerId != widget.tallerId) {
      _consultar();
    }
  }

  void _consultar() {
    // Un fallo (de red, o sin Firebase inicializado) no es motivo para pintar
    // un error en el chat: sin respuesta, simplemente no se ofrece reseñar.
    try {
      final buscar =
          widget.buscarResenable ?? ReviewService().findReviewableServiceId;
      _consulta = buscar(
        widget.userId,
        widget.tallerId,
      ).catchError((Object _) => null);
    } catch (_) {
      _consulta = Future<String?>.value();
    }
  }

  Future<void> _calificar(String idServicio) async {
    if (_abriendo || _yaReseniados.contains(idServicio)) return;
    setState(() => _abriendo = true);
    final abrir = widget.abrirResenia ?? showReviewBottomSheet;
    final enviada = await abrir(
      context,
      tallerId: widget.tallerId,
      tallerNombre: widget.tallerNombre,
      idServicio: idServicio,
    );
    if (!mounted) return;
    setState(() {
      _abriendo = false;
      if (enviada == true) {
        _yaReseniados.add(idServicio);
        _consultar();
      }
    });
    if (enviada == true) {
      UiUtils.showSuccessSnackbar(context, '¡Gracias por enviar tu reseña!');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _consulta,
      builder: (context, snapshot) {
        final idServicio = snapshot.data;
        if (idServicio == null || _yaReseniados.contains(idServicio)) {
          return const SizedBox.shrink();
        }
        final colors = context.appColors;
        return Container(
          key: const Key('aviso_resenia_chat'),
          margin: const EdgeInsets.fromLTRB(
            AppSpacing.base,
            AppSpacing.sm,
            AppSpacing.base,
            0,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: colors.primary.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Icon(Icons.star_rounded, color: colors.warning),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Tu servicio con ${widget.tallerNombre} terminó. '
                  '¿Cómo te fue?',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                // AppButton ocupa todo el ancho que le den.
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: AppButton(
                    key: const Key('aviso_resenia_calificar'),
                    text: 'Calificar servicio',
                    size: AppButtonSize.small,
                    onPressed: _abriendo ? null : () => _calificar(idServicio),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
