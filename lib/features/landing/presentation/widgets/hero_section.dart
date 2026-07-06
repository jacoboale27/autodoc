
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/utils/l10n_extension.dart';

class HeroSection extends StatelessWidget {
  const HeroSection({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Container(
      constraints: const BoxConstraints(maxWidth: 1200),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl,
        vertical: 80,
      ),
      child: Flex(
        direction: isDesktop ? Axis.horizontal : Axis.vertical,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Text Content
          Expanded(
            flex: isDesktop ? 6 : 0,
            child: Column(
              crossAxisAlignment: isDesktop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: colors.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: colors.secondary.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    context.l10n.heroBadge,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: colors.secondary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2),
                const SizedBox(height: 24),
                Text(
                  context.l10n.heroTitle,
                  textAlign: isDesktop ? TextAlign.left : TextAlign.center,
                  style: AppTextStyles.displayLarge.copyWith(
                    height: 1.1,
                    fontSize: isDesktop ? 72 : 48,
                  ),
                ).animate().fadeIn(delay: 200.ms, duration: 800.ms).slideY(begin: 0.1),
                const SizedBox(height: 24),
                Text(
                  context.l10n.heroSubtitle,
                  textAlign: isDesktop ? TextAlign.left : TextAlign.center,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: colors.textSecondary,
                    height: 1.6,
                  ),
                ).animate().fadeIn(delay: 400.ms, duration: 800.ms).slideY(begin: 0.1),
                const SizedBox(height: 40),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: isDesktop ? WrapAlignment.start : WrapAlignment.center,
                  children: [
                    AppButton(
                      text: context.l10n.heroStartGarage,
                      onPressed: () {},
                      size: AppButtonSize.large,
                      icon: const Icon(Icons.arrow_forward),
                    ),
                    AppButton(
                      text: context.l10n.heroViewDirectory,
                      onPressed: () {},
                      type: AppButtonType.secondary,
                      size: AppButtonSize.large,
                    ),
                  ],
                ).animate().fadeIn(delay: 600.ms, duration: 800.ms),
              ],
            ),
          ),
          
          if (isDesktop) const SizedBox(width: 40),
          
          // Visual Content (Mockups)
          Expanded(
            flex: isDesktop ? 5 : 0,
            child: Container(
              height: 500,
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Mockup 2 (Back)
                  Positioned(
                    right: 40,
                    bottom: 0,
                    child: _PhoneMockup(
                      image: 'assets/images/garage_screen_lightmode.jpg', 
                      rotate: 0.08,
                      scale: 0.9,
                      opacity: 0.6,
                    ).animate().fadeIn(delay: 800.ms).slideX(begin: 0.2),
                  ),
                  // Mockup 1 (Front)
                  Positioned(
                    left: 20,
                    top: 0,
                    child: _PhoneMockup(
                      image: 'assets/images/dashboard_screen_lightmode.jpg',
                      rotate: -0.1,
                      scale: 1.0,
                    ).animate().fadeIn(delay: 600.ms).slideX(begin: -0.2),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhoneMockup extends StatelessWidget {
  final String image;
  final double rotate;
  final double scale;
  final double opacity;

  const _PhoneMockup({
    required this.image,
    this.rotate = 0,
    this.scale = 1.0,
    this.opacity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotate,
      child: Transform.scale(
        scale: scale,
        child: Opacity(
          opacity: opacity,
          child: Container(
            width: 220,
            height: 460,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(36),
              border: Border.all(color: Colors.white12, width: 8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Image.asset(
                image,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: context.appColors.surfaceContainer,
                  child: const Center(child: Icon(Icons.phone_android, color: Colors.white24)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
