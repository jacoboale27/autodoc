import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/utils/responsive.dart';

class AuthBackgroundBlobs extends StatelessWidget {
  final AppColors colors;
  final bool isDark;

  const AuthBackgroundBlobs({
    super.key,
    required this.colors,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -100,
          left: -50,
          child:
              Container(
                width: Responsive.size(context, 300),
                height: Responsive.size(context, 300),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.primary.withValues(alpha: isDark ? 0.1 : 0.05),
                ),
              ).animate().scale(
                duration: const Duration(seconds: 2),
                curve: Curves.easeOut,
              ),
        ),
        Positioned(
          bottom: -50,
          right: -100,
          child:
              Container(
                width: Responsive.size(context, 400),
                height: Responsive.size(context, 400),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.secondary.withValues(
                    alpha: isDark ? 0.1 : 0.05,
                  ),
                ),
              ).animate().scale(
                delay: const Duration(milliseconds: 500),
                duration: const Duration(seconds: 2),
                curve: Curves.easeOut,
              ),
        ),
      ],
    );
  }
}
