import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Widget centralizado para mostrar la imagen de un vehículo.
/// Maneja tanto URLs de red como rutas de assets (placeholders).
class VehicleImageWidget extends StatelessWidget {
  final String? imageUrl;
  final double? height;
  final double? width;
  final BoxFit fit;

  const VehicleImageWidget({
    super.key,
    this.imageUrl,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    const String placeholderAsset = 'assets/images/default_vehicle.png';

    // Si la URL es nula o vacía, mostrar placeholder
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildPlaceholder(placeholderAsset);
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
      errorWidget: (context, url, error) => _buildPlaceholder(placeholderAsset),
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
