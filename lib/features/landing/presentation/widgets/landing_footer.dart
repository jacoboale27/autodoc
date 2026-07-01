/*
import 'package:flutter/material.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/theme/app_spacing.dart';

class LandingFooter extends StatelessWidget {
  const LandingFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: AppSpacing.xxl),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.outline.withValues(alpha: 0.2))),
      ),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Brand
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: colors.secondary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Icon(Icons.directions_car, color: colors.primary, size: 16),
                            ),
                            const SizedBox(width: 10),
                            Text('AutoDoc', style: AppTextStyles.titleMedium),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Transformando la gestión automotriz a través de tecnología inteligente y transparencia garantizada.',
                          style: AppTextStyles.bodySmall.copyWith(color: colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Links
                  _FooterColumn(
                    title: 'Para Dueños',
                    links: ['Mi Garaje', 'Alertas SOAT', 'Mantenimientos'],
                  ),
                  const SizedBox(width: 60),
                  _FooterColumn(
                    title: 'Para Talleres',
                    links: ['Gestión Digital', 'Reputación', 'Evidence Upload'],
                  ),
                  const SizedBox(width: 60),
                  _FooterColumn(
                    title: 'Social',
                    isSocial: true,
                    links: ['Instagram', 'LinkedIn'],
                  ),
                ],
              ),
              const SizedBox(height: 80),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.top(32),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: colors.outline.withValues(alpha: 0.1))),
                ),
                child: Text(
                  '© 2026 AutoDoc Technology. Hecho para conductores inteligentes.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall.copyWith(color: colors.textSecondary.withValues(alpha: 0.5)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterColumn extends StatelessWidget {
  final String title;
  final List<String> links;
  final bool isSocial;

  const _FooterColumn({required this.title, required this.links, this.isSocial = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        ...links.map((link) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            link,
            style: AppTextStyles.bodySmall.copyWith(color: context.appColors.textSecondary),
          ),
        )),
      ],
    );
  }
}
*/
