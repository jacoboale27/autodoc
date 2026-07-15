import 'package:flutter/material.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';

class AuthBottomNav extends StatelessWidget {
  final AppColors colors;
  final bool isDark;

  const AuthBottomNav({super.key, required this.colors, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outline.withValues(alpha: 0.2))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            offset: const Offset(0, -5),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavAction(Icons.help_outline, 'Ayuda', colors),
          _buildNavAction(Icons.shield_outlined, 'Privacidad', colors),
          _buildNavAction(Icons.gavel_outlined, 'Términos', colors),
        ],
      ),
    );
  }

  Widget _buildNavAction(IconData icon, String label, AppColors colors) {
    return GestureDetector(
      onTap: () {},
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: colors.textSecondary),
          const SizedBox(height: 4),
          Text(label, style: AppTextStyles.labelSmall.copyWith(color: colors.textSecondary)),
        ],
      ),
    );
  }
}
