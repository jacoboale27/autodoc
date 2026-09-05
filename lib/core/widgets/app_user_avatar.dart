import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:autodoc/core/theme/app_colors.dart';

/// Avatar de usuario con foto de perfil, con dos fallbacks en cascada:
/// la inicial del nombre si no hay foto (o falla al cargar), y un icono
/// genérico si tampoco hay nombre.
///
/// Recibe la URL ya resuelta: no hace ninguna lectura por su cuenta (ver
/// C1 en `docs/superpowers/plans/2026-09-02-hallazgos-uso-real.md`) — quien
/// lo usa decide de dónde sale esa URL (una lectura ya en curso, un campo
/// denormalizado, etc.), así que el mismo widget sirve tanto para una fila
/// de lista (sin lecturas extra) como para un `FutureBuilder` puntual.
class AppUserAvatar extends StatelessWidget {
  final String? urlFoto;
  final String nombre;
  final double radius;

  const AppUserAvatar({
    super.key,
    required this.urlFoto,
    required this.nombre,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final url = urlFoto;
    final tieneFoto = url != null && url.isNotEmpty;

    return CircleAvatar(
      radius: radius,
      backgroundColor: colors.primary.withValues(alpha: 0.2),
      child: tieneFoto
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: url,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                placeholder: (context, url) => _fallback(colors),
                errorWidget: (context, url, error) => _fallback(colors),
              ),
            )
          : _fallback(colors),
    );
  }

  Widget _fallback(AppColors colors) {
    final inicial = nombre.trim();
    if (inicial.isEmpty) {
      return Icon(Icons.person, color: colors.primary);
    }
    return Text(
      inicial[0].toUpperCase(),
      style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold),
    );
  }
}
