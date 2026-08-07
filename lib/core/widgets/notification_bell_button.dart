import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:autodoc/core/providers/notification_center_provider.dart';
import 'package:autodoc/core/theme/app_colors.dart';

/// Reusable notification bell button widget that shows unread count badge.
///
/// Displays a bell icon (active when unread, inactive otherwise) with optional
/// unread count badge in the top-right corner. Navigates to /notifications route on tap.
class NotificationBellButton extends StatelessWidget {
  /// Color for icon and badge when there are unread notifications.
  /// If null, defaults to primary app color.
  final Color? unreadColor;

  /// Color for icon when there are no unread notifications.
  /// If null, defaults to secondary text color.
  final Color? readColor;

  /// Icon to use when there are no unread notifications.
  /// Defaults to [Icons.notifications_none_rounded].
  final IconData readIcon;

  /// Icon to use when there are unread notifications.
  /// Defaults to [Icons.notifications_active_rounded].
  final IconData unreadIcon;

  const NotificationBellButton({
    super.key,
    this.unreadColor,
    this.readColor,
    this.readIcon = Icons.notifications_none_rounded,
    this.unreadIcon = Icons.notifications_active_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationCenterProvider>(
      builder: (context, notifProvider, _) {
        final appColors = context.appColors;
        final hasUnread = notifProvider.hasUnread;

        // Determine colors
        final activeColor = unreadColor ?? appColors.primary;
        final inactiveColor = readColor ?? appColors.textSecondary;
        final icon = hasUnread ? unreadIcon : readIcon;
        final iconColor = hasUnread ? activeColor : inactiveColor;
        final badgeColor = unreadColor ?? appColors.error;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: Icon(icon, color: iconColor),
              onPressed: () => context.push('/notifications'),
              tooltip: 'Notificaciones',
            ),
            if (hasUnread)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    '${notifProvider.unreadCount > 9 ? "9+" : notifProvider.unreadCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
