import 'package:flutter/material.dart';
import 'package:autodoc/core/widgets/app_skeleton.dart';

/// Placeholder layouts built from [AppSkeleton] for common loading states.
class AppSkeletonLayouts {
  AppSkeletonLayouts._();

  static Widget listCards({
    int itemCount = 4,
    double cardHeight = 120,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    return ListView.separated(
      padding: padding,
      itemCount: itemCount,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) => AppSkeleton.card(height: cardHeight),
    );
  }

  static Widget workshopList({int itemCount = 3}) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSkeleton.card(height: 160),
          const SizedBox(height: 8),
          AppSkeleton.card(height: 72),
        ],
      ),
    );
  }

  static Widget dashboard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSkeleton.card(height: 200),
          const SizedBox(height: 32),
          const AppSkeleton(width: 140, height: 18, borderRadius: 8),
          const SizedBox(height: 16),
          AppSkeleton.card(height: 88),
          const SizedBox(height: 12),
          AppSkeleton.card(height: 88),
        ],
      ),
    );
  }
}
