import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/features/dashboard/presentation/providers/vehicle_provider.dart';
import 'package:autodoc/features/mechanic/presentation/pages/initiate_service_screen.dart';

class VehicleSearchScreen extends StatefulWidget {
  const VehicleSearchScreen({super.key});

  @override
  State<VehicleSearchScreen> createState() => _VehicleSearchScreenState();
}

class _VehicleSearchScreenState extends State<VehicleSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  // Colores del sistema de diseño (basados en el HTML)
  final Color primaryBlue = const Color(0xFF0E3B69);
  final Color secondaryTeal = const Color(0xFF006A62);
  final Color surfaceContainer = const Color(0xFFE7EEFF);
  final Color accentMint = const Color(0xFF8CF1E4);

  String _formatPlate(String input) {
    String clean = input.replaceAll('-', '').toUpperCase();
    if (clean.length > 3) {
      return '${clean.substring(0, 3)}-${clean.substring(3)}';
    }
    return clean;
  }

  Future<void> _handleSearch() async {
    if (_searchController.text.isEmpty) return;

    setState(() {
      _isSearching = true;
    });

    try {
      final vehicleProvider = context.read<VehicleProvider>();
      final formattedPlate = _formatPlate(_searchController.text);
      final vehicle = await vehicleProvider.findVehicleByPlate(formattedPlate);
      
      if (vehicle != null) {
        // Add to recent in provider
        vehicleProvider.addRecentSearch(vehicle);

        // Navegar automáticamente a la pantalla de inicio de servicio
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => InitiateServiceScreen(vehicle: vehicle),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Vehículo con placa $formattedPlate no encontrado")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error en la búsqueda")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 700;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FF),
      appBar: isMobile 
        ? AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            title: Text('Panel de Taller', style: GoogleFonts.montserrat(color: primaryBlue, fontSize: 16, fontWeight: FontWeight.bold)),
            iconTheme: IconThemeData(color: primaryBlue),
          )
        : null,
      drawer: isMobile ? Drawer(child: _buildSidebar()) : null,
      body: Stack(
        children: [
          // Background Decorations (Soft Blobs) - Hidden or reduced on mobile for performance
          if (!isMobile) ...[
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentMint.withValues(alpha: 0.1),
                ),
              ),
            ),
          ],
          
          Row(
            children: [
              // Navigation Drawer (Solo en Desktop/Tablet)
              if (!isMobile) _buildSidebar(),
              
              // Contenido Principal
              Expanded(
                child: Column(
                  children: [
                    if (!isMobile) _buildTopBar(),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(isMobile ? 16 : 32),
                        child: Center(
                          child: Container(
                            constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 800),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSearchCard(isMobile),
                                const SizedBox(height: 24),
                                _buildRecentSearches(),
                                const SizedBox(height: 32),
                                _buildAssistantCard(isMobile),
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
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        border: Border(right: BorderSide(color: Colors.white.withValues(alpha: 0.4))),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: surfaceContainer,
                  child: const Icon(Icons.person, color: Color(0xFF0E3B69)),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AutoDoc', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 18, color: primaryBlue)),
                    Text('Mecánico Líder', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildNavItem(Icons.dashboard_outlined, 'Dashboard', false),
          _buildNavItem(Icons.search, 'Buscar Vehículo', true),
          _buildNavItem(Icons.settings_outlined, 'Configuración', false),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool active) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: active ? primaryBlue.withValues(alpha: 0.05) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: active ? Border(right: BorderSide(color: primaryBlue, width: 4)) : null,
      ),
      child: ListTile(
        leading: Icon(icon, color: active ? primaryBlue : Colors.blueGrey),
        title: Text(label, style: GoogleFonts.inter(
          fontWeight: active ? FontWeight.bold : FontWeight.normal,
          color: active ? primaryBlue : Colors.blueGrey,
        )),
        onTap: () {},
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.4))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.menu, color: primaryBlue),
              const SizedBox(width: 16),
              Text('BUSCAR VEHÍCULO', style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w900, fontSize: 20, color: primaryBlue, letterSpacing: -0.5
              )),
            ],
          ),
          Row(
            children: [
              const Icon(Icons.notifications_none, color: Colors.blueGrey),
              const SizedBox(width: 16),
              CircleAvatar(
                radius: 18,
                backgroundColor: primaryBlue,
                child: const Text('ML', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchCard(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 24 : 40),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(isMobile ? 24 : 32),
        boxShadow: [
          BoxShadow(color: primaryBlue.withValues(alpha: 0.05), blurRadius: 40, offset: const Offset(0, 10))
        ],
        border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text('Identificar Vehículo', style: GoogleFonts.montserrat(fontSize: isMobile ? 24 : 32, fontWeight: FontWeight.bold, color: primaryBlue)),
          const SizedBox(height: 8),
          Text(
            'Ingrese la placa o el número de identificación (PIN) para acceder al historial y diagnósticos.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: Colors.blueGrey, fontSize: isMobile ? 12 : 14),
          ),
          SizedBox(height: isMobile ? 24 : 40),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: primaryBlue.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                SizedBox(width: isMobile ? 12 : 24),
                Icon(Icons.directions_car, color: primaryBlue.withValues(alpha: 0.5), size: isMobile ? 20 : 24),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: GoogleFonts.inter(fontSize: isMobile ? 18 : 22, fontWeight: FontWeight.bold, color: primaryBlue, letterSpacing: isMobile ? 1 : 2),
                    decoration: InputDecoration(
                      hintText: 'PLACA O PIN...',
                      hintStyle: TextStyle(color: primaryBlue.withValues(alpha: 0.2), fontSize: isMobile ? 14 : 18),
                      border: InputBorder.none,
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(isMobile ? 12 : 16),
                  decoration: BoxDecoration(
                    color: accentMint,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.qr_code_scanner, color: primaryBlue, size: isMobile ? 20 : 28),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isSearching ? null : _handleSearch,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 32 : 48, vertical: isMobile ? 12 : 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
              elevation: 0,
            ),
            child: _isSearching 
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text('BUSCAR AUTO', style: GoogleFonts.montserrat(fontSize: isMobile ? 16 : 18, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }


  Widget _buildRecentSearches() {
    final vehicleProvider = context.watch<VehicleProvider>();
    final recentSearches = vehicleProvider.recentSearches;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: primaryBlue.withValues(alpha: 0.03), blurRadius: 20, offset: const Offset(0, 4))
        ],
        border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Búsquedas Recientes', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: primaryBlue, fontSize: 16)),
              Icon(Icons.history, size: 20, color: primaryBlue),
            ],
          ),
          const SizedBox(height: 16),
          if (recentSearches.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No hay búsquedas recientes',
                  style: GoogleFonts.inter(color: Colors.blueGrey.withValues(alpha: 0.5), fontSize: 13),
                ),
              ),
            )
          else
            ...recentSearches.map((v) => _buildRecentItem(v)),
        ],
      ),
    );
  }

  Widget _buildRecentItem(dynamic vehicle) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => InitiateServiceScreen(vehicle: vehicle),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: surfaceContainer, 
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primaryBlue.withValues(alpha: 0.05)),
              ),
              child: Icon(Icons.directions_car, size: 20, color: primaryBlue),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(vehicle.placa, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: primaryBlue)),
                  Text('${vehicle.marca} ${vehicle.modelo} • ${vehicle.anio}', 
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.blueGrey)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: primaryBlue.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }

  Widget _buildAssistantCard(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primaryBlue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryBlue.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: secondaryTeal, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Asistente de Servicio', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: primaryBlue, fontSize: 14)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Escanee el VIN en el marco de la puerta del conductor para resultados automáticos.', 
            style: GoogleFonts.inter(fontSize: 12, color: Colors.blueGrey)),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {}, 
              child: Text('SABER MÁS', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: secondaryTeal))
            ),
          ),
        ],
      ),
    );
  }
}
