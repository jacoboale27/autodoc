import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:autodoc/core/constants/firestore_collections.dart';
import 'package:autodoc/core/models/vehicle_model.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/core/theme/app_radius.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/widgets/app_card.dart';
import 'package:autodoc/core/widgets/app_page_body.dart';
import 'package:autodoc/core/widgets/missing_argument_screen.dart';

/// Ficha pública de un vehículo para un mecánico **sin** ticket de reparación
/// aceptado (A3/B2): solo nombre, placa, kilometraje e imagen. Ninguna
/// acción — ni "Recibir vehículo", ni "Iniciar servicio", ni historial —
/// porque nada de eso debería ser posible sin que el propietario haya
/// aceptado una cotización primero.
///
/// `abrirVehiculoComoMecanico` (`navegacion_vehiculo.dart`) es el único
/// lugar que decide traer al mecánico aquí en vez de a
/// `InitiateServiceScreen`; esta pantalla no repite esa decisión.
class VehiclePublicViewScreen extends StatefulWidget {
  final String vehiculoId;
  final VehicleModel? vehiculoPrecargado;

  const VehiclePublicViewScreen({
    super.key,
    required this.vehiculoId,
    this.vehiculoPrecargado,
  });

  @override
  State<VehiclePublicViewScreen> createState() =>
      _VehiclePublicViewScreenState();
}

class _VehiclePublicViewScreenState extends State<VehiclePublicViewScreen> {
  VehicleModel? _vehiculo;
  bool _cargando = false;
  bool _errorCarga = false;

  @override
  void initState() {
    super.initState();
    _vehiculo = widget.vehiculoPrecargado;
    if (_vehiculo == null) _cargarVehiculo();
  }

  /// Igual que `VehicleProfileScreen`/`InitiateServiceScreen`: `extra` es
  /// solo una precarga, nunca la única fuente del dato. Sin este respaldo,
  /// un F5 sobre esta URL (que sí puede pasar: es la primera pantalla del
  /// mecánico para un vehículo sin ticket) dejaba la vista en blanco.
  Future<void> _cargarVehiculo() async {
    setState(() {
      _cargando = true;
      _errorCarga = false;
    });
    try {
      final doc = await FirebaseFirestore.instance
          .collection(FirestoreCollections.vehiculos)
          .doc(widget.vehiculoId)
          .get();
      if (!mounted) return;
      if (!doc.exists) {
        setState(() {
          _cargando = false;
          _errorCarga = true;
        });
        return;
      }
      setState(() {
        _vehiculo = VehicleModel.fromMap(doc.data()!, doc.id);
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _errorCarga = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final vehiculo = _vehiculo;
    if (_errorCarga || vehiculo == null) {
      return const MissingArgumentScreen(
        mensaje: 'No se pudo cargar el vehículo.',
        rutaVuelta: '/mechanic_search',
      );
    }

    final colors = context.appColors;
    final nombre = [
      vehiculo.marca,
      vehiculo.modelo,
    ].where((p) => p != null && p.isNotEmpty).join(' ');

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.primary),
          tooltip: 'Volver',
          onPressed: () => context.go('/mechanic_search'),
        ),
        title: Text(
          'Vehículo',
          style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.bold),
        ),
        backgroundColor: colors.surfaceContainer,
        foregroundColor: colors.primary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: AppPageBody(
          maxWidth: AppBreakpoints.maxReadingWidth,
          child: AppCard(
            padding: const EdgeInsets.all(AppSpacing.xl),
            margin: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child:
                        vehiculo.fotoUrl != null && vehiculo.fotoUrl!.isNotEmpty
                        ? Image.network(
                            vehiculo.fotoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _SinFoto(colors: colors),
                          )
                        : _SinFoto(colors: colors),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  nombre.isEmpty ? 'Vehículo' : nombre,
                  style: AppTextStyles.headlineSmall.copyWith(
                    color: colors.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(vehiculo.placa, style: AppTextStyles.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${vehiculo.kilometrajeActual} km',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.base),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: colors.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: colors.primary),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'Necesitas una cotización aceptada por el '
                          'propietario para trabajar en este vehículo.',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: colors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SinFoto extends StatelessWidget {
  final AppColors colors;

  const _SinFoto({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: colors.surfaceContainer,
      child: Icon(
        Icons.directions_car,
        size: 64,
        color: colors.textSecondary.withValues(alpha: 0.5),
      ),
    );
  }
}
