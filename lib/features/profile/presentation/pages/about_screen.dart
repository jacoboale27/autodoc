import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:autodoc/core/utils/responsive.dart';

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
    setState(() {
      _version = info.version;
      _buildNumber = info.buildNumber;
    });
  }

  Future<void> _launchUrl(String urlString) async {
    final url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
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
          style: GoogleFonts.montserrat(
            color: colors.textPrimary,
            fontSize: Responsive.fontSize(context, 16),
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            // Logo
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.directions_car,
                size: 80,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'AutoDoc',
              style: GoogleFonts.montserrat(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tu copiloto digital para el cuidado del vehículo',
              style: TextStyle(color: colors.textSecondary, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            // Info Cards
            Container(
              decoration: BoxDecoration(
                color: colors.surfaceContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.info_outline, color: colors.primary),
                    title: const Text('Versión'),
                    trailing: Text(
                      '$_version ($_buildNumber)',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: colors.outline.withValues(alpha: 0.2),
                  ),
                  ListTile(
                    leading: Icon(Icons.email_outlined, color: colors.primary),
                    title: const Text('Soporte Técnico'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => _launchUrl('mailto:soporte@autodoc.app'),
                  ),
                  Divider(
                    height: 1,
                    color: colors.outline.withValues(alpha: 0.2),
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.privacy_tip_outlined,
                      color: colors.primary,
                    ),
                    title: const Text('Política de Privacidad'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => _launchUrl('https://autodoc.app/privacidad'),
                  ),
                  Divider(
                    height: 1,
                    color: colors.outline.withValues(alpha: 0.2),
                  ),
                  ListTile(
                    leading: Icon(Icons.gavel_outlined, color: colors.primary),
                    title: const Text('Términos y Condiciones'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => _launchUrl('https://autodoc.app/terminos'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
            Text(
              '© ${DateTime.now().year} AutoDoc Inc.\nTodos los derechos reservados.',
              style: TextStyle(
                color: colors.textSecondary.withValues(alpha: 0.7),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
