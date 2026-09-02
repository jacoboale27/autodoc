import 'package:flutter/material.dart';

import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/utils/l10n_extension.dart';

/// Visor de imagen a pantalla completa, con zoom y desplazamiento.
///
/// Genérico a propósito: no sabe nada de verificaciones, expedientes ni
/// administradores. Quien lo abre ya resolvió la URL (pedirla aquí dentro
/// duplicaría la petición de red que el llamador ya hizo) y decide qué texto
/// describe el documento para lectores de pantalla.
class AppImageViewer extends StatelessWidget {
  /// URL ya resuelta de la imagen a mostrar.
  final String imageUrl;

  /// Describe qué documento se está viendo, para `Semantics`. La decide el
  /// llamador: este widget no sabe en qué pantalla vive.
  final String semanticLabel;

  const AppImageViewer({
    super.key,
    required this.imageUrl,
    required this.semanticLabel,
  });

  /// Empuja el visor como una página nueva.
  ///
  /// Ayuda compartida para no repetir el `Navigator.push` en cada pantalla
  /// que lo consume (la bandeja del admin y, más adelante, la pantalla del
  /// taller). No añade nada al contrato del widget: sigue recibiendo la URL
  /// ya resuelta y la etiqueta semántica, nada más.
  static Future<void> open(
    BuildContext context, {
    required String imageUrl,
    required String semanticLabel,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) =>
            AppImageViewer(imageUrl: imageUrl, semanticLabel: semanticLabel),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.scrim,
      body: Stack(
        children: [
          Positioned.fill(
            child: Semantics(
              label: semanticLabel,
              image: true,
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, _, _) => Icon(
                      Icons.broken_image_outlined,
                      color: colors.onScrim,
                      size: 64,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                tooltip: context.l10n.wdClose,
                icon: Icon(Icons.close, color: colors.onScrim),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
