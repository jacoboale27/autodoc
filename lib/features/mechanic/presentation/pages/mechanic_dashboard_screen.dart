import 'package:flutter/material.dart';
import 'package:autodoc/core/constants/firestore_collections.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/features/mechanic/presentation/widgets/mechanic_sidebar.dart';
import 'package:autodoc/core/models/service_record_model.dart';
import 'package:autodoc/core/widgets/app_card.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/widgets/notification_bell_button.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:autodoc/core/utils/responsive.dart';
import 'package:autodoc/core/providers/theme_provider.dart';
import 'package:autodoc/core/providers/language_provider.dart';
import 'package:fl_chart/fl_chart.dart';

class MechanicDashboardScreen extends StatefulWidget {
  const MechanicDashboardScreen({super.key});

  @override
  State<MechanicDashboardScreen> createState() =>
      _MechanicDashboardScreenState();
}

class _MechanicDashboardScreenState extends State<MechanicDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 700;
    final colors = context.appColors;
    final theme = Theme.of(context);
    final userSession = context.watch<UserProfileProvider>();
    final userData = userSession.userData;

    if (userData == null || userData.idUsuario.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final mechanicName = userData.nombreCompleto;

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
                  fontSize: Responsive.fontSize(context, 16),
                  fontWeight: FontWeight.bold,
                ),
              ),
              iconTheme: IconThemeData(color: colors.primary),
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
                            color: colors.primary,
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
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: colors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const NotificationBellButton(),
                      ],
                    );
                  },
                ),
              ],
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
                            _buildDashboardMetrics(
                              colors,
                              isMobile,
                              userData.idUsuario,
                            ),
                            const SizedBox(height: 32),
                            _buildIncomeChartSection(
                              colors,
                              isMobile,
                              userData.idUsuario,
                            ),
                            const SizedBox(height: 32),
                            _buildRecentServices(colors, userData.idUsuario),
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
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.padding(context, 32),
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: colors.textSecondary.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'DASHBOARD',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w900,
              fontSize: Responsive.fontSize(context, 20),
              color: colors.primary,
              letterSpacing: -0.5,
            ),
          ),
          Row(
            children: [
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
                          color: colors.textSecondary,
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
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(width: 16),
              NotificationBellButton(
                readIcon: Icons.notifications_none,
                readColor: colors.textSecondary,
              ),
              const SizedBox(width: 16),
              CircleAvatar(
                radius: 18,
                backgroundColor: colors.primary,
                child: Text(
                  mechanicName.isNotEmpty ? mechanicName[0].toUpperCase() : 'M',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: Responsive.fontSize(context, 12),
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
            fontSize: Responsive.fontSize(context, 28),
            fontWeight: FontWeight.bold,
            color: colors.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Aquí tienes un resumen de la actividad de tu taller.',
          style: GoogleFonts.inter(
            fontSize: Responsive.fontSize(context, 14),
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(AppColors colors, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(Responsive.padding(context, 24)),
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
                    fontSize: Responsive.fontSize(context, 14),
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
            icon: Icon(
              Icons.search,
              size: Responsive.iconSize(context, 18),
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardMetrics(
    AppColors colors,
    bool isMobile,
    String tallerId,
  ) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection(FirestoreCollections.usuarios)
          .doc(tallerId)
          .snapshots(),
      builder: (context, userSnapshot) {
        final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
        final promedio = userData?['calificacion_promedio']?.toDouble() ?? 0.0;
        final totalResenias = userData?['total_resenias'] ?? 0;

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection(FirestoreCollections.servicios)
              .where('id_taller', isEqualTo: tallerId)
              .snapshots(),
          builder: (context, snapshot) {
            final allServicios = snapshot.hasData ? snapshot.data!.docs : [];
            final totalServicios = allServicios.length;

            final vehiculosUnicos = <String>{};
            int serviciosMesActual = 0;
            double ingresosMesActual = 0;
            double ingresosMesAnterior = 0;
            final now = DateTime.now();
            final pastMonth = DateTime(now.year, now.month - 1);

            for (var doc in allServicios) {
              final data = doc.data() as Map<String, dynamic>;
              vehiculosUnicos.add(data['id_vehiculo'] ?? '');
              final double costo = data['costo'] != null
                  ? (data['costo'] is int
                        ? (data['costo'] as int).toDouble()
                        : data['costo'] as double)
                  : 0.0;

              if (data['fecha'] != null) {
                final fecha = (data['fecha'] as Timestamp).toDate();
                if (fecha.year == now.year && fecha.month == now.month) {
                  serviciosMesActual++;
                  ingresosMesActual += costo;
                } else if (fecha.year == pastMonth.year &&
                    fecha.month == pastMonth.month) {
                  ingresosMesAnterior += costo;
                }
              }
            }

            String variacionIngresos = '';
            if (ingresosMesAnterior > 0) {
              final diff = ingresosMesActual - ingresosMesAnterior;
              final pct = (diff / ingresosMesAnterior) * 100;
              variacionIngresos =
                  '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%';
            } else if (ingresosMesActual > 0) {
              variacionIngresos = '+100%';
            } else {
              variacionIngresos = '0%';
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                final double cardWidth = isMobile
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 48) / 3;

                return Wrap(
                  spacing: 24,
                  runSpacing: 24,
                  children: [
                    _buildMetricCard(
                      title: 'Ingresos (Mes)',
                      value: '\$${ingresosMesActual.toStringAsFixed(2)}',
                      icon: Icons.attach_money,
                      accentColor: colors.success,
                      colors: colors,
                      width: cardWidth,
                      subtitle: variacionIngresos.isNotEmpty
                          ? '$variacionIngresos vs mes ant.'
                          : null,
                    ),
                    _buildMetricCard(
                      title: 'Servicios (Mes)',
                      value: serviciosMesActual.toString(),
                      icon: Icons.calendar_today,
                      accentColor: colors.secondary,
                      colors: colors,
                      width: cardWidth,
                    ),
                    _buildMetricCard(
                      title: 'Total Servicios',
                      value: totalServicios.toString(),
                      icon: Icons.build_circle,
                      accentColor: colors.primary,
                      colors: colors,
                      width: cardWidth,
                      onTap: () => context.push('/mechanic_service_history'),
                    ),
                    _buildMetricCard(
                      title: 'Vehículos Atendidos',
                      value: vehiculosUnicos.length.toString(),
                      icon: Icons.directions_car,
                      accentColor: colors.success,
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
              },
            );
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
    String? subtitle,
  }) {
    return AppCard(
      padding: EdgeInsets.all(Responsive.padding(context, 24)),
      margin: EdgeInsets.zero,
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(Responsive.padding(context, 16)),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: accentColor,
                size: Responsive.iconSize(context, 32),
              ),
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
                      fontSize: Responsive.fontSize(context, 14),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: GoogleFonts.inter(
                      color: colors.primary,
                      fontSize: Responsive.fontSize(context, 24),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        color: subtitle.startsWith('+')
                            ? colors.success
                            : (subtitle.startsWith('-')
                                  ? colors.error
                                  : colors.textSecondary),
                        fontSize: Responsive.fontSize(context, 12),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomeChartSection(
    AppColors colors,
    bool isMobile,
    String tallerId,
  ) {
    return AppCard(
      padding: EdgeInsets.all(Responsive.padding(context, 24)),
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tendencia de Ingresos',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: Responsive.fontSize(context, 18),
                  color: colors.primary,
                ),
              ),
              Icon(Icons.show_chart, color: colors.success),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 250,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection(FirestoreCollections.servicios)
                  .where('id_taller', isEqualTo: tallerId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;
                final now = DateTime.now();

                // Generar últimos 6 meses
                final Map<String, double> ingresosPorMes = {};
                for (int i = 5; i >= 0; i--) {
                  final m = DateTime(now.year, now.month - i);
                  ingresosPorMes['${m.year}-${m.month}'] = 0.0;
                }

                // Sumar ingresos
                for (var doc in docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  if (data['fecha'] != null) {
                    final fecha = (data['fecha'] as Timestamp).toDate();
                    final key = '${fecha.year}-${fecha.month}';
                    if (ingresosPorMes.containsKey(key)) {
                      final double costo = data['costo'] != null
                          ? (data['costo'] is int
                                ? (data['costo'] as int).toDouble()
                                : data['costo'] as double)
                          : 0.0;
                      ingresosPorMes[key] = (ingresosPorMes[key] ?? 0) + costo;
                    }
                  }
                }

                final values = ingresosPorMes.values.toList();
                final keys = ingresosPorMes.keys.toList();

                double maxY = 100;
                for (var v in values) {
                  if (v > maxY) maxY = v;
                }
                maxY = (maxY * 1.2).ceilToDouble(); // 20% margen superior

                final spots = <FlSpot>[];
                for (int i = 0; i < values.length; i++) {
                  spots.add(FlSpot(i.toDouble(), values[i]));
                }

                return LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: maxY > 0 ? maxY / 4 : 25,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: colors.textSecondary.withValues(alpha: 0.1),
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx >= 0 && idx < keys.length) {
                              final parts = keys[idx].split('-');
                              final m = int.parse(parts[1]);
                              const meses = [
                                'Ene',
                                'Feb',
                                'Mar',
                                'Abr',
                                'May',
                                'Jun',
                                'Jul',
                                'Ago',
                                'Sep',
                                'Oct',
                                'Nov',
                                'Dic',
                              ];
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  meses[m - 1],
                                  style: TextStyle(
                                    color: colors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              );
                            }
                            return const Text('');
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: maxY > 0 ? maxY / 4 : 25,
                          reservedSize: 42,
                          getTitlesWidget: (value, meta) {
                            if (value == maxY) return const SizedBox.shrink();
                            return Text(
                              '\$${value.toInt()}',
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 10,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    minX: 0,
                    maxX: 5,
                    minY: 0,
                    maxY: maxY > 0 ? maxY : 100,
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: colors.success,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          color: colors.success.withValues(alpha: 0.1),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentServices(AppColors colors, String tallerId) {
    return AppCard(
      padding: EdgeInsets.all(Responsive.padding(context, 24)),
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
                  fontSize: Responsive.fontSize(context, 18),
                  color: colors.primary,
                ),
              ),
              Icon(Icons.history, color: colors.textSecondary),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection(FirestoreCollections.servicios)
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
                  .map(
                    (d) => ServiceRecordModel.fromMap(
                      d.data() as Map<String, dynamic>,
                      d.id,
                    ),
                  )
                  .toList();

              return Column(
                children: records
                    .map((r) => _buildServiceTile(r, colors))
                    .toList(),
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
      padding: EdgeInsets.all(Responsive.padding(context, 16)),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.primary.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(Responsive.padding(context, 12)),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.build_circle,
              color: colors.primary,
              size: Responsive.iconSize(context, 24),
            ),
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
                    fontSize: Responsive.fontSize(context, 16),
                  ),
                ),
                Text(
                  DateFormat('dd MMM yyyy').format(record.fecha),
                  style: GoogleFonts.inter(
                    color: colors.textSecondary,
                    fontSize: Responsive.fontSize(context, 12),
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
                fontSize: Responsive.fontSize(context, 16),
              ),
            ),
        ],
      ),
    );
  }
}
