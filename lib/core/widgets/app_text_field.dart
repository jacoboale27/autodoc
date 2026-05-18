import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:autodoc/core/theme/app_colors.dart';

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
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(
        color: colors.primary.withValues(alpha: 0.1),
        width: 1,
      ),
    );

    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(
        color: colors.primary,
        width: 2,
      ),
    );

    final errorBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(
        color: colors.error,
        width: 1,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null && label!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              label!,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.primary.withValues(alpha: 0.8),
              ),
            ),
          ),
        TextFormField(
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
          style: GoogleFonts.inter(
            fontSize: 16,
            color: colors.surface == const Color(0xFF0F172A) ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: GoogleFonts.inter(
              color: colors.primary.withValues(alpha: 0.3),
            ),
            prefixIcon: prefixIcon != null
                ? IconTheme(
                    data: IconThemeData(color: colors.primary.withValues(alpha: 0.6)),
                    child: prefixIcon!,
                  )
                : null,
            suffixIcon: suffixIcon,
            suffixText: suffixText,
            suffixStyle: GoogleFonts.inter(
              color: colors.primary.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
            filled: true,
            fillColor: colors.surfaceContainer,
            border: border,
            enabledBorder: border,
            focusedBorder: focusedBorder,
            errorBorder: errorBorder,
            focusedErrorBorder: errorBorder,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
        ),
      ],
    );
  }
}
