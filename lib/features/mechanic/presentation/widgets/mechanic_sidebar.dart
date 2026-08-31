import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/core/providers/theme_provider.dart';
import 'package:autodoc/core/providers/session_reset.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_radius.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';

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
    final auth = context.read<AuthProvider>();
    if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) {
      Navigator.pop(context);
    }
    // Es el unico logout normal del rol taller: sin esto, ChatProvider,
    // NotificationCenterProvider y la suscripcion por taller de
    // ReparacionProvider siguen vivos con el uid saliente (hallazgo QA §5).
    clearSessionFrom(context);
    await auth.signOut();
    router.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final colors = context.appColors;
    final currentPath = GoRouterState.of(context).uri.path;
    // Una sub-cuenta de empleado (creada por `crearEmpleadoTaller`) tiene
    // `id_taller_propietario` seteado en su propio `usuarios/{uid}` aunque
    // comparta `rol == 'Taller'` con el dueño real: solo el dueño (campo
    // ausente/vacío) puede gestionar otras sub-cuentas, para que un
    // empleado no pueda crear ni desactivar otras cuentas de empleados.
    final idTallerPropietario = context
        .watch<UserProfileProvider>()
        .userData
        ?.idTallerPropietario;
    final esSubCuentaEmpleado =
        idTallerPropietario != null && idTallerPropietario.isNotEmpty;

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        border: Border(
          right: BorderSide(
            color: colors.outline.withValues(alpha: isDark ? 0.3 : 0.5),
          ),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: colors.primary.withValues(alpha: 0.15),
                  child: Icon(Icons.store, color: colors.primary),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AutoDoc',
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        'Panel de Taller',
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: colors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
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
                    onTap: () =>
                        _navigate(context, '/mechanic_service_history'),
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
                  if (!esSubCuentaEmpleado)
                    _buildNavItem(
                      context,
                      icon: Icons.badge_outlined,
                      label: 'Empleados',
                      isActive: currentPath == '/mechanic/empleados',
                      colors: colors,
                      onTap: () => _navigate(context, '/mechanic/empleados'),
                    ),
                  _buildNavItem(
                    context,
                    icon: Icons.inventory_2_outlined,
                    label: 'Catálogo',
                    isActive: currentPath == '/mechanic/catalogo',
                    colors: colors,
                    onTap: () => _navigate(context, '/mechanic/catalogo'),
                  ),
                  _buildNavItem(
                    context,
                    icon: Icons.photo_library_outlined,
                    label: 'Fotos del taller',
                    isActive: currentPath == '/workshop_gallery',
                    colors: colors,
                    onTap: () => _navigate(context, '/workshop_gallery'),
                  ),
                  _buildNavItem(
                    context,
                    icon: Icons.settings_outlined,
                    label: 'Configuración',
                    isActive: currentPath == '/workshop_settings',
                    colors: colors,
                    onTap: () => _navigate(context, '/workshop_settings'),
                  ),
                ],
              ),
            ),
          ),
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
          const SizedBox(height: AppSpacing.base),
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
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: isActive && !isDestructive
            ? activeColor.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: isActive && !isDestructive
            ? Border(right: BorderSide(color: activeColor, width: 4))
            : null,
      ),
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: titleColor,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
