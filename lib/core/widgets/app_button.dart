import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/theme/app_radius.dart';

enum AppButtonType { primary, secondary, text }
enum AppButtonSize { small, medium, large }

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final AppButtonType type;
  final AppButtonSize size;
  final bool isLoading;
  final bool hapticFeedback;
  final Widget? icon;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.type = AppButtonType.primary,
    this.size = AppButtonSize.medium,
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
    List<Color>? gradientColors;

    switch (type) {
      case AppButtonType.primary:
        backgroundColor = colors.primary;
        foregroundColor = colors.onPrimary;
        gradientColors = [colors.primary, colors.primary.withValues(alpha: 0.85)];
        break;
      case AppButtonType.secondary:
        backgroundColor = colors.secondary;
        foregroundColor = colors.onSecondary;
        break;
      case AppButtonType.text:
        backgroundColor = Colors.transparent;
        foregroundColor = colors.primary;
        break;
    }

    // Determine padding and text style based on size
    EdgeInsets padding;
    TextStyle textStyle;
    double iconSize;

    switch (size) {
      case AppButtonSize.small:
        padding = const EdgeInsets.symmetric(vertical: 8, horizontal: 16);
        textStyle = AppTextStyles.labelMedium;
        iconSize = 16;
        break;
      case AppButtonSize.medium:
        padding = const EdgeInsets.symmetric(vertical: 14, horizontal: 24);
        textStyle = AppTextStyles.titleSmall;
        iconSize = 20;
        break;
      case AppButtonSize.large:
        padding = const EdgeInsets.symmetric(vertical: 18, horizontal: 32);
        textStyle = AppTextStyles.titleMedium;
        iconSize = 24;
        break;
    }

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.full),
    );

    final textWidget = Text(
      text,
      style: textStyle.copyWith(color: foregroundColor),
    );

    Widget childContent;
    if (isLoading) {
      childContent = SizedBox(
        height: iconSize,
        width: iconSize,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
        ),
      );
    } else if (icon != null) {
      childContent = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconTheme(
            data: IconThemeData(size: iconSize, color: foregroundColor),
            child: icon!,
          ),
          const SizedBox(width: 8),
          textWidget,
        ],
      );
    } else {
      childContent = textWidget;
    }

    Widget buttonContent = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradientColors == null ? backgroundColor : null,
        gradient: gradientColors != null
            ? LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
      ),
      alignment: Alignment.center,
      child: childContent,
    );

    if (isLoading && type != AppButtonType.text) {
      buttonContent = buttonContent.animate(onPlay: (c) => c.repeat()).shimmer(
            duration: 1500.ms,
            color: Colors.white.withValues(alpha: 0.2),
          );
    }

    if (type == AppButtonType.text) {
      return TextButton(
        onPressed: _handlePress,
        style: TextButton.styleFrom(
          foregroundColor: foregroundColor,
          padding: EdgeInsets.zero,
          shape: shape,
        ),
        child: buttonContent,
      );
    }

    return ElevatedButton(
      onPressed: _handlePress,
      style: ElevatedButton.styleFrom(
        foregroundColor: foregroundColor,
        backgroundColor: Colors.transparent,
        shadowColor: type == AppButtonType.text ? Colors.transparent : colors.primary.withValues(alpha: 0.3),
        elevation: type == AppButtonType.text ? 0 : 0, // Let hover elevation do the work if needed
        padding: EdgeInsets.zero,
        shape: shape,
      ),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: buttonContent,
      ),
    );
  }
}
