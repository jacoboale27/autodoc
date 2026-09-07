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
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';

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

  /// ¿Hay ya una cotización aceptada de este taller para este vehículo?
  /// `null` mientras se comprueba.
  ///
  /// Sin esta distinción, el aviso de bloqueo tenía un solo texto para dos
  /// situaciones opuestas, y eso cerraba un bucle sin salida que la revisión
  /// adversarial reprodujo entero: la tarjeta de la cotización aceptada le
  /// dice al mecánico «Recibe el vehículo desde "Buscar Vehículo"», y Buscar
  /// Vehículo le respondía «Necesitas una cotización aceptada» cuando SÍ
  /// existía una. Ni diagnóstico ni salida. Aquí se separan: "todavía no hay
  /// cotización aceptada" (y se ofrece contactar al propietario) frente a
  /// "hay una, pero el ticket aún no se ha abierto" (y se ofrece ir al
  /// tablero, donde aparecerá).
  bool? _hayCotizacionAceptada;

  @override
  void initState() {
    super.initState();
    _vehiculo = widget.vehiculoPrecargado;
    if (_vehiculo == null) {
      _cargarVehiculo();
    } else {
      _comprobarCotizacionAceptada();
    }
  }

  /// Se filtra por `id_taller`, no por `id_mecanico == uid`.
  ///
  /// La pregunta que esta pantalla hace es «¿tiene MI TALLER una cotización
  /// aceptada de este vehículo?», y una cotización pertenece al taller, no al
  /// operario que la redactó. Filtrar por el uid de la sesión respondía otra
  /// pregunta: en un taller con empleados, el aviso decía «este vehículo no
  /// tiene una cotización aceptada en tu taller» a cualquiera que no fuera
  /// quien la escribió — al dueño incluida. Se filtraba así porque
  /// `firestore.rules` no admitía otra consulta de lista; la Ronda 4 añadió
  /// `actuaPorTaller(id_taller)` al `allow read` de /cotizaciones justo para
  /// esto.
  ///
  /// Un fallo aquí no rompe la pantalla: se queda en el aviso genérico, que
  /// es lo que había antes.
  Future<void> _comprobarCotizacionAceptada() async {
    final vehiculo = _vehiculo;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (vehiculo == null || uid == null) return;
    if (!mounted) return;
    // `idTallerEfectivo`: el uid del DUEÑO del taller, igual que el resto del
    // módulo (`vehicle_search_screen.dart`, `initiate_service_screen.dart`).
    final idTaller =
        context.read<UserProfileProvider>().userData?.idTallerEfectivo ?? uid;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('cotizaciones')
          .where('id_vehiculo', isEqualTo: vehiculo.idVehiculo)
          .where('id_taller', isEqualTo: idTaller)
          .where('estado', isEqualTo: 'aceptada')
          .limit(1)
          .get();
      if (!mounted) return;
      setState(() => _hayCotizacionAceptada = snap.docs.isNotEmpty);
    } catch (_) {
      if (!mounted) return;
      setState(() => _hayCotizacionAceptada = null);
    }
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
      _comprobarCotizacionAceptada();
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
                _AvisoDeBloqueo(
                  colors: colors,
                  hayCotizacionAceptada: _hayCotizacionAceptada,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// El aviso que explica POR QUÉ esta pantalla no ofrece ninguna acción.
///
/// Tiene dos textos y dos salidas porque hay dos causas distintas (ver
/// `_hayCotizacionAceptada`). Mientras la comprobación está en vuelo —o si
/// falló— se mantiene el texto genérico anterior: es el peor caso, no el
/// caso por defecto.
class _AvisoDeBloqueo extends StatelessWidget {
  final AppColors colors;
  final bool? hayCotizacionAceptada;

  const _AvisoDeBloqueo({
    required this.colors,
    required this.hayCotizacionAceptada,
  });

  @override
  Widget build(BuildContext context) {
    final conCotizacion = hayCotizacionAceptada == true;
    final texto = conCotizacion
        ? 'Este vehículo ya tiene una cotización aceptada en tu taller, pero '
              'el ticket todavía no se ha abierto. El ticket se abre solo al '
              'aceptarse la cotización y aparece en Reparaciones, en '
              '"Por recibir". Si no aparece ahí, no lo recibas desde aquí: '
              'avisa al soporte con la placa.'
        : 'Necesitas una cotización aceptada por el propietario para '
              'trabajar en este vehículo.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                conCotizacion ? Icons.hourglass_empty : Icons.info_outline,
                color: colors.primary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  texto,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: colors.primary,
                  ),
                ),
              ),
            ],
          ),
          if (conCotizacion) ...[
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => context.go('/mechanic_reparaciones'),
                icon: const Icon(Icons.dashboard_customize_outlined, size: 18),
                label: const Text('Ir a Reparaciones'),
              ),
            ),
          ],
        ],
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
