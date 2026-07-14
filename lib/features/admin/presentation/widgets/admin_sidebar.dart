import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/core/providers/user_session_provider.dart';
import 'package:autodoc/features/auth/presentation/providers/auth_provider.dart';

class AdminSidebar extends StatelessWidget {
  const AdminSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final userSession = context.watch<UserSessionProvider>();
    final user = userSession.userData;

    return Drawer(
      child: Container(
        color: Theme.of(context).colorScheme.surface,
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
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.white24,
                      shape: BoxShape.circle,
                    ),
                    child: const CircleAvatar(
                      radius: 35,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.admin_panel_settings, size: 40, color: Color(0xFF522C81)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user?.nombreCompleto ?? 'Administrador',
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    user?.correo ?? '',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
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
            const Spacer(),
            const Divider(indent: 20, endIndent: 20),
            _buildDrawerItem(
              context,
              icon: Icons.logout,
              label: 'Cerrar Sesión',
              route: '/login',
              isDestructive: true,
              onTap: () async {
                final router = GoRouter.of(context);
                await context.read<AuthProvider>().signOut();
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
    final color = isDestructive 
        ? Colors.red 
        : isSelected 
            ? Theme.of(context).colorScheme.primary 
            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        onTap: onTap ?? () {
          Navigator.pop(context);
          context.go(route);
        },
        leading: Icon(icon, color: color),
        title: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: isSelected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1) : null,
      ),
    );
  }
}
