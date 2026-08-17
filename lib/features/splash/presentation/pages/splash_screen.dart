import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/core/providers/auth_session_provider.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/features/auth/data/services/auth_preferences_service.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_motion.dart';
import 'package:autodoc/core/theme/app_shadows.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:math' as math;

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  AuthSessionProvider? _session;
  // `AuthSessionProvider._user` arranca en null y solo se llena de forma
  // ASINCRONA via su listener de `idTokenChanges()` (ver
  // auth_session_provider.dart). El provider se construye justo antes de
  // `runApp`, asi que su primera emision puede llegar bien despues del
  // primer frame del splash. Sin este flag, `_resolveDestination` leeria
  // `session.user` en null incluso para un usuario con sesion real y lo
  // mandaria a /login u /onboarding. Se registra el listener aqui (antes
  // del primer frame) para no perder esa primera emision.
  bool _sessionEmitted = false;

  static const Duration _minimumSplash = Duration(milliseconds: 400);
  static const Duration _pollInterval = Duration(milliseconds: 100);
  static const int _maxPolls = 20;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _session = context.read<AuthSessionProvider>();
    _session!.addListener(_onSessionChanged);
    // El giro solo arranca si el usuario no ha pedido menos movimiento;
    // se decide en el primer frame, cuando ya hay MediaQuery.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!AppMotion.reduced(context)) _controller.repeat();
      _resolveDestination();
    });
  }

  void _onSessionChanged() {
    _sessionEmitted = true;
  }

  Future<void> _resolveDestination() async {
    final started = DateTime.now();
    final session = context.read<AuthSessionProvider>();
    final profile = context.read<UserProfileProvider>();

    // Espera acotada (mismo presupuesto de 2 s / 100 ms que el sondeo del
    // perfil de abajo) a que la sesion emita su primer valor real antes de
    // decidir "no hay sesion". Sin esto, un usuario logueado en frio caeria
    // en la rama de no-sesion porque `session.user` sigue siendo null en el
    // primer frame.
    var sessionPolls = 0;
    while (!_sessionEmitted && sessionPolls < _maxPolls) {
      await Future<void>.delayed(_pollInterval);
      sessionPolls++;
    }
    if (!mounted) return;

    String destination;
    final user = session.user;

    if (user == null) {
      // Usuario NO autenticado: nunca ir a profile_setup
      final authPrefs = AuthPreferencesService();
      final rememberMe = await authPrefs.getRememberMe();
      final onboardingCompleted = await authPrefs.isOnboardingCompleted();
      destination = (rememberMe || onboardingCompleted)
          ? '/login'
          : '/onboarding';
    } else {
      // Usuario autenticado: esperar a que se cargue el perfil. Espera
      // acotada a que el perfil termine de intentarse: 2 s en vez de 5,
      // sondeando cada 100 ms en vez de cada 500.
      var polls = 0;
      while ((!profile.hasAttemptedFetch || profile.isLoading) &&
          polls < _maxPolls) {
        await Future<void>.delayed(_pollInterval);
        polls++;
      }
      if (!mounted) return;

      final userData = profile.userData;
      if (userData == null) {
        // Si no tiene datos de perfil aún, enviarlo a completar perfil
        destination = '/profile_setup';
      } else {
        // Si `resolveRedirect` retuvo al usuario en el splash mientras
        // el perfil cargaba (F5 o deep link a una ruta con id, o
        // notificacion push en frio), preservo el destino original en
        // vez de mandarlo siempre a la home del rol. `resolveRedirect`
        // corrige la ruta en la siguiente evaluacion del guard si no
        // es valida para este rol, asi que no hace falta validarla aqui.
        final redirectParam = GoRouterState.of(
          context,
        ).uri.queryParameters['redirect'];
        if (redirectParam != null && redirectParam.isNotEmpty) {
          destination = Uri.decodeComponent(redirectParam);
        } else {
          final role = userData.rol.trim().toLowerCase();
          destination = switch (role) {
            'taller' || 'mecanico' => '/mechanic_dashboard',
            'admin' || 'administrador' || 'superusuario' => '/admin/dashboard',
            _ => '/dashboard',
          };
        }
      }
    }

    // Retardo minimo anti-parpadeo: si todo estaba en cache, la resolucion
    // tarda ~0 ms y el splash aparecerian y desaparecerian en un frame,
    // que se lee como un fallo. 400 ms es el suelo, no el techo.
    final elapsed = DateTime.now().difference(started);
    if (elapsed < _minimumSplash) {
      await Future<void>.delayed(_minimumSplash - elapsed);
    }
    if (!mounted) return;
    context.go(destination);
  }

  @override
  void dispose() {
    _session?.removeListener(_onSessionChanged);
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
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      MediaQuery.sizeOf(context).height -
                      MediaQuery.paddingOf(context).vertical,
                ),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Top Icon
                        Align(
                          alignment: Alignment.topRight,
                          child: Icon(
                            Icons.settings_suggest,
                            color: colors.onPrimary.withValues(alpha: 0.24),
                            size: 40,
                          ),
                        ),

                        // Central Content
                        const SplashBranding(),

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
                                        color: secondaryColor.withValues(
                                          alpha: 0.2,
                                        ),
                                        width: 4,
                                      ),
                                    ),
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        secondaryColor,
                                      ),
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
                            const SizedBox(height: AppSpacing.xl),
                            Text(
                              'Cargando datos...',
                              style: AppTextStyles.titleMedium.copyWith(
                                color: colors.onPrimary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            // Progress indicator honesto: no hay una barra
                            // que mida progreso real, asi que se muestra
                            // indeterminada en vez de fingir un avance.
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 192),
                              child: LinearProgressIndicator(
                                minHeight: 4,
                                backgroundColor: colors.onPrimary.withValues(
                                  alpha: 0.1,
                                ),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  secondaryColor,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xxxl),
                          ],
                        ).animate().fadeIn(delay: 800.ms),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bloque de marca del splash: logo, nombre y eslogan. Aislado del resto de
/// la pantalla (router, providers, `Future.delayed`) para poder probarlo
/// solo. Publico (sin guion bajo) porque el test de temporizacion vive en
/// otro fichero y los miembros privados de Dart solo son visibles dentro
/// del mismo fichero fuente.
class SplashBranding extends StatelessWidget {
  const SplashBranding({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _SplashLogo(),
        const SizedBox(height: AppSpacing.xxl),
        Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Auto',
                  key: const ValueKey('splash-auto'),
                  // `success` daba 1,65:1 sobre `primary` en oscuro.
                  // `onPrimary` esta definido precisamente para ir encima de
                  // `primary`: 10,32:1 en claro y 12,12:1 en oscuro.
                  style: AppTextStyles.displaySmall.copyWith(
                    color: colors.onPrimary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -1,
                  ),
                ),
                Text(
                  'Doc',
                  key: const ValueKey('splash-doc'),
                  style: AppTextStyles.displaySmall.copyWith(
                    color: colors.secondary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -1,
                  ),
                ),
              ],
            )
            .animate()
            .fadeIn(delay: 400.ms, duration: 600.ms)
            .slideY(begin: 0.2, end: 0),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'DIAGNÓSTICO PROFESIONAL',
          style: AppTextStyles.labelMedium.copyWith(
            color: colors.onPrimary,
            letterSpacing: 4,
          ),
        ).animate().fadeIn(delay: 600.ms),
      ],
    );
  }
}

/// Isotipo hexagonal del splash. Tamaños fijos (128/110/100/80): es un
/// isotipo, no contenido, y no desborda a 320 px.
class _SplashLogo extends StatelessWidget {
  const _SplashLogo();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final secondaryColor = colors.secondary;
    // `colors.textPrimary` es blanco en modo oscuro (`darkTextPrimary`), asi
    // que usarlo aqui invertiria la sombra en un resplandor blanco. Se usa
    // `AppShadows.lightLg`/`darkLg` (mismo blurRadius/offset que antes),
    // que en ambos temas es un oscurecimiento real, igual que en
    // app_button.dart.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
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
                color: colors.onPrimary.withValues(alpha: 0.1),
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
              color: colors.onPrimary,
              borderRadius: BorderRadius.circular(16),
              boxShadow: isDark ? AppShadows.darkLg : AppShadows.lightLg,
            ),
            padding: const EdgeInsets.all(14),
            child: SvgPicture.asset('assets/logo/autodoc_isotype.svg'),
          ),
        ],
      ),
    ).animate().scale(
      delay: 200.ms,
      duration: 600.ms,
      curve: Curves.easeOutBack,
    );
  }
}
