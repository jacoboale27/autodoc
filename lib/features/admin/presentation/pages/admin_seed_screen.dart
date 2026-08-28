import 'package:flutter/material.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/utils/responsive.dart';
import 'package:flutter/foundation.dart';
import 'package:autodoc/core/utils/l10n_extension.dart';

/// Pantalla que indicaba el estado de la migración de cuentas.
/// La semilla fue ejecutada con éxito y los secretos fueron eliminados por seguridad.
class AdminSeedScreen extends StatelessWidget {
  const AdminSeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    if (!kDebugMode) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.adminAccessDenied)),
        body: Center(child: Text(context.l10n.adminAccessDeniedDesc)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.adminConfigAdmins),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(Responsive.padding(context, 24.0)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.security,
                size: Responsive.iconSize(context, 80),
                color: colors.success,
              ),
              const SizedBox(height: 24),
              Text(
                'Migración Completada',
                style: AppTextStyles.headlineSmall.copyWith(
                  fontSize: Responsive.fontSize(context, 24),
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Las cuentas administrativas ya fueron configuradas y los secretos se eliminaron del código fuente por motivos de seguridad.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyLarge.copyWith(
                  fontSize: Responsive.fontSize(context, 16),
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
