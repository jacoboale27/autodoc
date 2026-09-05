import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_radius.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/utils/l10n_extension.dart';

/// Qué eligió el usuario en la hoja de previsualización.
enum AdjuntoPreviewAccion { cancelar, cambiar, enviar }

/// Paso intermedio entre elegir una imagen y subirla al chat: muestra la
/// imagen, su nombre y su peso, y deja confirmar, volver a elegir o
/// descartar SIN haber tocado Storage todavía.
///
/// Es un componente nuevo y no una extensión de la previsualización de
/// `WorkshopVerificationScreen` (`_ArchivoPendiente` / `_tarjetaSlot`):
/// aquella vive incrustada como fila dentro de una lista de slots fijos de
/// un formulario, mientras que aquí se necesita un paso modal de pantalla
/// completa que se interponga en un flujo de composición de chat, con solo
/// una imagen a la vez y sin slots. Lo que SÍ se reutiliza de ese precedente
/// es la forma: un archivo "elegido pero no confirmado" vive en estado local
/// (aquí, los argumentos de esta hoja, mantenidos por quien la abre) y el
/// picker se inyecta con un typedef para tests — ver `SelectorDeImagen` en
/// `chat_screen.dart`.
class AdjuntoPreviewSheet extends StatelessWidget {
  const AdjuntoPreviewSheet({
    super.key,
    required this.bytes,
    required this.nombre,
  });

  final Uint8List bytes;
  final String nombre;

  String get _tamanoEnMB =>
      (bytes.lengthInBytes / (1024 * 1024)).toStringAsFixed(1);

  /// Abre la hoja y devuelve la acción elegida, o `null` si se cerró sin
  /// elegir ninguna (p. ej. tocando fuera).
  static Future<AdjuntoPreviewAccion?> mostrar(
    BuildContext context, {
    required Uint8List bytes,
    required String nombre,
  }) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet<AdjuntoPreviewAccion>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? colors.surfaceContainer : colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => AdjuntoPreviewSheet(bytes: bytes, nombre: nombre),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.xl,
          right: AppSpacing.xl,
          top: AppSpacing.lg,
          bottom: MediaQuery.of(context).padding.bottom + AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.chatAdjuntoPreviewTitulo,
              style: AppTextStyles.titleSmall.copyWith(
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Image.memory(
                bytes,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              context.l10n.chatAdjuntoPreviewInfo(nombre, _tamanoEnMB),
              style: AppTextStyles.bodySmall.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () =>
                        Navigator.pop(context, AdjuntoPreviewAccion.cancelar),
                    child: Text(context.l10n.chatAdjuntoPreviewCancelar),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextButton(
                    onPressed: () =>
                        Navigator.pop(context, AdjuntoPreviewAccion.cambiar),
                    child: Text(context.l10n.chatAdjuntoPreviewCambiar),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: () =>
                        Navigator.pop(context, AdjuntoPreviewAccion.enviar),
                    child: Text(context.l10n.chatAdjuntoPreviewEnviar),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
