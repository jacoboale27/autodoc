import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_shadows.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/utils/responsive.dart';
import 'package:autodoc/core/widgets/acciones_de_cabecera.dart';
import 'package:autodoc/core/widgets/navigation/app_nav_destination.dart';
import 'package:autodoc/features/chat/presentation/widgets/aviso_mensajes_nuevos.dart';

class AppTopNavBar extends StatelessWidget {
  const AppTopNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final currentPath = GoRouterState.of(context).uri.path;

    return Container(
      height: Responsive.size(context, 70),
      margin: EdgeInsets.all(Responsive.padding(context, 16)),
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.padding(context, 24),
      ),
      decoration: BoxDecoration(
        color: colors.surfaceContainer.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.outline.withValues(alpha: 0.3)),
        boxShadow: Theme.of(context).brightness == Brightness.dark
            ? AppShadows.darkSm
            : AppShadows.lightSm,
      ),
      child: Row(
        children: [
          // Logo
          InkWell(
            onTap: () => context.go('/dashboard'),
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                Container(
                  width: Responsive.size(context, 32),
                  height: Responsive.size(context, 32),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: EdgeInsets.all(Responsive.padding(context, 4)),
                  child: SvgPicture.asset('assets/logo/autodoc_isotype.svg'),
                ),
                SizedBox(width: Responsive.padding(context, 12)),
                Text(
                  'AutoDoc',
                  style: AppTextStyles.titleLarge.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: colors.textPrimary,
                    fontSize: Responsive.fontSize(context, 20),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final destination in AppNavDestinations.owner)
                      _TopNavLink(
                        route: destination.route,
                        title: destination.label,
                        icon: destination.icon,
                        semanticLabel: destination.semanticLabel,
                        isActive: currentPath == destination.route,
                        onTap: () => context.go(destination.route),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Tema, idioma, campana y avatar: los mismos controles que llevan
          // todas las demás pantallas (`AccionesDeCabecera`).
          const AccionesDeCabecera(mostrarAvatar: true),
        ],
      ),
    );
  }
}

class _TopNavLink extends StatelessWidget {
  final String route;
  final String title;
  final IconData icon;
  final String semanticLabel;
  final bool isActive;
  final VoidCallback onTap;

  const _TopNavLink({
    required this.route,
    required this.title,
    required this.icon,
    required this.semanticLabel,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final color = isActive ? colors.primary : colors.textSecondary;

    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.padding(context, 16),
            vertical: Responsive.padding(context, 8),
          ),
          child: Row(
            children: [
              IconoConMensajesSinLeer(
                route: route,
                icono: Icon(
                  icon,
                  color: color,
                  size: Responsive.iconSize(context, 18),
                ),
              ),
              SizedBox(width: Responsive.padding(context, 8)),
              Text(
                title,
                style: AppTextStyles.labelLarge.copyWith(
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  color: color,
                  fontSize: Responsive.fontSize(context, 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
