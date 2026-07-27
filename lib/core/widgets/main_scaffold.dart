import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/features/mechanic/presentation/widgets/mechanic_sidebar.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/utils/responsive.dart';
import 'package:autodoc/core/widgets/app_top_nav_bar.dart';

class MainScaffold extends StatelessWidget {
  final Widget child;

  const MainScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = Responsive.isDesktop(context);
    final userSession = Provider.of<UserProfileProvider>(context);
    final isMecanico = userSession.userData?.rol == 'Mecanico';

    if (isMecanico) {
      return Scaffold(
        appBar: isDesktop ? null : AppBar(title: const Text('AutoDoc Taller')),
        drawer: isDesktop ? null : const Drawer(child: MechanicSidebar()),
        body: Row(
          children: [
            if (isDesktop) const MechanicSidebar(),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      body: isDesktop
          ? Column(
              children: [
                const AppTopNavBar(),
                Expanded(child: child),
              ],
            )
          : child,
      bottomNavigationBar: isDesktop ? null : const InstagramBottomNavBar(),
    );
  }
}

class InstagramBottomNavBar extends StatelessWidget {
  const InstagramBottomNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors = context.appColors;

    final String currentLocation = GoRouterState.of(context).uri.toString();

    int currentIndex = 0;
    if (currentLocation.startsWith('/garage')) currentIndex = 1;
    if (currentLocation.startsWith('/chat_list')) {
      currentIndex = 2; // New tab for Chat
    }
    if (currentLocation.startsWith('/workshop_directory')) currentIndex = 3;
    if (currentLocation.startsWith('/user_profile')) currentIndex = 4;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceContainer : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white12 : Colors.black12,
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _NavBarItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home_filled,
                isActive: currentIndex == 0,
                onTap: () => context.go('/dashboard'),
                colors: colors,
                isDark: isDark,
              ),
              _NavBarItem(
                icon: Icons.directions_car_outlined,
                activeIcon: Icons.directions_car,
                isActive: currentIndex == 1,
                onTap: () => context.go('/garage'),
                colors: colors,
                isDark: isDark,
              ),
              _NavBarItem(
                icon: Icons.chat_bubble_outline_rounded,
                activeIcon: Icons.chat_bubble_rounded,
                isActive: currentIndex == 2,
                onTap: () => context.go('/chat_list'),
                colors: colors,
                isDark: isDark,
              ),
              _NavBarItem(
                icon: Icons.build_circle_outlined,
                activeIcon: Icons.build_circle,
                isActive: currentIndex == 3,
                onTap: () => context.go('/workshop_directory'),
                colors: colors,
                isDark: isDark,
              ),
              _NavBarItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                isActive: currentIndex == 4,
                onTap: () => context.go('/user_profile'),
                colors: colors,
                isDark: isDark,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final bool isActive;
  final VoidCallback onTap;
  final AppColors colors;
  final bool isDark;

  const _NavBarItem({
    required this.icon,
    required this.activeIcon,
    required this.isActive,
    required this.onTap,
    required this.colors,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isActive
              ? (isDark
                    ? colors.primary.withValues(alpha: 0.15)
                    : colors.primary.withValues(alpha: 0.1))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          isActive ? activeIcon : icon,
          color: isActive
              ? colors.primary
              : (isDark ? Colors.white70 : Colors.black87),
          size: 26,
        ),
      ),
    );
  }
}
