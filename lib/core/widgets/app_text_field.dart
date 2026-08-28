import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/theme/app_radius.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/utils/responsive.dart';

class AppTextField extends StatefulWidget {
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
  final int? maxLength;
  final int maxLines;
  final bool autofocus;
  final TextCapitalization textCapitalization;
  final bool readOnly;
  final VoidCallback? onTap;

  /// Pista bajo el campo. Prefiérela a meter la explicación en [hintText],
  /// que desaparece en cuanto el usuario escribe.
  final String? helperText;

  /// Error explícito para campos fuera de un `Form` o antes de validar.
  final String? errorText;

  /// Marca el campo como obligatorio: añade un asterisco visible y lo anuncia
  /// al lector de pantalla.
  final bool isRequired;

  /// Si `false`, el campo se muestra en modo lectura. `user_profile_screen`
  /// alterna entre lectura y edición con este parámetro.
  final bool enabled;

  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final void Function(String)? onSubmitted;

  /// Pistas para el gestor de contraseñas del sistema. Sin esto, iOS y
  /// Android no ofrecen rellenar el formulario de acceso.
  final Iterable<String>? autofillHints;

  /// Añade un botón de ojo que alterna [obscureText]. Solo tiene sentido
  /// cuando `obscureText` es `true`.
  final bool obscureToggle;

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
    this.maxLength,
    this.maxLines = 1,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.none,
    this.readOnly = false,
    this.onTap,
    this.helperText,
    this.errorText,
    this.isRequired = false,
    this.enabled = true,
    this.focusNode,
    this.textInputAction,
    this.onSubmitted,
    this.autofillHints,
    this.obscureToggle = false,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscured = widget.obscureText;

  @override
  void didUpdateWidget(AppTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.obscureText != widget.obscureText) {
      _obscured = widget.obscureText;
    }
  }

  Widget? _buildSuffix(AppColors colors) {
    if (!widget.obscureToggle) return widget.suffixIcon;
    return Tooltip(
      message: _obscured ? 'Mostrar contraseña' : 'Ocultar contraseña',
      child: IconButton(
        key: const ValueKey('app-text-field-obscure-toggle'),
        // 48x48 real: IconButton por defecto ya lo garantiza, pero lo
        // dejamos explícito porque InputDecoration puede encogerlo.
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        icon: Icon(
          _obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          color: colors.textSecondary,
        ),
        onPressed: () => setState(() => _obscured = !_obscured),
      ),
    );
  }

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

    final labelText = widget.label != null && widget.label!.isNotEmpty
        ? (widget.isRequired ? '${widget.label} *' : widget.label!)
        : null;

    final semanticLabel = labelText == null
        ? null
        : (widget.isRequired
              ? '${widget.label}, campo obligatorio'
              : widget.label!);

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
              controller: widget.controller,
              focusNode: widget.focusNode,
              enabled: widget.enabled,
              obscureText: _obscured,
              keyboardType: widget.keyboardType,
              validator: widget.validator,
              onChanged: widget.onChanged,
              inputFormatters: widget.inputFormatters,
              maxLength: widget.maxLength,
              maxLines: widget.maxLines,
              autofocus: widget.autofocus,
              textCapitalization: widget.textCapitalization,
              readOnly: widget.readOnly,
              onTap: widget.onTap,
              textInputAction: widget.textInputAction,
              onFieldSubmitted: widget.onSubmitted,
              autofillHints: widget.enabled ? widget.autofillHints : null,
              style: AppTextStyles.bodyLarge.copyWith(
                color: colors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: AppTextStyles.bodyLarge.copyWith(
                  color: colors.textSecondary.withValues(alpha: 0.6),
                ),
                prefixIcon: widget.prefixIcon != null
                    ? IconTheme(
                        data: IconThemeData(color: colors.textSecondary),
                        child: widget.prefixIcon!,
                      )
                    : null,
                suffixIcon: _buildSuffix(colors),
                suffixText: widget.suffixText,
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
                helperText: widget.helperText,
                errorText: widget.errorText,
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
