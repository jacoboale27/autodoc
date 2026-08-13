import 'package:flutter/material.dart';
import 'package:autodoc/core/theme/app_motion.dart';

/// Número que cuenta hasta su valor.
///
/// Se ve varias veces al día (dashboards), así que la duración se mantiene
/// corta: un conteo de un segundo hace esperar al usuario a ver sus propias
/// cifras. Con reduced motion activo no cuenta: muestra el valor final.
class AnimatedCounter extends StatefulWidget {
  final num value;
  final TextStyle? style;

  /// Duración del conteo. Por defecto [kDefaultDuration].
  final Duration? duration;

  final String? prefix;
  final String? suffix;

  /// Texto que anuncia el lector de pantalla. Sin él, se anunciaría el valor
  /// intermedio del tween en vez del final.
  final String? semanticLabel;

  static const Duration kDefaultDuration = Duration(milliseconds: 600);

  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.duration,
    this.prefix = '',
    this.suffix = '',
    this.semanticLabel,
  });

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;
  num _oldValue = 0;

  Duration get _duration => widget.duration ?? AnimatedCounter.kDefaultDuration;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration);
    _animation = _tweenTo(widget.value);
    _controller.forward();
  }

  Animation<double> _tweenTo(num end) {
    return Tween<double>(
      begin: _oldValue.toDouble(),
      end: end.toDouble(),
    ).animate(CurvedAnimation(parent: _controller, curve: AppMotion.easeOut));
  }

  @override
  void didUpdateWidget(AnimatedCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _oldValue = oldWidget.value;
      _controller.duration = _duration;
      _animation = _tweenTo(widget.value);
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _format(num value) =>
      widget.value is int ? value.toInt().toString() : value.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final label =
        widget.semanticLabel ??
        '${widget.prefix}${_format(widget.value)}${widget.suffix}';

    // Reduced motion: sin conteo. El movimiento del número es precisamente lo
    // que la preferencia pide eliminar.
    if (AppMotion.reduced(context)) {
      return Semantics(
        label: label,
        excludeSemantics: true,
        child: Text(
          '${widget.prefix}${_format(widget.value)}${widget.suffix}',
          style: widget.style,
        ),
      );
    }

    return Semantics(
      label: label,
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) => Text(
          '${widget.prefix}${_format(_animation.value)}${widget.suffix}',
          style: widget.style,
        ),
      ),
    );
  }
}
