import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:autodoc/features/auth/presentation/providers/auth_provider.dart';
import 'package:autodoc/core/providers/theme_provider.dart';
import 'package:autodoc/core/models/service_record_model.dart';
import 'package:intl/intl.dart';

class MechanicDashboardScreen extends StatefulWidget {
  const MechanicDashboardScreen({super.key});

  @override
  State<MechanicDashboardScreen> createState() => _MechanicDashboardScreenState();
}

class _MechanicDashboardScreenState extends State<MechanicDashboardScreen> {
  // Theme colors matching the HTML design provided
  final Color primaryBlue = const Color(0xFF0E3B69);
  final Color secondaryTeal = const Color(0xFF006A62);
  final Color surfaceContainer = const Color(0xFFE7EEFF);
  final Color accentMint = const Color(0xFF8CF1E4);

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 700;
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final authProvider = context.watch<AuthProvider>();
    final userData = authProvider.userData;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF9F9FF),
      appBar: isMobile 
        ? AppBar(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            elevation: 0,
            title: Text('Panel de Taller', style: GoogleFonts.montserrat(color: isDark ? Colors.white : primaryBlue, fontSize: 16, fontWeight: FontWeight.bold)),
            iconTheme: IconThemeData(color: isDark ? Colors.white : primaryBlue),
          )
        : null,
      drawer: isMobile ? Drawer(child: _buildSidebar(isDark)) : null,
      body: Row(
        children: [
          if (!isMobile) _buildSidebar(isDark),
          Expanded(
            child: Column(
              children: [
                if (!isMobile) _buildTopBar(isDark, userData?.nombreCompleto ?? 'Mecánico Líder'),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isMobile ? 16 : 32),
                    child: Center(
                      child: Container(
                        constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 1000),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildWelcomeHeader(userData?.nombreCompleto ?? 'Mecánico', isDark),
                            const SizedBox(height: 24),
                            _buildQuickActions(isDark, isMobile),
                            const SizedBox(height: 32),
                            _buildDashboardMetrics(isDark, isMobile, userData?.idUsuario ?? ''),
                            const SizedBox(height: 32),
                            _buildRecentServices(isDark, userData?.idUsuario ?? ''),
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

  Widget _buildSidebar(bool isDark) {
    final bgColor = isDark ? const Color(0xFF1E293B) : Colors.white.withValues(alpha: 0.7);
    final textColor = isDark ? Colors.white : primaryBlue;

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(right: BorderSide(color: isDark ? Colors.white10 : Colors.white.withValues(alpha: 0.4))),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: isDark ? primaryBlue.withValues(alpha: 0.5) : surfaceContainer,
                  child: Icon(Icons.store, color: isDark ? Colors.white : primaryBlue),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AutoDoc', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 18, color: textColor)),
                    Text('Panel de Taller', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildNavItem(Icons.dashboard, 'Dashboard', true, isDark, () {}),
          _buildNavItem(Icons.search, 'Buscar Vehículo', false, isDark, () {
            context.push('/mechanic_search');
          }),
          _buildNavItem(Icons.settings_outlined, 'Configuración', false, isDark, () {
            context.push('/workshop_settings');
          }),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool active, bool isDark, VoidCallback onTap) {
    final textColor = isDark ? Colors.white : primaryBlue;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: active ? primaryBlue.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: active ? Border(right: BorderSide(color: primaryBlue, width: 4)) : null,
      ),
      child: ListTile(
        leading: Icon(icon, color: active ? primaryBlue : (isDark ? Colors.white54 : Colors.blueGrey)),
        title: Text(label, style: GoogleFonts.inter(
          fontWeight: active ? FontWeight.bold : FontWeight.normal,
          color: active ? textColor : (isDark ? Colors.white70 : Colors.blueGrey),
        )),
        onTap: onTap,
      ),
    );
  }

  Widget _buildTopBar(bool isDark, String mechanicName) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white.withValues(alpha: 0.6),
        border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.white.withValues(alpha: 0.4))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text('DASHBOARD', style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w900, fontSize: 20, color: isDark ? Colors.white : primaryBlue, letterSpacing: -0.5
              )),
            ],
          ),
          Row(
            children: [
              Icon(Icons.notifications_none, color: isDark ? Colors.white70 : Colors.blueGrey),
              const SizedBox(width: 16),
              CircleAvatar(
                radius: 18,
                backgroundColor: primaryBlue,
                child: Text(mechanicName.isNotEmpty ? mechanicName[0].toUpperCase() : 'M', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeHeader(String mechanicName, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hola, $mechanicName 👋',
          style: GoogleFonts.montserrat(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : primaryBlue,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Aquí tienes un resumen de la actividad de tu taller.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: isDark ? Colors.white70 : Colors.blueGrey,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(bool isDark, bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryBlue, primaryBlue.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: primaryBlue.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Atención Rápida', style: GoogleFonts.inter(color: accentMint, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                Text(
                  'Inicia un nuevo servicio buscando la placa o PIN del vehículo.',
                  style: GoogleFonts.inter(color: Colors.white, fontSize: isMobile ? 14 : 16),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: () => context.push('/mechanic_search'),
            icon: const Icon(Icons.search),
            label: Text('Buscar', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentMint,
              foregroundColor: primaryBlue,
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardMetrics(bool isDark, bool isMobile, String tallerId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('servicios')
          .where('id_taller', isEqualTo: tallerId)
          .snapshots(),
      builder: (context, snapshot) {
        int totalServicios = 0;
        double ingresosTotales = 0.0;
        
        if (snapshot.hasData) {
          totalServicios = snapshot.data!.docs.length;
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            if (data.containsKey('costo') && data['costo'] != null) {
              ingresosTotales += (data['costo'] as num).toDouble();
            }
          }
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final double cardWidth = isMobile ? constraints.maxWidth : (constraints.maxWidth - 24) / 2;
            
            return Wrap(
              spacing: 24,
              runSpacing: 24,
              children: [
                _buildMetricCard(
                  title: 'Servicios Realizados',
                  value: totalServicios.toString(),
                  icon: Icons.build_circle,
                  color: secondaryTeal,
                  isDark: isDark,
                  width: cardWidth,
                ),
                _buildMetricCard(
                  title: 'Ingresos Estimados',
                  value: '\$${ingresosTotales.toStringAsFixed(2)}',
                  icon: Icons.attach_money,
                  color: const Color(0xFFD97706),
                  isDark: isDark,
                  width: cardWidth,
                ),
              ],
            );
          }
        );
      }
    );
  }

  Widget _buildMetricCard({required String title, required String value, required IconData icon, required Color color, required bool isDark, required double width}) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.blueGrey.withValues(alpha: 0.1)),
        boxShadow: [
          if (!isDark) BoxShadow(color: Colors.blueGrey.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(color: isDark ? Colors.white54 : Colors.blueGrey, fontSize: 14)),
                const SizedBox(height: 4),
                Text(value, style: GoogleFonts.montserrat(color: isDark ? Colors.white : primaryBlue, fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentServices(bool isDark, String tallerId) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white10 : Colors.blueGrey.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Servicios Recientes', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? Colors.white : primaryBlue)),
              Icon(Icons.history, color: isDark ? Colors.white54 : Colors.blueGrey),
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
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text('No hay servicios registrados aún.', style: GoogleFonts.inter(color: isDark ? Colors.white54 : Colors.blueGrey)),
                  ),
                );
              }

              final records = snapshot.data!.docs.map((d) => ServiceRecordModel.fromMap(d.data() as Map<String, dynamic>, d.id)).toList();

              return Column(
                children: records.map((record) => _buildServiceTile(record, isDark)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildServiceTile(ServiceRecordModel record, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF9F9FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.blueGrey.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.build_circle, color: primaryBlue, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(record.tipoServicio ?? 'Servicio', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: isDark ? Colors.white : primaryBlue, fontSize: 16)),
                Text(DateFormat('dd MMM yyyy').format(record.fecha), style: GoogleFonts.inter(color: isDark ? Colors.white54 : Colors.blueGrey, fontSize: 12)),
              ],
            ),
          ),
          if (record.costo != null && record.costo! > 0)
            Text('\$${record.costo!.toStringAsFixed(2)}', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: secondaryTeal, fontSize: 16)),
        ],
      ),
    );
  }
}
