import 'package:flutter/material.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';

/// Encabezado de una sección dentro de una pantalla.
///
/// Unifica cinco variantes ad hoc que usaban cuatro tamaños distintos (11 / 12
/// / 16 / 18) para la misma jerarquía, cada una con su propia llamada a
/// `GoogleFonts`.
class AppSectionHeader extends StatelessWidget {
  final String title;

  /// Línea de apoyo bajo el título.
  final String? subtitle;

  /// Acción alineada a la derecha del título (p.ej. "Ver todo").
  final Widget? trailing;

  /// Variante de etiqueta: título en mayúsculas, más pequeño y con tracking.
  /// Es el estilo de los bloques de formulario.
  final bool uppercase;

  const AppSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.uppercase = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final titleStyle = uppercase
        ? AppTextStyles.labelSmall.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: colors.textSecondary,
          )
        : AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  uppercase ? title.toUpperCase() : title,
                  style: titleStyle,
                ),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.sm),
              trailing!,
            ],
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle!,
            style: AppTextStyles.bodySmall.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}
