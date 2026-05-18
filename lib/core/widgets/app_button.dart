import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:autodoc/core/theme/app_colors.dart';

enum AppButtonType { primary, secondary, text }

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final AppButtonType type;
  final bool isLoading;
  final bool hapticFeedback;
  final Widget? icon;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.type = AppButtonType.primary,
    this.isLoading = false,
    this.hapticFeedback = true,
    this.icon,
  });

  void _handlePress() {
    if (isLoading || onPressed == null) return;
    if (hapticFeedback) {
      HapticFeedback.lightImpact();
    }
    onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    Color backgroundColor;
    Color foregroundColor;

    switch (type) {
      case AppButtonType.primary:
        backgroundColor = colors.primary;
        foregroundColor = Colors.white;
        break;
      case AppButtonType.secondary:
        backgroundColor = colors.secondary;
        foregroundColor = colors.primary;
        break;
      case AppButtonType.text:
        backgroundColor = Colors.transparent;
        foregroundColor = colors.primary;
        break;
    }

    final buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      elevation: type == AppButtonType.text ? 0 : 2,
      shadowColor: type == AppButtonType.text ? Colors.transparent : colors.primary.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
    );

    final textWidget = Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );

    Widget child;
    if (isLoading) {
      child = SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
        ),
      );
    } else if (icon != null) {
      child = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon!,
          const SizedBox(width: 8),
          textWidget,
        ],
      );
    } else {
      child = textWidget;
    }

    if (type == AppButtonType.text) {
      return TextButton(
        onPressed: _handlePress,
        style: TextButton.styleFrom(
          foregroundColor: foregroundColor,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: child,
      );
    }

    return ElevatedButton(
      onPressed: _handlePress,
      style: buttonStyle,
      child: child,
    );
  }
}
