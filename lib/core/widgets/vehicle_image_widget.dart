import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:autodoc/core/constants/tipos_vehiculo.dart';

/// Widget centralizado para mostrar la imagen de un vehículo.
/// Maneja tanto URLs de red como rutas de assets (placeholders).
class VehicleImageWidget extends StatelessWidget {
  final String? imageUrl;
  final double? height;
  final double? width;
  final BoxFit fit;

  /// `vehiculos.tipo_vehiculo`. Sin foto, el marcador de posición es una
  /// FOTO DE COCHE, y para una moto o un camión eso es mentira
  /// (observaciones del 2026-09-20). Con el tipo a mano se dibuja su icono.
  /// Automóvil y camioneta siguen con la foto: para ellos sí es lo que es.
  final String? tipoVehiculo;

  const VehicleImageWidget({
    super.key,
    this.imageUrl,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
    this.tipoVehiculo,
  });

  /// Tipos para los que la foto genérica de coche no sirve.
  static const Set<TipoVehiculo> _tiposSinFotoGenerica = {
    TipoVehiculo.motocicleta,
    TipoVehiculo.camion,
    TipoVehiculo.microbus,
    TipoVehiculo.autobus,
  };

  @override
  Widget build(BuildContext context) {
    const String placeholderAsset = 'assets/images/default_vehicle.jpg';

    // Si la URL es nula o vacía, mostrar placeholder
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _marcadorPorTipo(context) ?? _buildPlaceholder(placeholderAsset);
    }

    // Si la URL es un asset local
    if (imageUrl!.startsWith('assets/')) {
      return _buildPlaceholder(imageUrl!);
    }

    // Si es una URL de red
    return CachedNetworkImage(
      imageUrl: imageUrl!,
      height: height,
      width: width,
      fit: fit,
      placeholder: (context, url) => Container(
        height: height,
        width: width,
        color: Colors.grey[200],
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      errorWidget: (context, url, error) {
        // Sin esto el fallo es invisible: el usuario ve el placeholder y en
        // Firestore hay una foto_url perfectamente valida, asi que parece que
        // la busqueda no encontro nada cuando en realidad fue la descarga la
        // que fallo (anti-hotlink, CORS en web, enlace muerto...).
        debugPrint('[VehicleImageWidget] No se pudo cargar $url: $error');
        return _marcadorPorTipo(context) ?? _buildPlaceholder(placeholderAsset);
      },
    );
  }

  /// Icono del tipo sobre fondo neutro, o `null` si para este tipo la foto
  /// genérica sigue valiendo (o no se sabe el tipo).
  Widget? _marcadorPorTipo(BuildContext context) {
    if (tipoVehiculo == null) return null;
    final tipo = TipoVehiculo.desdeId(tipoVehiculo);
    if (!_tiposSinFotoGenerica.contains(tipo)) return null;
    final colores = Theme.of(context).colorScheme;
    return Container(
      height: height,
      width: width,
      color: colores.surfaceContainerHighest,
      child: Center(
        child: Icon(
          tipo.icono,
          size: (height == null || height! > 120) ? 56 : 32,
          color: colores.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildPlaceholder(String assetPath) {
    return Image.asset(
      assetPath,
      height: height,
      width: width,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        // Fallback final si el asset no existe
        return Container(
          height: height,
          width: width,
          color: Colors.grey[200],
          child: const Icon(Icons.directions_car, size: 48, color: Colors.grey),
        );
      },
    );
  }
}
