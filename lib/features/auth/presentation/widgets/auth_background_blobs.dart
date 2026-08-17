import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_motion.dart';

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
    final reduced = AppMotion.reduced(context);
    final windowClass = AppBreakpoints.of(context);

    // Los blobs son decorativos: en `compact` ocupan casi la pantalla y no
    // aportan nada, asi que se encogen con la clase de ventana en vez de
    // escalarse con `Responsive.size`.
    final smallDiameter = windowClass.isAtLeastExpanded ? 360.0 : 240.0;
    final largeDiameter = windowClass.isAtLeastExpanded ? 480.0 : 320.0;

    return ExcludeSemantics(
      child: Stack(
        children: [
          Positioned(
            top: -100,
            left: -50,
            child: _blob(
              diameter: smallDiameter,
              color: colors.primary.withValues(alpha: isDark ? 0.1 : 0.05),
              reduced: reduced,
              delay: Duration.zero,
            ),
          ),
          Positioned(
            bottom: -50,
            right: -100,
            child: _blob(
              diameter: largeDiameter,
              color: colors.secondary.withValues(alpha: isDark ? 0.1 : 0.05),
              reduced: reduced,
              delay: AppMotion.staggerStep,
            ),
          ),
        ],
      ),
    );
  }

  Widget _blob({
    required double diameter,
    required Color color,
    required bool reduced,
    required Duration delay,
  }) {
    final circle = Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );

    // Reduced motion: se conserva la aparicion por opacidad, se elimina la
    // escala. No es «sin animacion», es «sin desplazamiento».
    if (reduced) {
      return circle.animate().fadeIn(duration: AppMotion.sheetEnter);
    }
    return circle
        .animate()
        .fadeIn(delay: delay, duration: AppMotion.sheetEnter)
        .scale(
          delay: delay,
          duration: AppMotion.sheetEnter,
          curve: AppMotion.easeOut,
        );
  }
}
