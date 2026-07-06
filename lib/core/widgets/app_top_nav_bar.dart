import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/utils/responsive.dart';
import 'package:autodoc/features/auth/presentation/providers/auth_provider.dart';
import 'package:autodoc/core/providers/theme_provider.dart';
import 'package:autodoc/core/providers/language_provider.dart';
import 'package:provider/provider.dart';

class AppTopNavBar extends StatelessWidget {
  const AppTopNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final currentPath = GoRouterState.of(context).uri.path;

    return Container(
      height: Responsive.size(context, 70),
      margin: EdgeInsets.all(Responsive.padding(context, 16)),
      padding: EdgeInsets.symmetric(horizontal: Responsive.padding(context, 24)),
      decoration: BoxDecoration(
        color: colors.surfaceContainer.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.outline.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
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
                  child: Icon(Icons.directions_car, color: colors.primary, size: Responsive.iconSize(context, 20)),
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
          
          const Spacer(),
          
          // Nav Links
          _TopNavLink(
            title: 'Dashboard',
            icon: Icons.dashboard_outlined,
            isActive: currentPath == '/dashboard',
            onTap: () => context.go('/dashboard'),
          ),
          _TopNavLink(
            title: 'Garaje',
            icon: Icons.directions_car_outlined,
            isActive: currentPath == '/garage',
            onTap: () => context.push('/garage'),
          ),
          _TopNavLink(
            title: 'Directorio',
            icon: Icons.storefront_outlined,
            isActive: currentPath == '/workshop_directory',
            onTap: () => context.push('/workshop_directory'),
          ),
          
          const Spacer(),
          
          // Theme & Language Toggles
          Consumer2<ThemeProvider, LanguageProvider>(
            builder: (context, themeProvider, languageProvider, _) {
              final isDark = themeProvider.themeMode == ThemeMode.dark;
              final isEnglish = languageProvider.currentLocale.languageCode == 'en';
              return Row(
                children: [
                  IconButton(
                    icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, color: colors.textSecondary),
                    onPressed: () {
                      themeProvider.setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
                    },
                    tooltip: 'Theme',
                  ),
                  SizedBox(width: Responsive.padding(context, 8)),
                  InkWell(
                    onTap: () {
                      languageProvider.changeLanguage(isEnglish ? 'es' : 'en');
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: colors.outline.withValues(alpha: 0.5)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isEnglish ? 'EN' : 'ES',
                        style: TextStyle(fontWeight: FontWeight.bold, color: colors.textSecondary, fontSize: Responsive.fontSize(context, 12)),
                      ),
                    ),
                  ),
                  SizedBox(width: Responsive.padding(context, 16)),
                ],
              );
            },
          ),
          
          // Profile Action
          Consumer<AuthProvider>(
            builder: (context, authProvider, _) {
              final user = authProvider.user;
              return InkWell(
                onTap: () => context.push('/user_profile'),
                borderRadius: BorderRadius.circular(999),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: Responsive.size(context, 16),
                      backgroundColor: colors.primary,
                      backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                      child: user?.photoURL == null 
                          ? Text(
                              user?.displayName?.isNotEmpty == true ? user!.displayName![0].toUpperCase() : 'U',
                              style: TextStyle(color: Colors.white, fontSize: Responsive.fontSize(context, 14), fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                    SizedBox(width: Responsive.padding(context, 12)),
                    Text(
                      'Mi Perfil',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: colors.textPrimary,
                        fontSize: Responsive.fontSize(context, 14),
                      ),
                    ),
                  ],
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
  final bool isActive;
  final VoidCallback onTap;

  const _TopNavLink({
    required this.title,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final color = isActive ? colors.primary : colors.textSecondary;
    
    return InkWell(
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
    );
  }
}
