import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_radius.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/features/auth/presentation/providers/auth_provider.dart';
import 'package:autodoc/core/providers/session_reset.dart';

class AdminSidebar extends StatelessWidget {
  const AdminSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final userSession = context.watch<UserProfileProvider>();
    final user = userSession.userData;
    final colors = context.appColors;

    return Drawer(
      child: Container(
        color: colors.surface,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colors.primary,
                    colors.primary.withValues(alpha: 0.8),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: colors.onPrimary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: CircleAvatar(
                      radius: 35,
                      backgroundColor: colors.onPrimary,
                      child: Icon(
                        Icons.admin_panel_settings,
                        size: 40,
                        color: colors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user?.nombreCompleto ?? 'Administrador',
                    style: AppTextStyles.titleLarge.copyWith(
                      color: colors.onPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    user?.correo ?? '',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: colors.onPrimary.withValues(alpha: 0.8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // La navegacion va en un ListView y no directamente en la Column:
            // la cabecera (~200 dp) mas los seis destinos mas el pie suman
            // unos 700 dp, asi que en cualquier ventana mas baja que eso el
            // `Spacer()` que habia aqui pedia espacio libre inexistente y el
            // Drawer entero desbordaba. Cabecera y "Cerrar sesion" siguen
            // fijos —el pie es lo que no debe irse de la vista al scrollear—
            // y lo unico que se desplaza son los destinos.
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildDrawerItem(
                    context,
                    icon: Icons.dashboard_outlined,
                    label: 'Dashboard',
                    route: '/admin/dashboard',
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.people_outline,
                    label: 'Usuarios',
                    route: '/admin/usuarios',
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.build_circle_outlined,
                    label: 'Talleres',
                    route: '/admin/talleres',
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.verified_outlined,
                    label: 'Verificación',
                    route: '/admin/verificaciones',
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.rate_review_outlined,
                    label: 'Reseñas',
                    route: '/admin/resenias',
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.history_outlined,
                    label: 'Registro de Actividad',
                    route: '/admin/logs',
                  ),
                ],
              ),
            ),
            const Divider(indent: 20, endIndent: 20),
            _buildDrawerItem(
              context,
              icon: Icons.logout,
              label: 'Cerrar Sesión',
              route: '/login',
              isDestructive: true,
              onTap: () async {
                final router = GoRouter.of(context);
                final auth = context.read<AuthProvider>();
                // Mismo motivo que en MechanicSidebar: un admin que cierra
                // sesion tambien deja los providers por usuario escuchando
                // con el uid saliente (hallazgo QA §5).
                clearSessionFrom(context);
                await auth.signOut();
                router.go('/login');
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String route,
    bool isDestructive = false,
    VoidCallback? onTap,
  }) {
    final bool isSelected = GoRouterState.of(context).uri.toString() == route;
    final colors = context.appColors;
    final color = isDestructive
        ? colors.error
        : isSelected
        ? colors.primary
        : colors.textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        onTap:
            onTap ??
            () {
              Navigator.pop(context);
              context.go(route);
            },
        leading: Icon(icon, color: color),
        title: Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: color,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        tileColor: isSelected ? colors.primary.withValues(alpha: 0.1) : null,
      ),
    );
  }
}
