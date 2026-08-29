import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:autodoc/core/providers/session_reset.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/router/app_router.dart'
    show estadosMecanicoAprobado;
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_motion.dart';
import 'package:autodoc/core/theme/app_radius.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/utils/responsive.dart';
import 'package:autodoc/core/widgets/app_button.dart';
import 'package:autodoc/core/widgets/app_page_body.dart';
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
      // Mismo conjunto de valores de aprobacion que `resolveRedirect` en
      // app_router.dart y que `isMecanico()` en firestore.rules — deben
      // mantenerse sincronizados.
      final estado = userData.estado.trim().toLowerCase();
      if (estadosMecanicoAprobado.contains(estado)) {
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
    final authProvider = context.read<AuthProvider>();
    clearSessionFrom(context);
    await authProvider.signOut();
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
            child: AppPageBody(
              maxWidth: AppBreakpoints.maxFormWidth,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Pending icon
                  _entrance(context, 0, _pendingIcon(context, colors)),

                  const SizedBox(height: AppSpacing.xxxl),

                  // Title
                  _entrance(
                    context,
                    1,
                    Text(
                      'Cuenta Pendiente de Aprobación',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.headlineSmall.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.base),

                  // Subtitle
                  _entrance(
                    context,
                    2,
                    Text(
                      'Tu taller ${userData?.nombreCompleto ?? ''} ha sido registrado exitosamente. '
                      'Un administrador revisará tu solicitud pronto.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: colors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Info card
                  _entrance(
                    context,
                    3,
                    Semantics(
                      container: true,
                      label: '¿Qué sigue?',
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainer,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
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
                                  'Completa tu verificación: sin la foto de la fachada y los datos del '
                                  'taller, el administrador no tiene con qué revisarte.',
                              colors: colors,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            _infoRow(
                              icon: Icons.notifications_outlined,
                              text:
                                  'Recibirás una notificación push cuando tu cuenta sea aprobada.',
                              colors: colors,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            _infoRow(
                              icon: Icons.access_time_outlined,
                              text:
                                  'Tiempo estimado de aprobación: 1-2 días hábiles.',
                              colors: colors,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xxxl),

                  // Check approval button
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      text: _checking ? 'Verificando...' : 'Verificar Estado',
                      isLoading: _checking,
                      onPressed: _checking ? null : _checkApprovalStatus,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.base),

                  // Acceso al expediente de verificacion. Es lo que convierte
                  // esta pantalla de espera en algo accionable: sin evidencia
                  // el administrador no tiene con que verificar el taller, asi
                  // que "esperar" no avanzaba el tramite por si solo.
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      text: 'Completar verificación',
                      type: AppButtonType.secondary,
                      onPressed: () => context.push('/workshop_verification'),
                      icon: const Icon(Icons.assignment_outlined),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.base),

                  // Sign out option
                  AppButton(
                    text: 'Cerrar sesión',
                    type: AppButtonType.text,
                    size: AppButtonSize.small,
                    icon: const Icon(Icons.logout_rounded),
                    onPressed: _signOut,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pendingIcon(BuildContext context, AppColors colors) {
    final size = Responsive.size(context, 96);
    return Container(
      width: size,
      height: size,
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
        size: size / 2,
        color: colors.primary,
        semanticLabel: 'Pendiente de aprobación',
      ),
    );
  }

  /// Entrada escalonada. Con reduced motion se devuelve el hijo tal cual: se
  /// conserva el contenido y se elimina el desplazamiento, que es lo que la
  /// preferencia pide.
  Widget _entrance(BuildContext context, int index, Widget child) {
    if (AppMotion.reduced(context)) return child;
    final delay = AppMotion.staggerStep * index;
    return child
        .animate()
        .fadeIn(
          duration: AppMotion.sheetEnter,
          delay: delay,
          curve: AppMotion.easeOut,
        )
        .slideY(
          begin: 0.15,
          end: 0,
          duration: AppMotion.sheetEnter,
          delay: delay,
          curve: AppMotion.easeOut,
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
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodyMedium.copyWith(
              color: colors.textSecondary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
