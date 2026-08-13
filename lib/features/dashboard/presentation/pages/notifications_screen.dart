import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:autodoc/core/providers/notification_center_provider.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/models/app_notification_model.dart';
import 'package:autodoc/core/theme/app_breakpoints.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_radius.dart';
import 'package:autodoc/core/theme/app_spacing.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/widgets/app_empty_state.dart';
import 'package:autodoc/core/widgets/app_page_body.dart';
import 'package:autodoc/l10n/app_localizations.dart';
import 'package:timeago/timeago.dart' as timeago;

/// Normaliza un `deepLink` legado: antes de la Tarea 12, `/reserva_detail`
/// se guardaba sin id (dependía de `state.extra`, que ya no existe en la
/// ruta). Los documentos de notificación escritos antes de ese cambio siguen
/// teniendo ese deep link "pelado" en Firestore -- sin esta normalización,
/// tocar esa notificación cae en el 404 del router en vez de abrir la
/// reserva. Si el `metadata` trae el id de la reserva, se reconstruye la
/// ruta nueva; si no, se redirige a una ruta segura en vez del 404.
///
/// Público (sin `_`) para poder probarlo directamente desde
/// `test/features/dashboard/notifications_screen_test.dart`.
String normalizeDeepLink(AppNotification notif) {
  final deepLink = notif.deepLink;
  if (deepLink == '/reserva_detail') {
    final reservaId = notif.metadata?['reservaId'] as String?;
    if (reservaId != null && reservaId.isNotEmpty) {
      return '/reserva_detail/$reservaId';
    }
    return '/chat_list';
  }
  return deepLink!;
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final l10n = AppLocalizations.of(context)!;
    final userSession = context.watch<UserProfileProvider>();
    final notifProvider = context.watch<NotificationCenterProvider>();
    final userId = (userSession.userData?.idUsuario ?? "");

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.notifications,
          style: AppTextStyles.titleLarge.copyWith(color: colors.textPrimary),
        ),
        backgroundColor: colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.textPrimary),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (notifProvider.hasUnread)
            TextButton(
              onPressed: () => notifProvider.markAllAsRead(userId),
              child: Text(
                l10n.markAllRead,
                style: TextStyle(color: colors.primary),
              ),
            ),
        ],
      ),
      backgroundColor: colors.surface,
      body: _buildBody(context, notifProvider, userId, colors),
    );
  }

  Widget _buildBody(
    BuildContext context,
    NotificationCenterProvider provider,
    String userId,
    AppColors colors,
  ) {
    if (provider.isLoading && provider.notifications.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.notifications.isEmpty) {
      // No existe una clave de descripción específica en lib/l10n/ (solo
      // `noNotifications`); se reutiliza para título y descripción en vez de
      // inventar una clave nueva, fuera del alcance de esta fase.
      return AppEmptyState(
        icon: Icons.notifications_none_rounded,
        title: AppLocalizations.of(context)!.noNotifications,
        description: AppLocalizations.of(context)!.noNotifications,
      );
    }

    return AppPageBody(
      maxWidth: AppBreakpoints.maxReadingWidth,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        itemCount: provider.notifications.length,
        separatorBuilder: (_, index) => Divider(
          height: 1,
          color: colors.outline.withValues(alpha: 0.3),
          // 16 (gutter) + 44 (icono) + 12 (gap) = alineado con el texto.
          indent: AppSpacing.base + 44 + AppSpacing.md,
        ),
        itemBuilder: (context, index) {
          final notif = provider.notifications[index];
          return _NotificationTile(
            notification: notif,
            colors: colors,
            onTap: () {
              // Mark as read
              if (!notif.leida) {
                provider.markAsRead(userId, notif.id);
              }
              // Navigate to deep link
              if (notif.deepLink != null && notif.deepLink!.isNotEmpty) {
                context.push(normalizeDeepLink(notif));
              }
            },
            onDismiss: () => provider.deleteNotification(userId, notif.id),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final AppColors colors;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NotificationTile({
    required this.notification,
    required this.colors,
    required this.onTap,
    required this.onDismiss,
  });

  IconData _iconForType(String tipo) {
    switch (tipo) {
      case 'alerta':
        return Icons.warning_amber_rounded;
      case 'chat':
        return Icons.chat_bubble_outline_rounded;
      case 'reserva':
        return Icons.calendar_today_rounded;
      case 'review':
        return Icons.star_outline_rounded;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _colorForType(String tipo) {
    switch (tipo) {
      case 'alerta':
        return colors.warning;
      case 'chat':
        return colors.primary;
      case 'reserva':
        return colors.success;
      case 'review':
        // Antes: const Color(0xFFFFB800) — un dorado literal fuera de la
        // paleta. `warning` es el token ámbar de la marca y ya se usa para
        // "atención"; una reseña pendiente es exactamente eso.
        return colors.warning;
      default:
        return colors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = _colorForType(notification.tipo);
    final icon = _iconForType(notification.tipo);
    final unreadSuffix = notification.leida ? '' : ', sin leer';

    return Semantics(
      container: true,
      button: true,
      label: '${notification.titulo}. ${notification.body}$unreadSuffix',
      onTapHint: 'abrir',
      child: Dismissible(
        key: Key(notification.id),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => onDismiss(),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: AppSpacing.xl),
          color: colors.error.withValues(alpha: 0.1),
          child: Icon(Icons.delete_outline, color: colors.error),
        ),
        child: ExcludeSemantics(
          child: InkWell(
            onTap: onTap,
            child: Container(
              color: notification.leida
                  ? Colors.transparent
                  : colors.primary.withValues(alpha: 0.04),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.base,
                vertical: AppSpacing.md,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(icon, color: iconColor, size: 22),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                notification.titulo,
                                style: AppTextStyles.labelLarge.copyWith(
                                  color: colors.textPrimary,
                                  fontWeight: notification.leida
                                      ? FontWeight.normal
                                      : FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              timeago.format(
                                notification.timestamp,
                                locale: 'es',
                              ),
                              style: AppTextStyles.labelSmall.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          notification.body,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: colors.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Unread dot
                  if (!notification.leida) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(top: AppSpacing.xs + 2),
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
