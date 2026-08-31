import 'package:flutter/material.dart';
import 'package:autodoc/core/constants/firestore_collections.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/models/service_record_model.dart';
import 'package:autodoc/core/widgets/app_card.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/widgets/app_grid.dart';
import 'package:autodoc/core/widgets/app_page_body.dart';
import 'package:autodoc/core/widgets/app_section_header.dart';
import 'package:autodoc/core/widgets/notification_bell_button.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_radius.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:intl/intl.dart';
import 'package:autodoc/core/utils/responsive.dart';
import 'package:autodoc/core/providers/theme_provider.dart';
import 'package:autodoc/core/providers/language_provider.dart';
import 'package:autodoc/features/mechanic/presentation/widgets/mechanic_scaffold.dart';
import 'package:fl_chart/fl_chart.dart';

class MechanicDashboardScreen extends StatefulWidget {
  /// Cliente de Firestore inyectable. Aditivo — la pantalla monta tres
  /// `StreamBuilder` que por defecto tocan `FirebaseFirestore.instance` en
  /// `build`, así que un test que necesite un doble debe poder sustituirlo
  /// sin depender de un Firebase real. Mismo patrón que las Tasks 5 y 8.
  final FirebaseFirestore? firestore;

  const MechanicDashboardScreen({super.key, this.firestore});

  @override
  State<MechanicDashboardScreen> createState() =>
      _MechanicDashboardScreenState();
}

class _MechanicDashboardScreenState extends State<MechanicDashboardScreen> {
  FirebaseFirestore get _db => widget.firestore ?? FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final userSession = context.watch<UserProfileProvider>();
    final userData = userSession.userData;

    if (userData == null || userData.idUsuario.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final mechanicName = userData.nombreCompleto;

    return MechanicScaffold(
      title: 'Dashboard',
      actions: const [
        _TemaIdiomaActions(),
        SizedBox(width: AppSpacing.base),
        NotificationBellButton(),
      ],
      body: SingleChildScrollView(
        child: AppPageBody(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWelcomeHeader(mechanicName, colors),
                const SizedBox(height: AppSpacing.xl),
                _buildQuickActions(colors),
                const SizedBox(height: AppSpacing.xxl),
                _buildDashboardMetrics(colors, userData.idUsuario),
                const SizedBox(height: AppSpacing.xxl),
                _buildIncomeChartSection(colors, userData.idUsuario),
                const SizedBox(height: AppSpacing.xxl),
                _buildRecentServices(colors, userData.idUsuario),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader(String mechanicName, AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hola, $mechanicName 👋',
          style: AppTextStyles.headlineMedium.copyWith(color: colors.primary),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Aquí tienes un resumen de la actividad de tu taller.',
          style: AppTextStyles.bodyMedium.copyWith(color: colors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildQuickActions(AppColors colors) {
    return Container(
      padding: EdgeInsets.all(Responsive.padding(context, AppSpacing.xl)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primary, colors.primary.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.base,
        runSpacing: AppSpacing.base,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 200),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Atención Rápida',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: colors.secondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Inicia un nuevo servicio buscando la placa del vehículo.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: colors.onPrimary,
                  ),
                ),
              ],
            ),
          ),
          AppButton(
            text: 'Buscar',
            onPressed: () => context.push('/mechanic_search'),
            icon: Icon(Icons.search, size: Responsive.iconSize(context, 18)),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardMetrics(AppColors colors, String tallerId) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _db
          .collection(FirestoreCollections.usuarios)
          .doc(tallerId)
          .snapshots(),
      builder: (context, userSnapshot) {
        final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
        final promedio = userData?['calificacion_promedio']?.toDouble() ?? 0.0;
        final totalResenias = userData?['total_resenias'] ?? 0;

        return StreamBuilder<QuerySnapshot>(
          stream: _db
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

            return AppGrid(
              compactColumns: 1,
              mediumColumns: 2,
              expandedColumns: 3,
              largeColumns: 3,
              spacing: AppSpacing.xl,
              // Columnas de ~276 px (medium) a ~373 px (large con
              // maxContentWidth 1200). La tarjeta necesita ~110 px de alto:
              // caja de icono de 64 más padding. 2.6 deja entre 106 y 143.
              childAspectRatio: 2.6,
              children: [
                _MetricCard(
                  title: 'Ingresos (Mes)',
                  value: '\$${ingresosMesActual.toStringAsFixed(2)}',
                  icon: Icons.attach_money,
                  accentColor: colors.success,
                  colors: colors,
                  subtitle: variacionIngresos.isNotEmpty
                      ? '$variacionIngresos vs mes ant.'
                      : null,
                ),
                _MetricCard(
                  title: 'Servicios (Mes)',
                  value: serviciosMesActual.toString(),
                  icon: Icons.calendar_today,
                  accentColor: colors.secondary,
                  colors: colors,
                ),
                _MetricCard(
                  title: 'Total Servicios',
                  value: totalServicios.toString(),
                  icon: Icons.build_circle,
                  accentColor: colors.primary,
                  colors: colors,
                  onTap: () => context.push('/mechanic_service_history'),
                ),
                _MetricCard(
                  title: 'Vehículos Atendidos',
                  value: vehiculosUnicos.length.toString(),
                  icon: Icons.directions_car,
                  accentColor: colors.success,
                  colors: colors,
                ),
                _MetricCard(
                  title: 'Calificación',
                  value: promedio > 0 ? promedio.toStringAsFixed(1) : '—',
                  icon: Icons.star_rounded,
                  accentColor: colors.warning,
                  colors: colors,
                ),
                _MetricCard(
                  title: 'Reseñas',
                  value: totalResenias.toString(),
                  icon: Icons.rate_review_outlined,
                  accentColor: colors.primary,
                  colors: colors,
                  onTap: () => context.push('/mechanic_reviews'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildIncomeChartSection(AppColors colors, String tallerId) {
    final isCompact = AppBreakpoints.of(context).isCompact;

    return AppCard(
      padding: EdgeInsets.all(Responsive.padding(context, AppSpacing.xl)),
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(
            title: 'Tendencia de Ingresos',
            trailing: Icon(Icons.show_chart, color: colors.success),
          ),
          const SizedBox(height: AppSpacing.xl),
          StreamBuilder<QuerySnapshot>(
            stream: _db
                .collection(FirestoreCollections.servicios)
                .where('id_taller', isEqualTo: tallerId)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return SizedBox(
                  height: isCompact ? 200 : 280,
                  child: const Center(child: CircularProgressIndicator()),
                );
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

              final resumenTextual = List.generate(keys.length, (i) {
                final m = int.parse(keys[i].split('-')[1]);
                return '${meses[m - 1]} \$${values[i].toStringAsFixed(0)}';
              }).join(', ');

              double maxY = 100;
              for (var v in values) {
                if (v > maxY) maxY = v;
              }
              maxY = (maxY * 1.2).ceilToDouble(); // 20% margen superior

              final spots = <FlSpot>[];
              for (int i = 0; i < values.length; i++) {
                spots.add(FlSpot(i.toDouble(), values[i]));
              }

              return Semantics(
                label:
                    'Tendencia de ingresos de los últimos 6 meses. '
                    '$resumenTextual.',
                child: ExcludeSemantics(
                  child: SizedBox(
                    height: isCompact ? 200 : 280,
                    child: LineChart(
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
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      meses[m - 1],
                                      style: AppTextStyles.labelSmall.copyWith(
                                        color: colors.textSecondary,
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
                                if (value == maxY) {
                                  return const SizedBox.shrink();
                                }
                                return Text(
                                  '\$${value.toInt()}',
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: colors.textSecondary,
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
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecentServices(AppColors colors, String tallerId) {
    return AppCard(
      padding: EdgeInsets.all(Responsive.padding(context, AppSpacing.xl)),
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(
            title: 'Servicios Recientes',
            trailing: Icon(Icons.history, color: colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.base),
          StreamBuilder<QuerySnapshot>(
            stream: _db
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
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                  child: Center(
                    child: Text(
                      'No hay servicios registrados aún.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: colors.textSecondary,
                      ),
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
                    .map((r) => _ServiceTile(record: r, colors: colors))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Conmutadores de tema e idioma. Estaban escritos dos veces —una en el
/// `AppBar` de teléfono y otra en la barra de escritorio— con distinto color
/// cada uno. `MechanicScaffold` los pinta en la barra que corresponda.
class _TemaIdiomaActions extends StatelessWidget {
  const _TemaIdiomaActions();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Consumer2<ThemeProvider, LanguageProvider>(
      builder: (context, themeProvider, languageProvider, _) {
        final isDark = themeProvider.isDarkMode;
        final isEnglish = languageProvider.currentLocale.languageCode == 'en';

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: isDark
                  ? 'Cambiar a modo claro'
                  : 'Cambiar a modo oscuro',
              icon: Icon(
                isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                color: colors.primary,
              ),
              onPressed: themeProvider.toggleTheme,
            ),
            IconButton(
              tooltip: isEnglish ? 'Cambiar a español' : 'Switch to English',
              onPressed: () =>
                  languageProvider.changeLanguage(isEnglish ? 'es' : 'en'),
              icon: Text(
                isEnglish ? 'EN' : 'ES',
                style: AppTextStyles.labelLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.primary,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Tarjeta de un KPI del dashboard. `AppGrid` decide su celda; la tarjeta
/// solo rellena el espacio que recibe — antes un `SizedBox(width: ...)`
/// interno duplicaba el ancho que ya fijaba el `Wrap` externo (más el
/// padding de `AppCard`), y el cálculo de columnas nunca coincidía con el
/// ancho real dibujado.
class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color accentColor;
  final AppColors colors;
  final VoidCallback? onTap;
  final String? subtitle;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.accentColor,
    required this.colors,
    this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    // Padding y tamaño de icono fijos (no escalados por `Responsive`,
    // que solo conoce el ancho *global* de la ventana): a 1200 px la
    // celda de `AppGrid` con `childAspectRatio: 2.6` mide apenas ~104 px
    // de alto, el peor caso de los ocho anchos de auditoría (3 columnas,
    // celda ~269 px de ancho). No es el corte de `expanded` (840): ahí el
    // sidebar fijo de 280 px de `MechanicScaffold` deja tan poco ancho de
    // contenido que `AppGrid` cae a la clase `compact` y pinta 1 columna
    // ancha, no 3 estrechas. El contenido de esta tarjeta tiene que caber
    // en ~104 px siempre, no solo en el ancho en que se probó a mano.
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      margin: EdgeInsets.zero,
      onTap: onTap,
      semanticLabel: onTap == null
          ? null
          : (subtitle != null ? '$title: $value, $subtitle' : '$title: $value'),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: accentColor, size: 24),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: colors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  value,
                  style: AppTextStyles.headlineSmall.copyWith(
                    color: colors.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: subtitle!.startsWith('+')
                          ? colors.success
                          : (subtitle!.startsWith('-')
                                ? colors.error
                                : colors.textSecondary),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila de un servicio reciente. Antes era un `Container` crudo sin `onTap`
/// ni feedback, mientras que la tarjeta "Total Servicios" sí navega al
/// historial: el usuario aprendía que las filas de servicio son pulsables y
/// aquí no lo eran.
class _ServiceTile extends StatelessWidget {
  final ServiceRecordModel record;
  final AppColors colors;

  const _ServiceTile({required this.record, required this.colors});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: EdgeInsets.all(Responsive.padding(context, AppSpacing.base)),
      onTap: () => context.push('/mechanic_service_history'),
      semanticLabel:
          '${record.tipoServicio ?? 'Servicio'}, '
          '${DateFormat('dd MMM yyyy').format(record.fecha)}',
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(Responsive.padding(context, AppSpacing.md)),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              Icons.build_circle,
              color: colors.primary,
              size: Responsive.iconSize(context, 24),
            ),
          ),
          const SizedBox(width: AppSpacing.base),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.tipoServicio ?? 'Servicio',
                  style: AppTextStyles.titleSmall.copyWith(
                    color: colors.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  DateFormat('dd MMM yyyy').format(record.fecha),
                  style: AppTextStyles.labelMedium.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (record.costo != null && record.costo! > 0)
            Text(
              '\$${record.costo!.toStringAsFixed(2)}',
              style: AppTextStyles.titleSmall.copyWith(color: colors.secondary),
            ),
        ],
      ),
    );
  }
}
