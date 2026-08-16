import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:autodoc/core/widgets/app_snackbar.dart';

/// Standardized UI utility for user feedback (snackbars, dialogs).
class UiUtils {
  UiUtils._();

  /// Opens [urlString] in the platform's external handler (browser, mail
  /// client, etc.). Misma guarda de fallo introducida en `about_screen.dart`
  /// (Fase 7 Task 2): si no se pudo abrir, no se lanza excepcion — el
  /// llamador decide como avisar al usuario.
  static Future<void> openExternalUrl(String urlString) async {
    final url = Uri.parse(urlString);
    await canLaunchUrl(url) && await launchUrl(url);
  }

  /// Shows an error snackbar with standard error styling.
  static void showErrorSnackbar(BuildContext context, String message) {
    if (!context.mounted) return;
    AppSnackbar.show(context, message, type: SnackbarType.error);
  }

  /// Shows a success snackbar with standard success styling.
  static void showSuccessSnackbar(BuildContext context, String message) {
    if (!context.mounted) return;
    AppSnackbar.show(context, message, type: SnackbarType.success);
  }

  /// Shows an informational snackbar with standard primary styling.
  static void showInfoSnackbar(BuildContext context, String message) {
    if (!context.mounted) return;
    AppSnackbar.show(context, message, type: SnackbarType.info);
  }
}
