import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_radius.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/widgets/app_button.dart';

/// Proporción del banner en el perfil público (`_Portada`). El encuadre solo
/// tiene sentido contra ella.
const double kProporcionBanner = 3.2;

/// Elige qué franja del banner se ve en el perfil.
///
/// Observación del 2026-09-20: «el mecánico debería poder ajustar la parte
/// del banner que quiere que se vea, porque se encuadra como quiere la vd».
/// Casi ninguna foto es 3.2:1, así que `BoxFit.cover` recorta, y hasta ahora
/// el recorte se lo llevaba siempre el centro.
///
/// No recorta el archivo: guarda el `alignment` vertical en
/// `usuarios/{uid}.banner_encuadre` y lo publica el mismo trigger que el
/// resto de la ficha. Así la foto original se conserva entera y el ajuste se
/// puede cambiar mil veces sin volver a subir nada.
class AjustarBannerScreen extends StatefulWidget {
  final String urlBanner;

  const AjustarBannerScreen({super.key, required this.urlBanner});

  @override
  State<AjustarBannerScreen> createState() => _AjustarBannerScreenState();
}

class _AjustarBannerScreenState extends State<AjustarBannerScreen> {
  late double _encuadre =
      context.read<UserProfileProvider>().userData?.bannerEncuadre ?? 0;
  bool _guardando = false;

  Future<void> _guardar() async {
    if (_guardando) return;
    setState(() => _guardando = true);
    final perfil = context.read<UserProfileProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final usuario = perfil.userData;
      if (usuario == null) return;
      final ok = await perfil.updateProfile(
        usuario.copyWith(bannerEncuadre: _encuadre),
      );
      if (!ok) {
        messenger.showSnackBar(
          const SnackBar(content: Text('No se pudo guardar el encuadre.')),
        );
        return;
      }
      navigator.pop(true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text(
          'Encuadre del banner',
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: colors.surfaceContainer,
        foregroundColor: colors.primary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Así se verá la portada de tu perfil. Arrastra la foto (o '
                  'usa la barra) hasta dejar a la vista lo que quieras.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: colors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: AspectRatio(
                    aspectRatio: kProporcionBanner,
                    child: GestureDetector(
                      key: const Key('ajustar_banner_arrastre'),
                      // Arrastrar hacia abajo enseña la parte de ARRIBA de la
                      // foto, así que el alineamiento va en sentido
                      // contrario al dedo, como en cualquier visor.
                      onVerticalDragUpdate: (d) => setState(() {
                        _encuadre = (_encuadre - d.delta.dy / 60).clamp(
                          -1.0,
                          1.0,
                        );
                      }),
                      child: CachedNetworkImage(
                        imageUrl: widget.urlBanner,
                        fit: BoxFit.cover,
                        alignment: Alignment(0, _encuadre),
                        placeholder: (_, _) =>
                            Container(color: colors.surfaceContainer),
                        errorWidget: (_, _, _) => Container(
                          color: colors.surfaceContainer,
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.base),
                Row(
                  children: [
                    Icon(
                      Icons.vertical_align_top,
                      size: 18,
                      color: colors.textSecondary,
                    ),
                    Expanded(
                      child: Slider(
                        key: const Key('ajustar_banner_slider'),
                        value: _encuadre,
                        min: -1,
                        max: 1,
                        onChanged: (v) => setState(() => _encuadre = v),
                      ),
                    ),
                    Icon(
                      Icons.vertical_align_bottom,
                      size: 18,
                      color: colors.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  key: const Key('ajustar_banner_guardar'),
                  text: 'Guardar encuadre',
                  isLoading: _guardando,
                  onPressed: _guardando ? null : _guardar,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
