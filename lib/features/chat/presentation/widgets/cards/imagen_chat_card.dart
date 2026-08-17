import 'package:flutter/material.dart';
import 'package:autodoc/core/theme/app_colors.dart';

/// Imagen adjunta en el chat.
///
/// Tres decisiones frente a la versión anterior:
///
/// 1. **El alto está acotado.** Antes era `Container(width: 250)` sin
///    restricción de alto y `BoxFit.cover`, así que una captura alargada
///    producía una burbuja de más de una pantalla.
/// 2. **El tag del Hero incluye [mensajeId].** Con `tag: urlArchivo`, dos
///    mensajes con la misma imagen (reenviarla es normal) lanzaban
///    "There are multiple heroes that share the same tag".
/// 3. **El botón de cerrar del visor tiene fondo propio.** Antes era una X
///    blanca sobre un `Dialog` transparente: invisible sobre foto clara.
class ImagenChatCard extends StatelessWidget {
  final String urlArchivo;
  final bool isMe;

  /// Identificador del mensaje. Necesario para que el `Hero` sea único
  /// aunque la misma URL aparezca varias veces en la conversación.
  final String mensajeId;

  const ImagenChatCard({
    super.key,
    required this.urlArchivo,
    required this.isMe,
    required this.mensajeId,
  });

  /// Relación de aspecto máxima permitida (alto / ancho). 1.4 deja pasar el
  /// retrato 3:4 (1.33) sin recortar y acota la captura alargada.
  static const double _maxAspectRatio = 1.4;

  String get _heroTag => 'chat-imagen-$mensajeId-$urlArchivo';

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Semantics(
      label: 'Imagen adjunta. Toca para ampliar.',
      button: true,
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // El ancho lo pone la burbuja; el alto se deriva de él, nunca de
            // la relación de aspecto intrínseca de la imagen.
            final ancho = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : 250.0;
            return GestureDetector(
              onTap: () => _showImageDialog(context),
              child: Container(
                margin: const EdgeInsets.only(top: 8),
                constraints: BoxConstraints(maxHeight: ancho * _maxAspectRatio),
                decoration: BoxDecoration(
                  color: colors.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Hero(
                    tag: _heroTag,
                    child: Image.network(
                      urlArchivo,
                      fit: BoxFit.cover,
                      width: ancho,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 150,
                        color: colors.surfaceContainer,
                        child: Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          height: 150,
                          color: colors.surfaceContainer,
                          child: Center(
                            child: CircularProgressIndicator(
                              value: progress.expectedTotalBytes != null
                                  ? progress.cumulativeBytesLoaded /
                                        progress.expectedTotalBytes!
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showImageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: InteractiveViewer(
                child: Hero(
                  tag: _heroTag,
                  child: Image.network(urlArchivo, fit: BoxFit.contain),
                ),
              ),
            ),
            // Fondo propio: una X blanca sobre un Dialog transparente
            // desaparece encima de cualquier foto clara.
            Padding(
              padding: const EdgeInsets.all(8),
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 24),
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
