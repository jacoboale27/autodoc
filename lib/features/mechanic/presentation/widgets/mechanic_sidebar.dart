import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/core/providers/theme_provider.dart';
import 'package:autodoc/core/theme/app_colors.dart';

import 'package:autodoc/features/auth/presentation/providers/auth_provider.dart';

class MechanicSidebar extends StatelessWidget {
  const MechanicSidebar({super.key});

  void _navigate(BuildContext context, String route) {
    if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) {
      Navigator.pop(context);
    }
    if (GoRouterState.of(context).uri.path != route) {
      context.go(route);
    }
  }

  Future<void> _signOut(BuildContext context) async {
    final router = GoRouter.of(context);
    if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) {
      Navigator.pop(context);
    }
    await context.read<AuthProvider>().signOut();
    router.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final colors = context.appColors;
    final currentPath = GoRouterState.of(context).uri.path;

    final bgColor = isDark
        ? colors.surfaceContainer
        : Colors.white.withValues(alpha: 0.7);

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          right: BorderSide(
            color: isDark
                ? Colors.white10
                : Colors.white.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: colors.primary.withValues(alpha: 0.15),
                  child: Icon(Icons.store, color: colors.primary),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AutoDoc',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: colors.textPrimary,
                      ),
                    ),
                    Text(
                      'Panel de Taller',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildNavItem(
            context,
            icon: Icons.dashboard,
            label: 'Dashboard',
            isActive: currentPath == '/mechanic_dashboard',
            colors: colors,
            onTap: () => _navigate(context, '/mechanic_dashboard'),
          ),
          _buildNavItem(
            context,
            icon: Icons.search,
            label: 'Buscar Vehículo',
            isActive: currentPath == '/mechanic_search',
            colors: colors,
            onTap: () => _navigate(context, '/mechanic_search'),
          ),
          _buildNavItem(
            context,
            icon: Icons.history,
            label: 'Mis Servicios',
            isActive: currentPath == '/mechanic_service_history',
            colors: colors,
            onTap: () => _navigate(context, '/mechanic_service_history'),
          ),
          _buildNavItem(
            context,
            icon: Icons.dashboard_customize,
            label: 'Reparaciones',
            isActive: currentPath == '/mechanic_reparaciones',
            colors: colors,
            onTap: () => _navigate(context, '/mechanic_reparaciones'),
          ),
          _buildNavItem(
            context,
            icon: Icons.star_outline,
            label: 'Mis Reseñas',
            isActive: currentPath == '/mechanic_reviews',
            colors: colors,
            onTap: () => _navigate(context, '/mechanic_reviews'),
          ),
          _buildNavItem(
            context,
            icon: Icons.chat_bubble_outline,
            label: 'Mensajes',
            isActive: currentPath == '/chat_list',
            colors: colors,
            onTap: () => _navigate(context, '/chat_list'),
          ),
          _buildNavItem(
            context,
            icon: Icons.settings_outlined,
            label: 'Configuración',
            isActive: currentPath == '/workshop_settings',
            colors: colors,
            onTap: () => _navigate(context, '/workshop_settings'),
          ),
          const Spacer(),
          const Divider(indent: 20, endIndent: 20),
          _buildNavItem(
            context,
            icon: Icons.logout,
            label: 'Cerrar Sesión',
            isActive: false,
            colors: colors,
            isDestructive: true,
            onTap: () => _signOut(context),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isActive,
    required AppColors colors,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final activeColor = isDestructive ? colors.error : colors.primary;
    final iconColor = isDestructive
        ? colors.error
        : isActive
        ? colors.primary
        : colors.textSecondary;
    final titleColor = isDestructive
        ? colors.error
        : isActive
        ? colors.textPrimary
        : colors.textSecondary;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isActive && !isDestructive
            ? activeColor.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isActive && !isDestructive
            ? Border(right: BorderSide(color: activeColor, width: 4))
            : null,
      ),
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(
          label,
          style: GoogleFonts.inter(
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: titleColor,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
