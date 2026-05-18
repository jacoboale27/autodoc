import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/admin_dashboard_provider.dart';
import '../providers/admin_provider.dart';
import '../widgets/admin_sidebar.dart';
import '../widgets/metric_card.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/widgets/app_card.dart';
import 'package:intl/intl.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminDashboardProvider>().fetchMetrics();
      context.read<AdminProvider>().fetchLogs();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminDashboardProvider>();
    final adminProvider = context.watch<AdminProvider>();
    final authProvider = context.watch<AuthProvider>();
    final colors = context.appColors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Administrador'),
        centerTitle: true,
      ),
      drawer: const AdminSidebar(),
      body: provider.isLoading
          ? Center(child: CircularProgressIndicator(color: colors.primary))
          : provider.error != null
              ? Center(child: Text('Error: ${provider.error}'))
              : RefreshIndicator(
                  color: colors.primary,
                  onRefresh: () async {
                    await provider.fetchMetrics();
                    await adminProvider.fetchLogs();
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildWelcomeHeader(context, authProvider, colors),
                        const SizedBox(height: 32),
                        _buildSectionTitle(context, 'Métricas Globales'),
                        const SizedBox(height: 16),
                        _buildMetricsGrid(context, provider, colors),
                        const SizedBox(height: 32),
                        _buildSectionTitle(context, 'Acciones Rápidas'),
                        const SizedBox(height: 16),
                        _buildQuickActions(context, colors),
                        const SizedBox(height: 32),
                        _buildSectionTitle(context, 'Actividad Reciente'),
                        const SizedBox(height: 16),
                        _buildRecentActivity(context, adminProvider, colors),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildWelcomeHeader(BuildContext context, AuthProvider authProvider, AppColors colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primary,
            colors.primary.withValues(alpha: 0.75),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¡Bienvenido, ${authProvider.userData?.nombreCompleto ?? 'Admin'}!',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Panel de control administrativo',
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
    );
  }

  Widget _buildMetricsGrid(BuildContext context, AdminDashboardProvider provider, AppColors colors) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth > 900 ? 3 : (screenWidth > 600 ? 2 : 1);

    return GridView.count(
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 20,
      mainAxisSpacing: 20,
      shrinkWrap: true,
      childAspectRatio: 1.6,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        MetricCard(
          title: 'Usuarios',
          value: '${provider.metrics['usuarios']}',
          icon: Icons.people,
          color: colors.primary,
        ),
        MetricCard(
          title: 'Talleres',
          value: '${provider.metrics['talleres']}',
          icon: Icons.build,
          color: colors.warning,
        ),
        MetricCard(
          title: 'Vehículos',
          value: '${provider.metrics['vehiculos']}',
          icon: Icons.directions_car,
          color: colors.secondary,
        ),
        MetricCard(
          title: 'Servicios',
          value: '${provider.metrics['servicios']}',
          icon: Icons.miscellaneous_services,
          color: colors.secondary,
        ),
        MetricCard(
          title: 'Alertas',
          value: '${provider.metrics['alertas']}',
          icon: Icons.warning,
          color: colors.error,
        ),
        MetricCard(
          title: 'Reseñas',
          value: '${provider.metrics['resenias']}',
          icon: Icons.rate_review,
          color: colors.primary,
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context, AppColors colors) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildActionChip(
          context,
          icon: Icons.people_outline,
          label: 'Gestionar Usuarios',
          color: colors.primary,
          onTap: () => context.go('/admin/usuarios'),
        ),
        _buildActionChip(
          context,
          icon: Icons.build_circle_outlined,
          label: 'Gestionar Talleres',
          color: colors.warning,
          onTap: () => context.go('/admin/talleres'),
        ),
        _buildActionChip(
          context,
          icon: Icons.rate_review_outlined,
          label: 'Moderar Reseñas',
          color: colors.secondary,
          onTap: () => context.go('/admin/resenias'),
        ),
        _buildActionChip(
          context,
          icon: Icons.history_outlined,
          label: 'Ver Actividad',
          color: colors.primary,
          onTap: () => context.go('/admin/logs'),
        ),
      ],
    );
  }

  Widget _buildActionChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.arrow_forward_ios, color: color, size: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivity(BuildContext context, AdminProvider adminProvider, AppColors colors) {
    final recentLogs = adminProvider.logs.take(5).toList();

    if (recentLogs.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.history, size: 40, color: colors.textSecondary.withValues(alpha: 0.4)),
              const SizedBox(height: 12),
              Text(
                'Sin actividad reciente',
                style: TextStyle(color: colors.textSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          ...recentLogs.map((log) {
            final isDestructive = log.accion.contains('SUSPENDER') ||
                log.accion.contains('ELIMINAR') ||
                log.accion.contains('RECHAZAR');
            final accentColor = isDestructive ? colors.error : colors.secondary;

            return ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isDestructive ? Icons.warning_amber : Icons.check_circle_outline,
                  color: accentColor,
                  size: 20,
                ),
              ),
              title: Text(
                log.accion.replaceAll('_', ' '),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                log.detalle,
                style: TextStyle(fontSize: 12, color: colors.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                DateFormat('dd/MM HH:mm').format(log.fecha),
                style: TextStyle(fontSize: 11, color: colors.textSecondary.withValues(alpha: 0.6)),
              ),
            );
          }),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextButton.icon(
              onPressed: () => context.go('/admin/logs'),
              icon: Icon(Icons.arrow_forward, size: 16, color: colors.primary),
              label: Text(
                'Ver todo el registro',
                style: TextStyle(color: colors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
