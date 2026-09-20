import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:autodoc/config/secrets.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_radius.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/utils/maps_availability.dart';
import 'package:autodoc/core/widgets/app_button.dart';

/// Centro de San Salvador: donde abre el mapa si el taller aún no tiene
/// ubicación.
const LatLng ubicacionPorDefectoTaller = LatLng(13.6929, -89.2182);

/// Abre el selector a pantalla completa y devuelve el punto elegido, o `null`
/// si la persona sale sin confirmar.
Future<LatLng?> elegirUbicacionDelTaller(
  BuildContext context, {
  LatLng? inicial,
}) {
  return Navigator.of(context).push<LatLng>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => SelectorUbicacionTallerScreen(
        inicial: inicial ?? ubicacionPorDefectoTaller,
      ),
    ),
  );
}

/// Mapa para fijar la ubicación del taller.
///
/// Observaciones del 2026-09-19: «el mapa no funciona y se queda estático sin
/// poder moverse». Vivía dentro de un `AlertDialog`, y en la web eso no
/// funciona: `main.dart` activa la semántica (`ensureSemantics`) y la capa de
/// accesibilidad del diálogo —su barrera, que se cierra al tocarla— queda en
/// el DOM **encima** del mapa, que es una vista de plataforma. Los clics y el
/// arrastre se los quedaba esa capa. Reproducido con el mismo `GoogleMap`: en
/// un diálogo no se mueve; en una página, sí.
///
/// Por lo mismo el mapa no va envuelto en un `Semantics`: el texto de ayuda de
/// arriba cuenta qué hacer.
class SelectorUbicacionTallerScreen extends StatefulWidget {
  final LatLng inicial;

  /// Sustituye al `GoogleMap` en las pruebas de widget, donde el plugin no
  /// tiene plataforma. Recibe el punto actual, a quién avisar al elegir otro
  /// y `alCargar`, que es el `onMapCreated` del mapa de verdad.
  ///
  /// El tercer argumento no es decorado: un mapa que NO llama a `alCargar`
  /// modela el caso que importa —la clave vencida, en el que Google pinta su
  /// cartel de error y la app no se entera—, y sin él ese camino no se podría
  /// probar.
  @visibleForTesting
  final Widget Function(
    LatLng punto,
    ValueChanged<LatLng> alElegir,
    VoidCallback alCargar,
  )?
  construirMapa;

  /// Cuánto se espera a que Google Maps cargue antes de dar por hecho que no
  /// va a cargar. Ver [_SelectorUbicacionTallerScreenState._mapaNoCargo].
  @visibleForTesting
  final Duration esperaDelMapa;

  const SelectorUbicacionTallerScreen({
    super.key,
    required this.inicial,
    this.construirMapa,
    this.esperaDelMapa = const Duration(seconds: 8),
  });

  @override
  State<SelectorUbicacionTallerScreen> createState() =>
      _SelectorUbicacionTallerScreenState();
}

class _SelectorUbicacionTallerScreenState
    extends State<SelectorUbicacionTallerScreen> {
  late LatLng _punto = widget.inicial;

  /// El mapa llegó a crearse.
  bool _mapaListo = false;

  /// Pasó [SelectorUbicacionTallerScreen.esperaDelMapa] sin que el mapa se
  /// creara.
  ///
  /// Observaciones del 2026-09-19: «no sirve el mapa en ninguna parte». La
  /// clave de Google Maps del entorno está VENCIDA (`ExpiredKeyMapError`), y
  /// entonces la API pinta su propio cartel gris —«Se ha producido un
  /// error»— dentro de la vista de plataforma: la app no se entera, no puede
  /// taparlo y la persona se queda sin poder fijar su ubicación.
  ///
  /// No hay callback de fallo en `google_maps_flutter`: si la API no carga,
  /// `onMapCreated` sencillamente no se llama nunca. Por eso se mide por
  /// tiempo. Al vencer, el mapa se SUSTITUYE (no se superpone): así se
  /// retira también el cartel de Google.
  bool _mapaNoCargo = false;

  Timer? _esperaMapa;

  late final TextEditingController _latitud = TextEditingController(
    text: widget.inicial.latitude.toStringAsFixed(6),
  );
  late final TextEditingController _longitud = TextEditingController(
    text: widget.inicial.longitude.toStringAsFixed(6),
  );

  @override
  void initState() {
    super.initState();
    // Sin clave no hay mapa que esperar: esa rama ya tiene su propio aviso.
    if (isMapUnavailable(isWeb: kIsWeb, apiKey: AppSecrets.googleMapsApiKey)) {
      return;
    }
    _esperaMapa = Timer(widget.esperaDelMapa, () {
      if (mounted && !_mapaListo) setState(() => _mapaNoCargo = true);
    });
  }

  @override
  void dispose() {
    _esperaMapa?.cancel();
    _latitud.dispose();
    _longitud.dispose();
    super.dispose();
  }

  void _mapaCargo() {
    _esperaMapa?.cancel();
    if (mounted && !_mapaListo) setState(() => _mapaListo = true);
  }

  /// El punto que se devuelve: el del mapa, o el que se tecleó si el mapa no
  /// cargó. Un número ilegible o fuera de rango deja el punto como estaba.
  LatLng get _puntoElegido {
    if (!_mapaNoCargo) return _punto;
    final lat = double.tryParse(_latitud.text.trim());
    final lng = double.tryParse(_longitud.text.trim());
    if (lat == null || lng == null) return _punto;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return _punto;
    return LatLng(lat, lng);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final sinMapa = isMapUnavailable(
      isWeb: kIsWeb,
      apiKey: AppSecrets.googleMapsApiKey,
    );

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text(
          'Ubicación del taller',
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: colors.surfaceContainer,
        foregroundColor: colors.primary,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: AppButton(
              key: const Key('selector_ubicacion_confirmar'),
              text: 'Confirmar',
              size: AppButtonSize.small,
              onPressed: () => Navigator.of(context).pop(_puntoElegido),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: _mapaNoCargo && !sinMapa
                ? _PanelSinMapa(
                    latitud: _latitud,
                    longitud: _longitud,
                    colors: colors,
                  )
                : widget.construirMapa != null
                ? widget.construirMapa!(
                    _punto,
                    (p) => setState(() => _punto = p),
                    _mapaCargo,
                  )
                : sinMapa
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Text(
                        'El mapa no está disponible en esta versión. Usa '
                        '«Usar mi ubicación actual» desde el taller.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  )
                : GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: widget.inicial,
                      zoom: 15,
                    ),
                    // `greedy`: un dedo o la rueda mueven el mapa sin pedir
                    // Ctrl ni dos dedos (el modo por defecto, `auto`, se
                    // vuelve «cooperativo» en una página con scroll).
                    webGestureHandling: WebGestureHandling.greedy,
                    onMapCreated: (_) => _mapaCargo(),
                    zoomControlsEnabled: true,
                    myLocationButtonEnabled: false,
                    onTap: (p) => setState(() => _punto = p),
                    markers: {
                      Marker(
                        markerId: const MarkerId('taller'),
                        position: _punto,
                        draggable: true,
                        onDragEnd: (p) => setState(() => _punto = p),
                      ),
                    },
                  ),
          ),
          if (!_mapaNoCargo)
            Positioned(
              left: AppSpacing.base,
              right: AppSpacing.base,
              top: AppSpacing.base,
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 520),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.base,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainer.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Text(
                      'Mueve el mapa y toca donde está tu taller (también '
                      'puedes arrastrar el marcador). Luego pulsa Confirmar.',
                      key: const Key('selector_ubicacion_ayuda'),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Lo que se ve cuando Google Maps no carga: por qué pasa y cómo seguir sin
/// él. Las coordenadas van prellenadas con el punto actual, así que
/// confirmar sin tocar nada no cambia la ubicación guardada.
class _PanelSinMapa extends StatelessWidget {
  final TextEditingController latitud;
  final TextEditingController longitud;
  final AppColors colors;

  const _PanelSinMapa({
    required this.latitud,
    required this.longitud,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.map_outlined, size: 48, color: colors.textSecondary),
              const SizedBox(height: AppSpacing.base),
              Text(
                'El mapa no se pudo cargar',
                key: const Key('selector_ubicacion_sin_mapa'),
                textAlign: TextAlign.center,
                style: AppTextStyles.titleMedium.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Suele ser la clave de Google Maps: vencida, sin facturación '
                'o restringida a otro dominio. Mientras tanto puedes escribir '
                'las coordenadas de tu taller, o usar «Usar mi ubicación '
                'actual» en la pantalla anterior.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall.copyWith(
                  color: colors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              TextField(
                key: const Key('selector_ubicacion_latitud'),
                controller: latitud,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Latitud',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.base),
              TextField(
                key: const Key('selector_ubicacion_longitud'),
                controller: longitud,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Longitud',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
