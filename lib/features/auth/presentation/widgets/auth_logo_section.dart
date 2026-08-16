import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_motion.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/utils/responsive.dart';
import 'package:autodoc/core/utils/l10n_extension.dart';

class AuthLogoSection extends StatelessWidget {
  final AppColors colors;

  const AuthLogoSection({super.key, required this.colors});

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: SvgPicture.asset(
            'assets/logo/autodoc_isotype.svg',
            width: Responsive.iconSize(context, 48),
            height: Responsive.iconSize(context, 48),
            semanticsLabel: 'AutoDoc',
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'AutoDoc',
          style: AppTextStyles.headlineLarge.copyWith(
            color: colors.textPrimary,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.authCopilotSubtitle,
          style: AppTextStyles.bodyMedium.copyWith(color: colors.textSecondary),
        ),
      ],
    );

    if (AppMotion.reduced(context)) {
      return content.animate().fadeIn(duration: AppMotion.sheetEnter);
    }
    return content
        .animate()
        .fadeIn(duration: AppMotion.sheetEnter)
        .slideY(begin: -0.2, end: 0, curve: AppMotion.easeOut);
  }
}
