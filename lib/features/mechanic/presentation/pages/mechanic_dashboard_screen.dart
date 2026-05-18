import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:autodoc/features/auth/presentation/providers/auth_provider.dart';
import 'package:autodoc/features/mechanic/presentation/widgets/mechanic_sidebar.dart';
import 'package:autodoc/core/models/service_record_model.dart';
import 'package:autodoc/core/widgets/app_card.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:intl/intl.dart';

class MechanicDashboardScreen extends StatefulWidget {
  const MechanicDashboardScreen({super.key});

  @override
  State<MechanicDashboardScreen> createState() => _MechanicDashboardScreenState();
}

class _MechanicDashboardScreenState extends State<MechanicDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 700;
    final colors = context.appColors;
    final theme = Theme.of(context);
    final authProvider = context.watch<AuthProvider>();
    final userData = authProvider.userData;
    final mechanicName = userData?.nombreCompleto ?? 'Mecánico';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: isMobile
          ? AppBar(
              backgroundColor: theme.colorScheme.surface,
              elevation: 0,
              title: Text(
                'Panel de Taller',
                style: GoogleFonts.inter(
                  color: colors.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              iconTheme: IconThemeData(color: colors.primary),
            )
          : null,
      drawer: isMobile ? const Drawer(child: MechanicSidebar()) : null,
      body: Row(
        children: [
          if (!isMobile) const MechanicSidebar(),
          Expanded(
            child: Column(
              children: [
                if (!isMobile) _buildTopBar(colors, theme, mechanicName),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isMobile ? 16 : 32),
                    child: Center(
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: isMobile ? double.infinity : 1000,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildWelcomeHeader(mechanicName, colors),
                            const SizedBox(height: 24),
                            _buildQuickActions(colors, isMobile),
                            const SizedBox(height: 32),
                            _buildDashboardMetrics(colors, isMobile, userData?.idUsuario ?? ''),
                            const SizedBox(height: 32),
                            _buildRecentServices(colors, userData?.idUsuario ?? ''),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(AppColors colors, ThemeData theme, String mechanicName) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: colors.textSecondary.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'DASHBOARD',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w900,
              fontSize: 20,
              color: colors.primary,
              letterSpacing: -0.5,
            ),
          ),
          Row(
            children: [
              Icon(Icons.notifications_none, color: colors.textSecondary),
              const SizedBox(width: 16),
              CircleAvatar(
                radius: 18,
                backgroundColor: colors.primary,
                child: Text(
                  mechanicName.isNotEmpty ? mechanicName[0].toUpperCase() : 'M',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeHeader(String mechanicName, AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hola, $mechanicName 👋',
          style: GoogleFonts.inter(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: colors.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Aquí tienes un resumen de la actividad de tu taller.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(AppColors colors, bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primary, colors.primary.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Atención Rápida',
                  style: GoogleFonts.inter(
                    color: colors.secondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Inicia un nuevo servicio buscando la placa del vehículo.',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: isMobile ? 14 : 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          AppButton(
            text: 'Buscar',
            onPressed: () => context.push('/mechanic_search'),
            icon: const Icon(Icons.search, size: 18, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardMetrics(AppColors colors, bool isMobile, String tallerId) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Usuarios')
          .doc(tallerId)
          .snapshots(),
      builder: (context, userSnapshot) {
        final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
        final promedio = userData?['calificacion_promedio']?.toDouble() ?? 0.0;
        final totalResenias = userData?['total_resenias'] ?? 0;

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('servicios')
              .where('id_taller', isEqualTo: tallerId)
              .snapshots(),
          builder: (context, snapshot) {
            final totalServicios = snapshot.hasData ? snapshot.data!.docs.length : 0;

            return LayoutBuilder(builder: (context, constraints) {
              final double cardWidth =
                  isMobile ? constraints.maxWidth : (constraints.maxWidth - 48) / 3;

              return Wrap(
                spacing: 24,
                runSpacing: 24,
                children: [
                  _buildMetricCard(
                    title: 'Servicios Realizados',
                    value: totalServicios.toString(),
                    icon: Icons.build_circle,
                    accentColor: colors.secondary,
                    colors: colors,
                    width: cardWidth,
                  ),
                  _buildMetricCard(
                    title: 'Calificación',
                    value: promedio > 0 ? promedio.toStringAsFixed(1) : '—',
                    icon: Icons.star_rounded,
                    accentColor: colors.warning,
                    colors: colors,
                    width: cardWidth,
                  ),
                  _buildMetricCard(
                    title: 'Reseñas',
                    value: totalResenias.toString(),
                    icon: Icons.rate_review_outlined,
                    accentColor: colors.primary,
                    colors: colors,
                    width: cardWidth,
                    onTap: () => context.push('/mechanic_reviews'),
                  ),
                ],
              );
            });
          },
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color accentColor,
    required AppColors colors,
    required double width,
    VoidCallback? onTap,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(24),
      margin: EdgeInsets.zero,
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: accentColor, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: colors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: GoogleFonts.inter(
                      color: colors.primary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentServices(AppColors colors, String tallerId) {
    return AppCard(
      padding: const EdgeInsets.all(24),
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Servicios Recientes',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: colors.primary,
                ),
              ),
              Icon(Icons.history, color: colors.textSecondary),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('servicios')
                .where('id_taller', isEqualTo: tallerId)
                .orderBy('fecha', descending: true)
                .limit(5)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(color: colors.primary),
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      'No hay servicios registrados aún.',
                      style: GoogleFonts.inter(color: colors.textSecondary),
                    ),
                  ),
                );
              }

              final records = snapshot.data!.docs
                  .map((d) => ServiceRecordModel.fromMap(
                      d.data() as Map<String, dynamic>, d.id))
                  .toList();

              return Column(
                children: records.map((r) => _buildServiceTile(r, colors)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildServiceTile(ServiceRecordModel record, AppColors colors) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.primary.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.build_circle, color: colors.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.tipoServicio ?? 'Servicio',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                    fontSize: 16,
                  ),
                ),
                Text(
                  DateFormat('dd MMM yyyy').format(record.fecha),
                  style: GoogleFonts.inter(
                    color: colors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (record.costo != null && record.costo! > 0)
            Text(
              '\$${record.costo!.toStringAsFixed(2)}',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                color: colors.secondary,
                fontSize: 16,
              ),
            ),
        ],
      ),
    );
  }
}
