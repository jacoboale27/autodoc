import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';
import 'package:autodoc/features/auth/data/services/auth_preferences_service.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_motion.dart';
import 'package:autodoc/core/theme/app_radius.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:flutter_animate/flutter_animate.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const List<OnboardingContent> _contents = <OnboardingContent>[
    OnboardingContent(
      title: 'Diagnóstico en tiempo real',
      description:
          'Mantén tu auto en perfecto estado con monitoreo constante de '
          'todos los sistemas críticos.',
      icon: Icons.monitor_heart_outlined,
      features: ['Motor OK', 'Frenos Seguros'],
    ),
    OnboardingContent(
      title: 'Recordatorios Inteligentes',
      description:
          'Nunca más olvides un cambio de aceite o mantenimiento '
          'preventivo. Nosotros te avisamos.',
      icon: Icons.notifications_active_outlined,
      features: ['Aceite 80%', 'Llantas OK'],
    ),
    OnboardingContent(
      title: 'Tu auto te lo agradecerá',
      description:
          'Descubre una nueva forma de cuidar tu vehículo con recordatorios '
          'inteligentes y diagnósticos en tiempo real.',
      icon: Icons.directions_car_filled_outlined,
      features: ['Motor OK', '100% Vida'],
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _previous() => _pageController.previousPage(
    duration: AppMotion.transformDuration(context, AppMotion.dropdown),
    curve: AppMotion.easeInOut,
  );

  Future<void> _skip() async {
    await AuthPreferencesService().setOnboardingCompleted(true);
    if (mounted) context.go('/login');
  }

  Future<void> _next() async {
    if (_currentPage < _contents.length - 1) {
      await _pageController.nextPage(
        duration: AppMotion.transformDuration(context, AppMotion.dropdown),
        curve: AppMotion.easeInOut,
      );
      return;
    }
    await _skip();
  }

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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_currentPage > 0)
                      IconButton(
                        key: const ValueKey('onboarding-back'),
                        tooltip: 'Anterior',
                        onPressed: _previous,
                        icon: const Icon(Icons.arrow_back),
                      )
                    else
                      const SizedBox(width: 48),
                    Flexible(
                      child: Text(
                        'AutoDoc',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.titleLarge.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ).animate().fadeIn(duration: 500.ms),
                    ),
                    TextButton(
                      onPressed: _skip,
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
                    // El alto de la ilustracion es una fraccion del viewport,
                    // pero acotada por arriba y por abajo de forma que `min`
                    // nunca supere a `max`. La version anterior calculaba
                    // `maxHeight: height * 0.4` con `minHeight: 200` fijo, que
                    // se desnormaliza con cualquier alto < 500 px — es decir,
                    // en todo telefono girado.
                    //
                    // `MediaQuery.sizeOf` (no `MediaQuery.of(context).size`)
                    // porque esto no elige estructura de layout (lo que
                    // prohibe la regla de usar `WindowClass`): dimensiona una
                    // ilustracion proporcionalmente al alto disponible, y
                    // `WindowClass` solo conoce anchos.
                    final viewportHeight = MediaQuery.sizeOf(context).height;
                    final illustrationHeight = (viewportHeight * 0.4).clamp(
                      120.0,
                      360.0,
                    );
                    return SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 20),
                            // Illustration Section with Glassmorphism
                            SizedBox(
                              height: illustrationHeight,
                              child: Center(
                                // El panel ocupa el ancho disponible con
                                // un tope de lectura. Antes era
                                // `width: 280` literal: 19 % del ancho a
                                // 1440 px y recortado a 320 px.
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: AppBreakpoints.maxReadingWidth,
                                  ),
                                  child:
                                      ClipRRect(
                                            key: const ValueKey(
                                              'onboarding-panel',
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              AppRadius.xxl,
                                            ),
                                            child: BackdropFilter(
                                              filter: ImageFilter.blur(
                                                sigmaX: 12,
                                                sigmaY: 12,
                                              ),
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: colors.surfaceContainer
                                                      .withValues(
                                                        alpha: isDark
                                                            ? 0.6
                                                            : 0.8,
                                                      ),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        AppRadius.xxl,
                                                      ),
                                                  border: Border.all(
                                                    color: colors.outline
                                                        .withValues(alpha: 0.3),
                                                    width: 1.5,
                                                  ),
                                                ),
                                                padding: const EdgeInsets.all(
                                                  AppSpacing.xl,
                                                ),
                                                child: Column(
                                                  children: [
                                                    Expanded(
                                                      child: _illustration(
                                                        content,
                                                        colors,
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                      height: AppSpacing.base,
                                                    ),
                                                    Row(
                                                      children: [
                                                        _buildFeatureItem(
                                                          content.features[0],
                                                          Icons.check_circle,
                                                          colors,
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        _buildFeatureItem(
                                                          content.features[1],
                                                          index == 2
                                                              ? Icons
                                                                    .battery_full
                                                              : Icons.speed,
                                                          colors,
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          )
                                          .animate(
                                            target: _currentPage == index
                                                ? 1
                                                : 0,
                                          )
                                          .slideY(
                                            begin: 0.2,
                                            end: 0,
                                            duration: 500.ms,
                                          )
                                          .fadeIn(),
                                ),
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
                                )
                                .animate(target: _currentPage == index ? 1 : 0)
                                .slideY(begin: 0.5, end: 0, duration: 600.ms)
                                .fadeIn(),
                            const SizedBox(height: 16),
                            Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  child: Text(
                                    content.description,
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.bodyLarge.copyWith(
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                )
                                .animate(target: _currentPage == index ? 1 : 0)
                                .slideY(begin: 0.5, end: 0, duration: 700.ms)
                                .fadeIn(),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Pagination Dots
              Semantics(
                key: const ValueKey('onboarding-dots'),
                label: 'Paso ${_currentPage + 1} de ${_contents.length}',
                child: ExcludeSemantics(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xl,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _contents.length,
                        (index) => AnimatedContainer(
                          duration: AppMotion.transformDuration(
                            context,
                            AppMotion.dropdown,
                          ),
                          curve: AppMotion.easeOut,
                          margin: const EdgeInsets.only(right: AppSpacing.md),
                          height: 8,
                          width: _currentPage == index ? 32 : 8,
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? colors.primary
                                : colors.outline.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(AppRadius.xs),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom Button
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  0,
                  AppSpacing.xl,
                  AppSpacing.xxl,
                ),
                child: AppButton(
                  key: const ValueKey('onboarding-next'),
                  text: _currentPage == _contents.length - 1
                      ? 'Comenzar ahora'
                      : 'Siguiente',
                  size: AppButtonSize.large,
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _next,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _illustration(OnboardingContent content, AppColors colors) {
    final fallback = Container(
      key: const ValueKey('onboarding-illustration-fallback'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primary.withValues(alpha: 0.18),
            colors.secondary.withValues(alpha: 0.18),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Center(
        child: Icon(
          content.icon,
          size: 64,
          color: colors.primary,
          semanticLabel: content.title,
        ),
      ),
    );

    if (content.assetPath == null) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Image.asset(
        content.assetPath!,
        fit: BoxFit.cover,
        semanticLabel: content.title,
        errorBuilder: (_, _, _) => fallback,
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

  /// Ilustracion local. `null` mientras no existan los assets: en ese caso
  /// se dibuja el degradado con el icono, que es del design system y
  /// funciona sin red.
  final String? assetPath;

  /// Icono de respaldo, que **siempre** existe.
  final IconData icon;

  final List<String> features;

  const OnboardingContent({
    required this.title,
    required this.description,
    required this.icon,
    required this.features,
    this.assetPath,
  });
}
