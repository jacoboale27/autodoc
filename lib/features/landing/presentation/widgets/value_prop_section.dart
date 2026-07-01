/*

import 'package:flutter/material.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/theme/app_spacing.dart';

class ValuePropSection extends StatelessWidget {
  const ValuePropSection({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Container(
      width: double.infinity,
      color: colors.surfaceContainer.withValues(alpha: 0.5),
      padding: const EdgeInsets.symmetric(vertical: 100, horizontal: AppSpacing.xxl),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Flex(
            direction: isDesktop ? Axis.horizontal : Axis.vertical,
            children: [
              // Text Content
              Expanded(
                flex: isDesktop ? 1 : 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tranquilidad para el conductor, eficiencia para el experto.',
                      style: AppTextStyles.headlineLarge.copyWith(fontSize: isDesktop ? 40 : 28),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Diseñamos una plataforma que rompe la barrera de desconfianza entre dueños y talleres. Con AutoDoc, cada intervención es clara, cada costo es justificado y cada vehículo mantiene su valor de reventa.',
                      style: AppTextStyles.bodyLarge.copyWith(color: colors.textSecondary, height: 1.6),
                    ),
                    const SizedBox(height: 48),
                    Row(
                      children: [
                        _StatItem(value: '98%', label: 'Satisfacción del Usuario'),
                        const SizedBox(width: 48),
                        _StatItem(value: '+500', label: 'Talleres Verificados'),
                      ],
                    ),
                  ],
                ),
              ),
              
              if (isDesktop) const SizedBox(width: 80),
              if (!isDesktop) const SizedBox(height: 60),
              
              // Image
              Expanded(
                flex: isDesktop ? 1 : 0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(40),
                  child: Image.network(
                    'https://images.unsplash.com/photo-1649769069590-268b0b994462',
                    fit: BoxFit.cover,
                    height: isDesktop ? 500 : 300,
                    width: double.infinity,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 300,
                      color: colors.surfaceContainer,
                      child: const Icon(Icons.handyman_outlined, color: Colors.white24, size: 48),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;

  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: AppTextStyles.headlineMedium.copyWith(color: context.appColors.secondary),
        ),
        const SizedBox(height: 4),
        Text(
          label.toUpperCase(),
          style: AppTextStyles.labelSmall.copyWith(
            color: context.appColors.textSecondary,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

*/
