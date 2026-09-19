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
  /// tiene plataforma. Recibe el punto actual y a quién avisar al elegir otro.
  @visibleForTesting
  final Widget Function(LatLng punto, ValueChanged<LatLng> alElegir)?
  construirMapa;

  const SelectorUbicacionTallerScreen({
    super.key,
    required this.inicial,
    this.construirMapa,
  });

  @override
  State<SelectorUbicacionTallerScreen> createState() =>
      _SelectorUbicacionTallerScreenState();
}

class _SelectorUbicacionTallerScreenState
    extends State<SelectorUbicacionTallerScreen> {
  late LatLng _punto = widget.inicial;

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
              onPressed: () => Navigator.of(context).pop(_punto),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: widget.construirMapa != null
                ? widget.construirMapa!(
                    _punto,
                    (p) => setState(() => _punto = p),
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
