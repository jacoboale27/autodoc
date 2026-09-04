import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/features/dashboard/presentation/providers/vehicle_provider.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:autodoc/core/models/reparacion_model.dart';
import 'package:autodoc/core/models/vehicle_model.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/widgets/app_card.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/widgets/app_empty_state.dart';
import 'package:autodoc/core/widgets/app_page_body.dart';
import 'package:autodoc/core/widgets/notification_bell_button.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_radius.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/features/mechanic/presentation/pages/reparaciones_kanban_screen.dart'
    show etiquetasEstado;
import 'package:autodoc/features/mechanic/presentation/providers/reparacion_provider.dart';
import 'package:autodoc/features/mechanic/presentation/widgets/mechanic_scaffold.dart';
import 'package:autodoc/features/mechanic/presentation/navegacion_vehiculo.dart';
import 'package:autodoc/core/utils/plate_formatter.dart';

class VehicleSearchScreen extends StatefulWidget {
  const VehicleSearchScreen({super.key});

  @override
  State<VehicleSearchScreen> createState() => _VehicleSearchScreenState();
}

class _VehicleSearchScreenState extends State<VehicleSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    // A4a: esta pantalla es una entrada independiente a `ReparacionProvider`
    // (la otra es `ReparacionesKanbanScreen`, que ya llama a `watchTaller`
    // en su propio `initState`). Sin este `watchTaller` aquí, `_MisServicios`
    // vería una lista vacía a menos que el mecánico ya hubiera abierto el
    // kanban antes en la misma sesión — el mismo tipo de "una entrada se
    // corrigió, la otra no" que ya pasó con A3/B2.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final tallerId =
          context.read<UserProfileProvider>().userData?.idTallerEfectivo ?? '';
      if (tallerId.isNotEmpty) {
        context.read<ReparacionProvider>().watchTaller(tallerId);
      }
    });
  }

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
          // A3/B2: buscar una placa es una consulta, no autoriza nada.
          // `abrirVehiculoComoMecanico` decide si hay un ticket aceptado
          // (va a `InitiateServiceScreen`) o no (va a la ficha pública) —
          // mismo punto de decisión que `_abrirVehiculo`, para que las dos
          // entradas de esta pantalla nunca diverjan.
          await _abrirVehiculo(vehicle);
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

  Future<void> _abrirVehiculo(VehicleModel vehicle) async {
    final tallerId =
        context.read<UserProfileProvider>().userData?.idTallerEfectivo ?? '';
    if (!mounted) return;
    // `abrirVehiculoComoMecanico` es el único punto de decisión (Tarea 5,
    // A3/B2): sin ticket aceptado para este vehículo+taller, lleva a la
    // ficha pública; con uno, a `InitiateServiceScreen`. Ya usa `go` por
    // dentro (mismo motivo de siempre: la URL debe seguir a la pantalla para
    // que un F5 no deje al taller a medias).
    await abrirVehiculoComoMecanico(context, vehicle, tallerId);
  }

  /// `_MisServicios` solo tiene la placa y el id de vehículo del ticket
  /// (`ReparacionModel`), no un `VehicleModel` completo (marca/modelo/año),
  /// así que primero se resuelve por placa — la misma llamada que ya hace
  /// `_handleSearch` — y luego se reutiliza `_abrirVehiculo` para no abrir un
  /// segundo camino de navegación.
  Future<void> _abrirVehiculoDesdeReparacion(ReparacionModel reparacion) async {
    final vehicleProvider = context.read<VehicleProvider>();
    final vehicle = await vehicleProvider.findVehicleByPlate(reparacion.placa);
    if (!mounted) return;
    if (vehicle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se encontró el vehículo con placa ${reparacion.placa}',
          ),
        ),
      );
      return;
    }
    await _abrirVehiculo(vehicle);
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
              const SizedBox(height: AppSpacing.xl),
              _MisServicios(onSelect: _abrirVehiculoDesdeReparacion),
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

/// A4a: los servicios activos del taller, sin importar por dónde se hayan
/// iniciado (buscar vehículo, "mis vehículos" o el chat) — todos crean el
/// mismo ticket en `reparaciones` (`onCotizacionAceptada`), así que la única
/// condición para aparecer aquí es `id_taller`, no de dónde vino el mecánico.
///
/// `cancelado` se excluye a propósito: es el único estado que
/// `ReparacionProvider.buscarReparacionActiva` (y por tanto
/// `abrirVehiculoComoMecanico`) trata como "no hay ticket" — listar aquí un
/// ticket cancelado y luego mandar a la ficha pública al tocarlo sería
/// inconsistente con esa misma pantalla.
class _MisServicios extends StatelessWidget {
  final ValueChanged<ReparacionModel> onSelect;

  const _MisServicios({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final reparaciones = context
        .watch<ReparacionProvider>()
        .reparaciones
        .where((r) => r.estado != 'cancelado')
        .toList();

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
                  'Mis Servicios',
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: colors.primary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.build_outlined, size: 20, color: colors.primary),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          if (reparaciones.isEmpty)
            const AppEmptyState(
              title: 'No hay servicios activos',
              description:
                  'Los vehículos que reciba el taller aparecerán aquí, sin '
                  'importar desde dónde se haya iniciado el servicio.',
              icon: Icons.build_outlined,
            )
          else
            ...reparaciones.map(
              (r) => _MisServiciosItem(reparacion: r, onTap: () => onSelect(r)),
            ),
        ],
      ),
    );
  }
}

class _MisServiciosItem extends StatelessWidget {
  final ReparacionModel reparacion;
  final VoidCallback onTap;

  const _MisServiciosItem({required this.reparacion, required this.onTap});

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
                Icons.build_outlined,
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
                    reparacion.placa,
                    style: AppTextStyles.labelLarge.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.primary,
                    ),
                  ),
                  Text(
                    etiquetasEstado[reparacion.estado] ?? reparacion.estado,
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
