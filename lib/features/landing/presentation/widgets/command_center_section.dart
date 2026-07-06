import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_radius.dart';
import 'package:autodoc/core/utils/l10n_extension.dart';

enum CommandCenterTab { garage, history, alerts, sync }

class CommandCenterSection extends StatefulWidget {
  const CommandCenterSection({super.key});

  @override
  State<CommandCenterSection> createState() => _CommandCenterSectionState();
}

class _CommandCenterSectionState extends State<CommandCenterSection> {
  CommandCenterTab _activeTab = CommandCenterTab.garage;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDesktop = MediaQuery.of(context).size.width > 1000;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 100, horizontal: AppSpacing.xxl),
      child: Column(
        children: [
          Text(
            context.l10n.commandCenterTitle,
            style: AppTextStyles.headlineLarge.copyWith(fontSize: isDesktop ? 48 : 32),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.commandCenterSubtitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyLarge.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 64),

          Container(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Flex(
              direction: isDesktop ? Axis.horizontal : Axis.vertical,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Tabs List
                Expanded(
                  flex: isDesktop ? 4 : 0,
                  child: Column(
                    children: [
                      _TabCard(
                        title: context.l10n.tabGarageTitle,
                        subtitle: context.l10n.tabGarageSubtitle,
                        icon: Icons.directions_car,
                        isActive: _activeTab == CommandCenterTab.garage,
                        onTap: () => setState(() => _activeTab = CommandCenterTab.garage),
                      ),
                      const SizedBox(height: 16),
                      _TabCard(
                        title: context.l10n.tabHistoryTitle,
                        subtitle: context.l10n.tabHistorySubtitle,
                        icon: Icons.history,
                        isActive: _activeTab == CommandCenterTab.history,
                        onTap: () => setState(() => _activeTab = CommandCenterTab.history),
                      ),
                      const SizedBox(height: 16),
                      _TabCard(
                        title: context.l10n.tabAlertsTitle,
                        subtitle: context.l10n.tabAlertsSubtitle,
                        icon: Icons.notifications_active,
                        isActive: _activeTab == CommandCenterTab.alerts,
                        onTap: () => setState(() => _activeTab = CommandCenterTab.alerts),
                      ),
                      const SizedBox(height: 16),
                      _TabCard(
                        title: context.l10n.tabSyncTitle,
                        subtitle: context.l10n.tabSyncSubtitle,
                        icon: Icons.sync,
                        isActive: _activeTab == CommandCenterTab.sync,
                        onTap: () => setState(() => _activeTab = CommandCenterTab.sync),
                      ),
                    ],
                  ),
                ),
                
                if (isDesktop) const SizedBox(width: 48),
                if (!isDesktop) const SizedBox(height: 48),
                
                // Showcase Area
                Expanded(
                  flex: isDesktop ? 6 : 0,
                  child: Container(
                    height: 500,
                    decoration: BoxDecoration(
                      color: colors.surfaceContainer,
                      borderRadius: BorderRadius.circular(AppRadius.xxl),
                      border: Border.all(color: colors.outline.withValues(alpha: 0.2)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: AnimatedSwitcher(
                      duration: 400.ms,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.05, 0),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: _buildShowcaseContent(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShowcaseContent() {
    switch (_activeTab) {
      case CommandCenterTab.garage:
        return _ShowcaseImage(
          key: const ValueKey('garage'),
          imageUrl: 'https://images.unsplash.com/photo-1592199564137-731e91904939',
          overlay: Positioned.fill(
            child: Center(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  _GlassTag(label: 'Modelo', value: 'Porsche 911 Carrera'),
                  _GlassTag(label: 'Año', value: '2023'),
                  _GlassTag(
                    label: 'Seguro SOAT', 
                    value: 'Vigente hasta Dic 2026', 
                    icon: Icons.shield_outlined,
                    isWide: true,
                  ),
                ],
              ),
            ),
          ),
        );
      case CommandCenterTab.history:
        return _ShowcaseImage(
          key: const ValueKey('history'),
          imageUrl: 'https://images.pexels.com/photos/8985913/pexels-photo-8985913.jpeg',
          overlay: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Línea de Tiempo Clínica', style: AppTextStyles.titleLarge),
                const SizedBox(height: 32),
                _TimelineItem(
                  date: '15 JUN 2026',
                  title: 'Cambio de Kit de Distribución',
                  subtitle: 'Taller Central Motor • 45,000 km',
                  isLast: false,
                ),
                _TimelineItem(
                  date: '12 MAR 2026',
                  title: 'Mantenimiento Preventivo',
                  subtitle: 'AutoExpress • 42,300 km',
                  isLast: true,
                  dimmed: true,
                ),
              ],
            ),
          ),
        );
      case CommandCenterTab.alerts:
        return _ShowcaseImage(
          key: const ValueKey('alerts'),
          imageUrl: 'https://images.pexels.com/photos/10924197/pexels-photo-10924197.jpeg',
          overlay: Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: context.appColors.secondary,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: context.appColors.secondary.withValues(alpha: 0.3),
                    blurRadius: 40,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning_amber_rounded, color: context.appColors.primary, size: 40),
                  const SizedBox(width: 16),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ATENCIÓN REQUERIDA',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: context.appColors.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Próximo cambio de aceite en 500km',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: context.appColors.primary.withValues(alpha: 0.8),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(duration: 2.seconds),
          ),
        );
      case CommandCenterTab.sync:
        return Container(
          key: const ValueKey('sync'),
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _SyncNode(icon: Icons.garage_outlined, label: 'TALLER', color: context.appColors.primary),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Container(
                      height: 2,
                      color: context.appColors.secondary.withValues(alpha: 0.3),
                      child: Center(
                        child: Icon(Icons.refresh, color: context.appColors.secondary, size: 24)
                            .animate(onPlay: (c) => c.repeat())
                            .rotate(duration: 2.seconds),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  _SyncNode(icon: Icons.phone_android, label: 'TU APP', color: context.appColors.secondary),
                ],
              ),
              const SizedBox(height: 48),
              Text('Sincronización Certificada', style: AppTextStyles.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Tu mecánico sube la evidencia y tú la recibes al instante con trazabilidad total.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(color: context.appColors.textSecondary),
              ),
            ],
          ),
        );
    }
  }
}

class _TabCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _TabCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: AnimatedContainer(
        duration: 300.ms,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isActive ? colors.primary : colors.surfaceContainer,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: isActive ? colors.secondary : colors.outline.withValues(alpha: 0.2),
            width: 1,
          ),
          boxShadow: isActive ? [
            BoxShadow(
              color: colors.primary.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ] : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colors.secondary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: colors.secondary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.titleMedium.copyWith(
                      color: isActive ? Colors.white : colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: isActive ? Colors.white70 : colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShowcaseImage extends StatelessWidget {
  final String imageUrl;
  final Widget overlay;

  const _ShowcaseImage({super.key, required this.imageUrl, required this.overlay});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          imageUrl,
          fit: BoxFit.cover,
          color: Colors.black.withValues(alpha: 0.4),
          colorBlendMode: BlendMode.darken,
          errorBuilder: (context, error, stackTrace) => Container(color: Colors.black54),
        ),
        overlay,
      ],
    );
  }
}

class _GlassTag extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final bool isWide;

  const _GlassTag({required this.label, required this.value, this.icon, this.isWide = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isWide ? 300 : 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appColors.secondary.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: AppTextStyles.labelSmall.copyWith(color: context.appColors.secondary, fontSize: 10),
              ),
              Text(value, style: AppTextStyles.labelLarge),
            ],
          ),
          if (icon != null) Icon(icon, color: context.appColors.secondary, size: 20),
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final String date;
  final String title;
  final String subtitle;
  final bool isLast;
  final bool dimmed;

  const _TimelineItem({required this.date, required this.title, required this.subtitle, required this.isLast, this.dimmed = false});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: dimmed ? 0.5 : 1.0,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: context.appColors.secondary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: context.appColors.secondary.withValues(alpha: 0.5),
                      blurRadius: 8,
                    )
                  ],
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 40,
                  color: context.appColors.outline.withValues(alpha: 0.3),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(date, style: AppTextStyles.labelSmall.copyWith(color: context.appColors.secondary)),
              Text(title, style: AppTextStyles.labelLarge),
              Text(subtitle, style: AppTextStyles.bodySmall.copyWith(color: context.appColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SyncNode extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SyncNode({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Icon(icon, color: color, size: 32),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            fontWeight: FontWeight.w800,
            color: context.appColors.textSecondary,
          ),
        ),
      ],
    );
  }
}