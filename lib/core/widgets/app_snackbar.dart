import 'package:flutter/material.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_radius.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';

enum SnackbarType { success, error, info }

class AppSnackbar {
  AppSnackbar._();

  static void show(
    BuildContext context,
    String message, {
    SnackbarType type = SnackbarType.info,
  }) {
    final colors = context.appColors;
    final theme = Theme.of(context);

    // Capturamos el ScaffoldMessenger AHORA, mientras el context todavía es
    // válido: muchas llamadas hacen Navigator.pop justo antes de mostrar el
    // snackbar, y si lo buscáramos dentro del onPressed (que se ejecuta
    // después, al tocar "OK"), el context ya podría estar desmontado.
    final messenger = ScaffoldMessenger.of(context);

    // El fondo sale del tema (una superficie oscura en ambos modos), no del
    // color semántico: pintar el fondo de #48BB78 con texto blanco daba
    // 2.43:1, muy por debajo del 4.5:1 de WCAG AA. El significado lo lleva el
    // icono, que como glifo solo necesita 3:1 y lo supera con holgura.
    final background =
        theme.snackBarTheme.backgroundColor ?? colors.surfaceVariant;
    final foreground =
        theme.snackBarTheme.contentTextStyle?.color ?? colors.textPrimary;

    final (IconData icon, Color accent) = switch (type) {
      SnackbarType.success => (Icons.check_circle_outline, colors.success),
      SnackbarType.error => (Icons.error_outline, colors.error),
      // El morado de marca no llega a 3:1 sobre la superficie oscura del
      // snackbar; el teal complementario sí.
      SnackbarType.info => (Icons.info_outline, colors.secondary),
    };

    final snackBar = SnackBar(
      content: Row(
        children: [
          Icon(icon, color: accent, size: 24),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodyMedium.copyWith(
                color: foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: background,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      margin: const EdgeInsets.all(AppSpacing.base),
      elevation: 6,
      duration: const Duration(seconds: 4),
      action: SnackBarAction(
        label: 'OK',
        textColor: accent,
        onPressed: messenger.hideCurrentSnackBar,
      ),
    );

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }
}
