import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/features/auth/presentation/providers/auth_provider.dart';
import 'package:autodoc/features/auth/data/services/auth_preferences_service.dart';
import 'package:autodoc/core/utils/responsive.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
            final authPrefs = AuthPreferencesService();
            final rememberMe = await authPrefs.getRememberMe();
            final onboardingCompleted = await authPrefs.isOnboardingCompleted();
            if (mounted) {
              if (rememberMe || onboardingCompleted) {
                context.go('/login');
              } else {
                if (Responsive.isDesktop(context)) {
                  context.go('/landing');
                } else {
                  context.go('/onboarding');
                }
              }
            }
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
    final colors = context.appColors;
    final primaryColor = colors.primary;
    final secondaryColor = colors.secondary;
    final accentColor = colors.success;

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
                    accentColor.withValues(alpha: 0.15),
                    accentColor.withValues(alpha: 0.01),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ).animate().fadeIn(duration: 1.seconds),
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
          ).animate().fadeIn(duration: 1.seconds),

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
                              child: Icon(
                                Icons.verified,
                                color: primaryColor,
                                size: 50,
                              ),
                            ),
                          ],
                        ),
                      ).animate().scale(delay: 200.ms, duration: 600.ms, curve: Curves.easeOutBack),
                      const SizedBox(height: 32),
                      // App Name
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'Auto',
                              style: GoogleFonts.montserratAlternates(
                                textStyle: TextStyle(
                                  color: accentColor,
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -1,
                                ),
                              ),
                            ),
                            TextSpan(
                              text: 'Doc',
                              style: GoogleFonts.montserratAlternates(
                                textStyle: TextStyle(
                                  color: secondaryColor,
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 400.ms, duration: 600.ms).slideY(begin: 0.2, end: 0),
                      const SizedBox(height: 8),
                      Text(
                        'DIAGNÓSTICO PROFESIONAL',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: Colors.white.withValues(alpha: 0.6),
                          letterSpacing: 4,
                        ),
                      ).animate().fadeIn(delay: 600.ms),
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
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(secondaryColor),
                                strokeWidth: 4,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.directions_car,
                            color: secondaryColor,
                            size: 14,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Cargando datos...',
                        style: AppTextStyles.titleMedium.copyWith(
                          color: Colors.white,
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
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: const Duration(seconds: 3),
                            builder: (context, value, child) {
                              return Container(
                                width: 192 * value,
                                decoration: BoxDecoration(
                                  color: secondaryColor,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 48),
                    ],
                  ).animate().fadeIn(delay: 800.ms),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
