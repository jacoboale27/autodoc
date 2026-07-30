import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:autodoc/core/theme/app_colors.dart';

enum SnackbarType { success, error, info }

class AppSnackbar {
  static void show(
    BuildContext context,
    String message, {
    SnackbarType type = SnackbarType.info,
  }) {
    final colors = context.appColors;
    // Capturamos el ScaffoldMessenger AHORA, mientras el context todavía es
    // válido: muchas llamadas hacen Navigator.pop justo antes de mostrar el
    // snackbar, y si buscáramos el ScaffoldMessenger dentro del onPressed
    // (que se ejecuta después, al tocar "OK"), el context ya podría estar
    // desmontado y el botón no haría nada.
    final messenger = ScaffoldMessenger.of(context);

    Color backgroundColor;
    IconData icon;

    switch (type) {
      case SnackbarType.success:
        backgroundColor = colors.success;
        icon = Icons.check_circle_outline;
        break;
      case SnackbarType.error:
        backgroundColor = colors.error;
        icon = Icons.error_outline;
        break;
      case SnackbarType.info:
        backgroundColor = colors.primary;
        icon = Icons.info_outline;
        break;
    }

    final snackBar = SnackBar(
      content: Row(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: backgroundColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.all(16),
      elevation: 6,
      duration: const Duration(seconds: 4),
      action: SnackBarAction(
        label: 'OK',
        textColor: Colors.white,
        onPressed: messenger.hideCurrentSnackBar,
      ),
    );

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }
}
