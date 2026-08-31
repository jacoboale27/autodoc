import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/features/dashboard/presentation/providers/vehicle_provider.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:autodoc/core/models/vehicle_model.dart';
import 'package:autodoc/core/widgets/app_card.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/widgets/app_empty_state.dart';
import 'package:autodoc/core/widgets/app_page_body.dart';
import 'package:autodoc/core/widgets/notification_bell_button.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_radius.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/features/mechanic/presentation/widgets/mechanic_scaffold.dart';
import 'package:autodoc/core/utils/plate_formatter.dart';

class VehicleSearchScreen extends StatefulWidget {
  const VehicleSearchScreen({super.key});

  @override
  State<VehicleSearchScreen> createState() => _VehicleSearchScreenState();
}

class _VehicleSearchScreenState extends State<VehicleSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  Future<void> _scanQR() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Escanear QR')),
          body: MobileScanner(
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final barcode = barcodes.first;
                if (barcode.rawValue != null) {
                  Navigator.of(context).pop();
                  _searchController.text = barcode.rawValue!;
                  _handleSearch();
                }
              }
            },
          ),
        ),
      ),
    );
  }

  Future<void> _handleSearch() async {
    if (_searchController.text.isEmpty) return;

    setState(() {
      _isSearching = true;
    });

    try {
      final vehicleProvider = context.read<VehicleProvider>();
      final formattedPlate = normalizarPlaca(_searchController.text);
      final vehicle = await vehicleProvider.findVehicleByPlate(formattedPlate);

      if (vehicle != null) {
        vehicleProvider.addRecentSearch(vehicle);
        if (mounted) {
          // `go` y no `push`: con `push` se abria la pantalla pero la
          // barra de direcciones seguia diciendo /mechanic_search
          // (hallazgo §2.14; go_router match.dart:621-632 copia `matches`
          // y conserva `uri`), asi que un F5 sacaba al taller del servicio
          // a medias. `extra` sigue viajando igual: precarga el vehiculo
          // para no re-consultarlo.
          context.go(
            '/initiate_service/${vehicle.idVehiculo}',
            extra: vehicle,
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Vehículo con placa $formattedPlate no encontrado"),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Error en la búsqueda")));
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _abrirVehiculo(VehicleModel vehicle) {
    // Mismo motivo que en `_handleSearch`: `go` para que la URL siga a la
    // pantalla y el servicio se pueda enlazar y recargar.
    context.go('/initiate_service/${vehicle.idVehiculo}', extra: vehicle);
  }

  @override
  Widget build(BuildContext context) {
    return MechanicScaffold(
      title: 'Buscar Vehículo',
      actions: const [NotificationBellButton()],
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: AppPageBody(
          maxWidth: AppBreakpoints.maxReadingWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SearchCard(
                controller: _searchController,
                isSearching: _isSearching,
                onSearch: _handleSearch,
                onScan: _scanQR,
              ),
              const SizedBox(height: AppSpacing.xl),
              _RecentSearches(onSelect: _abrirVehiculo),
              const SizedBox(height: AppSpacing.xxl),
              const _AssistantCard(),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchCard extends StatelessWidget {
  final TextEditingController controller;
  final bool isSearching;
  final VoidCallback onSearch;
  final VoidCallback onScan;

  const _SearchCard({
    required this.controller,
    required this.isSearching,
    required this.onSearch,
    required this.onScan,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          Text(
            'Identificar Vehículo',
            textAlign: TextAlign.center,
            style: AppTextStyles.headlineSmall.copyWith(color: colors.primary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Ingrese la placa del vehículo para acceder al historial y registrar servicios.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.base,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: colors.surfaceContainer,
              borderRadius: BorderRadius.circular(AppRadius.full),
              border: Border.all(color: colors.primary.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.directions_car,
                  color: colors.primary.withValues(alpha: 0.5),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextField(
                    controller: controller,
                    style: AppTextStyles.titleMedium.copyWith(
                      color: colors.primary,
                      letterSpacing: 1.5,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Ej: ABC123',
                      hintStyle: AppTextStyles.bodyLarge.copyWith(
                        color: colors.textSecondary,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    textCapitalization: TextCapitalization.characters,
                    onSubmitted: (_) => onSearch(),
                  ),
                ),
                Semantics(
                  button: true,
                  label: 'Escanear código QR de la placa',
                  child: IconButton(
                    onPressed: onScan,
                    padding: EdgeInsets.zero,
                    // El tamaño mínimo tappable de IconButton en Material 3
                    // es 48 dp; se fija explícitamente para no depender del
                    // tamaño del icono decorativo. El GestureDetector
                    // anterior medía 44 en teléfono.
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    icon: Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: colors.secondary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.qr_code_scanner,
                        color: colors.primary,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              text: 'BUSCAR AUTO',
              isLoading: isSearching,
              onPressed: isSearching ? null : onSearch,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentSearches extends StatelessWidget {
  final ValueChanged<VehicleModel> onSelect;

  const _RecentSearches({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final vehicleProvider = context.watch<VehicleProvider>();
    final recentSearches = vehicleProvider.recentSearches;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Búsquedas Recientes',
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: colors.primary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.history, size: 20, color: colors.primary),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          if (recentSearches.isEmpty)
            const AppEmptyState(
              title: 'No hay búsquedas recientes',
              description:
                  'Los vehículos que busques aparecerán aquí para volver a abrirlos con un toque.',
              icon: Icons.history,
            )
          else
            ...recentSearches.map(
              (v) => _RecentItem(vehicle: v, onTap: () => onSelect(v)),
            ),
        ],
      ),
    );
  }
}

class _RecentItem extends StatelessWidget {
  final VehicleModel vehicle;
  final VoidCallback onTap;

  const _RecentItem({required this.vehicle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: colors.surfaceContainer,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(
                Icons.directions_car,
                size: 20,
                color: colors.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.base),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vehicle.placa,
                    style: AppTextStyles.labelLarge.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.primary,
                    ),
                  ),
                  Text(
                    '${vehicle.marca} ${vehicle.modelo} • ${vehicle.anio}',
                    style: AppTextStyles.bodySmall.copyWith(
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
}

/// Aviso informativo sobre el escáner de placa.
///
/// Antes tenía un botón "SABER MÁS" con un callback vacío que no llevaba a
/// ninguna parte: un control enfocable, anunciable y muerto. Se retira el
/// botón y se conserva el texto — el escáner de esta pantalla sí lee placas,
/// así que la descripción sigue siendo información válida para el usuario.
class _AssistantCard extends StatelessWidget {
  const _AssistantCard();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: colors.primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: colors.secondary, size: 24),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Asistente de Servicio',
                  style: AppTextStyles.titleSmall.copyWith(
                    color: colors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Escanee el VIN en el marco de la puerta del conductor para resultados automáticos.',
            style: AppTextStyles.bodySmall.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
