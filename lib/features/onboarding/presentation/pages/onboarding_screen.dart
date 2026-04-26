import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingContent> _contents = [
    OnboardingContent(
      title: 'Diagnóstico en tiempo real',
      description: 'Mantén tu auto en perfecto estado con monitoreo constante de todos los sistemas críticos.',
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuAGuLOtm-XW2HPNRArFEVcOAhv4hjIEx54m69ca89JZltsaqO4rUiGxbdPpKpBfxUAJa9aaFgZgvBfpkuHNw3e-iB4vf5LdvMmYdGCpG0Ofiv6z19ojLhGPnUe_9SWK48pl1BzBU1o8xvEILNvboHlEBMSw6NX3RaCY_yF8ZD2518ipqAt_1SQgzQ8BcaGIXp2h2d-agNaSJs-1c2VDrS78ys74l0KTKt-F03N6pKA9uLD6jQniKaI_eh4WtUrbNdZPSHFAjloNDtM',
      features: ['Motor OK', 'Frenos Seguros'],
    ),
    OnboardingContent(
      title: 'Recordatorios Inteligentes',
      description: 'Nunca más olvides un cambio de aceite o mantenimiento preventivo. Nosotros te avisamos.',
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuAGuLOtm-XW2HPNRArFEVcOAhv4hjIEx54m69ca89JZltsaqO4rUiGxbdPpKpBfxUAJa9aaFgZgvBfpkuHNw3e-iB4vf5LdvMmYdGCpG0Ofiv6z19ojLhGPnUe_9SWK48pl1BzBU1o8xvEILNvboHlEBMSw6NX3RaCY_yF8ZD2518ipqAt_1SQgzQ8BcaGIXp2h2d-agNaSJs-1c2VDrS78ys74l0KTKt-F03N6pKA9uLD6jQniKaI_eh4WtUrbNdZPSHFAjloNDtM', // Reusing placeholder as requested
      features: ['Aceite 80%', 'Llantas OK'],
    ),
    OnboardingContent(
      title: 'Tu auto te lo agradecerá',
      description: 'Descubre una nueva forma de cuidar tu vehículo con recordatorios inteligentes y diagnósticos en tiempo real.',
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuAGuLOtm-XW2HPNRArFEVcOAhv4hjIEx54m69ca89JZltsaqO4rUiGxbdPpKpBfxUAJa9aaFgZgvBfpkuHNw3e-iB4vf5LdvMmYdGCpG0Ofiv6z19ojLhGPnUe_9SWK48pl1BzBU1o8xvEILNvboHlEBMSw6NX3RaCY_yF8ZD2518ipqAt_1SQgzQ8BcaGIXp2h2d-agNaSJs-1c2VDrS78ys74l0KTKt-F03N6pKA9uLD6jQniKaI_eh4WtUrbNdZPSHFAjloNDtM',
      features: ['Motor OK', '100% Vida'],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    const primaryPurple = Color(0xFF522C81);
    const customMint = Color(0xFF81E6D9);
    const customBlue = Color(0xFF2C5282);
    const bgColorStart = Colors.white;
    const bgColorEnd = Color(0xFFF0F4F8);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [bgColorStart, bgColorEnd],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () {
                        if (_currentPage > 0) {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                      icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
                    ),
                    Text(
                      'AutoDoc',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        context.go('/login');
                      },
                      child: Text(
                        'Saltar',
                        style: GoogleFonts.inter(
                          color: primaryPurple,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Page Content
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemCount: _contents.length,
                  itemBuilder: (context, index) {
                    final content = _contents[index];
                    return SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 20),
                            // Illustration Section with Glassmorphism
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: MediaQuery.of(context).size.height * 0.4,
                                minHeight: 200,
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Decorative Blobs
                                  Positioned(
                                    top: 20,
                                    right: 20,
                                    child: Container(
                                      width: 100,
                                      height: 100,
                                      decoration: BoxDecoration(
                                        color: primaryPurple.withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                    ).withBlur(30),
                                  ),
                                  Positioned(
                                    bottom: 20,
                                    left: 20,
                                    child: Container(
                                      width: 120,
                                      height: 120,
                                      decoration: BoxDecoration(
                                        color: customMint.withValues(alpha: 0.2),
                                        shape: BoxShape.circle,
                                      ),
                                    ).withBlur(40),
                                  ),
                                  // Glass Panel
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      return ClipRRect(
                                        borderRadius: BorderRadius.circular(24),
                                        child: BackdropFilter(
                                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                          child: Container(
                                            width: 280,
                                            height: constraints.maxHeight,
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(alpha: 0.4),
                                              borderRadius: BorderRadius.circular(24),
                                              border: Border.all(
                                                color: Colors.white.withValues(alpha: 0.3),
                                                width: 1.5,
                                              ),
                                            ),
                                            padding: const EdgeInsets.all(24),
                                            child: Column(
                                              children: [
                                                Expanded(
                                                  child: ClipRRect(
                                                    borderRadius: BorderRadius.circular(16),
                                                    child: CachedNetworkImage(
                                                      imageUrl: content.imageUrl,
                                                      fit: BoxFit.cover,
                                                      placeholder: (context, url) => Container(color: Colors.white24),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 16),
                                                Row(
                                                  children: [
                                                    _buildFeatureItem(content.features[0], Icons.check_circle, primaryPurple),
                                                    const SizedBox(width: 8),
                                                    _buildFeatureItem(content.features[1], index == 2 ? Icons.battery_full : Icons.speed, primaryPurple),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                  ),
                                ],
                              ),
                            ),
                    
                            const SizedBox(height: 32),
                            // Text Content
                            Text(
                              content.title,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                height: 1.1,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: Text(
                                content.description,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  color: const Color(0xFF475569),
                                  height: 1.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Pagination Dots
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _contents.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.only(right: 12),
                      height: 8,
                      width: _currentPage == index ? 32 : 8,
                      decoration: BoxDecoration(
                        color: _currentPage == index ? primaryPurple : const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom Button
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                child: GestureDetector(
                  onTap: () {
                    if (_currentPage < _contents.length - 1) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      // Final Action: Navigate to Login
                      context.go('/login');
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: double.infinity,
                    height: 60,
                    decoration: BoxDecoration(
                      color: customMint,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: customMint.withValues(alpha: 0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _currentPage == _contents.length - 1 ? 'Comenzar ahora' : 'Siguiente',
                            style: GoogleFonts.inter(
                              color: customBlue,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.chevron_right, color: customBlue),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String text, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF334155),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingContent {
  final String title;
  final String description;
  final String imageUrl;
  final List<String> features;

  OnboardingContent({
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.features,
  });
}

extension on Widget {
  Widget withBlur(double sigma) => ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: this,
      );
}
