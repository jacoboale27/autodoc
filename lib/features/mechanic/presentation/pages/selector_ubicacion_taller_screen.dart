import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_radius.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/widgets/mapa_osm.dart';

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
/// el DOM **encima** del mapa, que era una vista de plataforma. Los clics y
/// el arrastre se los quedaba esa capa. De ahí que esto sea una pantalla
/// completa y no un diálogo.
///
/// Observación del 2026-09-20 («arregla lo del mapa»): la segunda causa era
/// la clave de Google Maps, vencida. Ya no hay clave: el mapa son tiles de
/// OpenStreetMap dibujados por Flutter ([MapaOsm]), así que no hay vista de
/// plataforma, ni clave que caduque, ni facturación que se caiga.
class SelectorUbicacionTallerScreen extends StatefulWidget {
  final LatLng inicial;

  const SelectorUbicacionTallerScreen({super.key, required this.inicial});

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
            child: MapaOsm(
              key: const Key('selector_ubicacion_mapa'),
              centro: widget.inicial,
              zoom: 15,
              onTap: (p) => setState(() => _punto = p),
              marcadores: [MarcadorMapa(punto: _punto, color: colors.primary)],
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
                    'Mueve el mapa y toca donde está tu taller. Luego pulsa '
                    'Confirmar.',
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
