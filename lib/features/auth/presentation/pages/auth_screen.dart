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
import 'package:autodoc/core/utils/responsive.dart';
import 'package:autodoc/core/utils/l10n_extension.dart';
import 'package:autodoc/core/utils/ui_utils.dart';

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

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: colors.surface,
        child: Stack(
          children: [
            // Decorative blobs
            Positioned.fill(
              child: AuthBackgroundBlobs(colors: colors, isDark: isDark),
            ),

            // Main Content
            Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  Responsive.padding(context, 24),
                  Responsive.padding(context, 60),
                  Responsive.padding(context, 24),
                  Responsive.padding(context, 100),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo Section
                      AuthLogoSection(colors: colors),
                      const SizedBox(height: 32),

                      // Central Glassmorphism Card
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _buildGlassCard(
                          colors,
                          isDark,
                          key: ValueKey(_isLoginMode),
                        ),
                      ),

                      const SizedBox(height: 32),
                      // Bottom Switch Link
                      TextButton(
                        onPressed: _toggleMode,
                        child: RichText(
                          text: TextSpan(
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: colors.textSecondary,
                            ),
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
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Navigation Bar for Mobile
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: AuthBottomNav(colors: colors, isDark: isDark),
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
          width: double.infinity,
          constraints: BoxConstraints(maxWidth: Responsive.size(context, 450)),
          padding: EdgeInsets.all(Responsive.padding(context, 32)),
          decoration: BoxDecoration(
            color: colors.surfaceContainer.withValues(
              alpha: isDark ? 0.7 : 0.8,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colors.outline.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
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
              _buildTextField(
                label: _isLoginMode
                    ? context.l10n.authEmailOrUserLabel
                    : context.l10n.authEmailLabel,
                hint: _isLoginMode
                    ? context.l10n.authEmailOrUserHint
                    : context.l10n.authEmailHint,
                icon: Icons.mail_outline,
                colors: colors,
                controller: _emailController,
              ),
              const SizedBox(height: 20),
              _buildTextField(
                label: context.l10n.authPasswordLabel,
                hint: context.l10n.authPasswordHint,
                icon: Icons.lock_outline,
                isPassword: true,
                colors: colors,
                controller: _passwordController,
              ),

              const SizedBox(height: 12),
              // Extras
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: Checkbox(
                          value: _rememberMe,
                          onChanged: (value) {
                            setState(() => _rememberMe = value ?? false);
                          },
                          activeColor: colors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => setState(() => _rememberMe = !_rememberMe),
                        child: Text(
                          context.l10n.authRememberMe,
                          style: AppTextStyles.labelMedium.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_isLoginMode)
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: _showForgotPasswordDialog,
                      child: Text(
                        context.l10n.authForgotPassword,
                        style: AppTextStyles.labelMedium.copyWith(
                          color: colors.primary,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 24),
              // Submit Button
              _buildSubmitButton(colors),

              const SizedBox(height: 24),
              // Divider
              Row(
                children: [
                  Expanded(
                    child: Divider(
                      color: colors.outline.withValues(alpha: 0.5),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      context.l10n.authOrContinueWith,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: colors.textSecondary,
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
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required IconData icon,
    required AppColors colors,
    required TextEditingController controller,
    bool isPassword = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(
              color: colors.textPrimary,
            ),
          ),
        ),
        Container(
          height: Responsive.size(context, 52),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.outline.withValues(alpha: 0.5)),
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword,
            style: AppTextStyles.bodyLarge.copyWith(color: colors.textPrimary),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: AppTextStyles.bodyLarge.copyWith(
                color: colors.textSecondary,
              ),
              prefixIcon: Icon(
                icon,
                color: colors.textSecondary,
                size: Responsive.iconSize(context, 20),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 15),
            ),
          ),
        ),
      ],
    );
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

    if (email.isEmpty || password.isEmpty) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.authCompleteCredentials)),
      );
      return;
    }

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

    if (email.isEmpty || password.isEmpty) {
      HapticFeedback.heavyImpact();
      UiUtils.showErrorSnackbar(context, context.l10n.authCompleteCredentials);
      return;
    }
    if (!_isValidEmail(email)) {
      HapticFeedback.heavyImpact();
      UiUtils.showErrorSnackbar(context, context.l10n.authEnterValidEmail);
      return;
    }
    if (password.length < 6) {
      HapticFeedback.heavyImpact();
      UiUtils.showErrorSnackbar(context, context.l10n.authPasswordTooShort);
      return;
    }

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

  Widget _buildSubmitButton(AppColors colors) {
    final authProvider = context.watch<AuthProvider>();

    return Semantics(
      label: _isLoginMode ? 'Botón Iniciar sesión' : 'Botón Registrarse',
      button: true,
      enabled: !authProvider.isLoading,
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: authProvider.isLoading
              ? null
              : () async {
                  if (_isLoginMode) {
                    await _handleEmailSignIn(authProvider);
                  } else {
                    await _handleEmailRegister(authProvider);
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: colors.onPrimary,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: AppTextStyles.titleMedium,
          ),
          child: authProvider.isLoading
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: colors.onPrimary,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  _isLoginMode
                      ? context.l10n.authLoginButton
                      : context.l10n.authRegisterButton,
                ),
        ),
      ),
    );
  }

  Widget _buildGoogleButton(AppColors colors) {
    final authProvider = context.read<AuthProvider>();

    return Semantics(
      label: 'Botón Continuar con Google',
      button: true,
      child: OutlinedButton(
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
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 54),
          side: BorderSide(color: colors.outline, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          foregroundColor: colors.textPrimary,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.network(
              'https://www.google.com/images/branding/googleg/1x/googleg_standard_color_128dp.png',
              height: 20,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.g_mobiledata, size: 20, color: Colors.blue),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                context.l10n.authGoogleLogin,
                style: AppTextStyles.titleSmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showForgotPasswordDialog() async {
    final colors = context.appColors;
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
              TextField(
                controller: resetEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: context.l10n.authEmailLabel,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.mail_outline),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.l10n.authCancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: colors.primary),
              onPressed: () async {
                final email = resetEmailController.text.trim();
                if (!_isValidEmail(email)) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(context.l10n.authInvalidEmail)),
                  );
                  return;
                }
                final authProvider = ctx.read<AuthProvider>();
                final success = await authProvider.sendPasswordReset(email);
                if (!ctx.mounted) return;
                if (success) {
                  Navigator.pop(ctx, true);
                } else {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        authProvider.error ?? ctx.l10n.authSendEmailError,
                      ),
                    ),
                  );
                }
              },
              child: Text(context.l10n.authSendLink),
            ),
          ],
        );
      },
    );

    final emailSentTo = resetEmailController.text.trim();
    resetEmailController.dispose();

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
                  context.l10n.authOpenLinkThenVerify,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
            actions: [
              if (isRegistration)
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.primary,
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(context.l10n.authUnderstood),
                )
              else
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(context.l10n.authContinueWithoutVerify),
                ),
              TextButton(
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
                child: Text(context.l10n.authResendEmail),
              ),
              if (!isRegistration)
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.primary,
                  ),
                  onPressed: () async {
                    final verified = await authProvider
                        .refreshEmailVerificationStatus();
                    if (!ctx.mounted) return;
                    if (verified) {
                      Navigator.pop(ctx, true);
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          content: Text(ctx.l10n.authEmailVerifiedSuccess),
                          backgroundColor: Colors.green,
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
                  child: Text(context.l10n.authAlreadyVerified),
                ),
            ],
          ),
        ) ??
        false;
  }
}
