import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class AuthScreen extends StatefulWidget {
  final bool isLogin;
  const AuthScreen({super.key, required this.isLogin});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late bool _isLoginMode;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _isLoginMode = widget.isLogin;
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
    const primaryPurple = Color(0xFF522C81);
    const mintColor = Color(0xFF81E6D9);
    const customBlue = Color(0xFF1E3A8A);
    const bgColorStart = Colors.white;
    const bgColorEnd = Color(0xFFF0F4F8);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [bgColorStart, bgColorEnd],
          ),
        ),
        child: Stack(
          children: [
            // Main Content
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 60, 24, 100),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo Section
                    _buildLogoSection(primaryPurple),
                    const SizedBox(height: 32),
                    
                    // Central Glassmorphism Card
                    _buildGlassCard(primaryPurple, mintColor, customBlue),
                    
                    const SizedBox(height: 32),
                    // Bottom Switch Link
                    TextButton(
                      onPressed: _toggleMode,
                      child: RichText(
                        text: TextSpan(
                          style: GoogleFonts.inter(color: const Color(0xFF475569), fontSize: 14),
                          children: [
                            TextSpan(text: _isLoginMode ? '¿No tienes una cuenta? ' : '¿Ya tienes una cuenta? '),
                            TextSpan(
                              text: _isLoginMode ? 'Regístrate gratis' : 'Inicia sesión',
                              style: GoogleFonts.inter(
                                color: primaryPurple,
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
              child: _buildBottomNav(primaryPurple),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoSection(Color primary) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(Icons.directions_car, color: primary, size: 48),
        ),
        const SizedBox(height: 16),
        Text(
          'AutoDoc',
          style: GoogleFonts.inter(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Tu copiloto para el control total de tu vehículo',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildGlassCard(Color primary, Color mint, Color blue) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 450),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                _isLoginMode ? 'Bienvenido de nuevo' : 'Crea tu cuenta',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isLoginMode ? 'Ingresa tus credenciales para acceder' : 'Regístrate para comenzar a gestionar tus documentos',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF475569), fontSize: 13),
              ),
              const SizedBox(height: 32),
              
              // Form Fields
              _buildTextField(
                label: 'Correo electrónico',
                hint: 'nombre@ejemplo.com',
                icon: Icons.mail_outline,
                mint: mint,
                controller: _emailController,
              ),
              const SizedBox(height: 20),
              _buildTextField(
                label: 'Contraseña',
                hint: '••••••••',
                icon: Icons.lock_outline,
                isPassword: true,
                mint: mint,
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
                          value: true,
                          onChanged: (_) {},
                          activeColor: primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('Recordarme', style: TextStyle(color: Color(0xFF475569), fontSize: 12)),
                    ],
                  ),
                  if (_isLoginMode)
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {},
                      child: Text(
                        '¿Olvidaste tu contraseña?',
                        style: GoogleFonts.inter(
                          color: primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              
              const SizedBox(height: 24),
              // Submit Button
              _buildSubmitButton(primary, mint, blue),
              
              const SizedBox(height: 24),
              // Divider
              Row(
                children: [
                  Expanded(child: Divider(color: const Color(0xFFCBD5E1).withValues(alpha: 0.5))),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('O CONTINUAR CON', style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  Expanded(child: Divider(color: const Color(0xFFCBD5E1).withValues(alpha: 0.5))),
                ],
              ),
              
              const SizedBox(height: 24),
              // Google Button
              _buildGoogleButton(blue),
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
    required Color mint,
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
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF334155),
            ),
          ),
        ),
        Container(
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
              prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 15),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(Color primary, Color mint, Color blue) {
    final authProvider = context.watch<AuthProvider>();
    
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: authProvider.isLoading ? null : () async {
          if (_isLoginMode) {
            final success = await authProvider.signIn(
              _emailController.text,
              _passwordController.text,
            );
            if (success && mounted) {
              // Esperar a que userData se cargue
              int attempts = 0;
              while (authProvider.userData == null && attempts < 10) {
                await Future.delayed(const Duration(milliseconds: 500));
                attempts++;
              }
              
              if (mounted) {
                final currentAuthProvider = context.read<AuthProvider>();
                final userData = currentAuthProvider.userData;
                if (userData != null) {
                  final role = userData.rol.trim().toLowerCase();
                  if (role == 'taller' || role == 'mecanico') {
                    context.go('/mechanic_search');
                  } else {
                    context.go('/dashboard');
                  }
                } else {
                  // Si no tiene perfil, enviarlo a completar
                  context.go('/profile_setup');
                }
              }
            }
          } else {
            final success = await authProvider.register(
              _emailController.text,
              _passwordController.text,
            );
            if (success && mounted) context.go('/profile_setup');
          }
          
          if (!authProvider.isLoading && authProvider.error != null && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(authProvider.error!)),
            );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: mint,
          foregroundColor: blue,
          elevation: 8,
          shadowColor: mint.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        child: Text(_isLoginMode ? 'Iniciar Sesión' : 'Registrarse'),
      ),
    );
  }

  Widget _buildGoogleButton(Color blue) {
    final authProvider = context.read<AuthProvider>();
    
    return OutlinedButton(
      onPressed: () async {
        final success = await authProvider.signInWithGoogle();
        if (success && mounted) {
          // Esperar a que userData se cargue
          int attempts = 0;
          while (authProvider.userData == null && attempts < 10) {
            await Future.delayed(const Duration(milliseconds: 500));
            attempts++;
          }
          
          if (mounted) {
            final currentAuthProvider = context.read<AuthProvider>();
            final userData = currentAuthProvider.userData;
            if (userData != null) {
              final role = userData.rol.trim().toLowerCase();
              if (role == 'taller' || role == 'mecanico') {
                context.go('/mechanic_search');
              } else {
                context.go('/dashboard');
              }
            } else {
              // Si no tiene perfil (usuario nuevo de Google), enviarlo a completar
              context.go('/profile_setup');
            }
          }
        } else if (mounted && authProvider.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(authProvider.error!)),
          );
        }
      },
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 54),
        side: BorderSide(color: blue, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        foregroundColor: blue,
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
              'Entrar con Google',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(Color primary) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.4),
            border: const Border(top: BorderSide(color: Colors.white24)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(child: _buildNavItem(Icons.login, 'Login', _isLoginMode, primary, () => setState(() => _isLoginMode = true))),
              Expanded(child: _buildNavItem(Icons.person_add_outlined, 'Registro', !_isLoginMode, primary, () => setState(() => _isLoginMode = false))),
              Expanded(child: _buildNavItem(Icons.help_outline, 'Soporte', false, primary, () {})),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive, Color primary, VoidCallback onTap) {
    final color = isActive ? primary : const Color(0xFF64748B);
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
