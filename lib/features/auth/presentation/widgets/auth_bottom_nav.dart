import 'package:flutter/material.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_shadows.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/utils/ui_utils.dart';

/// Barra de enlaces legales de la pantalla de acceso.
///
/// Las tres acciones abren enlaces reales; antes mostraban un `SnackBar`
/// de relleno («Abriendo sección de …») que no llevaba a ninguna parte.
class AuthBottomNav extends StatelessWidget {
  final AppColors colors;
  final bool isDark;

  /// Inyectable para tests; por defecto abre el navegador.
  final Future<void> Function(String url)? onOpenUrl;

  const AuthBottomNav({
    super.key,
    required this.colors,
    required this.isDark,
    this.onOpenUrl,
  });

  static const String _privacyUrl = 'https://autodoc.app/privacidad';
  static const String _termsUrl = 'https://autodoc.app/terminos';
  static const String _supportUrl = 'mailto:soporte@autodoc.app';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.outline.withValues(alpha: 0.2)),
        ),
        boxShadow: isDark ? AppShadows.darkSm : AppShadows.lightSm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _action(
            context,
            key: const ValueKey('auth-nav-help'),
            icon: Icons.help_outline,
            label: 'Ayuda',
            url: _supportUrl,
          ),
          _action(
            context,
            key: const ValueKey('auth-nav-privacy'),
            icon: Icons.shield_outlined,
            label: 'Privacidad',
            url: _privacyUrl,
          ),
          _action(
            context,
            key: const ValueKey('auth-nav-terms'),
            icon: Icons.gavel_outlined,
            label: 'Términos',
            url: _termsUrl,
          ),
        ],
      ),
    );
  }

  Widget _action(
    BuildContext context, {
    required Key key,
    required IconData icon,
    required String label,
    required String url,
  }) {
    return Flexible(
      child: Semantics(
        link: true,
        label: label,
        child: InkWell(
          key: key,
          onTap: () => (onOpenUrl ?? UiUtils.openExternalUrl)(url),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.sm,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 20, color: colors.textSecondary),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
