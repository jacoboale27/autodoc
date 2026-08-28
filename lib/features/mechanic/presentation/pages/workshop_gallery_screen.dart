import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:autodoc/config/secrets.dart';
import 'package:autodoc/core/models/galeria_taller.dart';
import 'package:autodoc/core/providers/auth_session_provider.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_radius.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/widgets/app_dialog_content.dart';
import 'package:autodoc/core/widgets/app_page_body.dart';
import 'package:autodoc/features/mechanic/presentation/providers/galeria_provider.dart';
import 'package:autodoc/features/mechanic/presentation/widgets/mechanic_scaffold.dart';

/// Galería comercial del taller: el logo y hasta cinco fotos del local.
///
/// Solo se llega aquí con la cuenta ya aprobada — no está en las rutas de
/// onboarding del enrutador, y `storage.rules` exige `esTallerAprobado` para
/// escribir. Es la contrapartida de la pantalla de verificación: allí se sube
/// evidencia privada para que te aprueben; aquí se publica escaparate una vez
/// aprobado.
class WorkshopGalleryScreen extends StatefulWidget {
  const WorkshopGalleryScreen({super.key});

  @override
  State<WorkshopGalleryScreen> createState() => _WorkshopGalleryScreenState();
}

class _WorkshopGalleryScreenState extends State<WorkshopGalleryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = context.read<AuthSessionProvider>().currentUid;
      if (uid.isNotEmpty) context.read<GaleriaProvider>().cargar(uid);
    });
  }

  Future<void> _elegirYSubir(String slot) async {
    final provider = context.read<GaleriaProvider>();
    final uid = context.read<AuthSessionProvider>().currentUid;
    if (uid.isEmpty) return;

    final archivo = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      // El tope de storage.rules son 5 MB. Reducir aqui evita rebotar contra
      // ese limite con una foto de camara moderna, y una tarjeta de directorio
      // no necesita mas resolucion.
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (archivo == null) return;

    final bytes = await archivo.readAsBytes();
    final ok = await provider.subirFoto(
      tallerId: uid,
      slot: slot,
      nombreOriginal: archivo.name,
      bytes: bytes,
    );
    if (!mounted) return;
    if (!ok) _avisar(provider.error!);
  }

  Future<void> _quitar(String slot) async {
    final provider = context.read<GaleriaProvider>();
    final uid = context.read<AuthSessionProvider>().currentUid;
    if (uid.isEmpty) return;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Quitar foto'),
        content: const AppDialogContent(
          child: Text(
            'La foto dejará de verse en tu ficha del directorio. Puedes volver a '
            'subir otra en su lugar.',
          ),
        ),
        actions: [
          AppButton(
            text: 'Cancelar',
            type: AppButtonType.text,
            size: AppButtonSize.small,
            onPressed: () => Navigator.pop(dialogContext, false),
          ),
          AppButton(
            text: 'Quitar',
            type: AppButtonType.danger,
            size: AppButtonSize.small,
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );
    if (confirmado != true) return;

    final ok = await provider.quitarFoto(tallerId: uid, slot: slot);
    if (!mounted) return;
    if (!ok) _avisar(provider.error!);
  }

  void _avisar(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final provider = context.watch<GaleriaProvider>();
    final uid = context.watch<AuthSessionProvider>().currentUid;

    return MechanicScaffold(
      title: 'Fotos del taller',
      body: provider.cargando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: AppPageBody(
                maxWidth: AppBreakpoints.maxFormWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estas fotos son las que ven los clientes en el '
                      'directorio. El logo es la imagen principal de tu ficha.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: colors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),

                    _tarjeta(colors, provider, uid, GaleriaTaller.slotLogo),
                    const SizedBox(height: AppSpacing.xl),

                    Text(
                      'Fotos del local',
                      style: AppTextStyles.titleMedium.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    for (var i = 1; i <= GaleriaTaller.maxFotosLocal; i++) ...[
                      _tarjeta(colors, provider, uid, 'local-$i'),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _tarjeta(
    AppColors colors,
    GaleriaProvider provider,
    String uid,
    String slot,
  ) {
    final esLogo = slot == GaleriaTaller.slotLogo;
    final archivo = provider.galeria.archivoDe(slot);
    final enCurso = provider.slotEnCurso == slot;
    final url = archivo == null
        ? null
        : GaleriaTaller.urlDe(
            bucket: AppSecrets.firebaseStorageBucket,
            idTaller: uid,
            nombreArchivo: archivo,
          );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.outline.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            height: 72,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: url != null
                  ? CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) =>
                          _marcador(colors, Icons.broken_image_outlined),
                    )
                  : _marcador(
                      colors,
                      esLogo
                          ? Icons.storefront_outlined
                          : Icons.add_photo_alternate_outlined,
                    ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  esLogo ? 'Logo del taller' : 'Foto ${slot.split('-').last}',
                  style: AppTextStyles.titleSmall.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  archivo != null
                      ? 'Publicada.'
                      : esLogo
                      ? 'Es la imagen principal de tu ficha.'
                      : 'Opcional.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (enCurso)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else ...[
            if (archivo != null)
              IconButton(
                onPressed: () => _quitar(slot),
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Quitar',
              ),
            AppButton(
              text: archivo != null ? 'Cambiar' : 'Subir',
              type: AppButtonType.text,
              size: AppButtonSize.small,
              onPressed: () => _elegirYSubir(slot),
            ),
          ],
        ],
      ),
    );
  }

  Widget _marcador(AppColors colors, IconData icono) => Container(
    color: colors.surface,
    child: Center(child: Icon(icono, color: colors.textSecondary)),
  );
}
