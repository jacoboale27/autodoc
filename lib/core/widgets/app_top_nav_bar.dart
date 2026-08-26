import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_shadows.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/utils/responsive.dart';
import 'package:autodoc/core/providers/theme_provider.dart';
import 'package:autodoc/core/providers/language_provider.dart';
import 'package:autodoc/core/providers/notification_center_provider.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/widgets/navigation/app_nav_destination.dart';

class AppTopNavBar extends StatelessWidget {
  const AppTopNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final currentPath = GoRouterState.of(context).uri.path;

    return Container(
      height: Responsive.size(context, 70),
      margin: EdgeInsets.all(Responsive.padding(context, 16)),
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.padding(context, 24),
      ),
      decoration: BoxDecoration(
        color: colors.surfaceContainer.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.outline.withValues(alpha: 0.3)),
        boxShadow: Theme.of(context).brightness == Brightness.dark
            ? AppShadows.darkSm
            : AppShadows.lightSm,
      ),
      child: Row(
        children: [
          // Logo
          InkWell(
            onTap: () => context.go('/dashboard'),
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                Container(
                  width: Responsive.size(context, 32),
                  height: Responsive.size(context, 32),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: EdgeInsets.all(Responsive.padding(context, 4)),
                  child: SvgPicture.asset('assets/logo/autodoc_isotype.svg'),
                ),
                SizedBox(width: Responsive.padding(context, 12)),
                Text(
                  'AutoDoc',
                  style: AppTextStyles.titleLarge.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: colors.textPrimary,
                    fontSize: Responsive.fontSize(context, 20),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final destination in AppNavDestinations.owner)
                      _TopNavLink(
                        title: destination.label,
                        icon: destination.icon,
                        semanticLabel: destination.semanticLabel,
                        isActive: currentPath == destination.route,
                        onTap: () => context.go(destination.route),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Theme & Language Toggles
          Consumer2<ThemeProvider, LanguageProvider>(
            builder: (context, themeProvider, languageProvider, _) {
              // isDarkMode (no `themeMode == dark`) resuelve tambien
              // ThemeMode.system contra el brillo real de la plataforma.
              final isDark = themeProvider.isDarkMode;
              final isEnglish =
                  languageProvider.currentLocale.languageCode == 'en';
              return Row(
                children: [
                  IconButton(
                    icon: Icon(
                      isDark
                          ? Icons.light_mode_outlined
                          : Icons.dark_mode_outlined,
                      color: colors.textSecondary,
                    ),
                    onPressed: themeProvider.toggleTheme,
                    tooltip: 'Theme',
                  ),
                  SizedBox(width: Responsive.padding(context, 8)),
                  InkWell(
                    onTap: () {
                      languageProvider.changeLanguage(isEnglish ? 'es' : 'en');
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Tooltip(
                      message: 'Cambiar idioma',
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: colors.outline.withValues(alpha: 0.5),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isEnglish ? 'EN' : 'ES',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colors.textSecondary,
                            fontSize: Responsive.fontSize(context, 12),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: Responsive.padding(context, 16)),
                ],
              );
            },
          ),

          // Notification Bell with Badge
          Consumer<NotificationCenterProvider>(
            builder: (context, notifProvider, _) {
              return Stack(
                children: [
                  IconButton(
                    icon: Icon(
                      notifProvider.hasUnread
                          ? Icons.notifications_active_rounded
                          : Icons.notifications_none_rounded,
                      color: notifProvider.hasUnread
                          ? colors.primary
                          : colors.textSecondary,
                    ),
                    onPressed: () => context.push('/notifications'),
                    tooltip: 'Notificaciones',
                  ),
                  if (notifProvider.hasUnread)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Semantics(
                        label:
                            '${notifProvider.unreadCount} notificaciones sin leer',
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: colors.error,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Text(
                            notifProvider.unreadCount > 9
                                ? '9+'
                                : '${notifProvider.unreadCount}',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: colors.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          SizedBox(width: Responsive.padding(context, 8)),

          // Profile Action
          Consumer<UserProfileProvider>(
            builder: (context, userSession, _) {
              final user = userSession.userData;
              return Tooltip(
                message: 'Tu cuenta',
                child: InkWell(
                  onTap: () => context.push('/user_profile'),
                  borderRadius: BorderRadius.circular(999),
                  child: CircleAvatar(
                    radius: Responsive.size(context, 16),
                    backgroundColor: colors.primary,
                    backgroundImage: user?.fotoPerfilUrl != null
                        ? NetworkImage(user!.fotoPerfilUrl!)
                        : null,
                    child: user?.fotoPerfilUrl == null
                        ? Text(
                            user?.nombreCompleto.isNotEmpty == true
                                ? user!.nombreCompleto[0].toUpperCase()
                                : 'U',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: colors.surface,
                            ),
                          )
                        : null,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TopNavLink extends StatelessWidget {
  final String title;
  final IconData icon;
  final String semanticLabel;
  final bool isActive;
  final VoidCallback onTap;

  const _TopNavLink({
    required this.title,
    required this.icon,
    required this.semanticLabel,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final color = isActive ? colors.primary : colors.textSecondary;

    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.padding(context, 16),
            vertical: Responsive.padding(context, 8),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: Responsive.iconSize(context, 18)),
              SizedBox(width: Responsive.padding(context, 8)),
              Text(
                title,
                style: AppTextStyles.labelLarge.copyWith(
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  color: color,
                  fontSize: Responsive.fontSize(context, 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
