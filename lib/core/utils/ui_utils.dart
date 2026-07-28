import 'package:flutter/material.dart';
import 'package:autodoc/core/widgets/app_snackbar.dart';

/// Standardized UI utility for user feedback (snackbars, dialogs).
class UiUtils {
  UiUtils._();

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
