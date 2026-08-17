import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_radius.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/widgets/app_page_body.dart';
import 'package:autodoc/core/widgets/app_snackbar.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = '';
  String _buildNumber = '';

  @override
  void initState() {
    super.initState();
    _initPackageInfo();
  }

  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _version = info.version;
      _buildNumber = info.buildNumber;
    });
  }

  Future<void> _launchUrl(String urlString) async {
    final url = Uri.parse(urlString);
    final opened = await canLaunchUrl(url) && await launchUrl(url);
    if (!opened && mounted) {
      // El usuario merece saber que no pasó nada. `upAboutLinkError` no
      // existe en el ARB y la fase prohíbe añadir claves nuevas; mostramos
      // la URL literal para que el usuario pueda copiarla.
      AppSnackbar.show(context, urlString, type: SnackbarType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surfaceContainer,
        elevation: 0,
        title: Text(
          'Acerca de AutoDoc',
          style: AppTextStyles.titleMedium.copyWith(color: colors.textPrimary),
        ),
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      body: AppPageBody(
        maxWidth: AppBreakpoints.maxReadingWidth,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: AppSpacing.xxl),
              Container(
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.directions_car,
                  size: 80,
                  color: colors.primary,
                  semanticLabel: 'AutoDoc',
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'AutoDoc',
                style: AppTextStyles.headlineMedium.copyWith(
                  color: colors.textPrimary,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Tu copiloto digital para el cuidado del vehículo',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: colors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxl),
              Container(
                key: const ValueKey('about-info-card'),
                decoration: BoxDecoration(
                  color: colors.surfaceContainer,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Column(
                  children: [
                    _tile(
                      colors,
                      icon: Icons.info_outline,
                      title: 'Versión',
                      trailing: Text(
                        _version.isEmpty ? '—' : '$_version ($_buildNumber)',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                    _divider(colors),
                    _tile(
                      colors,
                      icon: Icons.email_outlined,
                      title: 'Soporte Técnico',
                      onTap: () => _launchUrl('mailto:soporte@autodoc.app'),
                    ),
                    _divider(colors),
                    _tile(
                      colors,
                      icon: Icons.privacy_tip_outlined,
                      title: 'Política de Privacidad',
                      onTap: () => _launchUrl('https://autodoc.app/privacidad'),
                    ),
                    _divider(colors),
                    _tile(
                      colors,
                      icon: Icons.gavel_outlined,
                      title: 'Términos y Condiciones',
                      onTap: () => _launchUrl('https://autodoc.app/terminos'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                '© ${DateTime.now().year} AutoDoc Inc.\n'
                'Todos los derechos reservados.',
                key: const ValueKey('about-copyright'),
                style: AppTextStyles.bodySmall.copyWith(
                  color: colors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider(AppColors colors) =>
      Divider(height: 1, color: colors.outline.withValues(alpha: 0.2));

  Widget _tile(
    AppColors colors, {
    required IconData icon,
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: colors.primary),
      title: Text(
        title,
        style: AppTextStyles.bodyLarge.copyWith(color: colors.textPrimary),
      ),
      trailing:
          trailing ??
          (onTap == null
              ? null
              : Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: colors.textSecondary,
                )),
      onTap: onTap,
    );
  }
}
