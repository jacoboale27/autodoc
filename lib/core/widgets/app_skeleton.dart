import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:autodoc/core/theme/app_colors.dart';

class AppSkeleton extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;

  const AppSkeleton({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 12,
  });

  factory AppSkeleton.card({double height = 120}) {
    return AppSkeleton(
      width: double.infinity,
      height: height,
      borderRadius: 16,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark
        ? colors.surfaceContainer
        : colors.surfaceContainer.withValues(alpha: 0.9);
    final highlightColor = isDark
        ? colors.primary.withValues(alpha: 0.12)
        : colors.surface;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}
