import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/admin_dashboard_provider.dart';
import '../providers/admin_provider.dart';
import '../widgets/admin_sidebar.dart';
import '../widgets/metric_card.dart';
import '../widgets/services_trend_chart.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/widgets/app_card.dart';
import 'package:intl/intl.dart';
import 'package:autodoc/core/utils/responsive.dart';
import 'package:autodoc/core/providers/theme_provider.dart';
import 'package:autodoc/core/providers/language_provider.dart';
import 'package:autodoc/core/utils/l10n_extension.dart';

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
    final userSession = context.watch<UserProfileProvider>();
    final colors = context.appColors;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.adminDashboardTitle),
        centerTitle: true,
        actions: [
          Consumer2<ThemeProvider, LanguageProvider>(
            builder: (context, themeProvider, languageProvider, _) {
              final isDark = themeProvider.themeMode == ThemeMode.dark;
              final isEnglish =
                  languageProvider.currentLocale.languageCode == 'en';
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      isDark
                          ? Icons.light_mode_outlined
                          : Icons.dark_mode_outlined,
                    ),
                    onPressed: () => themeProvider.setThemeMode(
                      isDark ? ThemeMode.light : ThemeMode.dark,
                    ),
                  ),
                  TextButton(
                    onPressed: () => languageProvider.changeLanguage(
                      isEnglish ? 'es' : 'en',
                    ),
                    child: Text(
                      isEnglish ? 'EN' : 'ES',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              );
            },
          ),
        ],
      ),
      drawer: const AdminSidebar(),
      body: provider.isLoading
          ? Center(child: CircularProgressIndicator(color: colors.primary))
          : provider.error != null
          ? Center(child: Text(context.l10n.adminError(provider.error!)))
          : RefreshIndicator(
              color: colors.primary,
              onRefresh: () async {
                provider.fetchMetrics();
                await adminProvider.fetchLogs();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(Responsive.padding(context, 24.0)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWelcomeHeader(context, userSession, colors),
                    const SizedBox(height: 32),
                    _buildSectionTitle(
                      context,
                      context.l10n.adminGlobalMetricsTitle,
                    ),
                    const SizedBox(height: 16),
                    _buildMetricsGrid(context, provider, colors),
                    const SizedBox(height: 32),
                    ServicesTrendChart(
                      serviciosPorMes: Map<String, int>.from(
                        provider.metrics['serviciosPorMes'] ?? {},
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildSectionTitle(
                      context,
                      context.l10n.adminQuickActionsTitle,
                    ),
                    const SizedBox(height: 16),
                    _buildQuickActions(context, colors),
                    const SizedBox(height: 32),
                    _buildSectionTitle(
                      context,
                      context.l10n.adminRecentActivityTitle,
                    ),
                    const SizedBox(height: 16),
                    _buildRecentActivity(context, adminProvider, colors),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildWelcomeHeader(
    BuildContext context,
    UserProfileProvider userSession,
    AppColors colors,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(Responsive.padding(context, 24)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primary, colors.primary.withValues(alpha: 0.75)],
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
            padding: EdgeInsets.all(Responsive.padding(context, 12)),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.admin_panel_settings,
              color: Colors.white,
              size: Responsive.iconSize(context, 28),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.adminDashboardWelcome(
                    userSession.userData?.nombreCompleto ?? 'Admin',
                  ),
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: Responsive.fontSize(context, 20),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.adminDashboardSubtitle,
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: Responsive.fontSize(context, 14),
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

  Widget _buildMetricsGrid(
    BuildContext context,
    AdminDashboardProvider provider,
    AppColors colors,
  ) {
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
          title: context.l10n.adminMetricsUsers,
          value: '${provider.metrics['usuarios']}',
          icon: Icons.people,
          color: colors.primary,
        ),
        MetricCard(
          title: context.l10n.adminMetricsWorkshops,
          value: '${provider.metrics['talleres']}',
          icon: Icons.build,
          color: colors.warning,
        ),
        MetricCard(
          title: context.l10n.adminMetricsVehicles,
          value: '${provider.metrics['vehiculos']}',
          icon: Icons.directions_car,
          color: colors.secondary,
        ),
        MetricCard(
          title: context.l10n.adminMetricsServices,
          value: '${provider.metrics['servicios']}',
          icon: Icons.miscellaneous_services,
          color: colors.secondary,
        ),
        MetricCard(
          title: context.l10n.adminMetricsAlerts,
          value: '${provider.metrics['alertas']}',
          icon: Icons.warning,
          color: colors.error,
        ),
        MetricCard(
          title: context.l10n.adminMetricsReviews,
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
          label: context.l10n.adminQuickActionManageUsers,
          color: colors.primary,
          onTap: () => context.go('/admin/usuarios'),
        ),
        _buildActionChip(
          context,
          icon: Icons.build_circle_outlined,
          label: context.l10n.adminQuickActionManageWorkshops,
          color: colors.warning,
          onTap: () => context.go('/admin/talleres'),
        ),
        _buildActionChip(
          context,
          icon: Icons.rate_review_outlined,
          label: context.l10n.adminQuickActionModerateReviews,
          color: colors.secondary,
          onTap: () => context.go('/admin/resenias'),
        ),
        _buildActionChip(
          context,
          icon: Icons.history_outlined,
          label: context.l10n.adminQuickActionViewLogs,
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
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.padding(context, 16),
            vertical: Responsive.padding(context, 12),
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: Responsive.iconSize(context, 20)),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: Responsive.fontSize(context, 13),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.arrow_forward_ios,
                color: color,
                size: Responsive.iconSize(context, 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivity(
    BuildContext context,
    AdminProvider adminProvider,
    AppColors colors,
  ) {
    final recentLogs = adminProvider.logs.take(5).toList();

    if (recentLogs.isEmpty) {
      return AppCard(
        padding: EdgeInsets.all(Responsive.padding(context, 32)),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.history,
                size: Responsive.iconSize(context, 40),
                color: colors.textSecondary.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 12),
              Text(
                context.l10n.adminNoRecentActivity,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: Responsive.fontSize(context, 14),
                ),
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
            final isDestructive =
                log.accion.contains('SUSPENDER') ||
                log.accion.contains('ELIMINAR') ||
                log.accion.contains('RECHAZAR');
            final accentColor = isDestructive ? colors.error : colors.secondary;

            return ListTile(
              leading: Container(
                padding: EdgeInsets.all(Responsive.padding(context, 8)),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isDestructive
                      ? Icons.warning_amber
                      : Icons.check_circle_outline,
                  color: accentColor,
                  size: Responsive.iconSize(context, 20),
                ),
              ),
              title: Text(
                log.accion.replaceAll('_', ' '),
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 13),
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                log.detalle,
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 12),
                  color: colors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                DateFormat('dd/MM HH:mm').format(log.fecha),
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 11),
                  color: colors.textSecondary.withValues(alpha: 0.6),
                ),
              ),
            );
          }),
          Padding(
            padding: EdgeInsets.all(Responsive.padding(context, 12)),
            child: TextButton.icon(
              onPressed: () => context.go('/admin/logs'),
              icon: Icon(
                Icons.arrow_forward,
                size: Responsive.iconSize(context, 16),
                color: colors.primary,
              ),
              label: Text(
                context.l10n.adminViewAllLogs,
                style: TextStyle(color: colors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
