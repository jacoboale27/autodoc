import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';

/// Un punto que se dibuja sobre el mapa.
class MarcadorMapa {
  final LatLng punto;
  final Color color;

  /// Qué pasa al tocarlo. `null` = no es pulsable.
  final VoidCallback? onTap;

  /// Rótulo corto bajo el pin (el nombre del taller). `null` = solo el pin.
  final String? etiqueta;

  const MarcadorMapa({
    required this.punto,
    required this.color,
    this.onTap,
    this.etiqueta,
  });
}

/// El mapa de la app: tiles de OpenStreetMap dibujados por Flutter.
///
/// Observación del 2026-09-20 («no sirve el mapa en ninguna parte»): con
/// Google Maps, una clave vencida deja la app sin mapa —y sin forma de
/// enterarse, porque el error lo pinta la propia API dentro de una vista de
/// plataforma—. Esto no usa clave, ni facturación, ni vista de plataforma:
/// son imágenes y widgets, así que además funciona dentro de un diálogo, se
/// puede probar en un widget test y no puede caducar.
///
/// La atribución NO es decorativa: la política de uso de los tiles de OSM la
/// exige. Si algún día se cambia de proveedor de tiles, cambia con ella.
class MapaOsm extends StatefulWidget {
  final LatLng centro;
  final double zoom;
  final List<MarcadorMapa> marcadores;

  /// Toque sobre el mapa (no sobre un marcador).
  final void Function(LatLng punto)? onTap;

  /// Controlador para mover la cámara desde fuera (el directorio centra el
  /// mapa en el taller que se elige en la lista).
  final MapController? controlador;

  const MapaOsm({
    super.key,
    required this.centro,
    this.zoom = 13,
    this.marcadores = const [],
    this.onTap,
    this.controlador,
  });

  @override
  State<MapaOsm> createState() => _MapaOsmState();
}

class _MapaOsmState extends State<MapaOsm> {
  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return FlutterMap(
      mapController: widget.controlador,
      options: MapOptions(
        initialCenter: widget.centro,
        initialZoom: widget.zoom,
        onTap: widget.onTap == null ? null : (_, punto) => widget.onTap!(punto),
        // Sin rotación: gira sin querer con dos dedos y después nadie sabe
        // enderezarlo.
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          // La política de OSM pide identificar la aplicación.
          userAgentPackageName: 'sv.autodoc.app',
          tileProvider: NetworkTileProvider(),
        ),
        MarkerLayer(
          markers: [
            for (final m in widget.marcadores)
              Marker(
                point: m.punto,
                width: m.etiqueta == null ? 40 : 120,
                height: m.etiqueta == null ? 40 : 56,
                // El pin apunta al punto: su punta es el borde de abajo.
                alignment: Alignment.topCenter,
                child: GestureDetector(
                  onTap: m.onTap,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_on, color: m.color, size: 36),
                      if (m.etiqueta != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surface.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            m.etiqueta!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        RichAttributionWidget(
          attributions: [TextSourceAttribution('OpenStreetMap', onTap: () {})],
        ),
      ],
    );
  }
}
