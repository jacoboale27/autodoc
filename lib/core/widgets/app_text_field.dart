import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/theme/app_radius.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/utils/responsive.dart';

class AppTextField extends StatelessWidget {
  final String? label;
  final String? hintText;
  final TextEditingController? controller;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? suffixText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final TextCapitalization textCapitalization;
  final bool readOnly;
  final VoidCallback? onTap;

  /// Pista bajo el campo. Prefiérela a meter la explicación en [hintText],
  /// que desaparece en cuanto el usuario escribe.
  final String? helperText;

  /// Marca el campo como obligatorio: añade un asterisco visible y lo anuncia
  /// al lector de pantalla.
  final bool isRequired;

  const AppTextField({
    super.key,
    this.label,
    this.hintText,
    this.controller,
    this.prefixIcon,
    this.suffixIcon,
    this.suffixText,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.onChanged,
    this.inputFormatters,
    this.maxLines = 1,
    this.textCapitalization = TextCapitalization.none,
    this.readOnly = false,
    this.onTap,
    this.helperText,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      borderSide: BorderSide(
        color: colors.outline.withValues(alpha: 0.3),
        width: 1,
      ),
    );

    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      borderSide: BorderSide(color: colors.primary, width: 2),
    );

    final errorBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      borderSide: BorderSide(color: colors.error, width: 1),
    );

    final labelText = label != null && label!.isNotEmpty
        ? (isRequired ? '$label *' : label!)
        : null;

    final semanticLabel = labelText == null
        ? null
        : (isRequired ? '$label, campo obligatorio' : label!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (labelText != null)
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.xs,
              bottom: AppSpacing.sm,
            ),
            child: Text(
              labelText,
              style: AppTextStyles.labelLarge.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        // MergeSemantics: sin él, el label del Semantics ancestro y el
        // SemanticsNode propio del EditableText (con sus flags/acciones de
        // campo de texto) quedan como nodos separados en el árbol, y el
        // lector de pantalla no anuncia la etiqueta al enfocar el campo.
        MergeSemantics(
          child: Semantics(
            label: semanticLabel,
            child: TextFormField(
              controller: controller,
              obscureText: obscureText,
              keyboardType: keyboardType,
              validator: validator,
              onChanged: onChanged,
              inputFormatters: inputFormatters,
              maxLines: maxLines,
              textCapitalization: textCapitalization,
              readOnly: readOnly,
              onTap: onTap,
              style: AppTextStyles.bodyLarge.copyWith(
                color: colors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: AppTextStyles.bodyLarge.copyWith(
                  color: colors.textSecondary.withValues(alpha: 0.6),
                ),
                prefixIcon: prefixIcon != null
                    ? IconTheme(
                        data: IconThemeData(color: colors.textSecondary),
                        child: prefixIcon!,
                      )
                    : null,
                suffixIcon: suffixIcon,
                suffixText: suffixText,
                suffixStyle: AppTextStyles.labelLarge.copyWith(
                  color: colors.textSecondary,
                ),
                filled: true,
                fillColor: colors.surfaceContainer,
                border: border,
                enabledBorder: border,
                focusedBorder: focusedBorder,
                errorBorder: errorBorder,
                focusedErrorBorder: errorBorder,
                helperText: helperText,
                helperStyle: AppTextStyles.bodySmall.copyWith(
                  color: colors.textSecondary,
                ),
                errorStyle: AppTextStyles.bodySmall.copyWith(
                  color: colors.error,
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: Responsive.padding(context, AppSpacing.lg),
                  vertical: Responsive.padding(context, AppSpacing.base),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
