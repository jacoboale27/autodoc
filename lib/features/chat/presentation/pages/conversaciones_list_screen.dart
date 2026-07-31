import 'package:flutter/material.dart';

import 'package:responsive_framework/responsive_framework.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';
import 'package:autodoc/core/providers/user_profile_provider.dart';
import 'package:autodoc/core/providers/auth_session_provider.dart';
import 'package:autodoc/features/chat/presentation/providers/chat_provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:autodoc/core/utils/l10n_extension.dart';

class ConversacionesListScreen extends StatefulWidget {
  const ConversacionesListScreen({super.key});

  @override
  State<ConversacionesListScreen> createState() =>
      _ConversacionesListScreenState();
}

class _ConversacionesListScreenState extends State<ConversacionesListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthSessionProvider>().user;
      final userData = context.read<UserProfileProvider>().userData;
      if (user != null) {
        context.read<ChatProvider>().inicializarConversaciones(
          user.uid,
          userData?.rol == 'Mecanico',
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final chatProvider = context.watch<ChatProvider>();
    final userSession = context.watch<UserProfileProvider>();
    final isMecanico = userSession.userData?.rol == 'Mecanico';

    return Scaffold(
      backgroundColor: isDark ? colors.surfaceContainer : colors.surface,
      appBar: ResponsiveBreakpoints.of(context).largerThan(TABLET)
          ? null
          : AppBar(
              title: Text(
                'Mensajes',
                style: AppTextStyles.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
      body: chatProvider.error != null
          ? Center(
              child: Text(
                context.l10n.adminError(chatProvider.error!),
                style: TextStyle(color: colors.error),
              ),
            )
          : chatProvider.conversaciones.isEmpty
          ? _buildEmptyState(colors, isDark)
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: chatProvider.conversaciones.length,
              separatorBuilder: (context, index) => Divider(
                color: isDark ? Colors.white12 : Colors.black12,
                height: 1,
              ),
              itemBuilder: (context, index) {
                final conv = chatProvider.conversaciones[index];
                final noLeidos = isMecanico
                    ? conv.noLeidosMecanico
                    : conv.noLeidosPropietario;

                // Por ahora usamos nombres genéricos
                final targetName = isMecanico
                    ? conv.nombrePropietario
                    : conv.nombreMecanico;

                return ListTile(
                  onTap: () {
                    if (noLeidos > 0) {
                      chatProvider.marcarComoLeidos(
                        conv.id,
                        isMecanico,
                        userSession.userData?.idUsuario ?? '',
                      );
                    }
                    context.push('/chat/${conv.id}');
                  },
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 8,
                  ),
                  leading: CircleAvatar(
                    radius: 28,
                    backgroundColor: colors.primary.withValues(alpha: 0.2),
                    child: Icon(Icons.person, color: colors.primary),
                  ),
                  title: Text(
                    targetName,
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: noLeidos > 0
                          ? FontWeight.bold
                          : FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    conv.ultimoMensaje,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: noLeidos > 0
                          ? colors.textPrimary
                          : colors.textSecondary,
                      fontWeight: noLeidos > 0
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        timeago.format(conv.ultimoMensajeTs, locale: 'es'),
                        style: TextStyle(
                          fontSize: 12,
                          color: noLeidos > 0
                              ? colors.primary
                              : colors.textSecondary,
                          fontWeight: noLeidos > 0
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      if (noLeidos > 0)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: colors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            noLeidos.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildEmptyState(AppColors colors, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 64,
            color: colors.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No tienes mensajes aún',
            style: AppTextStyles.titleLarge.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Contacta a un taller para iniciar un chat.',
            style: TextStyle(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}
