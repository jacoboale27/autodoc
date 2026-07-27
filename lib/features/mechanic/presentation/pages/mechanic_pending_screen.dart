import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/utils/responsive.dart';
import 'package:autodoc/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Pantalla de espera para mecánicos que aún no han sido aprobados por el administrador.
///
/// Un mecánico que acaba de registrarse tiene `estado == 'Pendiente'` en su perfil.
/// Esta pantalla bloquea el acceso al dashboard hasta que el administrador aprueba
/// el taller, cambiando el estado a 'activo'.
class MechanicPendingScreen extends StatefulWidget {
  const MechanicPendingScreen({super.key});

  @override
  State<MechanicPendingScreen> createState() => _MechanicPendingScreenState();
}

class _MechanicPendingScreenState extends State<MechanicPendingScreen> {
  bool _checking = false;

  /// Reload user data to check if admin has approved the account.
  Future<void> _checkApprovalStatus() async {
    setState(() => _checking = true);
    final session = context.read<UserProfileProvider>();
    await session.fetchUserData(session.userData?.idUsuario ?? "");
    if (!mounted) return;
    setState(() => _checking = false);

    final userData = session.userData;
    if (userData != null) {
      final estado = (userData.estado).toLowerCase();
      if (estado == 'activo' || estado == 'active') {
        // Approved! Navigate to mechanic dashboard
        context.go('/mechanic_dashboard');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Tu cuenta aún está pendiente de aprobación. Por favor, espera.',
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _signOut() async {
    await context.read<AuthProvider>().signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final session = context.watch<UserProfileProvider>();
    final userData = session.userData;

    return Scaffold(
      backgroundColor: colors.surface,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [colors.surface, colors.surfaceContainer]
                : [
                    colors.surface,
                    colors.surfaceContainer.withValues(alpha: 0.5),
                  ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(Responsive.padding(context, 32)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Pending icon with animation
                Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colors.primary.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.schedule_rounded,
                        size: 60,
                        color: colors.primary,
                      ),
                    )
                    .animate(onPlay: (c) => c.repeat())
                    .scale(
                      duration: const Duration(seconds: 2),
                      begin: const Offset(1, 1),
                      end: const Offset(1.05, 1.05),
                    )
                    .then()
                    .scale(
                      begin: const Offset(1.05, 1.05),
                      end: const Offset(1, 1),
                    ),

                const SizedBox(height: 40),

                // Title
                Text(
                  'Cuenta Pendiente de Aprobación',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: Responsive.fontSize(context, 24),
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2),

                const SizedBox(height: 16),

                // Subtitle
                Text(
                  'Tu taller ${userData?.nombreCompleto ?? ''} ha sido registrado exitosamente. '
                  'Un administrador revisará tu solicitud pronto.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: Responsive.fontSize(context, 16),
                    color: colors.textSecondary,
                    height: 1.5,
                  ),
                ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.2),

                const SizedBox(height: 12),

                // Info card
                Container(
                  padding: EdgeInsets.all(Responsive.padding(context, 20)),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainer,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colors.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _infoRow(
                        icon: Icons.email_outlined,
                        text:
                            '¿Qué sigue? El administrador revisará tu solicitud y te notificará por email.',
                        colors: colors,
                      ),
                      const SizedBox(height: 12),
                      _infoRow(
                        icon: Icons.notifications_outlined,
                        text:
                            'Recibirás una notificación push cuando tu cuenta sea aprobada.',
                        colors: colors,
                      ),
                      const SizedBox(height: 12),
                      _infoRow(
                        icon: Icons.access_time_outlined,
                        text:
                            'Tiempo estimado de aprobación: 1-2 días hábiles.',
                        colors: colors,
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 1000.ms),

                const SizedBox(height: 40),

                // Check approval button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _checking ? null : _checkApprovalStatus,
                    icon: _checking
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.onPrimary,
                            ),
                          )
                        : const Icon(Icons.refresh_rounded),
                    label: Text(
                      _checking ? 'Verificando...' : 'Verificar Estado',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.fontSize(context, 16),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Sign out option
                TextButton.icon(
                  onPressed: _signOut,
                  icon: Icon(
                    Icons.logout_rounded,
                    color: colors.textSecondary,
                    size: 18,
                  ),
                  label: Text(
                    'Cerrar sesión',
                    style: GoogleFonts.inter(color: colors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String text,
    required AppColors colors,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: colors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: Responsive.fontSize(context, 13),
              color: colors.textSecondary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
