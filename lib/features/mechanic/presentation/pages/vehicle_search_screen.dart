import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/features/dashboard/presentation/providers/vehicle_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:autodoc/core/widgets/app_card.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/features/mechanic/presentation/widgets/mechanic_sidebar.dart';

class VehicleSearchScreen extends StatefulWidget {
  const VehicleSearchScreen({super.key});

  @override
  State<VehicleSearchScreen> createState() => _VehicleSearchScreenState();
}

class _VehicleSearchScreenState extends State<VehicleSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

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
        vehicleProvider.addRecentSearch(vehicle);
        if (mounted) {
          context.push('/initiate_service', extra: vehicle);
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
    final colors = context.appColors;
    final theme = Theme.of(context);

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
          // Navigation Drawer (Solo en Desktop/Tablet)
          if (!isMobile) const MechanicSidebar(),

          // Contenido Principal
          Expanded(
            child: Column(
              children: [
                if (!isMobile) _buildTopBar(colors, theme),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isMobile ? 16 : 32),
                    child: Center(
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: isMobile ? double.infinity : 800,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSearchCard(isMobile, colors),
                            const SizedBox(height: 24),
                            _buildRecentSearches(colors),
                            const SizedBox(height: 32),
                            _buildAssistantCard(isMobile, colors),
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

  Widget _buildTopBar(AppColors colors, ThemeData theme) {
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
            'BUSCAR VEHÍCULO',
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
                child: const Text(
                  'ML',
                  style: TextStyle(
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

  Widget _buildSearchCard(bool isMobile, AppColors colors) {
    return AppCard(
      padding: EdgeInsets.all(isMobile ? 24 : 40),
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          Text(
            'Identificar Vehículo',
            style: GoogleFonts.inter(
              fontSize: isMobile ? 24 : 32,
              fontWeight: FontWeight.bold,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ingrese la placa del vehículo para acceder al historial y registrar servicios.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: colors.textSecondary,
              fontSize: isMobile ? 12 : 14,
            ),
          ),
          SizedBox(height: isMobile ? 24 : 40),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: colors.surfaceContainer,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: colors.primary.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                SizedBox(width: isMobile ? 12 : 24),
                Icon(
                  Icons.directions_car,
                  color: colors.primary.withValues(alpha: 0.5),
                  size: isMobile ? 20 : 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: GoogleFonts.inter(
                      fontSize: isMobile ? 18 : 22,
                      fontWeight: FontWeight.bold,
                      color: colors.primary,
                      letterSpacing: isMobile ? 1 : 2,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Ej: ABC123',
                      hintStyle: TextStyle(
                        color: colors.primary.withValues(alpha: 0.2),
                        fontSize: isMobile ? 14 : 18,
                      ),
                      border: InputBorder.none,
                    ),
                    textCapitalization: TextCapitalization.characters,
                    onSubmitted: (_) => _handleSearch(),
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(isMobile ? 12 : 16),
                  decoration: BoxDecoration(
                    color: colors.secondary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.qr_code_scanner,
                    color: colors.primary,
                    size: isMobile ? 20 : 28,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              text: 'BUSCAR AUTO',
              isLoading: _isSearching,
              onPressed: _isSearching ? null : _handleSearch,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSearches(AppColors colors) {
    final vehicleProvider = context.watch<VehicleProvider>();
    final recentSearches = vehicleProvider.recentSearches;

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
                'Búsquedas Recientes',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: colors.primary,
                  fontSize: 16,
                ),
              ),
              Icon(Icons.history, size: 20, color: colors.primary),
            ],
          ),
          const SizedBox(height: 16),
          if (recentSearches.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No hay búsquedas recientes',
                  style: GoogleFonts.inter(
                    color: colors.textSecondary.withValues(alpha: 0.5),
                    fontSize: 13,
                  ),
                ),
              ),
            )
          else
            ...recentSearches.map((v) => _buildRecentItem(v, colors)),
        ],
      ),
    );
  }

  Widget _buildRecentItem(dynamic vehicle, AppColors colors) {
    return InkWell(
      onTap: () {
        context.push('/initiate_service', extra: vehicle);
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.directions_car, size: 20, color: colors.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vehicle.placa,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: colors.primary,
                    ),
                  ),
                  Text(
                    '${vehicle.marca} ${vehicle.modelo} • ${vehicle.anio}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: colors.primary.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssistantCard(bool isMobile, AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: colors.secondary, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Asistente de Servicio',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Escanee el VIN en el marco de la puerta del conductor para resultados automáticos.',
            style: GoogleFonts.inter(fontSize: 12, color: colors.textSecondary),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {},
              child: Text(
                'SABER MÁS',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colors.secondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
