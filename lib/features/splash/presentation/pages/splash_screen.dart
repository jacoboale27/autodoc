import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/features/auth/presentation/providers/auth_provider.dart';
import 'dart:math' as math;

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    // Navigate after checking auth state
    Future.delayed(const Duration(seconds: 3), () async {
      if (mounted) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        
        // Esperar un poco más si está cargando
        int attempts = 0;
        while (authProvider.user != null && authProvider.userData == null && attempts < 10) {
          await Future.delayed(const Duration(milliseconds: 500));
          attempts++;
        }

        if (mounted) {
          final user = authProvider.user;
          if (user != null) {
            final userData = authProvider.userData;
            if (userData != null) {
              final role = userData.rol.trim().toLowerCase();
              if (role == 'taller' || role == 'mecanico') {
                context.go('/mechanic_dashboard');
              } else if (role == 'admin' || role == 'administrador') {
                context.go('/admin/dashboard');
              } else {
                context.go('/dashboard');
              }
            } else {
              // Si no tiene datos de perfil aún, enviarlo a completar perfil
              context.go('/profile_setup');
            }
          } else {
            context.go('/onboarding');
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF2C5282);
    const secondaryColor = Color(0xFF48BB78);
    const accentBlue = Color(0xFF4299E1);

    return Scaffold(
      backgroundColor: primaryColor,
      body: Stack(
        children: [
          // Background Decorations (Premium Blobs)
          Positioned(
            top: -150,
            left: -150,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    accentBlue.withValues(alpha: 0.15),
                    accentBlue.withValues(alpha: 0.01),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -200,
            right: -200,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    secondaryColor.withValues(alpha: 0.15),
                    secondaryColor.withValues(alpha: 0.01),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top Icon
                  const Align(
                    alignment: Alignment.topRight,
                    child: Icon(
                      Icons.settings_suggest,
                      color: Colors.white24,
                      size: 40,
                    ),
                  ),

                  // Central Content
                  Column(
                    children: [
                      // Hexagonal Logo
                      SizedBox(
                        width: 128,
                        height: 128,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // White/10 Background rotated 45
                            Transform.rotate(
                              angle: math.pi / 4,
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                            // Secondary/40 Border rotated -12
                            Transform.rotate(
                              angle: -12 * math.pi / 180,
                              child: Container(
                                width: 110,
                                height: 110,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: secondaryColor.withValues(alpha: 0.4),
                                    width: 4,
                                  ),
                                ),
                              ),
                            ),
                            // Main Icon Box
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.verified,
                                color: primaryColor,
                                size: 50,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      // App Name
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'Auto',
                              style: GoogleFonts.montserratAlternates(
                                textStyle: const TextStyle(
                                  color: accentBlue,
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -1,
                                ),
                              ),
                            ),
                            TextSpan(
                              text: 'Doc',
                              style: GoogleFonts.montserratAlternates(
                                textStyle: const TextStyle(
                                  color: secondaryColor,
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'DIAGNÓSTICO PROFESIONAL',
                        style: GoogleFonts.inter(
                          textStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 4,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Footer Section
                  Column(
                    children: [
                      // Loading Indicator
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          RotationTransition(
                            turns: _controller,
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: secondaryColor.withValues(alpha: 0.2),
                                  width: 4,
                                ),
                              ),
                              child: const CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(secondaryColor),
                                strokeWidth: 4,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.directions_car,
                            color: secondaryColor,
                            size: 14,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Cargando datos de tu vehículo...',
                        style: GoogleFonts.inter(
                          textStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Progress Bar
                      Container(
                        width: 192,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: 64, // 1/3 of 192
                            decoration: BoxDecoration(
                              color: secondaryColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 48),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
