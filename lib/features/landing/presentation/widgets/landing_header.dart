import 'package:flutter/material.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/utils/l10n_extension.dart';

class LandingHeader extends StatelessWidget {
  const LandingHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return SliverAppBar(
      floating: true,
      pinned: false,
      backgroundColor: Colors.transparent,
      elevation: 0,
      toolbarHeight: 100,
      title: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1100),
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: colors.outline.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              // Logo
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: colors.secondary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.directions_car, color: colors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'AutoDoc',
                    style: AppTextStyles.titleLarge.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Nav Links
              if (MediaQuery.of(context).size.width > 800)
                Row(
                  children: [
                    _NavLink(title: context.l10n.navPlatform),
                    _NavLink(title: context.l10n.navOwners),
                    _NavLink(title: context.l10n.navWorkshops),
                  ],
                ),
              const Spacer(),
              // Auth
              Row(
                children: [
                  TextButton(
                    onPressed: () {},
                    child: Text(
                      context.l10n.navLogin,
                      style: AppTextStyles.labelLarge.copyWith(color: colors.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  AppButton(
                    text: context.l10n.navTryFree,
                    onPressed: () {},
                    size: AppButtonSize.small,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  final String title;
  const _NavLink({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        title,
        style: AppTextStyles.labelLarge.copyWith(
          fontWeight: FontWeight.w500,
          color: context.appColors.textSecondary,
        ),
      ),
    );
  }
}
