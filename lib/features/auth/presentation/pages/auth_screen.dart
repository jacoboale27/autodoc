import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'package:autodoc/core/providers/user_session_provider.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/utils/responsive.dart';
import 'package:autodoc/core/utils/l10n_extension.dart';

class AuthScreen extends StatefulWidget {
  final bool isLogin;
  const AuthScreen({super.key, required this.isLogin});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  static const String _supportEmail = 'soporte@autodoc.app';

  late bool _isLoginMode;
  bool _rememberMe = false;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _isLoginMode = widget.isLogin;
    _loadRememberMePreferences();
  }

  Future<void> _loadRememberMePreferences() async {
    final sessionProvider = context.read<UserSessionProvider>();
    final remember = await sessionProvider.loadRememberMe();
    final savedEmail = await sessionProvider.loadSavedEmail();
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
    await context.read<UserSessionProvider>().persistRememberMe(
      remember: _rememberMe,
      email: _emailController.text,
    );
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
            // Decorative blobs (theme aware)
            Positioned(
              top: -100,
              left: -50,
              child: Container(
                width: Responsive.size(context, 300),
                height: Responsive.size(context, 300),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.primary.withValues(alpha: isDark ? 0.1 : 0.05),
                ),
              ).animate().scale(duration: 2.seconds, curve: Curves.easeOut),
            ),
            Positioned(
              bottom: -50,
              right: -100,
              child: Container(
                width: Responsive.size(context, 400),
                height: Responsive.size(context, 400),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.secondary.withValues(alpha: isDark ? 0.1 : 0.05),
                ),
              ).animate().scale(delay: 500.ms, duration: 2.seconds, curve: Curves.easeOut),
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
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo Section
                    _buildLogoSection(colors),
                    const SizedBox(height: 32),
                    
                    // Central Glassmorphism Card
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _buildGlassCard(colors, isDark, key: ValueKey(_isLoginMode)),
                    ),
                    
                    const SizedBox(height: 32),
                    // Bottom Switch Link
                    TextButton(
                      onPressed: _toggleMode,
                      child: RichText(
                        text: TextSpan(
                          style: AppTextStyles.bodyMedium.copyWith(color: colors.textSecondary),
                          children: [
                            TextSpan(text: _isLoginMode ? context.l10n.authNoAccount : context.l10n.authHaveAccount),
                            TextSpan(
                              text: _isLoginMode ? context.l10n.authRegisterFree : context.l10n.authLogin,
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
            
            // Bottom Navigation Bar for Mobile
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomNav(colors, isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoSection(AppColors colors) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(Icons.directions_car, color: colors.primary, size: Responsive.iconSize(context, 48)),
        ),
        const SizedBox(height: 16),
        Text(
          'AutoDoc',
          style: AppTextStyles.headlineLarge.copyWith(
            color: colors.textPrimary,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.authCopilotSubtitle,
          style: AppTextStyles.bodyMedium.copyWith(color: colors.textSecondary),
        ),
      ],
    ).animate().fadeIn(duration: 800.ms).slideY(begin: -0.2, end: 0);
  }

  Widget _buildGlassCard(AppColors colors, bool isDark, {Key? key}) {
    return ClipRRect(
      key: key,
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), // Reduced blur for performance
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(maxWidth: Responsive.size(context, 450)),
          padding: EdgeInsets.all(Responsive.padding(context, 32)),
          decoration: BoxDecoration(
            color: colors.surfaceContainer.withValues(alpha: isDark ? 0.7 : 0.8),
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
                _isLoginMode ? context.l10n.authWelcomeBack : context.l10n.authCreateAccount,
                style: AppTextStyles.headlineSmall.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isLoginMode ? context.l10n.authEnterCredentials : context.l10n.authRegisterToManage,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: 32),
              
              // Form Fields
              _buildTextField(
                label: _isLoginMode ? context.l10n.authEmailOrUserLabel : context.l10n.authEmailLabel,
                hint: _isLoginMode ? context.l10n.authEmailOrUserHint : context.l10n.authEmailHint,
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => setState(() => _rememberMe = !_rememberMe),
                        child: Text(
                          context.l10n.authRememberMe,
                          style: AppTextStyles.labelMedium.copyWith(color: colors.textSecondary),
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
                  Expanded(child: Divider(color: colors.outline.withValues(alpha: 0.5))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(context.l10n.authOrContinueWith, style: AppTextStyles.labelSmall.copyWith(color: colors.textSecondary)),
                  ),
                  Expanded(child: Divider(color: colors.outline.withValues(alpha: 0.5))),
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
              hintStyle: AppTextStyles.bodyLarge.copyWith(color: colors.textSecondary),
              prefixIcon: Icon(icon, color: colors.textSecondary, size: Responsive.iconSize(context, 20)),
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

    final sessionProvider = context.read<UserSessionProvider>();
    final userData = sessionProvider.userData;
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
      context.go('/profile_setup');
    }
  }

  Future<void> _handleEmailSignIn(AuthProvider authProvider) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa correo y contraseña.')),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authProvider.error!)),
      );
    }
  }

  Future<void> _handleEmailRegister(AuthProvider authProvider) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (!_isValidEmail(email)) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un correo electrónico válido.')),
      );
      return;
    }
    if (password.length < 6) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La contraseña debe tener al menos 6 caracteres.')),
      );
      return;
    }

    final success = await authProvider.register(email, password);
    if (!mounted) return;

    if (success) {
      HapticFeedback.lightImpact();
      await _showEmailVerificationDialog(
        isRegistration: true,
        email: email,
      );
      if (mounted) context.go('/profile_setup');
    } else if (authProvider.error != null) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authProvider.error!)),
      );
    }
  }

  Widget _buildSubmitButton(AppColors colors) {
    final authProvider = context.watch<AuthProvider>();
    
    return SizedBox(
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: AppTextStyles.titleMedium,
        ),
        child: authProvider.isLoading 
          ? SizedBox(
              width: 24, height: 24, 
              child: CircularProgressIndicator(color: colors.onPrimary, strokeWidth: 2)
            ) 
          : Text(_isLoginMode ? context.l10n.authLoginButton : context.l10n.authRegisterButton),
      ),
    );
  }

  Widget _buildGoogleButton(AppColors colors) {
    final authProvider = context.read<AuthProvider>();
    
    return OutlinedButton(
      onPressed: () async {
        final success = await authProvider.signInWithGoogle();
        if (success && mounted) {
          HapticFeedback.lightImpact();
          final sessionProvider = context.read<UserSessionProvider>();
          final userData = sessionProvider.userData;
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
            context.go('/profile_setup');
          }
        } else if (mounted && authProvider.error != null) {
          HapticFeedback.heavyImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(authProvider.error!)),
          );
        }
      },
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 54),
        side: BorderSide(color: colors.outline, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        foregroundColor: colors.textPrimary,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.network(
            'https://www.google.com/images/branding/googleg/1x/googleg_standard_color_128dp.png',
            height: 20,
            errorBuilder: (context, error, stackTrace) => const Icon(Icons.g_mobiledata, size: 20, color: Colors.blue),
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
    );
  }

  Widget _buildBottomNav(AppColors colors, bool isDark) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          decoration: BoxDecoration(
            color: colors.surfaceContainer.withValues(alpha: isDark ? 0.8 : 0.9),
            border: Border(top: BorderSide(color: colors.outline.withValues(alpha: 0.2))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(child: _buildNavItem(Icons.login, context.l10n.authTabLogin, _isLoginMode, colors, () => setState(() => _isLoginMode = true))),
              Expanded(child: _buildNavItem(Icons.person_add_outlined, context.l10n.authTabRegister, !_isLoginMode, colors, () => setState(() => _isLoginMode = false))),
              Expanded(child: _buildNavItem(Icons.help_outline, context.l10n.authTabSupport, false, colors, _showSupportSheet)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive, AppColors colors, VoidCallback onTap) {
    final color = isActive ? colors.primary : colors.textSecondary;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: AppTextStyles.labelSmall.copyWith(color: color),
          ),
        ],
      ),
    );
  }

  Future<void> _showForgotPasswordDialog() async {
    final colors = context.appColors;
    final resetEmailController = TextEditingController(
      text: _isValidEmail(_emailController.text) ? _emailController.text.trim() : '',
    );

    final sent = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
              style: AppTextStyles.bodyMedium.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: resetEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: context.l10n.authEmailLabel,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                  SnackBar(content: Text(authProvider.error ?? ctx.l10n.authSendEmailError)),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                  style: AppTextStyles.bodyMedium.copyWith(color: colors.textSecondary),
                ),
                const SizedBox(height: 8),
                Text(
                  email,
                  style: AppTextStyles.titleMedium.copyWith(color: colors.primary),
                ),
                const SizedBox(height: 12),
                Text(
                  context.l10n.authOpenLinkThenVerify,
                  style: AppTextStyles.bodySmall.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
            actions: [
              if (isRegistration)
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: colors.primary),
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
                  style: FilledButton.styleFrom(backgroundColor: colors.primary),
                  onPressed: () async {
                    final verified = await authProvider.refreshEmailVerificationStatus();
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

  void _showSupportSheet() {
    final colors = context.appColors;

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: colors.surfaceContainer,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.authSupportCenter,
                style: AppTextStyles.titleLarge.copyWith(color: colors.primary),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.authSupportDesc,
                style: AppTextStyles.bodyMedium.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: 20),
              _supportTile(
                icon: Icons.email_outlined,
                title: context.l10n.authSupportEmail,
                subtitle: _supportEmail,
                colors: colors,
                onTap: () {
                  Clipboard.setData(const ClipboardData(text: _supportEmail));
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(context.l10n.authEmailCopied)),
                  );
                },
              ),
              _supportTile(
                icon: Icons.mark_email_read_outlined,
                title: context.l10n.authEmailVerification,
                subtitle: context.l10n.authEmailNotReceived,
                colors: colors,
                onTap: () {
                  Navigator.pop(ctx);
                  if (_isLoginMode && _isValidEmail(_emailController.text)) {
                    _showEmailVerificationDialog(
                      isRegistration: false,
                      email: _emailController.text.trim(),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.l10n.authLoginToResend),
                      ),
                    );
                  }
                },
              ),
              _supportTile(
                icon: Icons.lock_reset,
                title: context.l10n.authForgotPassTileTitle,
                subtitle: context.l10n.authReceiveRecoveryLink,
                colors: colors,
                onTap: () {
                  Navigator.pop(ctx);
                  _showForgotPasswordDialog();
                },
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.authSupportHours,
                style: AppTextStyles.labelSmall.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _supportTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required AppColors colors,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: colors.primary),
      title: Text(title, style: AppTextStyles.titleSmall),
      subtitle: Text(subtitle, style: AppTextStyles.bodySmall.copyWith(color: colors.textSecondary)),
      trailing: Icon(Icons.chevron_right, size: 20, color: colors.textSecondary),
      onTap: onTap,
    );
  }
}
