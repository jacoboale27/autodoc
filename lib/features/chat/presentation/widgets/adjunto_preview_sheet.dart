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

  /// Tamano con la unidad que le corresponde al archivo, no siempre en MB.
  ///
  /// Antes se formateaba en MB con un decimal fijo, asi que todo lo que
  /// pesara menos de ~50 KB —la mayoria de las fotos ya comprimidas que pasan
  /// por aqui— se anunciaba como "0.0 MB", que se lee como un archivo vacio
  /// justo en la pantalla cuyo trabajo es dar confianza antes de enviar.
  String get _tamanoLegible {
    final bytesTotales = bytes.lengthInBytes;
    if (bytesTotales < 1024) return '$bytesTotales B';
    if (bytesTotales < 1024 * 1024) {
      return '${(bytesTotales / 1024).round()} KB';
    }
    return '${(bytesTotales / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

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

    // F2 (revisión C6): la altura de la miniatura era un fijo de 220dp que,
    // sumado al resto del contenido (~384dp), desbordaba en un viewport bajo
    // (móvil en horizontal, ~330-360dp de alto útil). Se acota a una
    // fracción de la altura disponible en vez de un valor fijo, con un piso
    // razonable para que no se vuelva un timbre postal en pantallas altas.
    final alturaImagen = (MediaQuery.of(context).size.height * 0.3).clamp(
      120.0,
      220.0,
    );

    return SafeArea(
      // F2: `SafeArea` ya añade el padding inferior del inset del sistema a
      // su hijo — sumarlo también aquí (como hacía antes) lo contaba dos
      // veces en dispositivos con barra de gestos.
      child: Padding(
        padding: const EdgeInsets.only(
          left: AppSpacing.xl,
          right: AppSpacing.xl,
          top: AppSpacing.lg,
          bottom: AppSpacing.lg,
        ),
        // F2: el contenido puede seguir superando la altura disponible
        // incluso con la imagen acotada (nombres largos, dos líneas de
        // info); envolver en scroll evita el `RenderFlex` overflow y le da
        // al usuario una forma de llegar a los botones que no sea arrastrar
        // la propia hoja hacia abajo (lo que un `showModalBottomSheet`
        // interpreta como cancelar).
        child: SingleChildScrollView(
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
                  height: alturaImagen,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  // Bytes indecodificables (archivo de 0 bytes, HEIC no
                  // soportado) lanzaban durante el decode y dejaban un
                  // rectángulo en blanco con "Enviar" igual de habilitado.
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: alturaImagen,
                    width: double.infinity,
                    color: colors.surfaceContainer,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                context.l10n.chatAdjuntoPreviewInfo(nombre, _tamanoLegible),
                style: AppTextStyles.bodySmall.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      key: const Key('adjunto_preview_cancelar'),
                      onPressed: () =>
                          Navigator.pop(context, AdjuntoPreviewAccion.cancelar),
                      child: Text(context.l10n.chatAdjuntoPreviewCancelar),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextButton(
                      key: const Key('adjunto_preview_cambiar'),
                      onPressed: () =>
                          Navigator.pop(context, AdjuntoPreviewAccion.cambiar),
                      child: Text(context.l10n.chatAdjuntoPreviewCambiar),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton(
                      key: const Key('adjunto_preview_enviar'),
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
      ),
    );
  }
}
