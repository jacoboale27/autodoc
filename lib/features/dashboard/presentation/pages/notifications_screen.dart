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
import 'package:autodoc/core/widgets/acciones_de_cabecera.dart';
import 'package:autodoc/features/mechanic/presentation/providers/empleado_provider.dart';

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

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  /// Bloquea el segundo tap de "marcar todo como leido" mientras el primero
  /// sigue en vuelo: el batch escribe en Firestore y repetirlo duplica trabajo.
  bool _marcandoTodo = false;

  /// Invitación a un taller cuya respuesta está en vuelo (guard de GAPS-07:
  /// aceptar dos veces llamaría dos veces al servidor).
  String? _respondiendo;

  /// Invitaciones ya respondidas. `_respondiendo` se suelta al terminar, y la
  /// notificación no desaparece hasta el frame siguiente: sin esto, un toque
  /// más en ese hueco volvía a mandar la respuesta al servidor.
  final Set<String> _respondidas = {};

  /// Acepta o rechaza la invitación de un taller (observaciones del
  /// 2026-09-19). Aceptar convierte la cuenta en cuenta de empleado del
  /// taller, así que primero se confirma, y después se recarga el perfil y
  /// se lleva a la persona a su nuevo panel.
  Future<void> _responderInvitacion(
    AppNotification notif,
    String userId, {
    required bool aceptar,
  }) async {
    if (_respondiendo != null || _respondidas.contains(notif.id)) return;
    final idTaller = (notif.metadata?['id_taller'] ?? '').toString();
    final nombreTaller = (notif.metadata?['nombre_taller'] ?? 'el taller')
        .toString();
    if (idTaller.isEmpty) return;

    if (aceptar) {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Unirte al taller'),
          content: Text(
            'Tu cuenta pasará a ser una cuenta de empleado de $nombreTaller: '
            'entrarás al panel del taller con tu mismo correo y contraseña. '
            '¿Quieres unirte?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Unirme'),
            ),
          ],
        ),
      );
      if (confirmar != true || !mounted) return;
    }

    setState(() => _respondiendo = notif.id);
    final empleados = context.read<EmpleadoProvider>();
    final notificaciones = context.read<NotificationCenterProvider>();
    final perfil = context.read<UserProfileProvider>();
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await empleados.responderInvitacion(
      idTaller: idTaller,
      aceptar: aceptar,
    );
    if (!mounted) return;
    setState(() => _respondiendo = null);
    if (!ok) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            empleados.error ?? 'No se pudo responder la invitación.',
          ),
        ),
      );
      return;
    }
    _respondidas.add(notif.id);
    await notificaciones.deleteNotification(userId, notif.id);
    if (!aceptar) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Rechazaste la invitación.')),
      );
      return;
    }
    messenger.showSnackBar(
      SnackBar(content: Text('Ya eres parte de $nombreTaller.')),
    );
    // Con el perfil recargado, el rol ya es de taller y el router manda
    // cada pantalla al panel del taller.
    await perfil.fetchUserData(userId);
    router.go('/mechanic_dashboard');
  }

  Future<void> _marcarTodo(
    NotificationCenterProvider provider,
    String userId,
  ) async {
    if (_marcandoTodo) return;
    setState(() => _marcandoTodo = true);
    try {
      await provider.markAllAsRead(userId);
    } finally {
      if (mounted) setState(() => _marcandoTodo = false);
    }
  }

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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.titleLarge.copyWith(color: colors.textPrimary),
        ),
        backgroundColor: colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.textPrimary),
          onPressed: () => context.pop(),
        ),
        actions: [
          // Blocker 5 (revision de rama completa): con el harness de test
          // montando en español (como el resto de la app), `l10n.markAllRead`
          // ("Marcar todo como leído", 22 caracteres) desbordaba el AppBar a
          // 320dp — el `TextButton` nunca cabía junto al título en un
          // teléfono angosto. Era un bug de producción real que el harness
          // en inglés ("Mark all as read", 16 caracteres) ocultaba. Un
          // `IconButton` con `tooltip` no tiene ancho variable por idioma:
          // cabe siempre, y el texto completo sigue accesible (tooltip al
          // mantener presionado, y como label semántico para lectores de
          // pantalla).
          if (notifProvider.hasUnread)
            IconButton(
              icon: Icon(Icons.done_all_rounded, color: colors.primary),
              tooltip: l10n.markAllRead,
              onPressed: _marcandoTodo
                  ? null
                  : () => _marcarTodo(notifProvider, userId),
            ),
          const AccionesDeCabecera(mostrarCampana: false),
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
          if (notif.tipo == 'invitacion_empleo') {
            return _InvitacionEmpleoTile(
              notification: notif,
              colors: colors,
              respondiendo: _respondiendo == notif.id,
              onAceptar: () =>
                  _responderInvitacion(notif, userId, aceptar: true),
              onRechazar: () =>
                  _responderInvitacion(notif, userId, aceptar: false),
            );
          }
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

/// La invitación de un taller a unirse como empleado, con sus dos respuestas
/// (observaciones del 2026-09-19).
///
/// Es su propio widget y no una variante de `_NotificationTile` porque aquella
/// excluye la semántica de sus hijos (toda la fila es un solo botón): aquí
/// hay dos acciones distintas, y las dos tienen que poder activarse con un
/// lector de pantalla.
class _InvitacionEmpleoTile extends StatelessWidget {
  final AppNotification notification;
  final AppColors colors;
  final bool respondiendo;
  final VoidCallback onAceptar;
  final VoidCallback onRechazar;

  const _InvitacionEmpleoTile({
    required this.notification,
    required this.colors,
    required this.respondiendo,
    required this.onAceptar,
    required this.onRechazar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(Icons.handshake_outlined, color: colors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.titulo,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  notification.body,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    FilledButton(
                      key: Key('invitacion_aceptar_${notification.id}'),
                      onPressed: respondiendo ? null : onAceptar,
                      child: const Text('Aceptar'),
                    ),
                    OutlinedButton(
                      key: Key('invitacion_rechazar_${notification.id}'),
                      onPressed: respondiendo ? null : onRechazar,
                      child: const Text('Rechazar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
