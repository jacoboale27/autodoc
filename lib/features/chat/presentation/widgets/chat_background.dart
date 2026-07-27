import 'package:flutter/material.dart';
import 'dart:math' as math;

class ChatBackgroundPattern extends StatelessWidget {
  final Color color;

  const ChatBackgroundPattern({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ChatPatternPainter(color: color),
      child: Container(),
    );
  }
}

class _ChatPatternPainter extends CustomPainter {
  final Color color;

  _ChatPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final double step = 80;

    for (double x = 0; x < size.width; x += step) {
      for (double y = 0; y < size.height; y += step) {
        // Draw a mix of simple shapes resembling car parts (gears, wrenches)
        final int type = ((x + y) / step).round() % 3;

        canvas.save();
        canvas.translate(x + step / 2, y + step / 2);

        // Add a slight rotation for organic feel
        canvas.rotate(math.pi / 4 * type);

        if (type == 0) {
          // Simple wrench
          canvas.drawCircle(const Offset(-10, -10), 4, paint);
          canvas.drawLine(const Offset(-8, -8), const Offset(8, 8), paint);
          canvas.drawArc(
            Rect.fromCircle(center: const Offset(10, 10), radius: 5),
            math.pi * 0.25,
            math.pi * 1.5,
            false,
            paint,
          );
        } else if (type == 1) {
          // Simple gear
          canvas.drawCircle(Offset.zero, 6, paint);
          for (int i = 0; i < 6; i++) {
            canvas.rotate(math.pi / 3);
            canvas.drawLine(const Offset(6, 0), const Offset(10, 0), paint);
          }
        } else {
          // Simple car body silhouette
          final path = Path()
            ..moveTo(-12, 5)
            ..lineTo(12, 5)
            ..lineTo(10, 0)
            ..lineTo(4, -5)
            ..lineTo(-4, -5)
            ..lineTo(-8, 0)
            ..close();
          canvas.drawPath(path, paint);
          canvas.drawCircle(const Offset(-8, 5), 3, paint);
          canvas.drawCircle(const Offset(8, 5), 3, paint);
        }

        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
