import 'package:flutter/material.dart';
import '../widgets/auth_bottom_nav.dart';
import '../widgets/auth_background_blobs.dart';

import '../widgets/auth_logo_section.dart';

import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'package:autodoc/features/auth/data/services/auth_preferences_service.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_radius.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/core/theme/app_motion.dart';
import 'package:autodoc/core/theme/app_shadows.dart';
import 'package:autodoc/core/utils/responsive.dart';
import 'package:autodoc/core/utils/l10n_extension.dart';
import 'package:autodoc/core/utils/ui_utils.dart';
import 'package:autodoc/core/widgets/app_text_field.dart';
import 'package:autodoc/core/widgets/app_button.dart';

class AuthScreen extends StatefulWidget {
  final bool isLogin;
  const AuthScreen({super.key, required this.isLogin});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late bool _isLoginMode;
  bool _rememberMe = false;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authPreferences = AuthPreferencesService();
  // Dos GlobalKey, uno por modo, en vez de una sola compartida: AnimatedSwitcher
  // (ver `_card`) mantiene montado el widget saliente durante todo el cross-fade
  // mientras el entrante ya se infla, asi que ambos Form coexisten brevemente en
  // el arbol. Con una unica GlobalKey eso revienta con
  // "Duplicate GlobalKey detected in widget tree" en cuanto el usuario toca el
  // enlace de alternar login/registro. Cada _buildGlassCard se construye con el
  // valor de _isLoginMode vigente en ESE build, asi que el arbol saliente (con
  // el _isLoginMode anterior ya congelado) referencia su propia key y el
  // entrante la suya: nunca coinciden.
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();
  GlobalKey<FormState> get _formKey =>
      _isLoginMode ? _loginFormKey : _registerFormKey;

  @override
  void initState() {
    super.initState();
    _isLoginMode = widget.isLogin;
    _loadRememberMePreferences();
  }

  Future<void> _loadRememberMePreferences() async {
    final remember = await _authPreferences.getRememberMe();
    final savedEmail = await _authPreferences.getSavedEmail();
    if (!mounted) return;
    setState(() {
      _rememberMe = remember;
      if (savedEmail != null && savedEmail.isNotEmpty) {
        _emailController.text = savedEmail;
      }
    });
  }

  bool _isValidEmail(String value) {
    final email = value.trim();
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);
  }

  Future<void> _persistRememberMe() async {
    final remember = _rememberMe;
    final email = _emailController.text;
    await _authPreferences.setRememberMe(remember);
    if (remember && email.contains('@')) {
      await _authPreferences.saveEmail(email);
    } else if (!remember) {
      await _authPreferences.clearSavedCredentials();
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _isLoginMode = !_isLoginMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final windowClass = AppBreakpoints.of(context);
    final isWide = windowClass.isAtLeastExpanded;

    return Scaffold(
      backgroundColor: colors.surface,
      body: Stack(
        children: [
          Positioned.fill(
            child: AuthBackgroundBlobs(colors: colors, isDark: isDark),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: AppBreakpoints.gutter(windowClass),
                  vertical: AppSpacing.xl,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppBreakpoints.maxContentWidth,
                  ),
                  // AuthBottomNav vive aquí, como último hijo del mismo flujo
                  // que la tarjeta — no en un Stack ni fuera de un Expanded
                  // acotado. Así nunca puede quedar por delante ni por
                  // detrás de la tarjeta "por construcción": el orden
                  // secuencial del Column lo impide con independencia de
                  // cuánto crezca el formulario o si hace falta scroll.
                  //
                  // Se intentó (fix-round del task 5) la estructura del brief
                  // original — SafeArea > Column [ Expanded(Center(
                  // SingleChildScrollView(...))), AuthBottomNav ] — con
                  // AuthBottomNav como hermano fijo FUERA del Expanded. Se
                  // verificó empíricamente contra
                  // `auth_screen_layout_test.dart` a 375×812 (altura por
                  // defecto de `pumpEntry`) y falla de forma reproducible:
                  // el `Expanded` fija la altura del área scrollable en
                  // (818 lógicos de SafeArea − ~92 de AuthBottomNav) ≈ 720 px,
                  // pero la tarjeta del Task 4 (con logo, ambos campos,
                  // "remember me"/"forgot password", submit, divider y botón
                  // de Google) mide ~747 px de alto ella sola, más el logo de
                  // 210 px encima — muy por encima de esos ~720 px. Con
                  // `Center` dentro del `Expanded`, el contenido no cabe y el
                  // scroll arranca centrado/desde arriba: el borde inferior
                  // de la tarjeta queda en dy≈1013, muy por debajo del techo
                  // fijo de AuthBottomNav en dy≈731 — la tarjeta queda
                  // literalmente detrás/debajo de la barra en el primer
                  // frame, sin que el usuario haya hecho scroll todavía.
                  // Output real de test capturado:
                  //   Expected: a value less than or equal to <731.0>
                  //     Actual: <1013.0>
                  //   la tarjeta se mete debajo de la barra inferior
                  // Por eso se mantiene la colocación por flujo: no es un
                  // descuido, es la que pasa el test con el contenido real
                  // del Task 4 en el viewport auditado más pequeño.
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      isWide
                          ? _buildWideLayout(colors, isDark)
                          : _buildNarrowLayout(colors, isDark),
                      const SizedBox(height: AppSpacing.xxl),
                      AuthBottomNav(
                        key: const ValueKey('auth-bottom-nav'),
                        colors: colors,
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNarrowLayout(AppColors colors, bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AuthLogoSection(colors: colors),
        const SizedBox(height: AppSpacing.xxl),
        _card(colors, isDark),
        const SizedBox(height: AppSpacing.xxl),
        _modeSwitchLink(colors),
      ],
    );
  }

  Widget _buildWideLayout(AppColors colors, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Padding(
            key: const ValueKey('auth-brand-panel'),
            padding: const EdgeInsets.only(right: AppSpacing.xxl),
            child: AuthLogoSection(colors: colors),
          ),
        ),
        SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _card(colors, isDark),
              const SizedBox(height: AppSpacing.xxl),
              _modeSwitchLink(colors),
            ],
          ),
        ),
      ],
    );
  }

  Widget _card(AppColors colors, bool isDark) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: AnimatedSwitcher(
        duration: AppMotion.transformDuration(context, AppMotion.dropdown),
        switchInCurve: AppMotion.easeOut,
        switchOutCurve: AppMotion.easeOut,
        child: _buildGlassCard(colors, isDark, key: ValueKey(_isLoginMode)),
      ),
    );
  }

  Widget _modeSwitchLink(AppColors colors) {
    return AppButton(
      key: const ValueKey('auth-mode-switch'),
      text: '',
      type: AppButtonType.text,
      size: AppButtonSize.small,
      semanticLabel: _isLoginMode
          ? context.l10n.authRegisterFree
          : context.l10n.authLogin,
      onPressed: _toggleMode,
      child: RichText(
        text: TextSpan(
          style: AppTextStyles.bodyMedium.copyWith(color: colors.textSecondary),
          children: [
            TextSpan(
              text: _isLoginMode
                  ? context.l10n.authNoAccount
                  : context.l10n.authHaveAccount,
            ),
            TextSpan(
              text: _isLoginMode
                  ? context.l10n.authRegisterFree
                  : context.l10n.authLogin,
              style: AppTextStyles.bodyMedium.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassCard(AppColors colors, bool isDark, {Key? key}) {
    return ClipRRect(
      key: key,
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 10,
          sigmaY: 10,
        ), // Reduced blur for performance
        child: Container(
          key: const ValueKey('auth-card'),
          width: double.infinity,
          padding: EdgeInsets.all(Responsive.padding(context, 32)),
          decoration: BoxDecoration(
            color: colors.surfaceContainer.withValues(
              alpha: isDark ? 0.7 : 0.8,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colors.outline.withValues(alpha: 0.5)),
            boxShadow: isDark ? AppShadows.darkLg : AppShadows.lightLg,
          ),
          child: AutofillGroup(
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    _isLoginMode
                        ? context.l10n.authWelcomeBack
                        : context.l10n.authCreateAccount,
                    style: AppTextStyles.headlineSmall.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isLoginMode
                        ? context.l10n.authEnterCredentials
                        : context.l10n.authRegisterToManage,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Form Fields
                  AppTextField(
                    key: const ValueKey('auth-email-field'),
                    label: _isLoginMode
                        ? context.l10n.authEmailOrUserLabel
                        : context.l10n.authEmailLabel,
                    hintText: _isLoginMode
                        ? context.l10n.authEmailOrUserHint
                        : context.l10n.authEmailHint,
                    controller: _emailController,
                    prefixIcon: Icon(
                      Icons.mail_outline,
                      color: colors.textSecondary,
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.username],
                    validator: (value) {
                      final email = (value ?? '').trim();
                      if (email.isEmpty) {
                        return context.l10n.authCompleteCredentials;
                      }
                      // En login se admite tambien usuario admin sin arroba:
                      // esa es la regla de negocio existente, no se cambia.
                      if (!_isLoginMode && !_isValidEmail(email)) {
                        return context.l10n.authEnterValidEmail;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    key: const ValueKey('auth-password-field'),
                    label: context.l10n.authPasswordLabel,
                    hintText: context.l10n.authPasswordHint,
                    controller: _passwordController,
                    prefixIcon: Icon(
                      Icons.lock_outline,
                      color: colors.textSecondary,
                    ),
                    obscureText: true,
                    obscureToggle: true,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => _submit(),
                    validator: (value) {
                      final pass = value ?? '';
                      if (pass.isEmpty) {
                        return context.l10n.authCompleteCredentials;
                      }
                      if (!_isLoginMode && pass.length < 6) {
                        return context.l10n.authPasswordTooShort;
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 12),
                  // Extras
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Semantics(
                        label: context.l10n.authRememberMe,
                        checked: _rememberMe,
                        child: InkWell(
                          key: const ValueKey('auth-remember-me'),
                          onTap: () =>
                              setState(() => _rememberMe = !_rememberMe),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 4,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Checkbox(
                                    value: _rememberMe,
                                    onChanged: (value) => setState(
                                      () => _rememberMe = value ?? false,
                                    ),
                                    activeColor: colors.primary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                // Flexible: a 200% de escala de fuente el
                                // texto puede exceder el ancho que le deja
                                // el Wrap (mismo criterio que el separador
                                // "OR CONTINUE WITH" del punto 4f).
                                Flexible(
                                  child: Text(
                                    context.l10n.authRememberMe,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.labelMedium.copyWith(
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (_isLoginMode)
                        AppButton(
                          key: const ValueKey('auth-forgot-password'),
                          text: context.l10n.authForgotPassword,
                          type: AppButtonType.text,
                          size: AppButtonSize.small,
                          onPressed: _showForgotPasswordDialog,
                        ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  // Submit Button
                  AppButton(
                    key: const ValueKey('auth-submit'),
                    text: _isLoginMode
                        ? context.l10n.authLoginButton
                        : context.l10n.authRegisterButton,
                    size: AppButtonSize.large,
                    isLoading: context.watch<AuthProvider>().isLoading,
                    onPressed: _submit,
                    semanticLabel: _isLoginMode
                        ? context.l10n.authLoginButton
                        : context.l10n.authRegisterButton,
                  ),

                  const SizedBox(height: 24),
                  // Divider
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: colors.outline.withValues(alpha: 0.5),
                        ),
                      ),
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            context.l10n.authOrContinueWith,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: colors.outline.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  // Google Button
                  _buildGoogleButton(colors),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.isLoading) return;
    if (!(_formKey.currentState?.validate() ?? false)) {
      HapticFeedback.heavyImpact();
      return;
    }
    if (_isLoginMode) {
      await _handleEmailSignIn(authProvider);
    } else {
      await _handleEmailRegister(authProvider);
    }
  }

  Future<void> _navigateAfterAuth(AuthProvider authProvider) async {
    if (authProvider.needsEmailVerification) {
      final canContinue = await _showEmailVerificationDialog(
        isRegistration: false,
        email: _emailController.text.trim(),
      );
      if (!canContinue || !mounted) return;
    }
    // Navigation is automatically handled by the app_router.dart listening to auth and profile changes.
  }

  Future<void> _handleEmailSignIn(AuthProvider authProvider) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final success = await authProvider.signIn(email, password);
    if (!mounted) return;

    if (success) {
      HapticFeedback.lightImpact();
      await _persistRememberMe();
      await _navigateAfterAuth(authProvider);
    } else if (authProvider.error != null) {
      HapticFeedback.heavyImpact();
      UiUtils.showErrorSnackbar(context, authProvider.error!);
    }
  }

  Future<void> _handleEmailRegister(AuthProvider authProvider) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final success = await authProvider.register(email, password);
    if (!mounted) return;

    if (success) {
      HapticFeedback.lightImpact();
      await _showEmailVerificationDialog(isRegistration: true, email: email);
      if (mounted) context.go('/profile_setup');
    } else if (authProvider.error != null) {
      HapticFeedback.heavyImpact();
      UiUtils.showErrorSnackbar(context, authProvider.error!);
    }
  }

  Widget _buildGoogleButton(AppColors colors) {
    final authProvider = context.read<AuthProvider>();

    return AppButton(
      text: context.l10n.authGoogleLogin,
      type: AppButtonType.secondary,
      size: AppButtonSize.large,
      semanticLabel: context.l10n.authGoogleLogin,
      icon: Icon(Icons.g_mobiledata, size: 24, color: colors.textPrimary),
      onPressed: () async {
        final success = await authProvider.signInWithGoogle();
        if (success && mounted) {
          HapticFeedback.lightImpact();
          await _navigateAfterAuth(authProvider);
        } else if (mounted && authProvider.error != null) {
          HapticFeedback.heavyImpact();
          UiUtils.showErrorSnackbar(context, authProvider.error!);
        }
      },
    );
  }

  Future<void> _showForgotPasswordDialog() async {
    final colors = context.appColors;
    final screenContext = context; // capture BEFORE opening the dialog
    final resetEmailController = TextEditingController(
      text: _isValidEmail(_emailController.text)
          ? _emailController.text.trim()
          : '',
    );

    final sent = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            context.l10n.authForgotPassTitle,
            style: AppTextStyles.titleLarge,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.authForgotPassDesc,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: resetEmailController,
                label: context.l10n.authEmailLabel,
                keyboardType: TextInputType.emailAddress,
                prefixIcon: const Icon(Icons.mail_outline),
                autofillHints: const [AutofillHints.email],
              ),
            ],
          ),
          actions: [
            AppButton(
              text: context.l10n.authCancel,
              type: AppButtonType.text,
              size: AppButtonSize.small,
              onPressed: () => Navigator.pop(ctx, false),
            ),
            AppButton(
              text: context.l10n.authSendLink,
              type: AppButtonType.primary,
              size: AppButtonSize.small,
              onPressed: () async {
                final email = resetEmailController.text.trim();
                if (!_isValidEmail(email)) {
                  ScaffoldMessenger.of(screenContext).showSnackBar(
                    SnackBar(content: Text(context.l10n.authInvalidEmail)),
                  );
                  return;
                }
                try {
                  final authProvider = screenContext.read<AuthProvider>();
                  final success = await authProvider.sendPasswordReset(email);
                  if (!ctx.mounted) return;
                  if (success) {
                    Navigator.pop(ctx, true);
                  } else {
                    Navigator.pop(ctx, false);
                    if (!screenContext.mounted) return;
                    ScaffoldMessenger.of(screenContext).showSnackBar(
                      SnackBar(
                        content: Text(
                          authProvider.error ??
                              screenContext.l10n.authSendEmailError,
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (ctx.mounted) Navigator.pop(ctx, false);
                  if (screenContext.mounted) {
                    ScaffoldMessenger.of(screenContext).showSnackBar(
                      SnackBar(
                        content: Text(screenContext.l10n.authSendEmailError),
                      ),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );

    final emailSentTo = resetEmailController.text.trim();

    if (sent == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${context.l10n.authCheckInbox}${emailSentTo.isNotEmpty ? emailSentTo : ""}${context.l10n.authAndSpam}',
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    }

    // Dispose the controller after the frame has been processed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      resetEmailController.dispose();
    });
  }

  /// Retorna true si puede continuar (correo verificado o usuario eligió continuar).
  Future<bool> _showEmailVerificationDialog({
    required bool isRegistration,
    required String email,
  }) async {
    final colors = context.appColors;
    final authProvider = context.read<AuthProvider>();

    return await showDialog<bool>(
          context: context,
          barrierDismissible: !isRegistration,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.mark_email_unread_outlined, color: colors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.l10n.authVerifyEmailTitle,
                    style: AppTextStyles.titleLarge,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isRegistration
                      ? context.l10n.authSentLinkTo
                      : context.l10n.authAccountNotVerified,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  email,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: colors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  isRegistration
                      ? context.l10n.authOpenLinkOnRegister
                      : context.l10n.authOpenLinkThenVerify,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
            actions: [
              if (isRegistration)
                AppButton(
                  text: context.l10n.authUnderstood,
                  type: AppButtonType.primary,
                  size: AppButtonSize.small,
                  onPressed: () => Navigator.pop(ctx, true),
                )
              else
                AppButton(
                  text: context.l10n.authContinueWithoutVerify,
                  type: AppButtonType.text,
                  size: AppButtonSize.small,
                  onPressed: () => Navigator.pop(ctx, true),
                ),
              AppButton(
                text: context.l10n.authResendEmail,
                type: AppButtonType.text,
                size: AppButtonSize.small,
                onPressed: () async {
                  final ok = await authProvider.sendEmailVerification();
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        ok
                            ? ctx.l10n.authEmailResent
                            : (authProvider.error ?? ctx.l10n.authResendError),
                      ),
                    ),
                  );
                },
              ),
              if (!isRegistration)
                AppButton(
                  text: context.l10n.authAlreadyVerified,
                  type: AppButtonType.primary,
                  size: AppButtonSize.small,
                  onPressed: () async {
                    final verified = await authProvider
                        .refreshEmailVerificationStatus();
                    if (!ctx.mounted) return;
                    if (verified) {
                      Navigator.pop(ctx, true);
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          content: Text(ctx.l10n.authEmailVerifiedSuccess),
                          backgroundColor: colors.success,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          content: Text(ctx.l10n.authVerificationNotDetected),
                        ),
                      );
                    }
                  },
                ),
            ],
          ),
        ) ??
        false;
  }
}
