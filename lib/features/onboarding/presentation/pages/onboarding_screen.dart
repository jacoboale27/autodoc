import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';
import 'package:autodoc/features/auth/data/services/auth_preferences_service.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SizedBox(
        width: double.infinity,
        height: double.infinity,
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
                      icon: Icon(Icons.arrow_back, color: _currentPage > 0 ? colors.textPrimary : Colors.transparent),
                    ),
                    Text(
                      'AutoDoc',
                      style: AppTextStyles.titleLarge.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ).animate().fadeIn(duration: 500.ms),
                    TextButton(
                      onPressed: () async {
                        await AuthPreferencesService().setOnboardingCompleted(true);
                        if (context.mounted) {
                          context.go('/login');
                        }
                      },
                      child: Text(
                        'Saltar',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: colors.primary,
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
                                        color: colors.primary.withValues(alpha: 0.2),
                                        shape: BoxShape.circle,
                                      ),
                                    ).withBlur(30),
                                  ).animate(target: _currentPage == index ? 1 : 0).scale(duration: 600.ms),
                                  Positioned(
                                    bottom: 20,
                                    left: 20,
                                    child: Container(
                                      width: 120,
                                      height: 120,
                                      decoration: BoxDecoration(
                                        color: colors.secondary.withValues(alpha: 0.2),
                                        shape: BoxShape.circle,
                                      ),
                                    ).withBlur(40),
                                  ).animate(target: _currentPage == index ? 1 : 0).scale(duration: 800.ms),
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
                                              color: colors.surfaceContainer.withValues(alpha: isDark ? 0.6 : 0.8),
                                              borderRadius: BorderRadius.circular(24),
                                              border: Border.all(
                                                color: colors.outline.withValues(alpha: 0.3),
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
                                                      placeholder: (context, url) => Container(color: colors.surfaceContainer),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 16),
                                                Row(
                                                  children: [
                                                    _buildFeatureItem(content.features[0], Icons.check_circle, colors),
                                                    const SizedBox(width: 8),
                                                    _buildFeatureItem(content.features[1], index == 2 ? Icons.battery_full : Icons.speed, colors),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ).animate(target: _currentPage == index ? 1 : 0).slideY(begin: 0.2, end: 0, duration: 500.ms).fadeIn();
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
                              style: AppTextStyles.headlineMedium.copyWith(
                                color: colors.textPrimary,
                              ),
                            ).animate(target: _currentPage == index ? 1 : 0).slideY(begin: 0.5, end: 0, duration: 600.ms).fadeIn(),
                            const SizedBox(height: 16),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: Text(
                                content.description,
                                textAlign: TextAlign.center,
                                style: AppTextStyles.bodyLarge.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                            ).animate(target: _currentPage == index ? 1 : 0).slideY(begin: 0.5, end: 0, duration: 700.ms).fadeIn(),
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
                        color: _currentPage == index ? colors.primary : colors.outline.withValues(alpha: 0.5),
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
                  onTap: () async {
                    if (_currentPage < _contents.length - 1) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      // Final Action: Navigate to Login
                      await AuthPreferencesService().setOnboardingCompleted(true);
                      if (context.mounted) {
                        context.go('/login');
                      }
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: double.infinity,
                    height: 60,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: colors.primary.withValues(alpha: 0.3),
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
                            style: AppTextStyles.titleMedium.copyWith(
                              color: colors.onPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.chevron_right, color: colors.onPrimary),
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

  Widget _buildFeatureItem(String text, IconData icon, AppColors colors) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colors.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.outline.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: colors.primary),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                text,
                style: AppTextStyles.labelSmall.copyWith(
                  color: colors.textPrimary,
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
