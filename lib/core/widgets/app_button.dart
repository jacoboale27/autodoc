import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_motion.dart';
import 'package:autodoc/core/theme/app_radius.dart';
import 'package:autodoc/core/theme/app_shadows.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/utils/responsive.dart';

enum AppButtonType { primary, secondary, text }

enum AppButtonSize { small, medium, large }

/// Alto mínimo tappable. Material y las HIG de iOS piden 48 dp / 44 pt; se toma
/// el mayor de los dos para no tener dos comportamientos por plataforma.
const double _kMinTapHeight = 48.0;

class AppButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final AppButtonType type;
  final AppButtonSize size;
  final bool isLoading;
  final bool hapticFeedback;
  final Widget? icon;

  /// Descripción para lector de pantalla cuando [text] no basta por sí solo
  /// ("Guardar" → "Guardar los cambios del vehículo").
  final String? semanticLabel;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.type = AppButtonType.primary,
    this.size = AppButtonSize.medium,
    this.isLoading = false,
    this.hapticFeedback = true,
    this.icon,
    this.semanticLabel,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _isPressed = false;
  bool _isHovered = false;

  bool get _interactive => widget.onPressed != null && !widget.isLoading;

  void _setPressed(bool value) {
    if (!_interactive || _isPressed == value) return;
    setState(() => _isPressed = value);
  }

  void _setHovered(bool value) {
    if (!_interactive || _isHovered == value) return;
    setState(() => _isHovered = value);
  }

  void _handlePress() {
    if (!_interactive) return;
    if (widget.hapticFeedback) {
      HapticFeedback.lightImpact();
    }
    widget.onPressed!();
  }

  ({Color background, Color foreground, List<Color>? gradient}) _palette(
    AppColors colors,
  ) {
    return switch (widget.type) {
      AppButtonType.primary => (
        background: colors.primary,
        foreground: colors.onPrimary,
        gradient: [colors.primary, colors.primary.withValues(alpha: 0.85)],
      ),
      AppButtonType.secondary => (
        background: colors.secondary,
        foreground: colors.onSecondary,
        gradient: null,
      ),
      AppButtonType.text => (
        background: Colors.transparent,
        foreground: colors.primary,
        gradient: null,
      ),
    };
  }

  ({EdgeInsets padding, TextStyle textStyle, double iconSize}) _metrics(
    BuildContext context,
  ) {
    return switch (widget.size) {
      AppButtonSize.small => (
        padding: EdgeInsets.symmetric(
          vertical: Responsive.padding(context, AppSpacing.sm),
          horizontal: Responsive.padding(context, AppSpacing.base),
        ),
        textStyle: AppTextStyles.labelMedium,
        iconSize: Responsive.iconSize(context, 16),
      ),
      AppButtonSize.medium => (
        padding: EdgeInsets.symmetric(
          vertical: Responsive.padding(context, 14),
          horizontal: Responsive.padding(context, AppSpacing.xl),
        ),
        textStyle: AppTextStyles.titleSmall,
        iconSize: Responsive.iconSize(context, 20),
      ),
      AppButtonSize.large => (
        padding: EdgeInsets.symmetric(
          vertical: Responsive.padding(context, 18),
          horizontal: Responsive.padding(context, AppSpacing.xxl),
        ),
        textStyle: AppTextStyles.titleMedium,
        iconSize: Responsive.iconSize(context, 24),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = _palette(colors);
    final metrics = _metrics(context);

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.full),
    );

    final textWidget = Text(
      widget.text,
      style: metrics.textStyle.copyWith(color: palette.foreground),
      overflow: TextOverflow.ellipsis,
    );

    Widget childContent;
    if (widget.isLoading) {
      childContent = SizedBox(
        height: metrics.iconSize,
        width: metrics.iconSize,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(palette.foreground),
        ),
      );
    } else if (widget.icon != null) {
      childContent = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconTheme(
            data: IconThemeData(
              size: metrics.iconSize,
              color: palette.foreground,
            ),
            child: widget.icon!,
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(child: textWidget),
        ],
      );
    } else {
      childContent = textWidget;
    }

    // La sombra sí se pinta aquí (antes se configuraba shadowColor con
    // elevation: 0, así que Material nunca la dibujaba).
    final resting = widget.type == AppButtonType.text
        ? const <BoxShadow>[]
        : (isDark ? AppShadows.darkSm : AppShadows.lightSm);
    final hovered = widget.type == AppButtonType.text
        ? const <BoxShadow>[]
        : (isDark ? AppShadows.darkHover : AppShadows.lightHover);

    Widget surface = AnimatedContainer(
      duration: AppMotion.hover,
      curve: AppMotion.easeOut,
      constraints: const BoxConstraints(minHeight: _kMinTapHeight),
      padding: metrics.padding,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: palette.gradient == null ? palette.background : null,
        gradient: palette.gradient != null
            ? LinearGradient(
                colors: palette.gradient!,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        borderRadius: BorderRadius.circular(AppRadius.full),
        boxShadow: _isHovered ? hovered : resting,
      ),
      child: childContent,
    );

    if (widget.isLoading && widget.type != AppButtonType.text) {
      surface = surface
          .animate(onPlay: (controller) => controller.repeat())
          .shimmer(
            duration: 1500.ms,
            color: palette.foreground.withValues(alpha: 0.2),
          );
    }

    final button = Material(
      color: Colors.transparent,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _interactive ? _handlePress : null,
        borderRadius: BorderRadius.circular(AppRadius.full),
        hoverColor: colors.hoverOverlay,
        highlightColor: colors.pressedOverlay,
        child: surface,
      ),
    );

    return Semantics(
      button: true,
      enabled: _interactive,
      focusable: true,
      label: widget.semanticLabel ?? widget.text,
      // Siempre true: el propio Semantics ya declara el label (semanticLabel
      // o widget.text); sin esto, el Text hijo aporta el suyo y el lector de
      // pantalla anuncia el texto duplicado ("Guardar\nGuardar"). Como excluye
      // también la acción de tap y el foco del InkWell, se reexponen aquí.
      excludeSemantics: true,
      onTap: _interactive ? _handlePress : null,
      child: MouseRegion(
        cursor: _interactive
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onEnter: (_) => _setHovered(true),
        onExit: (_) => _setHovered(false),
        // Listener (eventos de puntero crudos) en vez de GestureDetector:
        // GestureDetector competiría en la gesture arena con el InkWell y le
        // robaría el ripple.
        child: Listener(
          onPointerDown: (_) => _setPressed(true),
          onPointerUp: (_) => _setPressed(false),
          onPointerCancel: (_) => _setPressed(false),
          child: AnimatedScale(
            // El press gana al hover: si el usuario está presionando, lo que
            // debe ver es la confirmación del toque, no el lift.
            scale: _isPressed
                ? AppMotion.pressScaleFor(context)
                : _isHovered
                ? AppMotion.hoverScaleFor(context)
                : 1.0,
            duration: AppMotion.transformDuration(
              context,
              _isPressed ? AppMotion.press : AppMotion.hover,
            ),
            curve: AppMotion.easeOut,
            child: button,
          ),
        ),
      ),
    );
  }
}
