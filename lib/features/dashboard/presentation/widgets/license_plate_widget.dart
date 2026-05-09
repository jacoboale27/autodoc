import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ElSalvadorLicensePlate extends StatelessWidget {
  final String placa;
  final double width;
  final double height;

  const ElSalvadorLicensePlate({
    super.key,
    required this.placa,
    this.width = 160,
    this.height = 90,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[400]!, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          children: [
            // Flag Background
            Positioned.fill(
              child: CustomPaint(
                painter: WavyFlagPainter(),
              ),
            ),
            
            // Text Layer
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top text
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'EL SALVADOR',
                        style: GoogleFonts.inter(
                          fontSize: height * 0.08,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  
                  // Plate number
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            placa,
                            style: GoogleFonts.inter(
                              fontSize: height * 0.35,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1E293B),
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  // Bottom text
                  Text(
                    'CENTRO AMERICA',
                    style: GoogleFonts.inter(
                      fontSize: height * 0.07,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            
            // Seal (center icon)
            Center(
              child: Opacity(
                opacity: 0.2,
                child: Image.network(
                  'https://upload.wikimedia.org/wikipedia/commons/thumb/1/1b/Coat_of_arms_of_El_Salvador.svg/1024px-Coat_of_arms_of_El_Salvador.svg.png',
                  height: height * 0.25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WavyFlagPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    
    // Light Blue sections (Top and Bottom)
    final blueColor = const Color(0xFF0047AB).withValues(alpha: 0.2);
    
    final path = Path();
    
    // Top wave
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height * 0.3);
    path.quadraticBezierTo(size.width * 0.75, size.height * 0.2, size.width * 0.5, size.height * 0.3);
    path.quadraticBezierTo(size.width * 0.25, size.height * 0.4, 0, size.height * 0.3);
    path.close();
    
    paint.color = blueColor;
    canvas.drawPath(path, paint);
    
    // Bottom wave
    final path2 = Path();
    path2.moveTo(0, size.height);
    path2.lineTo(size.width, size.height);
    path2.lineTo(size.width, size.height * 0.7);
    path2.quadraticBezierTo(size.width * 0.75, size.height * 0.8, size.width * 0.5, size.height * 0.7);
    path2.quadraticBezierTo(size.width * 0.25, size.height * 0.6, 0, size.height * 0.7);
    path2.close();
    
    canvas.drawPath(path2, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
