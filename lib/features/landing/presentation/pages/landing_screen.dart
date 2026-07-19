import 'package:flutter/material.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import '../widgets/landing_header.dart';
import '../widgets/hero_section.dart';
import '../widgets/command_center_section.dart';
import '../widgets/value_prop_section.dart';
import '../widgets/landing_footer.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.surface,
      body: Stack(
        children: [
          // Background Gradient Glow
          Positioned(
            top: -200,
            right: -200,
            child: Container(
              width: 600,
              height: 600,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    colors.primary.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          
          const CustomScrollView(
            slivers: [
              LandingHeader(),
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    HeroSection(),
                    CommandCenterSection(),
                    ValuePropSection(),
                    LandingFooter(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}