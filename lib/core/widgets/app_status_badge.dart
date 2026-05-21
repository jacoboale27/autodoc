import 'package:flutter/material.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';

enum AppStatusType { success, warning, error, info }

class AppStatusBadge extends StatelessWidget {
  final String text;
  final AppStatusType type;
  final IconData? icon;

  const AppStatusBadge({
    super.key,
    required this.text,
    this.type = AppStatusType.info,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    Color backgroundColor;
    Color foregroundColor;

    switch (type) {
      case AppStatusType.success:
        backgroundColor = colors.success.withValues(alpha: 0.15);
        foregroundColor = colors.success;
        break;
      case AppStatusType.warning:
        backgroundColor = colors.warning.withValues(alpha: 0.15);
        foregroundColor = colors.warning;
        break;
      case AppStatusType.error:
        backgroundColor = colors.error.withValues(alpha: 0.15);
        foregroundColor = colors.error;
        break;
      case AppStatusType.info:
        backgroundColor = colors.primary.withValues(alpha: 0.15);
        foregroundColor = colors.primary;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: foregroundColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: foregroundColor),
            const SizedBox(width: 4),
          ],
          Text(
            text.toUpperCase(),
            style: AppTextStyles.labelSmall.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
